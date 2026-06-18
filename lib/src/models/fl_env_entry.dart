/// A single decrypted key-value pair from the native registry.
class FlEnvEntry {
  /// Creates a [FlEnvEntry].
  const FlEnvEntry({required this.key, required this.value});

  /// The environment variable name (e.g. `'API_URL'`).
  final String key;

  /// The plaintext value (e.g. `'https://api.example.com'`).
  final String value;

  @override
  String toString() => 'FlEnvEntry(key: $key)';
}
