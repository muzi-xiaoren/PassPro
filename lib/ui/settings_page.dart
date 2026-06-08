import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
import '../sync/git_backend.dart';
import '../sync/sync_backend.dart';
import '../sync/webdav_backend.dart';

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
          // ============ 云同步 ============
          _SectionHeader(l10n.sectionCloudSync),
          SwitchListTile(
            title: Text(l10n.enableCloudSync),
            subtitle: Text(l10n.enableCloudSyncSub),
            value: settings.cloudEnabled,
            onChanged: settings.setCloudEnabled,
          ),
          if (settings.cloudEnabled) ...[
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
          _SectionHeader(l10n.sectionAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('PassPro'),
            subtitle: Text(l10n.aboutSubtitle),
          ),
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

class _CompactionSubtitle extends StatelessWidget {
  const _CompactionSubtitle();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final ix = app.vault.index;
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
              ? '${cfg.role == BackendRole.primary ? "Primary" : "Mirror"} · ${kind == BackendKind.webdav ? cfg.repo : "${cfg.owner}/${cfg.repo}"}'
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
      if (_patChanged && _pat.text.isNotEmpty && _pat.text != '••••••••') {
        await app.credentials.writePat(widget.initial.kind, _pat.text);
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
    var pat = _pat.text;
    if (pat == '••••••••' || pat.isEmpty) {
      pat = await app.credentials.readPat(widget.initial.kind) ?? '';
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
      final v = await backend.headVersion();
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
        _testMessage =
            l10n.testFailHttp(e.statusCode?.toString() ?? '-', e.message);
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
              segments: const [
                ButtonSegment(
                  value: BackendRole.primary,
                  label: Text('Primary'),
                ),
                ButtonSegment(
                  value: BackendRole.mirror,
                  label: Text('Mirror'),
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
            labelText: _isWebDav ? '用户名' : 'Owner',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _repo,
          decoration: InputDecoration(
            labelText: _isWebDav ? '服务器地址' : l10n.repoName,
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
            labelText: _isWebDav ? '远程文件路径' : l10n.filePath,
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
            labelText: _isWebDav ? '应用密码' : 'Personal Access Token',
            helperText: _isWebDav ? '坚果云请填写“第三方应用管理”生成的应用密码' : l10n.patHelper,
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
