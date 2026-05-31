import 'dart:typed_data';

import '../crypto/fernet_crypto.dart';
import '../models/password_entry.dart';

/// 内存里的"活记录"索引：record_id → 最新一条 LogRecord。
/// 启动时由 [replay] 一次性扫日志构建；之后所有 CRUD 都直接动它。
class MemoryIndex {
  /// 仅密文索引：不需要主密钥即可加载。明文密码只在调用 [decryptPassword] 时即时解密。
  final Map<String, LogRecord> _records = {};

  int get totalLineCount => _scannedLines;
  int _scannedLines = 0;

  int get activeCount => _records.length;

  /// 总行数 / 有效记录数 ≥ ratio 时建议 compact。
  double get amplification =>
      _records.isEmpty ? 0 : _scannedLines / _records.length;

  Iterable<LogRecord> get activeRecords => _records.values;

  /// 用日志记录 replay 出最新状态。同 id 后写覆盖前写；DEL 移除。
  void replay(List<LogRecord> log) {
    _records.clear();
    _scannedLines = log.length;
    for (final r in log) {
      switch (r.op) {
        case LogOp.add:
        case LogOp.update:
          _records[r.id] = r;
        case LogOp.delete:
          _records.remove(r.id);
      }
    }
  }

  /// 把一条新追加的日志应用到内存（不重置扫描计数）。
  void apply(LogRecord r) {
    _scannedLines += 1;
    switch (r.op) {
      case LogOp.add:
      case LogOp.update:
        _records[r.id] = r;
      case LogOp.delete:
        _records.remove(r.id);
    }
  }

  /// 查找：把输入网址按 :// / . 拆成关键词集合，与每条记录的关键词集合求交集。
  /// 与旧 Python query_data 行为对齐。
  List<LogRecord> searchByWebsite(String query) {
    final terms = _splitWebsite(query);
    if (terms.isEmpty) return List.unmodifiable(_records.values);
    final out = <LogRecord>[];
    for (final r in _records.values) {
      final storedTerms = _splitWebsite(r.website ?? '');
      if (storedTerms.intersection(terms).isNotEmpty) {
        out.add(r);
      }
    }
    return out;
  }

  static Set<String> _splitWebsite(String s) {
    final parts = s
        .replaceAll('://', '.')
        .replaceAll('/', '.')
        .split('.')
        .where((p) => p.isNotEmpty)
        .toSet();
    return parts;
  }

  /// 解密密码字段；失败抛 [FernetException]（主密钥错或数据坏）。
  String decryptPassword(LogRecord r, Uint8List masterKey) {
    final ct = r.encryptedPassword;
    if (ct == null) {
      throw const FernetException('记录无密文字段');
    }
    return FernetCrypto.decrypt(ct, masterKey);
  }

  /// 给定 record_id 查找当前活记录，找不到返回 null。
  LogRecord? get(String id) => _records[id];

  /// 用 (website, username) 唯一定位（与旧 Python 同账号判定一致）。
  LogRecord? findByWebsiteAndUsername(String website, String username) {
    for (final r in _records.values) {
      if (r.website == website && (r.username ?? '') == username) {
        return r;
      }
    }
    return null;
  }
}
