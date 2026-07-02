import 'dart:io';
import 'dart:math' as math;
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
import 'ui/background_image.dart';
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
    if (!transparentScaffold) return base;
    // 设了背景图时让脚手架背景透明，壁纸才能透出来；
    // 但输入框默认无填充是透明的，壁纸会直接透进框里，云同步等表单会显示成
    // 一片灰。给输入框补一层不透明填充，保证文字在壁纸上清晰可读。
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.colorScheme.surfaceContainerHighest,
      ),
    );
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

/// 全屏背景图层：解码限宽 + 模糊一次性烘焙成静态纹理（见 bakeBackgroundImage），
/// 运行期只画一张普通纹理，透明度走 RawImage 的绘制期 alpha（无 saveLayer）。
/// 文件缺失或解码失败时静默不显示。
class _BackgroundLayer extends StatefulWidget {
  const _BackgroundLayer({required this.settings});

  final AppSettings settings;

  @override
  State<_BackgroundLayer> createState() => _BackgroundLayerState();
}

class _BackgroundLayerState extends State<_BackgroundLayer> {
  ui.Image? _image;
  String? _bakedKey;
  bool _baking = false;

  @override
  void initState() {
    super.initState();
    _ensureBaked();
  }

  @override
  void didUpdateWidget(covariant _BackgroundLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureBaked();
  }

  /// 路径或模糊度变化时重新烘焙；拖动滑杆期间的中间值会被折叠成最后一次。
  Future<void> _ensureBaked() async {
    if (_baking) return;
    _baking = true;
    try {
      while (mounted) {
        final path = widget.settings.backgroundPath;
        final blur = widget.settings.backgroundBlur;
        final key = path.isEmpty ? '' : '$path|${blur.toStringAsFixed(3)}';
        if (key == _bakedKey) break;
        ui.Image? baked;
        if (path.isNotEmpty) {
          try {
            final view = WidgetsBinding.instance.platformDispatcher.views.first;
            final physW = view.physicalSize.width;
            // 留 20% 余量应对窗口拉大；再大人眼也看不出，徒增显存与耗时。
            final maxW =
                physW > 0 ? math.min(3072, (physW * 1.2).round()) : 2048;
            final logicalW =
                physW > 0 ? physW / view.devicePixelRatio : 1280.0;
            baked = await bakeBackgroundImage(
              await File(path).readAsBytes(),
              blurSigma: blur,
              maxWidth: maxW,
              logicalWidth: logicalW,
            );
          } catch (_) {
            baked = null;
          }
        }
        if (!mounted) {
          baked?.dispose();
          return;
        }
        final old = _image;
        setState(() {
          _image = baked;
          _bakedKey = key;
        });
        if (old != null) {
          // 等新纹理上屏后再释放旧的，避免释放仍被当前帧引用的图。
          WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
        }
      }
    } finally {
      _baking = false;
    }
  }

  @override
  void dispose() {
    final img = _image;
    if (img != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => img.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) return const SizedBox.shrink();
    final fit = switch (widget.settings.backgroundFit) {
      'contain' => BoxFit.contain,
      'fill' => BoxFit.fill,
      'fitWidth' => BoxFit.fitWidth,
      _ => BoxFit.cover,
    };
    return Positioned.fill(
      child: RepaintBoundary(
        child: RawImage(
          image: img,
          fit: fit,
          opacity: AlwaysStoppedAnimation(widget.settings.backgroundOpacity),
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
