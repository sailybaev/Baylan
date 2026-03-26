# Baylan — Project Specification

> Version: 0.2.0 — Decisions locked
> Status: Active design
> Last updated: 2026-03-27

This document is the single source of truth for product decisions, technical architecture, and implementation constraints. All code should be traceable to a decision recorded here.

---

## Table of Contents

1. [Product](#1-product)
2. [Identity System](#2-identity-system)
3. [Networking Model](#3-networking-model)
4. [Transport Layer](#4-transport-layer)
5. [Mesh Routing](#5-mesh-routing)
6. [Messaging Protocol](#6-messaging-protocol)
7. [User Experience](#7-user-experience)
8. [Platform Constraints](#8-platform-constraints)
9. [Security Model](#9-security-model)
10. [Data Model](#10-data-model)
11. [Future Capabilities](#11-future-capabilities)

---

## 1. Product

### 1.1 Target Users

Baylan is designed for people in situations where internet connectivity is absent, unreliable, or undesirable:

| Scenario          | Context                                                                 |
|-------------------|-------------------------------------------------------------------------|
| Campus / coworking| Dense indoor environments, poor carrier signal, shared Wi-Fi congestion |
| Travel (airplane) | No connectivity, but many devices within BLE/Wi-Fi range                |
| Remote areas      | Hiking, backcountry, festivals, construction sites                      |
| Events / protests | Network congestion or deliberate disruption                             |
| Disaster response | Infrastructure failure — exactly when communication matters most        |

### 1.2 Problem Statement

Modern messaging requires internet. When internet fails — or is deliberately unavailable — communication fails. Existing solutions (SMS, WhatsApp, Signal) have no offline mode. Satellite options (Starlink, Garmin inReach) are expensive, require subscriptions, or need hardware.

Smartphones today ship with Bluetooth 5, Wi-Fi 6, and powerful SoCs. A mesh of smartphones can form a dense enough network in many real-world scenarios to relay messages across hundreds of meters without any infrastructure.

The problem is not hardware. The problem is software.

### 1.3 Value Proposition

- No account required — identity is a keypair, generated locally
- No server to attack, take down, or surveil
- Works in the worst conditions (underground, airplane, stadium)
- Free and open source
- Cross-platform (iOS, Android, macOS)
- Familiar UX (Telegram-like, not walkie-talkie)

### 1.4 Non-Goals (v1)

- Internet-based messaging (Signal protocol relay is out of scope)
- File transfers (too large for mesh BLE bandwidth)
- Video calls
- Named persistent group chats (broadcast storms — v2)
- Cross-platform interop with other mesh networks (Meshtastic, etc.) in v1
- Background delivery (iOS foreground-only in v1)
- macOS app (iOS-first, macOS deferred)
- BLE transport (Multipeer only in v1, BLE in v2)

---

## 2. Identity System

### 2.1 Design Principles

- Identity must be self-sovereign: generated on-device, never requires a server
- Identity must be verifiable: cryptographic, not display-name-based
- Identity must be portable: can be backed up and restored
- Identity must be human-readable: shortened display form for UI

### 2.2 Keypair Generation

Algorithms: Two Curve25519-based keypairs using CryptoKit

- Signing: Ed25519 via `Curve25519.Signing`
- Key agreement: X25519 via `Curve25519.KeyAgreement`


---

## 4. Transport Layer

### 4.2 iOS / macOS: MultipeerConnectivity (Primary)

**Service type:** `baylan-mesh` (must match on all devices)

Note: Multipeer `serviceType` must be 1–15 characters, lowercase ASCII letters, numbers, and hyphen only. Dots are invalid (e.g., `com.baylan.mesh` is not allowed).

**Discovery flow:**
1. `MCNearbyServiceAdvertiser` — broadcasts presence using `serviceType: "baylan-mesh"`
2. `MCNearbyServiceBrowser` — scans for peers with matching service type
3. Browser auto-invites discovered peers (no UI) via `invitePeer(_:to:withContext:timeout:)`
4. Advertiser auto-accepts invitations by calling `invitationHandler(true, session)`
5. `MCSession` — observe `state` changes and consider a peer connected only when `state == .connected`

**Limitations:**
- Multipeer is Apple-only: iOS + macOS only
- macOS has no foreground restriction

#### Connection lifecycle and send gating

State machine (per peer):
- idle → discovering → invited → connecting → connected → disconnected (with backoff)

Rules:
- Only call `MCSession.send` when the target peer's session state is `.connected`.
- If a user taps "Start chat" and the peer isn't connected yet, transition to `connecting`, show a UI banner ("Connecting…"), and queue outbound messages.
- A background resend task drains the queue when the session transitions to `.connected`.
- If both sides invite simultaneously, tie-break with a deterministic rule (e.g., lexicographically smaller `user_id` keeps its outbound invite; the other cancels, then accepts).
- Apply exponential backoff on reconnect (e.g., 1s, 2s, 4s, up to 32s) and cancel backoff when any traffic is received.

Diagnostics (debug builds):
- Log all `MCSession` state transitions, invitation sends/accepts, and send failures with the peer's display_id and error codes.

---

## 7. User Experience

### 7.2 Screens

#### Chat Screen — Direct

- Standard message bubbles
- Delivery status indicators (sending, sent, delivered, read)
- Text input + send button
- Send button is disabled until a direct session is connected; messages typed while connecting are queued with a "clock" icon and sent automatically on connect
- A compact banner shows "Connecting to <peer>…" while the session is not yet connected

---

## 12. Implementation Checklist — Message Delivery Fix

<!-- existing content -->

---

## 13. Implementation Checklist — Multipeer Connectivity and Send Gating

Transport fixes:
- Service type: change all Multipeer usages to `serviceType: "baylan-mesh"` (valid 1–15 lowercase/hyphen). Ensure iOS and macOS builds use the same value.
- Auto-invite: the browser calls `invitePeer` immediately upon discovery; no UI.
- Auto-accept: implement `MCNearbyServiceAdvertiserDelegate.advertiser(_:didReceiveInvitationFromPeer:withContext:invitationHandler:)` and call `invitationHandler(true, session)` to accept.
- Session reuse: keep a single `MCSession` per transport with a stable `MCPeerID` for the app lifetime; do not recreate per message.
- State observation: publish `MCSessionState` per peer and gate send logic on `.connected`.

Send gating and queue:
- Queue outbound envelopes when `state != .connected` and the destination is not reachable; attach a created_at for TTL checks.
- Drain the queue immediately upon `.connected` and on each `peer` connection event.
- Backoff and retry on transient send errors; drop and mark `failed` only when TTL expires or the error is non-recoverable.

Tie-breaker for simultaneous invites:
- Compute `isInitiator = self.user_id < remote.user_id` (lexicographic compare).
- If `isInitiator` is true, send invite and ignore incoming invite; else cancel outbound and accept incoming invite.

UI integration:
- Disable the Send button until the direct session is connected; show a "Connecting…" banner after Start Chat.
- Render queued messages with a "clock" icon; replace with "relayed" or "delivered" state upon send/ack.

Diagnostics:
- Log: invite sent/accepted, session state changes, send failures (error code), and queued/drained counts.

Migration note:
- If you previously used an invalid service type (e.g., `com.baylan.mesh`), discovery may have worked via BLE presence but Multipeer sessions never connected. Update to `baylan-mesh` and verify state transitions on both macOS and iOS.

---

## Appendix A — Open Questions

<!-- existing content -->
