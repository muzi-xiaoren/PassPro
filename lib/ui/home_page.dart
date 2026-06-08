import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PassPro'),
        actions: [
          const _SyncStatusBadge(),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          const _AccountMenu(),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(icon: const Icon(Icons.search), text: l10n.tabQuery),
            Tab(icon: const Icon(Icons.add_circle_outline), text: l10n.tabAdd),
            Tab(icon: const Icon(Icons.list_alt), text: l10n.tabList),
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

// ===================== 顶栏同步菜单 =====================

enum _SyncAction { pull, push, overwriteLocal, overwriteRemote }

/// 把 sync 层的语义化状态（[SyncStatus.msg] + arg + mirrors）渲染成本地化文案。
/// 主仓库 + 每个副仓库(mirror)的结果都会展示（修复"只提示主仓库"与"中英文混杂"）。
String? _syncStatusText(AppLocalizations l10n, SyncStatus s) {
  final msg = s.msg;
  if (msg == null) return null;
  final arg = s.arg ?? '';
  final primary = s.primaryBackend ?? '';

  String word(MirrorOutcome o) => switch (o) {
        MirrorOutcome.ok => l10n.syncMirrorOk,
        MirrorOutcome.conflict => l10n.syncMirrorConflict,
        MirrorOutcome.failed => l10n.syncMirrorFailed,
      };

  // 副仓库逐个结果（失败附原因）："· 副仓库: gitee (失败: ...), webdav (成功)"。
  String mirrorsPart() {
    if (s.mirrors.isEmpty) return '';
    final summary = s.mirrors.map((m) {
      final extra =
          (m.outcome == MirrorOutcome.failed && (m.detail?.isNotEmpty ?? false))
              ? ': ${m.detail}'
              : '';
      return '${m.backend} (${word(m.outcome)}$extra)';
    }).join(', ');
    return ' · ${l10n.syncMirrorsLabel}: $summary';
  }

  // 主仓库结果统一呈现为"主仓库 <后端> (<结果>)"，每个结果都明确说明（含失败/冲突原因）。
  switch (msg) {
    case SyncMsg.pushedToPrimary:
    case SyncMsg.overwroteRemoteWithLocal:
      return l10n.syncPrimaryResult(primary, word(MirrorOutcome.ok)) +
          mirrorsPart();
    case SyncMsg.primaryPushFailed:
    case SyncMsg.primaryOverwriteFailed:
    case SyncMsg.primaryOffline:
      return '${l10n.syncPrimaryResult(primary, word(MirrorOutcome.failed))}: $arg';
    case SyncMsg.pushConflictManual:
    case SyncMsg.overwriteRemoteStillChanging:
      return l10n.syncPrimaryResult(primary, word(MirrorOutcome.conflict));
    case SyncMsg.noPrimary:
      return l10n.syncNoPrimary;
    case SyncMsg.pulledFrom:
      return l10n.syncPulledFrom(arg);
    case SyncMsg.allBackendsPullFailed:
      return l10n.syncAllBackendsPullFailed(arg);
    case SyncMsg.remoteEmptySkipped:
      return l10n.syncRemoteEmptySkipped;
    case SyncMsg.overwroteLocalFrom:
      return l10n.syncOverwroteLocalFrom(arg);
    case SyncMsg.genericError:
      return l10n.syncGenericError(arg);
  }
}

class _SyncStatusBadge extends StatelessWidget {
  const _SyncStatusBadge();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncManager>();
    final s = sync.status;
    final enabled = context.read<AppState>().settings.cloudEnabled;
    if (!enabled) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final (icon, color, label) = switch (s.state) {
      SyncState.idle => (Icons.cloud_outlined, null, l10n.syncIdle),
      SyncState.working => (Icons.sync, Colors.blue, l10n.syncWorking),
      SyncState.ok => (Icons.cloud_done_outlined, Colors.green, l10n.syncOk),
      SyncState.offline =>
        (Icons.cloud_off_outlined, Colors.orange, l10n.syncOffline),
      SyncState.error => (Icons.error_outline, Colors.red, l10n.syncError),
    };

    return PopupMenuButton<_SyncAction>(
      tooltip: _syncStatusText(l10n, s) ?? label,
      icon: Icon(icon, color: color),
      onSelected: (a) => _onAction(context, a),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _SyncAction.pull,
          child: _row(Icons.cloud_download_outlined, l10n.syncPull),
        ),
        PopupMenuItem(
          value: _SyncAction.push,
          child: _row(Icons.cloud_upload_outlined, l10n.syncPush),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _SyncAction.overwriteLocal,
          child: _row(Icons.download_for_offline_outlined,
              l10n.syncOverwriteLocal),
        ),
        PopupMenuItem(
          value: _SyncAction.overwriteRemote,
          child: _row(Icons.cloud_sync_outlined, l10n.syncOverwriteRemote),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(text),
        ],
      );

  Future<void> _onAction(BuildContext context, _SyncAction action) async {
    final l10n = AppLocalizations.of(context)!;
    final app = context.read<AppState>();
    final sync = app.sync;
    final isOverwrite = action == _SyncAction.overwriteLocal ||
        action == _SyncAction.overwriteRemote;

    // 覆盖操作二次确认
    if (isOverwrite) {
      final file = app.settings.primaryBackend?.filePath ?? 'passwords.log';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action == _SyncAction.overwriteLocal
              ? l10n.syncOverwriteLocal
              : l10n.syncOverwriteRemote),
          content: Text(action == _SyncAction.overwriteLocal
              ? l10n.syncOverwriteLocalConfirm(file)
              : l10n.syncOverwriteRemoteConfirm(file)),
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
    }
    if (!context.mounted) return;

    // 阻塞式等待界面（推送/拉取/覆盖期间）
    final nav = Navigator.of(context, rootNavigator: true);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    ));

    try {
      switch (action) {
        case _SyncAction.pull:
          await sync.pullAndMerge();
        case _SyncAction.push:
          await sync.pushAll();
        case _SyncAction.overwriteLocal:
          await sync.overwriteLocalWithRemote();
        case _SyncAction.overwriteRemote:
          await sync.overwriteRemoteWithLocal();
      }
    } finally {
      nav.pop(); // 关闭等待框
    }
    if (!context.mounted) return;

    // 结果以最终状态为准：error/offline 视为失败，其余为成功
    final st = sync.status;
    final failed =
        st.state == SyncState.error || st.state == SyncState.offline;
    final statusText = _syncStatusText(l10n, st);
    final okMsg = statusText ??
        switch (action) {
          _SyncAction.overwriteLocal => l10n.overwroteLocal,
          _SyncAction.overwriteRemote => l10n.overwroteRemote,
          _ => l10n.syncOk,
        };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failed ? (statusText ?? l10n.syncError) : okMsg)),
    );
  }
}

