import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:passpro/app_state.dart';
import 'package:passpro/l10n/app_localizations.dart';
import 'package:passpro/settings/app_settings.dart';
import 'package:passpro/settings/secure_credential_store.dart';
import 'package:passpro/storage/compactor.dart';
import 'package:passpro/storage/vault_repository.dart';
import 'package:passpro/sync/sync_manager.dart';
import 'package:passpro/ui/settings_page.dart';

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

/// 回归测试：云同步后端表单曾整体变成巨大灰块（release 的 ErrorWidget）。
/// 根因：_CollapsibleSection 的 PageStorageKey 激活了子树 PageStorage，
/// 内层无 key 的 ExpansionTile 写入 bool 展开状态，与 TextField 滚动器
/// 恢复偏移读的 double 同桶冲突，"as double?" 抛 _TypeError，
/// 表单 5 个输入框全部换成 10 万像素高的 RenderErrorBox。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('passpro_test_');
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<AppState> buildAppState() async {
    final settings = await AppSettings.load();
    await settings.setCloudEnabled(true);
    await settings.setSectionExpanded('cloud', true);
    await settings.updateBackend(const BackendConfig(
      kind: BackendKind.github,
      enabled: true,
      owner: 'muzi-xiaoren',
      repo: 'pass',
    ));
    final credentials = SecureCredentialStore();
    final vault = await VaultRepository.open();
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

  testWidgets('展开 GitHub 云同步表单：字段正常渲染、无 ErrorWidget',
      (tester) async {
    tester.view.physicalSize = const Size(1900, 1200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // 服务构造有真实文件 IO，须在 runAsync 里跑（假时钟 zone 中 IO 永不完成）。
    final app = (await tester.runAsync(buildAppState))!;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider.value(value: app.settings),
          ChangeNotifierProvider.value(value: app.sync),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
          ),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // 展开 GitHub 后端表单（内层 ExpansionTile 会写 PageStorage 状态，
    // 正是原 bug 的触发动作）。
    await tester.tap(find.text('GitHub').first, warnIfMissed: false);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull,
          reason: '展开 GitHub 表单第 $i 帧抛异常');
    }

    expect(find.byType(ErrorWidget), findsNothing,
        reason: '表单里出现了 ErrorWidget（release 下就是灰块）');

    final owner = find.widgetWithText(TextField, '拥有者');
    expect(owner, findsOneWidget);
    final size = tester.getSize(owner.first);
    expect(size.height, lessThan(120), reason: '拥有者输入框高度异常：$size');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
