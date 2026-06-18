import 'dart:io';

import 'package:fl_env/src/cli/parsers/file_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late FileScanner scanner;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fl_env_scanner_test_');
    scanner = FileScanner();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  void createFile(String name) =>
      File(p.join(tempDir.path, name)).writeAsStringSync('KEY=value');

  group('basic discovery', () {
    test('finds bare .env as "development" tier', () {
      createFile('.env');
      final result = scanner.scan(tempDir.path);
      expect(result.found, containsPair('development', anything));
      expect(result.found['development'], endsWith('.env'));
    });

    test('finds .env.staging as "staging" tier', () {
      createFile('.env.staging');
      final result = scanner.scan(tempDir.path);
      expect(result.found, containsPair('staging', anything));
    });

    test('finds .env.production as "production" tier', () {
      createFile('.env.production');
      final result = scanner.scan(tempDir.path);
      expect(result.found, containsPair('production', anything));
    });

    test('finds multiple tiers in one scan', () {
      createFile('.env');
      createFile('.env.staging');
      createFile('.env.production');
      final result = scanner.scan(tempDir.path);
      expect(
        result.found.keys,
        containsAll(['development', 'staging', 'production']),
      );
    });

    test('ignores non-.env files', () {
      createFile('config.yaml');
      createFile('main.dart');
      final result = scanner.scan(tempDir.path);
      expect(result.found, isEmpty);
    });
  });

  group('ignored patterns', () {
    test('ignores .env.example', () {
      createFile('.env.example');
      final result = scanner.scan(tempDir.path);
      expect(result.found, isEmpty);
      expect(result.ignored, contains('.env.example'));
    });

    test('ignores .env.sample', () {
      createFile('.env.sample');
      final result = scanner.scan(tempDir.path);
      expect(result.ignored, contains('.env.sample'));
    });

    test('ignores .env.template', () {
      createFile('.env.template');
      final result = scanner.scan(tempDir.path);
      expect(result.ignored, contains('.env.template'));
    });

    test('ignores .env.staging.example', () {
      createFile('.env.staging.example');
      final result = scanner.scan(tempDir.path);
      expect(result.ignored, contains('.env.staging.example'));
    });

    test('case-insensitive ignore (.env.EXAMPLE)', () {
      createFile('.env.EXAMPLE');
      final result = scanner.scan(tempDir.path);
      expect(result.ignored, contains('.env.EXAMPLE'));
    });
  });

  group('warnings', () {
    test('warns on .env.bak', () {
      createFile('.env.bak');
      final result = scanner.scan(tempDir.path);
      expect(result.warnings, contains('.env.bak'));
    });

    test('warns on .env.backup', () {
      createFile('.env.backup');
      final result = scanner.scan(tempDir.path);
      expect(result.warnings, contains('.env.backup'));
    });

    test('no warnings for clean files', () {
      createFile('.env');
      createFile('.env.staging');
      final result = scanner.scan(tempDir.path);
      expect(result.warnings, isEmpty);
    });
  });

  group('edge cases', () {
    test('non-existent directory returns empty result', () {
      final result = scanner.scan('/nonexistent/path');
      expect(result.found, isEmpty);
    });

    test('empty directory returns empty result', () {
      final result = scanner.scan(tempDir.path);
      expect(result.found, isEmpty);
    });

    test('found paths are absolute', () {
      createFile('.env');
      final result = scanner.scan(tempDir.path);
      expect(p.isAbsolute(result.found['development']!), isTrue);
    });
  });
}
