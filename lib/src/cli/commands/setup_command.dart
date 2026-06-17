import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// `fl_env setup` — scaffolds `fl_env.yaml` in a Flutter project.
///
/// Creates a default `fl_env.yaml` if absent and appends fl_env-specific
/// entries to the project's `.gitignore`.
class SetupCommand extends Command<void> {
  @override
  String get name => 'setup';

  @override
  String get description =>
      'Create fl_env.yaml scaffold and update .gitignore in a Flutter project.';

  @override
  Future<void> run() async {
    final projectRoot = globalResults?['project'] as String? ?? '.';

    _writeYamlScaffold(projectRoot);
    _updateGitignore(projectRoot);

    stdout.writeln('fl_env setup complete.');
    stdout.writeln("Edit fl_env.yaml to match your project's .env file paths,");
    stdout.writeln(
      "then run 'fl_env build' to generate the encrypted registry.",
    );
  }

  void _writeYamlScaffold(String root) {
    final file = File(p.join(root, 'fl_env.yaml'));
    if (file.existsSync()) {
      stdout.writeln('fl_env.yaml already exists — skipping.');
      return;
    }
    file.writeAsStringSync(_yamlScaffold);
    stdout.writeln('Created fl_env.yaml');
  }

  void _updateGitignore(String root) {
    final file = File(p.join(root, '.gitignore'));
    const marker = '# fl_env generated files';
    if (file.existsSync() && file.readAsStringSync().contains(marker)) {
      stdout.writeln('.gitignore already has fl_env entries — skipping.');
      return;
    }
    final sink = file.openWrite(mode: FileMode.append);
    sink.writeln();
    sink.writeln(_gitignoreBlock);
    sink.close();
    stdout.writeln('Updated .gitignore with fl_env entries.');
  }

  static const _yamlScaffold = '''
fl_env:
  default_env: development
  output:
    android: android/app/src/main
    ios: ios/Runner
  tiers:
    development: .env
    staging: .env.staging
    production: .env.production
''';

  static const _gitignoreBlock = '''# fl_env generated files — do not commit
# Run `fl_env build --env=<name>` to regenerate

**/com/pixmerc/fl_env/generated/FlEnvKey.kt
**/Generated/FlEnvKey.swift
**/res/raw/fl_env_registry.bin
**/Resources/FlEnvRegistry.bin
.fl_env_web_defines

# Source .env files
.env
.env.*
!.env.example
!.env.*.example
''';
}
