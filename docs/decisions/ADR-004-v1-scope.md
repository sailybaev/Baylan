# ADR-004: v1 Scope Constraints

**Status:** Accepted
**Date:** 2026-03-27

## Decisions Made

### iOS-first, macOS deferred
**Decision:** v1 ships iOS only. macOS is deferred.
**Why:** Reduces build complexity (one Xcode target, one set of entitlements). Multipeer works identically on macOS — it can be added in v2 with minimal shared-code changes.

### No background delivery in v1
**Decision:** App delivers messages only when in the foreground. No background BLE transport, no background task registration.
**Why:** iOS background restrictions make reliable background delivery complex to implement and test correctly. Ship a solid foreground experience first, then layer in background delivery (BLE) in v2.
**Impact:** `Info.plist` does NOT declare `bluetooth-central/peripheral` background modes in v1. `AppDelegate` does not register `BGProcessingTask`.

### Multipeer Connectivity only (no BLE in v1)
**Decision:** BLE transport is deferred to v2. Only `MultipeerTransport` is implemented in v1.
**Why:** BLE is needed primarily for background operation (which is deferred) and cross-platform (Android, deferred). Multipeer covers iOS-to-iOS foreground use perfectly. BLE adds code complexity without v1 benefit.
**Impact:** `BLETransport.swift` is a stub conforming to `TransportProtocol`. Not registered in v1.

### Nearby mesh channel (in scope for v1)
**Decision:** v1 includes a "Nearby" public broadcast channel in addition to 1-on-1 direct messages.
**Why:** The Nearby channel is the primary discovery and social hook. Users who open Baylan in the same physical space can immediately see each other and communicate without exchanging QR codes. It is the most compelling first-launch experience.
**Implementation:** `recipient_id = "nearby"` in MeshEnvelope. TTL capped at 3 hops. No encryption (public broadcast). Persisted locally.

### Message persistence (in scope for v1)
**Decision:** All messages (direct + nearby) are persisted locally in SwiftData and shown when the app reopens.
**Why:** An ephemeral chat app is significantly less useful. Users expect to see their history.

### Auto-add contacts
**Decision:** When a direct message is received from an unknown peer, they are auto-added to contacts and a thread is created. No approval step.
**Why:** Friction-free experience. In mesh context, you are physically near the sender. Blocking/removing can be a v2 feature.

### Backend: Go, empty in v1
**Decision:** Backend scaffolded at `backend/` but contains no code in v1. Stack is Go.
**Why:** Only needed for display name editing (internet-required) and future analytics. Not on the critical path for MVP.
