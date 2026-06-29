import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:passpro/crypto/vault_cipher.dart';

void main() {
  group('VaultCipher - PBKDF2 + AES-256-GCM', () {
    test('同一实例 roundtrip', () {
      final c = VaultCipher('correct horse battery staple');
      for (final pt in ['', 'hello', 'p@ss,=word', '中文密码🔐', 'a' * 1000]) {
        expect(c.decrypt(c.encrypt(pt)), pt);
      }
    });

    test('相同主密码、不同实例也能互相解密（盐自描述）', () {
      final a = VaultCipher('same-master');
      final b = VaultCipher('same-master');
      final token = a.encrypt('secret-value');
      expect(b.decrypt(token), 'secret-value');
    });

    test('主密钥错误抛 CryptoException', () {
      final right = VaultCipher('right-key');
      final wrong = VaultCipher('wrong-key');
      final token = right.encrypt('top secret');
      expect(() => wrong.decrypt(token), throwsA(isA<CryptoException>()));
    });

    test('被篡改的 token 抛 CryptoException（GCM 完整性）', () {
      final c = VaultCipher('k');
      final token = c.encrypt('data');
      // 翻转最后一个 base64 字符，破坏密文/标签
      final tampered =
          token.substring(0, token.length - 2) + (token.endsWith('A') ? 'B' : 'A');
      expect(() => c.decrypt(tampered), throwsA(isA<CryptoException>()));
    });

    test('token 头是新版本字节 0x01', () {
      final c = VaultCipher('k');
      final bytes = base64Url.decode(c.encrypt('x'));
      expect(bytes[0], 0x01);
    });

    test('非法 token 抛 CryptoException 而非崩溃', () {
      final c = VaultCipher('k');
      expect(() => c.decrypt('not-base64-!!!'), throwsA(isA<CryptoException>()));
      expect(() => c.decrypt('AAAA'), throwsA(isA<CryptoException>()));
    });
  });
}
