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

Algorithm: **Curve25519** (via `CryptoKit` on Apple, `Tink` on Android)

```
keypair = Curve25519.generateKeyPair()
  → privateKey: 32 bytes (stored in Keychain / Android Keystore)
  → publicKey:  32 bytes (shared freely)
```

Rationale for Curve25519:
- Industry standard for modern asymmetric crypto (used by Signal, WireGuard)
- Fast, constant-time, small key size
- Native in Apple CryptoKit (no third-party dependency on iOS/macOS)

### 2.3 User ID Derivation

```
user_id = SHA-256(publicKey)[0..<16]  →  hex string, 32 characters
display_id = user_id[0..<8]           →  "a3f7c901" (shown in UI)
```

The full user_id is used internally. The display_id is shown in the UI as a human-readable fingerprint. Users are encouraged to set a display name, but the display_id is always visible to prevent spoofing.

### 2.4 Identity Storage

| Platform | Private key storage   | Public key + metadata |
|----------|-----------------------|-----------------------|
| iOS      | Keychain (kSecAttrAccessibleAfterFirstUnlock) | UserDefaults / SwiftData |
| macOS    | Keychain              | UserDefaults / SwiftData |
| Android  | Android Keystore      | SharedPreferences / Room |

The private key never leaves the secure enclave storage. All signing happens in-place.

### 2.5 QR Code Exchange

A QR code encodes a compact identity payload:

```json
{
  "v": 1,
  "id": "a3f7c9018b2de456",
  "pk": "<base64-encoded-public-key>",
  "name": "Alice"
}
```

Scanning adds the peer to the local contact book with a verified public key binding. This is the primary trust-establishment mechanism in v1.

### 2.6 Display Name Editing

Display name is editable, but **only when internet is available**. The app checks for connectivity before allowing edits. The updated name is stored locally and, if a backend profile sync is implemented, pushed to the server. Local contacts who have previously scanned your QR will not automatically receive the name update in v1 — it will only propagate when they re-scan or when presence messages carry the new name.

### 2.7 Optional Internet Profile Sync

Out of scope for v1. Future: users may optionally upload a signed profile blob to a relay server, enabling contact discovery by username. The server never holds private keys and cannot impersonate users (signature is required).

---

## 3. Networking Model

### 3.1 Topology

Baylan uses an **opportunistic mesh** topology, not a structured DHT or fixed routing table. This is appropriate for the target scenarios (sparse, mobile, ephemeral networks).

```
Device A ──BLE──► Device B ──Multipeer──► Device C
                                              │
                                           (target)
```

All devices within range form an ad-hoc graph. Messages propagate outward from the source, hopping across relay devices, until they reach the destination or TTL expires.

### 3.2 Delay-Tolerant Networking (DTN)

Baylan implements a simplified DTN model:

- Messages are **stored locally** when the destination is unreachable
- When a new peer connects, the store-and-forward queue is evaluated
- Messages with remaining TTL that match a known routing opportunity are forwarded
- Maximum store-and-forward window: **5 minutes** (configurable, platform-constrained)
- This enables delivery even when no continuous path exists (contact opportunism)

### 3.3 Network Assumptions

- Range: BLE ~10–30m reliable, Multipeer (Wi-Fi) ~30–100m
- Density: minimum 1 relay device per ~50m for effective mesh
- Bandwidth: ~20–50 kbps effective for BLE; sufficient for text only
- Latency: highly variable (0.1s direct, up to 120s via multi-hop store-and-forward)
- Reliability: unreliable by design — the protocol handles it

---

## 4. Transport Layer

### 4.1 Abstraction

Every transport conforms to a single protocol. The mesh engine interacts only with this protocol, never with platform APIs directly.

```
TransportProtocol
  ├── discover()        — start scanning for peers
  ├── advertise()       — make self visible
  ├── connect(peer)     — establish session
  ├── disconnect(peer)
  ├── send(data, peer)  — send raw bytes to connected peer
  └── events           — stream of: peerFound, peerLost, dataReceived, connectionStateChanged
```

### 4.2 iOS / macOS: MultipeerConnectivity (Primary)

**Framework:** `MultipeerConnectivity` (Apple, built-in)

