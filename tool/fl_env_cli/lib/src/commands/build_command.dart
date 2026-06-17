import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:fl_env_cli/src/crypto/aes_encryptor.dart';
import 'package:fl_env_cli/src/lockfile/lock_manager.dart';
import 'package:fl_env_cli/src/parsers/dotenv_parser.dart';
import 'package:fl_env_cli/src/parsers/file_scanner.dart';
import 'package:fl_env_cli/src/parsers/yaml_config.dart';
import 'package:path/path.dart' as p;

/// `fl_env build` — the core pipeline command.
///
/// Reads `.env` files, encrypts every value with AES-256-GCM (HKDF-derived
/// key), writes the binary registry and native key files, and updates the
/// lockfile. Must be run before building the native Android or iOS app.
///
/// Required environment variable: `FL_ENV_MASTER_KEY` (64-char hex, 32 bytes).
class BuildCommand extends Command<void> {
  /// Creates a [BuildCommand].
  BuildCommand() {
    argParser.addOption(
      'env',
      abbr: 'e',
      help: 'Environment tier to build (overrides fl_env.yaml default_env).',
    );
  }

  @override
  String get name => 'build';

  @override
  String get description =>
      'Encrypt .env files and write the native registry + key files.';

  @override
  Future<void> run() async {
    final projectRoot = globalResults?['project'] as String? ?? '.';

    // 1. Validate FL_ENV_MASTER_KEY
    final masterKey = Platform.environment['FL_ENV_MASTER_KEY'];
    if (masterKey == null || masterKey.isEmpty) {
      stderr.writeln(
        'fl_env build: FL_ENV_MASTER_KEY is not set.\n'
        'Set it with:\n'
        '  export FL_ENV_MASTER_KEY=<64-char-hex-key>\n'
        'Generate a new key with:\n'
        '  dart run fl_env_cli keygen',
      );
      exitCode = 4;
      return;
    }

    // 2. Load fl_env.yaml
    final YamlConfig config;
    try {
      config = YamlConfig.load(projectRoot);
    } on ConfigNotFoundException catch (e) {
      stderr.writeln('fl_env build: ${e.message}');
      exitCode = 1;
      return;
    }

    // 3. Determine target tier
    final targetTier =
        argResults?['env'] as String? ?? config.defaultEnv;

    if (!config.tiers.containsKey(targetTier)) {
      stderr.writeln(
        "fl_env build: unknown tier '$targetTier'.\n"
        'Available tiers: ${config.tiers.keys.join(', ')}',
      );
      exitCode = 1;
      return;
    }

    // 4. Scan for env files and warn on unexpected state
    final scanResult = FileScanner().scan(projectRoot);
    if (scanResult.warnings.isNotEmpty) {
      for (final w in scanResult.warnings) {
        stderr.writeln('  warning: suspicious file found: $w');
      }
    }

    // 5. Parse the target tier's .env file
    final envFilePath = p.join(projectRoot, config.tiers[targetTier]!);
    final envFile = File(envFilePath);
    if (!envFile.existsSync()) {
      stderr.writeln(
        "fl_env build: env file not found: $envFilePath\n"
        "Create it or update 'tiers.$targetTier' in fl_env.yaml.",
      );
      exitCode = 1;
      return;
    }

    final parseResult = DotenvParser().parse(envFile.readAsStringSync());
    for (final w in parseResult.warnings) {
      stderr.writeln('  warning: $w');
    }

    // 6. Derive AES-256 key via HKDF-SHA256
    final Uint8List aesKey;
    try {
      aesKey = AesGcmEncryptor.deriveKey(masterKey);
    } catch (e) {
      stderr.writeln(
        'fl_env build: invalid FL_ENV_MASTER_KEY — $e\n'
        'Key must be a 64-character lowercase hex string (32 bytes).',
      );
      exitCode = 1;
      return;
    }

    // 7. Encrypt all values and build the binary registry
    final entries = parseResult.values;
    final registryBytes = _buildRegistry(entries, aesKey);

    // 8. Write Android artefacts
    final androidBase = p.join(projectRoot, config.androidOutputDir);
    _writeAndroidRegistry(androidBase, registryBytes);
    _writeAndroidKeyFile(androidBase, aesKey);

    // 9. Write iOS artefacts
    final iosBase = p.join(projectRoot, config.iosOutputDir);
    _writeIosRegistry(iosBase, registryBytes);
    _writeIosKeyFile(iosBase, aesKey);

    // 10. Update lockfile
    final activeTiers = {
      targetTier: envFilePath,
    };
    LockManager(projectRoot).write(activeTiers);

    stdout.writeln('fl_env build complete.');
    stdout.writeln('  Tier:    $targetTier');
    stdout.writeln('  Keys:    ${entries.length}');
    stdout.writeln('  Android: $androidBase');
    stdout.writeln('  iOS:     $iosBase');
  }

