import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fl_env/src/cli/lockfile/lock_manager.dart';
import 'package:fl_env/src/cli/parsers/yaml_config.dart';

/// `fl_env check` — verifies the registry is up-to-date with the `.env` files.
///
/// Exits with code 1 if any `.env` file has changed since the last
/// `fl_env build`, making it suitable as a CI gate.
class CheckCommand extends Command<void> {
  @override
  String get name => 'check';

  @override
  String get description =>
      'Check whether .env files have changed since the last build. '
      'Exits 1 if drift is detected (suitable for CI).';

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

    final lock = LockManager(projectRoot);

    if (lock.isDirty(config.tiers)) {
      stderr.writeln(
        'fl_env: registry is out of date. '
        "Run 'fl_env build' to update.",
      );
      exitCode = 1;
    } else {
      stdout.writeln('fl_env: registry is up-to-date.');
    }
  }
}