- Uses Wi-Fi Direct + Bluetooth LE for peer discovery and data transfer
- Automatic session negotiation
- Up to 8 peers per session natively (extendable via multiple sessions)
- Works identically on iOS and macOS → shared implementation in `apple/shared/`

**Discovery flow:**
1. `MCNearbyServiceAdvertiser` — broadcasts presence
2. `MCNearbyServiceBrowser` — scans for peers with matching service ID
3. Auto-invite strategy (no UI confirmation required in mesh mode)
4. `MCSession` — manages connection state and data channels

**Service identifier:** `com.baylan.mesh` (must match on all devices)

**Limitations:**
- Requires app in foreground (or active background task) on iOS
- macOS has no foreground restriction

### 4.3 iOS: BLE Fallback Transport

**Framework:** `CoreBluetooth`

Used when Multipeer is unavailable or as a supplementary channel:
- Custom GATT service for message advertisement
- Peripheral mode: advertises presence + small message payloads
- Central mode: scans and reads from nearby peripherals
- Throughput: ~1–5 kbps effective — short messages only
- Primary use: peer discovery heartbeat + small control messages

**BLE service UUID:** `BF550001-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (to be finalized)

### 4.4 Android: BLE (Primary)

**API:** Android BluetoothLeAdvertiser / BluetoothLeScanner + GATT

- GATT server for receiving messages
- GATT client for peer-initiated push
- Foreground service required for reliable background operation

### 4.5 Android: Wi-Fi Direct

**API:** `WifiP2pManager`

- Used for high-throughput sessions once peers are discovered via BLE
- More complex lifecycle management than iOS Multipeer
- Falls back to BLE-only if Wi-Fi Direct is unavailable

### 4.6 Transport Priority Matrix

| Scenario               | Primary              | Fallback |
|------------------------|----------------------|----------|
| iOS ↔ iOS              | MultipeerConnectivity | BLE      |
| iOS ↔ macOS            | MultipeerConnectivity | BLE      |
| macOS ↔ macOS          | MultipeerConnectivity | —        |
| Android ↔ Android      | BLE + Wi-Fi Direct   | BLE only |
| iOS ↔ Android          | BLE                  | —        |
| macOS ↔ Android        | BLE                  | —        |

Cross-platform (Apple ↔ Android) in v1 uses BLE only. Full cross-platform mesh is a v2 goal.

---

## 5. Mesh Routing

### 5.1 Routing Strategy: Epidemic (Gossip)

v1 uses **epidemic routing**: every device that receives a message and is not the destination re-broadcasts it to all known peers (subject to TTL and duplicate suppression). This is simple, robust in sparse networks, and requires no routing table maintenance.

Tradeoffs:
- Pro: zero configuration, handles network partitions well
- Con: message amplification — mitigated by TTL and hop limits

v2 consideration: PRoPHET routing (probabilistic, history-based) for denser networks.

### 5.2 Message Envelope

Every message in the mesh is wrapped in an envelope:

```
MeshEnvelope {
    message_id:    UUID           // globally unique, used for dedup
    sender_id:     UserID         // source (32-char hex)
    recipient_id:  UserID         // destination (32-char hex), or broadcast
    payload:       Data           // encrypted MessagePayload
    ttl:           UInt8          // decremented each hop, default 7
    hop_count:     UInt8          // incremented each hop
    created_at:    Int64          // unix timestamp (ms)
    signature:     Data           // sender's Ed25519 signature over fields above
}
```

### 5.3 Routing Rules

When a device receives a MeshEnvelope:

```
1. Verify signature (drop if invalid)
2. Check message_id against seen-set (drop if duplicate)
3. Add message_id to seen-set (with TTL expiry)
4. Decrement envelope.ttl
5. If ttl == 0: drop
6. If recipient_id == self.user_id: deliver to inbox
7. Else if recipient_id == broadcast: deliver locally + relay
8. Else: add to outbound relay queue
9. For each connected peer (not sender): send envelope
```

### 5.4 Duplicate Suppression

A bloom filter or fixed-size LRU cache keyed on `message_id` tracks recently seen messages. Cache size: 2048 entries with 10-minute TTL. This prevents forwarding loops in dense mesh scenarios.

### 5.5 Store-and-Forward Queue

When a message cannot be delivered (no path to recipient):
- Stored in local SQLite/SwiftData persistent queue
- Queue entry includes: envelope + expiry (created_at + store_ttl)
- On each new peer connection: scan queue for messages with recipient in peer's known-route
- Immediate: forward directly if peer IS the recipient
- Via relay: forward if peer is a relay node (always true in epidemic routing)
- Expiry: messages older than `store_ttl` (default 5 minutes) are purged

---

## 6. Messaging Protocol

### 6.1 Conversation Types

Baylan has two conversation types in v1:

| Type | Description | Routing |
|------|-------------|---------|
| **Direct** | 1-on-1 between two known users | recipient_id = peer's user_id |
| **Nearby** | Public mesh channel visible to all nearby peers | recipient_id = `"nearby"` (special broadcast) |

**Nearby channel** is a single shared space — like a local public square. All devices within mesh range that have Baylan open can see and post to it. Messages are TTL-capped at 3 hops to keep it geographically local. There is one Nearby channel per session; it is not named or persistent beyond message history.

### 6.2 Message Types

```
MessageType {
    text          // UTF-8 text message
    ack           // delivery acknowledgment
    presence      // heartbeat / online status
    key_exchange  // public key advertisement for discovery
}
```

### 6.2 MessagePayload (inner, encrypted)

```
MessagePayload {
    type:       MessageType
    body:       String?         // text content (for .text)
    timestamp:  Int64           // sender-side timestamp
    thread_id:  UUID?           // conversation identifier
}
```

### 6.3 Encryption

v1: **NaCl box** (X25519 key exchange + XSalsa20-Poly1305)

```
encryptedPayload = NaCl.box(
    message: serialized(MessagePayload),
    recipientPublicKey: recipient.publicKey,
    senderPrivateKey: self.privateKey
)
```

The mesh envelope carries only sender_id and recipient_id in the clear (needed for routing). The payload is opaque to relay nodes.

Relay nodes forward ciphertext they cannot read. This provides **forward secrecy for content** even in epidemic routing.

### 6.4 Delivery States

| State      | Meaning                                              |
|------------|------------------------------------------------------|
| `sending`  | In local outbound queue, no peer path confirmed yet  |
| `relayed`  | At least one relay node confirmed receipt            |
| `delivered`| Destination device sent an `ack` message back        |
| `failed`   | TTL expired, no delivery path found                  |

`relayed` is a best-effort state: a relay ACK doesn't guarantee final delivery.

### 6.5 Presence Protocol

Every 30 seconds (when active), a device broadcasts a `presence` message:
- Contains: user_id, display_name, public_key, timestamp
- TTL: 2 hops (only visible to nearby mesh, not propagated far)
- Used to populate the "nearby" peer list in UI
- Not encrypted — public advertisement

---

## 7. User Experience

### 7.1 Design Philosophy

The UI must feel **familiar**, not technical. Users should not need to understand mesh networking to use Baylan. The experience should feel like Telegram for text, with subtle indicators of the underlying mesh behavior.

### 7.2 Screens

#### Discovery Screen
- Primary entry point
- Animated radar / pulse visualization showing nearby peers
- Each peer bubble: display_name + display_id + signal strength heuristic
- Tap peer → start conversation or view profile
- "Nearby" channel button always visible — tap to open shared mesh channel

#### Conversations Screen
- List of active conversations (most recent first)
- **Nearby** channel always pinned at top
- Per-conversation: peer name, last message preview, delivery state indicator, timestamp
- Unread badge

#### Chat Screen — Direct
- Standard message bubbles (sent right, received left)
- Delivery state icon per message (clock = sending, arrow = relayed, double-check = delivered, X = failed)
- "via mesh" subtitle when message was relayed (hop count > 1)
- Text input + send button

#### Chat Screen — Nearby (mesh channel)
- Same bubble layout but sender name shown above each bubble
- All messages visible to all nearby peers
- No delivery states (broadcast, best-effort)
- Messages persist locally for the session

#### Identity Screen
- Large QR code (your identity payload)
- Your display_id and display_name
- "Copy public key" action
- "Edit display name" action (requires internet — greyed out if offline)

#### Settings Screen
- Display name (internet required to edit)
- Store-and-forward window duration
- Clear local message history

### 7.3 Contact Auto-Addition

When a peer scans your QR code, or when you receive a direct message from an unknown peer, they are automatically added to your contacts and a conversation thread is created. No manual approval step in v1. Users can delete conversations later.

This means the Conversations list grows organically as you encounter people.

### 7.3 Nearby Awareness

The discovery screen updates in real time as peers come and go. A peer is considered "nearby" if a presence message was received within the last 90 seconds. Distance heuristics are approximate (signal strength only — no GPS required).

### 7.4 Delivery State UX

The delivery state is always visible in the chat. Users in unreliable mesh environments should understand that `relayed` is a positive sign, not a failure. Copy: "Your message is traveling the mesh."

---

## 8. Platform Constraints

### 8.1 iOS Background Execution

iOS aggressively suspends apps in background. This is the most significant constraint for a mesh application.

| Background mode          | Available | Notes                                              |
|--------------------------|-----------|----------------------------------------------------|
| Background fetch         | Yes       | Periodic, OS-controlled, ~15 min intervals         |
| Background processing    | Yes       | For heavy tasks, unreliable timing                  |
| `uses-bluetooth-le`      | Yes       | BLE scanning/advertising continues in background   |
| `voip`                   | No        | Not applicable (not a VoIP app)                    |
| MultipeerConnectivity    | Partial   | Session may survive ~30s after background, then suspended |
| Background URLSession    | Yes       | Not relevant for mesh                              |

**Strategy for iOS background:**
- Primary: BLE heartbeat (background-capable via `bluetooth-central` / `bluetooth-peripheral` entitlements)
- BLE carries small `presence` messages and indicates available messages
- When user foregrounds app, Multipeer session restores and queued messages transfer
- Notify user via local notification: "X messages received while away"

This means iOS Multipeer is primarily a foreground transport. BLE is the always-on background channel.

### 8.2 macOS Background Execution

macOS has no equivalent restrictions. The app can run Multipeer in background indefinitely, making macOS nodes excellent mesh relays. macOS nodes should be treated as high-reliability relay points.

### 8.3 Battery Considerations

BLE scanning is the primary battery concern.

| Operation              | Current draw (approx) | Strategy                            |
|------------------------|----------------------|-------------------------------------|
| BLE scanning (active)  | ~10mA                | Duty-cycle: 30s on / 30s off        |
| BLE advertising        | ~5mA                 | Continuous (low-power mode)         |
| Multipeer session (Wi-Fi active) | ~50–100mA | Only when app is foreground         |
| Message crypto         | Negligible           | Curve25519 is fast                  |

Implement adaptive scanning: slower duty cycle when battery < 20%.

### 8.4 Connection Reliability

Mesh connections are unreliable by design. The protocol handles this. Implementation must:
- Never block on a single connection
- Always use async/non-blocking send
- Always handle `peerLost` gracefully (not as an error condition)
- Reconnect automatically with exponential backoff

### 8.5 Android Background Execution

Android requires a **Foreground Service** with a persistent notification for reliable background BLE operation. This is non-negotiable for Android mesh relay functionality.

---

## 9. Security Model

### 9.1 Threat Model

| Threat                        | Mitigation                                             |
|-------------------------------|--------------------------------------------------------|
| Message eavesdropping         | NaCl box encryption, relay nodes see only ciphertext   |
| Identity spoofing             | Signature on every envelope, public key binding via QR |
| Replay attacks                | message_id dedup + timestamp validation (±5 min window)|
| Sybil attacks                 | Not mitigated in v1 (open network assumption)          |
| Traffic analysis (metadata)   | Partial: sender_id visible to relays in v1             |
| Malicious relay manipulation  | Signature verification prevents modification           |
| Flooding / DoS                | TTL limits amplification; rate-limit per peer          |

### 9.2 Trust Model

- **No central authority.** No CA, no server-side verification.
- **Trust on first scan.** When you scan someone's QR, you bind their display_name to their public key. That binding is local.
- **Display ID is always shown.** Even if a peer claims a display name you recognize, the display_id is always visible — preventing name-spoofing.
- **Future:** trust levels (verified via QR, seen-only, unknown)

### 9.3 What Is NOT Private in v1

- `sender_id` and `recipient_id` are in the clear in the envelope (needed for routing)
- Presence broadcasts (display_name, user_id) are unencrypted
- Traffic analysis by a local observer can infer who is talking to whom

Metadata privacy is a v2 concern (onion routing, anonymous relay identifiers).

---

## 10. Data Model

### 10.1 Core Entities

```
Identity {
    user_id:       String      // PK, SHA-256(pubkey)[0..<16]
    display_name:  String
    public_key:    Data
    is_self:       Bool
    first_seen:    Date
    last_seen:     Date
    verified:      Bool        // true if added via QR scan
}

