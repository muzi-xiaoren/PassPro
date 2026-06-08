import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../settings/app_settings.dart';
import 'sync_backend.dart';

/// WebDAV 后端，用于坚果云 / Nextcloud / NAS 等云端文件夹。
///
/// 字段复用 [BackendConfig]：
/// - owner: WebDAV 用户名
/// - repo: WebDAV 服务器地址，如 https://dav.jianguoyun.com/dav/
/// - filePath: 远程文件路径，如 /PassPro/passwords.log
class WebDavBackend implements SyncBackend {
  WebDavBackend({
    required this.config,
    required String password,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  })  : _password = password,
        _http = httpClient ?? http.Client(),
        _timeout = timeout;

  @override
  final BackendConfig config;

  final String _password;
  final http.Client _http;
  final Duration _timeout;

  @override
  BackendKind get kind => BackendKind.webdav;

  Map<String, String> get _headers => {
        'Authorization':
            'Basic ${base64.encode(utf8.encode('${config.owner}:$_password'))}',
        'User-Agent': 'PassPro',
      };

  Uri _fileUri() {
    final base = config.repo.endsWith('/') ? config.repo : '${config.repo}/';
    final path = config.filePath.startsWith('/')
        ? config.filePath.substring(1)
        : config.filePath;
    return Uri.parse(base).resolve(path);
  }

  String? _versionFrom(http.Response resp) =>
      resp.headers['etag'] ?? resp.headers['last-modified'];

  @override
  Future<RemoteSnapshot> pull() async {
    final resp = await _http.get(_fileUri(), headers: _headers).timeout(_timeout);
    // 坚果云在“父文件夹尚不存在”时返回 409 而非 404；读取场景下都按“远端无文件”处理，
    // 首次 push 会用 MKCOL 自动建好目录。
    if (resp.statusCode == 404 || resp.statusCode == 409) {
      return RemoteSnapshot(
        content: Uint8List(0),
        version: null,
        exists: false,
      );
    }
    if (resp.statusCode >= 400) {
      throw SyncException(resp.body, statusCode: resp.statusCode);
    }
    return RemoteSnapshot(
      content: resp.bodyBytes,
      version: _versionFrom(resp),
      exists: true,
    );
  }

  @override
  Future<String?> headVersion() async {
    final req = http.Request('HEAD', _fileUri())..headers.addAll(_headers);
    final streamed = await _http.send(req).timeout(_timeout);
    final resp = await http.Response.fromStream(streamed);
    // 404 = 文件不存在；409 = 坚果云“父文件夹还没建”。测试连接时两者都视为“暂无文件”，
    // 不当作失败（首次 push 会自动建目录并创建文件）。
    if (resp.statusCode == 404 || resp.statusCode == 409) return null;
    if (resp.statusCode >= 400) {
      throw SyncException(resp.body, statusCode: resp.statusCode);
    }
    return _versionFrom(resp);
  }

  @override
  Future<String?> testConnection() async {
    final req = http.Request('HEAD', _fileUri())..headers.addAll(_headers);
    final streamed = await _http.send(req).timeout(_timeout);
    final resp = await http.Response.fromStream(streamed);
    // 文件夹已存在、文件还没建 → 正常（首次 push 会创建文件）。
    if (resp.statusCode == 404) return null;
    // 坚果云：父文件夹不存在时返回 409。坚果云不能通过 WebDAV 自动建顶层文件夹，
    // 必须先在坚果云里手动建好，否则推送也会失败 —— 所以这里明确提示用户。
    if (resp.statusCode == 409) {
      throw SyncException(
        'target folder does not exist',
        statusCode: 409,
        kind: SyncErrorKind.webdavFolderMissing,
      );
    }
    if (resp.statusCode >= 400) {
      throw SyncException(resp.body, statusCode: resp.statusCode);
    }
    return _versionFrom(resp);
  }

  @override
  Future<PushOutcome> push({
    required Uint8List content,
    required String? baseVersion,
    required String commitMessage,
  }) async {
    await _ensureDirectories();
    final headers = {
      ..._headers,
      'Content-Type': 'application/octet-stream',
      if (baseVersion != null) 'If-Match': baseVersion,
      if (baseVersion == null) 'If-None-Match': '*',
    };
    var resp =
        await _http.put(_fileUri(), headers: headers, body: content).timeout(_timeout);
    if (resp.statusCode == 412 || resp.statusCode == 409) {
      if (baseVersion == null) {
        resp = await _http
            .put(_fileUri(), headers: {
              ..._headers,
              'Content-Type': 'application/octet-stream',
            }, body: content)
            .timeout(_timeout);
      } else {
        return PushOutcome.conflict;
      }
    }
    if (resp.statusCode >= 400) {
      throw SyncException(resp.body, statusCode: resp.statusCode);
    }
    return PushOutcome.ok;
  }

  Future<void> _ensureDirectories() async {
    final parts = config.filePath
        .split('/')
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.length <= 1) return;

    final base = config.repo.endsWith('/') ? config.repo : '${config.repo}/';
    var current = Uri.parse(base);
    for (final part in parts.take(parts.length - 1)) {
      current = current.resolve('$part/');
      final req = http.Request('MKCOL', current)..headers.addAll(_headers);
      final streamed = await _http.send(req).timeout(_timeout);
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 201 ||
          resp.statusCode == 405 ||
          resp.statusCode == 301 ||
          resp.statusCode == 302) {
        continue;
      }
      if (resp.statusCode >= 400) {
        throw SyncException(resp.body, statusCode: resp.statusCode);
      }
    }
  }
}
