import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_env_cli/src/crypto/aes_encryptor.dart';
import 'package:test/test.dart';

void main() {
  // A known 64-char hex master key for deterministic testing.
  const testMasterKey =
      'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';

  group('deriveKey', () {
    test('returns exactly 32 bytes', () {
      final key = AesGcmEncryptor.deriveKey(testMasterKey);
      expect(key.length, 32);
    });

    test('is deterministic for the same input', () {
      final key1 = AesGcmEncryptor.deriveKey(testMasterKey);
      final key2 = AesGcmEncryptor.deriveKey(testMasterKey);
      expect(key1, equals(key2));
    });

    test('produces different keys for different master keys', () {
      final key1 = AesGcmEncryptor.deriveKey(testMasterKey);
      final key2 = AesGcmEncryptor.deriveKey(
        'cafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe',
      );
      expect(key1, isNot(equals(key2)));
    });

    test('throws on odd-length hex string', () {
      expect(() => AesGcmEncryptor.deriveKey('abc'), throwsArgumentError);
    });
  });

  group('encrypt', () {
    late Uint8List key;

    setUp(() => key = AesGcmEncryptor.deriveKey(testMasterKey));

    test('nonce is exactly 12 bytes', () {
      final plain = Uint8List.fromList(utf8.encode('hello'));
      final entry = AesGcmEncryptor.encrypt(key, plain);
      expect(entry.nonce.length, 12);
    });

    test('cipherWithTag length = plaintext length + 16', () {
      final plain = Uint8List.fromList(utf8.encode('hello world'));
      final entry = AesGcmEncryptor.encrypt(key, plain);
      expect(entry.cipherWithTag.length, plain.length + 16);
    });

    test('ciphertext differs from plaintext', () {
      final plain = Uint8List.fromList(utf8.encode('secret'));
      final entry = AesGcmEncryptor.encrypt(key, plain);
      expect(entry.cipherWithTag, isNot(equals(plain)));
    });

    test(
        'two encryptions of same plaintext produce different ciphertexts (random nonce)',
        () {
      final plain = Uint8List.fromList(utf8.encode('same value'));
      final e1 = AesGcmEncryptor.encrypt(key, plain);
      final e2 = AesGcmEncryptor.encrypt(key, plain);
      // Nonces must differ
      expect(e1.nonce, isNot(equals(e2.nonce)));
    });

    test('encrypts empty plaintext', () {
      final plain = Uint8List(0);
      final entry = AesGcmEncryptor.encrypt(key, plain);
      expect(entry.cipherWithTag.length, 16); // only the auth tag
    });
  });

  group('decrypt (round-trip)', () {
    late Uint8List key;

    setUp(() => key = AesGcmEncryptor.deriveKey(testMasterKey));

    test('decrypts back to original plaintext', () {
      final original = utf8.encode('Hello, fl_env!');
      final plain = Uint8List.fromList(original);
      final entry = AesGcmEncryptor.encrypt(key, plain);
      final decrypted = AesGcmEncryptor.decrypt(key, entry);
      expect(utf8.decode(decrypted), 'Hello, fl_env!');
    });

    test('round-trips empty value', () {
      final entry = AesGcmEncryptor.encrypt(key, Uint8List(0));
      final decrypted = AesGcmEncryptor.decrypt(key, entry);
      expect(decrypted, isEmpty);
    });

    test('round-trips URL value', () {
      const url = 'https://api.example.com/v2';
      final entry = AesGcmEncryptor.encrypt(
        key,
        Uint8List.fromList(utf8.encode(url)),
      );
      expect(utf8.decode(AesGcmEncryptor.decrypt(key, entry)), url);
    });

    test('round-trips unicode value', () {
      const text = 'こんにちは世界';
      final entry = AesGcmEncryptor.encrypt(
        key,
        Uint8List.fromList(utf8.encode(text)),
      );
      expect(utf8.decode(AesGcmEncryptor.decrypt(key, entry)), text);
    });

    test('decryption fails with wrong key', () {
      final wrongKey = AesGcmEncryptor.deriveKey(
        'cafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe',
      );
      final entry = AesGcmEncryptor.encrypt(
        key,
        Uint8List.fromList(utf8.encode('secret')),
      );
      expect(
        () => AesGcmEncryptor.decrypt(wrongKey, entry),
        throwsA(anything),
      );
    });

    test('decryption fails with tampered ciphertext', () {
      final entry = AesGcmEncryptor.encrypt(
        key,
        Uint8List.fromList(utf8.encode('sensitive')),
      );
      // Flip a byte in the ciphertext
      final tampered = Uint8List.fromList(entry.cipherWithTag);
      tampered[0] ^= 0xFF;
      final tamperedEntry = EncryptedEntry(
        nonce: entry.nonce,
        cipherWithTag: tampered,
      );
      expect(
        () => AesGcmEncryptor.decrypt(key, tamperedEntry),
        throwsA(anything),
      );
    });
  });
}
