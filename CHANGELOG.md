## 0.1.0

### New features

- **CLI tool** (`tool/fl_env_cli`): `fl_env scan`, `check`, `setup`, `build`, `keygen` commands.
  `fl_env build` encrypts all `.env` values with AES-256-GCM (HKDF-SHA256 key derivation) and
  writes a binary registry plus native key files for Android and iOS.
- **Android plugin** (API 23+): `AesGcmDecryptor` (JCE), `RegistryReader` (FLEN binary format),
  `RuntimeStorage` (EncryptedSharedPreferences), full `FlEnvPlugin` MethodChannel wiring.
- **iOS plugin** (iOS 13.0+): `AesGcmDecryptor` (CryptoKit), `RegistryReader`, `RuntimeStorage`
  (UserDefaults), full `FlEnvPlugin` MethodChannel wiring.
- **Dart service layer**: `FlEnvService` singleton with typed accessors — `get`, `getRequired`,
  `getInt`, `getRequiredInt`, `getBool`, `getDouble`, `getUri`, `getList`.
- **Testing harness**: `FlEnvFakeChannel` for unit tests without the native layer.
- **Exception hierarchy**: `FlEnvNotInitializedException` (E001), `FlEnvInitException` (E002),
  `FlEnvKeyNotFoundException` (E003), `FlEnvTypeCastException` (E004), `FlEnvPhaseException` (E005).
- **Binary registry format**: magic `FLEN`, version, tier-1/tier-2 counts, per-entry
  nonce + AES-256-GCM ciphertext — parseable by Kotlin `ByteBuffer` and Swift `Data` with no
  third-party dependencies.

### Security

- Master key (`FL_ENV_MASTER_KEY`) is never committed — only lives in CI secrets and developer machines.
- Derived AES key is embedded in the native binary as a gitignored generated source file;
  migration to Android Keystore / iOS Secure Enclave is planned for Phase 2.
- Each value is encrypted with a fresh random 12-byte nonce.
