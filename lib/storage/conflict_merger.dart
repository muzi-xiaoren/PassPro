import '../models/password_entry.dart';

/// 把本地和远端两份日志按 record_id 做行级 union：
///   - 同 id 取 ts 较大的那条
///   - DEL 永远胜过同 ts 的非 DEL（保证删除最终成立）
///   - 输出按 ts 升序排列，方便 replay
List<LogRecord> mergeLogs(List<LogRecord> a, List<LogRecord> b) {
  final byId = <String, LogRecord>{};
  void consider(LogRecord r) {
    final cur = byId[r.id];
    if (cur == null) {
      byId[r.id] = r;
      return;
    }
    if (r.ts.isAfter(cur.ts)) {
      byId[r.id] = r;
    } else if (r.ts == cur.ts &&
        r.op == LogOp.delete &&
        cur.op != LogOp.delete) {
      byId[r.id] = r;
    }
  }

  for (final r in a) {
    consider(r);
  }
  for (final r in b) {
    consider(r);
  }

  final out = byId.values.toList()
    ..sort((x, y) => x.ts.compareTo(y.ts));
  return out;
}
