import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/password_entry.dart';

/// 负责把 [LogRecord] 行追加 / 读取到磁盘日志文件。
/// 物理路径：<app_support_dir>/PassPro/passwords.log
class LogStore {
  LogStore._(this._file);

  final File _file;

  static Future<LogStore> open() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'PassPro'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, 'passwords.log'));
    if (!await file.exists()) {
      // 一次性迁移：早期 macOS 构建开启了 App Sandbox，数据写在沙盒容器内。
      // 现已去掉沙盒（让 Keychain 在 adhoc 签名下可用），路径改为
      // ~/Library/Application Support/com.example.PassPro/PassPro/passwords.log。
      // 若新路径还没有文件、而旧容器里有数据，则搬过来，避免升级后“数据消失”。
      await _migrateFromSandboxContainer(file);
    }
    if (!await file.exists()) {
      await file.writeAsString('');
    }
    return LogStore._(file);
  }

  /// macOS 专用：把旧沙盒容器里的 passwords.log 迁移到新（非沙盒）路径。
  /// 失败不致命——当作全新空库继续即可。
  static Future<void> _migrateFromSandboxContainer(File dest) async {
    if (!Platform.isMacOS) return;
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return;
    final legacy = File(p.join(
      home,
      'Library',
      'Containers',
      'com.example.PassPro',
      'Data',
      'Library',
      'Application Support',
      'com.example.PassPro',
      'PassPro',
      'passwords.log',
    ));
    try {
      if (await legacy.exists() && await legacy.length() > 0) {
        await dest.parent.create(recursive: true);
        await legacy.copy(dest.path);
      }
    } catch (_) {
      // 旧容器读不到（权限/不存在）就忽略。
    }
  }

  File get file => _file;
  String get path => _file.path;

  Future<int> sizeBytes() async => _file.length();

  /// 一次性读取所有行（小文件 OK）。
  Future<List<LogRecord>> readAll() async {
    final out = <LogRecord>[];
    if (!await _file.exists()) return out;
    final lines = await _file.readAsLines();
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      try {
        out.add(LogRecord.fromLine(line));
      } catch (_) {
        // 一行坏不能搞挂整个 store，跳过并继续
        continue;
      }
    }
    return out;
  }

  Future<void> append(LogRecord record) async {
    final sink = _file.openWrite(mode: FileMode.append);
    try {
      sink.writeln(record.toLine());
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  /// 用一组新记录原子替换整个日志（compaction / 从远端覆盖时使用）。
  Future<void> replaceAll(Iterable<LogRecord> records) async {
    final tmp = File('${_file.path}.tmp');
    final sink = tmp.openWrite();
    try {
      for (final r in records) {
        sink.writeln(r.toLine());
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    await tmp.rename(_file.path);
  }
}
