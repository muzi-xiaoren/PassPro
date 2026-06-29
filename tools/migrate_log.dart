// PassPro 加密迁移脚本（一次性，离线运行，不打进 app）。
//
// 作用：把旧版 PassPro 的 passwords.log（密码字段为 Fernet 密文，
// 密钥 = sha256(主密码)）迁移成新版格式（密码字段为 AES-256-GCM 密文，
// 密钥 = PBKDF2-HMAC-SHA256(主密码, 随机盐)）。
//
//   1. 先把原 log 备份到 ~/Downloads/PassPro-backup-<时间戳>.log；
//   2. 提示输入主密钥；
//   3. 逐行把 Fernet 密文解密后用新算法重新加密，仅替换 "p" 字段，
//      op/id/ts/w/u 全部原样保留（不动日志结构）；
//   4. 原子写回原 log。
//
// 用法（在仓库根目录，需已装 Flutter/Dart）：
//   dart run tools/migrate_log.dart [log文件路径]
// 不传路径时默认 macOS 路径：
//   ~/Library/Application Support/com.example.PassPro/PassPro/passwords.log
//
// 注意：运行前请确保 PassPro 已关闭；迁移后请用新版 app 打开验证再删备份。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:passpro/crypto/vault_cipher.dart';
import 'package:pointycastle/export.dart';

Future<void> main(List<String> args) async {
  final logPath = args.isNotEmpty ? args.first : _defaultMacLogPath();
  final logFile = File(logPath);
  if (!logFile.existsSync()) {
    stderr.writeln('找不到日志文件：$logPath');
    stderr.writeln('可手动指定路径： dart run tools/migrate_log.dart /path/to/passwords.log');
    exit(1);
  }

  final original = logFile.readAsStringSync();

  // 1) 备份到 ~/Downloads。
  final backup = _backup(original);
  stdout.writeln('已备份原日志到：${backup.path}');

  // 2) 读取主密钥（与 app 一致：留空当作单个空格）。
  stdout.write('请输入主密钥（输入时不回显，回车确认）：');
  final master = _readMasterKey();
  final password = master.isEmpty ? ' ' : master;
  final legacyKey = Uint8List.fromList(sha256.convert(utf8.encode(password)).bytes);

  final cipher = VaultCipher(password);

  // 3) 逐行迁移。
  final lines = const LineSplitter().convert(original);
  final out = StringBuffer();
  var migrated = 0, kept = 0, failed = 0;

  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    Map<String, dynamic> m;
    try {
      m = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      out.writeln(line); // 不认识的行原样保留
      kept++;
      continue;
    }
    final p = m['p'] as String?;
    if (p == null || p.isEmpty) {
      out.writeln(jsonEncode(m)); // DEL 等无密文行
      kept++;
      continue;
    }
    // 已是新格式（version 0x01）则跳过，幂等可重复运行。
    if (_isNewFormat(p)) {
      out.writeln(jsonEncode(m));
      kept++;
      continue;
    }
    try {
      final plain = _fernetDecrypt(p, legacyKey);
      m['p'] = cipher.encrypt(plain);
      out.writeln(jsonEncode(m));
      migrated++;
    } catch (e) {
      stderr.writeln('解密失败（主密钥错误或数据损坏），保留原行：id=${m['id']} $e');
      out.writeln(jsonEncode(m));
      failed++;
    }
  }

  if (failed > 0) {
    stderr.writeln('\n有 $failed 条解密失败，未做改动。请确认主密钥正确后重跑（脚本可重复运行）。');
    stderr.writeln('原日志未被覆盖。');
    exit(2);
  }

  // 4) 原子写回。
  final tmp = File('${logFile.path}.tmp');
  tmp.writeAsStringSync(out.toString());
  tmp.renameSync(logFile.path);

  stdout.writeln('\n迁移完成：重新加密 $migrated 条，保留 $kept 行。');
  stdout.writeln('请用新版 PassPro 打开验证无误后再删除备份。');
}

String _defaultMacLogPath() {
  final home = Platform.environment['HOME'] ?? '';
  return '$home/Library/Application Support/com.example.PassPro/PassPro/passwords.log';
}

File _backup(String content) {
  final home = Platform.environment['HOME'] ?? '.';
  final downloads = Directory('$home/Downloads');
  if (!downloads.existsSync()) downloads.createSync(recursive: true);
  final now = DateTime.now();
  String two(int x) => x.toString().padLeft(2, '0');
  final stamp = '${now.year}${two(now.month)}${two(now.day)}-'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  final f = File('${downloads.path}/PassPro-backup-$stamp.log');
  f.writeAsStringSync(content);
  return f;
}

/// 关闭终端回显读一行主密钥；非终端(管道)环境下优雅退化为普通读取。
String _readMasterKey() {
  bool? hadEcho;
  try {
    hadEcho = stdin.echoMode; // 非 TTY 时 getter 也会抛，需一并捕获
    stdin.echoMode = false;
  } catch (_) {}
  final line = stdin.readLineSync(encoding: utf8) ?? '';
  try {
    if (hadEcho != null) stdin.echoMode = hadEcho;
  } catch (_) {}
  stdout.writeln();
  return line;
}

/// 新格式 token：base64url 解码后首字节为 0x01。
bool _isNewFormat(String token) {
  try {
    final pad = (4 - token.length % 4) % 4;
    final data = base64Url.decode(token + ('=' * pad));
    return data.isNotEmpty && data[0] == 0x01;
  } catch (_) {
    return false;
  }
}

/// 旧版 Fernet (spec 0x80) 解密。key = sha256(主密码)。
///   token = base64url( 0x80 || ts(8) || iv(16) || ct || hmac_sha256(32) )
///   signing_key = key[0:16]，encryption_key = key[16:32]，AES-128-CBC + PKCS7
String _fernetDecrypt(String token, Uint8List key) {
  final pad = (4 - token.length % 4) % 4;
  final data = base64Url.decode(token + ('=' * pad));
  if (data.length < 1 + 8 + 16 + 16 + 32 || data[0] != 0x80) {
    throw const FormatException('不是合法的 Fernet token');
  }
  final mac = data.sublist(data.length - 32);
  final body = data.sublist(0, data.length - 32);
  final signingKey = key.sublist(0, 16);
  final expected = Hmac(sha256, signingKey).convert(body).bytes;
  if (!_constantTimeEquals(mac, expected)) {
    throw const FormatException('HMAC 校验失败（主密钥错误或数据被篡改）');
  }
  final iv = Uint8List.fromList(data.sublist(9, 25));
  final ciphertext = Uint8List.fromList(data.sublist(25, data.length - 32));
  final encryptionKey = key.sublist(16, 32);

  final cbc = CBCBlockCipher(AESEngine())
    ..init(false, ParametersWithIV<KeyParameter>(KeyParameter(encryptionKey), iv));
  if (ciphertext.isEmpty || ciphertext.length % 16 != 0) {
    throw const FormatException('密文长度不是 16 的整数倍');
  }
  final out = Uint8List(ciphertext.length);
  for (var off = 0; off < ciphertext.length; off += 16) {
    cbc.processBlock(ciphertext, off, out, off);
  }
  final padLen = out[out.length - 1];
  if (padLen < 1 || padLen > 16) {
    throw const FormatException('PKCS7 padding 不合法');
  }
  return utf8.decode(out.sublist(0, out.length - padLen));
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
