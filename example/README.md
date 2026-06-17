# fl_env — Example App

Demo app showcasing the [`fl_env`](https://pub.dev/packages/fl_env) Flutter plugin.

The app loads encrypted environment values from three tiers (development / staging / production) and displays them with their Dart accessor types.

---

## Prerequisites

- Flutter ≥ 3.41.0
- A master key (generated below)

---

## Running the example

```sh
# 1. From the example/ directory — generate a master key
export FL_ENV_MASTER_KEY=$(dart run fl_env keygen)

# 2. Copy the example .env templates to real files
cp .env.example .env
cp .env.staging.example .env.staging
cp .env.production.example .env.production

# 3. Encrypt all tiers and write the native key + registry files
dart run fl_env build

# 4. Launch the app
flutter run
```

The app shows each environment value alongside its Dart accessor (`get()`, `getInt()`, `getBool()`, `getList()`). If `fl_env build` has not been run, an error card appears with the above steps.

---

## Project layout

| Path | Purpose |
|------|---------|
| `fl_env.yaml` | fl_env config — tier names, output paths for native files |
| `.env` / `.env.staging` / `.env.production` | Plaintext secrets (gitignored) |
| `*.example` files | Safe placeholder values to commit |
| `lib/main.dart` | Demo UI — reads values via `FlEnvService` |

---

See the [fl_env README](../README.md) for the full package documentation.
