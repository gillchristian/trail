# Moved (2026-06-09, TASK-034)

The philosophy docs moved into the extracted framework:

- `principles.md` → `../framework/principles.md`
- `verification.md` → `../framework/verification.md`
- `when-stuck.md` → `../framework/when-stuck.md`
- `working-style.md` → `../framework/working-style.md`
- `pr-workflow.md` → `../framework/delivery.md` (profile `pr`); the
  trail-specific parts (author identity, Batman root commit, squash-only)
  live in the project manifest, `../README.md`.

References to `knowledge/philosophy/...` in the journal, `DONE.md`, and old
ADRs are historical and intentionally unchanged (append-only) — they mean the
files above. **Do not recreate documents in this directory.**
