# The knowledge framework

**Framework v1 (2026-06-09).** A file-based working system for autonomous
agent sessions: pick one task, verify it honestly, deliver it per the
project's rules, write down what happened — so a future session with zero
memory can pick up exactly where this one stopped.

This directory is project-agnostic and travels as a unit. The copy you are
reading may be a downstream copy; the **project manifest** (`../README.md`)
records which project this is, the enabled delivery mode, the project's own
rules, and where the upstream copy lives. If you landed here first, read the
manifest before acting on anything below.

New project? `SETUP.md` is the adoption guide. Already-installed project?
Never run SETUP.md's steps — and never edit the files in this directory to
say project-specific things; project specifics belong in the manifest.

## The pieces

- **This directory** — the stable "how I work": `principles.md` (values, in
  priority order), `verification.md` (when a task counts as done),
  `when-stuck.md` (what to do instead of asking the user), `working-style.md`
  (cadence, scope discipline, anti-patterns), `delivery.md` (the pluggable
  part: how verified work leaves the tree — profiles `pr` / `commits` /
  `none`, per-task overrides).
- **`../planning/`** — the active plan: `CURRENT.md` (exactly one task, with
  acceptance criteria), `BACKLOG.md` (ordered queue), `DONE.md` (archive).
- **`../progress/`** — `journal.md` (append-only log; future-me's memory),
  `blockers.md` (the things only the user can resolve).
- **`../decisions/`** — one ADR per non-trivial decision, plus `INDEX.md`
  (which also holds the template and the "what deserves an ADR" bar).
- **`../reference/`** — project facts: the brief (product intent — it wins
  conflicts with planning), glossary, local CI commands, specs.
- **`../whiteboard/`** — discussions in flight that haven't earned an ADR or
  a backlog task; conventions and index in its README.

## The loop

Every working session follows the same shape. Steps marked § are defined by
the enabled delivery profile (`delivery.md`) — the manifest usually shows
them instantiated for the project.

1. **Orient** — Read the manifest (`../README.md`), then `../planning/CURRENT.md`
   for the active task. If empty, refill from `../planning/BACKLOG.md`.
2. **Plan** — Write the acceptance criteria into `CURRENT.md` before touching code.
3. **Stage §** — Prepare per the delivery profile (`pr`: branch off the
   default branch; `commits` / `none`: nothing to do).
4. **Execute** — Implement, checkpointing per the profile as I go.
5. **Verify** — Run the gates in `verification.md`, including gate 7 (the
   profile's delivery gates) and the project's local CI commands. If any
   fail, fix before moving on.
6. **Deliver §** — The profile's delivery steps (`pr`: open and merge the PR;
   `commits`: final commit; `none`: verified tree + hand-off record).
7. **Log** — Append a journal entry: timestamp, what was done, what was
   verified (with quoted output), the profile's delivery record, what's next.
8. **Advance** — Move the task to `DONE.md`, do the profile's post-delivery
   sync if it defines one (`pr`: sync the default branch; `commits` / `none`:
   nothing), pull the next task into `CURRENT.md`.

If I ever feel stuck or unsure, the answer is in `when-stuck.md` — not in
asking the user.

## Changing the framework

Framework files stay instance-free: no project names, no stack names, no
user identities, no repo-specific rituals — those live in the manifest.
Downstream copies don't edit these files in place (a local edit forks the
framework silently); improvements go to the upstream copy recorded in the
manifest, then re-copy the directory wholesale and bump the version line
above.
