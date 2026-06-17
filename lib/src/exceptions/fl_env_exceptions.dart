/// Base class for all fl_env errors.
///
/// Every subclass carries a stable [code] (e.g. `FL_ENV_E001`) that can be
/// used in support conversations and documentation links, a human-readable
/// [message] describing what went wrong, a [suggestion] for the most likely
/// fix, and a [documentationUrl] pointing to the relevant docs section.
abstract class FlEnvException implements Exception {
  /// Creates a [FlEnvException].
  const FlEnvException({
    required this.message,
    required this.suggestion,
    required this.documentationUrl,
    required this.code,
  });

  /// Plain English description of what failed.
  final String message;

  /// Plain English description of the most likely fix.
  final String suggestion;

  /// Direct link to the relevant documentation section.
  final String documentationUrl;

  /// Stable error code, e.g. `FL_ENV_E001`. Consistent across Dart and native.
  final String code;

  @override
  String toString() => '[$code] $message\n'
      '  Suggestion: $suggestion\n'
      '  Docs: $documentationUrl';
}

/// Thrown when any [FlEnvService] method is called before [FlEnvService.init]
/// has completed successfully.
///
/// Error code: `FL_ENV_E001`
class FlEnvNotInitializedException extends FlEnvException {
  /// Creates a [FlEnvNotInitializedException].
  const FlEnvNotInitializedException()
      : super(
          code: 'FL_ENV_E001',
          message: 'FlEnvService has not been initialised.',
          suggestion:
              'Call `await FlEnvService.instance.init()` in main() before '
              'calling any other FlEnvService methods.',
          documentationUrl:
              'https://github.com/PixMerc-Private-Limited/fl_env#initialization',
        );
}

/// Thrown when the native layer fails to decrypt or load the registry.
///
/// Common causes: `fl_env build` was not run, the registry binary is missing,
/// or the master key has changed since the last build.
///
/// Error code: `FL_ENV_E002`
class FlEnvInitException extends FlEnvException {
  /// Creates a [FlEnvInitException] with a native [detail] message.
  const FlEnvInitException({required String detail})
      : super(
          code: 'FL_ENV_E002',
          message: 'FlEnvService failed to initialise: $detail',
          suggestion:
              'Run `dart run fl_env_cli build` to regenerate the encrypted '
              'registry, then rebuild the native app.',
          documentationUrl:
              'https://github.com/PixMerc-Private-Limited/fl_env#troubleshooting',
        );
}

/// Thrown by [FlEnvService.getRequired] when the requested key is absent from
/// the active environment registry.
///
/// Error code: `FL_ENV_E003`
class FlEnvKeyNotFoundException extends FlEnvException {
  /// Creates a [FlEnvKeyNotFoundException] for [key].
  const FlEnvKeyNotFoundException({required String key})
      : super(
          code: 'FL_ENV_E003',
          message: "Key '$key' was not found in the active environment.",
          suggestion:
              "Check that '$key' is defined in the appropriate .env file "
              'and that you have re-run `fl_env build`.',
          documentationUrl:
              'https://github.com/PixMerc-Private-Limited/fl_env#accessing-values',
        );
}

/// Thrown by typed getters (e.g. [FlEnvService.getInt]) when the raw string
/// value cannot be coerced to the requested type.
///
/// Error code: `FL_ENV_E004`
class FlEnvTypeCastException extends FlEnvException {
  /// Creates a [FlEnvTypeCastException].
  const FlEnvTypeCastException({
    required String key,
    required String value,
    required String targetType,
  }) : super(
          code: 'FL_ENV_E004',
          message: "Key '$key' has value '$value' which cannot be parsed as "
              '$targetType.',
          suggestion:
              "Check that the value for '$key' in your .env file is a valid "
              '$targetType.',
          documentationUrl:
              'https://github.com/PixMerc-Private-Limited/fl_env#typed-access',
        );
}

/// Thrown when a feature is called that is not available in the current
/// Phase 1 release.
///
/// The most common case is calling [FlEnvService.switchEnvironment], which
/// is available from fl_env 0.2.0.
///
/// Error code: `FL_ENV_E005`
class FlEnvPhaseException extends FlEnvException {
  /// Creates a [FlEnvPhaseException] for the unsupported [feature].
  const FlEnvPhaseException({required String feature})
      : super(
          code: 'FL_ENV_E005',
          message: "'$feature' is not available in fl_env 0.1.x (Phase 1).",
          suggestion: 'This capability is planned for fl_env 0.2.0. '
              'Subscribe to https://github.com/PixMerc-Private-Limited/fl_env '
              'for release notifications.',
          documentationUrl:
              'https://github.com/PixMerc-Private-Limited/fl_env#roadmap',
        );
}
