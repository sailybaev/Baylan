# Baylan

> *Baylan (байлан)* — "connection" in Kazakh. A network that needs no network.

**Baylan** is an open-source, offline-first peer-to-peer mesh messaging application for iOS, macOS, and Android. Devices communicate directly using Bluetooth and Wi-Fi — no internet, no servers, no infrastructure required.

---

## Platforms

| Platform | Status     | Transport                          |
|----------|------------|------------------------------------|
| iOS      | In dev     | Multipeer Connectivity, BLE        |
| macOS    | In dev     | Multipeer Connectivity, BLE        |
| Android  | Planned    | BLE, Wi-Fi Direct                  |
| Backend  | Planned    | Analytics + optional profile sync  |

---

## Features

- **Zero-infrastructure messaging** — works on a plane, underground, in a stadium
- **Mesh relay** — messages hop across nearby devices to reach destinations out of direct range
- **Store-and-forward** — messages are carried and delivered when a path opens
- **Delay-tolerant delivery** — handles unreliable, intermittent connections gracefully
- **Cryptographic identity** — every user is identified by a public/private keypair, not a phone number or account
- **QR-based contact exchange** — share your identity by showing a QR code
- **Nearby peer discovery** — see who is around you in real time
- **Delivery states** — know if your message is sending, relayed, or delivered
- **Cross-platform** — iOS and macOS share the same core logic

---

## Tech Stack

| Layer        | Apple (iOS/macOS)             | Android                |
|--------------|-------------------------------|------------------------|
| Language     | Swift 5.9+                    | Kotlin                 |
| UI           | SwiftUI                       | Jetpack Compose        |
| Transport    | MultipeerConnectivity, CoreBluetooth | BluetoothLE, Wi-Fi Direct |
| Crypto       | CryptoKit (Curve25519)        | Tink / BouncyCastle    |
| Storage      | SwiftData / SQLite            | Room                   |
| Arch pattern | Protocol-oriented, TCA-inspired | Clean Architecture + MVI |

---

## Architecture Overview

Baylan is built around a **transport abstraction layer**: the mesh engine does not know whether data is moving over Bluetooth, Wi-Fi, or any other channel. Any transport can be plugged in by conforming to a single protocol.

```
┌─────────────────────────────────────────────┐
│                  UI Layer                   │
│         (SwiftUI / Jetpack Compose)         │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│              Feature Layer                  │
│         Chat · Discovery · Identity         │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│              Services Layer                 │
│    MessageService · PeerService · IdentityService │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│               Core Layer                    │
│  MeshRouter · MessageQueue · CryptoEngine   │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│           Transport Abstraction             │
│    TransportProtocol (send · receive · discover) │
└──────┬─────────────────────┬────────────────┘
       │                     │
┌──────▼──────┐       ┌──────▼──────┐
│  Multipeer  │       │     BLE     │
│Connectivity │       │  Transport  │
└─────────────┘       └─────────────┘
```

### Mesh Routing

Each message carries a TTL (time-to-live) and hop count. When a device receives a message not addressed to itself, it checks its routing table and rebroadcasts if the TTL allows. Duplicate suppression via message ID prevents loops. Messages are persisted locally and forwarded when a path to the destination appears (store-and-forward).

---

## Screens Overview

- **Discovery** — radar-like view of nearby peers
- **Conversations** — list of active chats (Telegram-style)
- **Chat** — message thread with delivery state indicators
- **Identity** — your QR code + public key display
- **Settings** — display name, transport preferences

---

## Roadmap

### Phase 1 — Foundation
- [x] Mono-repo scaffold
- [x] Project documentation
- [ ] Core protocols and interfaces
- [ ] Cryptographic identity (CryptoKit, Curve25519)
- [ ] Multipeer transport (iOS + macOS)
- [ ] Basic SwiftUI shell (peer list, identity screen)

### Phase 2 — Mesh Core
- [ ] Multi-hop routing engine
- [ ] Store-and-forward queue
- [ ] TTL and duplicate suppression
- [ ] BLE fallback transport (iOS)
- [ ] Android BLE transport

### Phase 3 — Messaging
- [ ] Full chat UI
- [ ] Message persistence (SwiftData / Room)
- [ ] Delivery state tracking
- [ ] Contact exchange via QR

### Phase 4 — Hardening
- [ ] Background operation (iOS limits)
- [ ] Battery optimization
- [ ] End-to-end encryption (double-ratchet or NaCl box)
- [ ] Network visualization screen

### Phase 5 — Future
- [ ] Direct voice calls (no relay)
- [ ] Group chats
- [ ] Optional backend (analytics, profile backup)

---

## Vision

Baylan is non-profit and open source. The mission is to give people a communication tool that works when everything else fails — in remote areas, during disasters, on campuses without signal, in crowds. No account required, no server to take down, no company to trust.

Communication is a right. Infrastructure is a privilege. Baylan removes the dependency.

---

## Repository Structure

```
baylan/
├── apple/
│   ├── shared/          # Swift Package — shared across iOS + macOS
│   │   ├── Core/        # Transport, Mesh, Crypto, Storage protocols + implementations
│   │   ├── Features/    # Chat, Discovery feature logic
│   │   ├── Models/      # Shared data models
│   │   └── Services/    # High-level business services
│   ├── ios/             # iOS app target (SwiftUI, platform entitlements)
│   └── macos/           # macOS app target (SwiftUI, platform entitlements)
├── android/             # Kotlin Android app
├── backend/             # Optional Node.js/Go backend
└── docs/                # Architecture docs, ADRs, design notes
```

---

## License

MIT — see [LICENSE](LICENSE)

---

## Contributing

This project is in early bootstrap phase. Architecture decisions are being finalized. See [`project.md`](project.md) for the full technical specification and [`docs/`](docs/) for architecture records.





A       Q    Q    Q    Q     B
key                         key
Akey(soob) -> q -> q -> q -> q -> Bkey(Akey(soob)) = soob

QR
zayavka