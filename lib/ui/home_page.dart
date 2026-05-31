import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/password_entry.dart';
import '../storage/vault_repository.dart';
import '../sync/sync_manager.dart';
import 'password_generator.dart';
import 'settings_page.dart';
import 'sync_prompts.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passman Pro'),
        actions: [
          const _SyncStatusBadge(),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          IconButton(
            tooltip: '锁定',
            icon: const Icon(Icons.lock_outline),
            onPressed: () {
              app.lock();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: '查询'),
            Tab(icon: Icon(Icons.add_circle_outline), text: '新增'),
            Tab(icon: Icon(Icons.list_alt), text: '列表'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _QueryTab(),
          _AddTab(),
          _ListTab(),
        ],
      ),
    );
  }
}

// ===================== 顶栏同步状态徽章 =====================

class _SyncStatusBadge extends StatelessWidget {
  const _SyncStatusBadge();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncManager>();
    final s = sync.status;
    final enabled = context.read<AppState>().settings.cloudEnabled;
    if (!enabled) return const SizedBox.shrink();

    final (icon, color, label) = switch (s.state) {
      SyncState.idle => (Icons.cloud_outlined, null, '未同步'),
      SyncState.working => (Icons.sync, Colors.blue, '同步中…'),
      SyncState.ok => (Icons.cloud_done_outlined, Colors.green, '已同步'),
      SyncState.offline => (Icons.cloud_off_outlined, Colors.orange, '离线'),
      SyncState.error => (Icons.error_outline, Colors.red, '同步失败'),
    };

    return Tooltip(
      message: s.message ?? label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: IconButton(
          icon: Icon(icon, color: color),
          onPressed: () async {
            await sync.pullAndMerge();
          },
        ),
      ),
    );
  }
}

// ===================== 查询 Tab =====================

class _QueryTab extends StatefulWidget {
  const _QueryTab();

  @override
  State<_QueryTab> createState() => _QueryTabState();
}

class _QueryTabState extends State<_QueryTab> {
  final _ctrl = TextEditingController();
  QueryResult? _result;
  String? _emptyMessage;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _doQuery() {
    final app = context.read<AppState>();
    final r = app.vault.query(_ctrl.text.trim(), app.masterKey);
    setState(() {
      _result = r;
      _emptyMessage = r.invalidKey
          ? '主密钥错误：找到匹配网址但无法解密'
          : (r.isEmpty ? '没有找到匹配的记录' : null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _doQuery(),
            decoration: InputDecoration(
              labelText: '网址（支持关键词部分匹配）',
              hintText: 'github.com / muzi-xiaoren',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _doQuery,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_result == null) {
      return const Center(
        child: Text('输入网址，回车开始查询'),
      );
    }
    if (_emptyMessage != null) {
      return Center(child: Text(_emptyMessage!));
    }
    return ListView.separated(
      itemCount: _result!.entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _PasswordCard(
        entry: _result!.entries[i],
        onChanged: _doQuery,
      ),
    );
  }
}

class _PasswordCard extends StatefulWidget {
  const _PasswordCard({required this.entry, required this.onChanged});

  final PasswordEntry entry;
  final VoidCallback onChanged;

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.entry.website,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '编辑',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(context),
                ),
                IconButton(
                  tooltip: '删除',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context),
                ),
              ],
            ),
            if (widget.entry.username.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16),
                    const SizedBox(width: 4),
                    Expanded(child: Text(widget.entry.username)),
                    IconButton(
                      tooltip: '复制用户名',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => _copy(widget.entry.username, '用户名'),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                const Icon(Icons.key_outlined, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: SelectableText(
                    _show ? widget.entry.password : '•' * 12,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  tooltip: _show ? '隐藏' : '显示',
                  icon: Icon(
                    _show
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _show = !_show),
                ),
                IconButton(
                  tooltip: '复制密码',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copy(widget.entry.password, '密码'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label 已复制'), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditPasswordPage(existing: widget.entry),
      ),
    );
    if (res == true) widget.onChanged();
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除 ${widget.entry.website} 的这条记录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final app = context.read<AppState>();
    final beforeOk = await _maybePromptPull(context);
    if (!beforeOk) return;

    await app.vault.deleteById(widget.entry.id);
    if (!context.mounted) return;
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除')),
    );
    await _maybePromptPush(context);
  }
}

// ===================== 新增 Tab =====================

class _AddTab extends StatefulWidget {
  const _AddTab();

  @override
  State<_AddTab> createState() => _AddTabState();
}

class _AddTabState extends State<_AddTab> {
  final _website = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _length = TextEditingController(text: '20');
  bool _upper = true, _lower = true, _digits = true, _special = true;

  @override
  void dispose() {
    _website.dispose();
    _username.dispose();
    _password.dispose();
    _length.dispose();
    super.dispose();
  }

  void _generate() {
    final n = int.tryParse(_length.text) ?? 20;
    _password.text = PasswordGenerator.generate(
      length: n,
      useUpper: _upper,
      useLower: _lower,
      useDigits: _digits,
      useSpecial: _special,
    );
    setState(() {});
  }

  Future<void> _save() async {
    final w = _website.text.trim();
    final pw = _password.text;
    if (w.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网址和密码不能为空')),
      );
      return;
    }

