import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'home_page.dart';

class MasterKeyPage extends StatefulWidget {
  const MasterKeyPage({super.key});

  @override
  State<MasterKeyPage> createState() => _MasterKeyPageState();
}

class _MasterKeyPageState extends State<MasterKeyPage> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _unlock() {
    final pw = _ctrl.text.isEmpty ? ' ' : _ctrl.text;
    context.read<AppState>().unlock(pw);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  'Passman Pro',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '请输入主密钥',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _ctrl,
                  obscureText: _obscure,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _unlock(),
                  decoration: InputDecoration(
                    labelText: 'Master Key',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _unlock,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('解锁'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '主密钥不会被保存，每次启动需要重新输入。\n留空将以单空格作为主密钥（与旧版兼容）。',
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
