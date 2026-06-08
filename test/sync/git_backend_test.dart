import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:passpro/settings/app_settings.dart';
import 'package:passpro/sync/git_backend.dart';
import 'package:passpro/sync/sync_backend.dart';

void main() {
  GitBackend backend(BackendKind kind, http.Client client, {String branch = 'master'}) =>
      GitBackend(
        config: BackendConfig(
          kind: kind,
          owner: 'o',
          repo: 'r',
          branch: branch,
          filePath: 'passwords.log',
        ),
        pat: 'token',
        httpClient: client,
      );

  final body = Uint8List.fromList([1, 2, 3]);

  group('GitBackend.push 方法选择（Gitee POST 新建 / PUT 更新）', () {
    test('Gitee 新建文件（无 sha）必须用 POST', () async {
      var method = '';
      final client = MockClient((req) async {
        method = req.method;
        return http.Response('{"content":{"sha":"x"}}', 201);
      });
      final out = await backend(BackendKind.gitee, client).push(
        content: body,
        baseVersion: null,
        commitMessage: 'create',
      );
      expect(method, 'POST'); // 关键：Gitee 新建用 POST，不能用 PUT
      expect(out, PushOutcome.ok);
    });

    test('Gitee 更新文件（有 sha）用 PUT', () async {
      var method = '';
      final client = MockClient((req) async {
        method = req.method;
        return http.Response('{"content":{"sha":"y"}}', 200);
      });
      final out = await backend(BackendKind.gitee, client).push(
        content: body,
        baseVersion: 'sha-abc',
        commitMessage: 'update',
      );
      expect(method, 'PUT');
      expect(out, PushOutcome.ok);
    });

    test('GitHub 新建文件用 PUT（PUT 同时支持新建/更新）', () async {
      var method = '';
      final client = MockClient((req) async {
        method = req.method;
        return http.Response('{"content":{"sha":"z"}}', 201);
      });
      final out = await backend(BackendKind.github, client).push(
        content: body,
        baseVersion: null,
        commitMessage: 'create',
      );
      expect(method, 'PUT');
      expect(out, PushOutcome.ok);
    });

    test('Gitee POST 新建时文件已存在 → 冲突（而非抛错）', () async {
      final client = MockClient((req) async {
        return http.Response(
          '{"message":"A file with this name already exists"}',
          400,
        );
      });
      final out = await backend(BackendKind.gitee, client).push(
        content: body,
        baseVersion: null,
        commitMessage: 'create',
      );
      expect(out, PushOutcome.conflict);
    });

    test('force=true：先取最新 sha 再 PUT 更新现有文件', () async {
      final methods = <String>[];
      final client = MockClient((req) async {
        methods.add(req.method);
        if (req.method == 'GET') {
          // headVersion → 文件存在，返回 sha
          return http.Response('{"sha":"live-sha"}', 200);
        }
        return http.Response('{"content":{"sha":"new"}}', 200);
      });
      final out = await backend(BackendKind.gitee, client).push(
        content: body,
        baseVersion: null, // 即使没传基线，force 也会自己拉一次 sha
        commitMessage: 'force',
        force: true,
      );
      expect(methods, ['GET', 'PUT']); // 文件存在 → 走更新（PUT）
      expect(out, PushOutcome.ok);
    });
  });
}
