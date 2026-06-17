import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// A single encrypted value produced by [AesGcmEncryptor.encrypt].
class EncryptedEntry {
  /// Creates an [EncryptedEntry].
  const EncryptedEntry({required this.nonce, required this.cipherWithTag});

  /// 12-byte random GCM nonce (IV).
  final Uint8List nonce;

  /// AES-256-GCM ciphertext with the 16-byte authentication tag appended.
  ///
  /// Length = `plaintext.length + 16`.
  final Uint8List cipherWithTag;
}

/// AES-256-GCM encryption with HKDF-SHA256 key derivation.
///
/// Used by the `fl_env build` command to encrypt `.env` values before
/// writing them into the binary registry.
class AesGcmEncryptor {
  static const int _keyBytes = 32; // AES-256
  static const int _nonceBytes = 12; // GCM standard nonce
  static const int _tagBits = 128; // GCM authentication tag length

  /// Derives a 256-bit AES key from [masterKeyHex] using HKDF-SHA256.
  ///
  /// [masterKeyHex] must be a 64-character lowercase hex string (32 bytes).
  /// The derivation uses a fixed info string `'fl_env v1'` and a zero salt
  /// (Phase 1 simplification — Phase 2 will introduce a per-project salt).
  static Uint8List deriveKey(String masterKeyHex) {
    final ikm = _hexDecode(masterKeyHex);
    // Phase 1: zero salt. Phase 2: per-project random salt stored in fl_env.yaml.
    final salt = Uint8List(32);
    final info = Uint8List.fromList(utf8.encode('fl_env v1'));

    final hkdf = HKDFKeyDerivator(SHA256Digest())
      ..init(HkdfParameters(ikm, _keyBytes, salt, info));
    final okm = Uint8List(_keyBytes);
    hkdf.deriveKey(null, 0, okm, 0);
    return okm;
  }

  /// Encrypts [plaintext] with [key] using AES-256-GCM.
  ///
  /// Returns an [EncryptedEntry] with a freshly generated 12-byte nonce and
  /// the ciphertext + 16-byte GCM authentication tag concatenated.
  static EncryptedEntry encrypt(Uint8List key, Uint8List plaintext) {
    final nonce = _randomNonce();

    final params = AEADParameters(
      KeyParameter(key),
      _tagBits,
      nonce,
      Uint8List(0), // no additional authenticated data in Phase 1
    );

    final cipher = GCMBlockCipher(AESEngine())..init(true, params);
    // PointyCastle GCM appends the 16-byte auth tag automatically.
    final cipherWithTag = cipher.process(plaintext);

    return EncryptedEntry(nonce: nonce, cipherWithTag: cipherWithTag);
  }

  /// Decrypts [entry] using [key]. Used in tests and round-trip validation.
  ///
  /// Returns the plaintext bytes, or throws if the authentication tag fails.
  static Uint8List decrypt(Uint8List key, EncryptedEntry entry) {
    final params = AEADParameters(
      KeyParameter(key),
      _tagBits,
      entry.nonce,
      Uint8List(0),
    );

    final cipher = GCMBlockCipher(AESEngine())..init(false, params);
    return cipher.process(entry.cipherWithTag);
  }

  static Uint8List _randomNonce() {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_nonceBytes, (_) => rng.nextInt(256)),
    );
  }

  static Uint8List _hexDecode(String hex) {
    if (hex.length % 2 != 0) {
      throw ArgumentError('Hex string must have even length: $hex');
    }
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}
