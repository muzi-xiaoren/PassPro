import 'dart:typed_data';

import '../settings/app_settings.dart';

/// 抽象远端仓库后端。GitHub / Gitee 都用 REST API 上传单个文件。
abstract class SyncBackend {
  BackendKind get kind;
  BackendConfig get config;

  /// 拉取远端当前文件 + commit/version 标识。文件不存在时 [content] 为空字节、[version] 为 null。
  Future<RemoteSnapshot> pull();

  /// 上传新内容；需要带上"基线 version"，远端若不一致返回冲突（[PushOutcome.conflict]）。
  Future<PushOutcome> push({
    required Uint8List content,
    required String? baseVersion,
    required String commitMessage,
  });

  /// 仅检查远端最新 version，用于"智能跳过"。失败抛异常。
  Future<String?> headVersion();
}

class RemoteSnapshot {
  final Uint8List content;
  final String? version;
  final bool exists;

  const RemoteSnapshot({
    required this.content,
    required this.version,
    required this.exists,
  });
}

enum PushOutcome { ok, conflict }

class SyncException implements Exception {
  final String message;
  final int? statusCode;
  const SyncException(this.message, {this.statusCode});
  @override
  String toString() =>
      'SyncException($statusCode): $message';
}
