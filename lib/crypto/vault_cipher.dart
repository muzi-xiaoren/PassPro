import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 会话级加解密器：持有主密码，按需派生密钥并缓存。
///
/// 算法：
///   - 密钥派生 (KDF)：PBKDF2-HMAC-SHA256，随机盐 + 高迭代，输出 32 字节。
///   - 对称加密：AES-256-GCM（AEAD，自带完整性认证标签，无需额外 HMAC）。
///
/// Token 自描述，便于离线迁移脚本产出与本类完全一致的格式：
///   base64url( 0x01 || kdfId(1)=1 || iter(4,BE) || saltLen(1) || salt || nonce(12) || ciphertext+tag(16) )
///
/// 盐随每条 token 一起存储，因此无需任何额外的同步通道/元数据文件；
/// 同一盐派生出的密钥会被缓存，整库通常只需一次 PBKDF2。
class VaultCipher {
  VaultCipher(this._password) : _writeSalt = _randomBytes(16);

  final String _password;

  /// 本会话所有写入统一使用的盐（构造时随机生成一次）。
  final Uint8List _writeSalt;

  static const int _version = 0x01;
  static const int _kdfPbkdf2Sha256 = 1;
  static const int _iterations = 100000;
  static const int _saltLen = 16;
  static const int _nonceLen = 12;
  static const int _tagBits = 128;

  static final Random _rng = Random.secure();

  /// 已派生密钥缓存：'<saltBase64>|<iter>' → 32 字节密钥。
  final Map<String, Uint8List> _keyCache = {};

  static String _cacheKeyFor(Uint8List salt, int iterations) =>
      '${base64Url.encode(salt)}|$iterations';

  Uint8List _deriveKey(Uint8List salt, int iterations) {
    final cacheKey = _cacheKeyFor(salt, iterations);
    return _keyCache[cacheKey] ??=
        _pbkdf2(_password, salt, iterations);
  }

