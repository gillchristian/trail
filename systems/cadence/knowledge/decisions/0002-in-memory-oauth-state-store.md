# 0002 — In-memory OAuth state store with active sweep

**Date:** 2026-05-15
**Status:** accepted
**Implemented by:** PR #4 (`a68896e`), TASK-003. See `server/handlers/oauth_state.go`.

## Context

The trail spec (§4.2) required an OAuth `state` parameter that binds the `/auth/strava` flow to its `/auth/callback`, both for CSRF resistance and to encode which frontend (`trail` / `cadence`) the flow originated from. The spec named two viable backings for the per-flow nonce store: an in-memory `sync.Map` with a 5-min TTL, or a tiny `oauth_states` SQLite table. The spec recommended in-memory; the recommendation needed a written rationale because future-me will wonder.

## Decision

In-memory `sync.Map` of `nonce → {origin, expiresAt}`, 5-min TTL, with a 1-min background sweep goroutine that evicts expired entries (`oauthSweepEvery = 1 * time.Minute`, `oauthStateTTL = 5 * time.Minute`). `Take(nonce)` is one-shot via `LoadAndDelete` — a replayed nonce returns `ErrOAuthStateUnknown`. The store also accepts an injectable `now func() time.Time` so expiry can be tested without real sleeps.

## Alternatives considered

- **DB-backed `oauth_states` table.** Survives a restart. But (a) cadence is single-machine and rarely restarts; (b) the failure mode of "restart during an in-flight OAuth round-trip" is a user clicking "Connect Strava" once more — a non-event; (c) more code (migration + store + cleanup query). Rejected per "boring option" + spec recommendation.
- **Passive-only TTL (no sweep).** Simpler, but the spec's wording said "5-min TTL eviction", which read to me as active cleanup. The sweep goroutine is ~10 LoC and prevents an unbounded map under abuse. Kept.
- **JWT-style signed state, no server-side store.** Eliminates the map entirely. But you lose one-shot-ness (a replayed signed token would still validate) — explicitly the property the spec wanted. Rejected.

## Consequences

- **Makes easy:** new origins (add a constant + an entry in `IsAllowedOrigin`); local testing (no DB seeding needed); fast Take (no DB roundtrip).
- **Makes harder:** if cadence ever scales to multiple instances, the in-memory store would not share state across replicas — would have to migrate to a shared datastore. This is currently outside the single-machine constraint.
- **Revisit if:** the single-machine constraint is ever lifted (it shouldn't be, given the SQLite-on-Fly-volume shape).
