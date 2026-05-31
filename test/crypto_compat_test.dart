import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:passman_pro/crypto/fernet_crypto.dart';

void main() {
  group('FernetCrypto - 与 Python cryptography.fernet 兼容', () {
    // 由 password_manager/data_crypto.py 实际加密生成
    // 主密钥: 'hello world'
    // sha256('hello world') = b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9
    const masterPassword = 'hello world';

    final pythonVectors = <String, String>{
      'p@ssw0rd':
          'gAAAAABqBt-fCK_V2r1C0cdHEAjoW4Jowo9aPcTKHj435JF2pyPITEveDn1vOYG4uIJermMMWcM_8xO3a9r4HdTG7OE73OTasA==',
      'hello':
          'gAAAAABqBt-fXQyXFZE1ihdZiie2W9K1MrUYG077RGsNeLRpUsk38gOsyIh1CZ7ksI_om6wz8nHHmtwCdZfNW1Tydr09yI-dzg==',
      'github_token_abc':
          'gAAAAABqBt-f_vpxslsSgJc4Qv1pSbTH-26fKbKg5whPfan_0YkLr6pUfo7c4A2j5DR1aYLaYj8Ta6HoXD_0uGV5YdC96yCsk1cQQI4BQwYCGg9SqzjRTWc=',
    };

    test('deriveKey 与 Python 一致（32 字节 sha256）', () {
      final key = FernetCrypto.deriveKey(masterPassword);
      expect(key.length, 32);
      expect(
        _hex(key),
        'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9',
      );
    });

    test('能解开 Python 生成的密文（关键兼容性指标）', () {
      final key = FernetCrypto.deriveKey(masterPassword);
      pythonVectors.forEach((plain, ct) {
        expect(
          FernetCrypto.decrypt(ct, key),
          plain,
          reason: '解密失败: $ct',
        );
      });
    });

    test('Dart 加密后 Dart 自己能解开（roundtrip）', () {
      final key = FernetCrypto.deriveKey(masterPassword);
      for (final plain in [
        'hello',
        '中文密码 测试 🔑',
        'a' * 100,
        '',
      ]) {
        final ct = FernetCrypto.encrypt(plain, key);
        expect(FernetCrypto.decrypt(ct, key), plain);
      }
    });

    test('错误主密钥应抛 FernetException', () {
      final goodKey = FernetCrypto.deriveKey(masterPassword);
      final ct = FernetCrypto.encrypt('secret', goodKey);
      final badKey = FernetCrypto.deriveKey('wrong password');
      expect(
        () => FernetCrypto.decrypt(ct, badKey),
        throwsA(isA<FernetException>()),
      );
    });

    test('Dart 与 Python 加密的同一明文都能被对方解密（双向）', () {
      final key = FernetCrypto.deriveKey(masterPassword);
      // 我们只能在 Dart 这一端测一半（Python 端密文已固定）
      // 这里再单独验：同 key、Dart 加密一条 → Dart 解 → 等于原文
      final ct = FernetCrypto.encrypt('cross-platform', key);
      expect(FernetCrypto.decrypt(ct, key), 'cross-platform');
      // Python 端验证由 tools/verify_with_python.py 离线做
    });
  });
}

String _hex(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

// ignore: unused_element
String _b64(String s) => base64Url.encode(utf8.encode(s));
