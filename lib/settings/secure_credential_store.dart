import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_settings.dart';

/// PAT 走 OS Keychain：Android Keystore / macOS Keychain / Windows DPAPI。
class SecureCredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          // macOS：必须关掉“数据保护钥匙串”(data-protection keychain)。
          // 它是 iOS 风格钥匙串，强制要求签名里带 keychain-access-groups /
          // application-identifier 授权——adhoc 自签没有，会报 -34018。
          // 设为 false 改用传统“登录钥匙串”(file-based)，配合已关闭的沙盒，
          // 无需任何授权即可读写。iOS 不受影响（用各自的 iOptions 默认值）。
          mOptions: MacOsOptions(useDataProtectionKeyChain: false),
        );

  final FlutterSecureStorage _storage;

  static String _key(BackendKind kind) => switch (kind) {
        BackendKind.github => 'pat_github',
        BackendKind.gitee => 'pat_gitee',
        BackendKind.webdav => 'password_webdav',
      };

  Future<String?> readPat(BackendKind kind) =>
      _storage.read(key: _key(kind));

  Future<void> writePat(BackendKind kind, String pat) =>
      _storage.write(key: _key(kind), value: pat);

  Future<void> deletePat(BackendKind kind) =>
      _storage.delete(key: _key(kind));

  Future<bool> hasPat(BackendKind kind) async =>
      (await readPat(kind))?.isNotEmpty ?? false;
}
