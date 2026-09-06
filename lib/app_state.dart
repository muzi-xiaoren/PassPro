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
  }) {
    // 开了云同步时，迁移要等这台机器和远端对齐之后才敢做（见 [_readyToMigrate]）。
    // 解锁那一刻往往还没拉完，所以同步状态一变就再判一次。
    sync.addListener(_onSyncChanged);
  }

  @override
  void dispose() {
    sync.removeListener(_onSyncChanged);
    super.dispose();
  }

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
  /// 迁移过的库走 keyring：拿主密钥拆开那一小块取出库密钥，**恒定 1 次 PBKDF2**，
  /// 而且 GCM 认证标签直接判定密钥对不对，不用再拿"有没有一条记录解得开"去猜。
  /// 之后解密任何记录都是纯 AES，零 PBKDF2——库里有 100 条还是 1 万条都一样快。
  ///
  /// 还没迁移的老库走 [_unlockLegacy]。
  Future<bool> unlock(String masterPassword) async {
    final blob = vault.keyring;
    if (blob == null) return _unlockLegacy(masterPassword);

    Uint8List? vk;
    try {
      vk = await VaultCipher.unwrapVaultKeyAsync(masterPassword, blob);
    } catch (_) {
      // isolate 起不来（极少数平台/沙箱）就地兜底，慢一点也得让人进得去。
      vk = VaultCipher.unwrapVaultKey(masterPassword, blob);
    }
    if (vk == null) return false; // 主密钥不对，精确判定
    _cipher = VaultCipher(masterPassword, vaultKey: vk);
    notifyListeners();
    _scheduleMigration(); // 还有 v1 老记录就后台转
    return true;
  }

  /// 老库（还没有 keyring）的解锁：主密钥不落盘，也没有 keyring 可比对，
  /// 只能拿"库里至少有一条记录能被这把密钥解开"来判定。
  Future<bool> _unlockLegacy(String masterPassword) async {
    final tokens = _activeTokens();
    final probe =
        VaultCipher(masterPassword, legacyWriteSalt: _dominantSalt(tokens));
    if (!await _verifyLegacy(probe, tokens)) return false;
    _cipher = probe;
    notifyListeners();
    // 主密钥验过了 → 立刻建库密钥并开始迁移（条件不满足就留到对齐之后）。
    _scheduleMigration();
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
  Future<bool> _verifyLegacy(VaultCipher c, List<String> tokens) async {
    if (tokens.isEmpty) return true;
    // 一条都不是本格式的密文（文件损坏 / 导入了别的东西）：没有可校验的对象，
    // 放行。否则用户会被永久关在解锁页外面，连导入导出都点不到。
    if (!tokens.any((t) => VaultCipher.tokenParams(t) != null)) return true;
    final sameSalt = [
      for (final t in tokens)
        if (c.usesLegacyWriteParams(t)) t,
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

  // ==================== 迁移到库密钥（一次性） ====================

  /// 后台迁移任务；换主密钥前要等它跑完，否则两边同时重写同一批记录。
  /// 非 null 表示本次会话已经起过（跑完也不再重复起）。
  Future<void>? _migrating;

  /// 仅用于测试：等待后台迁移跑完（没起过时为 null）。
  @visibleForTesting
  Future<void>? get pendingMaintenance => _migrating;

  void _onSyncChanged() => _scheduleMigration();

  /// 起一次后台迁移；条件不满足就什么都不做，留到下次（同步完成 / 下次启动）。
  void _scheduleMigration() {
    if (_migrating != null) return; // 本会话已经起过
    final c = _cipher;
    if (c == null) return;
    if (c.hasVaultKey && !_hasLegacyRecords()) return; // 已经全是 v2 了
    if (!_readyToMigrate()) return;
    final f = _migrate(c);
    _migrating = f;
    unawaited(f);
  }

  bool _hasLegacyRecords() =>
      _activeTokens().any(VaultCipher.isLegacyToken);

  /// 迁移要么新建 keyring、要么以 ts=now 重写记录，按"时间戳新的胜出"的合并
  /// 规则，它会盖过远端**还没拉下来**的更新；更要命的是两台机器各自建一把库
  /// 密钥、各自把记录转过去，合并之后只有一把 keyring 活下来，另一台转过的
  /// 记录就全废了。所以开了云同步必须先和远端对齐过一次才敢动手；没开云同步
  /// 的本地库随便迁。（迁移只是优化，晚一轮不影响任何功能。）
  bool _readyToMigrate() {
    if (!settings.cloudEnabled) return true;
    if (sync.status.state == SyncState.working) return false;
    return sync.status.lastSyncAt != null;
  }

  Future<void> _migrate(VaultCipher c) async {
    if (!identical(_cipher, c)) return; // 期间被锁定/换过密钥就别写了
    try {
      var cipher = c;
      if (!cipher.hasVaultKey) {
        // 迁移前先把原件留一份，万一中途出岔子人手上还有迁移前的日志。
        await vault.backupBeforeMigration();
        final vk = VaultCipher.newVaultKey();
        final blob = await cipher.wrapVaultKeyWithOwnPassword(vk);
        if (!identical(_cipher, c)) return;
        await vault.writeKeyring(blob);
        cipher = cipher.upgraded(vk);
        _cipher = cipher;
        notifyListeners();
      }
      await vault.migrateToVaultKey(cipher);
    } catch (_) {
      // 迁移只是优化，失败不影响使用，下次启动再试。
    }
  }

  /// 挑库里用得最多的那个盐当本会话的 v1 写盐（迁移完就用不上了）。
  ///
  /// 老版本每个 VaultCipher 实例都随机生成写盐，于是"每有一次会话写入就多一个
  /// 盐"，解锁预热要跑的 PBKDF2 次数随使用时间线性增长。复用最主流的那个盐
  /// 能把预热压回 1 次。老记录各自带盐，照样解得开。
  ///
  /// 计数相同时按盐的字节序取最小的那个——多设备各自处理时要选出同一个盐。
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

  // ==================== 换主密钥 ====================

  /// 更换主密钥：拿新主密钥把**同一把库密钥**重新包一遍，只重写 keyring 那一行。
  /// 记录一条都不用动，所以是 O(1)，几毫秒的事。
  ///
  /// 换之前会先把剩下的 v1 老记录转完——不转的话它们只认老主密钥，换完就再也
  /// 读不出来了。老主密钥都解不开的记录（比如曾经用错密钥存进去的）原样保留，
  /// 并在 [RekeyResult.leftBehind] 里如实上报。
  ///
  /// 库还没迁移（开了云同步但本次会话还没跟远端对齐）时返回
  /// [RekeyResult.needsSync]，让用户先同步一次——这时候换密钥要重写整库，
  /// 和别的设备撞上就会把数据搅乱。
  Future<RekeyResult> rekey(String newMasterPassword) async {
    try {
      await _migrating; // 等后台迁移落地，避免两条写路径互相覆盖
    } catch (_) {
      // 迁移失败不影响换密钥
    }
    final from = _cipher;
    if (from == null) throw StateError('未解锁');
    if (!from.hasVaultKey) return const RekeyResult.needsSync();

    final report = await vault.migrateToVaultKey(from);
    final vk = from.vaultKey!;
    final blob = await VaultCipher.wrapVaultKeyAsync(newMasterPassword, vk);
    await vault.writeKeyring(blob);
    _cipher = VaultCipher(newMasterPassword, vaultKey: vk);
    notifyListeners();
    return RekeyResult.ok(report.skipped);
  }

  void lock() {
    _cipher = null;
    _migrating = null; // 下次解锁（可能换了密钥）要能重新起迁移
    notifyListeners();
  }
}

/// 换主密钥的结果。
class RekeyResult {
  /// false = 没换成，需要先同步一次（库还没迁移到库密钥）。
  final bool ok;

  /// 老主密钥也解不开、原样留下的记录条数（换完之后它们仍只认老主密钥）。
  final int leftBehind;

  const RekeyResult.ok(this.leftBehind) : ok = true;
  const RekeyResult.needsSync()
      : ok = false,
        leftBehind = 0;
}
