# ADR 001 — AES-256-GCM with HKDF-SHA256 Key Derivation

**Status:** Accepted  
**Date:** 2026-06-17

## Context

fl_env needs to encrypt `.env` values at build time (CLI) and decrypt them at
runtime on Android and iOS. The encryption scheme must be:

1. Strong enough to protect secrets if the compiled binary is extracted.
2. Implementable without third-party dependencies on Android and iOS (JCE and
   CryptoKit are both standard).
3. Deterministic enough to re-derive the same key from the same master secret.
4. Designed so the master key never enters the compiled binary.

## Decision

**Algorithm:** AES-256-GCM  
**Key derivation:** HKDF-SHA256 (RFC 5869)  
**Key input:** `FL_ENV_MASTER_KEY` — a 64-character lowercase hex string (32
bytes) provided as a CI/CD environment variable and never committed.

### HKDF parameters (Phase 1)

| Parameter | Value | Rationale |
|---|---|---|
| Hash | SHA-256 | Matches AES-256 security level |
| IKM | master key bytes (32) | Raw entropy from FL_ENV_MASTER_KEY |
| Salt | 32 zero bytes | Phase 1 simplification; Phase 2 uses per-build random salt stored in registry header |
| Info | `"fl_env v1"` (UTF-8) | Domain separation; version bump forces key rotation |
| Length | 32 bytes | AES-256 key size |

### Why HKDF over PBKDF2?

PBKDF2 is designed for low-entropy human passwords (slow stretching). Our IKM
is already 256 bits of entropy, so stretching provides no benefit. HKDF is the
standard key-derivation function for high-entropy keying material (TLS 1.3,
Signal Protocol).

### Why not raw master key as AES key?

Domain separation via HKDF info string `"fl_env v1"` ensures the AES key is
independent of any other use of the master key material. Bumping the info
string in a future version forces re-derivation without requiring a new master
key.

### Nonce strategy

A fresh 12-byte cryptographically random nonce is generated per value
encryption. The nonce is stored alongside the ciphertext in the binary
registry. GCM authentication tag is 128 bits (the default maximum).

## Phase 1 Limitations

- Salt is 32 zero bytes — a static salt provides no per-build entropy isolation.
  If the same master key is used across environments, the same AES key is
  derived for all of them.
- No key rotation — changing the master key requires re-running `fl_env build`.

## Phase 2 Migration Path

1. Generate a random 32-byte salt per `fl_env build` run.
2. Store the salt in the registry file header (after the version field).
3. Native code reads the salt from the file before HKDF derivation.
4. Rotate the master key annually via CI secret rotation.
5. Move the derived AES key into the Android Keystore / iOS Secure Enclave
   rather than embedding it as a source file.

## Alternatives Considered

| Option | Rejected because |
|---|---|
| AES-CBC + HMAC | More complex (Encrypt-then-MAC), no built-in auth tag |
| ChaCha20-Poly1305 | Not available in JCE without third-party provider on API 23-27 |
| RSA-OAEP | Asymmetric; key size and performance mismatch for bulk value encryption |
| Plain AES-GCM without HKDF | No domain separation; couples master key directly to cipher key |
