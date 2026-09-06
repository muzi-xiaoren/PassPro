import 'dart:convert';

import '../crypto/vault_cipher.dart';
import '../models/password_entry.dart';
import '../models/search_config.dart';
import 'conflict_merger.dart';
import 'csv_codec.dart';
import 'log_store.dart';
import 'memory_index.dart';

/// 业务层入口：把 [LogStore] + [MemoryIndex] 拼成 CRUD API。
/// UI 只跟这个类打交道。
class VaultRepository {
  VaultRepository._(this.store, this.index);

  final LogStore store;
  final MemoryIndex index;

  static Future<VaultRepository> open() async {
    final store = await LogStore.open();
    final index = MemoryIndex();
    index.replay(await store.readAll());
    return VaultRepository._(store, index);
  }

  /// 新建一条；同 (website, username) 且密码相同视为重复，返回 false。
  Future<bool> add({
    required String website,
    required String username,
    required String plaintextPassword,
    required VaultCipher cipher,
  }) async {
    if (website.isEmpty) {
      throw ArgumentError('website 不能为空');
    }

    // 重复判定：同 website + username + 解出来明文一致
    final exist = index.findByWebsiteAndUsername(website, username);
    final existCt = exist?.encryptedPassword;
    if (existCt != null && existCt.isNotEmpty) {
      try {
        final old = cipher.decrypt(existCt);
        if (old == plaintextPassword) return false;
      } on CryptoException {
        // 解不出来视为不同账户，继续走 add 路径
      }
    }

    final ct = cipher.encrypt(plaintextPassword);
    final record = LogRecord(
      op: LogOp.add,
      id: _newId(),
      ts: DateTime.now().toUtc(),
      website: website,
      username: username,
      encryptedPassword: ct,
    );
    await store.append(record);
    index.apply(record);
    return true;
  }

  /// 更新一条（按 id）。
  Future<void> update({
    required String id,
    String? website,
    String? username,
    String? plaintextPassword,
    required VaultCipher cipher,
  }) async {
    final current = index.get(id);
    if (current == null) {
      throw StateError('record $id 不存在');
    }
    final newCt = plaintextPassword == null
        ? current.encryptedPassword!
        : cipher.encrypt(plaintextPassword);

    final record = LogRecord(
      op: LogOp.update,
      id: id,
      ts: DateTime.now().toUtc(),
      website: website ?? current.website,
      username: username ?? current.username,
      encryptedPassword: newCt,
    );
    await store.append(record);
    index.apply(record);
  }

  /// 按 record_id 删除（写 tombstone）。
  Future<void> deleteById(String id) async {
    if (index.get(id) == null) {
      throw StateError('record $id 不存在');
    }
    final record = LogRecord(
      op: LogOp.delete,
      id: id,
      ts: DateTime.now().toUtc(),
    );
    await store.append(record);
    index.apply(record);
  }

  /// 查询（关键词拆分匹配）。返回的是**仍为密文**的命中记录，明文密码由界面
  /// 在用户点"显示 / 复制 / 编辑"时按需解密（[MemoryIndex.decryptPasswordAsync]）。
  ///
  /// **同步版，只在密钥必然已缓存时使用**（测试 / 桌面脚本）。UI 一律走
  /// [queryAsync]：密钥没缓存时探测那一下会就地跑 PBKDF2，把点击那一帧冻住。
  QueryResult query(String website, VaultCipher cipher, SearchConfig config) {
    final hits = index.search(website, config);
    if (hits.isEmpty) return const QueryResult.empty();
    return _probeKey(hits, cipher);
  }

  /// [query] 的异步版：命中记录用到的盐先在后台 isolate 里一次性派生好，
  /// 之后的解密全部命中缓存，UI 线程零 PBKDF2。查询界面必须用这个。
  Future<QueryResult> queryAsync(
    String website,
    VaultCipher cipher,
    SearchConfig config,
  ) async {
    final hits = index.search(website, config);
    if (hits.isEmpty) return const QueryResult.empty();
    try {
      await cipher
          .warmUpForTokens([for (final r in hits) r.encryptedPassword]);
    } catch (_) {
      // 预热失败就退回按需派生，功能不受影响。
    }
    return _probeKey(hits, cipher);
  }

