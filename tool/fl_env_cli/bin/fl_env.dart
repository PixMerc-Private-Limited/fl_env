import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fl_env_cli/fl_env_cli.dart';

Future<void> main(List<String> arguments) async {
  final runner = FlEnvCommandRunner();
  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    exit(64); // EX_USAGE
  } catch (e, st) {
    stderr.writeln('fl_env error: $e');
    if (arguments.contains('--verbose')) stderr.writeln(st);
    exit(1);
  }
}
