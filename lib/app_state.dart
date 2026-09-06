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

  /// 当前会话打开的那些 keyring 的记录 id（换主密钥时要逐把重新包）。
  List<String> _myKeyringIds = const [];

  /// 当前主密钥打开的密钥空间还没建 keyring（老库、还没迁移）时为 true。
  bool get hasKeySpace => _myKeyringIds.isNotEmpty;

  void _setSession(VaultCipher c, List<String> keyringIds) {
    _cipher = c;
    _myKeyringIds = keyringIds;
    notifyListeners();
  }

  /// 解锁 / 会话中途切换主密钥。
  ///
  /// 一个库可以装**多个密钥空间**：每把主密钥包着自己的库密钥（keyring），
  /// 只解得开自己那批记录，新存的也归自己。所以这里挨个试着拆库里的 keyring：
  ///
  ///   - 拆开了 → 进那个空间（拆一把 = 1 次 PBKDF2，一批扔进同一个 isolate）；
  ///   - 一把都没拆开，但有 v1 老记录能被这把主密钥解开 → 它是那批记录的主人，
  ///     照常放行，随后在后台把它们收进一个新建的空间；
  ///   - 空库首次使用 → 直接开一个空间，不用问；
  ///   - 其余情况 → [UnlockOutcome.unknownKey]，**不放行也不新建**，当前会话
  ///     原样保留（会话中途切换失败不该把人踢出去）。可能是输错了
  ///     一个字，也可能是真想开个新空间——交给 UI 问一句，答"新建"再走
  ///     [createKeySpace]。老版本这里是无条件放行，于是输错一个字就悄悄进了一个
  ///     空空间，存进去的东西全落在一把记不住的密钥下。
  Future<UnlockOutcome> unlock(String masterPassword) async {
    final keyrings = vault.keyrings;
    if (keyrings.isNotEmpty) {
      final ids = keyrings.keys.toList(growable: false);
      final blobs = [for (final id in ids) keyrings[id]!];
      final hits = await _unwrapAll(masterPassword, blobs);
      if (hits.isNotEmpty) {
        _migrating = null; // 换了个空间，后台迁移要按新空间重来
        _setSession(
          VaultCipher(
            masterPassword,
            vaultKey: hits.first.key,
            alsoDecryptWith: [for (final h in hits.skip(1)) h.key],
          ),
          [for (final h in hits) ids[h.index]],
        );
        _scheduleMigration(); // 认领本空间里还停在 v1 的老记录
        return UnlockOutcome.ok;
      }
    }

    // 没有 keyring 认这把主密钥：看看它是不是某批 v1 老记录的主人。
    final tokens = _activeTokens();
    final legacy = [
      for (final t in tokens)
        if (VaultCipher.isLegacyToken(t)) t,
    ];
    if (legacy.isNotEmpty) {
      final probe =
          VaultCipher(masterPassword, legacyWriteSalt: _dominantSalt(legacy));
      if (await _verifyLegacy(probe, legacy)) {
        _migrating = null;
        _setSession(probe, const []); // 先按 v1 读写，随后后台建 keyring
        _scheduleMigration();
        return UnlockOutcome.ok;
      }
    }

    // 全新的空库：第一次用，直接开个空间。
    if (keyrings.isEmpty && tokens.isEmpty) {
      await createKeySpace(masterPassword);
      return UnlockOutcome.ok;
    }
    return UnlockOutcome.unknownKey;
  }

  static Future<List<({int index, Uint8List key})>> _unwrapAll(
    String password,
    List<String> blobs,
  ) async {
    try {
      return await VaultCipher.unwrapAllAsync(password, blobs);
    } catch (_) {
      // isolate 起不来（极少数平台/沙箱）就地兜底，慢一点也得让人进得去。
      return [
        for (var i = 0; i < blobs.length; i++)
          if (VaultCipher.unwrapVaultKey(password, blobs[i]) case final k?)
            (index: i, key: k),
      ];
    }
  }

  /// 用这把主密钥新开一个密钥空间：生成一把新的库密钥、包成 keyring 写进日志。
  /// 之后存进去的记录都归这个空间，只有这把主密钥解得开；库里已有的其他条目
  /// 照常列出来（网站/账号本来就是明文），但解不开。
  Future<void> createKeySpace(String masterPassword) async {
    _migrating = null; // 换了个空间，后台迁移要按新空间重来
    final vk = VaultCipher.newVaultKey();
    final blob = await VaultCipher.wrapVaultKeyAsync(masterPassword, vk);
    final id = VaultRepository.newKeyringId();
    await vault.writeKeyring(id, blob);
    _setSession(VaultCipher(masterPassword, vaultKey: vk), [id]);
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
        final id = VaultRepository.newKeyringId();
        await vault.writeKeyring(id, blob);
        cipher = cipher.upgraded(vk);
        _setSession(cipher, [id]);
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

  /// 更换主密钥：拿新主密钥把**当前空间的库密钥**重新包一遍，只重写 keyring
  /// 那一行（同一空间有多把库密钥时逐把重写）。记录一条都不用动，所以是 O(1)。
  ///
  /// 只影响当前这个密钥空间；库里其他空间的 keyring 和记录一概不碰。
  ///
  /// 换之前会先把本空间里剩下的 v1 老记录转完——不转的话它们只认老主密钥，
  /// 换完就再也读不出来了。老主密钥都解不开的记录（属于别的空间）原样保留，
  /// 并在 [RekeyResult.leftBehind] 里如实上报。
  ///
  /// 当前空间还没建 keyring（开了云同步但本次会话还没跟远端对齐）时返回
  /// [RekeyResult.needsSync]，让用户先同步一次。
  Future<RekeyResult> rekey(String newMasterPassword) async {
    try {
      await _migrating; // 等后台迁移落地，避免两条写路径互相覆盖
    } catch (_) {
      // 迁移失败不影响换密钥
    }
    final from = _cipher;
    if (from == null) throw StateError('未解锁');
    if (!from.hasVaultKey || _myKeyringIds.isEmpty) {
      return const RekeyResult.needsSync();
    }

    final report = await vault.migrateToVaultKey(from);
    final keys = from.vaultKeys;
    for (var i = 0; i < _myKeyringIds.length && i < keys.length; i++) {
      final blob =
          await VaultCipher.wrapVaultKeyAsync(newMasterPassword, keys[i]);
      await vault.writeKeyring(_myKeyringIds[i], blob);
    }
    _setSession(
      VaultCipher(
        newMasterPassword,
        vaultKey: keys.first,
        alsoDecryptWith: keys.skip(1).toList(),
      ),
      _myKeyringIds,
    );
    return RekeyResult.ok(report.skipped);
  }

  void lock() {
    _cipher = null;
    _myKeyringIds = const [];
    _migrating = null; // 下次解锁（可能换了密钥）要能重新起迁移
    notifyListeners();
  }
}

/// 解锁结果。
enum UnlockOutcome {
  /// 进了某个已有的密钥空间。
  ok,

  /// 这把主密钥打不开库里任何已有条目。可能是输错了一个字，也可能是想用它开一个
  /// 新的密钥空间——由 UI 问一句，答"新建"再调 [AppState.createKeySpace]。
  unknownKey,
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