  /// 只解一条来判断主密钥对不对——以前是把每条命中都解开塞进结果里，
  /// 一次查询就把全部明文摊在内存里，白跑一堆 AES-GCM。
  /// 一条都解不开才算主密钥错误（有坏行时继续往下试）。
  QueryResult _probeKey(List<LogRecord> hits, VaultCipher cipher) {
    for (final r in hits) {
      final ct = r.encryptedPassword;
      // 密文字段缺失（老数据 / 合并进来的残缺行）：以前这里是 `!`，
      // 抛的是 TypeError 而不是 CryptoException，会直接逃出点击回调。
      if (ct == null || ct.isEmpty) continue;
      try {
        cipher.decrypt(ct);
        return QueryResult.ok(hits);
      } on CryptoException {
        // 这条解不开，继续试下一条
      }
    }
    return const QueryResult.invalidKey();
  }

  // ============ 库密钥 / 迁移到 v2 ============

  /// 当前 keyring（用主密钥包起来的库密钥）；老库还没迁移时为 null。
  String? get keyring => index.keyring;

  /// 写入/更新 keyring。ts=now，合并时新的胜出——换主密钥就落这一行，O(1)。
  Future<void> writeKeyring(String blob) async {
    final r = LogRecord(
      op: LogOp.update,
      id: kKeyringRecordId,
      ts: DateTime.now().toUtc(),
      website: '',
      username: '',
      encryptedPassword: blob,
    );
    await store.append(r);
    index.apply(r);
  }

  /// 迁移前留一份原件：`passwords.log.v1bak`（只留第一份）。
  Future<String?> backupBeforeMigration() => store.backupOnce('v1bak');

  /// 把还停在 v1 的记录逐条转成 v2（改用库密钥加密，不再带盐、不再跑 PBKDF2）。
  ///
  /// 迁移完之后，解锁只剩"拆 keyring"那一次 PBKDF2，跟库里有多少条无关。
  /// [c] 解不开的记录（主密钥不对）原样保留并计入 [MigrationReport.skipped]，
  /// 不会丢数据；写回前会再解一次校验，确保新密文可读才落盘。
  ///
  /// 所需的 v1 密钥在本方法内先统一后台预热；预热不到的直接跳过——迁移是后台
  /// 维护动作，绝不能自己在 UI 线程上补跑 PBKDF2（那正是卡死的老毛病）。
  Future<MigrationReport> migrateToVaultKey(VaultCipher c) async {
    if (!c.hasVaultKey) {
      return const MigrationReport(converted: 0, skipped: 0);
    }
    final targets = [
      for (final r in index.activeRecords.toList(growable: false))
        if (r.encryptedPassword case final ct?)
          if (ct.isNotEmpty && VaultCipher.isLegacyToken(ct)) r,
    ];
    if (targets.isEmpty) {
      return const MigrationReport(converted: 0, skipped: 0);
    }
    try {
      await c.warmUpForTokens([for (final r in targets) r.encryptedPassword]);
    } catch (_) {
      // 预热失败就靠下面的 isKeyWarm 兜底，本轮能转多少转多少。
    }

    final fresh = <LogRecord>[];
    var skipped = 0;
    final now = DateTime.now().toUtc();
    for (final snapshot in targets) {
      // 快照到这里隔着预热的那几秒 await：期间用户可能改了/删了记录，同步也
      // 可能整表 replay 过。一律拿索引里的**当前版本**来转，绝不能用快照里的
      // 老内容盖回去——那等于把用户刚存的改动或远端的更新悄悄回滚。
      final r = index.get(snapshot.id);
      if (r == null) continue; // 期间被删了：别用 UPD 把它复活
      final ct = r.encryptedPassword;
      if (ct == null || ct.isEmpty) continue;
      if (!VaultCipher.isLegacyToken(ct)) continue; // 期间已经是 v2 了
      if (!c.isKeyWarm(ct)) {
        skipped++;
        continue;
      }
      final String plain;
      try {
        plain = c.decrypt(ct);
      } on CryptoException {
        skipped++;
        continue;
      }
      final String next;
      try {
        next = c.encrypt(plain);
        if (c.decrypt(next) != plain) {
          skipped++;
          continue;
        }
      } on CryptoException {
        skipped++;
        continue;
      }
      fresh.add(LogRecord(
        op: LogOp.update,
        id: r.id,
        ts: now,
        website: r.website,
        username: r.username,
        encryptedPassword: next,
      ));
    }
    if (fresh.isNotEmpty) {
      await store.appendAll(fresh);
      index.applyAll(fresh);
    }
    return MigrationReport(converted: fresh.length, skipped: skipped);
  }

