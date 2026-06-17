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

/// Parsed representation of `fl_env.yaml`.
class YamlConfig {
  YamlConfig._({
    required this.defaultEnv,
    required this.tiers,
    required this.androidOutputDir,
    required this.iosOutputDir,
  });

  /// The environment tier used when `--env` is not specified.
  final String defaultEnv;

  /// Map of tier-name → relative `.env` file path.
  ///
  /// Example: `{'development': '.env', 'staging': '.env.staging'}`.
  final Map<String, String> tiers;

  /// Relative path to the Android `src/main` directory.
  final String androidOutputDir;

  /// Relative path to the iOS `Runner` directory.
  final String iosOutputDir;

  /// Loads and parses `fl_env.yaml` from [projectRoot].
  ///
  /// Throws [ConfigNotFoundException] if the file does not exist.
  factory YamlConfig.load(String projectRoot) {
    final file = File(p.join(projectRoot, 'fl_env.yaml'));
    if (!file.existsSync()) {
      throw ConfigNotFoundException(
        'fl_env.yaml not found at ${file.path}.\n'
        "Run 'fl_env setup' to create it.",
      );
    }

    final doc = loadYaml(file.readAsStringSync());
    final root = (doc as YamlMap)['fl_env'] as YamlMap;
    final output = root['output'] as YamlMap;
    final tiersNode = root['tiers'] as YamlMap;

    return YamlConfig._(
      defaultEnv: (root['default_env'] as String?) ?? 'development',
      tiers: Map<String, String>.fromEntries(
        tiersNode.entries.map(
          (e) => MapEntry(e.key as String, e.value as String),
        ),
      ),
      androidOutputDir:
          (output['android'] as String?) ?? 'android/app/src/main',
      iosOutputDir: (output['ios'] as String?) ?? 'ios/Runner',
    );
  }

  @override
  String toString() => 'YamlConfig(defaultEnv: $defaultEnv, tiers: $tiers)';
}
