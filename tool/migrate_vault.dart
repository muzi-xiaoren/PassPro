// 把老格式（v1：每条密文自带盐、密钥 = PBKDF2(主密钥, 盐)）的库迁移到
// 两层密钥（v2：记录用随机库密钥加密，库密钥由主密钥包成 keyring）。
//
// 用法：
//   dart run tool/migrate_vault.dart [passwords.log 的路径]
//
// app 在首次解锁时会自动做同样的事；这个脚本是给"想先在本机迁完再上传"的场景
// 准备的，用的是 app 里同一份 VaultCipher 代码，不是另写一套。
//
// - 主密钥只从终端读，不回显、不打印、不落盘；
// - 动手前先把原件复制成 passwords.log.v1bak；
// - 只往日志尾部追加，绝不重写已有行；
// - 每条新密文写之前都先解一次校验，解不出来就跳过、原样保留。
import 'dart:convert';
import 'dart:io';

import 'package:passpro/crypto/vault_cipher.dart';
import 'package:passpro/models/password_entry.dart';

const _defaultMacPath =
    'Library/Application Support/com.example.PassPro/PassPro/passwords.log';

Future<int> main(List<String> args) async {
  final path = args.isNotEmpty
      ? args.first
      : '${Platform.environment['HOME']}/$_defaultMacPath';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('找不到日志文件：$path');
    return 1;
  }
  stdout.writeln('库文件：$path');

  final raw = file.readAsLinesSync();
  final records = <LogRecord>[];
  var badLines = 0;
  for (final line in raw) {
    final t = line.trim();
    if (t.isEmpty) continue;
    try {
      records.add(LogRecord.fromLine(t));
    } catch (_) {
      badLines++; // 坏行原样留在文件里，不动它
    }
  }

  // replay 出活记录 + keyring
  final active = <String, LogRecord>{};
  LogRecord? keyring;
  for (final r in records) {
    if (r.id == kKeyringRecordId) {
      if (r.op != LogOp.delete) keyring = r;
      continue;
    }
    if (r.op == LogOp.delete) {
      active.remove(r.id);
    } else {
      active[r.id] = r;
    }
  }
  stdout.writeln('总行数 ${raw.length}（坏行 $badLines）｜活记录 ${active.length}');

  if (keyring != null) {
    stdout.writeln('这个库已经有 keyring 了，不需要再迁移。');
    return 0;
  }

  final legacy = [
    for (final r in active.values)
      if (r.encryptedPassword case final ct?)
        if (ct.isNotEmpty && VaultCipher.isLegacyToken(ct)) r,
  ];
  final salts = <String>{};
  for (final r in legacy) {
    final p = VaultCipher.tokenParams(r.encryptedPassword!);
    if (p != null) salts.add(base64Url.encode(p.salt));
  }
  stdout.writeln('待迁移 ${legacy.length} 条，涉及 ${salts.length} 个盐'
      '（老结构下每次解锁都要按盐数跑一遍 PBKDF2）');
  stdout.writeln('');
  stdout.writeln('注意：迁移后老版本 PassPro 读不了这个库，所有设备都要升到 1.1.0。');
  stdout.writeln('如果开了云同步，请先拉取一次再迁移，迁完再推送。');
  stdout.writeln('');

  final password = _readMasterKey();
  if (password == null) return 1;

  // 校验主密钥：至少要能解开一条老记录。
  final vaultKey = VaultCipher.newVaultKey();
  final cipher = VaultCipher(password, vaultKey: vaultKey);
  if (legacy.isNotEmpty) {
    stdout.writeln('正在校验主密钥…');
    var ok = false;
    for (final r in legacy) {
      try {
        cipher.decrypt(r.encryptedPassword!);
        ok = true;
        break;
      } on CryptoException {
        // 这条解不开，继续试下一条（库里可能混着别的密钥加密的记录）
      }
    }
    if (!ok) {
      stderr.writeln('主密钥不对：库里没有一条记录能用它解开，什么都没改。');
      return 1;
    }
    stdout.writeln('主密钥校验通过。');
  }

  // 迁移前先留一份原件。
  final backup = File('$path.v1bak');
  if (!backup.existsSync()) {
    file.copySync(backup.path);
    stdout.writeln('原件已备份：${backup.path}');
  } else {
    stdout.writeln('已存在备份，保留第一份：${backup.path}');
  }

  final now = DateTime.now().toUtc();
  final fresh = <LogRecord>[
    LogRecord(
      op: LogOp.update,
      id: kKeyringRecordId,
      ts: now,
      website: '',
      username: '',
      encryptedPassword: VaultCipher.wrapVaultKey(password, vaultKey),
    ),
  ];
  var skipped = 0;
  for (final r in legacy) {
    final ct = r.encryptedPassword!;
    final String plain;
    try {
      plain = cipher.decrypt(ct);
    } on CryptoException {
      skipped++; // 别的主密钥加密的：原样保留，不丢
      continue;
    }
    final String next;
    try {
      next = cipher.encrypt(plain);
      if (cipher.decrypt(next) != plain) {
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

  final sink = file.openWrite(mode: FileMode.append);
  for (final r in fresh) {
    sink.writeln(r.toLine());
  }
  await sink.flush();
  await sink.close();

  stdout.writeln('');
  stdout.writeln('迁移完成：转换 ${fresh.length - 1} 条，跳过 $skipped 条'
      '${skipped > 0 ? '（这些用当前主密钥解不开，原样留着了）' : ''}');
  stdout.writeln('之后解锁只需要拆 keyring 那一次 PBKDF2，跟库里有多少条无关。');
  return 0;
}

/// 从终端读主密钥，不回显。
String? _readMasterKey() {
  if (!stdin.hasTerminal) {
    stderr.writeln('需要在终端里运行（要读主密钥且不回显）。');
    return null;
  }
  stdout.write('请输入主密钥（不会回显，也不会被打印或保存）：');
  final previous = stdin.echoMode;
  stdin.echoMode = false;
  final pw = stdin.readLineSync(encoding: utf8);
  stdin.echoMode = previous;
  stdout.writeln('');
  if (pw == null || pw.isEmpty) {
    stderr.writeln('没读到主密钥，什么都没改。');
    return null;
  }
  return pw;
}
