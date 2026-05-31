import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'settings/app_settings.dart';
import 'settings/secure_credential_store.dart';
import 'storage/compactor.dart';
import 'storage/vault_repository.dart';
import 'sync/sync_manager.dart';
import 'ui/master_key_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = await AppSettings.load();
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

  // 启动后异步探测远端（"智能跳过"用）；失败静默。
  // ignore: discarded_futures
  sync.checkRemoteAsync();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: sync),
      ],
      child: const PassmanProApp(),
    ),
  );
}

class PassmanProApp extends StatelessWidget {
  const PassmanProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Passman Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          brightness: Brightness.dark,
        ),
      ),
      home: const MasterKeyPage(),
    );
  }
}
