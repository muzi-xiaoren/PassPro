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
    expect(vault.keyrings, isEmpty);

    final app = await buildApp(vault);
    // 造数据时那几次 v1 加密是在主 isolate 上跑的，从这里开始才算解锁路径。
    VaultCipher.debugMainIsolatePbkdf2Count = 0;
    expect(await app.unlock(masterKey), UnlockOutcome.ok);
    await app.pendingMaintenance;

    expect(vault.keyrings, isNotEmpty, reason: '迁移后应该有 keyring');
    expect(VaultCipher.isKeyring(vault.keyrings.values.single), isTrue);
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
    expect(await first.unlock(masterKey), UnlockOutcome.ok);
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
    expect(await again.unlock('not-the-master-key'), UnlockOutcome.unknownKey,
        reason: 'keyring 的 GCM 标签能精确判定这把密钥打不开任何东西');
    expect(again.isUnlocked, isFalse);
    expect(await again.unlock(masterKey), UnlockOutcome.ok);
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
    expect(await app.unlock(masterKey), UnlockOutcome.ok);
    await app.pendingMaintenance;

    final before = {
      for (final r in vault.index.activeRecords) r.id: r.encryptedPassword,
    };
    final keyringBefore = vault.keyrings.values.single;
    final linesBefore = (await vault.store.readAll()).length;

    const newKey = 'new-master-key';
    final result = await app.rekey(newKey);
    expect(result.ok, isTrue);
    expect(result.leftBehind, 0);

    final after = {
      for (final r in vault.index.activeRecords) r.id: r.encryptedPassword,
    };
    expect(after, before, reason: '换主密钥不该动任何一条记录的密文');
    expect(vault.keyrings.values.single, isNot(keyringBefore),
        reason: 'keyring 应该换新的');
    expect((await vault.store.readAll()).length, linesBefore + 1,
        reason: '整个换密钥只该往日志里加 keyring 这一行');

    // 老密钥再也打不开，新密钥全都读得出。
    final old = await buildApp(vault);
    expect(await old.unlock(masterKey), UnlockOutcome.unknownKey);
    final next = await buildApp(vault);
    expect(await next.unlock(newKey), UnlockOutcome.ok);
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
    expect(await app.unlock(masterKey), UnlockOutcome.ok);
    await app.pendingMaintenance;

    expect(vault.index.get(kKeyringRecordId), isNull);
    expect(vault.exportCsv(app.cipher).count, 7);

    // 压实会整表重写，keyring 必须原样带过去——丢了整库就永远打不开。
    await Compactor(vault.store, vault.index).compact();
    expect(vault.keyrings, isNotEmpty, reason: '压实把 keyring 弄丢了');
    expect(vault.index.activeCount, 7);

    final reopened = await VaultRepository.open();
    expect(reopened.keyrings, isNotEmpty);
    final back = await buildApp(reopened);
    expect(await back.unlock(masterKey), UnlockOutcome.ok);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('老版本把 keyring 当条目删掉的 DEL 行会被忽略', () async {
    final vault = await legacyVault();
    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), UnlockOutcome.ok);
    await app.pendingMaintenance;
    final blob = vault.keyrings.values.single;

    // 老版本不认识 keyring，会把它显示成一条空条目；用户手滑删掉的话，
    // 整库就再也打不开了。所以 keyring 上的 DEL 一律不认。
    final del = LogRecord(
      op: LogOp.delete,
      id: kKeyringRecordId,
      ts: DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    await vault.store.append(del);
    vault.index.apply(del);
    expect(vault.keyrings.values.single, blob);

    final reopened = await VaultRepository.open();
    expect(reopened.keyrings.values.single, blob,
        reason: '重新 replay 之后 keyring 也得还在');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('开了云同步、本次会话还没跟远端对齐时不迁移', () async {
    final vault = await legacyVault();
    final s = await AppSettings.load();
    await s.setCloudEnabled(true);

    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), UnlockOutcome.ok);
    // 两台机器各自建一把库密钥、各自把记录转过去，合并之后只有一把 keyring
    // 活得下来，另一台转过的记录就全废了。所以必须先对齐再迁。
    expect(app.pendingMaintenance, isNull, reason: '没对齐远端就开始迁移了');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(vault.keyrings, isEmpty, reason: '没对齐远端就建了 keyring');
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

  test('库里全是解不开的坏密文时不放行，但可以新开空间进去', () async {
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

    // 一条都解不开 → 不放行，但可以用这把密钥新开一个空间进去（导入导出都还能点）。
    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), UnlockOutcome.unknownKey);
    expect(app.isUnlocked, isFalse);
    await app.createKeySpace(masterKey);
    expect(app.isUnlocked, isTrue);
    expect(vault.keyrings, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('一个库装多个密钥空间：各存各的，互相解不开，条目仍然都列出来', () async {
    final vault = await VaultRepository.open();
    final app = await buildApp(vault);
    expect(await app.unlock('key-A'), UnlockOutcome.ok); // 空库首次：直接开空间
    for (var i = 0; i < 3; i++) {
      await vault.add(
        website: 'a$i.com',
        username: 'ua',
        plaintextPassword: 'pa-$i',
        cipher: app.cipher,
      );
    }

    // 换一把库里不认识的密钥：不放行，得先确认要新建（UI 会弹窗问）。
    expect(await app.unlock('key-B'), UnlockOutcome.unknownKey);
    await app.createKeySpace('key-B');
    for (var i = 0; i < 2; i++) {
      await vault.add(
        website: 'b$i.com',
        username: 'ub',
        plaintextPassword: 'pb-$i',
        cipher: app.cipher,
      );
    }
    expect(vault.keyrings.length, 2, reason: '两个空间应各有一把 keyring');

    // 条目是全都列出来的（网站/账号本来就是明文），只是别人的解不开。
    expect(vault.index.activeCount, 5);
    String? tryDecrypt(String w) {
      final r = vault.index.activeRecords.firstWhere((r) => r.website == w);
      try {
        return app.cipher.decrypt(r.encryptedPassword!);
      } on CryptoException {
        return null;
      }
    }
    expect(tryDecrypt('b0.com'), 'pb-0');
    expect(tryDecrypt('a0.com'), isNull, reason: 'B 不该解得开 A 存的');

    // 切回 A：自己的解得开，B 的解不开。
    expect(await app.unlock('key-A'), UnlockOutcome.ok);
    expect(tryDecrypt('a2.com'), 'pa-2');
    expect(tryDecrypt('b1.com'), isNull);

    // 重开 app 也一样。
    final reopened = await VaultRepository.open();
    final again = await buildApp(reopened);
    expect(await again.unlock('key-B'), UnlockOutcome.ok);
    expect(
      again.cipher.decrypt(reopened.index.activeRecords
          .firstWhere((r) => r.website == 'b1.com')
          .encryptedPassword!),
      'pb-1',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('输错一个字不会悄悄开出一个新空间', () async {
    final vault = await legacyVault();
    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), UnlockOutcome.ok);
    await app.pendingMaintenance;
    final before = vault.keyrings.length;

    // 老版本这里无条件放行：手滑一个字就进了空空间，之后存的东西全落在一把
    // 记不住的密钥下，还要等到某天点开某条才发现解不出来。
    expect(await app.unlock('master-ke'), UnlockOutcome.unknownKey);
    expect(vault.keyrings.length, before, reason: '不该自作主张建空间');
    // 会话中途切换失败不该把人踢出去：还在原来的空间里，自己的条目照样解得开。
    expect(app.isUnlocked, isTrue);
    expect(
      app.cipher.decrypt(vault.index.activeRecords
          .firstWhere((r) => r.website == 'main0.com')
          .encryptedPassword!),
      'p0',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('更换主密钥只动当前空间，别的空间照旧', () async {
    final vault = await VaultRepository.open();
    final app = await buildApp(vault);
    expect(await app.unlock('key-A'), UnlockOutcome.ok);
    await vault.add(
      website: 'a.com',
      username: 'u',
      plaintextPassword: 'pa',
      cipher: app.cipher,
    );
    final keyringsOfA = Set.of(vault.keyrings.keys);
    await app.createKeySpace('key-B');
    final keyringB =
        vault.keyrings.keys.firstWhere((k) => !keyringsOfA.contains(k));
    await vault.add(
      website: 'b.com',
      username: 'u',
      plaintextPassword: 'pb',
      cipher: app.cipher,
    );

    final before = {
      for (final r in vault.index.activeRecords) r.id: r.encryptedPassword,
    };
    final keyringsBefore = Map.of(vault.keyrings);

    // 回到 A 改它的主密钥
    expect(await app.unlock('key-A'), UnlockOutcome.ok);
    final result = await app.rekey('key-A2');
    expect(result.ok, isTrue);

    expect(
      {for (final r in vault.index.activeRecords) r.id: r.encryptedPassword},
      before,
      reason: '换主密钥不该动任何一条记录的密文',
    );
    final changed = [
      for (final e in vault.keyrings.entries)
        if (keyringsBefore[e.key] != e.value) e.key,
    ];
    expect(changed.length, 1, reason: '只该有一把 keyring 被重写');
    expect(changed.single, isNot(keyringB), reason: '动到了 B 的 keyring');

    // A 的新密钥进 A，B 的老密钥照常进 B，各自解得开自己的。
    final asA = await buildApp(vault);
    expect(await asA.unlock('key-A2'), UnlockOutcome.ok);
    expect(
      asA.cipher.decrypt(vault.index.activeRecords
          .firstWhere((r) => r.website == 'a.com')
          .encryptedPassword!),
      'pa',
    );
    final asB = await buildApp(vault);
    expect(await asB.unlock('key-B'), UnlockOutcome.ok);
    expect(
      asB.cipher.decrypt(vault.index.activeRecords
          .firstWhere((r) => r.website == 'b.com')
          .encryptedPassword!),
      'pb',
    );
    // A 的老密钥不再能进 A
    final asOldA = await buildApp(vault);
    expect(await asOldA.unlock('key-A'), UnlockOutcome.unknownKey);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('同一把主密钥下有两把库密钥（两台设备各自迁移过）时，两批记录都解得开', () async {
    final vault = await VaultRepository.open();
    // 手工造"脑裂"：同一个主密钥包了两把不同的库密钥，记录分散在两把下面。
    final vk1 = VaultCipher.newVaultKey();
    final vk2 = VaultCipher.newVaultKey();
    await vault.writeKeyring(
        VaultRepository.newKeyringId(), VaultCipher.wrapVaultKey(masterKey, vk1));
    await vault.writeKeyring(
        VaultRepository.newKeyringId(), VaultCipher.wrapVaultKey(masterKey, vk2));
    await vault.add(
      website: 'one.com',
      username: 'u',
      plaintextPassword: 'p1',
      cipher: VaultCipher(masterKey, vaultKey: vk1),
    );
    await vault.add(
      website: 'two.com',
      username: 'u',
      plaintextPassword: 'p2',
      cipher: VaultCipher(masterKey, vaultKey: vk2),
    );

    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), UnlockOutcome.ok);
    // 解锁时把这把主密钥能拆开的 keyring 全收下，读的时候挨个试——脑裂对用户不可见。
    expect(
      {
        for (final r in vault.index.activeRecords)
          r.website!: app.cipher.decrypt(r.encryptedPassword!),
      },
      {'one.com': 'p1', 'two.com': 'p2'},
    );

    // 换主密钥要把两把 keyring 都重新包，否则另一把下面的记录就没人认领了。
    final result = await app.rekey('brand-new');
    expect(result.ok, isTrue);
    final after = await buildApp(vault);
    expect(await after.unlock('brand-new'), UnlockOutcome.ok);
    expect(
      {
        for (final r in vault.index.activeRecords)
          r.website!: after.cipher.decrypt(r.encryptedPassword!),
      },
      {'one.com': 'p1', 'two.com': 'p2'},
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('空库解锁不炸，之后写入的就是新格式', () async {
    final vault = await VaultRepository.open();
    final app = await buildApp(vault);
    expect(await app.unlock(masterKey), UnlockOutcome.ok);
    await app.pendingMaintenance;
    await vault.add(
      website: 'first.com',
      username: 'a',
      plaintextPassword: 'p',
      cipher: app.cipher,
    );
    expect(vault.keyrings, isNotEmpty);
    expect(ctsOf(vault).any(VaultCipher.isLegacyToken), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
