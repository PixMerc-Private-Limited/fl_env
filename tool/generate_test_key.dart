/// Generates a deterministic test master key for CI.
///
/// Usage:
///   dart run tool/generate_test_key.dart
///
/// The key is written to stdout so CI can capture it:
///   export FL_ENV_MASTER_KEY=$(dart run tool/generate_test_key.dart)
library;

import 'dart:io';

void main() {
  // A fixed, non-secret key used only in CI test fixtures.
  // NEVER use this key in production.
  const testKey =
      'c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6'
      'a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2';
  stdout.write(testKey);
}
