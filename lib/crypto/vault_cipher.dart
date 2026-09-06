import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 会话级加解密器。
///
/// **两层密钥（v2）**：
/// ```
/// 库密钥(32 字节随机，一库一把，永不变) --AES-GCM--> 每条记录的密文
/// 主密钥 --PBKDF2(盐)--> 包裹密钥 --AES-GCM--> 库密钥   ← 这一小块叫 keyring
/// ```
/// 记录只认库密钥，所以记录里**不带盐、也不跑 PBKDF2**；库密钥是满熵随机数，
/// 没有"预计算彩虹表"这回事，盐对它没有意义。整库一辈子只有 keyring 那一个盐，
/// 解锁 = 拆 keyring = **恒定 1 次 PBKDF2**，跟库里有多少条、用了多少年无关。
///
/// 换主密钥因此是 O(1)：拿新主密钥把**同一把库密钥**重新包一遍，记录一条不动。
///
/// **v1（老格式，只读）**：每条密文自带盐，密钥 = PBKDF2(主密钥, 该条的盐)。
/// 老版本每个会话都随机生成写盐，于是"用一阵子就攒出十几二十个盐"，解锁要按
/// 盐数跑 N 次 PBKDF2——Windows 上卡十几秒进不去就是这么来的。v1 密文永远解得开，
/// 迁移时逐条转成 v2；转不动的（主密钥不对）原样留着，不丢数据。
///
/// Token 自描述，便于离线迁移脚本产出与本类完全一致的格式：
///   v1 记录 base64url( 0x01 || kdfId(1) || iter(4,BE) || saltLen(1) || salt || nonce(12) || ct+tag(16) )
///   v2 记录 base64url( 0x02 || nonce(12) || ct+tag(16) )
///   keyring base64url( 0x11 || kdfId(1) || iter(4,BE) || saltLen(1) || salt || nonce(12) || wrapped+tag(48) )
class VaultCipher {
  /// [vaultKey] 为 null 表示这个库还没迁移到 v2（多设备时要等同步对齐才敢建
  /// keyring，见 AppState），这期间读写都退回 v1，用 [legacyWriteSalt] 派生写密钥。
  VaultCipher(
    this._password, {
    Uint8List? vaultKey,
    List<Uint8List> alsoDecryptWith = const [],
    Uint8List? legacyWriteSalt,
  })  : _vaultKeys = [if (vaultKey != null) vaultKey, ...alsoDecryptWith],
        _legacyWriteSalt = legacyWriteSalt ?? _randomBytes(_saltLen);

  final String _password;

  /// 这把主密钥能打开的全部库密钥；空 = 还在 v1 模式。
  ///
  /// 通常只有一把。会有多把是因为：两台设备各自离线迁移过同一个老库，各建了
  /// 一把 keyring，记录按 ts 分散到了两把库密钥下——但两把 keyring 都是同一个
  /// 主密钥包的，所以这里全收下，读的时候挨个试（AES 是微秒级，试几把无所谓），
  /// 写的时候统一用第一把。于是这种"脑裂"对用户完全不可见。
  final List<Uint8List> _vaultKeys;

  /// v1 模式下所有写入使用的盐。
  final Uint8List _legacyWriteSalt;

  bool get hasVaultKey => _vaultKeys.isNotEmpty;

  /// 写入用的库密钥。还在 v1 模式时为 null。
  Uint8List? get vaultKey => _vaultKeys.isEmpty ? null : _vaultKeys.first;

  /// 这把主密钥能打开的全部库密钥（换主密钥时要把它们逐把重新包一遍，
  /// 否则换完之后另一把下面的记录就没人认领了）。
  List<Uint8List> get vaultKeys => List.unmodifiable(_vaultKeys);

  /// v1 模式下的写盐（调用方用它判断某条 v1 密文是否已是"当前会话格式"）。
  Uint8List get legacyWriteSalt => _legacyWriteSalt;

  static const int _v1 = 0x01;
  static const int _v2 = 0x02;
  static const int _keyringTag = 0x11;
  static const int _kdfPbkdf2Sha256 = 1;
  static const int _iterations = 100000;

