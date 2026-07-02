import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';
import '../models/search_config.dart';
import '../services/update_checker.dart';
import '../settings/app_settings.dart';
import '../sync/git_backend.dart';
import '../sync/sync_backend.dart';
import '../sync/webdav_backend.dart';

/// 应用版本号（关于页展示 + 检查更新比较的基准）。发版时同步改 pubspec.yaml。
const String kAppVersion = '1.0.5';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // ============ 语言 ============
          _SectionHeader(l10n.sectionLanguage),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            trailing: DropdownButton<String>(
              value: settings.localeCode,
              underline: const SizedBox.shrink(),
              onChanged: (code) {
                if (code != null) settings.setLocale(code);
              },
              items: [
                DropdownMenuItem(value: '', child: Text(l10n.followSystem)),
                const DropdownMenuItem(value: 'zh', child: Text('简体中文')),
                const DropdownMenuItem(value: 'en', child: Text('English')),
                const DropdownMenuItem(value: 'ja', child: Text('日本語')),
                const DropdownMenuItem(value: 'ko', child: Text('한국어')),
                const DropdownMenuItem(value: 'fr', child: Text('Français')),
                const DropdownMenuItem(value: 'ru', child: Text('Русский')),
                const DropdownMenuItem(value: 'de', child: Text('Deutsch')),
              ],
            ),
          ),

          const Divider(),
          // ============ 搜索规则（可下拉展开/收起） ============
          _CollapsibleSection(
            id: 'search',
            title: l10n.sectionSearch,
            children: const [_SearchRuleSection()],
          ),

          const Divider(),
          // ============ 背景图（可下拉展开/收起） ============
          _CollapsibleSection(
            id: 'background',
            title: l10n.sectionBackground,
            children: const [_BackgroundSection()],
          ),

          const Divider(),
          // ============ 云同步（可下拉展开/收起） ============
          _CollapsibleSection(
            id: 'cloud',
            title: l10n.sectionCloudSync,
            children: [
              SwitchListTile(
                title: Text(l10n.enableCloudSync),
                subtitle: Text(l10n.enableCloudSyncSub),
                value: settings.cloudEnabled,
                onChanged: settings.setCloudEnabled,
              ),
              if (settings.cloudEnabled) ...[
                SwitchListTile(
                  title: Text(l10n.autoSyncOnLaunch),
                  subtitle: Text(l10n.autoSyncOnLaunchSub),
                  value: settings.autoSyncOnLaunch,
                  onChanged: settings.setAutoSyncOnLaunch,
                ),
                _BackendTile(kind: BackendKind.github),
                _BackendTile(kind: BackendKind.gitee),
                _BackendTile(kind: BackendKind.webdav),
                const Divider(),
                _SectionHeader(l10n.sectionSyncPrompt),
                SwitchListTile(
                  title: Text(l10n.promptBeforePull),
                  subtitle: Text(l10n.promptBeforePullSub),
                  value: settings.promptBeforeEdit,
                  onChanged: settings.setPromptBeforeEdit,
                ),
                SwitchListTile(
                  title: Text(l10n.promptAfterPush),
                  value: settings.promptAfterEdit,
                  onChanged: settings.setPromptAfterEdit,
                ),
                SwitchListTile(
                  title: Text(l10n.smartSkip),
                  subtitle: Text(l10n.smartSkipSub),
                  value: settings.smartSkip,
                  onChanged: settings.setSmartSkip,
                ),
              ],
            ],
          ),

          const Divider(),
          // ============ 维护 ============
          _SectionHeader(l10n.sectionMaintenance),
          ListTile(
            leading: const Icon(Icons.compress),
            title: Text(l10n.compactNow),
            subtitle: const _CompactionSubtitle(),
            onTap: () => _runCompaction(context),
          ),

          const Divider(),
          // ============ 本地备份（可下拉展开/收起） ============
          _CollapsibleSection(
            id: 'backup',
            title: l10n.sectionBackup,
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(l10n.exportBackup),
                subtitle: Text(l10n.exportBackupSub),
                onTap: () => _exportLog(context),
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(l10n.importBackup),
                subtitle: Text(l10n.importBackupSub),
                onTap: () => _importLog(context),
              ),
              ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: Text(l10n.exportCsvTitle),
                subtitle: Text(l10n.exportCsvSub),
                onTap: () => _exportCsv(context),
              ),
              ListTile(
                leading: const Icon(Icons.file_open_outlined),
                title: Text(l10n.importCsvTitle),
                subtitle: Text(l10n.importCsvSub),
                onTap: () => _importCsv(context),
              ),
            ],
          ),

          const Divider(),
          _SectionHeader(l10n.sectionAbout),
          const _CheckUpdateTile(),
          const _AboutSection(),
        ],
      ),
    );
  }

  Future<void> _runCompaction(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final app = context.read<AppState>();
    if (app.settings.cloudEnabled) {
      // 协议：先 pull 再 compact 再 push
      final pulled = await app.sync.pullAndMerge();
      // ignore: unused_local_variable
      final _ = pulled;
    }
    final report = await app.compactor.compact();
    if (!context.mounted) return;
    final saved = report.savedBytes;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.compactDone(report.activeRecords, _humanBytes(saved)),
        ),
      ),
    );
    if (app.settings.cloudEnabled) {
      await app.sync.pushAll(commitMessage: 'compact log');
    }
  }

  // ============ 本地导入 / 导出 ============

  /// 导出加密备份（原始 .log 文件，密码仍为密文）。
  Future<void> _exportLog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = app.vault.index.activeCount;
      if (count == 0) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.nothingToExport)));
        return;
      }
      final data = Uint8List.fromList(await app.vault.exportLogBytes());
      final saved =
          await _saveBytes('PassPro-backup-${_stamp()}.log', data);
      if (saved) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone(count))));
      }
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.exportFailed('$e'))));
    }
  }

  /// 导入加密备份（.log），与现有库按记录合并。
  Future<void> _importLog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _pickBytes();
      if (bytes == null) return;
      final r = await app.vault.importLogBytes(bytes);
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.importDone(r.added, r.total))));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.importFailed('$e'))));
    }
  }

  /// 导出明文 CSV（导出前二次确认，密码会以明文落盘）。
  Future<void> _exportCsv(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exportCsvWarnTitle),
        content: Text(l10n.exportCsvWarnBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.continueLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final out = app.vault.exportCsv(app.cipher);
      if (out.count == 0) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.nothingToExport)));
        return;
      }
      // 前置 UTF-8 BOM，方便 Excel 正确识别中文。
      final data = Uint8List.fromList(utf8.encode('\u{FEFF}${out.csv}'));
      final saved =
          await _saveBytes('PassPro-export-${_stamp()}.csv', data);
      if (saved) {
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.exportDone(out.count))));
      }
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.exportFailed('$e'))));
    }
  }

  /// 从明文 CSV 导入（按 网站,账号,密码 三列，逐条用当前主密钥加密入库）。
  Future<void> _importCsv(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _pickBytes();
      if (bytes == null) return;
      var text = utf8.decode(bytes, allowMalformed: true);
      if (text.startsWith('\u{FEFF}')) text = text.substring(1); // 去掉 BOM
      final r = await app.vault.importCsv(text, app.cipher);
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.importDone(r.added, r.total))));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.importFailed('$e'))));
    }
  }

  /// 弹系统文件选择框，读出所选文件字节；用户取消返回 null。
  Future<Uint8List?> _pickBytes() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.single;
    if (f.bytes != null) return f.bytes;
    final path = f.path;
    if (path == null) return null;
    return File(path).readAsBytes();
  }

  /// 弹系统保存框写出字节；移动端通过 file_picker 直接落盘，桌面端取路径自行写。
  /// 用户取消返回 false。
  Future<bool> _saveBytes(String fileName, Uint8List data) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final path =
          await FilePicker.platform.saveFile(fileName: fileName, bytes: data);
      return path != null;
    }
    final path = await FilePicker.platform.saveFile(fileName: fileName);
    if (path == null) return false;
    await File(path).writeAsBytes(data);
    return true;
  }

  static String _stamp() {
    final n = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}-'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }
}

