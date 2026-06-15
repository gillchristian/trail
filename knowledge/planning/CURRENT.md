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

## Active

### TASK-042 — Print-friendly export of the planning table

**Source:** BACKLOG parking lot, promoted 2026-06-15 (batch task 4 of 5; 039/040/041
shipped — PRs #72/#74/#76).
**Branch:** `feat/task-042-print-plan`

**Goal.** Let the user print the plan table (km mode + section mode) cleanly on
paper — legible black-on-white, the app's dark chrome stripped, rows not split
across page breaks, the table header repeated per page.

**Approach.** The plan page (`viewPlanTable`, `Main.elm:4082`) stacks chrome
above the table: `viewPlanCrumb`, `viewPlanHeader`, `viewPlanTargetPanel`,
`viewPredictorStrip`, `viewActualRunStrip`, `viewPlanTabs` (+ Download-CSV
button ~4700), then `viewKmTable`/`viewSectionTable`. Outside it sit the sticky
`viewHeader` (2056) and `viewFooter`. Plan:
- Add a **Print** button next to Download CSV → new port `printPage : () -> Cmd msg`
  → `window.print()` in `main.js` (Elm can't call it directly).
- Mark chrome `print:hidden` (Tailwind v4 `print:` variant is available —
  `@import "tailwindcss"`): app header, footer, crumb, target panel, predictor
  strip, actual strip, tabs, the CSV/Print buttons.
- Keep `viewPlanHeader` (race name + stats) + the table visible. Wrap the
  printable part in a `.plan-print` container and add an `@media print` block in
  `src/styles/app.css`: white background, black text, real borders on `th`/`td`,
  `thead { display: table-header-group }` (repeat header per page),
  `tr { break-inside: avoid }`, and reset the dark `bg-*`/`text-*` cell colors
  to readable print values (scoped to `.plan-print` so it doesn't touch screen).

**Acceptance criteria:**
- [ ] A **Print** control on the plan page triggers the browser print dialog
  (port → `window.print()`); works in both km and section modes.
- [ ] `@media print` rules exist in the built CSS and: hide app chrome, render
  the table black-on-white with visible cell borders, repeat the header row per
  page, and avoid splitting a row across pages.
- [ ] On-screen appearance is unchanged (print rules are print-scoped /
  `print:` variants only).
- [ ] Build emits the print CSS; the `printPage` port appears in the compiled
  bundle (so the JS `subscribe` binds); all five local-CI gates green.
- [ ] **Visual check:** confirm the print preview in a browser is clean — *this
  is the real acceptance and needs a human* (the env can't render a print
  preview headlessly, same limitation as TASK-040's round-trip). Implement the
  conventional, low-risk pattern; flag the visual review in the PR.

**Notes.** No new route — print the existing page via `@media print`, the
robust/standard approach. Section-mode + km-mode share the page, so one print
path covers both. Keep it conservative; this is a stylesheet, not a redesign.
