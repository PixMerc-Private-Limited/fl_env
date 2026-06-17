/// Immutable snapshot of the active environment's configuration.
///
/// Returned by [FlEnvService.config] after a successful [FlEnvService.init].
class FlEnvConfig {
  /// Creates a [FlEnvConfig].
  const FlEnvConfig({
    required this.defaultEnv,
    required this.envFiles,
    required this.outputDir,
  });

  /// The environment tier active at initialisation time (e.g. `'development'`).
  final String defaultEnv;

  /// Glob patterns for `.env` files keyed by tier name.
  ///
  /// Example: `{'development': '.env', 'staging': '.env.staging'}`.
  final Map<String, String> envFiles;

  /// Directory where the CLI writes generated native key files and registries.
  final String outputDir;

  @override
  String toString() => 'FlEnvConfig(defaultEnv: $defaultEnv, '
      'envFiles: $envFiles, outputDir: $outputDir)';
}