String _humanBytes(int n) {
  if (n < 1024) return '${n}B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)}KB';
  return '${(n / 1024 / 1024).toStringAsFixed(1)}MB';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// 可下拉展开/收起的设置分区；展开状态按 [id] 持久化记忆。
class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.id,
    required this.title,
    required this.children,
  });

  final String id;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppSettings>();
    final theme = Theme.of(context);
    return Theme(
      // 去掉 ExpansionTile 自带的上下分隔线，外观更接近原来的分区标题。
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        // 千万不要在这里加 PageStorageKey：它会激活整棵子树的 PageStorage，
        // 内层无 key 的 ExpansionTile 写入的 bool 会与 TextField 滚动器
        // 恢复偏移时读的 double 落在同一个存储桶，读到 bool 直接抛
        // _TypeError → 表单全部输入框变成 10 万像素高的 ErrorWidget 灰盒。
        // 展开状态用 settings.sectionExpanded 持久化即可（见下）。
        initiallyExpanded: settings.sectionExpanded(id),
        onExpansionChanged: (v) => settings.setSectionExpanded(id, v),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: children,
      ),
    );
  }
}

// ============ 背景图设置（图片 + 透明度 + 模糊度 + 大小） ============

class _BackgroundSection extends StatelessWidget {
  const _BackgroundSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<AppSettings>();
    final has = settings.hasBackground;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: Text(l10n.bgChooseImage),
          subtitle: Text(has ? l10n.bgImageSet : l10n.bgNoImage),
          trailing: has
              ? IconButton(
                  tooltip: l10n.bgClearImage,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _clear(context),
                )
              : null,
          onTap: () => _pick(context),
        ),
        if (has) ...[
          _slider(
            context,
            l10n.bgOpacity,
            settings.backgroundOpacity,
            0,
            1,
            (v) => settings.setBackgroundOpacity(v),
          ),
          _slider(
            context,
            l10n.bgBlur,
            settings.backgroundBlur,
            0,
            20,
            (v) => settings.setBackgroundBlur(v),
          ),
          ListTile(
            title: Text(l10n.bgFit),
            trailing: DropdownButton<String>(
              value: settings.backgroundFit,
              underline: const SizedBox.shrink(),
              onChanged: (v) {
                if (v != null) settings.setBackgroundFit(v);
              },
              items: [
                DropdownMenuItem(value: 'cover', child: Text(l10n.bgFitCover)),
                DropdownMenuItem(
                    value: 'contain', child: Text(l10n.bgFitContain)),
                DropdownMenuItem(value: 'fill', child: Text(l10n.bgFitFill)),
                DropdownMenuItem(
                    value: 'fitWidth', child: Text(l10n.bgFitWidth)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _slider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final v = value.clamp(min, max);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(label)),
          Expanded(
            child: Slider(
              value: v,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              max <= 1 ? v.toStringAsFixed(2) : v.toStringAsFixed(0),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final settings = context.read<AppSettings>();
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    final bytes = f.bytes ??
        (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) return;
    final dir = await getApplicationSupportDirectory();
    // 用唯一文件名避免 Flutter 图片缓存命中旧图；写入后清掉旧背景文件。
    final dest = File(p.join(dir.path, 'PassPro',
        'bg-${DateTime.now().millisecondsSinceEpoch}.img'));
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(bytes);
    final old = settings.backgroundPath;
    await settings.setBackgroundPath(dest.path);
    if (old.isNotEmpty && old != dest.path) {
      try {
        await File(old).delete();
      } catch (_) {/* 旧文件删不掉无所谓 */}
    }
  }

  Future<void> _clear(BuildContext context) async {
    final settings = context.read<AppSettings>();
    final old = settings.backgroundPath;
    await settings.setBackgroundPath('');
    if (old.isNotEmpty) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
  }
}

// ============ 搜索规则 ============

class _SearchRuleSection extends StatefulWidget {
  const _SearchRuleSection();

  @override
  State<_SearchRuleSection> createState() => _SearchRuleSectionState();
}

class _SearchRuleSectionState extends State<_SearchRuleSection> {
  late final TextEditingController _delimiter;

  @override
  void initState() {
    super.initState();
    _delimiter = TextEditingController(
      text: context.read<AppSettings>().searchCustomDelimiter,
    );
  }

  @override
  void dispose() {
    _delimiter.dispose();
    super.dispose();
  }

  String _modeName(AppLocalizations l10n, SearchMode m) => switch (m) {
        SearchMode.exact => l10n.searchExact,
        SearchMode.contains => l10n.searchContains,
        SearchMode.fuzzy => l10n.searchFuzzy,
        SearchMode.custom => l10n.searchCustom,
      };

  String _modeDesc(AppLocalizations l10n, SearchMode m) => switch (m) {
        SearchMode.exact => l10n.searchExactDesc,
        SearchMode.contains => l10n.searchContainsDesc,
        SearchMode.fuzzy => l10n.searchFuzzyDesc,
        SearchMode.custom => l10n.searchCustomDesc,
      };

  String _strategyName(AppLocalizations l10n, SearchStrategy s) => switch (s) {
        SearchStrategy.exact => l10n.searchExact,
        SearchStrategy.contains => l10n.searchContains,
        SearchStrategy.fuzzy => l10n.searchFuzzy,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<AppSettings>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in SearchMode.values)
          ListTile(
            dense: true,
            leading: Icon(
              settings.searchMode == m
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: settings.searchMode == m
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            title: Text(_modeName(l10n, m)),
            subtitle: Text(_modeDesc(l10n, m)),
            onTap: () => settings.setSearchMode(m),
          ),
        if (settings.searchMode == SearchMode.custom)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _delimiter,
                    decoration: InputDecoration(
                      labelText: l10n.searchDelimiterLabel,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: settings.setSearchCustomDelimiter,
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<SearchStrategy>(
                  value: settings.searchCustomStrategy,
                  onChanged: (s) {
                    if (s != null) settings.setSearchCustomStrategy(s);
                  },
                  items: [
                    for (final s in SearchStrategy.values)
                      DropdownMenuItem(
                        value: s,
                        child: Text(_strategyName(l10n, s)),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ============ 检查更新 ============

class _CheckUpdateTile extends StatefulWidget {
  const _CheckUpdateTile();

  @override
  State<_CheckUpdateTile> createState() => _CheckUpdateTileState();
}

class _CheckUpdateTileState extends State<_CheckUpdateTile> {
  bool _checking = false;

  Future<void> _check() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _checking = true);
    try {
      final info = await UpdateChecker.check(kAppVersion);
      if (!mounted) return;
      if (info.hasUpdate) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.checkUpdate),
            content: Text(l10n.updateAvailable(info.latestVersion)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l10n.continueLabel),
              ),
            ],
          ),
        );
        if (go == true) {
          await launchUrl(
            Uri.parse(info.htmlUrl),
            mode: LaunchMode.externalApplication,
          );
        }
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.updateUpToDate(info.latestVersion))),
        );
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.updateCheckFailed)));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.system_update_alt),
      title: Text(l10n.checkUpdate),
      subtitle: _checking ? Text(l10n.checkingUpdate) : null,
      trailing: _checking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _checking ? null : _check,
    );
  }
}

