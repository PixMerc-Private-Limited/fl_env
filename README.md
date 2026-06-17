# fl_env

Secure environment variable management for Flutter. `.env` files are encrypted at build time by the CLI and decrypted natively at runtime — no plaintext at rest in the compiled binary.

---

## How it works

```
Developer machine / CI
  .env file  ──▶  fl_env build  ──▶  fl_env_registry.bin  ──▶  committed to repo
                       │
                       └──▶  FlEnvKey.kt / FlEnvKey.swift  ──▶  gitignored (never committed)

Device at runtime
  FlEnvRegistry.bin + FlEnvKey  ──▶  AES-256-GCM decrypt  ──▶  FlEnvService.get("KEY")
```

- The **master key** (`FL_ENV_MASTER_KEY`) lives only in CI secrets and developer machines.
- The **derived AES key** is embedded in the native binary at compile time (gitignored).
- The **ciphertext registry** is committed — it is safe to do so because decryption requires the key file that is never committed.

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
dart run tool/fl_env_cli/bin/fl_env.dart keygen
# → prints a 64-char hex key
export FL_ENV_MASTER_KEY=<your-key>
```

Store this key in your CI secrets (GitHub Actions: `Settings → Secrets → FL_ENV_MASTER_KEY`). Never commit it.

### 2 — Scaffold the config

```sh
dart run tool/fl_env_cli/bin/fl_env.dart setup
# Creates fl_env.yaml and updates .gitignore
```

Edit `fl_env.yaml` to match your project's `.env` file locations.

### 3 — Create your `.env` file

```sh
cp .env.example .env
# Fill in real values — this file is gitignored
```

### 4 — Build the encrypted registry

```sh
FL_ENV_MASTER_KEY=<your-key> dart run tool/fl_env_cli/bin/fl_env.dart build
# Writes:
#   android/app/src/main/res/raw/fl_env_registry.bin
#   android/app/src/main/kotlin/.../generated/FlEnvKey.kt   ← gitignored
#   ios/Runner/Resources/FlEnvRegistry.bin
#   ios/Runner/Generated/FlEnvKey.swift                      ← gitignored
```

> **iOS extra step:** Add `FlEnvRegistry.bin` to Xcode → Runner target → Build Phases → Copy Bundle Resources.

### 5 — Initialize in Dart

```dart
// main.dart
import 'package:fl_env/fl_env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlEnvService.instance.init();
  runApp(const MyApp());
}
```

Then access values anywhere:

```dart
final apiUrl = FlEnvService.instance.getRequired('API_URL');
final timeout = FlEnvService.instance.getInt('TIMEOUT') ?? 30;
final debug   = FlEnvService.instance.getBool('DEBUG') ?? false;
```

---

## API reference

| Method | Returns | Throws |
|--------|---------|--------|
| `get(key)` | `String?` | `FlEnvNotInitializedException` |
| `getRequired(key)` | `String` | `FlEnvKeyNotFoundException` |
| `getInt(key)` | `int?` | `FlEnvTypeCastException` |
| `getRequiredInt(key)` | `int` | `FlEnvKeyNotFoundException` |
| `getBool(key)` | `bool?` | `FlEnvTypeCastException` |
| `getDouble(key)` | `double?` | `FlEnvTypeCastException` |
| `getUri(key)` | `Uri?` | `FlEnvTypeCastException` |
| `getList(key, {separator})` | `List<String>?` | — |
| `activeEnvironment` | `String` | — |
| `switchEnvironment(env)` | `Never` | `FlEnvPhaseException` (Phase 2) |

`getBool` truth table: `true/1/yes` → `true` · `false/0/no` → `false` · anything else → `FlEnvTypeCastException`

---

## Exception reference

| Code | Class | Thrown when |
|------|-------|-------------|
| `FL_ENV_E001` | `FlEnvNotInitializedException` | Any accessor called before `init()` |
| `FL_ENV_E002` | `FlEnvInitException` | `init()` fails (native error) |
| `FL_ENV_E003` | `FlEnvKeyNotFoundException` | `getRequired*` called for missing key |
| `FL_ENV_E004` | `FlEnvTypeCastException` | Value cannot be parsed to requested type |
| `FL_ENV_E005` | `FlEnvPhaseException` | `switchEnvironment()` called (Phase 2 only) |

---

## Testing

Use `FlEnvFakeChannel` to avoid the native layer in unit tests:

```dart
setUp(() async {
  await FlEnvService.instance.init(
    channel: const FlEnvFakeChannel({
      'API_URL': 'http://localhost:8080',
      'DEBUG': 'true',
    }),
  );
});

tearDown(() => FlEnvService.instance.reset());
```

---

## CI integration

Add to your CI pipeline **before** the native build step:

```yaml
- name: Generate test fixtures
  env:
    FL_ENV_MASTER_KEY: ${{ secrets.FL_ENV_MASTER_KEY }}
  run: |
    dart run tool/fl_env_cli/bin/fl_env.dart build --env=development

- name: Check registry is up-to-date
  run: dart run tool/fl_env_cli/bin/fl_env.dart check
```

`fl_env check` exits 1 if any `.env` file has changed since the last `fl_env build`, making it a reliable CI gate.

---

## Security model

- **At rest:** All values are AES-256-GCM encrypted. The registry file is safe to commit.
- **Key derivation:** HKDF-SHA256 with info string `"fl_env v1"` (domain separation). See [ADR 001](doc/adr/001-aes-gcm-key-derivation.md).
- **Key storage (Phase 1):** The derived key is embedded as a source file (`FlEnvKey.kt`/`.swift`) which is gitignored. It lives in the compiled binary but is never in source control.
- **Key storage (Phase 2):** Migration to Android Keystore / iOS Secure Enclave (planned).
- **Master key:** Only ever present in CI secrets and developer machines. Never committed.

---

## .gitignore requirements

`fl_env setup` appends these entries automatically:

```gitignore
**/com/pixmerc/fl_env/generated/FlEnvKey.kt
**/Generated/FlEnvKey.swift
**/res/raw/fl_env_registry.bin
**/Resources/FlEnvRegistry.bin
.fl_env_web_defines
.env
.env.*
!.env.example
!.env.*.example
```

---

## License

MIT — see [LICENSE](LICENSE).
