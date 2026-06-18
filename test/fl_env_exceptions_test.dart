import 'package:fl_env/src/exceptions/fl_env_exceptions.dart';
import 'package:fl_env/src/models/fl_env_config.dart';
import 'package:fl_env/src/models/fl_env_entry.dart';
import 'package:test/test.dart';

void main() {
  group('FlEnvException hierarchy', () {
    test('FlEnvNotInitializedException is a FlEnvException', () {
      const e = FlEnvNotInitializedException();
      expect(e, isA<FlEnvException>());
      expect(e, isA<Exception>());
      expect(e.code, 'FL_ENV_E001');
      expect(e.message, isNotEmpty);
      expect(e.suggestion, isNotEmpty);
      expect(e.documentationUrl, isNotEmpty);
    });

    test('FlEnvInitException carries detail in message', () {
      const detail = 'registry binary missing';
      const e = FlEnvInitException(detail: detail);
      expect(e, isA<FlEnvException>());
      expect(e.code, 'FL_ENV_E002');
      expect(e.message, contains(detail));
    });

    test('FlEnvKeyNotFoundException carries key in message', () {
      const key = 'API_URL';
      const e = FlEnvKeyNotFoundException(key: key);
      expect(e, isA<FlEnvException>());
      expect(e.code, 'FL_ENV_E003');
      expect(e.message, contains(key));
      expect(e.suggestion, contains(key));
    });

    test('FlEnvTypeCastException carries key, value, and targetType', () {
      const e = FlEnvTypeCastException(
        key: 'TIMEOUT',
        value: 'not-a-number',
        targetType: 'int',
      );
      expect(e, isA<FlEnvException>());
      expect(e.code, 'FL_ENV_E004');
      expect(e.message, contains('TIMEOUT'));
      expect(e.message, contains('not-a-number'));
      expect(e.message, contains('int'));
    });

    test('FlEnvPhaseException carries feature name in message', () {
      const feature = 'switchEnvironment';
      const e = FlEnvPhaseException(feature: feature);
      expect(e, isA<FlEnvException>());
      expect(e.code, 'FL_ENV_E005');
      expect(e.message, contains(feature));
    });

    test('toString includes code and message', () {
      const e = FlEnvNotInitializedException();
      final str = e.toString();
      expect(str, contains('FL_ENV_E001'));
      expect(str, contains('Suggestion:'));
      expect(str, contains('Docs:'));
    });

    test('all exceptions are throwable and catchable as FlEnvException', () {
      void throwAndCatch(FlEnvException ex) {
        expect(() => throw ex, throwsA(isA<FlEnvException>()));
      }

      throwAndCatch(const FlEnvNotInitializedException());
      throwAndCatch(const FlEnvInitException(detail: 'test'));
      throwAndCatch(const FlEnvKeyNotFoundException(key: 'K'));
      throwAndCatch(
        const FlEnvTypeCastException(key: 'K', value: 'v', targetType: 'bool'),
      );
      throwAndCatch(const FlEnvPhaseException(feature: 'f'));
    });

    test('exception codes are unique', () {
      final codes = {
        const FlEnvNotInitializedException().code,
        const FlEnvInitException(detail: 'd').code,
        const FlEnvKeyNotFoundException(key: 'k').code,
        const FlEnvTypeCastException(
          key: 'k',
          value: 'v',
          targetType: 't',
        ).code,
        const FlEnvPhaseException(feature: 'f').code,
      };
      expect(codes.length, 5);
    });
  });

  group('FlEnvConfig', () {
    test('stores fields correctly', () {
      const config = FlEnvConfig(
        defaultEnv: 'development',
        envFiles: {'development': '.env'},
        outputDir: 'android/app/src/main',
      );
      expect(config.defaultEnv, 'development');
      expect(config.envFiles['development'], '.env');
      expect(config.outputDir, 'android/app/src/main');
    });

    test('toString is informative', () {
      const config = FlEnvConfig(
        defaultEnv: 'staging',
        envFiles: {},
        outputDir: '',
      );
      expect(config.toString(), contains('staging'));
    });
  });

  group('FlEnvEntry', () {
    test('stores key and value', () {
      const entry = FlEnvEntry(key: 'API_URL', value: 'https://example.com');
      expect(entry.key, 'API_URL');
      expect(entry.value, 'https://example.com');
    });

    test('toString includes key but not value (security)', () {
      const entry = FlEnvEntry(key: 'SECRET', value: 'super-secret');
      expect(entry.toString(), contains('SECRET'));
      expect(entry.toString(), isNot(contains('super-secret')));
    });
  });
}
