import 'dart:async';

import 'package:flutter/foundation.dart';

import 'crypto/vault_cipher.dart';
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

  VaultCipher? _cipher;

  bool get isUnlocked => _cipher != null;

  /// 当前会话的加解密器；未解锁时抛错。
  VaultCipher get cipher {
    final c = _cipher;
    if (c == null) throw StateError('未解锁');
    return c;
  }

  void unlock(String masterPassword) {
    final c = VaultCipher(masterPassword);
    _cipher = c;
    notifyListeners();
    // 后台预热各盐对应的密钥，避免解锁后前几次复制卡在 PBKDF2 上。
    _warmUpKeys(c);
  }

  /// 枚举库里所有密文用到的（盐, 迭代次数），在后台 isolate 里一次性派生好密钥。
  /// 纯优化，失败静默忽略（按需派生的老路径仍可用）。
  void _warmUpKeys(VaultCipher c) {
    final params = <({Uint8List salt, int iterations})>[];
    for (final r in vault.index.activeRecords) {
      final ct = r.encryptedPassword;
      if (ct == null) continue;
      final tp = VaultCipher.tokenParams(ct);
      if (tp != null) params.add(tp);
    }
    if (params.isEmpty) return;
    unawaited(c.warmUp(params).catchError((_) {}));
  }

  /// 热更换当前会话使用的主密钥（不重新加密已有条目）。
  /// 仅影响之后的加密/解密：之前用旧密钥写入的条目仍需旧密钥才能解密。
  void rekey(String newMasterPassword) {
    _cipher = VaultCipher(newMasterPassword);
    notifyListeners();
  }

  void lock() {
    _cipher = null;
    notifyListeners();
  }
}
