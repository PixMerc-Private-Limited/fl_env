import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fl_env/src/cli/lockfile/lock_manager.dart';
import 'package:fl_env/src/cli/parsers/dotenv_parser.dart';
import 'package:fl_env/src/cli/parsers/yaml_config.dart';
import 'package:path/path.dart' as p;

/// `fl_env check` — validates env files and detects registry drift.
///
/// Checks performed in order:
///   1. Lockfile drift: `.env` file hashes vs. last `fl_env build`.
///   2. Required keys: every key in `required_keys` present in every tier.
///   3. Key types: values coercible to declared types in `key_types`.
///
/// Exits with code 1 on any failure; suitable as a CI gate.
class CheckCommand extends Command<void> {
  @override
  String get name => 'check';

  @override
  String get description =>
      'Validate env files against fl_env.yaml and detect registry drift. '
      'Exits 1 if any check fails (suitable for CI).';

  @override
  Future<void> run() async {
    final projectRoot = globalResults?['project'] as String? ?? '.';

    final YamlConfig config;
    try {
      config = YamlConfig.load(projectRoot);
    } on ConfigNotFoundException catch (e) {
      stderr.writeln('fl_env check: ${e.message}');
      exitCode = 1;
      return;
    }

    stdout.writeln();
    var failed = false;

    // ── 1. Lockfile drift ────────────────────────────────────────────────────
    final lock = LockManager(projectRoot);
    final tierPaths = _resolveTierPaths(config, projectRoot);

    if (lock.isDirty(tierPaths)) {
      _fail(
        'Registry is out of date with .env files.',
        "Run 'dart run fl_env build' to regenerate.",
      );
      failed = true;
    } else {
      _pass('Registry is up-to-date with .env files.');
    }

    // ── 2. Required keys ─────────────────────────────────────────────────────
    if (config.requiredKeys.isNotEmpty) {
      final parser = DotenvParser();
      for (final entry in tierPaths.entries) {
        final tier = entry.key;
        final file = File(entry.value);
        if (!file.existsSync()) {
          _fail(
            'Tier "$tier": file ${entry.value} not found.',
            'Create the file or remove it from fl_env.yaml tiers.',
          );
          failed = true;
          continue;
        }
        final result = parser.parse(file.readAsStringSync());
        for (final key in config.requiredKeys) {
          if (!result.values.containsKey(key)) {
            _fail(
              'Tier "$tier": required key "$key" is missing from ${p.basename(entry.value)}.',
              'Add $key=<value> to ${entry.value}.',
            );
            failed = true;
          }
        }
      }
      if (!failed) {
        _pass(
          'All ${config.requiredKeys.length} required key(s) present in '
          '${tierPaths.length} tier(s).',
        );
      }
    }

    // ── 3. Key types ─────────────────────────────────────────────────────────
    if (config.keyTypes.isNotEmpty) {
      final parser = DotenvParser();
      for (final entry in tierPaths.entries) {
        final tier = entry.key;
        final file = File(entry.value);
        if (!file.existsSync()) continue;
        final result = parser.parse(file.readAsStringSync());
        for (final typeEntry in config.keyTypes.entries) {
          final key = typeEntry.key;
          final type = typeEntry.value;
          final value = result.values[key];
          if (value == null) continue; // missing keys caught in step 2
          if (!_isCoercible(value, type)) {
            _fail(
              'Tier "$tier": key "$key" has value "$value" which cannot be '
                  'coerced to type "$type".',
              'Fix the value in ${p.basename(entry.value)} or update key_types in fl_env.yaml.',
            );
            failed = true;
          }
        }
      }
      if (!failed) {
        _pass(
          'All ${config.keyTypes.length} typed key(s) are coercible in '
          '${tierPaths.length} tier(s).',
        );
      }
    }

    stdout.writeln();
    if (failed) {
      exitCode = 1;
    } else {
      stdout.writeln('  All checks passed.');
    }
  }

  void _pass(String msg) => stdout.writeln('  ✓ $msg');
  void _fail(String msg, String suggestion) {
    stderr.writeln('  ✗ $msg');
    stderr.writeln('    → $suggestion');
  }

  Map<String, String> _resolveTierPaths(YamlConfig config, String projectRoot) {
    return config.tiers.map(
      (tier, relPath) => MapEntry(tier, p.join(projectRoot, relPath)),
    );
  }

  bool _isCoercible(String value, String type) {
    return switch (type) {
      'int' => int.tryParse(value) != null,
      'double' => double.tryParse(value) != null,
      'bool' => const {
        'true',
        'false',
        '1',
        '0',
        'yes',
        'no',
      }.contains(value.toLowerCase()),
      'uri' => Uri.tryParse(value)?.hasScheme ?? false,
      'list' => true, // any non-empty string is a valid comma-separated list
      _ => true, // 'string' and unknowns always pass
    };
  }
}
