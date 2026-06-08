import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../settings/app_settings.dart';
import 'sync_backend.dart';

/// GitHub 和 Gitee 的 REST API 都支持"读取/创建/更新仓库单文件"，路径形如
///   GET    /repos/:owner/:repo/contents/:path?ref=:branch
///   PUT    /repos/:owner/:repo/contents/:path     body: {message, content(base64), branch, sha?}
///
/// 差异：
///   - host：api.github.com  vs  gitee.com/api/v5
///   - 认证头：GitHub `Authorization: Bearer <PAT>`；Gitee 既可用 header 也可用 ?access_token=
///     这里统一走 header 模式，Gitee 支持。
///   - PUT 时 GitHub 不能省 sha（更新需要），Gitee 同。
class GitBackend implements SyncBackend {
  GitBackend({
    required this.config,
    required String pat,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  })  : _pat = pat,
        _http = httpClient ?? http.Client(),
        _timeout = timeout;

  @override
  final BackendConfig config;

  final String _pat;
  final http.Client _http;
  final Duration _timeout;

  @override
  BackendKind get kind => config.kind;

  String get _host => switch (kind) {
        BackendKind.github => 'https://api.github.com',
        BackendKind.gitee => 'https://gitee.com/api/v5',
        BackendKind.webdav => throw StateError('WebDAV does not use GitBackend'),
      };

  Uri _contentsUri({String? ref}) {
    final base =
        '$_host/repos/${config.owner}/${config.repo}/contents/${config.filePath}';
    return ref == null ? Uri.parse(base) : Uri.parse('$base?ref=$ref');
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_pat',
        'Accept': kind == BackendKind.github
            ? 'application/vnd.github+json'
            : 'application/json',
        'User-Agent': 'PassPro',
      };

  @override
  Future<RemoteSnapshot> pull() async {
    final resp = await _http
        .get(_contentsUri(ref: config.branch), headers: _headers)
        .timeout(_timeout);
    if (resp.statusCode == 404) {
      return RemoteSnapshot(
        content: Uint8List(0),
        version: null,
        exists: false,
      );
    }
    if (resp.statusCode >= 400) {
      throw SyncException(resp.body, statusCode: resp.statusCode);
    }
    final decoded = jsonDecode(resp.body);
    // Gitee 对“空仓库 / 路径是目录”会返回 JSON 数组而非 404；都按“远端无文件”处理。
    if (decoded is! Map<String, dynamic>) {
      return RemoteSnapshot(content: Uint8List(0), version: null, exists: false);
    }
    final b64 = (decoded['content'] as String).replaceAll('\n', '');
    final bytes = base64.decode(b64);
    final sha = decoded['sha'] as String;
    return RemoteSnapshot(content: bytes, version: sha, exists: true);
  }

  @override
  Future<String?> headVersion() async {
    final resp = await _http
        .get(_contentsUri(ref: config.branch), headers: _headers)
        .timeout(_timeout);
    if (resp.statusCode == 404) return null;
    if (resp.statusCode >= 400) {
      throw SyncException(resp.body, statusCode: resp.statusCode);
    }
    final decoded = jsonDecode(resp.body);
    // Gitee 空仓库/目录返回数组 → 视为“文件还没建”。
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['sha'] as String?;
  }

  @override
  Future<String?> testConnection() async {
    // 先确认仓库本身存在/有权限。否则 contents 接口对"仓库不存在"也只回 404，
    // 会被 headVersion 误判成"文件还没建"（测试假成功，但 push 时报 Not Found Project）。
    final repoResp = await _http
        .get(Uri.parse('$_host/repos/${config.owner}/${config.repo}'),
            headers: _headers)
        .timeout(_timeout);
    if (repoResp.statusCode == 404) {
      throw SyncException(
        'repository not found or no access: ${config.owner}/${config.repo}',
        statusCode: 404,
        kind: SyncErrorKind.repoNotFound,
      );
    }
    if (repoResp.statusCode >= 400) {
      throw SyncException(repoResp.body, statusCode: repoResp.statusCode);
    }
    // 仓库 OK，再取文件版本（文件不存在 = null，属正常）。
    return headVersion();
  }

  @override
  Future<PushOutcome> push({
    required Uint8List content,
    required String? baseVersion,
    required String commitMessage,
  }) async {
    final body = <String, Object?>{
      'message': commitMessage,
      'content': base64.encode(content),
      'branch': config.branch,
      if (baseVersion != null) 'sha': baseVersion,
    };
    final resp = await _http
        .put(
          _contentsUri(),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    if (resp.statusCode == 409 ||
        (resp.statusCode == 422 && resp.body.contains('sha'))) {
      return PushOutcome.conflict;
    }
    if (resp.statusCode >= 400) {
      throw SyncException(resp.body, statusCode: resp.statusCode);
    }
    return PushOutcome.ok;
  }
}
