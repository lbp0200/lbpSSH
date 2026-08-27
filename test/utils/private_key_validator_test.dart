import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/utils/private_key_validator.dart';

void main() {
  group('isValidPrivateKey', () {
    test('Given PEM private key, When validating, Then returns true', () {
      const key =
          '-----BEGIN PRIVATE KEY-----\nMIIB\n-----END PRIVATE KEY-----';
      expect(isValidPrivateKey(key), isTrue);
    });

    test('Given OpenSSH private key, When validating, Then returns true', () {
      const key =
          '-----BEGIN OPENSSH PRIVATE KEY-----\nAAA\n-----END OPENSSH PRIVATE KEY-----';
      expect(isValidPrivateKey(key), isTrue);
    });

    test('Given RSA private key, When validating, Then returns true', () {
      const key =
          '-----BEGIN RSA PRIVATE KEY-----\nAAA\n-----END RSA PRIVATE KEY-----';
      expect(isValidPrivateKey(key), isTrue);
    });

    test('Given DSA private key, When validating, Then returns true', () {
      const key =
          '-----BEGIN DSA PRIVATE KEY-----\nAAA\n-----END DSA PRIVATE KEY-----';
      expect(isValidPrivateKey(key), isTrue);
    });

    test('Given EC private key, When validating, Then returns true', () {
      const key =
          '-----BEGIN EC PRIVATE KEY-----\nAAA\n-----END EC PRIVATE KEY-----';
      expect(isValidPrivateKey(key), isTrue);
    });

    test('Given random text, When validating, Then returns false', () {
      expect(isValidPrivateKey('not a key'), isFalse);
    });

    test('Given empty string, When validating, Then returns false', () {
      expect(isValidPrivateKey(''), isFalse);
    });

    test(
      'Given whitespace-padded key, When validating, Then trims and returns true',
      () {
        const key =
            '  \n-----BEGIN PRIVATE KEY-----\nMIIB\n-----END PRIVATE KEY-----\n  ';
        expect(isValidPrivateKey(key), isTrue);
      },
    );
  });
}
