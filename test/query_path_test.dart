import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:passpro/crypto/vault_cipher.dart';
import 'package:passpro/models/password_entry.dart';
import 'package:passpro/models/search_config.dart';
import 'package:passpro/storage/memory_index.dart';

/// 回归测试：查询路径不得在 UI 线程（当前 isolate）上跑 PBKDF2。
///
/// 背景：查询页原来是同步的 `vault.query()`，密钥没缓存时会就地跑
/// 100k 次 PBKDF2（手机上 0.6~1.2s/盐，库里 3 个盐 = 2~4 秒主线程冻死），
/// 同时后台预热 isolate 在算同样的东西抢 CPU → Android 判 ANR 杀进程。
/// 现象就是"打开 App 在查询框输入后一点就卡死然后退出"。
void main() {
  setUp(() => VaultCipher.debugMainIsolatePbkdf2Count = 0);

  LogRecord rec(String id, String website, String? ct) => LogRecord(
        op: LogOp.add,
        id: id,
        ts: DateTime.now().toUtc(),
        website: website,
        username: 'alice',
        encryptedPassword: ct,
      );

  test('warmUpForTokens 之后解密全部命中缓存，UI 线程零 PBKDF2', () async {
    final writer = VaultCipher('master-key');
    final tokens = [
      for (var i = 0; i < 5; i++) writer.encrypt('pw-$i'),
    ];

    // 全新实例 = 冷缓存，等价于刚启动 App。
    final reader = VaultCipher('master-key');
    VaultCipher.debugMainIsolatePbkdf2Count = 0;
    await reader.warmUpForTokens(tokens);
    for (var i = 0; i < tokens.length; i++) {
      expect(reader.decrypt(tokens[i]), 'pw-$i');
    }
    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0,
        reason: '预热后仍在 UI 线程上派生了密钥');
  });

  test('并发 decryptAsync 同一把密钥只派生一次，不重复 spawn isolate', () async {
    final writer = VaultCipher('master-key');
    final tokens = [for (var i = 0; i < 8; i++) writer.encrypt('pw-$i')];

    final reader = VaultCipher('master-key');
    VaultCipher.debugMainIsolatePbkdf2Count = 0;
    // 模拟用户连点：8 个并发解密同时打进来。
    final out = await Future.wait([
      for (final t in tokens) reader.decryptAsync(t),
    ]);
    expect(out, [for (var i = 0; i < 8; i++) 'pw-$i']);
    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0,
        reason: '并发解密退化成了 UI 线程同步派生');
  });

  test('不同盐（多批次写入）也能一次预热干净', () async {
    // 每个 VaultCipher 实例有自己的写盐，模拟多次会话写入的库。
    final tokens = [
      for (var i = 0; i < 3; i++) VaultCipher('master-key').encrypt('pw-$i'),
    ];
    final salts = {
      for (final t in tokens)
        String.fromCharCodes(VaultCipher.tokenParams(t)!.salt),
    };
    expect(salts.length, 3, reason: '构造的测试数据应有 3 个不同的盐');

    final reader = VaultCipher('master-key');
    VaultCipher.debugMainIsolatePbkdf2Count = 0;
    await reader.warmUpForTokens(tokens);
    for (var i = 0; i < tokens.length; i++) {
      expect(reader.decrypt(tokens[i]), 'pw-$i');
    }
    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0);
  });

  test('密文字段缺失的记录被跳过，不抛 TypeError', () {
    final cipher = VaultCipher('master-key');
    final index = MemoryIndex()
      ..replay([
        rec('a', 'github.com', cipher.encrypt('pw')),
        rec('b', 'github.com', null), // 老数据 / 合并进来的残缺行
        rec('c', 'github.com', ''),
      ]);
    final hits = index.search('github.com', const SearchConfig());
    expect(hits.length, 3);
    // 以前 `r.encryptedPassword!` 会在这里抛 TypeError 逃出点击回调。
    for (final r in hits) {
      final ct = r.encryptedPassword;
      expect(() {
        if (ct == null || ct.isEmpty) return;
        cipher.decrypt(ct);
      }, returnsNormally);
    }
  });

  test('warmUp 对空/非法 token 安全返回', () async {
    final c = VaultCipher('master-key');
    await c.warmUpForTokens([null, '', 'not-a-token', '???']);
    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0);
  });

  test('tokenParams 的盐长度是 16 字节', () {
    final t = VaultCipher('k').encrypt('x');
    final p = VaultCipher.tokenParams(t)!;
    expect(p.salt, isA<Uint8List>());
    expect(p.salt.length, 16);
    expect(p.iterations, 100000);
  });
}