  /// 新写入使用的 PBKDF2 迭代次数（调用方挑复用盐时要按它过滤）。
  static int get defaultIterations => _iterations;
  static const int _saltLen = 16;
  static const int _nonceLen = 12;
  static const int _tagBits = 128;
  static const int _tagLen = 16;
  static const int _vaultKeyLen = 32;

  static final Random _rng = Random.secure();

  /// 已派生的 v1 密钥缓存：'<saltBase64>|<iter>' → 32 字节密钥。
  final Map<String, Uint8List> _keyCache = {};

  /// 正在后台派生中的密钥：cacheKey → 完成时缓存已写好的 Future。
  /// 用来给并发的 [warmUp] 去重——否则连点几下就会 spawn 好几个 isolate
  /// 重复算同一把密钥，在手机上直接把 CPU 打满。
  final Map<String, Future<void>> _inflight = {};

  /// 仅用于测试/诊断：当前 isolate（UI 线程）上真正跑过的 PBKDF2 次数。
  /// 用户手势路径应恒为 0，一旦增长就说明又有同步派生堵住了主线程。
  static int debugMainIsolatePbkdf2Count = 0;

  // ==================== 库密钥 / keyring ====================

  /// 生成一把新的库密钥（迁移时一库只生成一次）。
  static Uint8List newVaultKey() => _randomBytes(_vaultKeyLen);

  /// 用主密钥把库密钥包起来，产出可直接存进日志的 keyring 串。
  /// **会跑一次 PBKDF2**，UI 路径请用 [wrapVaultKeyAsync]。
  static String wrapVaultKey(
    String password,
    Uint8List vaultKey, {
    Uint8List? salt,
    int iterations = _iterations,
  }) {
    final s = salt ?? _randomBytes(_saltLen);
    debugMainIsolatePbkdf2Count++;
    final wrapKey = _pbkdf2(password, s, iterations);
    final nonce = _randomBytes(_nonceLen);
    final ct = _gcm(
      forEncryption: true,
      key: wrapKey,
      nonce: nonce,
      input: vaultKey,
    );
    final out = BytesBuilder()
      ..addByte(_keyringTag)
      ..addByte(_kdfPbkdf2Sha256)
      ..add(_u32be(iterations))
      ..addByte(s.length)
      ..add(s)
      ..add(nonce)
      ..add(ct);
    return base64Url.encode(out.toBytes());
  }

  /// 拆 keyring 取回库密钥；主密钥不对（GCM 认证标签校验失败）或数据坏 → null。
  ///
  /// 这就是新的主密钥校验：**精确判定，不用再拿"有没有一条记录解得开"去猜**。
  /// **会跑一次 PBKDF2**，UI 路径请用 [unwrapVaultKeyAsync]。
  static Uint8List? unwrapVaultKey(String password, String blob) {
    final Uint8List data;
    try {
      data = base64Url.decode(_padBase64(blob));
    } catch (_) {
      return null;
    }
    if (data.length < 1 + 1 + 4 + 1 + _saltLen + _nonceLen + _tagLen) {
      return null;
    }
    if (data[0] != _keyringTag) return null;
    var o = 1;
    if (data[o++] != _kdfPbkdf2Sha256) return null;
    final iterations = _readU32be(data, o);
    o += 4;
    final saltLen = data[o++];
    if (o + saltLen + _nonceLen + _tagLen > data.length) return null;
    final salt = Uint8List.fromList(data.sublist(o, o + saltLen));
    o += saltLen;
    final nonce = Uint8List.fromList(data.sublist(o, o + _nonceLen));
    o += _nonceLen;
    final ct = Uint8List.fromList(data.sublist(o));
    debugMainIsolatePbkdf2Count++;
    final wrapKey = _pbkdf2(password, salt, iterations);
    try {
      final key =
          _gcm(forEncryption: false, key: wrapKey, nonce: nonce, input: ct);
      return key.length == _vaultKeyLen ? key : null;
    } catch (_) {
      return null; // 标签校验失败 = 主密钥不对
    }
  }