// ===================== 顶栏账户菜单（锁定 / 更换密钥） =====================

enum _AccountAction { changeKey, lock }

class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<_AccountAction>(
      icon: const Icon(Icons.lock_outline),
      tooltip: l10n.accountMenu,
      onSelected: (a) async {
        switch (a) {
          case _AccountAction.changeKey:
            await showDialog<void>(
              context: context,
              builder: (_) => const _ChangeKeyDialog(),
            );
          case _AccountAction.lock:
            context.read<AppState>().lock();
            Navigator.of(context).popUntil((r) => r.isFirst);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _AccountAction.changeKey,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.key_outlined, size: 20),
              const SizedBox(width: 12),
              Text(l10n.changeMasterKey),
            ],
          ),
        ),
        PopupMenuItem(
          value: _AccountAction.lock,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 20),
              const SizedBox(width: 12),
              Text(l10n.lock),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChangeKeyDialog extends StatefulWidget {
  const _ChangeKeyDialog();

  @override
  State<_ChangeKeyDialog> createState() => _ChangeKeyDialogState();
}

class _ChangeKeyDialogState extends State<_ChangeKeyDialog> {
  final _key = TextEditingController();
  final _confirm = TextEditingController();
  late bool _obscure;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 与解锁页共用“是否默认明文可见”偏好
    _obscure = !context.read<AppState>().settings.masterKeyVisible;
  }

  @override
  void dispose() {
    _key.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    // 与解锁一致：留空 → 单空格
    final newPw = _key.text.isEmpty ? ' ' : _key.text;
    final confirmPw = _confirm.text.isEmpty ? ' ' : _confirm.text;
    if (newPw != confirmPw) {
      setState(() => _error = l10n.masterKeyMismatch);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    context.read<AppState>().rekey(newPw);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.masterKeyChanged)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.changeMasterKey),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _key,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.newMasterKey,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscure ? l10n.show : l10n.hide,
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () {
                  setState(() => _obscure = !_obscure);
                  context
                      .read<AppState>()
                      .settings
                      .setMasterKeyVisible(!_obscure);
                },
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.confirmNewMasterKey,
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          Text(
            l10n.changeMasterKeyHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
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
    final l10n = AppLocalizations.of(context)!;
    final r = app.vault.query(_ctrl.text.trim(), app.masterKey);
    setState(() {
      _result = r;
      _emptyMessage = r.invalidKey
          ? l10n.queryInvalidKey
          : (r.isEmpty ? l10n.queryNoMatch : null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              labelText: l10n.queryFieldLabel,
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
      return Center(
        child: Text(AppLocalizations.of(context)!.queryPrompt),
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
    final l10n = AppLocalizations.of(context)!;
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
                  tooltip: l10n.edit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(context),
                ),
                IconButton(
                  tooltip: l10n.delete,
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
                      tooltip: l10n.copyUsername,
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () =>
                          _copy(widget.entry.username, l10n.usernameCopied),
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
                  tooltip: _show ? l10n.hide : l10n.show,
                  icon: Icon(
                    _show
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _show = !_show),
                ),
                IconButton(
                  tooltip: l10n.copyPassword,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () =>
                      _copy(widget.entry.password, l10n.passwordCopied),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _copy(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
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
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.deleteBody(widget.entry.website)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.delete),
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
      SnackBar(content: Text(l10n.deleted)),
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
    final l10n = AppLocalizations.of(context)!;
    final w = _website.text.trim();
    final pw = _password.text;
    if (w.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.websitePasswordEmpty)),
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
      SnackBar(content: Text(ok ? l10n.saved : l10n.duplicateEntry)),
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
    final l10n = AppLocalizations.of(context)!;
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
                  Text(l10n.generatePassword,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _length,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.length,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _generate,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.generate),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: Text(l10n.charUpper),
                        selected: _upper,
                        onSelected: (v) => setState(() => _upper = v),
                      ),
                      FilterChip(
                        label: Text(l10n.charLower),
                        selected: _lower,
                        onSelected: (v) => setState(() => _lower = v),
                      ),
                      FilterChip(
                        label: Text(l10n.charDigits),
                        selected: _digits,
                        onSelected: (v) => setState(() => _digits = v),
                      ),
                      FilterChip(
                        label: Text(l10n.charSpecial),
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
                  Text(l10n.saveToVault,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _website,
                    decoration: InputDecoration(
                      labelText: l10n.websiteRequired,
                      prefixIcon: const Icon(Icons.link),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _username,
                    decoration: InputDecoration(
                      labelText: l10n.usernameOptional,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: l10n.passwordRequired,
                      prefixIcon: const Icon(Icons.key_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(l10n.save),
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

enum _ListSort { nameAsc, nameDesc, timeDesc, timeAsc }

class _ListTab extends StatefulWidget {
  const _ListTab();

  @override
  State<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<_ListTab> {
  late _ListSort _sort;

  @override
  void initState() {
    super.initState();
    _sort = _sortFromName(context.read<AppState>().settings.listSort);
  }

  _ListSort _sortFromName(String name) => _ListSort.values.firstWhere(
        (e) => e.name == name,
        orElse: () => _ListSort.nameAsc,
      );

  int _compare(LogRecord a, LogRecord b) {
    switch (_sort) {
      case _ListSort.nameAsc:
        return (a.website ?? '')
            .toLowerCase()
            .compareTo((b.website ?? '').toLowerCase());
      case _ListSort.nameDesc:
        return (b.website ?? '')
            .toLowerCase()
            .compareTo((a.website ?? '').toLowerCase());
      case _ListSort.timeDesc:
        return b.ts.compareTo(a.ts);
      case _ListSort.timeAsc:
        return a.ts.compareTo(b.ts);
    }
  }

  String _sortLabel(AppLocalizations l10n, _ListSort s) {
    switch (s) {
      case _ListSort.nameAsc:
        return l10n.sortNameAsc;
      case _ListSort.nameDesc:
        return l10n.sortNameDesc;
      case _ListSort.timeDesc:
        return l10n.sortTimeDesc;
      case _ListSort.timeAsc:
        return l10n.sortTimeAsc;
    }
  }

  /// 点击条目区域：主密钥可解密则直接复制密码到剪贴板，否则提示。
  void _copyPassword(LogRecord r) {
    final app = context.read<AppState>();
    final l10n = AppLocalizations.of(context)!;
    try {
      final pw = app.vault.index.decryptPassword(r, app.masterKey);
      Clipboard.setData(ClipboardData(text: pw));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.passwordCopied),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.decryptFailedCopy)),
      );
    }
  }

  /// 打开详情/编辑页；主密钥错误时进入带返回按钮的提示页（macOS 也能返回）。
  Future<void> _openDetail(LogRecord r) async {
    final app = context.read<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) {
          try {
            final entry = PasswordEntry(
              id: r.id,
              website: r.website ?? '',
              username: r.username ?? '',
              password: app.vault.index.decryptPassword(r, app.masterKey),
              updatedAt: r.ts,
            );
            return EditPasswordPage(existing: entry);
          } catch (_) {
            return Scaffold(
              appBar: AppBar(title: Text(l10n.cannotDecrypt)),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.cannotDecryptBody,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
    if (ok == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    final records = app.vault.index.activeRecords.toList(growable: false)
      ..sort(_compare);

    if (records.isEmpty) {
      return Center(child: Text(l10n.emptyVault));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Text(
                l10n.totalCount(records.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              PopupMenuButton<_ListSort>(
                initialValue: _sort,
                tooltip: l10n.sortTooltip,
                onSelected: (v) {
                  setState(() => _sort = v);
                  context.read<AppState>().settings.setListSort(v.name);
                },
                itemBuilder: (_) => [
                  for (final s in _ListSort.values)
                    PopupMenuItem(value: s, child: Text(_sortLabel(l10n, s))),
                ],
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort, size: 18),
                      const SizedBox(width: 4),
                      Text(_sortLabel(l10n, _sort)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
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
                    (r.username ?? '').isEmpty ? l10n.noUsername : r.username!,
                  ),
                  onTap: () => _copyPassword(r),
                  trailing: IconButton(
                    tooltip: l10n.edit,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openDetail(r),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
    final l10n = AppLocalizations.of(context)!;
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
      SnackBar(content: Text(l10n.updated)),
    );
    await _maybePromptPush(context);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.deleteBody(_website.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.edit),
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
              decoration: InputDecoration(
                labelText: l10n.website,
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              decoration: InputDecoration(
                labelText: l10n.username,
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: !_showPw,
              decoration: InputDecoration(
                labelText: l10n.password,
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
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.save),
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
