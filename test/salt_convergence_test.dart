import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:passpro/app_state.dart';
import 'package:passpro/crypto/vault_cipher.dart';
import 'package:passpro/settings/app_settings.dart';
import 'package:passpro/settings/secure_credential_store.dart';
import 'package:passpro/storage/compactor.dart';
import 'package:passpro/storage/vault_repository.dart';
import 'package:passpro/sync/sync_manager.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

/// 回归测试：库里的盐数量不能随使用次数无限增长。
///
/// 每个 VaultCipher 实例原来都随机生成写盐，于是"每有一次会话写入就多一个
/// 盐"，解锁预热要跑的 PBKDF2 次数（~0.2s/次，手机 0.6~1.2s）随使用时间
/// 线性增长。解锁时改为复用库里用得最多的盐，库会逐步收敛到单盐。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  const masterKey = 'master-key';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('passpro_salt_test_');
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    VaultCipher.debugMainIsolatePbkdf2Count = 0;
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Set<String> saltsOf(VaultRepository vault) => {
        for (final r in vault.index.activeRecords)
          if (r.encryptedPassword != null)
            if (VaultCipher.tokenParams(r.encryptedPassword!) case final p?)
              base64Url.encode(p.salt),
      };

  Future<AppState> buildApp(VaultRepository vault) async {
    final settings = await AppSettings.load();
    final credentials = SecureCredentialStore();
    return AppState(
      vault: vault,
      settings: settings,
      credentials: credentials,
      sync: SyncManager(
        settings: settings,
        credentials: credentials,
        logStore: vault.store,
        memoryIndex: vault.index,
      ),
      compactor: Compactor(vault.store, vault.index),
    );
  }

  test('解锁后把历史多盐收敛成单盐，之后反复写入也不再长盐', () async {
    final vault = await VaultRepository.open();

    // 造一个 3 盐库：主批次 5 条 + 另外两次会话各 1 条（复刻真实库 95/1/1…）。
    final main = VaultCipher(masterKey);
    for (var i = 0; i < 5; i++) {
      await vault.add(
        website: 'main$i.com',
        username: 'a',
        plaintextPassword: 'p$i',
        cipher: main,
      );
    }
    for (var b = 0; b < 2; b++) {
      await vault.add(
        website: 'other$b.com',
        username: 'a',
        plaintextPassword: 'p',
        cipher: VaultCipher(masterKey),
      );
    }
    expect(saltsOf(vault).length, 3, reason: '测试数据应有 3 个盐');
    final mainSalt = base64Url.encode(
      VaultCipher.tokenParams(vault.index.activeRecords.first.encryptedPassword!)!.salt,
    );

    // 连续三个"会话"：解锁 → 等后台收敛 → 写一条。
    // 老版本每轮都会多出一个新盐，解锁预热就得按盐数跑 N 次 PBKDF2
    //（Windows 上 19 个盐 = 卡十几秒才进得去）。
    for (var session = 0; session < 3; session++) {
      final app = await buildApp(vault);
      VaultCipher.debugMainIsolatePbkdf2Count = 0;
      expect(await app.unlock(masterKey), isTrue);
      await app.pendingMaintenance;
      expect(saltsOf(vault).length, 1,
          reason: '第 $session 轮解锁后没收敛成单盐');
      expect(saltsOf(vault).single, mainSalt, reason: '收敛到的不是最主流的盐');
      expect(VaultCipher.debugMainIsolatePbkdf2Count, 0,
          reason: '解锁 + 收敛在 UI 线程上跑了 PBKDF2');

      await vault.add(
        website: 'session$session.com',
        username: 'a',
        plaintextPassword: 'p',
        cipher: app.cipher,
      );
      expect(saltsOf(vault).length, 1,
          reason: '第 $session 轮写入引入了新盐，盐数会随使用无限增长');
    }

    // 收敛之后再解锁：只剩一个盐，预热一次 PBKDF2 就够，UI 线程仍然是零。
    final app = await buildApp(vault);
    VaultCipher.debugMainIsolatePbkdf2Count = 0;
    expect(await app.unlock(masterKey), isTrue);
    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0);

    // 所有条目都仍解得开，收敛没弄丢任何数据。
    for (final r in vault.index.activeRecords) {
      expect(() => app.cipher.decrypt(r.encryptedPassword!), returnsNormally);
    }
    expect(vault.index.activeCount, 5 + 2 + 3);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('主密钥错误时解锁被拒，正确密钥才放行', () async {
    final vault = await VaultRepository.open();
    final seed = VaultCipher(masterKey);
    for (var i = 0; i < 3; i++) {
      await vault.add(
        website: 'site$i.com',
        username: 'a',
        plaintextPassword: 'p$i',
        cipher: seed,
      );
    }

    final wrong = await buildApp(vault);
    // 老版本这里无条件放行：拿错密钥照样进主界面，看得到一列条目，
    // 直到点开某条才发现解不出来。
    expect(await wrong.unlock('not-the-master-key'), isFalse);
    expect(wrong.isUnlocked, isFalse);

    final right = await buildApp(vault);
    expect(await right.unlock(masterKey), isTrue);
    expect(right.isUnlocked, isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('空库时任何主密钥都能解锁（没有可校验的密文）', () async {
    final vault = await VaultRepository.open();
    final app = await buildApp(vault);
    expect(await app.unlock('whatever'), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('更换主密钥会用新密钥重加密整库，老密钥不再能解锁', () async {
    final vault = await VaultRepository.open();
    final seed = VaultCipher(masterKey);
    for (var i = 0; i < 4; i++) {
      await vault.add(
        website: 'site$i.com',
        username: 'a',
        plaintextPassword: 'pw-$i',
        cipher: seed,
      );
    }

    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), isTrue);
    await app.pendingMaintenance;

    const newKey = 'new-master-key';
    VaultCipher.debugMainIsolatePbkdf2Count = 0;
    final report = await app.rekey(newKey);
    expect(report.converted, 4);
    expect(report.skipped, 0);
    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0,
        reason: '整库重加密在 UI 线程上跑了 PBKDF2');
    expect(saltsOf(vault).length, 1, reason: '换密钥后应统一到新盐');

    // 换完之后库里只有新密钥一把：老密钥全解不开，新密钥全解得开。
    // 老版本换密钥只换会话密钥、不动已有密文，于是同一个库里混着两把钥匙。
    for (final r in vault.index.activeRecords) {
      expect(() => app.cipher.decrypt(r.encryptedPassword!), returnsNormally);
    }
    final old = await buildApp(vault);
    expect(await old.unlock(masterKey), isFalse);
    final next = await buildApp(vault);
    expect(await next.unlock(newKey), isTrue);
    expect(
      {
        for (final r in vault.index.activeRecords)
          r.website: next.cipher.decrypt(r.encryptedPassword!),
      },
      {for (var i = 0; i < 4; i++) 'site$i.com': 'pw-$i'},
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('空库解锁不炸，随机生成写盐', () async {
    final vault = await VaultRepository.open();
    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), isTrue);
    await vault.add(
      website: 'first.com',
      username: 'a',
      plaintextPassword: 'p',
      cipher: app.cipher,
    );
    expect(saltsOf(vault).length, 1);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
