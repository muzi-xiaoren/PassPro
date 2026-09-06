import 'dart:async';
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

  /// 解锁：主密钥正确返回 true，错误返回 false（不进入主界面）。
  ///
  /// 判定方式是"库里至少有一条记录能被这把密钥解开"——主密钥本身不落盘，
  /// 也就没有校验串可比对。空库（或全是无密文的记录）时任何主密钥都算合法。
  ///
  /// 只在**主流盐**上派生一次密钥就够判定（正确密钥走这条快路，一次
  /// PBKDF2 ~0.2s/桌面）。以前这里等的是"全部盐都预热完"，老库里一次会话
  /// 一个盐、攒了十几二十个盐，Windows 上就要卡十几秒才能进去。
  /// 剩下的盐挪到进主界面之后在后台补，并顺手把它们收敛掉（见 [_warmRestAndConverge]）。
  Future<bool> unlock(String masterPassword) async {
    final tokens = _activeTokens();
    final c = VaultCipher(masterPassword, writeSalt: _dominantSalt(tokens));
    if (!await _verify(c, tokens)) return false;
    _cipher = c;
    notifyListeners();
    _converging = _warmRestAndConverge(c);
    unawaited(_converging);
    return true;
  }

  List<String> _activeTokens() => [
        for (final r in vault.index.activeRecords)
          if (r.encryptedPassword case final ct?)
            if (ct.isNotEmpty) ct,
      ];

  /// 至少能解开一条 → 主密钥正确。先只试主流盐那批（1 次 PBKDF2），
  /// 试不通才把剩下的盐补齐再判一次——那是密钥真的错了或者库里混了多把
  /// 密钥的少数情况，慢一点可以接受。
  Future<bool> _verify(VaultCipher c, List<String> tokens) async {
    if (tokens.isEmpty) return true;
    final sameSalt = [
      for (final t in tokens)
        if (c.usesWriteParams(t)) t,
    ];
    if (sameSalt.isNotEmpty) {
      await _warm(c, sameSalt);
      if (_anyDecrypts(c, sameSalt)) return true;
    }
    await _warm(c, tokens);
    return _anyDecrypts(c, tokens);
  }

  static Future<void> _warm(VaultCipher c, List<String> tokens) async {
    try {
      await c.warmUpForTokens(tokens);
    } catch (_) {
      // 预热失败（isolate 起不来等）不影响正确性，只是会退回按需派生。
    }
  }

  static bool _anyDecrypts(VaultCipher c, List<String> tokens) {
    for (final t in tokens) {
      try {
        c.decrypt(t);
        return true;
      } on CryptoException {
        // 这条解不开，继续试下一条
      }
    }
    return false;
  }

  /// 后台盐收敛任务；换主密钥前要等它跑完，否则两边同时重写同一批记录。
  Future<void>? _converging;

  /// 仅用于测试：等待解锁后的后台盐收敛跑完。
  @visibleForTesting
  Future<void>? get pendingMaintenance => _converging;

  /// 进主界面之后的后台收尾：把剩余的盐预热掉，再把它们统一重加密成写盐。
  /// 收敛一次之后库里只剩一个盐，之后每次解锁都只需要一次 PBKDF2。
  Future<void> _warmRestAndConverge(VaultCipher c) async {
    if (_activeTokens().every(c.usesWriteParams)) return;
    if (!identical(_cipher, c)) return; // 期间被锁定/换过密钥就别写了
    try {
      // reencrypt 内部会把要动的记录的密钥先在后台派生好。
      await vault.reencrypt(from: c, to: c, onlyStale: true);
    } catch (_) {
      // 收敛只是优化，失败不影响使用，下次启动再试。
    }
  }

  /// 挑库里用得最多的那个盐当本会话写盐。
  ///
  /// 以前每个 VaultCipher 实例都随机生成写盐，于是"每有一次会话写入就多一个
  /// 盐"，解锁预热要跑的 PBKDF2 次数随使用时间线性增长。复用最主流的那个盐
  /// 能让库随使用逐步收敛到单盐，预热稳定在 1 次。老记录各自带盐，照样解得开。
  ///
  /// 计数相同时按盐的字节序取最小的那个——多设备各自收敛时要选出同一个盐，
  /// 否则 A 收敛成盐 1、B 收敛成盐 2，同步过去互相判定为"陈旧"来回重写。
  static Uint8List? _dominantSalt(List<String> tokens) {
    final counts = <String, ({Uint8List salt, int n})>{};
    for (final t in tokens) {
      final p = VaultCipher.tokenParams(t);
      if (p == null || p.iterations != VaultCipher.defaultIterations) continue;
      final k = base64Url.encode(p.salt);
      counts[k] = (salt: p.salt, n: (counts[k]?.n ?? 0) + 1);
    }
    if (counts.isEmpty) return null;
    String? bestKey;
    ({Uint8List salt, int n})? best;
    for (final e in counts.entries) {
      if (best == null ||
          e.value.n > best.n ||
          (e.value.n == best.n && e.key.compareTo(bestKey!) < 0)) {
        best = e.value;
        bestKey = e.key;
      }
    }
    return best!.salt;
  }

  /// 更换主密钥：用新密钥把整库重新加密一遍。
  ///
  /// 以前这里只换了会话密钥、不动已有密文，于是换完之后老条目仍归旧密钥、
  /// 新写入归新密钥，同一个库里混着两把钥匙谁也打不全。现在整库重写，
  /// 换完之后库里只有新密钥一把（旧密钥解不开的条目原样保留并如实上报）。
  Future<ReencryptReport> rekey(String newMasterPassword) async {
    try {
      await _converging; // 等后台收敛落地，避免两条写路径互相覆盖
    } catch (_) {
      // 收敛失败不影响换密钥
    }
    final from = _cipher;
    final to = VaultCipher(newMasterPassword); // 新密钥用全新随机盐
    await to.warmUpWriteKey();
    var report = const ReencryptReport(converted: 0, skipped: 0);
    if (from != null) {
      report = await vault.reencrypt(from: from, to: to, onlyStale: false);
    }
    _cipher = to;
    notifyListeners();
    return report;
  }

  void lock() {
    _cipher = null;
    notifyListeners();
  }
}
