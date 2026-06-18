## 0.1.0

### New features

- **CLI tool**: `fl_env setup`, `keygen`, `build`, `scan`, `check`, `inspect` commands.
- **`fl_env build`**: Encrypts all `.env` tier values with AES-256-GCM (HKDF-SHA256 key derivation)
  and writes a binary registry (`fl_env_registry.bin` / `FlEnvRegistry.bin`) plus a binary key file
  (`fl_env_key.bin` / `FlEnvKey.bin`) into the consumer's own app module. Resources are written to
  `android/app/src/main/res/raw/` and `ios/Runner/` by default — the consumer's directories, not
  the plugin's source tree. This is the only approach that works correctly with a published package
  (consumers cannot write into `~/.pub-cache/`).
- **`fl_env inspect [--env=<name>]`**: Prints Tier 1 key-value pairs directly from the plaintext
  `.env` file. Values whose keys match sensitive patterns (`KEY`, `TOKEN`, `SECRET`, …) are
  partially redacted so developers can confirm what will be encrypted without exposing secrets in
  terminal output.
- **`fl_env check`** (extended): In addition to lockfile drift detection, now validates
  `required_keys` (every declared key present in every tier) and `key_types` (values coercible to
  declared types). Exits 1 on any failure — suitable as a CI gate before a native build.
- **`fl_env setup`** (extended): Installs an `xcodeproj`-based Ruby hook into the consumer's
  `ios/Podfile` `post_install` block. The hook adds `FlEnvKey.bin` and `FlEnvRegistry.bin` to
  Xcode's Copy Bundle Resources phase on `pod install`, so no manual Xcode step is needed.
  Prints tutorial-style next-steps output on completion.
- **`fl_env.yaml` schema additions**: `required_keys` (list of mandatory keys), `key_types`
  (per-key type declarations: `string`, `int`, `double`, `bool`, `uri`, `list`),
  `sensitive_key_patterns` (custom redaction patterns for `fl_env inspect`).
- **Android plugin** (API 23+): `AesGcmDecryptor` (JCE), `RegistryReader` (FLEN binary format),
  `RuntimeStorage` (EncryptedSharedPreferences), full `FlEnvPlugin` MethodChannel wiring.
  `KeyManager` reads the AES key from `res/raw/fl_env_key.bin` via
  `context.resources.getIdentifier`.
- **iOS plugin** (iOS 13.0+): `AesGcmDecryptor` (CryptoKit), `RegistryReader`, `RuntimeStorage`
  (UserDefaults), full `FlEnvPlugin` MethodChannel wiring. `KeychainManager` reads the AES key
  from `FlEnvKey.bin` via `Bundle.main`.
- **Dart service layer**: `FlEnvService` singleton with typed accessors — `get`, `getRequired`,
  `getInt`, `getRequiredInt`, `getBool`, `getDouble`, `getUri`, `getList`.
- **Testing harness**: `FlEnvFakeChannel` for unit tests without the native layer.
- **Exception hierarchy**: `FlEnvNotInitializedException` (E001), `FlEnvInitException` (E002),
  `FlEnvKeyNotFoundException` (E003), `FlEnvTypeCastException` (E004), `FlEnvPhaseException` (E005).
  All exceptions carry `code`, `message`, `suggestion`, and `documentationUrl`
  (`https://fl-env.pixmerc.com/errors/<code>`).
- **Binary registry format**: magic `FLEN`, version, tier-1/tier-2 counts, per-entry 12-byte nonce
  + AES-256-GCM ciphertext — parseable by Kotlin `ByteBuffer` and Swift `Data` with no
  third-party native dependencies.

### Security

- Master key (`FL_ENV_MASTER_KEY`) is never committed — only lives in CI secrets and developer machines.
- Derived AES key is stored as a gitignored binary resource in the consumer's own app module
  (`android/…/res/raw/fl_env_key.bin`, `ios/Runner/FlEnvKey.bin`), embedded in the compiled binary.
  Migration to Android Keystore / iOS Secure Enclave hardware backing is planned for Phase 2.
- Each value is encrypted with a fresh random 12-byte nonce (AES-256-GCM).
- Registry ciphertext is safe to commit — it is useless without the corresponding key binary.
