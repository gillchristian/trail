# 0010 — Course identity for `.trail` sharing: stable shareId + canonical course hash, hard-block on mismatch

**Date:** 2026-06-15
**Status:** accepted

## Context

WI-1 (TASK-047) of the coach-collaboration arc (ADR-0009) needs two guarantees
before any merge can be trusted: a returned `.trail` can be matched back to the
race it came from, and a plan built on a *different course* is refused (the
"freeze the course, merge the plan" axiom). This is the resolution of the spec's
**Q1**, taken with the user on 2026-06-15. Two facts about the existing code
shaped it: `Race.id` is the IDB key and is **regenerated on every import**
(`Main.elm`, so the same file can be imported twice as two rows), and trail is
pure Elm with no crypto primitive and a Layer-0 (offline, no-port-if-avoidable)
ethos.

## Decision

1. **Stable `shareId`, distinct from `id`.** A new `Race.shareId` is minted once
   (JS-side via `crypto.randomUUID()`, like `id`) and **preserved across the
   export/import round-trip** — only `id` is regenerated on import. `shareId` is
   the cross-round-trip identity; `id` stays the local row key.

2. **`courseHash` over the canonical decoded track, not raw bytes.** The hash is
   computed from the parsed track points with lat/lon rounded to 5 decimals
   (≈1.1 m) and elevation to the nearest metre. Two exports of the same course
   match even when the GPX differs cosmetically (whitespace, decimal precision,
   reordered metadata, a re-export). *(User choice, Q1: canonical over raw.)*

3. **Pure-Elm, non-cryptographic hash.** A deterministic double polynomial
   rolling hash (two independent moduli → ~60-bit fingerprint), each fold staying
   within Elm's safe-integer range so no `Math.imul`-style 32-bit emulation or JS
   crypto port is needed. The threat model is "did these two plans start from the
   same course?", not an adversary.

4. **Hard-block on `courseHash` mismatch.** When an incoming file's `shareId`
   matches a race but its `courseHash` differs, the import is refused with a
   clear message — never a silent warn-and-allow. *(User choice, Q1.)* The guard
   is the pure `TrailSync.classify : … -> … -> ImportVerdict`
   (`Mergeable | DifferentRace | DifferentCourse`); an empty `shareId` never
   matches.

`.trail` format bumps to **v2** (carries the two fields); the version gate widens
to accept `{1, 2}`. v1 files decode with both fields defaulting to `""` and are
stamped on import (`shareId` minted JS-side, `courseHash` computed from the
embedded GPX).

## Alternatives considered

- **Reuse `Race.id` as the shared identity.** Rejected — it is deliberately
  regenerated on import, so it can't survive the round-trip that links a coach's
  returned file to its race.
- **Hash the raw GPX bytes.** Rejected (Q1) — trivial but brittle: any cosmetic
  re-save changes the hash and blocks a legitimate same-course merge.
- **Cryptographic hash via a JS `SubtleCrypto` port.** Rejected — it would
  thread an async port through what is otherwise pure, for no benefit: the threat
  model isn't adversarial, so a non-crypto fingerprint is sufficient and keeps
  the feature pure/offline.
- **Warn-and-allow on course mismatch.** Rejected (Q1) — it lets two plans
  addressed to different geometry merge, silently making aid distances / per-km
  plans meaningless. Hard-block upholds the freeze-the-course axiom; with
  canonical hashing, benign diffs don't trigger it anyway.

## Consequences

**Easy:** match a returned file to its race; refuse a wrong-course import before
any merge runs; all of it pure and offline; the guard is a typed value WI-3
(TASK-050) consumes, not a runtime failure path.

**Hard / to revisit:** preserving `shareId` on import means re-importing *your
own* file as a new race produces two local rows sharing a `shareId` — benign for
WI-1, but WI-3's "update-from-file" path is the intended route and must handle
the ambiguity (logged for TASK-050). A non-cryptographic hash is not
collision-proof against a crafted course — acceptable under the threat model; if
that ever changes, swap in a crypto hash (the `courseHash` field and guard stay
the same shape).
