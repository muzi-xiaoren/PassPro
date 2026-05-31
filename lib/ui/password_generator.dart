import 'dart:math';

/// 与旧 Python password_generate.py 等价：四类字符开关 + 长度，返回随机串。
class PasswordGenerator {
  static const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const _digits = '0123456789';
  // 与 Python string.punctuation 对齐
  static const _special = r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~''';

  static final _rng = Random.secure();

  static String generate({
    required int length,
    required bool useUpper,
    required bool useLower,
    required bool useDigits,
    required bool useSpecial,
  }) {
    final pool = StringBuffer();
    if (useUpper) pool.write(_upper);
    if (useLower) pool.write(_lower);
    if (useDigits) pool.write(_digits);
    if (useSpecial) pool.write(_special);
    final chars = pool.toString();
    if (chars.isEmpty || length <= 0) return '';
    return List.generate(length, (_) => chars[_rng.nextInt(chars.length)])
        .join();
  }
}
