import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'desktop/window_state.dart';
import 'l10n/app_localizations.dart';
import 'settings/app_settings.dart';
import 'settings/secure_credential_store.dart';
import 'storage/compactor.dart';
import 'storage/vault_repository.dart';
import 'sync/sync_manager.dart';
import 'ui/master_key_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = await AppSettings.load();

  // 桌面端：恢复上次窗口位置/大小（移动端跳过）。
  if (isDesktop) {
    await WindowStateManager(settings).initAndRestore();
  }

  final credentials = SecureCredentialStore();
  final vault = await VaultRepository.open();
  final sync = SyncManager(
    settings: settings,
    credentials: credentials,
    logStore: vault.store,
    memoryIndex: vault.index,
  );
  final compactor = Compactor(vault.store, vault.index);

  final appState = AppState(
    vault: vault,
    settings: settings,
    credentials: credentials,
    sync: sync,
    compactor: compactor,
  );

  // 启动后台同步：开了"进入软件自动同步"就直接拉取合并，否则只轻量探测远端
  //（"智能跳过"用）。都失败静默，不阻塞启动。
  if (settings.cloudEnabled && settings.autoSyncOnLaunch) {
    // ignore: discarded_futures
    sync.pullAndMerge();
  } else {
    // ignore: discarded_futures
    sync.checkRemoteAsync();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: sync),
      ],
      child: const PassProApp(),
    ),
  );
}

class PassProApp extends StatelessWidget {
  const PassProApp({super.key});

  ThemeData _theme(Brightness brightness, bool transparentScaffold) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3F51B5),
        brightness: brightness,
      ),
    );
    // 设了背景图时让脚手架背景透明，壁纸才能透出来。
    return transparentScaffold
        ? base.copyWith(scaffoldBackgroundColor: Colors.transparent)
        : base;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final hasBg = settings.hasBackground;
    return MaterialApp(
      title: 'PassPro',
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _theme(Brightness.light, hasBg),
      darkTheme: _theme(Brightness.dark, hasBg),
      builder: hasBg
          ? (context, child) => Stack(
                children: [
                  // 底色（壁纸下方），避免透明处发黑。
                  Positioned.fill(
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                  _BackgroundLayer(settings: settings),
                  if (child != null) Positioned.fill(child: child),
                ],
              )
          : null,
      home: const MasterKeyPage(),
    );
  }
}

/// 全屏背景图层：按设置的大小(填充方式)/透明度/模糊度渲染。
/// 文件缺失或解码失败时静默不显示。
class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final path = settings.backgroundPath;
    if (path.isEmpty) return const SizedBox.shrink();
    final fit = switch (settings.backgroundFit) {
      'contain' => BoxFit.contain,
      'fill' => BoxFit.fill,
      'fitWidth' => BoxFit.fitWidth,
      _ => BoxFit.cover,
    };
    Widget img = Image.file(
      File(path),
      fit: fit,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    final blur = settings.backgroundBlur;
    if (blur > 0) {
      img = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: img,
      );
    }
    return Positioned.fill(
      child: Opacity(
        opacity: settings.backgroundOpacity,
        child: img,
      ),
    );
  }
}
