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
/// 设计取舍：website/username 第一版保持明文（与旧 Python 文件兼容），密码字段为 Fernet 密文。
enum LogOp { add, update, delete }

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
