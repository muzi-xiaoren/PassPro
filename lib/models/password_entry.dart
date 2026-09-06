import 'dart:convert';

/// 内存里的一条密码记录（明文 password 字段，仅在内存中存在）。
class PasswordEntry {
  final String id;
  final String website;
  final String username;
  final String password;
  final DateTime updatedAt;

  const PasswordEntry({
    required this.id,
    required this.website,
    required this.username,
    required this.password,
    required this.updatedAt,
  });

  PasswordEntry copyWith({
    String? website,
    String? username,
    String? password,
    DateTime? updatedAt,
  }) {
    return PasswordEntry(
      id: id,
      website: website ?? this.website,
      username: username ?? this.username,
      password: password ?? this.password,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 日志中的一行：操作类型 + record_id + 时间戳 + (密文) website/username/password。
///
/// 物理格式（行式 JSON，便于 git diff 与冲突合并）：
///   {"op":"ADD","id":"...","ts":1715000000,"w":"github.com","u":"alice","p":"<fernet-ct>"}
///   {"op":"DEL","id":"...","ts":1715000001}
///
/// 设计取舍：website/username 保持明文（便于 git diff 与冲突合并），密码字段为密文。
enum LogOp { add, update, delete }

/// keyring（用主密钥包起来的库密钥）作为一条 id 固定的普通记录存在同一个日志里。
///
/// 为什么不另起一种行类型：老版本的 PassPro 解析不认识的 op 会直接跳过整行，
/// 一旦它做了压实/整表重写就会把 keyring 弄丢——而 keyring 丢了整库就永远打不开。
/// 存成普通记录，老版本会原样保留它（只是在列表里显示成一条空条目）。
/// 新版本把它从 [MemoryIndex] 的活记录里摘出去，UI 完全看不到，也删不掉。
const String kKeyringRecordId = '__passpro_keyring__';

class LogRecord {
  final LogOp op;
  final String id;
  final DateTime ts;
  final String? website;
  final String? username;
  final String? encryptedPassword;

  const LogRecord({
    required this.op,
    required this.id,
    required this.ts,
    this.website,
    this.username,
    this.encryptedPassword,
  });

  String toLine() {
    final m = <String, Object?>{
      'op': switch (op) {
        LogOp.add => 'ADD',
        LogOp.update => 'UPD',
        LogOp.delete => 'DEL',
      },
      'id': id,
      'ts': ts.toUtc().millisecondsSinceEpoch ~/ 1000,
    };
    if (op != LogOp.delete) {
      m['w'] = website ?? '';
      m['u'] = username ?? '';
      m['p'] = encryptedPassword ?? '';
    }
    return jsonEncode(m);
  }

  static LogRecord fromLine(String line) {
    final m = jsonDecode(line) as Map<String, dynamic>;
    final op = switch (m['op'] as String) {
      'ADD' => LogOp.add,
      'UPD' => LogOp.update,
      'DEL' => LogOp.delete,
      final other => throw FormatException('未知 op: $other'),
    };
    return LogRecord(
      op: op,
      id: m['id'] as String,
      ts: DateTime.fromMillisecondsSinceEpoch(
        (m['ts'] as int) * 1000,
        isUtc: true,
      ),
      website: m['w'] as String?,
      username: m['u'] as String?,
      encryptedPassword: m['p'] as String?,
    );
  }
}
