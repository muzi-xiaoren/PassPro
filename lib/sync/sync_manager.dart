import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/password_entry.dart';
import '../settings/app_settings.dart';
import '../settings/secure_credential_store.dart';
import '../storage/conflict_merger.dart';
import '../storage/log_store.dart';
import '../storage/memory_index.dart';
import 'git_backend.dart';
import 'sync_backend.dart';
import 'webdav_backend.dart';

/// 同步状态供 UI 展示。
enum SyncState { idle, working, ok, offline, error }

/// 语义化状态文案类型。sync 层没有 BuildContext，拿不到 l10n，
/// 所以这里只产出"类型 + 参数"，由 UI 层按当前语言渲染（修复中英文混杂）。
enum SyncMsg {
  allBackendsPullFailed, // arg = 错误详情
  pulledFrom, // arg = 后端名
  noPrimary,
  primaryOffline, // arg = 错误
  primaryPushFailed, // arg = 错误
  pushConflictManual,
  pushedToPrimary, // + mirrors
  remoteEmptySkipped,
  overwroteLocalFrom, // arg = 后端名
  primaryOverwriteFailed, // arg = 错误
  overwriteRemoteStillChanging,
  overwroteRemoteWithLocal, // + mirrors
  genericError, // arg = 错误
}

/// 单个副仓库(mirror)的推送结果，用于在状态里逐个展示成功/冲突/失败。
enum MirrorOutcome { ok, conflict, failed }

class MirrorResult {
  final String backend; // 后端名：github / gitee / webdav
  final MirrorOutcome outcome;
  final String? detail; // 失败原因（仅 failed 时有意义）
  const MirrorResult(this.backend, this.outcome, {this.detail});
}

class SyncStatus {
  final SyncState state;
  final SyncMsg? msg;
  final String? arg;
  final String? primaryBackend; // 主仓库后端名，用于"每个结果都说明一下"
  final List<MirrorResult> mirrors;
  final DateTime? lastSyncAt;
  final String? lastRemoteVersion;

  const SyncStatus({
    this.state = SyncState.idle,
    this.msg,
    this.arg,
    this.primaryBackend,
    this.mirrors = const [],
    this.lastSyncAt,
    this.lastRemoteVersion,
  });

  SyncStatus copyWith({
    SyncState? state,
    SyncMsg? msg,
    String? arg,
    String? primaryBackend,
    List<MirrorResult>? mirrors,
    DateTime? lastSyncAt,
    String? lastRemoteVersion,
  }) {
    return SyncStatus(
      state: state ?? this.state,
      msg: msg ?? this.msg,
      arg: arg ?? this.arg,
      primaryBackend: primaryBackend ?? this.primaryBackend,
      mirrors: mirrors ?? this.mirrors,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastRemoteVersion: lastRemoteVersion ?? this.lastRemoteVersion,
    );
  }
}

/// 主备策略调度：
///   pull → 优先 primary，失败/不可达自动降级到 mirror
///   push → primary 必须成功，mirror 失败仅 warning
///   headVersion → primary，失败时回退 mirror
class SyncManager extends ChangeNotifier {
  SyncManager({
    required this.settings,
    required this.credentials,
    required this.logStore,
    required this.memoryIndex,
  });

  final AppSettings settings;
  final SecureCredentialStore credentials;
  final LogStore logStore;
  final MemoryIndex memoryIndex;

  SyncStatus _status = const SyncStatus();
  SyncStatus get status => _status;

  // 启动时检查远端是否有变化（用于 prompt 智能跳过）
  String? _knownRemoteVersion;

  /// 远端是否比上次同步更新（true=有新内容应提示拉取；null=未知/无法检测）。
  bool? remoteHasUpdates;

  void _setStatus(SyncStatus s) {
    _status = s;
    notifyListeners();
  }

  Future<SyncBackend?> _resolveBackend(BackendConfig cfg) async {
    if (!cfg.enabled) return null;
    final secret = await credentials.readPat(cfg.kind);
    if (secret == null || secret.isEmpty) return null;
    if (cfg.owner.isEmpty || cfg.repo.isEmpty || cfg.filePath.isEmpty) {
      return null;
    }
    return switch (cfg.kind) {
      BackendKind.github || BackendKind.gitee =>
        GitBackend(config: cfg, pat: secret),
      BackendKind.webdav => WebDavBackend(config: cfg, password: secret),
    };
  }

