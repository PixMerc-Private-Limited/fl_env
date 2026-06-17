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
  .env.staging      ─┤──▶  fl_env build  ──▶  FlEnvRegistry.bin   ← commit this (ciphertext only)
  .env.production   ─┘          │
                                └──────────────▶  FlEnvKey.kt/.swift  ← gitignore this (never commit)

Device at runtime
  FlEnvRegistry.bin + FlEnvKey  ──▶  AES-256-GCM decrypt  ──▶  FlEnvService.get('KEY')
```

- **Master key** (`FL_ENV_MASTER_KEY`) — lives only in CI secrets and developer machines. Never in the repo.
- **Derived AES key** — embedded in the native binary at compile time as a gitignored source file.
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

### 1 — Generate a master key

```sh
openssl rand -hex 32
# Prints a 64-character hex string — this is your FL_ENV_MASTER_KEY
```

**Store this key in your CI secrets** (`Settings → Secrets → Actions → FL_ENV_MASTER_KEY`). Never commit it.

### 2 — Scaffold the config

Run from your project root:

```sh
dart run fl_env setup
```

This creates `fl_env.yaml` and appends the required `.gitignore` entries automatically.

### 3 — Edit `fl_env.yaml`

The scaffold creates a starting point — edit the paths to match your project layout:

```yaml
fl_env:
  default_env: development       # active tier at runtime
  output:
    android: android/app/src/main
    ios: ios/Runner
  tiers:
    development: .env
    staging:     .env.staging
    production:  .env.production
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
FL_ENV_MASTER_KEY=<your-key> dart run fl_env build
```

This writes four files:

| File | Destination | Commit? |
|------|-------------|:-------:|
| `fl_env_registry.bin` | `android/…/res/raw/` | ✅ yes |
| `FlEnvKey.kt` | `android/…/generated/` | ❌ no |
| `FlEnvRegistry.bin` | `ios/…/Resources/` | ✅ yes |
| `FlEnvKey.swift` | `ios/…/Generated/` | ❌ no |

> **iOS note:** Add `FlEnvRegistry.bin` to your Xcode target once — open Xcode, select the Runner target → Build Phases → Copy Bundle Resources → `+` → select the file.

> **Before first build:** The repo ships placeholder `FlEnvKey.kt` / `FlEnvKey.swift` stubs with empty bytes so the project compiles immediately after cloning. Without a real master key the app will show an error card at runtime explaining what to do. Run `fl_env build` to replace the stubs with the real derived key.

Re-run `fl_env build` whenever any `.env` file changes.

### 6 — Initialize in Dart

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
    # Paths are relative to fl_env.yaml (usually your project root).
    # fl_env build writes FlEnvKey + registry into these directories.
    android: android/app/src/main
    ios: ios/Runner

  tiers:
    # Map tier name → path to the .env file (relative to fl_env.yaml)
    development: .env
    staging:     .env.staging
    production:  .env.production
```

All tiers are encrypted and bundled into the registry. The `default_env` value selects which tier is loaded at runtime.

---

## CLI commands

All commands accept `--project <path>` to target a directory other than the current working directory.

| Command | What it does |
|---------|-------------|
| `fl_env setup` | Writes a `fl_env.yaml` scaffold and updates `.gitignore` |
| `fl_env build` | Encrypts all tiers, writes registry + key files |
| `fl_env scan` | Lists discovered `.env` files and their resolved tier names |
| `fl_env check` | Exits 1 if any `.env` has changed since the last build (use as a CI gate) |

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
import 'package:flutter_test/flutter_test.dart';

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

`fl_env check` exits 1 if any `.env` file has changed since the last `fl_env build` — a reliable gate that catches stale registries before a native build wastes several minutes.

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

All exceptions extend `FlEnvException` and expose a `message`, `suggestion`, and `code`.

---

## Security model

| Aspect | Detail |
|--------|--------|
| Encryption | AES-256-GCM per value |
| Key derivation | HKDF-SHA256 with info `"fl_env v1"` (domain separation) |
| Master key | CI secrets + developer machine only — never committed |
| Derived key (Phase 1) | Gitignored native source file, embedded in the compiled binary |
| Derived key (Phase 2) | Android Keystore / iOS Secure Enclave migration (planned) |
| Registry | Ciphertext committed to repo — safe because decryption requires the key file |

---

## .gitignore requirements

`fl_env setup` appends these automatically. If you prefer to add them manually:

```gitignore
# fl_env — generated files, never commit
**/com/pixmerc/fl_env/generated/FlEnvKey.kt
**/Generated/FlEnvKey.swift
**/res/raw/fl_env_registry.bin
**/Resources/FlEnvRegistry.bin
.fl_env_web_defines

# Source .env files — commit only *.example templates
.env
.env.*
!.env.example
!.env.*.example
```

---

## License

MIT — see [LICENSE](LICENSE).
