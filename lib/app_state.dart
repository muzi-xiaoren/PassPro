import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'crypto/fernet_crypto.dart';
import 'settings/app_settings.dart';
import 'settings/secure_credential_store.dart';
import 'storage/compactor.dart';
import 'storage/vault_repository.dart';
import 'sync/sync_manager.dart';

/// 整个 app 共享的运行时状态：主密钥（内存）+ 仓库 + 设置 + 同步。
/// 通过 Provider 注入到 UI。
class AppState extends ChangeNotifier {
  AppState({
    required this.vault,
    required this.settings,
    required this.credentials,
    required this.sync,
    required this.compactor,
  });

  final VaultRepository vault;
  final AppSettings settings;
  final SecureCredentialStore credentials;
  final SyncManager sync;
  final Compactor compactor;
  final SessionPromptSkip sessionSkip = SessionPromptSkip();

  Uint8List? _masterKey;
  String? _masterPasswordDisplay; // 仅供主界面顶部回显

  bool get isUnlocked => _masterKey != null;
  Uint8List get masterKey {
    final k = _masterKey;
    if (k == null) throw StateError('未解锁');
    return k;
  }

  String get masterPasswordDisplay => _masterPasswordDisplay ?? '';

  void unlock(String masterPassword) {
    _masterPasswordDisplay = masterPassword;
    _masterKey = FernetCrypto.deriveKey(masterPassword);
    notifyListeners();
  }

  void lock() {
    _masterKey = null;
    _masterPasswordDisplay = null;
    notifyListeners();
  }
}
