import 'package:fl_env/src/exceptions/fl_env_exceptions.dart';
import 'package:flutter/services.dart';

const _channelName = 'com.pixmerc.fl_env/channel';

/// Contract for the native communication layer.
abstract class FlEnvChannelBase {
  /// Returns all key/value pairs from the encrypted registry.
  Future<Map<String, String>> getAll();

  /// Returns the value for [key], or null if not found.
  Future<String?> getValue(String key);

  /// Returns the name of the active environment tier.
  Future<String> getActiveTier();
}

/// Production implementation backed by a [MethodChannel] to native Android/iOS.
class FlEnvChannel implements FlEnvChannelBase {
  /// Creates a [FlEnvChannel].
  const FlEnvChannel([this._channel = const MethodChannel(_channelName)]);

  final MethodChannel _channel;

  @override
  Future<Map<String, String>> getAll() async {
    try {
      final raw = await _channel.invokeMapMethod<String, String>('getAll');
      return raw ?? const {};
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  @override
  Future<String?> getValue(String key) async {
    try {
      return await _channel.invokeMethod<String>('getValue', {'key': key});
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  @override
  Future<String> getActiveTier() async {
    try {
      final tier = await _channel.invokeMethod<String>('getActiveTier');
      return tier ?? 'development';
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  FlEnvException _mapPlatformException(PlatformException e) {
    switch (e.code) {
      case 'PHASE_RESTRICTION':
        return const FlEnvPhaseException(feature: 'switchEnvironment');
      default:
        return FlEnvInitException(detail: '${e.code}: ${e.message}');
    }
  }
}