// ============ 关于（两列布局 + 可点击跳转 GitHub） ============

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  static const String _author = 'muzi-xiaoren';
  static const String _repoUrl = 'https://github.com/muzi-xiaoren/PassPro';
  static const String _repoLabel = 'github.com/muzi-xiaoren/PassPro';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 8),
              Text('PassPro', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          _AboutRow(
              label: l10n.aboutVersionLabel, child: const Text(kAppVersion)),
          const SizedBox(height: 8),
          _AboutRow(label: l10n.aboutAuthorLabel, child: const Text(_author)),
          const SizedBox(height: 8),
          _AboutRow(
            label: l10n.aboutRepoLabel,
            child: InkWell(
              onTap: () => _openRepo(context),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _repoLabel,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new,
                        size: 16, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRepo(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(_repoUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    // 打开失败时回退：把地址提示出来，便于用户手动复制访问。
    if (!launched) {
      messenger.showSnackBar(const SnackBar(content: Text(_repoUrl)));
    }
  }
}

/// 关于页的一行：左列标签（定宽）+ 右列内容（自适应），即"两列"布局。
class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium ?? const TextStyle(),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _CompactionSubtitle extends StatefulWidget {
  const _CompactionSubtitle();

  @override
  State<_CompactionSubtitle> createState() => _CompactionSubtitleState();
}

class _CompactionSubtitleState extends State<_CompactionSubtitle> {
  late final _index = context.read<AppState>().vault.index;

  @override
  void initState() {
    super.initState();
    // 整理日志后索引会 replay 并通知，这里即时刷新“有效/总行数/放大率”。
    _index.addListener(_onChanged);
  }

  @override
  void dispose() {
    _index.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ix = _index;
    final amp = ix.amplification.toStringAsFixed(2);
    return Text(l10n.compactionStatus(ix.activeCount, ix.totalLineCount, amp));
  }
}

// ============ 后端配置卡 ============

class _BackendTile extends StatelessWidget {
  const _BackendTile({required this.kind});

  final BackendKind kind;

  String get _name => switch (kind) {
        BackendKind.github => 'GitHub',
        BackendKind.gitee => 'Gitee',
        BackendKind.webdav => 'WebDAV',
      };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final l10n = AppLocalizations.of(context)!;
    final cfg = switch (kind) {
      BackendKind.github => settings.github,
      BackendKind.gitee => settings.gitee,
      BackendKind.webdav => settings.webdav,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          kind == BackendKind.github ? Icons.code : Icons.cloud_outlined,
        ),
        title: Text(_name),
        subtitle: Text(
          cfg.enabled
              ? '${cfg.role == BackendRole.primary ? l10n.rolePrimary : l10n.roleMirror} · ${kind == BackendKind.webdav ? cfg.repo : "${cfg.owner}/${cfg.repo}"}'
              : l10n.backendDisabled,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _BackendForm(initial: cfg),
          ),
        ],
      ),
    );
  }
}

