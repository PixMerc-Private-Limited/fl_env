import 'dart:io';
import 'dart:math';

import 'package:args/command_runner.dart';
import 'package:fl_env_cli/src/commands/build_command.dart';
import 'package:fl_env_cli/src/commands/check_command.dart';
import 'package:fl_env_cli/src/commands/scan_command.dart';
import 'package:fl_env_cli/src/commands/setup_command.dart';

/// Top-level CLI runner for the `fl_env` tool.
class FlEnvCommandRunner extends CommandRunner<void> {
  /// Creates the command runner with all registered sub-commands.
  FlEnvCommandRunner()
      : super(
          'fl_env',
          'Secure .env encryption for Flutter — '
              'CLI-encrypted files, native decryption at runtime.',
        ) {
    argParser
      ..addFlag(
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Print the fl_env CLI version.',
      )
      ..addOption(
        'project',
        abbr: 'p',
        defaultsTo: '.',
        help: 'Path to the Flutter project root.',
      );

    addCommand(ScanCommand());
    addCommand(CheckCommand());
    addCommand(SetupCommand());
    addCommand(BuildCommand());
    addCommand(_KeygenCommand());
  }

  @override
  Future<void> run(Iterable<String> args) async {
    final results = argParser.parse(args);
    if (results['version'] == true) {
      stdout.writeln('fl_env_cli 0.1.0');
      return;
    }
    await super.run(args);
  }
}

/// `fl_env keygen` — generates a cryptographically random master key.
class _KeygenCommand extends Command<void> {
  @override
  String get name => 'keygen';

  @override
  String get description =>
      'Generate a cryptographically random FL_ENV_MASTER_KEY.';

  @override
  Future<void> run() async {
    final rng = Random.secure();
    final bytes =
        List<int>.generate(32, (_) => rng.nextInt(256));
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    stdout.writeln(hex);
    stderr.writeln(
      'Copy this key and store it securely (e.g. in your CI secrets):\n'
      '  export FL_ENV_MASTER_KEY=$hex',
    );
  }
}
