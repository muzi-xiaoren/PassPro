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
        'User-Agent': 'passman_pro',
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
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    final b64 = (j['content'] as String).replaceAll('\n', '');
    final bytes = base64.decode(b64);
    final sha = j['sha'] as String;
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
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    return j['sha'] as String?;
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