  /// [wrapVaultKey] 的后台版：PBKDF2 在独立 isolate 里跑，UI 线程零阻塞。
  static Future<String> wrapVaultKeyAsync(
    String password,
    Uint8List vaultKey,
  ) =>
      Isolate.run(() => wrapVaultKey(password, vaultKey));

  /// [unwrapVaultKey] 的后台版：解锁走这条，转圈期间 UI 不掉帧。
  static Future<Uint8List?> unwrapVaultKeyAsync(
    String password,
    String blob,
  ) =>
      Isolate.run(() => unwrapVaultKey(password, blob));

  /// 一个库可以有多把 keyring（多个密钥空间）。在同一个后台 isolate 里逐把试拆，
  /// 返回这把主密钥能拆开的全部（下标 + 库密钥）；一把都拆不开返回空表。
  ///
  /// 一次 spawn 全部试完：拆一把 = 一次 PBKDF2（~0.25s），分开 spawn 的话每把都
  /// 要付一次 isolate 启动的钱。作用域里只有两个可发送的参数——闭包一旦捎上
  /// Future 之类的东西，Dart 会直接以 "object is unsendable" 抛错。
  static Future<List<({int index, Uint8List key})>> unwrapAllAsync(
    String password,
    List<String> blobs,
  ) =>
      Isolate.run(() => [
            for (var i = 0; i < blobs.length; i++)
              if (unwrapVaultKey(password, blobs[i]) case final k?)
                (index: i, key: k),
          ]);

  /// 用**自己的主密钥**把 [vaultKey] 包成 keyring（后台 isolate 跑 PBKDF2）。
  /// 主密钥不出这个对象。
  Future<String> wrapVaultKeyWithOwnPassword(Uint8List vaultKey) =>
      wrapVaultKeyAsync(_password, vaultKey);

  /// 同一个主密钥、换上库密钥的新会话 cipher（老库迁移到 v2 时用）。
  VaultCipher upgraded(Uint8List vaultKey) =>
      VaultCipher(_password, vaultKey: vaultKey, alsoDecryptWith: _vaultKeys);

  /// 是不是一条 keyring 串。
  static bool isKeyring(String blob) {
    try {
      final d = base64Url.decode(_padBase64(blob));
      return d.isNotEmpty && d[0] == _keyringTag;
    } catch (_) {
      return false;
    }
  }

  /// 这条密文是不是还停在 v1（需要迁移到库密钥）。
  static bool isLegacyToken(String token) {
    try {
      final d = base64Url.decode(_padBase64(token));
      return d.isNotEmpty && d[0] == _v1;
    } catch (_) {
      return false;
    }
  }

  // ==================== v1 密钥预热（只在迁移期间用） ====================

  static String _cacheKeyFor(Uint8List salt, int iterations) =>
      '${base64Url.encode(salt)}|$iterations';

  Uint8List _deriveLegacyKey(Uint8List salt, int iterations) {
    final cacheKey = _cacheKeyFor(salt, iterations);
    final cached = _keyCache[cacheKey];
    if (cached != null) return cached;
    debugMainIsolatePbkdf2Count++;
    return _keyCache[cacheKey] = _pbkdf2(_password, salt, iterations);
  }

