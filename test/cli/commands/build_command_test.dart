import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_env/src/cli/crypto/aes_encryptor.dart';
import 'package:fl_env/src/cli/parsers/dotenv_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Registry binary format round-trip tests.
// The parser logic mirrors what the native Kotlin/Swift code will implement.
// ---------------------------------------------------------------------------

/// Minimal registry builder — mirrors BuildCommand._buildRegistry logic.
Uint8List buildRegistry(Map<String, String> entries, Uint8List key) {
  final out = BytesBuilder();
  out.add(const [0x46, 0x4C, 0x45, 0x4E]); // "FLEN"
  out.add(_uint32BE(1)); // version
  out.add(_uint32BE(entries.length)); // tier1 count
  out.add(_uint32BE(0)); // tier2 count

  for (final kv in entries.entries) {
    final keyBytes = Uint8List.fromList(utf8.encode(kv.key));
    out.add(_uint32BE(keyBytes.length));
    out.add(keyBytes);

    final plaintext = Uint8List.fromList(utf8.encode(kv.value));
    final enc = AesGcmEncryptor.encrypt(key, plaintext);

    out.add(enc.nonce);
    out.add(_uint32BE(enc.cipherWithTag.length));
    out.add(enc.cipherWithTag);
  }
  return out.toBytes();
}

/// Minimal registry reader — mirrors the native RegistryReader logic.
Map<String, String> readRegistry(Uint8List data, Uint8List key) {
  final bd = ByteData.sublistView(data);
  var offset = 0;

  // Validate magic
  final magic = [data[0], data[1], data[2], data[3]];
  expect(magic, equals([0x46, 0x4C, 0x45, 0x4E]), reason: 'magic mismatch');
  offset += 4;

  final version = bd.getUint32(offset, Endian.big);
  expect(version, 1, reason: 'version mismatch');
  offset += 4;

  final tier1Count = bd.getUint32(offset, Endian.big);
  offset += 4;
  offset += 4; // skip tier2 count

  final result = <String, String>{};
  for (var i = 0; i < tier1Count; i++) {
    final keyLen = bd.getUint32(offset, Endian.big);
    offset += 4;
    final entryKey = utf8.decode(data.sublist(offset, offset + keyLen));
    offset += keyLen;

    final nonce = data.sublist(offset, offset + 12);
    offset += 12;

    final cipherLen = bd.getUint32(offset, Endian.big);
    offset += 4;
    final cipherWithTag = data.sublist(offset, offset + cipherLen);
    offset += cipherLen;

    final plaintext = AesGcmEncryptor.decrypt(
      key,
      EncryptedEntry(nonce: nonce, cipherWithTag: cipherWithTag),
    );
    result[entryKey] = utf8.decode(plaintext);
  }
  return result;
}

Uint8List _uint32BE(int value) {
  final bd = ByteData(4);
  bd.setUint32(0, value, Endian.big);
  return bd.buffer.asUint8List();
}

