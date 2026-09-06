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
  // --check：只校验主密钥并把每条记录的情况列出来，一个字节都不写。
  final checkOnly = args.contains('--check');
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final path = positional.isNotEmpty
      ? positional.first
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

  if (keyring != null && !checkOnly) {
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
  if (!checkOnly) {
    stdout.writeln('');
    stdout.writeln('注意：迁移后老版本 PassPro 读不了这个库，所有设备都要升到 1.1.0。');
    stdout.writeln('如果开了云同步，请先拉取一次再迁移，迁完再推送。');
  }
  stdout.writeln('');

  final password = _readMasterKey();
  if (password == null) return 1;
  // 只报长度和是否含非 ASCII：够看出"终端把输入截了/串了"，又不泄露密钥本身。
  final nonAscii = password.runes.any((r) => r > 127);
  stdout.writeln('读到主密钥：${password.length} 个字符'
      '${nonAscii ? '（含非 ASCII 字符）' : '（全部是 ASCII）'}');

  if (checkOnly) {
    _report(active.values.toList(), password);
    return 0;
  }

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

/// 只查不改：把每条记录按盐分组，报告这把主密钥能解开哪些。
void _report(List<LogRecord> active, String password) {
  final cipher = VaultCipher(password, vaultKey: VaultCipher.newVaultKey());
  final groups = <String, List<LogRecord>>{};
  for (final r in active) {
    final ct = r.encryptedPassword;
    final key = (ct == null || ct.isEmpty)
        ? '<无密文>'
        : switch (VaultCipher.tokenParams(ct)) {
            final p? => base64Url.encode(p.salt).substring(0, 8),
            _ => VaultCipher.isLegacyToken(ct) ? '<v1 但解析不出>' : '<非 v1>',
          };
    (groups[key] ??= []).add(r);
  }
  final sorted = groups.entries.toList()
    ..sort((a, b) => b.value.length - a.value.length);

  stdout.writeln('');
  stdout.writeln('按盐分组（盐取 base64 前 8 位）：');
  var okTotal = 0;
  for (final g in sorted) {
    var ok = 0;
    for (final r in g.value) {
      final ct = r.encryptedPassword;
      if (ct == null || ct.isEmpty) continue;
      try {
        cipher.decrypt(ct);
        ok++;
      } on CryptoException {
        // 解不开
      }
    }
    okTotal += ok;
    stdout.writeln('  盐 ${g.key.padRight(16)} ${g.value.length.toString().padLeft(3)} 条'
        '  能解开 $ok 条'
        '  例：${g.value.take(3).map((r) => r.website ?? '?').join('、')}');
  }
  stdout.writeln('');
  stdout.writeln('合计：${active.length} 条里能解开 $okTotal 条。');
  if (okTotal == 0) {
    stdout.writeln('');
    stdout.writeln('一条都解不开，通常是这两种情况之一：');
    stdout.writeln('  1) 输入被终端截断/串码了——看上面报的字符数对不对得上；');
    stdout.writeln('  2) 这个库当初就不是用这把主密钥建的。老版本的 PassPro 从来');
    stdout.writeln('     不校验主密钥，输错也照样放进主界面，所以有可能一直没发现。');
  }
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