Message {
    message_id:    UUID        // PK
    thread_id:     UUID
    sender_id:     String      // FK → Identity
    recipient_id:  String      // FK → Identity
    body:          String?
    type:          MessageType
    state:         DeliveryState
    created_at:    Date
    delivered_at:  Date?
    hop_count:     Int
}

Thread {
    thread_id:     UUID        // PK
    peer_id:       String      // FK → Identity
    last_message:  UUID?
    unread_count:  Int
    updated_at:    Date
}

RelayQueueEntry {
    entry_id:      UUID
    envelope_data: Data        // serialized MeshEnvelope
    created_at:    Date
    expires_at:    Date
    attempts:      Int
}
```

### 10.2 Serialization

All on-wire messages use **Protocol Buffers** (protobuf) for compact binary serialization.

- Apple: Swift protobuf (`apple/protobuf/`)
- Android: protobuf-lite

Message schema definitions live in `docs/proto/` and are the canonical wire format spec.

---

## 11. Future Capabilities

### 11.1 Direct Voice Calls

- Push-to-talk or continuous audio over a direct (single-hop) Multipeer/BLE session
- No relay — voice is not delay-tolerant
- Codec: Opus (~8–16 kbps) via AVFoundation
- Not planned until messaging is stable

### 11.2 Group Chats

- Broadcast messages (recipient_id = group_id)
- Group membership list distributed via signed group manifests
- Epidemic routing handles fanout naturally
- Risk: broadcast storms in dense mesh — requires careful TTL tuning

### 11.3 Network Visualization

- Graph view of the known mesh topology
- Each node: peer, edge: observed connection
- Useful for power users, mesh debugging
- Data: derived from routing table + received envelope hop paths

### 11.4 Cross-Platform Interop (Apple ↔ Android)

- Full mesh (not just BLE) requires a common Wi-Fi Direct transport
- iOS Wi-Fi Direct is not exposed in MultipeerConnectivity API — needs BonjourServiceBrowser workaround or NearbyConnections (Google)
- Likely a v3 investigation

### 11.5 Optional Backend

Scope-limited backend (no messages stored). Stack: **Go**.

Planned capabilities:
- Display name registration (internet-required name edits)
- Profile backup (encrypted keypair blob — user-controlled)
- Analytics (anonymized mesh health telemetry)
- Push notification bridge: "someone sent you a message, open Baylan"

Backend is empty in v1 — scaffolded at `backend/` for future use. No messages are ever stored server-side.

---

## Appendix A — Open Questions

| # | Question | Priority | Status |
|---|----------|----------|--------|
| 1 | Protobuf vs MessagePack for wire format? | High | Open |
| 2 | SwiftData vs GRDB for Apple storage? | High | Open |
| 3 | TCA vs plain MVVM for Apple architecture? | Medium | Open |
| 4 | BLE MTU strategy for messages > 512 bytes? | High | Open |
| 5 | How to handle large mesh partitions rejoining with large queues? | Medium | Open |
| 6 | Rate limiting strategy per peer (flood control)? | Medium | Open |
| 7 | iOS local notification strategy for background message receipt? | High | Open |

---

## Appendix B — Glossary

| Term | Definition |
|------|------------|
| Mesh | A network where every device can act as both client and relay |
| Epidemic routing | Flood-based routing where every node forwards to all peers |
| DTN | Delay-Tolerant Networking — designed for interrupted connectivity |
| Store-and-forward | Hold a message locally until a path to the destination appears |
| TTL | Time-to-live — decremented each hop; message dropped at 0 |
| MeshEnvelope | The outer packet that wraps an encrypted payload for mesh routing |
| display_id | First 8 hex chars of user_id — shown in UI as a fingerprint |
| Presence | A periodic broadcast announcing a device's existence on the mesh |
| NaCl box | Public-key authenticated encryption (X25519 + XSalsa20-Poly1305) |
| GATT | Generic Attribute Profile — BLE application layer protocol |
