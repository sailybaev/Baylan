# ADR-002: Curve25519 for Identity Keypairs

**Status:** Accepted
**Date:** 2026-03-27

## Context

Baylan needs a public/private keypair system for identity. The keypair must:
- Be generated entirely on-device
- Support authenticated encryption of message payloads
- Support signing of mesh envelopes (integrity)
- Be performant on mobile hardware
- Avoid third-party dependencies where possible

## Decision

Use **Curve25519** (for key exchange / encryption) and **Ed25519** (for signing) via Apple's `CryptoKit` framework on iOS/macOS.

- Key exchange: `Curve25519.KeyAgreement` → derive shared secret → NaCl-box equivalent
- Signing: `Curve25519.Signing` (Ed25519) → sign mesh envelopes
- `user_id` = `SHA256(publicKey.rawRepresentation).prefix(16)` as hex string

## Consequences

- **Pro:** CryptoKit is a first-party Apple framework — zero external dependencies on Apple platforms
- **Pro:** Curve25519 / Ed25519 are battle-tested, used in Signal and WireGuard
- **Pro:** Constant-time operations — resistant to timing side-channels
- **Pro:** Small key size (32 bytes) fits easily in BLE advertisement payloads
- **Con:** Android needs a third-party library (Tink or BouncyCastle) for the same operations — acceptable given ecosystem difference

## Alternatives Considered

- RSA-2048: rejected — large keys, slow on mobile, no forward secrecy
- ECDSA P-256: available in CryptoKit but larger signatures, less modern
- libsodium: excellent library but adds external dependency on Apple platforms unnecessarily
