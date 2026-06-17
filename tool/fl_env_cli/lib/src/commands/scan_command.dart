import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:fl_env_cli/src/parsers/file_scanner.dart';

/// `fl_env scan` — discovers `.env` files and reports what fl_env sees.
class ScanCommand extends Command<void> {
  @override
  String get name => 'scan';

  @override
  String get description =>
      'Scan the project for .env files and show what fl_env discovers.';

  @override
  Future<void> run() async {
    final projectRoot = globalResults?['project'] as String? ?? '.';
    final result = FileScanner().scan(projectRoot);

    if (result.found.isEmpty && result.ignored.isEmpty) {
      stdout.writeln('No .env files found in $projectRoot');
      return;
    }

    if (result.found.isNotEmpty) {
      stdout.writeln('Found ${result.found.length} tier(s):');
      for (final entry in result.found.entries) {
        stdout.writeln('  [${entry.key}] → ${entry.value}');
      }
    }

    if (result.ignored.isNotEmpty) {
      stdout.writeln('\nIgnored (example/sample/template):');
      for (final name in result.ignored) {
        stdout.writeln('  $name');
      }
    }

    if (result.warnings.isNotEmpty) {
      stderr.writeln('\nWarnings — suspicious file names detected:');
      for (final name in result.warnings) {
        stderr.writeln('  ⚠ $name');
      }
    }
  }
}
