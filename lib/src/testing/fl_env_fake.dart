import 'package:fl_env/src/channel/fl_env_channel.dart';

/// In-memory [FlEnvChannelBase] implementation for use in tests.
///
/// Example usage:
/// ```dart
/// setUp(() async {
///   await FlEnvService.instance.init(
///     channel: FlEnvFakeChannel({'API_URL': 'http://localhost'}),
///   );
/// });
///
/// tearDown(() => FlEnvService.instance.reset());
/// ```
class FlEnvFakeChannel implements FlEnvChannelBase {
  /// Creates a [FlEnvFakeChannel] with the supplied [values].
  const FlEnvFakeChannel(this._values, {String activeTier = 'test'})
    : _activeTier = activeTier;

  final Map<String, String> _values;
  final String _activeTier;

  @override
  Future<Map<String, String>> getAll() async => Map.unmodifiable(_values);

  @override
  Future<String?> getValue(String key) async => _values[key];

  @override
  Future<String> getActiveTier() async => _activeTier;
}
