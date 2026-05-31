import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Fernet (spec v0x80) 加解密。与 Python `cryptography.fernet.Fernet` 完全兼容。
///
/// Token 结构：base64url( 0x80 || ts(8) || iv(16) || ct || hmac_sha256(32) )
///   - signing_key = key[0:16]，HMAC 用
///   - encryption_key = key[16:32]，AES-128-CBC 用
///
/// 派生 32 字节密钥（与旧 Python 代码一致）：
///   sha256(master_password_utf8).digest()
class FernetCrypto {
  static const int _version = 0x80;
  static final _rng = Random.secure();

  /// 与旧 Python `generate_key` 等价的派生函数。
  /// Python 那边外层 base64url 是为了喂给 Fernet API；内部真正用的就是这 32 字节。
  static Uint8List deriveKey(String masterPassword) {
    final digest = sha256.convert(utf8.encode(masterPassword)).bytes;
    return Uint8List.fromList(digest);
  }

  static String encrypt(String plaintext, Uint8List key) {
    _checkKey(key);
    final iv = _randomBytes(16);
    final ts = _timestampBytes(DateTime.now());
    return _encryptInternal(plaintext, key, iv, ts);
  }

  /// 测试用：固定 IV 与时间戳以验证与 Python 输出比特一致。
  static String encryptWith(
    String plaintext,
    Uint8List key, {
    required Uint8List iv,
    required DateTime time,
  }) {
    _checkKey(key);
    if (iv.length != 16) {
      throw ArgumentError('IV 必须是 16 字节');
    }
    return _encryptInternal(plaintext, key, iv, _timestampBytes(time));
  }

  static String decrypt(String token, Uint8List key) {
    _checkKey(key);
    Uint8List data;
    try {
      data = base64Url.decode(_padBase64(token));
    } on FormatException {
      throw FernetException('token 不是合法 base64url');
    }
    if (data.length < 1 + 8 + 16 + 16 + 32) {
      throw FernetException('token 长度不合法');
    }
    if (data[0] != _version) {
      throw FernetException('未知的 Fernet 版本: 0x${data[0].toRadixString(16)}');
    }

    final mac = data.sublist(data.length - 32);
    final body = data.sublist(0, data.length - 32);

    final signingKey = key.sublist(0, 16);
    final expectedMac = Hmac(sha256, signingKey).convert(body).bytes;
    if (!_constantTimeEquals(mac, expectedMac)) {
      throw FernetException('HMAC 校验失败（主密钥错误或数据被篡改）');
    }

    final iv = data.sublist(9, 25);
    final ciphertext = data.sublist(25, data.length - 32);
    final encryptionKey = key.sublist(16, 32);

    final plaintext = _aesCbcPkcs7(
      encryptionKey,
      iv,
      Uint8List.fromList(ciphertext),
      forEncryption: false,
    );
    try {
      return utf8.decode(plaintext);
    } on FormatException {
      throw FernetException('解密后不是合法 UTF-8');
    }
  }

  static String _encryptInternal(
    String plaintext,
    Uint8List key,
    Uint8List iv,
    Uint8List tsBytes,
  ) {
    final signingKey = key.sublist(0, 16);
    final encryptionKey = key.sublist(16, 32);

    final ciphertext = _aesCbcPkcs7(
      encryptionKey,
      iv,
      Uint8List.fromList(utf8.encode(plaintext)),
      forEncryption: true,
    );

    final hmacInput = BytesBuilder()
      ..addByte(_version)
      ..add(tsBytes)
      ..add(iv)
      ..add(ciphertext);
    final body = hmacInput.toBytes();
    final mac = Hmac(sha256, signingKey).convert(body).bytes;

    final token = Uint8List(body.length + mac.length)
      ..setRange(0, body.length, body)
      ..setRange(body.length, body.length + mac.length, mac);
    return base64Url.encode(token);
  }

  /// AES-128-CBC + PKCS7。手工 padding + 按块处理，绕开 pointycastle
  /// `PaddedBlockCipherImpl` 在某些版本上加密路径输出 buffer 算错的问题。
  static Uint8List _aesCbcPkcs7(
    Uint8List key,
    Uint8List iv,
    Uint8List data, {
    required bool forEncryption,
  }) {
    const blockSize = 16;
    final cipher = CBCBlockCipher(AESEngine())
      ..init(
        forEncryption,
        ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
      );

    if (forEncryption) {
      // PKCS7：永远要补 1~blockSize 字节，使总长是 blockSize 的整数倍
      final padLen = blockSize - (data.length % blockSize);
      final padded = Uint8List(data.length + padLen)
        ..setRange(0, data.length, data);
      for (var i = data.length; i < padded.length; i++) {
        padded[i] = padLen;
      }
      final out = Uint8List(padded.length);
      for (var offset = 0; offset < padded.length; offset += blockSize) {
        cipher.processBlock(padded, offset, out, offset);
      }
      return out;
    } else {
      if (data.length == 0 || data.length % blockSize != 0) {
        throw const FernetException('密文长度不是 16 的整数倍');
      }
      final out = Uint8List(data.length);
      for (var offset = 0; offset < data.length; offset += blockSize) {
        cipher.processBlock(data, offset, out, offset);
      }
      final padLen = out[out.length - 1];
      if (padLen < 1 || padLen > blockSize) {
        throw const FernetException('PKCS7 padding 不合法');
      }
      // 校验所有 padding 字节都等于 padLen（防止解密产物乱构）
      for (var i = out.length - padLen; i < out.length; i++) {
        if (out[i] != padLen) {
          throw const FernetException('PKCS7 padding 校验失败');
        }
      }
      return out.sublist(0, out.length - padLen);
    }
  }

  static Uint8List _timestampBytes(DateTime t) {
    final secs = t.toUtc().millisecondsSinceEpoch ~/ 1000;
    final out = Uint8List(8);
    ByteData.view(out.buffer).setUint64(0, secs, Endian.big);
    return out;
  }

  static Uint8List _randomBytes(int n) {
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  static void _checkKey(Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError('Fernet 密钥必须是 32 字节，得到 ${key.length}');
    }
  }

  static String _padBase64(String s) {
    final pad = (4 - s.length % 4) % 4;
    return s + ('=' * pad);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class FernetException implements Exception {
  final String message;
  const FernetException(this.message);
  @override
  String toString() => 'FernetException: $message';
}
