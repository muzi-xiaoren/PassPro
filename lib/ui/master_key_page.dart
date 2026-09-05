import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';
import 'home_page.dart';

class MasterKeyPage extends StatefulWidget {
  const MasterKeyPage({super.key});

  @override
  State<MasterKeyPage> createState() => _MasterKeyPageState();
}

class _MasterKeyPageState extends State<MasterKeyPage> {
  final _ctrl = TextEditingController();
  late bool _obscure;
  // 解锁要等后台把各盐的密钥派生完（~0.2s/盐，手机上更久）。
  // 期间禁用按钮并转圈，避免用户进主界面后再撞上同步 PBKDF2。
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    // 恢复上次选择的“是否默认明文可见”
    _obscure = !context.read<AppState>().settings.masterKeyVisible;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_unlocking) return;
    final pw = _ctrl.text.isEmpty ? ' ' : _ctrl.text;
    final app = context.read<AppState>();
    final navigator = Navigator.of(context);
    setState(() => _unlocking = true);
    try {
      await app.unlock(pw);
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'PassPro',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.enterMasterKey,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _ctrl,
                  obscureText: _obscure,
                  autofocus: true,
                  enabled: !_unlocking,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _unlock(),
                  decoration: InputDecoration(
                    labelText: l10n.masterKeyLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
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
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _unlocking ? null : _unlock,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _unlocking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.unlock),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.masterKeyHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