  /// 纯函数版 PBKDF2（无实例状态），供实例方法与后台 isolate 共用。
  static Uint8List _pbkdf2(String password, Uint8List salt, int iterations) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));
    return kdf.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// 后台预热：在独立 isolate 里把 [params] 里各不同盐对应的密钥派生好并写入缓存，
  /// 使随后的 [decrypt] 直接命中缓存、不再阻塞 UI 线程。
  ///
  /// 单条 token 各自带盐，同一会话里往往有若干个不同的盐（迁移批次 + 各次新增），
  /// 每个盐首次解密都要跑一次 ~100ms 的 PBKDF2；解锁后调用本方法一次性预热，
  /// 即可消除"进入软件后前几次复制明显卡顿"的问题。
  Future<void> warmUp(Iterable<({Uint8List salt, int iterations})> params) async {
    final pending = <({Uint8List salt, int iterations, String cacheKey})>[];
    final seen = <String>{};
    for (final p in params) {
      final ck = _cacheKeyFor(p.salt, p.iterations);
      if (_keyCache.containsKey(ck) || !seen.add(ck)) continue;
      pending.add((salt: p.salt, iterations: p.iterations, cacheKey: ck));
    }
    if (pending.isEmpty) return;
    final password = _password;
    final derived = await Isolate.run(() => [
          for (final p in pending)
            (
              cacheKey: p.cacheKey,
              key: _pbkdf2(password, p.salt, p.iterations),
            ),
        ]);
    for (final d in derived) {
      _keyCache[d.cacheKey] = d.key;
    }
  }

  /// 从 token 里解析出（盐, 迭代次数），用于 [warmUp] 枚举所有需要预热的盐。
  /// 非本格式（旧数据/坏数据）返回 null。
  static ({Uint8List salt, int iterations})? tokenParams(String token) {
    try {
      final data = base64Url.decode(_padBase64(token));
      if (data.length < 1 + 1 + 4 + 1 + _saltLen + _nonceLen + 16) return null;
      if (data[0] != _version) return null;
      var o = 1;
      if (data[o++] != _kdfPbkdf2Sha256) return null;
      final iterations = _readU32be(data, o);
      o += 4;
      final saltLen = data[o++];
      if (o + saltLen > data.length) return null;
      return (
        salt: Uint8List.fromList(data.sublist(o, o + saltLen)),
        iterations: iterations,
      );
    } catch (_) {
      return null;
    }
  }

  /// 加密明文，返回 base64url token（始终用最新格式）。
  String encrypt(String plaintext) {
    final key = _deriveKey(_writeSalt, _iterations);
    final nonce = _randomBytes(_nonceLen);
    final ct = _gcm(
      forEncryption: true,
      key: key,
      nonce: nonce,
      input: Uint8List.fromList(utf8.encode(plaintext)),
    );
    final out = BytesBuilder()
      ..addByte(_version)
      ..addByte(_kdfPbkdf2Sha256)
      ..add(_u32be(_iterations))
      ..addByte(_writeSalt.length)
      ..add(_writeSalt)
      ..add(nonce)
      ..add(ct);
    return base64Url.encode(out.toBytes());
  }

  /// 解密 token；主密钥错误或数据损坏抛 [CryptoException]。
  String decrypt(String token) {
    Uint8List data;
    try {
      data = base64Url.decode(_padBase64(token));
    } on FormatException {
      throw const CryptoException('token 不是合法 base64url');
    }
    if (data.length < 1 + 1 + 4 + 1 + _saltLen + _nonceLen + 16) {
      throw const CryptoException('token 长度不合法');
    }
    if (data[0] != _version) {
      throw CryptoException('未知的 token 版本: 0x${data[0].toRadixString(16)}');
    }
    var o = 1;
    final kdfId = data[o++];
    if (kdfId != _kdfPbkdf2Sha256) {
      throw CryptoException('未知的 KDF: $kdfId');
    }
    final iterations = _readU32be(data, o);
    o += 4;
    final saltLen = data[o++];
    if (o + saltLen + _nonceLen + 16 > data.length) {
      throw const CryptoException('token 字段越界');
    }
    final salt = Uint8List.fromList(data.sublist(o, o + saltLen));
    o += saltLen;
    final nonce = Uint8List.fromList(data.sublist(o, o + _nonceLen));
    o += _nonceLen;
    final ct = Uint8List.fromList(data.sublist(o));

    final key = _deriveKey(salt, iterations);
    final Uint8List plain;
    try {
      plain = _gcm(forEncryption: false, key: key, nonce: nonce, input: ct);
    } catch (_) {
      // GCM 标签校验失败（主密钥错误或数据被篡改）等。
      throw const CryptoException('解密失败（主密钥错误或数据损坏）');
    }
    try {
      return utf8.decode(plain);
    } on FormatException {
      throw const CryptoException('解密后不是合法 UTF-8');
    }
  }

  static Uint8List _gcm({
    required bool forEncryption,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List input,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        forEncryption,
        AEADParameters(KeyParameter(key), _tagBits, nonce, Uint8List(0)),
      );
    final out = Uint8List(cipher.getOutputSize(input.length));
    final len = cipher.processBytes(input, 0, input.length, out, 0);
    final fin = cipher.doFinal(out, len);
    return Uint8List.sublistView(out, 0, len + fin);
  }

  static Uint8List _u32be(int v) {
    final out = Uint8List(4);
    ByteData.view(out.buffer).setUint32(0, v, Endian.big);
    return out;
  }

  static int _readU32be(Uint8List b, int offset) =>
      ByteData.sublistView(b, offset, offset + 4).getUint32(0, Endian.big);

  static Uint8List _randomBytes(int n) {
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  static String _padBase64(String s) {
    final pad = (4 - s.length % 4) % 4;
    return s + ('=' * pad);
  }
}

class CryptoException implements Exception {
  final String message;
  const CryptoException(this.message);
  @override
  String toString() => 'CryptoException: $message';
}