  // ============ 本地导入 / 导出 ============

  /// 当前加密日志文件的原始字节（用于"导出加密备份 .log"）。
  Future<List<int>> exportLogBytes() => store.file.readAsBytes();

  /// 导入一份 .log 备份字节：解析后与现有库按 record_id 合并（不丢数据），
  /// 再原子重写并 replay。返回新增条数与合并后总条数。
  /// 解析不出任何有效记录时抛 [FormatException]（多半是选错了文件）。
  Future<ImportResult> importLogBytes(List<int> bytes) async {
    final text = utf8.decode(bytes, allowMalformed: true);
    final imported = <LogRecord>[];
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      try {
        imported.add(LogRecord.fromLine(line));
      } catch (_) {
        // 跳过坏行
      }
    }
    if (imported.isEmpty) {
      throw const FormatException('文件中没有可识别的记录');
    }
    final beforeIds = index.activeRecords.map((r) => r.id).toSet();
    final merged = mergeLogs(await store.readAll(), imported);
    await store.replaceAll(merged);
    index.replay(await store.readAll());
    final afterIds = index.activeRecords.map((r) => r.id).toSet();
    final added = afterIds.difference(beforeIds).length;
    return ImportResult(added: added, total: afterIds.length);
  }

  /// 把当前库导成明文 CSV（首行表头）。无法用当前主密钥解出的记录会被跳过。
  /// 返回 CSV 文本与实际导出的条数。
  ({String csv, int count}) exportCsv(VaultCipher cipher) {
    final rows = <List<String>>[
      ['website', 'username', 'password'],
    ];
    for (final r in index.activeRecords) {
      String pw;
      try {
        pw = index.decryptPassword(r, cipher);
      } on CryptoException {
        continue; // 当前主密钥解不出来的记录跳过
      }
      rows.add([r.website ?? '', r.username ?? '', pw]);
    }
    return (csv: encodeCsv(rows), count: rows.length - 1);
  }

  /// 从明文 CSV 导入：按 网站,账号,密码 三列读取，逐条用当前主密钥加密入库。
  /// 自动跳过表头行与空行；与现有完全相同的条目（去重）不重复计数。
  Future<ImportResult> importCsv(String text, VaultCipher cipher) async {
    final rows = decodeCsv(text);
    var added = 0;
    var headerChecked = false;
    for (final row in rows) {
      if (row.every((c) => c.trim().isEmpty)) continue;
      final website = row.isNotEmpty ? row[0].trim() : '';
      final username = row.length > 1 ? row[1].trim() : '';
      final password = row.length > 2 ? row[2] : '';
      if (!headerChecked) {
        headerChecked = true;
        if (_looksLikeHeader(website)) continue;
      }
      if (website.isEmpty || password.isEmpty) continue;
      final ok = await add(
        website: website,
        username: username,
        plaintextPassword: password,
        cipher: cipher,
      );
      if (ok) added++;
    }
    return ImportResult(added: added, total: index.activeCount);
  }

  static bool _looksLikeHeader(String first) {
    const heads = {'website', 'url', 'site', '网站', '网址', 'address'};
    return heads.contains(first.toLowerCase());
  }

  static String _newId() {
    // 16 字节随机 + 时间戳前缀，足够单设备内唯一
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36);
    final rnd = (DateTime.now().microsecond * 1315423911) & 0x7FFFFFFF;
    return '$ts-${rnd.toRadixString(36)}';
  }
}

/// 迁移结果：成功转成 v2 的条数与解不开被跳过的条数。
class MigrationReport {
  final int converted;
  final int skipped;
  const MigrationReport({required this.converted, required this.skipped});
  bool get didNothing => converted == 0 && skipped == 0;
}

/// 导入结果：本次新增的条数与合并/入库后的总条数。
class ImportResult {
  final int added;
  final int total;
  const ImportResult({required this.added, required this.total});
}

class QueryResult {
  /// 命中的记录，密码字段仍是密文。明文按需解密，不在查询时批量摊开。
  final List<LogRecord> records;
  final bool invalidKey;

  const QueryResult.ok(this.records) : invalidKey = false;
  const QueryResult.invalidKey()
      : records = const [],
        invalidKey = true;
  const QueryResult.empty()
      : records = const [],
        invalidKey = false;

  bool get isEmpty => records.isEmpty && !invalidKey;
}
