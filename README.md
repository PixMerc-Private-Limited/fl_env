# fl_env

[![pub.dev](https://img.shields.io/pub/v/fl_env.svg)](https://pub.dev/packages/fl_env)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios%20%7C%20web-blue)](https://pub.dev/packages/fl_env)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Secure, encrypted environment variables for Flutter. `.env` files are encrypted at build time by the CLI — no plaintext secrets in your binary or your repo.

---

## How it works

```
Your machine / CI
  .env.development  ─┐
  .env.staging      ─┤──▶  fl_env build  ──▶  fl_env_registry.bin  ← commit (ciphertext)
  .env.production   ─┘          │             FlEnvRegistry.bin
                                └──────────── fl_env_key.bin        ← gitignore (key)
                                              FlEnvKey.bin

Device at runtime
  *Registry.bin + *Key.bin  ──▶  AES-256-GCM decrypt  ──▶  FlEnvService.get('KEY')
```

- **Master key** (`FL_ENV_MASTER_KEY`) — lives only in CI secrets and developer machines. Never in the repo.
- **Derived AES key** — written to the consumer's native app module as a gitignored binary resource (`fl_env_key.bin` / `FlEnvKey.bin`). Embedded in the compiled binary; not accessible from the plugin's own source.
- **Registry** — encrypted values committed to the repo. Safe to commit; useless without the key.

---

## Platform support

| Android | iOS | Web |
|:-------:|:---:|:---:|
| ✅ | ✅ | ⚠️ stub |

Web returns empty values in Phase 1 (native crypto only). Android requires API 23+.

---

## Installation

```yaml
# pubspec.yaml
dependencies:
  fl_env: ^0.1.0
```

---

## Quick start

### 1 — Scaffold the config

Run from your Flutter project root:

```sh
dart run fl_env setup
```

This creates `fl_env.yaml`, appends `.gitignore` entries, and installs the iOS Podfile hook that adds the binary resources to Xcode's Copy Bundle Resources phase automatically.

### 2 — Generate a master key

```sh
export FL_ENV_MASTER_KEY=$(dart run fl_env keygen)
```

Store this value in your CI secrets (`Settings → Secrets → Actions → FL_ENV_MASTER_KEY`). Never commit it.

### 3 — Edit `fl_env.yaml`

The scaffold creates a starting point — edit to match your project:

```yaml
fl_env:
  default_env: development
  output:
    android: android/app/src/main
    ios: ios/Runner
  tiers:
    development: .env
    staging:     .env.staging
    production:  .env.production
  required_keys:
    - API_URL
    - API_KEY
  key_types:
    TIMEOUT: int
    DEBUG: bool
```

See the [fl_env.yaml reference](#fl_envyaml-reference) below for all options.

### 4 — Create your `.env` files

```sh
# .env  (gitignored — fill in real values)
API_URL=https://dev.api.example.com
API_KEY=dev_key_xxxxxxxxxxxx
TIMEOUT=30
DEBUG=true
TAGS=flutter,dart,dev
```

Commit a `.env.example` with safe dummy values so teammates can bootstrap:

```sh
# .env.example  (committed — safe placeholder values)
API_URL=https://dev.api.example.com
API_KEY=dev_key_xxxxxxxxxxxx
TIMEOUT=30
DEBUG=true
TAGS=flutter,dart,dev
```

### 5 — Build the encrypted registry

```sh
dart run fl_env build
```

This writes four files into your consumer app's own directories:

| File | Destination | Commit? |
|------|-------------|:-------:|
| `fl_env_key.bin` | `android/app/src/main/res/raw/` | ❌ no |
| `fl_env_registry.bin` | `android/app/src/main/res/raw/` | ✅ yes |
| `FlEnvKey.bin` | `ios/Runner/` | ❌ no |
| `FlEnvRegistry.bin` | `ios/Runner/` | ✅ yes |

### 6 — iOS: run pod install

```sh
cd ios && pod install
```

The Podfile hook installed by `fl_env setup` adds `FlEnvKey.bin` and `FlEnvRegistry.bin` to Xcode's Copy Bundle Resources phase automatically. This only needs to happen once (or after a fresh clone).

### 7 — Initialize in Dart

```dart
// main.dart
import 'package:fl_env/fl_env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlEnvService.instance.init();
  runApp(const MyApp());
}
```

Then read values from anywhere in your app:

```dart
final url     = FlEnvService.instance.get('API_URL');           // String?
final timeout = FlEnvService.instance.getInt('TIMEOUT') ?? 30;  // int
final debug   = FlEnvService.instance.getBool('DEBUG') ?? false; // bool
final tags    = FlEnvService.instance.getList('TAGS');           // List<String>?
```

---

## fl_env.yaml reference

```yaml
fl_env:
  default_env: development     # tier name to load at runtime

  output:
    # Paths relative to fl_env.yaml (your project root).
    # fl_env build writes key + registry into these directories.
    android: android/app/src/main
    ios: ios/Runner

  tiers:
    # Map tier name → path to the .env file (relative to fl_env.yaml)
    development: .env
    staging:     .env.staging
    production:  .env.production

  # Optional: every listed key must be present in every tier's .env file.
  # fl_env check exits 1 if any are missing.
  required_keys:
    - API_URL
    - API_KEY

  # Optional: declare the expected type for specific keys.
  # fl_env check verifies the value is coercible before a build.
  # Supported types: string (default), int, double, bool, uri, list
  key_types:
    TIMEOUT: int
    DEBUG: bool
    API_URL: uri

  # Optional: keys whose values are redacted in fl_env inspect output.
  # Defaults: SECRET, KEY, TOKEN, PASSWORD, PRIVATE, CREDENTIAL, AUTH
  sensitive_key_patterns:
    - SECRET
    - KEY
    - TOKEN
```

---

## CLI commands

All commands accept `--project <path>` to target a directory other than the current working directory.

| Command | What it does |
|---------|-------------|
| `fl_env setup` | Writes `fl_env.yaml`, updates `.gitignore`, installs iOS Podfile hook |
| `fl_env keygen` | Prints a fresh 64-char hex master key to stdout |
| `fl_env build [--env=<name>]` | Encrypts all tiers, writes registry + key binary files |
| `fl_env inspect [--env=<name>]` | Prints Tier 1 key-value pairs from the `.env` file; redacts sensitive values |
| `fl_env scan` | Lists discovered `.env` files and their resolved tier names |
| `fl_env check` | Detects drift, validates required_keys and key_types; exits 1 on failure (CI gate) |

---

## Dart API

### Typed accessors

| Method | Return type | Throws if unparseable |
|--------|-------------|----------------------|
| `get(key)` | `String?` | — |
| `getRequired(key)` | `String` | `FlEnvKeyNotFoundException` |
| `getInt(key)` | `int?` | `FlEnvTypeCastException` |
| `getRequiredInt(key)` | `int` | `FlEnvKeyNotFoundException` / `FlEnvTypeCastException` |
| `getBool(key)` | `bool?` | `FlEnvTypeCastException` |
| `getDouble(key)` | `double?` | `FlEnvTypeCastException` |
| `getUri(key)` | `Uri?` | `FlEnvTypeCastException` |
| `getList(key, {separator})` | `List<String>?` | — |
| `activeEnvironment` | `String` | — |

All accessors throw `FlEnvNotInitializedException` if called before `init()`.

**`getBool` truth table** (case-insensitive):

| Value | Result |
|-------|--------|
| `true` / `1` / `yes` | `true` |
| `false` / `0` / `no` | `false` |
| anything else | `FlEnvTypeCastException` |

---

## Testing

Use `FlEnvFakeChannel` to bypass the native layer in unit tests:

```dart
import 'package:fl_env/fl_env.dart';
import 'package:test/test.dart';

void main() {
  setUp(() async {
    await FlEnvService.instance.init(
      channel: const FlEnvFakeChannel({
        'API_URL': 'http://localhost:8080',
        'DEBUG':   'true',
        'TIMEOUT': '5',
      }),
    );
  });

  tearDown(() => FlEnvService.instance.reset());

  test('reads API_URL', () {
    expect(FlEnvService.instance.get('API_URL'), 'http://localhost:8080');
  });

  test('parses DEBUG as bool', () {
    expect(FlEnvService.instance.getBool('DEBUG'), isTrue);
  });
}
```

`FlEnvFakeChannel` also accepts an `activeTier` parameter (defaults to `'test'`).

---

## CI integration

Add these steps **before** the native build step:

```yaml
- name: Generate env registry
  env:
    FL_ENV_MASTER_KEY: ${{ secrets.FL_ENV_MASTER_KEY }}
  run: |
    cp .env.example .env
    cp .env.staging.example  .env.staging
    cp .env.production.example .env.production
    dart run fl_env build

- name: Assert registry is up-to-date
  run: dart run fl_env check
```

`fl_env check` exits 1 if any `.env` file has changed since the last `fl_env build`, or if any `required_keys` are missing, or if any `key_types` values are not coercible — a reliable gate that catches misconfiguration before a native build wastes several minutes.

Add `FL_ENV_MASTER_KEY` to your repository secrets: **Settings → Secrets → Actions → New repository secret**.

---

## Exception reference

| Code | Class | Thrown when |
|------|-------|-------------|
| `FL_ENV_E001` | `FlEnvNotInitializedException` | Any accessor called before `init()` |
| `FL_ENV_E002` | `FlEnvInitException` | `init()` fails (native decryption error) |
| `FL_ENV_E003` | `FlEnvKeyNotFoundException` | `getRequired*` called for an absent key |
| `FL_ENV_E004` | `FlEnvTypeCastException` | Value cannot be parsed to the requested type |
| `FL_ENV_E005` | `FlEnvPhaseException` | `switchEnvironment()` called (Phase 2 only) |

All exceptions extend `FlEnvException` and expose `message`, `suggestion`, `code`, and `documentationUrl` (pointing to `https://fl-env.pixmerc.com/errors/<code>`).

---

## Security model

| Aspect | Detail |
|--------|--------|
| Encryption | AES-256-GCM per value, unique 12-byte nonce per entry |
| Key derivation | HKDF-SHA256 with info `"fl_env v1"` (domain separation) |
| Master key | CI secrets + developer machine only — never committed |
| Derived key (Phase 1) | Gitignored binary resource in consumer app module (`fl_env_key.bin` / `FlEnvKey.bin`), embedded in compiled binary |
| Derived key (Phase 2) | Android Keystore / iOS Secure Enclave migration (planned) |
| Registry | Ciphertext committed to repo — safe because decryption requires the key |

---

## .gitignore requirements

`fl_env setup` appends these automatically. If you prefer to add them manually:

```gitignore
# fl_env generated files — do not commit
android/app/src/main/res/raw/fl_env_key.bin
android/app/src/main/res/raw/fl_env_registry.bin
ios/Runner/FlEnvKey.bin
ios/Runner/FlEnvRegistry.bin

# Lockfile (tracks .env hashes for drift detection)
.fl_env.lock

# Source .env files — commit only *.example templates
.env
.env.*
!.env.example
!.env.*.example
```

---

## License

MIT — see [LICENSE](LICENSE).
