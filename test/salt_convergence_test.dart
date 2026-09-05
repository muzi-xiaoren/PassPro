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

  test('解锁复用最主流的盐，反复写入不再增加盐', () async {
    final vault = await VaultRepository.open();

    // 造一个 3 盐库：主批次 5 条 + 另外两次会话各 1 条（复刻真实库 102/1/1）。
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

    // 连续三个"会话"：解锁 → 写一条。以前每轮都会多出一个新盐。
    for (var session = 0; session < 3; session++) {
      final app = await buildApp(vault);
      await app.unlock(masterKey);
      await vault.add(
        website: 'session$session.com',
        username: 'a',
        plaintextPassword: 'p',
        cipher: app.cipher,
      );
      expect(saltsOf(vault).length, 3,
          reason: '第 $session 轮写入引入了新盐，盐数会随使用无限增长');
      final added = vault.index.activeRecords
          .firstWhere((r) => r.website == 'session$session.com');
      expect(
        base64Url.encode(VaultCipher.tokenParams(added.encryptedPassword!)!.salt),
        mainSalt,
        reason: '新条目没有复用最主流的盐',
      );
    }

    // 收敛后再解锁，预热只需处理这 3 个盐，且 UI 线程零 PBKDF2。
    final app = await buildApp(vault);
    VaultCipher.debugMainIsolatePbkdf2Count = 0;
    await app.unlock(masterKey);
    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0);

    // 所有条目（含新旧盐）都仍解得开。
    for (final r in vault.index.activeRecords) {
      expect(() => app.cipher.decrypt(r.encryptedPassword!), returnsNormally);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('空库解锁不炸，随机生成写盐', () async {
    final vault = await VaultRepository.open();
    final app = await buildApp(vault);
    await app.unlock(masterKey);
    await vault.add(
      website: 'first.com',
      username: 'a',
      plaintextPassword: 'p',
      cipher: app.cipher,
    );
    expect(saltsOf(vault).length, 1);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
