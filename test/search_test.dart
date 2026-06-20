import 'package:flutter_test/flutter_test.dart';
import 'package:passpro/models/password_entry.dart';
import 'package:passpro/models/search_config.dart';
import 'package:passpro/storage/memory_index.dart';

void main() {
  LogRecord rec(String id, String website) => LogRecord(
        op: LogOp.add,
        id: id,
        ts: DateTime.fromMillisecondsSinceEpoch(int.parse(id) * 1000, isUtc: true),
        website: website,
        username: '',
        encryptedPassword: 'gAAAAAdummy',
      );

  MemoryIndex buildIndex() {
    final ix = MemoryIndex();
    ix.replay([
      rec('1', 'github.com'),
      rec('2', 'gitee.com'),
      rec('3', 'github.io'),
      rec('4', 'mygithub.example.com'),
    ]);
    return ix;
  }

  List<String> sites(List<LogRecord> rs) =>
      rs.map((r) => r.website ?? '').toList();

  group('MemoryIndex.search', () {
    test('exact：完全相同的网址只显示它', () {
      final ix = buildIndex();
      final r = ix.search('github.com', const SearchConfig(mode: SearchMode.exact));
      expect(sites(r), ['github.com']);
    });

    test('exact：无完全相同则返回词集相交项', () {
      final ix = buildIndex();
      // "github" 作为词，与 github.com / github.io 的词集相交
      final r = ix.search('github', const SearchConfig(mode: SearchMode.exact));
      expect(sites(r).toSet(), {'github.com', 'github.io'});
    });

    test('contains：显示所有相关项，最相关在前', () {
      final ix = buildIndex();
      final r =
          ix.search('github.com', const SearchConfig(mode: SearchMode.contains));
      // 全部 4 条都至少共享一个词（com 或 github），github.com 共享 2 个词排第一
      expect(r.length, 4);
      expect(r.first.website, 'github.com');
    });

    test('fuzzy：整串子串匹配，前缀优先', () {
      final ix = buildIndex();
      final r = ix.search('github', const SearchConfig(mode: SearchMode.fuzzy));
      // gitee.com 不含 "github"
      expect(sites(r).toSet(), {'github.com', 'github.io', 'mygithub.example.com'});
      // 前缀命中的排在前
      expect(r.first.website == 'github.com' || r.first.website == 'github.io',
          isTrue);
      expect(r.last.website, 'mygithub.example.com');
    });

    test('custom + fuzzy：按自定义分隔符拆成多关键词，需全部命中', () {
      final ix = buildIndex();
      final r = ix.search(
        'git com',
        const SearchConfig(
          mode: SearchMode.custom,
          customDelimiter: ' ',
          customStrategy: SearchStrategy.fuzzy,
        ),
      );
      // 需同时包含 "git" 和 "com"：github.io 不含 com，被排除
      expect(sites(r).toSet(),
          {'github.com', 'gitee.com', 'mygithub.example.com'});
    });

    test('custom + exact：用自定义分隔符做精确词集', () {
      final ix = buildIndex();
      final r = ix.search(
        'github.com',
        const SearchConfig(
          mode: SearchMode.custom,
          customDelimiter: '.',
          customStrategy: SearchStrategy.exact,
        ),
      );
      expect(sites(r), ['github.com']);
    });

    test('空查询返回全部', () {
      final ix = buildIndex();
      expect(ix.search('', const SearchConfig()).length, 4);
    });
  });
}
