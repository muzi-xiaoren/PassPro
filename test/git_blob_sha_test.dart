import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:passpro/sync/sync_manager.dart';

void main() {
  group('SyncManager.gitBlobSha 与 git hash-object 一致', () {
    test('"hello\\n" 的 blob sha', () {
      final sha = SyncManager.gitBlobSha(
        Uint8List.fromList(utf8.encode('hello\n')),
      );
      // printf 'hello\n' | git hash-object --stdin
      expect(sha, 'ce013625030ba8dba906f756967f9e9ca394464a');
    });

    test('空内容的 blob sha', () {
      final sha = SyncManager.gitBlobSha(Uint8List(0));
      // git hash-object 空文件
      expect(sha, 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391');
    });
  });
}
