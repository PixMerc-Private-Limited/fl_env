import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// `fl_env setup` — scaffolds `fl_env.yaml`, updates `.gitignore`, and
/// installs the iOS Podfile hook that adds the binary resource files to
/// Xcode's Copy Bundle Resources build phase.
class SetupCommand extends Command<void> {
  @override
  String get name => 'setup';

  @override
  String get description =>
      'Create fl_env.yaml, update .gitignore, and install the iOS Podfile hook.';

  @override
  Future<void> run() async {
    final projectRoot = globalResults?['project'] as String? ?? '.';

    final wroteYaml = _writeYamlScaffold(projectRoot);
    final gitignoreCount = _updateGitignore(projectRoot);
    final addedPodfileHook = _installPodfileHook(projectRoot);

    stdout.writeln();
    if (wroteYaml) {
      stdout.writeln('  ✓ Created fl_env.yaml');
    } else {
      stdout.writeln('  – fl_env.yaml already exists (skipped)');
    }
    stdout.writeln('  ✓ Updated .gitignore ($gitignoreCount entries)');
    if (addedPodfileHook) {
      stdout.writeln('  ✓ Added iOS Podfile hook (run `pod install` in ios/)');
    } else {
      stdout.writeln('  – iOS Podfile hook already present (skipped)');
    }

    stdout.writeln();
    stdout.writeln('Next steps:');
    stdout.writeln(
      '  1. Generate your master key:       '
      'export FL_ENV_MASTER_KEY=\$(dart run fl_env keygen)',
    );
    stdout.writeln(
      '  2. Copy env file templates:        '
      'cp .env.example .env',
    );
    stdout.writeln(
      '  3. Encrypt and write native files: '
      'dart run fl_env build',
    );
    stdout.writeln(
      '  4. iOS only — run pod install:     '
      'cd ios && pod install',
    );
    stdout.writeln(
      '  5. Run your app:                   '
      'flutter run',
    );
    stdout.writeln();
  }

  /// Returns `true` if the file was written (did not already exist).
  bool _writeYamlScaffold(String root) {
    final file = File(p.join(root, 'fl_env.yaml'));
    if (file.existsSync()) return false;
    file.writeAsStringSync(_yamlScaffold);
    return true;
  }

  /// Returns the number of new gitignore entries appended.
  int _updateGitignore(String root) {
    final file = File(p.join(root, '.gitignore'));
    const marker = '# fl_env generated files';
    if (file.existsSync() && file.readAsStringSync().contains(marker)) {
      return 0;
    }
    final sink = file.openWrite(mode: FileMode.append);
    sink.writeln();
    sink.writeln(_gitignoreBlock);
    sink.close();
    return _gitignoreEntryCount;
  }

  /// Installs the fl_env xcodeproj hook into the consumer's `ios/Podfile`.
  ///
  /// Strategy:
  /// - If an existing `post_install do |installer|` block is found, the hook
  ///   code is injected inside it (after the `post_install do |installer|`
  ///   line). This avoids the CocoaPods "multiple post_install" error.
  /// - If no `post_install` block exists, a new standalone block is appended.
  ///
  /// The hook is idempotent: keyed on the `# fl_env-setup` marker.
  ///
  /// Returns `true` if the hook was written.
  bool _installPodfileHook(String root) {
    final podfile = File(p.join(root, 'ios', 'Podfile'));
    if (!podfile.existsSync()) return false;

    const marker = '# fl_env-setup';
    var content = podfile.readAsStringSync();
    if (content.contains(marker)) return false;

    const existingHookPattern = 'post_install do |installer|';
    if (content.contains(existingHookPattern)) {
      // Inject inside the existing post_install block, right after its header.
      content = content.replaceFirst(
        existingHookPattern,
        '$existingHookPattern\n$_podfileHookBody',
      );
    } else {
      // No existing post_install — append a new standalone block.
      content = '$content\n$_podfileStandaloneHook\n';
    }

    podfile.writeAsStringSync(content);
    return true;
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
  # required_keys:
  #   - API_URL
  #   - API_KEY
  # key_types:
  #   TIMEOUT: int
  #   DEBUG: bool
''';

  static const _gitignoreBlock = '''# fl_env generated files — do not commit
# Run `dart run fl_env build` to regenerate

# Android
android/app/src/main/res/raw/fl_env_key.bin
android/app/src/main/res/raw/fl_env_registry.bin

# iOS
ios/Runner/FlEnvKey.bin
ios/Runner/FlEnvRegistry.bin

# Lockfile (tracks .env hashes; keep if you want CI drift detection,
# delete to force a fresh build)
.fl_env.lock

# Source .env files
.env
.env.*
!.env.example
!.env.*.example
''';

  // 8 meaningful entries (2 Android, 2 iOS, 1 lockfile, 3 env file patterns)
  static const _gitignoreEntryCount = 8;

  // Code injected inside an existing post_install block.
  static const _podfileHookBody = '''
  # fl_env-setup — do not remove
  # Adds FlEnvKey.bin and FlEnvRegistry.bin to Copy Bundle Resources so they
  # are available via Bundle.main at runtime.
  require 'xcodeproj'
  fl_env_project_path = File.expand_path('Runner.xcodeproj', __dir__)
  if File.exist?(fl_env_project_path)
    fl_env_project = Xcodeproj::Project.open(fl_env_project_path)
    fl_env_target = fl_env_project.targets.find { |t| t.name == 'Runner' }
    if fl_env_target
      fl_env_phase = fl_env_target.build_phases.find { |p| p.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase) }
      if fl_env_phase
        fl_env_group = fl_env_project.main_group.find_subpath('Runner', true)
        %w[FlEnvKey.bin FlEnvRegistry.bin].each do |name|
          next if fl_env_phase.files.any? { |f| f.file_ref&.display_name == name }
          ref = fl_env_group.new_reference(name)
          ref.set_source_tree('<group>')
          fl_env_phase.add_file_reference(ref)
        end
        fl_env_project.save
      end
    end
  end
''';

  // Standalone block used when no post_install exists in the Podfile.
  static const _podfileStandaloneHook = '''
# fl_env-setup — do not remove
# Adds FlEnvKey.bin and FlEnvRegistry.bin to Copy Bundle Resources so they
# are available via Bundle.main at runtime.
post_install do |installer|
  require 'xcodeproj'
  fl_env_project_path = File.expand_path('Runner.xcodeproj', __dir__)
  if File.exist?(fl_env_project_path)
    fl_env_project = Xcodeproj::Project.open(fl_env_project_path)
    fl_env_target = fl_env_project.targets.find { |t| t.name == 'Runner' }
    if fl_env_target
      fl_env_phase = fl_env_target.build_phases.find { |p| p.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase) }
      if fl_env_phase
        fl_env_group = fl_env_project.main_group.find_subpath('Runner', true)
        %w[FlEnvKey.bin FlEnvRegistry.bin].each do |name|
          next if fl_env_phase.files.any? { |f| f.file_ref&.display_name == name }
          ref = fl_env_group.new_reference(name)
          ref.set_source_tree('<group>')
          fl_env_phase.add_file_reference(ref)
        end
        fl_env_project.save
      end
    end
  end
end
''';
}