  Future<SyncBackend?> _primary() async {
    final cfg = settings.primaryBackend;
    return cfg == null ? null : _resolveBackend(cfg);
  }

  Future<List<SyncBackend>> _mirrors() async {
    final out = <SyncBackend>[];
    for (final cfg in settings.mirrorBackends) {
      final b = await _resolveBackend(cfg);
      if (b != null) out.add(b);
    }
    return out;
  }

  /// 启动时异步探测：远端 head version 与上次记录是否一致。
  Future<void> checkRemoteAsync() async {
    if (!settings.cloudEnabled) {
      remoteHasUpdates = null;
      return;
    }
    try {
      final primary = await _primary();
      String? remoteVer;
      if (primary != null) {
        try {
          remoteVer = await primary.headVersion();
        } catch (_) {
          // primary 不可达，回退 mirror
          for (final m in await _mirrors()) {
            try {
              remoteVer = await m.headVersion();
              break;
            } catch (_) {/* try next */}
          }
        }
      }
      remoteHasUpdates =
          remoteVer != null && remoteVer != _knownRemoteVersion;
      _setStatus(_status.copyWith(lastRemoteVersion: remoteVer));
    } on SocketException {
      _setStatus(_status.copyWith(state: SyncState.offline));
    } catch (e) {
      _setStatus(_status.copyWith(
        state: SyncState.error,
        msg: SyncMsg.genericError,
        arg: e.toString(),
      ));
    }
  }

