import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Thrown when `fl_env.yaml` cannot be found.
class ConfigNotFoundException implements Exception {
  /// Creates a [ConfigNotFoundException].
  const ConfigNotFoundException(this.message);

  /// Human-readable description.
  final String message;

  @override
  String toString() => 'ConfigNotFoundException: $message';
}

/// Valid type labels for [YamlConfig.keyTypes].
const _validTypes = {'string', 'int', 'double', 'bool', 'uri', 'list'};

/// Built-in patterns that mark a key as sensitive (Tier 2 candidate).
/// Used by `fl_env check` to warn if sensitive keys appear in Tier 1 files
/// and by `fl_env inspect` to redact values in output.
const defaultSensitiveKeyPatterns = [
  'SECRET',
  'KEY',
  'TOKEN',
  'PASSWORD',
  'PRIVATE',
  'CREDENTIAL',
  'AUTH',
];

/// Parsed representation of `fl_env.yaml`.
class YamlConfig {
  YamlConfig._({
    required this.defaultEnv,
    required this.tiers,
    required this.androidOutputDir,
    required this.iosOutputDir,
    required this.requiredKeys,
    required this.keyTypes,
    required this.sensitiveKeyPatterns,
  });

  /// The environment tier used when `--env` is not specified.
  final String defaultEnv;

  /// Map of tier-name → relative `.env` file path.
  ///
  /// Example: `{'development': '.env', 'staging': '.env.staging'}`.
  final Map<String, String> tiers;

  /// Relative path to the Android `src/main` directory.
  ///
  /// Defaults to `android/app/src/main` — the consumer app's own module,
  /// where `fl_env build` writes `fl_env_key.bin` and `fl_env_registry.bin`
  /// into `res/raw/`.
  final String androidOutputDir;

  /// Relative path to the iOS app bundle source directory.
  ///
  /// Defaults to `ios/Runner`. Files written here are added to Xcode's Copy
  /// Bundle Resources phase by the Podfile hook that `fl_env setup` installs.
  final String iosOutputDir;

  /// Keys that must be present in every tier's `.env` file.
  ///
  /// `fl_env check` exits non-zero if any required key is missing from any
  /// discovered tier. Empty list means no enforcement.
  final List<String> requiredKeys;

  /// Map of key-name → expected type (`string`, `int`, `double`, `bool`,
  /// `uri`, `list`). `fl_env check` validates that values are coercible.
  final Map<String, String> keyTypes;

  /// Key-name fragments that mark a value as sensitive.
  ///
  /// Keys matching any pattern (case-insensitive substring) are redacted in
  /// `fl_env inspect` output. Defaults to [defaultSensitiveKeyPatterns] merged
  /// with any additional patterns declared in `fl_env.yaml`.
  final List<String> sensitiveKeyPatterns;

  /// Returns `true` if [key] matches any pattern in [sensitiveKeyPatterns].
  bool isSensitive(String key) {
    final upper = key.toUpperCase();
    return sensitiveKeyPatterns.any((p) => upper.contains(p.toUpperCase()));
  }

  /// Loads and parses `fl_env.yaml` from [projectRoot].
  ///
  /// Throws [ConfigNotFoundException] if the file does not exist.
  factory YamlConfig.load(String projectRoot) {
    final file = File(p.join(projectRoot, 'fl_env.yaml'));
    if (!file.existsSync()) {
      throw ConfigNotFoundException(
        'fl_env.yaml not found at ${file.path}.\n'
        "Run 'dart run fl_env setup' to create it.",
      );
    }

    final doc = loadYaml(file.readAsStringSync());
    final root = (doc as YamlMap)['fl_env'] as YamlMap;
    final output = root['output'] as YamlMap?;
    final tiersNode = root['tiers'] as YamlMap;

    // required_keys
    final requiredKeysNode = root['required_keys'];
    final requiredKeys = requiredKeysNode == null
        ? <String>[]
        : (requiredKeysNode as YamlList).cast<String>();

    // key_types
    final keyTypesNode = root['key_types'] as YamlMap?;
    final keyTypes = <String, String>{};
    if (keyTypesNode != null) {
      for (final entry in keyTypesNode.entries) {
        final type = entry.value as String;
        if (!_validTypes.contains(type)) {
          throw ConfigNotFoundException(
            "fl_env.yaml: key_types['${entry.key}'] has unknown type '$type'.\n"
            "Valid types: ${_validTypes.join(', ')}.",
          );
        }
        keyTypes[entry.key as String] = type;
      }
    }

    // sensitive_key_patterns
    final extraPatternsNode = root['sensitive_key_patterns'];
    final extraPatterns = extraPatternsNode == null
        ? <String>[]
        : (extraPatternsNode as YamlList).cast<String>();
    final sensitiveKeyPatterns = [
      ...defaultSensitiveKeyPatterns,
      ...extraPatterns,
    ];

    return YamlConfig._(
      defaultEnv: (root['default_env'] as String?) ?? 'development',
      tiers: Map<String, String>.fromEntries(
        tiersNode.entries.map(
          (e) => MapEntry(e.key as String, e.value as String),
        ),
      ),
      androidOutputDir:
          (output?['android'] as String?) ?? 'android/app/src/main',
      iosOutputDir: (output?['ios'] as String?) ?? 'ios/Runner',
      requiredKeys: requiredKeys,
      keyTypes: keyTypes,
      sensitiveKeyPatterns: sensitiveKeyPatterns,
    );
  }

  @override
  String toString() => 'YamlConfig(defaultEnv: $defaultEnv, tiers: $tiers)';
}
