# 0003 — Validate OAuth state before exchanging the Strava code

**Date:** 2026-05-15
**Status:** accepted
**Implemented by:** PR #4 (`a68896e`), TASK-003. See `(*AuthHandler).Callback` in `server/handlers/auth.go`.

## Context

`/auth/callback` receives both an authorisation `code` (from Strava) and a `state` parameter (from cadence, round-tripped via Strava). The handler has to do three things: decode `state`, validate the nonce against the in-memory store, and exchange the `code` with Strava for tokens. The order matters. The spec didn't dictate it explicitly, so the choice gets pinned here.

## Decision

State validation runs **before** the Strava code exchange. Concretely:

1. Parse `code` and `state` from the query string (400 if either is missing).
2. `decodeOAuthState(state)` → 400 on malformed.
3. `OAuthState.Take(nonce)` → 400 on unknown / replayed / expired.
4. Check that the encoded `origin` matches the stored `origin` → 400 on mismatch.
5. Check `IsAllowedOrigin(origin)` → 400 on unknown origin.
6. Only now: `Strava.ExchangeCodeForTokens(code)`.
7. Persist `(tokens, sessionToken, origin)`; upsert athlete name; redirect.

## Alternatives considered

- **Exchange first, then validate.** Marginally simpler error paths (Strava errors and state errors share less code). Rejected on two grounds:
  - **Security:** a replayed `state` (which we'll 4xx anyway) would still consume a Strava `code`. If the original flow's user hadn't completed their callback yet, an attacker could race to invalidate the code.
  - **Efficiency:** every malformed callback would burn a Strava API call (1 of our 100 / 15 min quota).
- **Validate state, exchange, then re-check origin/match.** No upside over a single pre-exchange validation block; just adds branches.

## Consequences

- **Makes easy:** all 400 responses for callback issues fail fast, without any external dependency. The Strava exchange only runs when we've already committed to honour the result.
- **Makes harder:** if Strava's exchange ever fails for transient reasons, the consumed nonce is already gone. The user has to click "Connect Strava" again. The acceptance is OK because OAuth codes are single-use anyway — a transient Strava error would have invalidated the code regardless.
- **Revisit if:** we add intentional retry-on-Strava-503 behaviour. Currently we treat any non-200 from `/oauth/token` as a 500 to the caller, which is fine for a one-user app.
