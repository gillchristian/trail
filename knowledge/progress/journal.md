# Journal

Append-only. Newest at the bottom. Each entry is a snapshot for future-me with no memory of this session.

## Entry format

```
---
## YYYY-MM-DD HH:MM — <short heading>

**Task:** TASK-NNN (or "scaffolding" / "exploration" / "blocker triage")
**What I did:** 1–3 sentences.
**What I verified:** which gates I ran, including any literal command output worth preserving.
**What changed in the repo:** files touched, key commits (sha + subject).
**What I learned:** anything that would surprise future-me. Non-obvious only.
**Next:** the very next thing I will do when I resume.
```

## Entries

---
## 2026-05-15 14:10 — knowledge/ scaffolding

**Task:** scaffolding (no TASK-NNN; this is the meta-system itself).
**What I did:** Set up `knowledge/` with philosophy, planning, progress, decisions, and reference subdirectories — porting the working system from the trail project (`~/dev/trail/knowledge/`). Adapted philosophy docs for Go/chi/SQLite specifics; seeded `planning/BACKLOG.md` with TASK-001 through TASK-005, each pointing at the relevant section of trail's `cadence-backend-spec.md`. Created `reference/project-brief.md` (about cadence) and `reference/trail-integration.md` (pointer + hand-off context). Updated `CLAUDE.md` to point at `knowledge/README.md` as the entry point.
**What I verified:** No code changed in `server/` or `client/`. All knowledge files render as expected. Pointers to the trail spec use absolute paths (`/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md`).
**What changed in the repo:** New `knowledge/` tree (~14 files). `CLAUDE.md` gained a one-line pointer at the top.
**What I learned:**
- Cadence has no `_test.go` files in `server/` yet. The verification gates lean on `go build`, `go vet`, manual `curl` smoke, and exercising the existing cadence frontend.
- The git config is already correct for the no-Claude-attribution rule; nothing to configure.
- Existing commit messages in master are loose (one-line subjects, no bodies). The new workflow tightens this from now on; don't backfill old commits.
**Next:** Pull TASK-001 (split `tokens` into `tokens` + `sessions`) into `CURRENT.md` and start the first PR.
