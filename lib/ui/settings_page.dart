import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../settings/app_settings.dart';
import '../sync/git_backend.dart';
import '../sync/sync_backend.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // ============ 云同步 ============
          const _SectionHeader('云同步'),
          SwitchListTile(
            title: const Text('启用云同步'),
            subtitle: const Text('关闭后所有数据仅保留在本机'),
            value: settings.cloudEnabled,
            onChanged: settings.setCloudEnabled,
          ),
          if (settings.cloudEnabled) ...[
            _BackendTile(kind: BackendKind.github),
            _BackendTile(kind: BackendKind.gitee),
            const Divider(),
            const _SectionHeader('同步提示'),
            SwitchListTile(
              title: const Text('操作前提示拉取'),
              subtitle: const Text('新增/修改/删除前先弹出"拉取远端"提示'),
              value: settings.promptBeforeEdit,
              onChanged: settings.setPromptBeforeEdit,
            ),
            SwitchListTile(
              title: const Text('操作后提示推送'),
              value: settings.promptAfterEdit,
              onChanged: settings.setPromptAfterEdit,
            ),
            SwitchListTile(
              title: const Text('智能跳过'),
              subtitle: const Text('远端无更新时自动跳过"拉取"提示'),
              value: settings.smartSkip,
              onChanged: settings.setSmartSkip,
            ),
          ],

          const Divider(),
          // ============ 维护 ============
          const _SectionHeader('维护'),
          ListTile(
            leading: const Icon(Icons.compress),
            title: const Text('立即整理日志'),
            subtitle: const _CompactionSubtitle(),
            onTap: () => _runCompaction(context),
          ),

          const Divider(),
          const _SectionHeader('关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Passman Pro'),
            subtitle: Text('版本 0.1.0  ·  Fernet 兼容旧版加密文件'),
          ),
        ],
      ),
    );
  }

  Future<void> _runCompaction(BuildContext context) async {
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
          '已整理：${report.activeRecords} 条有效记录，节省 ${_humanBytes(saved)}',
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
    final ix = app.vault.index;
    final amp = ix.amplification.toStringAsFixed(2);
    return Text('当前 ${ix.activeCount} 条有效 / ${ix.totalLineCount} 行（放大率 $amp×）');
  }
}

// ============ 后端配置卡 ============

class _BackendTile extends StatelessWidget {
  const _BackendTile({required this.kind});

  final BackendKind kind;

  String get _name => kind == BackendKind.github ? 'GitHub' : 'Gitee';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final cfg = kind == BackendKind.github ? settings.github : settings.gitee;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          kind == BackendKind.github ? Icons.code : Icons.cloud_outlined,
        ),
        title: Text(_name),
        subtitle: Text(
          cfg.enabled
              ? '${cfg.role == BackendRole.primary ? "Primary" : "Mirror"} · ${cfg.owner}/${cfg.repo}'
              : '未启用',
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
    final app = context.read<AppState>();
    final updated = widget.initial.copyWith(
      enabled: _enabled,
      role: _role,
      owner: _owner.text.trim(),
      repo: _repo.text.trim(),
      branch: _branch.text.trim().isEmpty ? 'main' : _branch.text.trim(),
      filePath: _filePath.text.trim().isEmpty
          ? 'passwords.log'
          : _filePath.text.trim(),
    );
    await app.settings.updateBackend(updated);
    if (_patChanged && _pat.text.isNotEmpty && _pat.text != '••••••••') {
      await app.credentials.writePat(widget.initial.kind, _pat.text);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存')),
    );
  }

  Future<void> _test() async {
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
      branch: _branch.text.trim().isEmpty ? 'main' : _branch.text.trim(),
      filePath: _filePath.text.trim().isEmpty
          ? 'passwords.log'
          : _filePath.text.trim(),
    );
    try {
      final backend = GitBackend(config: cfg, pat: pat);
      final v = await backend.headVersion();
      setState(() => _testMessage = v == null
          ? '连接成功（远端文件还不存在，首次推送会创建）'
          : '连接成功（当前 sha=${v.substring(0, 7)}…）');
    } on SyncException catch (e) {
      setState(() => _testMessage = '失败：HTTP ${e.statusCode} ${e.message}');
    } catch (e) {
      setState(() => _testMessage = '失败：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('启用'),
          value: _enabled,
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        Row(
          children: [
            const Text('角色：'),
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
          decoration: const InputDecoration(
            labelText: 'Owner',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _repo,
          decoration: const InputDecoration(
            labelText: '仓库名',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _branch,
          decoration: const InputDecoration(
            labelText: '分支',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _filePath,
          decoration: const InputDecoration(
            labelText: '文件路径',
            border: OutlineInputBorder(),
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
          decoration: const InputDecoration(
            labelText: 'Personal Access Token',
            helperText: '存进 OS Keychain，不会写入任何文件',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (_testMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _testMessage!,
            style: TextStyle(
              color: _testMessage!.startsWith('失败')
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
              label: const Text('测试连接'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存'),
            ),
          ],
        ),
      ],
    );
  }
}