    final app = context.read<AppState>();
    final beforeOk = await _maybePromptPull(context);
    if (!beforeOk) return;

    final ok = await app.vault.add(
      website: w,
      username: _username.text.trim(),
      plaintextPassword: pw,
      masterKey: app.masterKey,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '已保存' : '已存在相同条目')),
    );
    if (ok) {
      _website.clear();
      _username.clear();
      _password.clear();
      await _maybePromptPush(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('生成密码',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _length,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '长度',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _generate,
                        icon: const Icon(Icons.refresh),
                        label: const Text('生成'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('大写'),
                        selected: _upper,
                        onSelected: (v) => setState(() => _upper = v),
                      ),
                      FilterChip(
                        label: const Text('小写'),
                        selected: _lower,
                        onSelected: (v) => setState(() => _lower = v),
                      ),
                      FilterChip(
                        label: const Text('数字'),
                        selected: _digits,
                        onSelected: (v) => setState(() => _digits = v),
                      ),
                      FilterChip(
                        label: const Text('特殊'),
                        selected: _special,
                        onSelected: (v) => setState(() => _special = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('保存到密码库',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _website,
                    decoration: const InputDecoration(
                      labelText: '网址 *',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: '用户名（可选）',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(
                      labelText: '密码 *',
                      prefixIcon: Icon(Icons.key_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== 列表 Tab =====================

class _ListTab extends StatefulWidget {
  const _ListTab();

  @override
  State<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<_ListTab> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final records = app.vault.index.activeRecords.toList(growable: false)
      ..sort((a, b) => (a.website ?? '').compareTo(b.website ?? ''));

    if (records.isEmpty) {
      return const Center(child: Text('密码库为空，去"新增"添加第一条吧'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = records[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(r.website ?? ''),
            subtitle: Text(
              (r.username ?? '').isEmpty ? '（无用户名）' : r.username!,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) {
                      try {
                        final entry = PasswordEntry(
                          id: r.id,
                          website: r.website ?? '',
                          username: r.username ?? '',
                          password: app.vault.index.decryptPassword(
                            r,
                            app.masterKey,
                          ),
                          updatedAt: r.ts,
                        );
                        return EditPasswordPage(existing: entry);
                      } catch (_) {
                        return const Scaffold(
                          body: Center(child: Text('该记录无法用当前主密钥解密')),
                        );
                      }
                    },
                  ),
                );
                if (ok == true && mounted) setState(() {});
              },
            ),
          ),
        );
      },
    );
  }
}

// ===================== 编辑页 =====================

class EditPasswordPage extends StatefulWidget {
  const EditPasswordPage({super.key, required this.existing});

  final PasswordEntry existing;

  @override
  State<EditPasswordPage> createState() => _EditPasswordPageState();
}

class _EditPasswordPageState extends State<EditPasswordPage> {
  late final TextEditingController _website;
  late final TextEditingController _username;
  late final TextEditingController _password;
  bool _showPw = false;

  @override
  void initState() {
    super.initState();
    _website = TextEditingController(text: widget.existing.website);
    _username = TextEditingController(text: widget.existing.username);
    _password = TextEditingController(text: widget.existing.password);
  }

  @override
  void dispose() {
    _website.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    final beforeOk = await _maybePromptPull(context);
    if (!beforeOk) return;

    await app.vault.update(
      id: widget.existing.id,
      website: _website.text.trim(),
      username: _username.text.trim(),
      plaintextPassword: _password.text,
      masterKey: app.masterKey,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已更新')),
    );
    await _maybePromptPush(context);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除 ${_website.text} 的这条记录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final app = context.read<AppState>();
    final beforeOk = await _maybePromptPull(context);
    if (!beforeOk) return;
    await app.vault.deleteById(widget.existing.id);
    if (!context.mounted) return;
    await _maybePromptPush(context);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _website,
              decoration: const InputDecoration(
                labelText: '网址',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: '用户名',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: !_showPw,
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.key_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showPw
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showPw = !_showPw),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== 同步提示工具 =====================

/// 操作前提示。返回 false 表示用户取消整个操作。
Future<bool> _maybePromptPull(BuildContext context) async {
  final app = context.read<AppState>();
  if (!app.settings.cloudEnabled) return true;
  if (!app.settings.promptBeforeEdit) return true;
  if (app.sessionSkip.skipBefore) return true;
  // 智能跳过：远端无更新且智能跳过开
  if (app.settings.smartSkip && app.sync.remoteHasUpdates == false) {
    return true;
  }

  final choice = await showPullPrompt(context);
  if (choice == PromptChoice.cancel) return false;
  if (choice == PromptChoice.confirm) {
    await app.sync.pullAndMerge();
  }
  return true;
}

Future<void> _maybePromptPush(BuildContext context) async {
  final app = context.read<AppState>();
  if (!app.settings.cloudEnabled) return;
  if (!app.settings.promptAfterEdit) return;
  if (app.sessionSkip.skipAfter) {
    // 静默推（fire-and-forget）
    unawaited(app.sync.pushAll());
    return;
  }
  final choice = await showPushPrompt(context);
  if (choice == PromptChoice.confirm) {
    await app.sync.pushAll();
  }
}
