import 'package:flutter_test/flutter_test.dart';
import 'package:passman_pro/models/password_entry.dart';
import 'package:passman_pro/storage/conflict_merger.dart';

void main() {
  group('conflict_merger', () {
    LogRecord add(String id, int ts, String w) => LogRecord(
          op: LogOp.add,
          id: id,
          ts: DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true),
          website: w,
          username: '',
          encryptedPassword: 'ct',
        );
    LogRecord upd(String id, int ts, String w) => LogRecord(
          op: LogOp.update,
          id: id,
          ts: DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true),
          website: w,
          username: '',
          encryptedPassword: 'ct',
        );
    LogRecord del(String id, int ts) => LogRecord(
          op: LogOp.delete,
          id: id,
          ts: DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true),
        );

    test('union 两端独立 id', () {
      final merged = mergeLogs(
        [add('a', 1, 'a.com')],
        [add('b', 2, 'b.com')],
      );
      expect(merged.length, 2);
    });

    test('同 id 取 ts 更大', () {
      final merged = mergeLogs(
        [add('a', 1, 'old.com')],
        [upd('a', 2, 'new.com')],
      );
      expect(merged.single.website, 'new.com');
    });

    test('同 ts 时 DEL 胜出', () {
      final merged = mergeLogs(
        [upd('a', 5, 'x.com')],
        [del('a', 5)],
      );
      expect(merged.single.op, LogOp.delete);
    });

    test('输出按时间升序', () {
      final merged = mergeLogs(
        [add('b', 3, 'b'), add('a', 1, 'a')],
        [add('c', 2, 'c')],
      );
      expect(merged.map((r) => r.id).toList(), ['a', 'c', 'b']);
    });
  });
}
