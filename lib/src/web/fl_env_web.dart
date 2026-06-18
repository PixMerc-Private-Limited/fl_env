import 'package:fl_env/src/channel/fl_env_channel.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web stub. Phase 1: web is not supported — all methods return empty/null.
class FlEnvWebPlugin {
  /// Registers the web plugin with the Flutter plugin registrar.
  static void registerWith(Registrar registrar) {
    // No-op in Phase 1; web support is Phase 2.
  }
}

/// Web implementation of [FlEnvChannelBase] — returns empty data.
class FlEnvWebChannel implements FlEnvChannelBase {
  /// Creates a [FlEnvWebChannel].
  const FlEnvWebChannel();

  @override
  Future<Map<String, String>> getAll() async => const {};

  @override
  Future<String?> getValue(String key) async => null;

  @override
  Future<String> getActiveTier() async => 'web';
}
