# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Entry template

```markdown
### TASK-NNN — <title>

**Source:** BACKLOG / parking lot / user request
**Branch:** <kind>/task-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, anything decided while planning.
```

### TASK-068 — Translate: modals + toasts

**Source:** BACKLOG (i18n epic). **Deps:** TASK-061 (done, PR #134). Person labels reuse `Translations.you` (TASK-067).
**Branch:** `feat/task-068-modal-translations`
**Acceptance criteria:**
- [ ] Delete-confirm modal (`viewDeleteModal`/`viewModal`): "Delete race?" + body (interpolated race name) + Delete/Cancel.
- [ ] Identity flows (`viewIdentityModals`): name prompt ("What's your name?" + the two contextual subtitles + save/export button), ownership choice ("Whose plan is this?" + "I'm X" / "Someone else's plan" + descriptions), device-link ("Link this device?" + explanation). Interpolated names.
- [ ] Merge-review modal (`viewMergeReview`): "N change(s) overlap…", "M changes from X added automatically" (compound plural), per-card context labels + two person-named options (You / `<name>`), "N of M chosen", "Keep my version"/"Apply changes", the discard-confirm copy. **Person-named throughout** (WI-5) — reuse `you`; never "coach".
- [ ] Storage-error toast: "Storage error".
- [ ] New Spanish terms in glossary; no `_ ->`; CI green. **Manual browser check:** delete, an identity prompt, and a merge review read Spanish.

**Notes:** Highest interpolation/plural density. `viewModal` is a generic shell (title/body/confirm/cancel passed in) — localize at call sites. The merge review person tints/names come from the WI-5 directory (already person-named — just localize the chrome/connectives). Compound plural ("M change was/were added") needs the one/other verb agreement (English) — Spanish "se agregó/agregaron". Spec WI-4 surface task. On close, pull TASK-069 (QA sweep + exhaustiveness check + `<html lang>` + `section.label`).

---

**Arc state (2026-06-17):** **coach-collaboration arc COMPLETE.** WI-1 (TASK-047),
WI-2 (048), aid-id (049), WI-3 engine (050), WI-4 feed (051), backfill (053),
WI-5 identity (054), home owner view (055), and WI-3·UI merge integration + review
modal (056) all shipped. ADRs 0009–0013. The whole flow — share a `.trail`,
annotate it, import it back, three-way-merge with a person-named review surface —
is live and user-verified in-browser.

**Recommended in-browser checks (standing, pre-arc):** TASK-040 IDB round-trip; TASK-042 print preview; TASK-045 section table/card with a linked actual.

---

## Standing reminders (not active tasks)

- **i18n epic is the active arc (started 2026-06-18).** English + Spanish,
  type-driven, no library — TASK-058–069, sequenced machinery (058→060) →
  translation sweep (061→069). Spec `reference/i18n-spec.md` (read its *Resolved
  decisions* callout), ADR-0014, glossary `reference/i18n-glossary.md`. **Units
  (metric/imperial) are descoped** to TASK-070 (parking lot) — language only.
  Translation PRs are large-surface and user-reviewed; keep terms consistent via
  the glossary.
- **Calibration is paused (user, 2026-06-15).** The two core continuous rates
  shipped (TASK-043 vmh, TASK-044 flat pace); the harder roadmap §7 fits
  (descent / fatigue / Riegel / sustainable-HR / decoupling) stay queued —
  promote only on a fresh go-ahead.
- **Three manual checks recommended** (headless env can't do them): browser
  round-trip after the TASK-040 IDB migration; print-preview of the TASK-042
  table; section table/card with a **linked actual** for TASK-045 (clock Time,
  Actual − Time = Δ, monotonic Cum ending at total clock).
- **Coach-collab arc: COMPLETE** (2026-06-17). All work items shipped + verified
  (TASK-046–051, 053–056; ADRs 0009–0013). Nothing outstanding in the arc.
- **Vercel deploy (in progress, 2026-06-18).** The build is fixed (TASK-057 —
  `elm` is now a dev dep; `spawn elm ENOENT` gone). **Remaining is config, not
  code:** (1) set `VITE_BACKEND_URL` in Vercel to the cadence URL — it's inlined
  at *build* time, so set it before building; (2) on **cadence's** side add the
  Vercel origin to CORS (`FRONTEND_URLS`) and set `FRONTEND_URL_TRAIL` to the
  Vercel URL (the OAuth callback redirects there). No `vercel.json` needed
  (hash router → static `dist/`). Optional follow-up: pin `engines.node: "22.x"`
  (Vercel built on Node 24; dev/`.nvmrc` pin v22). The Strava developer-app
  callback domain is cadence's and does **not** change.
