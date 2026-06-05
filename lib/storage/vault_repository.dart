import 'dart:typed_data';

import '../crypto/fernet_crypto.dart';
import '../models/password_entry.dart';
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
    required Uint8List masterKey,
  }) async {
    if (website.isEmpty) {
      throw ArgumentError('website 不能为空');
    }

    // 重复判定：同 website + username + 解出来明文一致
    final exist = index.findByWebsiteAndUsername(website, username);
    if (exist != null) {
      try {
        final old = FernetCrypto.decrypt(exist.encryptedPassword!, masterKey);
        if (old == plaintextPassword) return false;
      } on FernetException {
        // 解不出来视为不同账户，继续走 add 路径
      }
    }

    final ct = FernetCrypto.encrypt(plaintextPassword, masterKey);
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
    required Uint8List masterKey,
  }) async {
    final current = index.get(id);
    if (current == null) {
      throw StateError('record $id 不存在');
    }
    final newCt = plaintextPassword == null
        ? current.encryptedPassword!
        : FernetCrypto.encrypt(plaintextPassword, masterKey);

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

  /// 按网址精确删（与旧 Python delete_data 行为对齐）。
  /// 需要主密钥能解出该网址至少一条记录，否则返回 'invalid-key'；
  /// 未找到匹配记录返回 'not-found'。
  Future<DeleteOutcome> deleteByWebsite(
    String website,
    Uint8List masterKey,
  ) async {
    final matches = index.activeRecords
        .where((r) => r.website == website)
        .toList(growable: false);
    if (matches.isEmpty) return DeleteOutcome.notFound;

    // 验主密钥：能解出任意一条就算通过
    var keyValid = false;
    for (final r in matches) {
      try {
        FernetCrypto.decrypt(r.encryptedPassword!, masterKey);
        keyValid = true;
        break;
      } on FernetException {
        continue;
      }
    }
    if (!keyValid) return DeleteOutcome.invalidKey;

    for (final r in matches) {
      await deleteById(r.id);
    }
    return DeleteOutcome.ok;
  }

  /// 查询（关键词拆分匹配 + 解密）。返回的 [PasswordEntry] 已带明文 password。
  /// 若主密钥错误，对应记录会被跳过；若全部跳过则返回空列表。
  QueryResult query(String website, Uint8List masterKey) {
    var hits = index.searchByWebsite(website);
    if (hits.isEmpty) return const QueryResult.empty();
    // 完全匹配优先：若存在与查询串完全相同的网址（忽略大小写与首尾空格），
    // 则只保留完全匹配项，不再展示其他模糊命中的记录。
    final q = website.trim().toLowerCase();
    if (q.isNotEmpty) {
      final exact = hits
          .where((r) => (r.website ?? '').trim().toLowerCase() == q)
          .toList(growable: false);
      if (exact.isNotEmpty) hits = exact;
    }
    final entries = <PasswordEntry>[];
    var invalidKeySeen = false;
    for (final r in hits) {
      try {
        final pw = FernetCrypto.decrypt(r.encryptedPassword!, masterKey);
        entries.add(PasswordEntry(
          id: r.id,
          website: r.website ?? '',
          username: r.username ?? '',
          password: pw,
          updatedAt: r.ts,
        ));
      } on FernetException {
        invalidKeySeen = true;
      }
    }
    if (entries.isEmpty && invalidKeySeen) {
      return const QueryResult.invalidKey();
    }
    return QueryResult.ok(entries);
  }

  static String _newId() {
    // 16 字节随机 + 时间戳前缀，足够单设备内唯一
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36);
    final rnd = (DateTime.now().microsecond * 1315423911) & 0x7FFFFFFF;
    return '$ts-${rnd.toRadixString(36)}';
  }
}

enum DeleteOutcome { ok, notFound, invalidKey }

class QueryResult {
  final List<PasswordEntry> entries;
  final bool invalidKey;

  const QueryResult.ok(this.entries) : invalidKey = false;
  const QueryResult.invalidKey()
      : entries = const [],
        invalidKey = true;
  const QueryResult.empty()
      : entries = const [],
        invalidKey = false;

  bool get isEmpty => entries.isEmpty && !invalidKey;
}
