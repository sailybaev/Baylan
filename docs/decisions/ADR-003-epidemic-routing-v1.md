# ADR-003: Epidemic Routing for v1 Mesh

**Status:** Accepted
**Date:** 2026-03-27

## Context

Baylan needs a mesh routing strategy that works in sparse, mobile, opportunistic networks. The strategy must handle:
- No pre-existing routing table
- Devices joining and leaving constantly
- No central coordinator

## Decision

Use **epidemic routing** (simple flood with TTL) for v1.

Every device that receives a message it did not originate and is not the recipient re-broadcasts it to all connected peers, subject to:
- TTL > 0 (decremented on each hop, default TTL = 7)
- message_id not in local seen-set (duplicate suppression)

## Consequences

- **Pro:** Maximally simple to implement correctly
- **Pro:** Highly robust in sparse networks — maximizes delivery probability
- **Pro:** No routing table maintenance, no coordination overhead
- **Con:** Message amplification in dense networks — mitigated by TTL limit
- **Con:** Not optimal for battery in dense deployments — acceptable for v1 scale

## Alternatives Considered

- **PRoPHET routing:** probabilistic, history-based — better performance in dense networks, significantly more complex; deferred to v2
- **Spray-and-wait:** limits copies per message — better battery, lower delivery rate in sparse networks; consider for v2
- **Source routing:** requires topology knowledge — not feasible in opportunistic mesh

## Review Trigger

Re-evaluate when the network has >20 peers in range simultaneously, or when battery complaints surface in testing.
