import 'package:fl_env/src/channel/fl_env_channel.dart';
import 'package:fl_env/src/exceptions/fl_env_exceptions.dart';
import 'package:fl_env/src/models/fl_env_config.dart';
import 'package:flutter/foundation.dart';

/// Singleton service that exposes typed accessors for the encrypted .env registry.
///
/// Must be initialised once before use, typically in `main()`:
/// ```dart
/// await FlEnvService.instance.init();
/// ```
class FlEnvService {
  FlEnvService._();

  static final FlEnvService _instance = FlEnvService._();

  /// The singleton instance.
  static FlEnvService get instance => _instance;

  FlEnvChannelBase _channel = const FlEnvChannel();
  Map<String, String> _registry = const {};
  String _activeEnvironment = 'development';
  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initialises the service by loading all values from the native registry.
  ///
  /// Pass a [channel] override for testing (use [FlEnvFakeChannel]).
  Future<void> init({FlEnvChannelBase? channel}) async {
    _channel = channel ?? const FlEnvChannel();
    try {
      _registry = await _channel.getAll();
      _activeEnvironment = await _channel.getActiveTier();
      _initialized = true;
    } on FlEnvException {
      rethrow;
    } catch (e) {
      throw FlEnvInitException(detail: e.toString());
    }
  }

  /// Resets the singleton to an uninitialised state.
  ///
  /// For use in tests only. Guarded by [kDebugMode] in production.
  @visibleForTesting
  void reset() {
    assert(kDebugMode, 'FlEnvService.reset() must only be called in debug mode.');
    _registry = const {};
    _activeEnvironment = 'development';
    _initialized = false;
    _channel = const FlEnvChannel();
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The name of the currently active environment tier.
  String get activeEnvironment => _activeEnvironment;

  /// Available environment names. Phase 1: always a single-element list.
  List<String> get availableEnvironments => [_activeEnvironment];

  /// The config snapshot (Phase 1: defaults only).
  FlEnvConfig get config => FlEnvConfig(
        defaultEnv: _activeEnvironment,
        envFiles: const {},
        outputDir: '',
      );

  // ---------------------------------------------------------------------------
  // Core accessors
  // ---------------------------------------------------------------------------

  /// Returns the raw string value for [key], or null if not found.
  String? get(String key) {
    _assertInit();
    return _registry[key];
  }

  /// Returns the raw string value for [key].
  ///
  /// Throws [FlEnvKeyNotFoundException] if the key is absent.
  String getRequired(String key) {
    final value = get(key);
    if (value == null) throw FlEnvKeyNotFoundException(key: key);
    return value;
  }

  /// Returns the value for [key] parsed as [int], or null if not found.
  int? getInt(String key) {
    final raw = get(key);
    if (raw == null) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      throw FlEnvTypeCastException(key: key, value: raw, targetType: 'int');
    }
    return parsed;
  }

  /// Returns the value for [key] parsed as [int].
  int getRequiredInt(String key) {
    final value = getInt(key);
    if (value == null) throw FlEnvKeyNotFoundException(key: key);
    return value;
  }

  /// Returns the value for [key] parsed as [bool], or null if not found.
  ///
  /// Truthy: `'true'`, `'1'`, `'yes'` (case-insensitive).
  /// Falsy: `'false'`, `'0'`, `'no'` (case-insensitive).
  bool? getBool(String key) {
    final raw = get(key);
    if (raw == null) return null;
    switch (raw.toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
      default:
        throw FlEnvTypeCastException(key: key, value: raw, targetType: 'bool');
    }
  }

  /// Returns the value for [key] parsed as [double], or null if not found.
  double? getDouble(String key) {
    final raw = get(key);
    if (raw == null) return null;
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      throw FlEnvTypeCastException(key: key, value: raw, targetType: 'double');
    }
    return parsed;
  }

  /// Returns the value for [key] parsed as a [Uri], or null if not found.
  Uri? getUri(String key) {
    final raw = get(key);
    if (raw == null) return null;
    final parsed = Uri.tryParse(raw);
    if (parsed == null) {
      throw FlEnvTypeCastException(key: key, value: raw, targetType: 'Uri');
    }
    return parsed;
  }

  /// Returns the value for [key] split on [separator], or null if not found.
  List<String>? getList(String key, {String separator = ','}) {
    final raw = get(key);
    if (raw == null) return null;
    return raw.split(separator).map((s) => s.trim()).toList();
  }

  /// Throws [FlEnvPhaseException] — multi-environment switching is Phase 2.
  Never switchEnvironment(String environment) {
    throw const FlEnvPhaseException(feature: 'switchEnvironment');
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _assertInit() {
    if (!_initialized) throw const FlEnvNotInitializedException();
  }
}
