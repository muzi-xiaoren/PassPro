/// 极简 RFC4180 CSV 编解码，仅用于密码库的明文导入/导出。
///
/// - 字段中含逗号 / 双引号 / 换行时，用双引号包裹，内部双引号转义为两个双引号。
/// - 解析支持带引号字段（可跨行）、`\r\n` 与 `\n` 两种换行。
library;

/// 把若干行编码成 CSV 文本（行间用 `\r\n`）。
String encodeCsv(List<List<String>> rows) =>
    rows.map((r) => r.map(_encodeField).join(',')).join('\r\n');

String _encodeField(String s) {
  final needsQuote = s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r');
  if (!needsQuote) return s;
  return '"${s.replaceAll('"', '""')}"';
}

/// 把整个 CSV 文本解析成行列。空输入返回空列表。
List<List<String>> decodeCsv(String input) {
  final rows = <List<String>>[];
  var field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;
  var i = 0;
  final n = input.length;

  void endField() {
    row.add(field.toString());
    field = StringBuffer();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  while (i < n) {
    final ch = input[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < n && input[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      field.write(ch);
      i++;
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
      i++;
      continue;
    }
    if (ch == ',') {
      endField();
      i++;
      continue;
    }
    if (ch == '\r') {
      if (i + 1 < n && input[i + 1] == '\n') i++;
      endRow();
      i++;
      continue;
    }
    if (ch == '\n') {
      endRow();
      i++;
      continue;
    }
    field.write(ch);
    i++;
  }
  // 收尾：仍有未结束的字段/行（文件末尾无换行）时补一行。
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}
