import 'package:flutter_test/flutter_test.dart';
import 'package:passpro/storage/csv_codec.dart';

void main() {
  group('csv_codec', () {
    test('普通字段往返', () {
      final rows = [
        ['website', 'username', 'password'],
        ['github.com', 'alice', 'p@ss'],
      ];
      final text = encodeCsv(rows);
      expect(decodeCsv(text), rows);
    });

    test('含逗号/引号/换行的字段被正确转义并还原', () {
      final rows = [
        ['a,b', 'he said "hi"', 'line1\nline2'],
      ];
      final text = encodeCsv(rows);
      // 逗号、引号、换行的字段都应被双引号包裹
      expect(text.contains('"a,b"'), isTrue);
      expect(text.contains('"he said ""hi"""'), isTrue);
      expect(decodeCsv(text), rows);
    });

    test('密码含逗号与等号也能完整往返', () {
      final rows = [
        ['site', 'u', 'A1b2,C3=d4"e5'],
      ];
      expect(decodeCsv(encodeCsv(rows)), rows);
    });

    test('空输入返回空列表', () {
      expect(decodeCsv(''), isEmpty);
    });

    test('末尾换行不产生多余空行', () {
      expect(decodeCsv('a,b\r\n'), [
        ['a', 'b'],
      ]);
      expect(decodeCsv('a,b\n'), [
        ['a', 'b'],
      ]);
    });

    test('无引号的 \\n 与 \\r\\n 都识别为换行', () {
      expect(decodeCsv('a,b\nc,d'), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('末尾无换行也能读到最后一行', () {
      expect(decodeCsv('x,y,z'), [
        ['x', 'y', 'z'],
      ]);
    });
  });
}
