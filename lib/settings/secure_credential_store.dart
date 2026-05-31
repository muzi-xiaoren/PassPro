import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_settings.dart';

/// PAT 走 OS Keychain：Android Keystore / macOS Keychain / Windows DPAPI。
class SecureCredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(BackendKind kind) =>
      kind == BackendKind.github ? 'pat_github' : 'pat_gitee';

  Future<String?> readPat(BackendKind kind) =>
      _storage.read(key: _key(kind));

  Future<void> writePat(BackendKind kind, String pat) =>
      _storage.write(key: _key(kind), value: pat);

  Future<void> deletePat(BackendKind kind) =>
      _storage.delete(key: _key(kind));

  Future<bool> hasPat(BackendKind kind) async =>
      (await readPat(kind))?.isNotEmpty ?? false;
}