  /// 拉取并合并到本地日志。返回是否实际产生了本地变化。
  Future<bool> pullAndMerge() async {
    if (!settings.cloudEnabled) return false;
    _setStatus(_status.copyWith(state: SyncState.working));

    final primary = await _primary();
    final mirrors = await _mirrors();

    SyncBackend? used;
    RemoteSnapshot? snap;
    Object? lastError;
    for (final b in [if (primary != null) primary, ...mirrors]) {
      try {
        snap = await b.pull();
        used = b;
        break;
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    if (snap == null || used == null) {
      _setStatus(_status.copyWith(
        state: SyncState.error,
        msg: SyncMsg.allBackendsPullFailed,
        arg: '$lastError',
      ));
      return false;
    }

    if (!snap.exists || snap.content.isEmpty) {
      _knownRemoteVersion = snap.version;
      _setStatus(_status.copyWith(
        state: SyncState.ok,
        lastSyncAt: DateTime.now(),
        lastRemoteVersion: snap.version,
      ));
      remoteHasUpdates = false;
      return false;
    }

    final remoteLog = _parseLog(snap.content);
    final localLog = await logStore.readAll();
    final merged = mergeLogs(localLog, remoteLog);
    if (!_logsEqual(merged, localLog)) {
      await logStore.replaceAll(merged);
      memoryIndex.replay(merged);
    }

    _knownRemoteVersion = snap.version;
    remoteHasUpdates = false;
    _setStatus(_status.copyWith(
      state: SyncState.ok,
      lastSyncAt: DateTime.now(),
      lastRemoteVersion: snap.version,
      msg: SyncMsg.pulledFrom,
      arg: used.kind.name,
    ));
    return !_logsEqual(merged, localLog);
  }

  /// 推送当前本地日志：primary 必成功，mirror 尽力。
  /// 返回 true 表示 primary 写入成功。
  Future<bool> pushAll({String commitMessage = 'update passwords'}) async {
    if (!settings.cloudEnabled) return false;
    _setStatus(_status.copyWith(state: SyncState.working));

    final primary = await _primary();
    if (primary == null) {
      _setStatus(_status.copyWith(
        state: SyncState.error,
        msg: SyncMsg.noPrimary,
      ));
      return false;
    }

    final primaryName = primary.kind.name;
    final localBytes = await _readLocalBytes();
    String? baseVersion;
    try {
      baseVersion = await primary.headVersion();
    } catch (_) {
      // 拉取 head 失败也不阻塞（仓库可能不存在文件）
    }

    PushOutcome outcome;
    try {
      outcome = await primary.push(
        content: localBytes,
        baseVersion: baseVersion,
        commitMessage: commitMessage,
      );
    } on SocketException catch (e) {
      _setStatus(_status.copyWith(
        state: SyncState.offline,
        msg: SyncMsg.primaryOffline,
        arg: '$e',
        primaryBackend: primaryName,
      ));
      return false;
    } catch (e) {
      _setStatus(_status.copyWith(
        state: SyncState.error,
        msg: SyncMsg.primaryPushFailed,
        arg: '$e',
        primaryBackend: primaryName,
      ));
      return false;
    }

    if (outcome == PushOutcome.conflict) {
      // 远端比本地新：先拉合并，再重试一次
      final changed = await pullAndMerge();
      if (changed) {
        return pushAll(commitMessage: commitMessage);
      }
      _setStatus(_status.copyWith(
        state: SyncState.error,
        msg: SyncMsg.pushConflictManual,
        primaryBackend: primaryName,
      ));
      return false;
    }

    // primary 成功后再尽力推 mirror，逐个记录结果（成功/冲突/失败）。
    final mirrors = await _pushMirrors(localBytes, commitMessage);

    _knownRemoteVersion = await primary.headVersion();
    _setStatus(_status.copyWith(
      state: SyncState.ok,
      lastSyncAt: DateTime.now(),
      lastRemoteVersion: _knownRemoteVersion,
      msg: SyncMsg.pushedToPrimary,
      primaryBackend: primaryName,
      mirrors: mirrors,
    ));
    return true;
  }

  /// 把本地内容尽力推送到每个 mirror，逐个返回结果（不抛异常）。
  /// 冲突时自动 pull+merge+强制覆盖（副仓库是下游副本，最终应与本地一致且不丢数据）；
  /// 失败时把错误详情一并带回，便于 UI 明确说明每个结果的原因。
  Future<List<MirrorResult>> _pushMirrors(
    Uint8List localBytes,
    String commitMessage, {
    bool merge = true,
  }) async {
    final results = <MirrorResult>[];
    for (final m in await _mirrors()) {
      final name = m.kind.name;
      try {
        String? mv;
        try {
          mv = await m.headVersion();
        } catch (_) {}
        var mo = await m.push(
          content: localBytes,
          baseVersion: mv,
          commitMessage: commitMessage,
        );
        if (mo == PushOutcome.conflict) {
          mo = await _resolveMirrorConflict(
            m,
            localBytes,
            commitMessage,
            merge: merge,
          );
        }
        results.add(MirrorResult(
          name,
          mo == PushOutcome.conflict
              ? MirrorOutcome.conflict
              : MirrorOutcome.ok,
        ));
      } catch (e) {
        results.add(MirrorResult(
          name,
          MirrorOutcome.failed,
          detail: _shortError(e),
        ));
      }
    }
    return results;
  }

  /// 副仓库冲突兜底：强制覆盖远端，消除坚果云 ETag 漂移造成的"假冲突"，
  /// 也让落后的副本追平。
  ///   - [merge]=true（普通同步）：先拉远端，与本地按 record_id 合并（任一端条目都不丢）再写，
  ///     避免覆盖掉副本上独有的条目。
  ///   - [merge]=false（"用本地覆盖云端"）：尊重用户意图，直接以本地内容覆盖。
  Future<PushOutcome> _resolveMirrorConflict(
    SyncBackend m,
    Uint8List localBytes,
    String commitMessage, {
    bool merge = true,
  }) async {
    final snap = await m.pull();
    var toPush = localBytes;
    if (merge && snap.exists && snap.content.isNotEmpty) {
      final merged = mergeLogs(_parseLog(localBytes), _parseLog(snap.content));
      toPush = _serializeLog(merged);
    }
    return m.push(
      content: toPush,
      baseVersion: snap.version,
      commitMessage: commitMessage,
      force: true,
    );
  }

  /// 把日志记录序列化成与本地文件一致的字节（每行 toLine() + '\n'）。
  Uint8List _serializeLog(List<LogRecord> records) {
    final sb = StringBuffer();
    for (final r in records) {
      sb.writeln(r.toLine());
    }
    return Uint8List.fromList(utf8.encode(sb.toString()));
  }

  String _shortError(Object e) {
    final s = e.toString();
    return s.length > 200 ? '${s.substring(0, 200)}…' : s;
  }

  /// 用云端覆盖本地：拉取远端快照并**完全替换**本地日志（不合并）。
  /// 远端不存在 / 为空时不执行（避免误清空本地），返回 false 并置错误状态。
  Future<bool> overwriteLocalWithRemote() async {
    if (!settings.cloudEnabled) return false;
    _setStatus(_status.copyWith(state: SyncState.working));

    final primary = await _primary();
    final mirrors = await _mirrors();

    SyncBackend? used;
    RemoteSnapshot? snap;
    Object? lastError;
    for (final b in [if (primary != null) primary, ...mirrors]) {
      try {
        snap = await b.pull();
        used = b;
        break;
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    if (snap == null || used == null) {
      _setStatus(_status.copyWith(
        state: SyncState.error,
        msg: SyncMsg.allBackendsPullFailed,
        arg: '$lastError',
      ));
      return false;
    }

    if (!snap.exists || snap.content.isEmpty) {
      _setStatus(_status.copyWith(
        state: SyncState.error,
        msg: SyncMsg.remoteEmptySkipped,
      ));
      return false;
    }

    final remoteLog = _parseLog(snap.content);
    await logStore.replaceAll(remoteLog);
    memoryIndex.replay(remoteLog);

    _knownRemoteVersion = snap.version;
    remoteHasUpdates = false;
    _setStatus(_status.copyWith(
      state: SyncState.ok,
      lastSyncAt: DateTime.now(),
      lastRemoteVersion: snap.version,
      msg: SyncMsg.overwroteLocalFrom,
      arg: used.kind.name,
    ));
    return true;
  }

  /// 用本地覆盖云端：以远端**当前**版本为基线强制推送本地内容（覆盖远端，不合并）。
  /// 返回 true 表示 primary 覆盖成功。
  Future<bool> overwriteRemoteWithLocal({
    String commitMessage = 'overwrite from local',
  }) async {
    if (!settings.cloudEnabled) return false;
    _setStatus(_status.copyWith(state: SyncState.working));

    final primary = await _primary();
    if (primary == null) {
      _setStatus(_status.copyWith(
        state: SyncState.error,
        msg: SyncMsg.noPrimary,
      ));
      return false;
    }

    final primaryName = primary.kind.name;
    final localBytes = await _readLocalBytes();

    Future<PushOutcome> pushWithCurrentHead() async {
      String? head;
      try {
        head = await primary.headVersion();
      } catch (_) {
        // 文件不存在等：用 null 基线创建
      }
      return primary.push(
        content: localBytes,
        baseVersion: head,
        commitMessage: commitMessage,
      );
    }

    PushOutcome outcome;
    try {
      outcome = await pushWithCurrentHead();
      // 远端在读取 head 之后又被改动 → 再取一次最新 head 重推一次
      if (outcome == PushOutcome.conflict) {
        outcome = await pushWithCurrentHead();
      }
    } on SocketException catch (e) {
      _setStatus(_status.copyWith(
        state: SyncState.offline,
        msg: SyncMsg.primaryOffline,
        arg: '$e',
        primaryBackend: primaryName,
      ));
      return false;
    } catch (e) {
      _setStatus(_status.copyWith(
        state: SyncState.error,
        msg: SyncMsg.primaryOverwriteFailed,
        arg: '$e',
        primaryBackend: primaryName,
      ));
      return false;
    }

    if (outcome == PushOutcome.conflict) {
      _setStatus(_status.copyWith(
        state: SyncState.error,
        msg: SyncMsg.overwriteRemoteStillChanging,
        primaryBackend: primaryName,
      ));
      return false;
    }

    // primary 成功后再尽力覆盖 mirror；冲突时直接以本地强制覆盖（不合并，尊重"用本地覆盖"意图）
    final mirrors = await _pushMirrors(localBytes, commitMessage, merge: false);

    _knownRemoteVersion = await primary.headVersion();
    _setStatus(_status.copyWith(
      state: SyncState.ok,
      lastSyncAt: DateTime.now(),
      lastRemoteVersion: _knownRemoteVersion,
      msg: SyncMsg.overwroteRemoteWithLocal,
      primaryBackend: primaryName,
      mirrors: mirrors,
    ));
    return true;
  }

  Future<Uint8List> _readLocalBytes() async {
    final file = logStore.file;
    return file.readAsBytes();
  }

  List<LogRecord> _parseLog(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final out = <LogRecord>[];
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      try {
        out.add(LogRecord.fromLine(line));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  bool _logsEqual(List<LogRecord> a, List<LogRecord> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].toLine() != b[i].toLine()) return false;
    }
    return true;
  }
}

/// 跨整个 app 用的"本次会话不再提示"标记。
class SessionPromptSkip {
  bool skipBefore = false;
  bool skipAfter = false;
}
