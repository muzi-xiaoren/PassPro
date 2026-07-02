import 'package:flutter/foundation.dart';

import '../crypto/vault_cipher.dart';
import '../models/password_entry.dart';
import '../models/search_config.dart';

/// 内存里的"活记录"索引：record_id → 最新一条 LogRecord。
/// 启动时由 [replay] 一次性扫日志构建；之后所有 CRUD 都直接动它。
///
/// 同时是 [ChangeNotifier]：任何写操作（[apply]/[replay]）后都会通知监听者，
/// 让列表/查询界面无需手动 setState 即可热更新（修复"删除后需切换界面才刷新"）。
class MemoryIndex extends ChangeNotifier {
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
    notifyListeners();
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
    notifyListeners();
  }

  /// 按 [config] 搜索并返回排好序（匹配度高→低）的活记录。
  /// 空查询返回全部。匹配大小写不敏感。
  List<LogRecord> search(String query, SearchConfig config) {
    final q = query.trim();
    if (q.isEmpty) return List.of(_records.values);
    return switch (config.strategy) {
      SearchStrategy.fuzzy => _fuzzy(q, config.delimiter),
      SearchStrategy.exact => _termMatch(q, config.delimiter, exact: true),
      SearchStrategy.contains => _termMatch(q, config.delimiter, exact: false),
    };
  }

  /// 按分隔符把字符串拆成小写词集；delimiter 为 null 时用内置标准分割(`.` `/` `://`)。
  static Set<String> _termsBy(String s, String? delimiter) {
    final lower = s.toLowerCase();
    final raw = delimiter == null
        ? lower.replaceAll('://', '.').replaceAll('/', '.').split('.')
        : lower.split(delimiter);
    return raw.where((t) => t.isNotEmpty).toSet();
  }

  /// exact/contains：词集求交。exact 模式下若有与查询完全相等的网址则只返回它们。
  List<LogRecord> _termMatch(String q, String? delimiter, {required bool exact}) {
    final qTerms = _termsBy(q, delimiter);
    if (qTerms.isEmpty) return List.of(_records.values);
    final ql = q.toLowerCase();
    final scored = <(LogRecord, int)>[];
    for (final r in _records.values) {
      final shared =
          qTerms.where(_termsBy(r.website ?? '', delimiter).contains).length;
      if (shared > 0) scored.add((r, shared));
    }
    if (scored.isEmpty) return const [];
    if (exact) {
      final exactEq = [
        for (final e in scored)
          if ((e.$1.website ?? '').trim().toLowerCase() == ql) e.$1,
      ];
      if (exactEq.isNotEmpty) return exactEq;
    }
    scored.sort((a, b) => _rank(a, b, ql));
    return [for (final e in scored) e.$1];
  }

  /// fuzzy：把查询按分隔符(无则整串为一词)拆成关键词，网址需包含每个关键词(子串)。
  List<LogRecord> _fuzzy(String q, String? delimiter) {
    final ql = q.toLowerCase();
    final terms = delimiter == null
        ? <String>[ql]
        : ql.split(delimiter).where((t) => t.isNotEmpty).toList();
    if (terms.isEmpty) return List.of(_records.values);
    final scored = <(LogRecord, int)>[];
    for (final r in _records.values) {
      final w = (r.website ?? '').toLowerCase();
      if (terms.every(w.contains)) {
        scored.add((r, w.startsWith(terms.first) ? 2 : 1));
      }
    }
    scored.sort((a, b) {
      if (a.$2 != b.$2) return b.$2 - a.$2;
      final aw = (a.$1.website ?? '').toLowerCase();
      final bw = (b.$1.website ?? '').toLowerCase();
      if (aw.length != bw.length) return aw.length - bw.length;
      return aw.compareTo(bw);
    });
    return [for (final e in scored) e.$1];
  }

  /// 词集模式排序：共享词多者优先 → 前缀命中优先 → 字母序。
  static int _rank((LogRecord, int) a, (LogRecord, int) b, String ql) {
    if (a.$2 != b.$2) return b.$2 - a.$2;
    final aw = (a.$1.website ?? '').toLowerCase();
    final bw = (b.$1.website ?? '').toLowerCase();
    final ap = aw.startsWith(ql) ? 0 : 1;
    final bp = bw.startsWith(ql) ? 0 : 1;
    if (ap != bp) return ap - bp;
    return aw.compareTo(bw);
  }

  /// 解密密码字段；失败抛 [CryptoException]（主密钥错或数据坏）。
  String decryptPassword(LogRecord r, VaultCipher cipher) {
    final ct = r.encryptedPassword;
    if (ct == null) {
      throw const CryptoException('记录无密文字段');
    }
    return cipher.decrypt(ct);
  }

  /// [decryptPassword] 的异步版：密钥未缓存时在后台 isolate 派生，
  /// 复制/打开详情等用户手势路径用它，UI 线程零 PBKDF2。
  Future<String> decryptPasswordAsync(LogRecord r, VaultCipher cipher) {
    final ct = r.encryptedPassword;
    if (ct == null) {
      throw const CryptoException('记录无密文字段');
    }
    return cipher.decryptAsync(ct);
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
