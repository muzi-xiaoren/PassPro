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
      await file.writeAsString('');
    }
    return LogStore._(file);
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

  /// 批量追加：整库重加密时一次开一次文件写完，避免逐条开关句柄。
  Future<void> appendAll(Iterable<LogRecord> records) async {
    final sink = _file.openWrite(mode: FileMode.append);
    try {
      for (final r in records) {
        sink.writeln(r.toLine());
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  /// 复制一份当前日志到同目录下的 `passwords.log.<suffix>`，返回它的路径。
  /// 迁移到新格式前调一次：万一迁移过程中出岔子，用户手上还有迁移前的原件。
  /// 同名备份已存在就不再覆盖——第一份（真正的迁移前原件）最值钱。
  Future<String?> backupOnce(String suffix) async {
    final dest = File('${_file.path}.$suffix');
    if (await dest.exists()) return null;
    if (!await _file.exists()) return null;
    await _file.copy(dest.path);
    return dest.path;
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
