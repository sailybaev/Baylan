# Apple Platform Architecture

> Covers: iOS + macOS
> Language: Swift 5.9+
> UI Framework: SwiftUI
> Package strategy: Swift Package Manager

---

## Overview

iOS and macOS share the vast majority of Baylan's logic. The core mesh engine, cryptographic identity, transport protocol, message persistence, and feature-level business logic are all **platform-agnostic Swift** that compiles identically on both targets.

Platform-specific code is limited to:
- App entry points and lifecycle management
- UI layout adaptations (sidebar on macOS, tab bar on iOS)
- Platform entitlement differences (background BLE on iOS, unrestricted on macOS)
- Some AVFoundation and NotificationCenter integrations that have minor API differences

This approach eliminates duplication and ensures that a fix or improvement to the mesh engine benefits both platforms simultaneously.

---

## Repository Layout

```
apple/
├── shared/                         ← Swift Package (BaylanCore)
│   ├── Package.swift
│   ├── Sources/
│   │   └── BaylanCore/
│   │       ├── Core/
│   │       │   ├── Transport/
│   │       │   │   ├── TransportProtocol.swift       ← interface
│   │       │   │   ├── MultipeerTransport.swift      ← iOS + macOS
│   │       │   │   └── BLETransport.swift            ← iOS (CoreBluetooth)
│   │       │   ├── Mesh/
│   │       │   │   ├── MeshRouterProtocol.swift      ← interface
│   │       │   │   ├── MeshRouter.swift              ← epidemic routing engine
│   │       │   │   ├── MeshEnvelope.swift            ← wire model
│   │       │   │   └── RelayQueue.swift              ← store-and-forward
│   │       │   ├── Crypto/
│   │       │   │   ├── CryptoEngine.swift            ← NaCl box, key generation
│   │       │   │   └── IdentityStore.swift           ← Keychain persistence
│   │       │   └── Storage/
│   │       │       ├── MessageRepositoryProtocol.swift
│   │       │       └── SwiftDataMessageRepository.swift
│   │       ├── Features/
│   │       │   ├── Chat/
│   │       │   │   ├── ChatViewModel.swift
│   │       │   │   └── MessageSender.swift
│   │       │   └── Discovery/
│   │       │       ├── DiscoveryViewModel.swift
│   │       │       └── PeerPresenceTracker.swift
│   │       ├── Models/
│   │       │   ├── Identity.swift
│   │       │   ├── Message.swift
│   │       │   ├── Thread.swift
│   │       │   └── Peer.swift
│   │       └── Services/
│   │           ├── IdentityService.swift             ← keypair + user_id
│   │           ├── MessageService.swift              ← send/receive orchestration
│   │           └── PeerService.swift                 ← peer lifecycle management
│   └── Tests/
│       └── BaylanCoreTests/
│
├── ios/                            ← Xcode target: BaylaniOS
│   ├── BaylanApp.swift             ← @main entry point
│   ├── AppDelegate.swift           ← background task registration
│   ├── Info.plist                  ← BLE entitlements, background modes
│   ├── Views/                      ← iOS-specific SwiftUI views
│   │   ├── RootTabView.swift
│   │   ├── DiscoveryView.swift
│   │   ├── ConversationsView.swift
│   │   ├── ChatView.swift
│   │   └── IdentityView.swift
│   └── Resources/
│
└── macos/                          ← Xcode target: BaylanMacOS
    ├── BaylanApp.swift             ← @main entry point
    ├── Info.plist
    ├── Views/                      ← macOS-specific SwiftUI views
    │   ├── RootSidebarView.swift   ← NavigationSplitView layout
    │   ├── DiscoveryView.swift
    │   ├── ConversationsView.swift
    │   ├── ChatView.swift
    │   └── IdentityView.swift
    └── Resources/
```

---

## What Goes Into `shared/`