class _BackendForm extends StatefulWidget {
  const _BackendForm({required this.initial});
  final BackendConfig initial;

  @override
  State<_BackendForm> createState() => _BackendFormState();
}

class _BackendFormState extends State<_BackendForm> {
  late bool _enabled;
  late BackendRole _role;
  late final TextEditingController _owner;
  late final TextEditingController _repo;
  late final TextEditingController _branch;
  late final TextEditingController _filePath;
  late final TextEditingController _pat;
  bool _patChanged = false;
  bool _testing = false;
  String? _testMessage;
  bool _testFailed = false;

  bool get _isWebDav => widget.initial.kind == BackendKind.webdav;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initial.enabled;
    _role = widget.initial.role;
    _owner = TextEditingController(text: widget.initial.owner);
    _repo = TextEditingController(text: widget.initial.repo);
    _branch = TextEditingController(text: widget.initial.branch);
    _filePath = TextEditingController(text: widget.initial.filePath);
    _pat = TextEditingController();
    _loadPat();
  }

  Future<void> _loadPat() async {
    final app = context.read<AppState>();
    final existing = await app.credentials.readPat(widget.initial.kind);
    if (existing != null && mounted) {
      _pat.text = '••••••••';
    }
  }

  @override
  void dispose() {
    _owner.dispose();
    _repo.dispose();
    _branch.dispose();
    _filePath.dispose();
    _pat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final app = context.read<AppState>();
    try {
      final updated = widget.initial.copyWith(
        enabled: _enabled,
        role: _role,
        owner: _owner.text.trim(),
        repo: _repo.text.trim(),
        branch: _branch.text.trim().isEmpty
            ? BackendConfig.defaultBranchFor(widget.initial.kind)
            : _branch.text.trim(),
        filePath: _filePath.text.trim().isEmpty
            ? BackendConfig.defaultFilePathFor(widget.initial.kind)
            : _filePath.text.trim(),
      );
      await app.settings.updateBackend(updated);
      final pat = _pat.text.trim();
      if (_patChanged && pat.isNotEmpty && pat != '••••••••') {
        await app.credentials.writePat(widget.initial.kind, pat);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saved)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  Future<void> _test() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    final app = context.read<AppState>();
    var pat = _pat.text.trim();
    if (pat == '••••••••' || pat.isEmpty) {
      pat = (await app.credentials.readPat(widget.initial.kind) ?? '').trim();
    }
    final cfg = widget.initial.copyWith(
      enabled: true,
      role: _role,
      owner: _owner.text.trim(),
      repo: _repo.text.trim(),
      branch: _branch.text.trim().isEmpty
          ? BackendConfig.defaultBranchFor(widget.initial.kind)
          : _branch.text.trim(),
      filePath: _filePath.text.trim().isEmpty
          ? BackendConfig.defaultFilePathFor(widget.initial.kind)
          : _filePath.text.trim(),
    );
    try {
      final backend = _isWebDav
          ? WebDavBackend(config: cfg, password: pat)
          : GitBackend(config: cfg, pat: pat);
      final v = await backend.testConnection();
      setState(() {
        _testFailed = false;
        final shortVersion = v == null || v.length <= 7 ? v : v.substring(0, 7);
        _testMessage = v == null
            ? l10n.testOkNoFile
            : l10n.testOkSha(shortVersion!);
      });
    } on SyncException catch (e) {
      setState(() {
        _testFailed = true;
        _testMessage = switch (e.kind) {
          SyncErrorKind.repoNotFound =>
            l10n.repoNotFoundOrNoAccess('${cfg.owner}/${cfg.repo}'),
          SyncErrorKind.webdavFolderMissing => l10n.webdavFolderMissing,
          SyncErrorKind.http =>
            l10n.testFailHttp(e.statusCode?.toString() ?? '-', e.message),
        };
      });
    } catch (e) {
      setState(() {
        _testFailed = true;
        _testMessage = l10n.testFail(e.toString());
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: Text(l10n.enable),
          value: _enabled,
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        Row(
          children: [
            Text(l10n.roleLabel),
            const SizedBox(width: 12),
            SegmentedButton<BackendRole>(
              segments: [
                ButtonSegment(
                  value: BackendRole.primary,
                  label: Text(l10n.rolePrimary),
                ),
                ButtonSegment(
                  value: BackendRole.mirror,
                  label: Text(l10n.roleMirror),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _owner,
          decoration: InputDecoration(
            labelText: _isWebDav ? l10n.webdavAccount : l10n.owner,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _repo,
          decoration: InputDecoration(
            labelText: _isWebDav ? l10n.webdavServer : l10n.repoName,
            hintText: _isWebDav ? 'https://dav.jianguoyun.com/dav/' : null,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (!_isWebDav) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _branch,
            decoration: InputDecoration(
              labelText: l10n.branch,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _filePath,
          decoration: InputDecoration(
            labelText: _isWebDav ? l10n.webdavRemotePath : l10n.filePath,
            hintText: _isWebDav ? '/PassPro/passwords.log' : null,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pat,
          obscureText: true,
          onChanged: (_) => _patChanged = true,
          onTap: () {
            if (_pat.text == '••••••••') _pat.clear();
            _patChanged = true;
          },
          decoration: InputDecoration(
            labelText: _isWebDav ? l10n.webdavAppPassword : l10n.personalAccessToken,
            helperText: _isWebDav ? l10n.webdavAppPasswordHelper : l10n.patHelper,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (_testMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _testMessage!,
            style: TextStyle(
              color: _testFailed
                  ? Theme.of(context).colorScheme.error
                  : Colors.green,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check),
              label: Text(l10n.testConnection),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.save),
            ),
          ],
        ),
      ],
    );
  }
}
