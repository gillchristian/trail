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

### TASK-034 — Framework/project split + extractable framework with pluggable delivery

**Source:** user request (2026-06-09), second half: "clear boundary between the framework and project-specific stuff; extract the framework for other projects with pluggable features (e.g. the branch/commit/PR part optional, with per-task liberty when granted)." Design reviewed by a 3-lens adversarial panel (fresh-agent bootstrap, reuse/drift, minimalism); this plan is the synthesis.
**Branch:** `docs/task-034-framework-extraction`
**Acceptance criteria:**
- [x] `knowledge/framework/` holds the complete project-agnostic system, flat, 7 files: `README.md` (areas + abstract loop + version/upstream stamp), `SETUP.md` (adoption guide with installed-guard and inline skeletons — no templates tree), `principles.md`, `verification.md`, `when-stuck.md`, `working-style.md`, `delivery.md`. Moves use `git mv` so history follows.
- [x] Instance-free guard passes: `grep -riE '\btrail\b|\belm\b|batman|gillchristian|coros|samples/' knowledge/framework/` returns nothing (`context7` allowed only inside an "e.g." clause; word boundaries because "trailing"/"trailers" are unavoidable English).
- [x] `knowledge/README.md` becomes the project manifest: greppable `delivery: pr` declaration with the operative consequence inline, project rules (user-only attribution, Batman root commit, squash-only), the instantiated 8-step loop for trail, and the layout map.
- [x] `framework/delivery.md`: shared commit conventions stated once; attribution hook at the commit and PR steps ("apply the manifest's identity rules — re-read that section now"); framework default = no agent attribution when a manifest is silent; three profiles (pr / commits / none) each with its own delivery record format and end-of-session sweep variant; undeclared mode = `none` (fail-safe); `none` profile has an explicit git command policy (read-only allowed; never commit/push/checkout/reset/stash/clean; file restoration per-file and only for files this session changed).
- [x] Per-task override contract in `delivery.md`: valid only when recorded in the CURRENT.md task entry before acting (`**Delivery override:** …`), scope = that task only, expires when the task leaves CURRENT.md, and push/force/protected-branch/PR are never implied — each must be individually named by the user.
- [x] `framework/verification.md` keeps a numbered gate 7: "Delivered per the project's delivery mode — apply the enabled profile's gates in `delivery.md`"; the end-of-session sweep's `git status` line is delegated to the profiles.
- [x] De-git sweep of core docs: principles #4 ("checkpoint"; "work I didn't create this session"), working-style cadence bullet, when-stuck "revert" row (restore only files this session changed, per profile policy), loop steps that mentioned PR/merge-sha/sync-master moved into the pr profile.
- [x] Live references repointed (`CLAUDE.md`, `reference/local-ci.md` incl. the now-wrong gate-8/step-4 numbers, `reference/pace-prediction-roadmap.md:318`); historical journal/DONE/ADR references untouched; tombstone redirect at `knowledge/philosophy/README.md`.
- [x] `CLAUDE.md` keeps the inlined non-negotiables (incl. trail's branch/PR rule and attribution) and lists the explicit reading chain: manifest → framework README → enabled profile.
- [x] Verified by dry-run, not inspection: (a) a fresh-eyes agent walks the trail chain and states the loop + delivery rules correctly; (b) a second agent follows `SETUP.md` literally in a temp dir as a delivery-none work project and the result contains no git-instruction leakage; findings fixed before merge.
- [x] Local CI green (docs-only, run anyway).
**Notes:** Panel calls adopted: one `delivery.md` with profiles over 4 module files (delivery-commits has zero standing usage — it doubles as the override target; framework's own three-usages rule); no `templates/` tree (live files self-document their formats per TASK-033 — a second never-exercised copy is where staleness would breed); flat `framework/` (7 files don't need subdirs); 2-line version/upstream stamp instead of a CHANGELOG; one tombstone file (cheap insurance against a future agent "recreating" pr-workflow.md and forking the framework in-repo). Publishing `framework/` as its own repo stays a user step — SETUP.md makes any copy self-sufficient.
