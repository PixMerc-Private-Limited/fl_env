import 'package:fl_env_cli/src/parsers/dotenv_parser.dart';
import 'package:test/test.dart';

void main() {
  late DotenvParser parser;

  setUp(() => parser = DotenvParser());

  // ---------------------------------------------------------------------------
  // Basic key=value
  // ---------------------------------------------------------------------------
  group('basic key=value', () {
    test('simple string value', () {
      final r = parser.parse('KEY=value');
      expect(r.values['KEY'], 'value');
    });

    test('numeric value', () {
      final r = parser.parse('TIMEOUT=30');
      expect(r.values['TIMEOUT'], '30');
    });

    test('empty value', () {
      final r = parser.parse('KEY=');
      expect(r.values['KEY'], '');
    });

    test('value containing equals sign', () {
      final r = parser.parse('KEY=a=b=c');
      expect(r.values['KEY'], 'a=b=c');
    });

    test('value with spaces is trimmed when unquoted', () {
      final r = parser.parse('KEY=  hello  ');
      expect(r.values['KEY'], 'hello');
    });

    test('key is trimmed', () {
      final r = parser.parse('  KEY  =value');
      expect(r.values['KEY'], 'value');
    });
  });

  // ---------------------------------------------------------------------------
  // Blank lines and comments
  // ---------------------------------------------------------------------------
  group('blank lines and comments', () {
    test('blank lines are skipped', () {
      final r = parser.parse('\n\nKEY=value\n\n');
      expect(r.values, hasLength(1));
    });

    test('comment lines are skipped', () {
      final r = parser.parse('# comment\nKEY=value');
      expect(r.values, hasLength(1));
      expect(r.values['KEY'], 'value');
    });

    test('inline comment is stripped from unquoted value', () {
      final r = parser.parse('KEY=value # this is a comment');
      expect(r.values['KEY'], 'value');
    });

    test('inline comment with no space before # is kept', () {
      // Only ` #` (space + hash) triggers comment stripping
      final r = parser.parse('KEY=value#notacomment');
      expect(r.values['KEY'], 'value#notacomment');
    });

    test('empty comment line', () {
      final r = parser.parse('#\nKEY=value');
      expect(r.values, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // export prefix
  // ---------------------------------------------------------------------------
  group('export prefix', () {
    test('strips export prefix', () {
      final r = parser.parse('export KEY=value');
      expect(r.values['KEY'], 'value');
    });

    test('strips export prefix with extra space', () {
      final r = parser.parse('export  KEY=value');
      expect(r.values['KEY'], 'value');
    });

    test('export keyword in value is not stripped', () {
      final r = parser.parse('KEY=export something');
      expect(r.values['KEY'], 'export something');
    });
  });

  // ---------------------------------------------------------------------------
  // Double-quoted values
  // ---------------------------------------------------------------------------
  group('double-quoted values', () {
    test('strips surrounding double quotes', () {
      final r = parser.parse('KEY="hello world"');
      expect(r.values['KEY'], 'hello world');
    });

    test('preserves spaces inside double quotes', () {
      final r = parser.parse('KEY="  padded  "');
      expect(r.values['KEY'], '  padded  ');
    });

    test('double-quoted value with equals sign', () {
      final r = parser.parse('KEY="a=b"');
      expect(r.values['KEY'], 'a=b');
    });

    test('double-quoted value with hash (not a comment)', () {
      final r = parser.parse('KEY="value # not a comment"');
      expect(r.values['KEY'], 'value # not a comment');
    });

    test('escaped double quote inside double-quoted value', () {
      final r = parser.parse(r'KEY="say \"hello\""');
      expect(r.values['KEY'], 'say "hello"');
    });

    test('escaped backslash inside double-quoted value', () {
      final r = parser.parse(r'KEY="path\\to\\file"');
      expect(r.values['KEY'], r'path\to\file');
    });

    test('newline escape in double-quoted value', () {
      final r = parser.parse(r'KEY="line1\nline2"');
      expect(r.values['KEY'], 'line1\nline2');
    });

    test('tab escape in double-quoted value', () {
      final r = parser.parse(r'KEY="col1\tcol2"');
      expect(r.values['KEY'], 'col1\tcol2');
    });

    test('empty double-quoted value', () {
      final r = parser.parse('KEY=""');
      expect(r.values['KEY'], '');
    });
  });

  // ---------------------------------------------------------------------------
  // Single-quoted values
  // ---------------------------------------------------------------------------
  group('single-quoted values', () {
    test('strips surrounding single quotes', () {
      final r = parser.parse("KEY='hello world'");
      expect(r.values['KEY'], 'hello world');
    });

    test('single-quoted: no escape processing', () {
      final r = parser.parse(r"KEY='no\nescape'");
      expect(r.values['KEY'], r'no\nescape');
    });

    test('single-quoted: hash is not a comment', () {
      final r = parser.parse("KEY='value # stays'");
      expect(r.values['KEY'], 'value # stays');
    });

    test('empty single-quoted value', () {
      final r = parser.parse("KEY=''");
      expect(r.values['KEY'], '');
    });
  });

  // ---------------------------------------------------------------------------
  // Multi-line content (multiple entries)
  // ---------------------------------------------------------------------------
  group('multiple entries', () {
    test('parses multiple key=value lines', () {
      final r = parser.parse('A=1\nB=2\nC=3');
      expect(r.values, <String, String>{'A': '1', 'B': '2', 'C': '3'});
    });

    test('handles Windows line endings (CRLF)', () {
      final r = parser.parse('A=1\r\nB=2');
      expect(r.values['A'], '1');
      expect(r.values['B'], '2');
    });

    test('handles old Mac line endings (CR)', () {
      final r = parser.parse('A=1\rB=2');
      expect(r.values['A'], '1');
      expect(r.values['B'], '2');
    });
  });

  // ---------------------------------------------------------------------------
  // Duplicate keys
  // ---------------------------------------------------------------------------
  group('duplicate keys', () {
    test('last value wins on duplicate key', () {
      final r = parser.parse('KEY=first\nKEY=second');
      expect(r.values['KEY'], 'second');
    });

    test('duplicate key emits a warning', () {
      final r = parser.parse('KEY=first\nKEY=second');
      expect(r.warnings, isNotEmpty);
      expect(r.warnings.first, contains('KEY'));
    });

    test('no warnings for unique keys', () {
      final r = parser.parse('A=1\nB=2');
      expect(r.warnings, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------
  group('edge cases', () {
    test('empty input returns empty map', () {
      final r = parser.parse('');
      expect(r.values, isEmpty);
    });

    test('only comments returns empty map', () {
      final r = parser.parse('# comment 1\n# comment 2');
      expect(r.values, isEmpty);
    });

    test('line without = is skipped', () {
      final r = parser.parse('NOEQUALS\nKEY=value');
      expect(r.values, hasLength(1));
      expect(r.values['KEY'], 'value');
    });

    test('URL value with protocol', () {
      final r = parser.parse('BASE_URL=https://api.example.com/v1');
      expect(r.values['BASE_URL'], 'https://api.example.com/v1');
    });

    test('value with special characters', () {
      final r = parser.parse(r'KEY=!@$%^&*()_+-');
      expect(r.values['KEY'], r'!@$%^&*()_+-');
    });

    test('unicode value', () {
      final r = parser.parse('KEY=こんにちは');
      expect(r.values['KEY'], 'こんにちは');
    });

    test('bool-like values are preserved as strings', () {
      final r = parser.parse('DEBUG=true\nFEATURE=false\nFLAG=1');
      expect(r.values['DEBUG'], 'true');
      expect(r.values['FEATURE'], 'false');
      expect(r.values['FLAG'], '1');
    });
  });
}
