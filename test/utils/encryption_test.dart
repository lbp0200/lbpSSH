import 'package:flutter_test/flutter_test.dart';
import 'package:lbpSSH/utils/encryption.dart';
import 'dart:convert';

void main() {
  group('EncryptionUtil', () {
    group('deriveKey', () {
      test('should derive key from short password', () {
        final key = EncryptionUtil.deriveKey('short');

        expect(key.length, 32);
        expect(key.bytes.length, 32);
      });

      test('should derive key from long password', () {
        final key = EncryptionUtil.deriveKey('a' * 50);

        expect(key.length, 32);
        expect(key.bytes.length, 32);
      });

      test('should derive key from empty password', () {
        final key = EncryptionUtil.deriveKey('');

        expect(key.length, 32);
        expect(key.bytes.length, 32);
      });

      test('should derive key from password with special characters', () {
        final key = EncryptionUtil.deriveKey('p@ss!word#123');

        expect(key.length, 32);
      });

      test('should produce same key for same password', () {
        final key1 = EncryptionUtil.deriveKey('testpassword');
        final key2 = EncryptionUtil.deriveKey('testpassword');

        expect(base64Encode(key1.bytes), base64Encode(key2.bytes));
      });

      test('should produce different keys for different passwords', () {
        final key1 = EncryptionUtil.deriveKey('password1');
        final key2 = EncryptionUtil.deriveKey('password2');

        expect(base64Encode(key1.bytes), isNot(base64Encode(key2.bytes)));
      });
    });

    group('encrypt/decrypt', () {
      test('should encrypt and decrypt simple text', () {
        const original = 'Hello, World!';
        const password = 'testpassword123';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decrypted = EncryptionUtil.decrypt(encrypted, password);

        expect(decrypted, original);
      });

      test('should throw exception for empty string', () {
        const original = '';
        const password = 'testpassword123';

        expect(
          () => EncryptionUtil.encrypt(original, password),
          throwsException,
        );
      });

      test('should encrypt and decrypt Chinese text', () {
        const original = '你好，世界！';
        const password = 'testpassword123';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decrypted = EncryptionUtil.decrypt(encrypted, password);

        expect(decrypted, original);
      });

      test('should encrypt and decrypt special characters', () {
        const original = '!@#\$%^&*()_+-=[]{}|;\':",./<>?';
        const password = 'testpassword123';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decrypted = EncryptionUtil.decrypt(encrypted, password);

        expect(decrypted, original);
      });

      test('should encrypt and decrypt multiline text', () {
        const original = '''Line 1
Line 2
Line 3''';
        const password = 'testpassword123';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decrypted = EncryptionUtil.decrypt(encrypted, password);

        expect(decrypted, original);
      });

      test('should produce different ciphertext for same plaintext', () {
        const original = 'Same text';
        const password = 'testpassword123';

        final encrypted1 = EncryptionUtil.encrypt(original, password);
        final encrypted2 = EncryptionUtil.encrypt(original, password);

        expect(encrypted1, isNot(encrypted2));
      });

      test('should fail decryption with wrong password', () {
        const original = 'Secret message';
        const correctPassword = 'correctpassword';
        const wrongPassword = 'wrongpassword';

        final encrypted = EncryptionUtil.encrypt(original, correctPassword);

        expect(
          () => EncryptionUtil.decrypt(encrypted, wrongPassword),
          throwsException,
        );
      });

      test('should encrypt and decrypt JSON-like string', () {
        const original = '{"name": "test", "value": 123}';
        const password = 'jsonpassword';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decrypted = EncryptionUtil.decrypt(encrypted, password);

        expect(decrypted, original);
      });

      test('should handle long text', () {
        final original = 'A' * 10000;
        const password = 'longtextpassword';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decrypted = EncryptionUtil.decrypt(encrypted, password);

        expect(decrypted, original);
      });

      test('should handle unicode characters', () {
        const original = 'Hello 你好 مرحبا Привет 🌍';
        const password = 'unicodepassword';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decrypted = EncryptionUtil.decrypt(encrypted, password);

        expect(decrypted, original);
      });
    });

    group('generateRandomKey', () {
      test('should generate key of correct length', () {
        final key = EncryptionUtil.generateRandomKey();

        expect(key.length, 44);
      });

      test('should generate different keys each time', () {
        final key1 = EncryptionUtil.generateRandomKey();
        final key2 = EncryptionUtil.generateRandomKey();

        expect(key1, isNot(key2));
      });

      test('should generate valid base64 key', () {
        final key = EncryptionUtil.generateRandomKey();

        expect(() => base64Decode(key), returnsNormally);
      });
    });

    group('encryption format', () {
      test('should produce base64 encoded ciphertext', () {
        const original = 'Test message';
        const password = 'testpassword';

        final encrypted = EncryptionUtil.encrypt(original, password);

        expect(() => base64Decode(encrypted), returnsNormally);
      });

      test('should include IV in ciphertext', () {
        const original = 'Test message';
        const password = 'testpassword';

        final encrypted = EncryptionUtil.encrypt(original, password);
        final decoded = base64Decode(encrypted);

        expect(decoded.length, greaterThan(16));
      });
    });
  });
}