The shared package (`BaylanCore`) contains everything that has no direct dependency on a specific Apple platform SDK. The rule is simple:

> If the code would compile and behave identically on both iOS and macOS, it belongs in `shared/`.

### Core/Transport/

**Purpose:** Abstract the physical communication layer.

`TransportProtocol` is the central interface. All mesh logic talks to this protocol — it never calls `MCSession` or `CBPeripheral` directly.

`MultipeerTransport` implements this protocol using `MultipeerConnectivity`. This framework is available on both iOS and macOS with identical APIs. This is the primary reason iOS and macOS can share transport code — Apple made the framework cross-platform.

`BLETransport` implements the protocol using `CoreBluetooth`. CoreBluetooth is also available on macOS (Bluetooth entitlement required), but in v1 this transport is primarily exercised on iOS for background operation. It lives in shared because the code is identical — only the entitlement and usage context differs.

Both transports publish peer events and received data via `AsyncStream` or `Combine` publishers, letting the mesh engine consume them uniformly.

### Core/Mesh/

**Purpose:** The routing brain of the application.

The mesh router holds no platform dependencies. It receives frames from any transport via the `TransportProtocol` interface, applies routing logic (TTL decrement, dedup check, forwarding decision), and emits inbound messages to the feature layer.

The relay queue (`RelayQueue`) is a persistent store (SwiftData or SQLite) that holds envelopes awaiting a forwarding opportunity. It runs entirely in Swift with no platform-specific code.

`MeshEnvelope` is a pure Swift struct (Codable or protobuf-backed). No UIKit, no AppKit, no Foundation framework beyond basic types.

### Core/Crypto/

**Purpose:** All cryptographic operations.

`CryptoKit` is fully available on both iOS and macOS with identical APIs. Key generation, signing, verification, and NaCl-equivalent box operations all share one implementation.

`IdentityStore` uses the `Security` framework (`Keychain`) to persist the private key. Keychain APIs are consistent across iOS and macOS — the same code works on both with minor attribute differences (`kSecAttrAccessibleAfterFirstUnlock` on iOS, `kSecAttrAccessibleAlways` for macOS daemon-like behavior).

### Core/Storage/

**Purpose:** Message and thread persistence.

`MessageRepositoryProtocol` abstracts the database. `SwiftDataMessageRepository` implements it using SwiftData (iOS 17+ / macOS 14+). SwiftData is platform-agnostic at the API level — one implementation serves both.

If SwiftData turns out to be insufficient (complex query requirements), a `GRDBMessageRepository` can be added without touching the rest of the system.

### Features/

**Purpose:** Business logic for discrete product features.

`ChatViewModel` and `DiscoveryViewModel` are `ObservableObject` (or `@Observable`) classes that hold view state and call into `Services/`. They contain no UIKit/AppKit imports. SwiftUI views on both platforms bind to the same ViewModels — platform-specific views only provide the visual layout, not the logic.

### Models/

**Purpose:** Shared data types used across all layers.

`Identity`, `Message`, `Thread`, `Peer` — plain Swift structs and enums. Codable conformance. No platform dependencies.

### Services/

**Purpose:** Orchestration layer between features and core.

`IdentityService` — creates or loads the local keypair on first launch, exposes the current user identity.

`MessageService` — coordinates sending (encrypt → wrap in envelope → hand to mesh router → persist) and receiving (receive from mesh → decrypt → persist → notify UI).

`PeerService` — tracks peer lifecycle (seen, connected, lost), manages the nearby peer list, triggers presence broadcasts.

These services are initialized once at app startup and injected via SwiftUI's `Environment` or a dependency container. Identical on iOS and macOS.

---

## What Is Platform-Specific

### iOS `ios/`

- `AppDelegate` registers background task identifiers (`BGProcessingTaskRequest`, `BGAppRefreshTaskRequest`)
- `Info.plist` declares `bluetooth-central` and `bluetooth-peripheral` background modes
- Tab-bar navigation (`RootTabView`) — appropriate for iPhone
- Potential use of `UNUserNotificationCenter` for local notifications when messages arrive while backgrounded
- Future: `CallKit` integration (voice calls)

