import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:passpro/app_state.dart';
import 'package:passpro/crypto/vault_cipher.dart';
import 'package:passpro/models/password_entry.dart';
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

/// 两层密钥（keyring + 库密钥）的行为约束。
///
/// 老结构里主密钥**就是**记录的加密密钥：每条密文自带盐，一个会话一个盐，
/// 解锁要按盐数跑 N 次 PBKDF2（19 个盐 = Windows 上卡十几秒），换主密钥则要
/// 重写整库。新结构把记录交给一把随机库密钥，主密钥只用来包住它：
/// 解锁恒定 1 次 PBKDF2，换主密钥只重写 keyring 那一行。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  const masterKey = 'master-key';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('passpro_vaultkey_test_');
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

  /// 造一个老格式的库：主批次 5 条 + 另外两次"会话"各 1 条，共 3 个盐
  /// （复刻真实库里 95/1/1/… 的形状）。
  Future<VaultRepository> legacyVault() async {
    final vault = await VaultRepository.open();
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
        plaintextPassword: 'op$b',
        cipher: VaultCipher(masterKey),
      );
    }
    return vault;
  }

  List<String> ctsOf(VaultRepository v) => [
        for (final r in v.index.activeRecords)
          if (r.encryptedPassword case final ct?) ct,
      ];

  test('老库解锁后自动迁移：记录全部转成库密钥格式，明文一条不差', () async {
    final vault = await legacyVault();
    expect(ctsOf(vault).every(VaultCipher.isLegacyToken), isTrue);
    expect(vault.keyring, isNull);

    final app = await buildApp(vault);
    // 造数据时那几次 v1 加密是在主 isolate 上跑的，从这里开始才算解锁路径。
    VaultCipher.debugMainIsolatePbkdf2Count = 0;
    expect(await app.unlock(masterKey), isTrue);
    await app.pendingMaintenance;

    expect(vault.keyring, isNotNull, reason: '迁移后应该有 keyring');
    expect(VaultCipher.isKeyring(vault.keyring!), isTrue);
    expect(ctsOf(vault).any(VaultCipher.isLegacyToken), isFalse,
        reason: '还有记录停在老格式');
    expect(vault.index.activeCount, 7, reason: 'keyring 不能被当成密码条目');
    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0,
        reason: '解锁 + 迁移在 UI 线程上跑了 PBKDF2');

    final got = {
      for (final r in vault.index.activeRecords)
        r.website!: app.cipher.decrypt(r.encryptedPassword!),
    };
    expect(got, {
      for (var i = 0; i < 5; i++) 'main$i.com': 'p$i',
      for (var b = 0; b < 2; b++) 'other$b.com': 'op$b',
    });

    // 迁移前的原件留了一份，出岔子还能捞回来。
    expect(await File('${vault.store.path}.v1bak').exists(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('迁移之后解锁只拆 keyring：主密钥错直接判死，且不再随记录数变慢', () async {
    final vault = await legacyVault();
    final first = await buildApp(vault);
    expect(await first.unlock(masterKey), isTrue);
    await first.pendingMaintenance;

    // 再攒 20 条，模拟长期使用。老结构下这会不停长盐、解锁越来越慢。
    for (var i = 0; i < 20; i++) {
      await vault.add(
        website: 'later$i.com',
        username: 'a',
        plaintextPassword: 'lp$i',
        cipher: first.cipher,
      );
    }

    final again = await buildApp(vault);
    VaultCipher.debugMainIsolatePbkdf2Count = 0;
    expect(await again.unlock('not-the-master-key'), isFalse,
        reason: 'keyring 的 GCM 标签能精确判定密钥不对');
    expect(again.isUnlocked, isFalse);
    expect(await again.unlock(masterKey), isTrue);
    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0,
        reason: '拆 keyring 必须在后台 isolate 里跑');
    // 解密全部 27 条，一次 PBKDF2 都不该有——记录只认库密钥。
    for (final ct in ctsOf(vault)) {
      again.cipher.decrypt(ct);
    }
    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('换主密钥是 O(1)：记录密文一个字节都不动，只重写 keyring', () async {
    final vault = await legacyVault();
    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), isTrue);
    await app.pendingMaintenance;

    final before = {
      for (final r in vault.index.activeRecords) r.id: r.encryptedPassword,
    };
    final keyringBefore = vault.keyring;
    final linesBefore = (await vault.store.readAll()).length;

    const newKey = 'new-master-key';
    final result = await app.rekey(newKey);
    expect(result.ok, isTrue);
    expect(result.leftBehind, 0);

    final after = {
      for (final r in vault.index.activeRecords) r.id: r.encryptedPassword,
    };
    expect(after, before, reason: '换主密钥不该动任何一条记录的密文');
    expect(vault.keyring, isNot(keyringBefore), reason: 'keyring 应该换新的');
    expect((await vault.store.readAll()).length, linesBefore + 1,
        reason: '整个换密钥只该往日志里加 keyring 这一行');

    // 老密钥再也打不开，新密钥全都读得出。
    final old = await buildApp(vault);
    expect(await old.unlock(masterKey), isFalse);
    final next = await buildApp(vault);
    expect(await next.unlock(newKey), isTrue);
    expect(
      {
        for (final r in vault.index.activeRecords)
          r.website!: next.cipher.decrypt(r.encryptedPassword!),
      },
      {
        for (var i = 0; i < 5; i++) 'main$i.com': 'p$i',
        for (var b = 0; b < 2; b++) 'other$b.com': 'op$b',
      },
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('keyring 不会被当成密码条目：搜不到、导不出、压实之后还在', () async {
    final vault = await legacyVault();
    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), isTrue);
    await app.pendingMaintenance;

    expect(vault.index.get(kKeyringRecordId), isNull);
    expect(vault.exportCsv(app.cipher).count, 7);

    // 压实会整表重写，keyring 必须原样带过去——丢了整库就永远打不开。
    await Compactor(vault.store, vault.index).compact();
    expect(vault.keyring, isNotNull, reason: '压实把 keyring 弄丢了');
    expect(vault.index.activeCount, 7);

    final reopened = await VaultRepository.open();
    expect(reopened.keyring, isNotNull);
    final back = await buildApp(reopened);
    expect(await back.unlock(masterKey), isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('老版本把 keyring 当条目删掉的 DEL 行会被忽略', () async {
    final vault = await legacyVault();
    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), isTrue);
    await app.pendingMaintenance;
    final blob = vault.keyring;

    // 老版本不认识 keyring，会把它显示成一条空条目；用户手滑删掉的话，
    // 整库就再也打不开了。所以 keyring 上的 DEL 一律不认。
    final del = LogRecord(
      op: LogOp.delete,
      id: kKeyringRecordId,
      ts: DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    await vault.store.append(del);
    vault.index.apply(del);
    expect(vault.keyring, blob);

    final reopened = await VaultRepository.open();
    expect(reopened.keyring, blob, reason: '重新 replay 之后 keyring 也得还在');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('开了云同步、本次会话还没跟远端对齐时不迁移', () async {
    final vault = await legacyVault();
    final s = await AppSettings.load();
    await s.setCloudEnabled(true);

    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), isTrue);
    // 两台机器各自建一把库密钥、各自把记录转过去，合并之后只有一把 keyring
    // 活得下来，另一台转过的记录就全废了。所以必须先对齐再迁。
    expect(app.pendingMaintenance, isNull, reason: '没对齐远端就开始迁移了');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(vault.keyring, isNull, reason: '没对齐远端就建了 keyring');
    expect(ctsOf(vault).every(VaultCipher.isLegacyToken), isTrue);

    // 这期间照样能正常用（读写都退回老格式）。
    await vault.add(
      website: 'while-offline.com',
      username: 'a',
      plaintextPassword: 'x',
      cipher: app.cipher,
    );
    expect(
      app.cipher.decrypt(
        vault.index
            .activeRecords
            .firstWhere((r) => r.website == 'while-offline.com')
            .encryptedPassword!,
      ),
      'x',
    );

    // 换主密钥这时候要重写整库，会和别的设备撞车，所以先拦住。
    final r = await app.rekey('whatever');
    expect(r.ok, isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('迁移期间用户改的/删的记录不会被老快照盖回去', () async {
    final vault = await VaultRepository.open();
    final main = VaultCipher(masterKey);
    for (var i = 0; i < 3; i++) {
      await vault.add(
        website: 'main$i.com',
        username: 'a',
        plaintextPassword: 'p$i',
        cipher: main,
      );
    }
    // 三条各带各盐的老记录：迁移要重写它们，预热这三个盐要几百毫秒。
    for (var b = 0; b < 3; b++) {
      await vault.add(
        website: 'old$b.com',
        username: 'a',
        plaintextPassword: 'old-$b',
        cipher: VaultCipher(masterKey),
      );
    }
    LogRecord byName(String w) =>
        vault.index.activeRecords.firstWhere((r) => r.website == w);
    final edited = byName('old0.com').id;
    final doomed = byName('old1.com').id;

    final c = VaultCipher(masterKey, vaultKey: VaultCipher.newVaultKey());
    // 不 await：迁移卡在"后台预热三个老盐"的 await 上，正好模拟真实情况——
    // 用户已经进主界面了，迁移还在跑。
    final job = vault.migrateToVaultKey(c);
    await vault.update(
      id: edited,
      plaintextPassword: 'edited-during-migration',
      cipher: c,
    );
    await vault.deleteById(doomed);
    final report = await job;

    expect(vault.index.get(doomed), isNull, reason: '迁移把已删除的记录复活了');
    expect(c.decrypt(vault.index.get(edited)!.encryptedPassword!),
        'edited-during-migration',
        reason: '迁移把用户刚改的密码盖回了老值');
    expect(report.converted, greaterThanOrEqualTo(1));
    expect(VaultCipher.isLegacyToken(byName('old2.com').encryptedPassword!),
        isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('库里全是解不开的坏密文时仍然放行（别把人永久锁在门外）', () async {
    final vault = await VaultRepository.open();
    final broken = LogRecord(
      op: LogOp.add,
      id: 'broken-1',
      ts: DateTime.now().toUtc(),
      website: 'broken.com',
      username: 'a',
      encryptedPassword: 'this-is-not-a-passpro-token',
    );
    await vault.store.append(broken);
    vault.index.apply(broken);

    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('空库解锁不炸，之后写入的就是新格式', () async {
    final vault = await VaultRepository.open();
    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), isTrue);
    await app.pendingMaintenance;
    await vault.add(
      website: 'first.com',
      username: 'a',
      plaintextPassword: 'p',
      cipher: app.cipher,
    );
    expect(vault.keyring, isNotNull);
    expect(ctsOf(vault).any(VaultCipher.isLegacyToken), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