  /// 纯函数版 PBKDF2（无实例状态），供实例方法与后台 isolate 共用。
  static Uint8List _pbkdf2(String password, Uint8List salt, int iterations) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));
    return kdf.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// 后台预热：在独立 isolate 里把 [params] 里各不同盐对应的 v1 密钥派生好，
  /// 使随后的 [decrypt] 直接命中缓存、不再阻塞 UI 线程。
  Future<void> warmUp(Iterable<({Uint8List salt, int iterations})> params) async {
    final waits = <Future<void>>[];
    final pending = <({Uint8List salt, int iterations, String cacheKey})>[];
    final seen = <String>{};
    for (final p in params) {
      final ck = _cacheKeyFor(p.salt, p.iterations);
      if (_keyCache.containsKey(ck) || !seen.add(ck)) continue;
      final running = _inflight[ck];
      if (running != null) {
        // 同一把密钥已在别处派生中，等它就行，别再开一个 isolate。
        waits.add(running);
        continue;
      }
      pending.add((salt: p.salt, iterations: p.iterations, cacheKey: ck));
    }

    if (pending.isNotEmpty) {
      final batch = _deriveInIsolate(
        _password,
        [for (final p in pending) (salt: p.salt, iterations: p.iterations)],
      ).then((derived) {
        for (var i = 0; i < pending.length; i++) {
          _keyCache[pending[i].cacheKey] = derived[i];
        }
      }).whenComplete(() {
        for (final p in pending) {
          _inflight.remove(p.cacheKey);
        }
      });
      // 先登记再等待：期间到来的同盐请求会命中 _inflight。
      for (final p in pending) {
        _inflight[p.cacheKey] = batch;
      }
      waits.add(batch);
    }

    if (waits.isEmpty) return;
    await Future.wait(waits);
  }

  /// 后台 isolate 里批量跑 PBKDF2。
  ///
  /// **必须单独开一个方法**：`Isolate.run` 的闭包会把所在作用域的捕获变量整包
  /// 送过去，如果和 `waits` / `_inflight` 里的 Future 共用作用域，Dart 会以
  /// "object is unsendable - _Future" 抛错——于是预热静默失败，解密退回 UI 线程
  /// 同步派生，正好把我们想根治的卡死又放回来。这里的作用域只有两个可发送的
  /// 参数，不会再踩到。
  static Future<List<Uint8List>> _deriveInIsolate(
    String password,
    List<({Uint8List salt, int iterations})> jobs,
  ) =>
      Isolate.run(
        () => [for (final j in jobs) _pbkdf2(password, j.salt, j.iterations)],
      );

  /// 为一批 v1 密文预热密钥：解析出各自的盐，去重后一次性在后台派生好。
  /// v2 密文不需要预热（库密钥现成的），会被跳过。
  Future<void> warmUpForTokens(Iterable<String?> tokens) {
    final params = <({Uint8List salt, int iterations})>[];
    for (final t in tokens) {
      if (t == null || t.isEmpty) continue;
      final p = tokenParams(t);
      if (p != null) params.add(p);
    }
    if (params.isEmpty) return Future<void>.value();
    return warmUp(params);
  }

  /// 解这条密文要用的密钥是否已就绪（解它不会触发 PBKDF2）。
  /// v2 密文恒为 true——库密钥不需要派生。
  bool isKeyWarm(String token) {
    if (!isLegacyToken(token)) return hasVaultKey;
    final p = tokenParams(token);
    if (p == null) return false;
    return _keyCache.containsKey(_cacheKeyFor(p.salt, p.iterations));
  }

  /// 该 v1 密文是否已经用本会话的写盐 + 当前迭代次数加密。
  bool usesLegacyWriteParams(String token) {
    final p = tokenParams(token);
    if (p == null || p.iterations != _iterations) return false;
    if (p.salt.length != _legacyWriteSalt.length) return false;
    for (var i = 0; i < p.salt.length; i++) {
      if (p.salt[i] != _legacyWriteSalt[i]) return false;
    }
    return true;
  }

  /// 与 [decrypt] 相同，但 v1 密文的密钥未缓存时先在后台 isolate 派生，
  /// UI 线程零 PBKDF2。
  Future<String> decryptAsync(String token) async {
    final params = tokenParams(token);
    if (params != null &&
        !_keyCache.containsKey(_cacheKeyFor(params.salt, params.iterations))) {
      try {
        await warmUp([params]);
      } catch (_) {
        // 后台派生失败（isolate 起不来等）不该让解密失败，退回同步派生。
      }
    }
    return decrypt(token);
  }

  /// 从 **v1** token 里解析出（盐, 迭代次数）。v2 / keyring / 坏数据返回 null。
  static ({Uint8List salt, int iterations})? tokenParams(String token) {
    try {
      final data = base64Url.decode(_padBase64(token));
      if (data.length < 1 + 1 + 4 + 1 + _saltLen + _nonceLen + _tagLen) {
        return null;
      }
      if (data[0] != _v1) return null;
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

  // ==================== 记录加解密 ====================

  /// 加密明文。有库密钥就写 v2（不带盐、零 PBKDF2）；还没迁移则退回 v1。
  String encrypt(String plaintext) {
    final input = Uint8List.fromList(utf8.encode(plaintext));
    final nonce = _randomBytes(_nonceLen);
    final vk = vaultKey;
    if (vk != null) {
      final ct = _gcm(
        forEncryption: true,
        key: vk,
        nonce: nonce,
        input: input,
      );
      final out = BytesBuilder()
        ..addByte(_v2)
        ..add(nonce)
        ..add(ct);
      return base64Url.encode(out.toBytes());
    }
    final key = _deriveLegacyKey(_legacyWriteSalt, _iterations);
    final ct = _gcm(forEncryption: true, key: key, nonce: nonce, input: input);
    final out = BytesBuilder()
      ..addByte(_v1)
      ..addByte(_kdfPbkdf2Sha256)
      ..add(_u32be(_iterations))
      ..addByte(_legacyWriteSalt.length)
      ..add(_legacyWriteSalt)
      ..add(nonce)
      ..add(ct);
    return base64Url.encode(out.toBytes());
  }

  /// 解密 token（v1 / v2 自动分辨）；主密钥错误或数据损坏抛 [CryptoException]。
  String decrypt(String token) {
    Uint8List data;
    try {
      data = base64Url.decode(_padBase64(token));
    } on FormatException {
      throw const CryptoException('token 不是合法 base64url');
    }
    if (data.isEmpty) {
      throw const CryptoException('token 为空');
    }
    return switch (data[0]) {
      _v2 => _decryptV2(data),
      _v1 => _decryptV1(data),
      final v => throw CryptoException('未知的 token 版本: 0x${v.toRadixString(16)}'),
    };
  }

  String _decryptV2(Uint8List data) {
    if (_vaultKeys.isEmpty) {
      // 库密钥还没拿到（老库尚未迁移就读到了新格式的记录，多半是别的设备
      // 迁移完同步过来的）：等 keyring 一并同步过来就能解开，别报"数据损坏"。
      throw const CryptoException('缺少库密钥，无法解密（keyring 尚未同步到本机）');
    }
    if (data.length < 1 + _nonceLen + _tagLen) {
      throw const CryptoException('token 长度不合法');
    }
    final nonce = Uint8List.fromList(data.sublist(1, 1 + _nonceLen));
    final ct = Uint8List.fromList(data.sublist(1 + _nonceLen));
    // 多把库密钥时挨个试：不是本空间的记录会在这里全部失败，抛
    // CryptoException——这正是"别的主密钥存的条目解不开"的正常路径。
    for (final k in _vaultKeys) {
      try {
        return _finish(key: k, nonce: nonce, ct: ct);
      } on CryptoException {
        continue;
      }
    }
    throw const CryptoException('解密失败（主密钥错误或数据损坏）');
  }

  String _decryptV1(Uint8List data) {
    if (data.length < 1 + 1 + 4 + 1 + _saltLen + _nonceLen + _tagLen) {
      throw const CryptoException('token 长度不合法');
    }
    var o = 1;
    final kdfId = data[o++];
    if (kdfId != _kdfPbkdf2Sha256) {
      throw CryptoException('未知的 KDF: $kdfId');
    }
    final iterations = _readU32be(data, o);
    o += 4;
    final saltLen = data[o++];
    if (o + saltLen + _nonceLen + _tagLen > data.length) {
      throw const CryptoException('token 字段越界');
    }
    final salt = Uint8List.fromList(data.sublist(o, o + saltLen));
    o += saltLen;
    final nonce = Uint8List.fromList(data.sublist(o, o + _nonceLen));
    o += _nonceLen;
    final ct = Uint8List.fromList(data.sublist(o));
    return _finish(key: _deriveLegacyKey(salt, iterations), nonce: nonce, ct: ct);
  }

  static String _finish({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List ct,
  }) {
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
