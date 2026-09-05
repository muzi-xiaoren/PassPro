import 'dart:convert';

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

  /// 解锁并**等待**密钥预热完成后才返回。
  ///
  /// 以前这里是 fire-and-forget：解锁立刻放行进主界面，预热 isolate 还在后台
  /// 算 PBKDF2 时用户已经在查询框打字、点条目了，主线程只好自己再同步算一遍
  /// （每个盐 ~0.6-1.2s / 手机），和预热 isolate 抢 CPU，几秒无响应直接被
  /// Android 当 ANR 杀掉。改成解锁页转圈等它算完，之后所有路径必然命中缓存。
  Future<void> unlock(String masterPassword) async {
    _cipher = await _newCipher(masterPassword);
    notifyListeners();
  }

  /// 建会话加解密器：写盐复用库里最常见的那个（见下），然后等预热完成。
  Future<VaultCipher> _newCipher(String password) async {
    final tokens = [
      for (final r in vault.index.activeRecords) r.encryptedPassword,
    ];
    final c = VaultCipher(password, writeSalt: _dominantSalt(tokens));
    try {
      await c.warmUpForTokens(tokens);
    } catch (_) {
      // 预热失败不影响可用性，只是会退回按需派生。
    }
    return c;
  }

  /// 挑库里用得最多的那个盐当本会话写盐。
  ///
  /// 以前每个 VaultCipher 实例都随机生成写盐，于是"每有一次会话写入就多一个
  /// 盐"，解锁预热要跑的 PBKDF2 次数随使用时间线性增长。复用最主流的那个盐
  /// 能让库随使用逐步收敛到单盐，预热稳定在 1 次。老记录各自带盐，照样解得开。
  static Uint8List? _dominantSalt(List<String?> tokens) {
    final counts = <String, ({Uint8List salt, int n})>{};
    for (final t in tokens) {
      if (t == null || t.isEmpty) continue;
      final p = VaultCipher.tokenParams(t);
      if (p == null || p.iterations != VaultCipher.defaultIterations) continue;
      final k = base64Url.encode(p.salt);
      counts[k] = (salt: p.salt, n: (counts[k]?.n ?? 0) + 1);
    }
    if (counts.isEmpty) return null;
    var best = counts.values.first;
    for (final v in counts.values) {
      if (v.n > best.n) best = v;
    }
    return best.salt;
  }

  /// 热更换当前会话使用的主密钥（不重新加密已有条目）。
  /// 仅影响之后的加密/解密：之前用旧密钥写入的条目仍需旧密钥才能解密。
  /// 同样等预热完成——新密钥下老条目多半解不开，但盐相同的那部分要预热掉。
  Future<void> rekey(String newMasterPassword) async {
    _cipher = await _newCipher(newMasterPassword);
    notifyListeners();
  }

  void lock() {
    _cipher = null;
    notifyListeners();
  }
}
