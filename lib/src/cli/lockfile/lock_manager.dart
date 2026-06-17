import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Manages the `.fl_env.lock` file that records the SHA-256 hash of each
/// processed `.env` file at the time of the last `fl_env build`.
///
/// The `fl_env check` command uses [isDirty] to detect whether any `.env`
/// files have changed since the last build, enabling CI drift detection
/// without re-encrypting.
class LockManager {
  /// Creates a [LockManager] rooted at [projectRoot].
  LockManager(this._projectRoot);

  static const _fileName = '.fl_env.lock';

  final String _projectRoot;

  String get _lockPath => p.join(_projectRoot, _fileName);

  /// Reads the existing lock file.
  ///
  /// Returns an empty map if no lock file exists yet.
  Map<String, String> read() {
    final file = File(_lockPath);
    if (!file.existsSync()) return <String, String>{};
    final decoded = jsonDecode(file.readAsStringSync());
    return Map<String, String>.from(decoded as Map);
  }

  /// Writes SHA-256 hashes for each entry in [tierToPath] to the lock file.
  ///
  /// [tierToPath] maps tier names (e.g. `'staging'`) to absolute file paths.
  void write(Map<String, String> tierToPath) {
    final hashes = tierToPath.map(
      (tier, filePath) => MapEntry(tier, _sha256File(filePath)),
    );
    File(_lockPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(hashes),
    );
  }

  /// Returns `true` if any file in [tierToPath] has changed since the last
  /// [write], or if no lock file exists.
  bool isDirty(Map<String, String> tierToPath) {
    final saved = read();
    if (saved.isEmpty) return true;
    for (final entry in tierToPath.entries) {
      final file = File(entry.value);
      if (!file.existsSync()) return true;
      final current = _sha256File(entry.value);
      if (saved[entry.key] != current) return true;
    }
    return false;
  }

  String _sha256File(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    return sha256.convert(bytes).toString();
  }
}
