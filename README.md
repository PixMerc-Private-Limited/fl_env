# fl_env

> **Work in progress** — this is a placeholder release (0.0.1).
> The full v0.1.0 implementation is in active development.

fl_env securely loads and manages environment variables in Flutter apps.
Values are AES-256-GCM encrypted at build time by the `fl_env` CLI tool
and decrypted natively on Android and iOS at runtime — never stored in plain
text in your repository.

## What's coming in 0.1.0

- `fl_env` CLI: dotenv scanner, AES-256-GCM build-time encryption
- Native Android decryption (API 23+, JCE `AES/GCM/NoPadding`)
- Native iOS decryption (iOS 13+, CryptoKit `AES.GCM`)
- Typed Dart accessors: `get`, `getRequired`, `getInt`, `getBool`, `getDouble`, `getUri`, `getList`
- `FlEnvFakeChannel` test harness for consumer app unit tests

## Repository

[github.com/Sam21-39/fl_env](https://github.com/Sam21-39/fl_env)
