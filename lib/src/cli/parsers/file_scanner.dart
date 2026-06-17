import 'dart:io';

import 'package:path/path.dart' as p;

/// The result of a [FileScanner.scan] call.
class ScanResult {
  /// Creates a [ScanResult].
  const ScanResult({
    required this.found,
    required this.ignored,
    required this.warnings,
  });

  /// Tier-name → absolute file path for discovered `.env` files.
  final Map<String, String> found;

  /// File names that were skipped due to ignore patterns.
  final List<String> ignored;

  /// File names that matched suspicious patterns (e.g. `.env.bak`).
  final List<String> warnings;
}

/// Discovers `.env.*` files in a Flutter project directory.
///
/// Built-in ignored suffixes: `.example`, `.sample`, `.template`,
/// and their dotted variants (e.g. `.env.local.example`).
///
/// A tier name is derived from the file name:
/// - `.env` → `'development'`
/// - `.env.staging` → `'staging'`
/// - `.env.prod` → `'prod'`
class FileScanner {
  static const _ignoredSuffixes = <String>[
    '.example',
    '.sample',
    '.template',
  ];

  static const _warningSubstrings = <String>[
    'backup',
    'bak',
    '.old',
    'copy',
    '.tmp',
  ];

  /// Scans [projectRoot] (non-recursively) for `.env` files.
  ScanResult scan(String projectRoot) {
    final dir = Directory(projectRoot);
    if (!dir.existsSync()) {
      return const ScanResult(found: {}, ignored: [], warnings: []);
    }

    final found = <String, String>{};
    final ignored = <String>[];
    final warnings = <String>[];

    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);

      if (!_isEnvFile(name)) continue;

      if (_isIgnored(name)) {
        ignored.add(name);
        continue;
      }

      if (_isWarning(name)) {
        warnings.add(name);
      }

      final tier = _tierName(name);
      found[tier] = entity.absolute.path;
    }

    return ScanResult(found: found, ignored: ignored, warnings: warnings);
  }

  bool _isEnvFile(String name) => name == '.env' || name.startsWith('.env.');

  bool _isIgnored(String name) {
    final lower = name.toLowerCase();
    return _ignoredSuffixes.any(lower.endsWith);
  }

  bool _isWarning(String name) {
    final lower = name.toLowerCase();
    return _warningSubstrings.any(lower.contains);
  }

  String _tierName(String name) {
    if (name == '.env') return 'development';
    // Strip the leading `.env.`
    return name.substring('.env.'.length);
  }
}
