# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### TASK-032 — "Crew access" aid-station service (personal-crew assistance)

**Why.** Ultras distinguish stations where a runner's *own crew* may meet and
assist them from race-only aid. It's a distinct planning signal (crew
logistics) and independent of drop-bag / food / medical, so it's a 7th
`Service` category, not an alias. Asked for by the user 2026-06-05.

**Scope (locked):** 7th `Service` variant. Label **"Crew access"**, icon 🤝,
key `crew`. CSV import tolerant of `crew` / `crew access` / `assistance` /
`assistance permitted` / `personal assistance` / `support crew`. Same flat-tag
model as the others — settable via the manual form chips (free, via
`allServices`) and CSV; shown wherever services render.

**Acceptance criteria:**

1. [ ] `Types.Service` gains `Crew`; `allServices`, `serviceToString`
   (`crew`), `serviceFromString`, `serviceLabel` ("Crew access"), `serviceIcon`
   (🤝) all updated (compiler-enforced).
2. [ ] `AidCsv.serviceFromToken` maps the crew/assistance tokens → `Crew`;
   unknown still warns.
3. [ ] `leaflet-element.js` `SERVICE_EMOJI`/`SERVICE_LABEL` include `crew`
   (the spot the compiler can't see).
4. [ ] Verification: `elm make` clean; `npm run build` clean; smoke gains a
   crew-token check and stays green.
5. [ ] No Claude attribution. PR opened + merged; docs PR closes the task
   (CURRENT cleared, DONE, journal).

**Branch:** `feat/task-032-crew-service`
