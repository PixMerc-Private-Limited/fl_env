import 'package:fl_env/fl_env.dart';
import 'package:test/test.dart';

void main() {
  setUp(() async {
    await FlEnvService.instance.init(
      channel: const FlEnvFakeChannel({
        'API_URL': 'https://api.example.com',
        'TIMEOUT': '30',
        'TIMEOUT_FLOAT': '1.5',
        'DEBUG': 'true',
        'ENABLED': '1',
        'DISABLED': 'false',
        'NOPE': 'no',
        'TAGS': 'flutter,dart,mobile',
        'NOT_BOOL': 'maybe',
        'NOT_INT': 'abc',
        'NOT_FLOAT': 'xyz',
        'EMPTY_VAL': '',
      }, activeTier: 'staging'),
    );
  });

  tearDown(() => FlEnvService.instance.reset());

  group('init / state', () {
    test('initialized successfully', () {
      expect(FlEnvService.instance.activeEnvironment, 'staging');
    });

    test('availableEnvironments contains activeEnvironment', () {
      expect(FlEnvService.instance.availableEnvironments, contains('staging'));
    });

    test('throws FlEnvNotInitializedException when not initialized', () async {
      FlEnvService.instance.reset();
      expect(
        () => FlEnvService.instance.get('API_URL'),
        throwsA(isA<FlEnvNotInitializedException>()),
      );
    });
  });

  group('get / getRequired', () {
    test('get returns value for existing key', () {
      expect(FlEnvService.instance.get('API_URL'), 'https://api.example.com');
    });

    test('get returns null for missing key', () {
      expect(FlEnvService.instance.get('MISSING'), isNull);
    });

    test('getRequired returns value for existing key', () {
      expect(
        FlEnvService.instance.getRequired('API_URL'),
        'https://api.example.com',
      );
    });

    test('getRequired throws FlEnvKeyNotFoundException for missing key', () {
      expect(
        () => FlEnvService.instance.getRequired('MISSING'),
        throwsA(isA<FlEnvKeyNotFoundException>()),
      );
    });

    test('get returns empty string for empty value', () {
      expect(FlEnvService.instance.get('EMPTY_VAL'), '');
    });
  });

  group('getInt', () {
    test('parses valid integer', () {
      expect(FlEnvService.instance.getInt('TIMEOUT'), 30);
    });

    test('returns null for missing key', () {
      expect(FlEnvService.instance.getInt('MISSING'), isNull);
    });

    test('throws FlEnvTypeCastException for non-integer value', () {
      expect(
        () => FlEnvService.instance.getInt('NOT_INT'),
        throwsA(isA<FlEnvTypeCastException>()),
      );
    });

    test('getRequiredInt throws FlEnvKeyNotFoundException for missing key', () {
      expect(
        () => FlEnvService.instance.getRequiredInt('MISSING'),
        throwsA(isA<FlEnvKeyNotFoundException>()),
      );
    });

    test('getRequiredInt returns value for existing key', () {
      expect(FlEnvService.instance.getRequiredInt('TIMEOUT'), 30);
    });
  });

  group('getBool', () {
    test("'true' is truthy", () {
      expect(FlEnvService.instance.getBool('DEBUG'), isTrue);
    });

    test("'1' is truthy", () {
      expect(FlEnvService.instance.getBool('ENABLED'), isTrue);
    });

    test("'false' is falsy", () {
      expect(FlEnvService.instance.getBool('DISABLED'), isFalse);
    });

    test("'no' is falsy", () {
      expect(FlEnvService.instance.getBool('NOPE'), isFalse);
    });

    test('returns null for missing key', () {
      expect(FlEnvService.instance.getBool('MISSING'), isNull);
    });

    test('throws FlEnvTypeCastException for ambiguous value', () {
      expect(
        () => FlEnvService.instance.getBool('NOT_BOOL'),
        throwsA(isA<FlEnvTypeCastException>()),
      );
    });
  });

  group('getDouble', () {
    test('parses valid double', () {
      expect(FlEnvService.instance.getDouble('TIMEOUT_FLOAT'), 1.5);
    });

    test('returns null for missing key', () {
      expect(FlEnvService.instance.getDouble('MISSING'), isNull);
    });

    test('throws FlEnvTypeCastException for non-double value', () {
      expect(
        () => FlEnvService.instance.getDouble('NOT_FLOAT'),
        throwsA(isA<FlEnvTypeCastException>()),
      );
    });
  });

  group('getUri', () {
    test('parses valid URI', () {
      final uri = FlEnvService.instance.getUri('API_URL');
      expect(uri, isNotNull);
      expect(uri!.host, 'api.example.com');
    });

    test('returns null for missing key', () {
      expect(FlEnvService.instance.getUri('MISSING'), isNull);
    });
  });

  group('getList', () {
    test('splits on comma by default', () {
      expect(FlEnvService.instance.getList('TAGS'), [
        'flutter',
        'dart',
        'mobile',
      ]);
    });

    test('returns null for missing key', () {
      expect(FlEnvService.instance.getList('MISSING'), isNull);
    });

    test('respects custom separator', () {
      expect(FlEnvService.instance.getList('TAGS', separator: ','), [
        'flutter',
        'dart',
        'mobile',
      ]);
    });
  });

  group('switchEnvironment', () {
    test('throws FlEnvPhaseException', () {
      expect(
        () => FlEnvService.instance.switchEnvironment('production'),
        throwsA(isA<FlEnvPhaseException>()),
      );
    });

    test('FlEnvPhaseException has correct code', () {
      expect(
        () => FlEnvService.instance.switchEnvironment('production'),
        throwsA(
          isA<FlEnvPhaseException>().having(
            (e) => e.code,
            'code',
            'FL_ENV_E005',
          ),
        ),
      );
    });
  });

  group('FlEnvFakeChannel', () {
    test('getAll returns all values', () async {
      const channel = FlEnvFakeChannel({'K': 'V'});
      expect(await channel.getAll(), {'K': 'V'});
    });

    test('getValue returns value for key', () async {
      const channel = FlEnvFakeChannel({'K': 'V'});
      expect(await channel.getValue('K'), 'V');
    });

    test('getValue returns null for missing key', () async {
      const channel = FlEnvFakeChannel({'K': 'V'});
      expect(await channel.getValue('MISSING'), isNull);
    });

    test('getActiveTier returns custom tier', () async {
      const channel = FlEnvFakeChannel({}, activeTier: 'staging');
      expect(await channel.getActiveTier(), 'staging');
    });

    test('getActiveTier defaults to test', () async {
      const channel = FlEnvFakeChannel({});
      expect(await channel.getActiveTier(), 'test');
    });
  });
}
