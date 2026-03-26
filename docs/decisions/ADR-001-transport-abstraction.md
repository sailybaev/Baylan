# ADR-001: Transport Abstraction Layer

**Status:** Accepted
**Date:** 2026-03-27

## Context

Baylan must support multiple physical transports (MultipeerConnectivity, BLE, Wi-Fi Direct) and must remain functional as new transports are added or existing ones are deprecated. The mesh routing engine should not be coupled to any specific radio technology.

## Decision

All transports conform to a single `TransportProtocol`. The mesh engine, message service, and all feature code interact only with this protocol. Concrete transport implementations are injected at app startup.

## Consequences

- **Pro:** Transport implementations are independently testable with mock objects
- **Pro:** Adding a new transport (e.g., Wi-Fi Direct on iOS if Apple ever exposes it) requires only a new conforming type, no changes to routing logic
- **Pro:** Cross-platform parity is enforced by protocol — Android must implement the same conceptual interface
- **Con:** Lowest-common-denominator API may not expose advanced capabilities of specific transports (acceptable for v1)

## Alternatives Considered

- Direct MCSession usage throughout: rejected — untestable, couples business logic to radio API
- Separate routing logic per transport: rejected — duplication, inconsistent behavior