void main() {
  const masterKey =
      'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';

  late Uint8List key;

  setUp(() => key = AesGcmEncryptor.deriveKey(masterKey));

  group('registry binary format', () {
    test('starts with FLEN magic', () {
      final bytes = buildRegistry({'K': 'V'}, key);
      expect(bytes[0], 0x46); // F
      expect(bytes[1], 0x4C); // L
      expect(bytes[2], 0x45); // E
      expect(bytes[3], 0x4E); // N
    });

    test('version field is 1', () {
      final bytes = buildRegistry({'K': 'V'}, key);
      final bd = ByteData.sublistView(bytes);
      expect(bd.getUint32(4, Endian.big), 1);
    });

    test('tier1 count matches entry count', () {
      final entries = {'A': '1', 'B': '2', 'C': '3'};
      final bytes = buildRegistry(entries, key);
      final bd = ByteData.sublistView(bytes);
      expect(bd.getUint32(8, Endian.big), 3);
    });

    test('tier2 count is always 0 in Phase 1', () {
      final bytes = buildRegistry({'K': 'V'}, key);
      final bd = ByteData.sublistView(bytes);
      expect(bd.getUint32(12, Endian.big), 0);
    });

    test('empty registry has 16-byte header only', () {
      final bytes = buildRegistry({}, key);
      expect(bytes.length, 16);
    });

    test('round-trip: single entry', () {
      final input = {'API_URL': 'https://api.example.com'};
      final bytes = buildRegistry(input, key);
      final output = readRegistry(bytes, key);
      expect(output, equals(input));
    });

    test('round-trip: multiple entries', () {
      final input = {
        'BASE_URL': 'https://api.example.com/v2',
        'TIMEOUT': '30',
        'DEBUG': 'false',
        'API_KEY': 'sk-test-abc123',
      };
      final bytes = buildRegistry(input, key);
      final output = readRegistry(bytes, key);
      expect(output, equals(input));
    });

    test('round-trip: empty value', () {
      final input = {'EMPTY_KEY': ''};
      final bytes = buildRegistry(input, key);
      final output = readRegistry(bytes, key);
      expect(output, equals(input));
    });

    test('round-trip: unicode value', () {
      final input = {'GREETING': 'こんにちは世界'};
      final bytes = buildRegistry(input, key);
      final output = readRegistry(bytes, key);
      expect(output, equals(input));
    });

    test('round-trip: value with special characters', () {
      final input = {'SECRET': r'p@$$w0rd!#&='};
      final bytes = buildRegistry(input, key);
      final output = readRegistry(bytes, key);
      expect(output, equals(input));
    });

    test('wrong key fails to decrypt', () {
      final wrongKey = AesGcmEncryptor.deriveKey(
        'cafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe',
      );
      final bytes = buildRegistry({'K': 'secret'}, key);
      expect(() => readRegistry(bytes, wrongKey), throwsA(anything));
    });
  });

  group('build command integration (file system)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fl_env_build_test_');
    });
    tearDown(() => tempDir.deleteSync(recursive: true));

    test('DotenvParser + AesGcmEncryptor + registry round-trip', () {
      const envContent = '''
BASE_URL=https://api.example.com
TIMEOUT=30
DEBUG=true
''';
      final parsed = DotenvParser().parse(envContent);
      expect(parsed.values.length, 3);

      final bytes = buildRegistry(parsed.values, key);
      final decoded = readRegistry(bytes, key);

      expect(decoded['BASE_URL'], 'https://api.example.com');
      expect(decoded['TIMEOUT'], '30');
      expect(decoded['DEBUG'], 'true');
    });

    test('FlEnvKey.kt byte conversion: unsigned to signed', () {
      final testKey = Uint8List.fromList([0, 127, 128, 255]);
      final signed = testKey.map((b) => b > 127 ? b - 256 : b).toList();
      expect(signed[0], 0);
      expect(signed[1], 127);
      expect(signed[2], -128); // 128 → -128
      expect(signed[3], -1); // 255 → -1
    });

    test('FlEnvKey.swift: all bytes are in 0..255 range', () {
      for (final b in key) {
        expect(b, greaterThanOrEqualTo(0));
        expect(b, lessThanOrEqualTo(255));
      }
    });

    test('writes android key file to correct path', () {
      final androidBase = p.join(tempDir.path, 'android', 'app', 'src', 'main');
      final keyDir = Directory(
        p.join(
          androidBase,
          'kotlin',
          'com',
          'pixmerc',
          'fl_env',
          'generated',
        ),
      )..createSync(recursive: true);

      final signed = key.map((b) => b > 127 ? b - 256 : b).toList();
      final byteList = signed.join(', ');
      final source = 'internal object FlEnvKey { val bytes: ByteArray = '
          'byteArrayOf($byteList) }';
      File(p.join(keyDir.path, 'FlEnvKey.kt')).writeAsStringSync(source);

      final written = File(p.join(keyDir.path, 'FlEnvKey.kt'));
      expect(written.existsSync(), isTrue);
      expect(written.readAsStringSync(), contains('byteArrayOf'));
      for (final b in signed) {
        expect(b, inInclusiveRange(-128, 127));
      }
    });
  });
}