### macOS `macos/`

- `NSApplicationDelegate` for menu bar and dock behavior
- Sidebar navigation (`NavigationSplitView` in two-column mode) — appropriate for desktop
- Window management (SwiftUI `WindowGroup`, `Settings` scene)
- No background restrictions — can keep Multipeer session alive indefinitely
- Future: menu bar status icon showing mesh connectivity

---

## Dependency Injection Strategy

Both iOS and macOS apps compose the same dependency graph at startup:

```swift
// Pseudocode — actual DI code will be written in Phase 1

let cryptoEngine = CryptoEngine()
let identityService = IdentityService(crypto: cryptoEngine)
let multipeerTransport = MultipeerTransport(identity: identityService.localIdentity)
let meshRouter = MeshRouter(transports: [multipeerTransport])
let messageRepository = SwiftDataMessageRepository()
let messageService = MessageService(router: meshRouter, repository: messageRepository, crypto: cryptoEngine)
let peerService = PeerService(router: meshRouter)
```

This graph is injected into SwiftUI views via `environmentObject` or a purpose-built `AppEnvironment` struct. ViewModels pull services from this environment.

---

## Why Not a Universal Target (Catalyst)?

Mac Catalyst (running the iOS app on macOS without modification) is explicitly rejected for Baylan:

1. **Multipeer session management** differs subtly — macOS can keep sessions alive where iOS cannot, and we want to exploit that difference.
2. **Navigation patterns** differ fundamentally — iPhone tab bar vs macOS sidebar.
3. **Window management** on macOS requires AppKit-level control that Catalyst abstracts poorly.
4. **Entitlements** differ — macOS Bluetooth entitlement is separate from iOS background modes.

Running a true native macOS app that shares a Swift Package with iOS gives the best result at acceptable cost.

---

## Package Dependencies (Planned)

| Package | Purpose | Shared/Platform |
|---------|---------|-----------------|
| `swift-protobuf` (Apple) | Wire format serialization | Shared |
| `swift-collections` (Apple) | OrderedDictionary for routing table | Shared |
| `GRDB.swift` (optional, v2) | Advanced SQLite queries | Shared |
| `swift-crypto` (Apple) | Crypto operations on older OS targets if needed | Shared |

No third-party UI dependencies. SwiftUI only.

---

## Testing Strategy

All shared core code (Transport, Mesh, Crypto, Storage, Services) is fully unit-testable without a device:

- Transports are protocol-based → mock transports in tests
- Mesh router logic tested with mock transport in-memory
- Crypto tested with known vectors
- ViewModels tested with mock services

Platform-specific views are tested with Xcode UI tests (XCUITest) on simulator.

The shared package has its own test target (`BaylanCoreTests`) that runs in CI without requiring a device or simulator.

---

## Build Configuration

```
Xcode Workspace: Baylan.xcworkspace
├── Package: apple/shared/Package.swift  (BaylanCore)
├── Project: apple/ios/BaylanIOS.xcodeproj
│   └── Target: BaylanIOS
│       └── Dependencies: BaylanCore
└── Project: apple/macos/BaylanMacOS.xcodeproj
    └── Target: BaylanMacOS
        └── Dependencies: BaylanCore
```

Both app targets import `BaylanCore` via local Swift Package reference. No CocoaPods, no Carthage.

---

## Minimum Deployment Targets

| Platform | Minimum | Rationale |
|----------|---------|-----------|
| iOS      | 17.0    | SwiftData, `Observable` macro, modern async/await |
| macOS    | 14.0    | Sonoma, same SwiftData/Observable availability |

These targets cover ~85% of active iOS devices (as of 2025) and the vast majority of macOS machines capable of running the app.
