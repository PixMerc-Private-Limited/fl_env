import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fl_env/src/cli/parsers/dotenv_parser.dart';
import 'package:fl_env/src/cli/parsers/yaml_config.dart';
import 'package:path/path.dart' as p;

/// `fl_env inspect [--env=<name>]` — display Tier 1 values for a given
/// environment tier.
///
/// Reads the plaintext `.env` file (CLI-side) and prints each key-value pair,
/// redacting the tails of values whose keys match a sensitive pattern.
/// This lets developers confirm that the correct values will be encrypted
/// without exposing full secrets in terminal output or logs.
///
/// Note: shows what *will be* encrypted — run `fl_env build` first to ensure
/// the registry reflects what is shown here.
class InspectCommand extends Command<void> {
  /// Creates an [InspectCommand].
  InspectCommand() {
    argParser.addOption(
      'env',
      abbr: 'e',
      help:
          'Environment tier to inspect (defaults to fl_env.yaml default_env).',
    );
  }

  @override
  String get name => 'inspect';

  @override
  String get description =>
      'Display Tier 1 key-value pairs for an environment tier. '
      'Sensitive values are redacted.';

  @override
  Future<void> run() async {
    final projectRoot = globalResults?['project'] as String? ?? '.';

    final YamlConfig config;
    try {
      config = YamlConfig.load(projectRoot);
    } on ConfigNotFoundException catch (e) {
      stderr.writeln('fl_env inspect: ${e.message}');
      exitCode = 1;
      return;
    }

    final targetTier = argResults?['env'] as String? ?? config.defaultEnv;
    if (!config.tiers.containsKey(targetTier)) {
      stderr.writeln(
        "fl_env inspect: unknown tier '$targetTier'.\n"
        'Available tiers: ${config.tiers.keys.join(', ')}',
      );
      exitCode = 1;
      return;
    }

    final envRelPath = config.tiers[targetTier]!;
    final envFile = File(p.join(projectRoot, envRelPath));
    if (!envFile.existsSync()) {
      stderr.writeln(
        "fl_env inspect: env file not found: ${envFile.path}\n"
        "Run 'dart run fl_env build' first, or check tiers.$targetTier in fl_env.yaml.",
      );
      exitCode = 1;
      return;
    }

    final result = DotenvParser().parse(envFile.readAsStringSync());

    stdout.writeln();
    stdout.writeln('  Tier:  $targetTier ($envRelPath)');
    stdout.writeln('  Keys:  ${result.values.length}');
    stdout.writeln();

    if (result.values.isEmpty) {
      stdout.writeln('  (no key-value pairs found)');
      stdout.writeln();
      return;
    }

    // Align values column: longest key + 2 spaces padding.
    final maxKeyLen = result.values.keys.fold(
      0,
      (m, k) => m > k.length ? m : k.length,
    );
    final colWidth = maxKeyLen + 2;

    for (final entry in result.values.entries) {
      final key = entry.key;
      final raw = entry.value;
      final sensitive = config.isSensitive(key);
      final display = sensitive ? _redact(raw) : raw;
      final tag = sensitive ? '  (redacted)' : '';
      final paddedKey = key.padRight(colWidth);
      stdout.writeln('  $paddedKey→  $display$tag');
    }

    stdout.writeln();

    if (result.warnings.isNotEmpty) {
      for (final w in result.warnings) {
        stderr.writeln('  warning: $w');
      }
    }
  }

  /// Redacts the value by showing only the first few characters and
  /// replacing the rest with bullet characters.
  String _redact(String value) {
    const showChars = 4;
    const bullets = '••••••••';
    if (value.length <= showChars) return bullets;
    return '${value.substring(0, showChars)}$bullets';
  }
}
