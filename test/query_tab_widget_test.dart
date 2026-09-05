import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:passpro/app_state.dart';
import 'package:passpro/crypto/vault_cipher.dart';
import 'package:passpro/l10n/app_localizations.dart';
import 'package:passpro/settings/app_settings.dart';
import 'package:passpro/settings/secure_credential_store.dart';
import 'package:passpro/storage/compactor.dart';
import 'package:passpro/storage/vault_repository.dart';
import 'package:passpro/sync/sync_manager.dart';
import 'package:passpro/ui/home_page.dart';

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

/// 回归测试：手机上"打开 App → 查询框输入 → 点击"会卡死然后被系统杀掉。
///
/// 根因是查询页的 `_doQuery()` 同步调 `vault.query()`，密钥没缓存时就地跑
/// 100k 次 PBKDF2（手机 0.6~1.2s/盐 × 3 个盐），同时后台预热 isolate 在算
/// 同一批东西抢 CPU，主线程几秒无响应 → Android ANR 杀进程。
/// 这里断言用户手势路径上 UI 线程的 PBKDF2 次数恒为 0。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('passpro_query_test_');
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

  const masterKey = 'master-key';

  Future<AppState> buildAppState() async {
    final settings = await AppSettings.load();
    final credentials = SecureCredentialStore();
    final vault = await VaultRepository.open();

    // 三个不同实例 = 三个不同的写盐，复刻真实库里"迁移批次 + 各次新增"
    // 造成的多盐状态（用户库实测就是 3 个盐）。
    for (var batch = 0; batch < 3; batch++) {
      final writer = VaultCipher(masterKey);
      for (var i = 0; i < 6; i++) {
        await vault.add(
          website: 'github$batch$i.com',
          username: 'alice',
          plaintextPassword: 'pw-$batch-$i',
          cipher: writer,
        );
      }
    }

    final sync = SyncManager(
      settings: settings,
      credentials: credentials,
      logStore: vault.store,
      memoryIndex: vault.index,
    );
    return AppState(
      vault: vault,
      settings: settings,
      credentials: credentials,
      sync: sync,
      compactor: Compactor(vault.store, vault.index),
    );
  }

  Future<void> pumpHome(WidgetTester tester, AppState app) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider.value(value: app.settings),
          ChangeNotifierProvider.value(value: app.sync),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('查询框输入后点建议项：不抛异常、UI 线程零 PBKDF2、结果正常渲染',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final app = (await tester.runAsync(buildAppState))!;
    // 解锁现在会等预热完成（真实 App 里解锁页转圈等的就是这一步）。
    await tester.runAsync(() => app.unlock(masterKey));

    // 解锁后再"同步拉进来"一批新盐的记录：预热只覆盖解锁那一刻已有的盐，
    // 启动自动同步合并进来的新记录必然是冷的。网站名与已有记录不重叠，
    // 保证下面查到的命中项全是冷盐——老代码在这里就地跑 PBKDF2。
    await tester.runAsync(() async {
      final remote = VaultCipher(masterKey);
      for (var i = 0; i < 6; i++) {
        await app.vault.add(
          website: 'synced$i.com',
          username: 'bob',
          plaintextPassword: 'synced-$i',
          cipher: remote,
        );
      }
    });

    await pumpHome(tester, app);

    // 从这里开始就是"用户手势路径"，一次 PBKDF2 都不该落在 UI 线程上。
    VaultCipher.debugMainIsolatePbkdf2Count = 0;

    await tester.enterText(find.byType(TextField).first, 'synced2');
    await tester.pump(const Duration(milliseconds: 250)); // 越过 180ms 防抖
    expect(tester.takeException(), isNull);
    expect(find.text('synced2.com'), findsWidgets, reason: '补全建议没出来');

    await tester.tap(find.text('synced2.com').first, warnIfMissed: false);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull, reason: '点击后第 $i 帧抛异常');
    }

    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0,
        reason: '点击那一帧在 UI 线程上跑了 PBKDF2——手机上就是这里 ANR 被杀');
    expect(find.text('synced2.com'), findsWidgets, reason: '查询结果没渲染出来');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('查询结果默认打码，点👁才按需解密，UI 线程零 PBKDF2',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final app = (await tester.runAsync(buildAppState))!;
    await tester.runAsync(() => app.unlock(masterKey));
    await pumpHome(tester, app);
    VaultCipher.debugMainIsolatePbkdf2Count = 0;

    // 输入前缀后点补全项（直接输全名的话 find.text 会命中输入框自身）。
    await tester.enterText(find.byType(TextField).first, 'github00');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('github00.com').first, warnIfMissed: false);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(tester.takeException(), isNull);

    // 查询本身不解密：明文不该出现在树里。
    expect(find.text('•' * 12), findsOneWidget, reason: '密码没有打码显示');
    expect(find.text('pw-0-0'), findsNothing,
        reason: '查询就把明文摊出来了（应该按需解密）');

    // 点👁 → 按需解密后才显示明文。
    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('pw-0-0'), findsOneWidget, reason: '点👁后明文没显示出来');
    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0,
        reason: '按需解密退化成了 UI 线程同步派生');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('连续快速点击多个建议项不会堆叠查询、不抛异常', (tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final app = (await tester.runAsync(buildAppState))!;
    await tester.runAsync(() => app.unlock(masterKey));
    await pumpHome(tester, app);
    VaultCipher.debugMainIsolatePbkdf2Count = 0;

    for (final q in ['github0', 'github1', 'github2', 'github0']) {
      await tester.enterText(find.byType(TextField).first, q);
      await tester.pump(const Duration(milliseconds: 250));
      final tile = find.text('${q}0.com');
      if (tile.evaluate().isEmpty) continue;
      await tester.tap(tile.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 20)); // 不等结果就下一发
      expect(tester.takeException(), isNull);
    }
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
    }
    expect(VaultCipher.debugMainIsolatePbkdf2Count, 0);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