  // ---------------------------------------------------------------------------
  // Binary registry format
  //
  // Bytes  Field               Type        Notes
  // ---------------------------------------------------------------
  // 0–3    Magic               UInt32 BE   0x464C454E ("FLEN")
  // 4–7    Version             UInt32 BE   1
  // 8–11   Tier-1 entry count  UInt32 BE
  // 12–15  Tier-2 entry count  UInt32 BE   Phase 1: always 0
  //
  // Per Tier-1 entry (repeated tier1Count times):
  //   key-length  UInt32 BE
  //   key         UTF-8 bytes
  //   nonce       12 bytes
  //   cipher-len  UInt32 BE   length of ciphertext + 16-byte GCM tag
  //   cipher+tag  bytes
  // ---------------------------------------------------------------------------
  Uint8List _buildRegistry(Map<String, String> entries, Uint8List key) {
    final out = BytesBuilder();

    // Magic: "FLEN"
    out.add(const [0x46, 0x4C, 0x45, 0x4E]);
    // Version: 1
    out.add(_uint32BE(1));
    // Tier-1 count
    out.add(_uint32BE(entries.length));
    // Tier-2 count (Phase 1: always 0)
    out.add(_uint32BE(0));

    for (final kv in entries.entries) {
      final keyBytes = Uint8List.fromList(utf8.encode(kv.key));
      out.add(_uint32BE(keyBytes.length));
      out.add(keyBytes);

      final plaintext = Uint8List.fromList(utf8.encode(kv.value));
      final enc = AesGcmEncryptor.encrypt(key, plaintext);

      out.add(enc.nonce); // 12 bytes
      out.add(_uint32BE(enc.cipherWithTag.length));
      out.add(enc.cipherWithTag);
    }

    return out.toBytes();
  }

  static Uint8List _uint32BE(int value) {
    final bd = ByteData(4);
    bd.setUint32(0, value, Endian.big);
    return bd.buffer.asUint8List();
  }

  // ---------------------------------------------------------------------------
  // Android file writers
  // ---------------------------------------------------------------------------

  void _writeAndroidRegistry(String androidBase, Uint8List bytes) {
    final dir = Directory(p.join(androidBase, 'res', 'raw'))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'fl_env_registry.bin')).writeAsBytesSync(bytes);
  }

  void _writeAndroidKeyFile(String androidBase, Uint8List key) {
    final dir = Directory(
      p.join(androidBase, 'kotlin', 'com', 'pixmerc', 'fl_env', 'generated'),
    )..createSync(recursive: true);

    // Kotlin byteArrayOf() takes signed bytes (−128..127).
    final signed = key.map((b) => b > 127 ? b - 256 : b).toList();
    final byteList = signed.join(', ');

    final source = '''// AUTO-GENERATED by fl_env CLI — DO NOT COMMIT — gitignored
package com.pixmerc.fl_env.generated

internal object FlEnvKey {
    val bytes: ByteArray = byteArrayOf($byteList)
}
''';
    File(p.join(dir.path, 'FlEnvKey.kt')).writeAsStringSync(source);
  }

  // ---------------------------------------------------------------------------
  // iOS file writers
  // ---------------------------------------------------------------------------

  void _writeIosRegistry(String iosBase, Uint8List bytes) {
    final dir = Directory(p.join(iosBase, 'Resources'))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'FlEnvRegistry.bin')).writeAsBytesSync(bytes);
  }

  void _writeIosKeyFile(String iosBase, Uint8List key) {
    final dir = Directory(p.join(iosBase, 'Generated'))
      ..createSync(recursive: true);

    // Swift uses unsigned UInt8 (0..255) — no sign conversion needed.
    final byteList = key.join(', ');

    final source = '''// AUTO-GENERATED by fl_env CLI — DO NOT COMMIT — gitignored
// swiftlint:disable all
enum FlEnvKey {
    static let bytes: [UInt8] = [$byteList]
}
''';
    File(p.join(dir.path, 'FlEnvKey.swift')).writeAsStringSync(source);
  }
}
