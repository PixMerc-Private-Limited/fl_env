import 'package:fl_env/fl_env.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await FlEnvService.instance.init();
  });

  group('FlEnvService integration', () {
    test('service initializes successfully', () {
      expect(FlEnvService.instance.activeEnvironment, isNotEmpty);
    });

    test('get returns a non-null value for API_URL', () {
      final value = FlEnvService.instance.get('API_URL');
      expect(value, isNotNull);
      expect(value, isNotEmpty);
    });

    test('getInt returns an integer for TIMEOUT', () {
      final timeout = FlEnvService.instance.getInt('TIMEOUT');
      expect(timeout, isNotNull);
      expect(timeout, greaterThan(0));
    });

    test('getBool returns a bool for DEBUG', () {
      final debug = FlEnvService.instance.getBool('DEBUG');
      expect(debug, isNotNull);
    });

    test('switchEnvironment throws FlEnvPhaseException', () {
      expect(
        () => FlEnvService.instance.switchEnvironment('production'),
        throwsA(isA<FlEnvPhaseException>()),
      );
    });

    test('getRequired throws FlEnvKeyNotFoundException for unknown key', () {
      expect(
        () => FlEnvService.instance.getRequired('DEFINITELY_NOT_A_REAL_KEY'),
        throwsA(isA<FlEnvKeyNotFoundException>()),
      );
    });
  });
}
