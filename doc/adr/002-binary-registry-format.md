# ADR 002 — Binary Registry Format

**Status:** Accepted  
**Date:** 2026-06-17

## Context

The CLI must write a file that Android and iOS native code can parse without
any runtime dependencies. The file contains AES-256-GCM ciphertext for every
`.env` key-value pair.

Requirements:
- Parseable by Kotlin `ByteBuffer` and Swift `Data` with no external libraries.
- Detectable as a fl_env registry file (magic header) to catch misconfiguration.
- Versioned so the format can evolve.
- Forward-compatible: Phase 1 has a single tier; Phase 2 will have overlay tiers.

## Decision

### File Layout

```
Offset  Size    Field                  Notes
------  ------  -----                  -----
0       4       Magic                  0x46 0x4C 0x45 0x4E ("FLEN")
4       4       Version                UInt32 big-endian = 1
8       4       Tier-1 entry count     UInt32 big-endian
12      4       Tier-2 entry count     UInt32 big-endian (Phase 1: always 0)
16      …       Tier-1 entries         see per-entry layout below
…       …       Tier-2 entries         Phase 1: empty

Per entry:
  4     key-length    UInt32 big-endian
  n     key           UTF-8 bytes (n = key-length)
  12    nonce         random, per-value
  4     cipher-length UInt32 big-endian (ciphertext + 16-byte GCM tag)
  m     cipher+tag    AES-256-GCM output (m = cipher-length)
```

### Magic Bytes

`FLEN` (`0x464C454E`) identifies the file type. Native code checks this on
every read and throws a clear error on mismatch, preventing silent corruption
or loading the wrong file.

### Big-Endian Integer Choice

Both `ByteBuffer.order(ByteOrder.BIG_ENDIAN)` (Android) and manual bit-shifting
in Swift work identically with big-endian encoding. Big-endian is also the
network byte order standard, making the format easy to inspect with hex tools.

### Tier-1 / Tier-2 Split

Phase 1 uses only Tier-1 (the active environment values). The Tier-2 count is
reserved for Phase 2 overlay semantics (e.g., "shared" defaults merged with
environment-specific overrides). Reserving the field now means Phase 2 parsers
can handle Phase 1 files without format bumps.

### Why Not JSON or YAML?

- Parsing requires a library on native side or a custom parser.
- No built-in binary encoding for ciphertext (Base64 overhead, extra complexity).
- Larger file size.

### Why Not Protobuf?

- Adds a build-time code generation step on Android and iOS.
- No meaningful benefit over a simple length-prefixed binary format for this
  fixed schema.

## Phase 2 Migration Path

1. Bump version to 2 in the header.
2. Add a 32-byte salt field after the version field (for HKDF, see ADR 001).
3. Populate Tier-2 entries with shared/override values.
4. Native code checks version and parses accordingly; version 1 files continue
   to work by treating Tier-2 count as 0.

## Alternatives Considered

| Option | Rejected because |
|---|---|
| JSON with Base64 ciphertext | Larger, requires JSON parser, no magic detection |
| SQLite | Heavy dependency, overkill for a read-once key-value store |
| Dart FFI-shared struct | Cross-language ABI is fragile and platform-specific |
| One file per key | O(n) file reads at startup; no atomic replace |
