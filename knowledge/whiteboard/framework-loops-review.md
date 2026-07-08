# Framework v3 vs. the loops playbook — improvement review

**Status:** open — **tiers 1–3 adopted 2026-07-08** (MONO-006 framework v4 · MONO-007
framework v5 · MONO-008 ritual scripts · MONO-009 verify skills; delivery records in
trail's `DONE.md`); Tier 4 (#8–#16) parked here, appetite-gated; TASK-072 (trail
browser-drive) still parked

**Context.** The Claude Code team published "Getting started with loops" (2026-07-06):
a taxonomy of agent loops — turn-based / goal-based / time-based / proactive — classified
by trigger, stop criteria, and primitive, plus guidance on keeping quality up (executable
verification skills, second-agent review, encode fixes into the system) and token usage
down (scripts for deterministic work, right-sized models, pilot runs). This document
reviews framework v3 and its instances against that playbook. Method: six parallel
analysts (one per article dimension), findings consolidated, then each finding
adversarially verified through two lenses — factual accuracy against the real files, and
fit with the framework's own philosophy — plus a completeness pass. Every recommendation
below is the *narrowed* post-verification form, not the analyst's first draft.

**The one-line verdict.** The framework is a well-designed *turn-based* loop with
goal-based-grade task contracts — it hands off the check and the stop condition per task
better than most of the article's examples. What it lacks is everything *around* the
task: an independent evaluator, a session-level stop condition, a post-merge watch,
executable (rather than prose) verification, and any mechanism that promotes recurring
lessons into rules. The article's other levers (scheduling, model routing, proactive
triage) are mostly optional for a solo-operator repo — adopt them by appetite, not by
default.

---

## What the framework already gets right

Recorded first, because the verification pass confirmed these as genuine — and because
several article recommendations turn out to already exist here in prose form.

- **Per-task stop criteria are already /goal-grade.** Acceptance criteria are written
  before code (`principles.md` #5, loop step 2), and the template couples every
  criterion to its check: `- [ ] criterion (how it will be verified)`. Real instances
  are genuinely deterministic — track's delivery records quote countable evidence
  ("TrackTests 68→71 · TrackUITests 7→8", "BUILD SUCCEEDED (no warnings)").
- **Verification honesty is the precondition for any self-verifying loop, and it's
  first-class.** "Quote the output… If I can't quote it, I didn't run it"; "If I cannot
  verify, that is a blocker. Don't fake-verify" (`verification.md`).
- **The no-human failure path is defined** — something the article's proactive loop
  presumes but never spells out: time-box → pivot → `blockers.md`, and "better one held
  PR than a bad merge" (`delivery.md`).
- **Scripts-for-deterministic-verification is already practiced at the instance
  level.** Trail's nine smoke harnesses drive the real compiled Elm modules and are
  named regression guards ("Regression guard for the TASK-039 overlap + TASK-045
  clock-time bugs"); track records verified `xcodebuild`/`simctl` flows and accretes
  gotchas the moment they bite.
- **A session circuit breaker exists** ("three tasks in a row went badly → stop new
  work and sweep", `working-style.md`) — the article doesn't even describe one.
- **Task shaping is token-conscious** without mentioning tokens: 15–60-minute tasks,
  smallest viable slice, split-in-backlog.

The gaps below are therefore mostly *structural* (who checks, when to stop, what
executes) rather than philosophical. The philosophy already matches the article.

---

## Improvements, in adoption order

A caution that applies to the whole list, echoing the article's own opening ("not all
tasks require complex loops"): adopted wholesale, these would roughly double the surface
area of a framework whose core virtue is smallness, and several add per-task overhead.
Tier 1 is the safety net for unattended merging — adopt it. Tier 2 is the big
token/quality lever. Tier 3 is cheap prose hardening. Tier 4 is appetite-gated.

### Tier 1 — the safety net for unattended merging

**1. A fresh-context review gate before merge (F1).** Every stop condition today is
self-graded by the agent that did the work: the `pr` cycle goes implement → local CI →
open → merge, all one context, often overnight. `verification.md` names the bias in its
own section title ("How to verify without me lying to myself") but answers it only with
honesty heuristics; `delivery.md` names the need ("would normally want a second pair of
eyes") but the only move it offers is draft-and-pivot. The article's fix is structural,
not attitudinal: a reviewer with fresh context, not influenced by the author's
reasoning.
*Change:* a new delivery gate in the `pr` profile (and a matching `verification.md`
gate between gates 6 and 7): before merging a **task PR**, obtain a review from a
fresh-context reviewer given only the diff and the `CURRENT.md` acceptance criteria —
never the authoring transcript — grading each criterion pass/fail; fix or explicitly
rebut each confirmed correctness finding in the PR description before merging. Phrased
by capability role, instance-free: "whatever second-agent facility the environment
provides — e.g. a built-in code-review skill, or a spawned subagent." Close PRs and
other AC-free bookkeeping are exempt. Degradation path: if the environment provides no
second-agent facility, note that once in `blockers.md` and proceed under today's rules.

**2. A session envelope: when does the *session* stop? (F2).** The per-task loop has
excellent stop criteria; the session loop has none. Step 8 (Advance) unconditionally
pulls the next task; the framework defines what to do *when* stopping (the sweep) but
never *when to stop* — no task-count budget, no defined empty-backlog terminal state
(track actually reached it and improvised in prose), and the three-bad-tasks breaker
doesn't say whether to resume afterward.
*Change:* an instance-free "Session envelope" section in `working-style.md`, referenced
from the loop: the manifest MAY declare a default envelope as a project-rule line (for
this repo, plausibly "run until the backlog's active list is empty or the first hard
blocker" — which also becomes the default when nothing is declared); a session-specific
envelope ("stop after the export task", "N tasks tonight") is recorded in the planning
area before work starts, mirroring the per-task-override contract; and step 8 checks
the envelope before pulling, with the empty-backlog state defined in the loop itself.
Related context-boundary lever the review surfaced (originally buried inside F3): each
task, not each session, is the natural fresh-context unit — an envelope line is where
"prefer starting the next task with fresh context" would live if adopted.

**3. Watch master after the merge (F6).** The `pr` cycle ends at merge → sync → next
task. The Hotfix exception is purely reactive — nothing ever *detects* the breakage.
This is the one finding whose failure mode has already occurred in this repo: trail's
`local-ci.md` records the Vercel build dying with `spawn elm ENOENT` while every local
gate was green. An overnight agent that merges a deploy-breaking PR at 2am then
cheerfully advances through five more tasks compounds the damage silently.
*Change:* gate **D3 — remote check resolved** in the `pr` profile: if the reference
area's `local-ci.md` records a remote-check command, run it after the merge and before
merging the close PR (close-PR prep absorbs deploy latency); the command must resolve
to green or red — "in progress" is neither, so poll or use the command's wait mode.
Red: the hotfix becomes the next task, jumping the backlog, and the close PR notes it.
Unresolvable (outage, auth): `blockers.md`, don't tick D3. Plus one end-of-session
sweep line: "the last merge's remote check resolved green (or is logged)?" Each system
records its concrete command in its own `local-ci.md`.

### Tier 2 — the big token and quality levers

**4. A "scripts over re-derivation" rule (F9).** The framework never says a
deterministic recurring procedure should be encoded once and invoked thereafter — the
article's most direct token lever. Sharpest case: the close-PR ritual (fixed branch
name, fixed title, three formulaic file edits, open, merge) has run on the order of
**80–90 times** (repo is at PR #178), each time re-derived from prose with a dozen tool
calls. Trail's local CI is 10 separate commands with no aggregate wrapper.
*Change:* in `working-style.md`, instance-free: "a deterministic procedure performed
from prose three times earns a script, recorded in the reference area; thereafter
invoke it and quote its output." In `delivery.md`, scoped to the close PR: its
mechanical shell (branch, title, file moves, open, merge, sync) may be scripted if the
project records one; the journal and `DONE.md` prose remain *authored input* to the
script — and no script ever performs the merge decision on a task PR. Instance work:
`scripts/close-pr.sh`; an `npm run ci` aggregate in trail; a `verify.sh` in track.

**5. Executable verification — and trail's missing eyes (F3).** Every gate and command
table is markdown the agent must recall at the right moment; nothing executes it. And
the centerpiece gate 3 ("it does the thing") is unsatisfiable-as-written for trail's UI:
a browser PWA with **no recorded way to see or drive its own interface** — no browser
tooling, no screenshot procedure, nothing equivalent to track's `simctl` screenshots and
XCUITest suites (which track evolved organically; the article's verify-frontend-change
skill in all but packaging).
*Change, in order:* (a) as trail-system work, add browser tooling (Chrome DevTools MCP
or a Playwright-driven smoke script) and record the UI smoke procedure in trail's
`local-ci.md` — this closes the real gap and is valuable with no framework change at
all; (b) via a `MONO-` task, add thin per-system skills (`verify-trail`,
`verify-track`) that execute the system's `local-ci.md` plus its interactive-drive
steps — commands live only in `local-ci.md`, so the skill can't drift from the
authority; (c) one instance-free sentence in `verification.md`: "if the project records
an executable verification procedure for the surface touched, run it and quote its
output."

### Tier 3 — cheap prose hardening

**6. Make "valid acceptance criterion" a rule, not a template hint (F4).** The
skeleton's `criterion (how it will be verified)` parenthetical is a seed, not a rule
with a litmus test — nothing in the framework would reject "UI feels responsive."
Track's excellent criteria are a writer's habit, uncodified. And the one measuring tool
that exists (trail's `perf:trace`) is demoted to "not a gate" with no baseline defining
what "regress" means.
*Change:* promote the hint to a binding rule in `verification.md`, referenced from loop
step 2: a criterion is valid iff it names its decider — a command + expected
exit/output, a countable delta, or a named manual probe + its expected observation —
litmus: "if a fresh evaluator couldn't check it, rewrite or split it." Where the
reference area records numeric budgets, quote the measured number against the budget.
Instance follow-ups: a test-floor ratchet for track (fail if suite counts drop; floor
bumped in the same PR that adds tests); for trail, record the last measured
`perf:trace` number as a baseline and quote fresh-vs-baseline in PRs that touch the
pipeline — a visibility rule, not an absolute-threshold gate.

**7. Caps an agent can actually count (F5).** The pivot trigger is "30 minutes of
focused effort" and task sizing is "15–60 minutes" — but an agent doesn't experience
wall-clock effort; the trigger fires on vibes or never. (Softened from the analyst's
draft: journal entries carry mandated timestamps and `date` exists — the defect is that
nothing says to anchor to readable clocks.) "Three tasks went badly" never defines
"badly" — an agent that merged three shakily-verified PRs would grade all three as
fine.
*Change:* rewrite when-stuck rung 7 around attempts: "if three distinct attempts at the
same obstacle produce no new information — not just no fix, no new *fact* — stop,"
with numbered tries in the blocker entry and timestamps only as an anchored fallback.
Express task size as "one verifiable slice" first, minutes second. Define "went badly"
as a checkable floor: it opened a blocker; it dropped or rewrote an acceptance
criterion under gate 1; it required a corrective delivery (revert/repair); or it
exhausted an attempt budget — assessable from the last three journal entries at orient
time.

### Tier 4 — appetite-gated

**8. A lesson-promotion step and a retro trigger (F7).** The journal is the sole
landing place for lessons and the only mandated future read is "the last ~5 entries" —
trail's journal is 101 entries deep. Command-class lessons already reach a durable home
(track's TRACK-012 signing lesson landed in `local-ci.md`, which gate 5 re-reads every
task — that channel demonstrably works). What's missing is the third class: recurring
*failure shapes* — trail's journal names "the cross-cutting-formatter trap recurred,"
and that trap exists nowhere outside the journal.
*Change:* (a) one classification question in the Log step and the sweep: "did anything
this session change how future work should be verified, delivered, or designed? If
yes, name where it was encoded — local-ci, ADR, manifest, framework-change candidate —
or why not." (b) A deterministic retro trigger (at epic close, or every N tasks): read
the journal back to the last retro marker, list failure shapes appearing more than
once, encode each as a gate/rule or a framework-change candidate.

**9. A session hand-off summary; fix the MORNING.md pointer (F8).** The sweep checks
hygiene but produces no session-level artifact — the operator reconstructs an overnight
multi-task run by reading N journal entries. Separately, root `CLAUDE.md` mentions
per-system `MORNING.md` files, but only trail's exists and it froze itself in May as a
historical snapshot.
*Change:* one sweep item — "for a multi-task session, append a closing session-summary
journal entry: tasks delivered (with delivery records), blockers opened, what's next" —
and a `MONO-` docs fix deleting the stale `MORNING.md` mention from root `CLAUDE.md`
(don't resurrect the file; the journal is the hand-off surface by design). Scheduled
(`/schedule`-style) triggering of sessions is *deliberately deferred*: it depends on
the session envelope (#2) and the permission envelope (#12), and the operator starting
sessions manually is not currently the bottleneck.

**10. Make `local-ci.md` current-truth by rule (F10).** Track's `local-ci.md` has
become a ~194-line changelog (TRACK-001…014) whose stale toolchain header is
contradicted by a warning buried at line ~180 ("update that when convenient") — every session
must read and reconcile the whole file to know which command currently works.
*Change:* one instance-free sentence at gate 5 (and the SETUP stub): the local-CI file
is *current-truth* — each gate lists the command, what it proves, and when it was last
verified; superseded facts are corrected in place; history belongs in the journal.
Then a small TRACK chore restructuring the file to that shape, ideally behind the
`verify.sh` from #4 (which would also encode the "piping xcodebuild masks its exit
code" lesson executably).

**11. Enforce the CURRENT.md invariant (F11).** Track's `CURRENT.md` "Active" section
holds eight completed-task paragraphs — the "exactly one task" invariant is stated but
appears on no checklist, so orientation reads scrollback every session.
*Change:* an instance docs PR moving the completed paragraphs into `DONE.md`, plus one
line in the `pr` profile's gates/sweep: "`CURRENT.md`'s Active section holds exactly
the active task, or is empty — completed-task summaries live only in `DONE.md`." (A
broader "reading budget" trimming of the manifest chain was considered and rejected:
the auxiliary framework docs are already referenced at their moments of use, and the
chain itself is safety-critical.)

**12. A permission envelope for unattended runs (critic).** The article names auto mode
as one of the four proactive-loop ingredients; the framework's only treatment of
permissions is a when-stuck row that classes a prompt as weather (retry → blocker →
pivot), and the repo's sole permission config is a gitignored `settings.local.json`
containing one disabled MCP server. Overnight autonomy currently rests on per-machine
state that travels nowhere.
*Change:* check in a versioned `.claude/settings.json` allowlisting the loop's
recurring command surface (the `local-ci.md` gate commands, `xcodebuild`/`simctl`,
`npm`/`npx` from `systems/*`, `git` branch/push, `gh pr create/merge`); document the
unattended-session permission posture in the root manifest next to the delivery
posture. One instance-free framework sentence extending the when-stuck row: "a
permission prompt that recurs is a system defect, not weather — before pivoting, record
the exact denied command so the operator can encode a grant."

**13. An inbox role for inbound work (critic).** The article's canonical proactive loop
starts by *checking for new reports* — and this repo's real work stream has exactly
that shape (TRACK-008…014 are all user-sourced — testing, feedback, requests), yet
loop step 1 orients
from `CURRENT.md`/`BACKLOG.md` only; user feedback has no defined landing place beyond
a screenshot-hygiene aside.
*Change:* add an `inbox` role to the framework's area roster (mapped per-system by the
manifest's Locations block), and one Orient sentence: "before pulling from BACKLOG,
sweep the inbox: each raw item becomes a backlog task with acceptance criteria, a
blocker question, or an explicit won't-do note."

**14. Sanction the competitive spike (critic).** Approach uncertainty is resolved
single-track today: "try the boring option," "pick the one that's easier to undo," and
ADR alternatives written by the same mind that already chose. The article's pattern —
build competing candidates, judge adversarially — is actively discouraged by a strict
reading of principle 2 ("parallel half-finished work is forbidden").
*Change:* a when-stuck rung between 6 and 7: when two approaches survive the
boring-option test and the choice is expensive to undo, timebox building both as
throwaway spikes (parallel worktrees where the environment provides them), judge the
candidates against the task's acceptance criteria with fresh context, keep one, record
the loser's *observed* failure in the ADR. Plus one clarifying clause on principle 2:
candidate spikes inside a single task are not parallel half-finished work — the task
is *choosing*.

**15. Give the parallel-agent model an operating procedure (F14).** The root manifest
designs one-agent-per-system parallelism (worktrees, three-axis disjointness), but the
framework — the thing each agent actually reads — never acknowledges concurrency, the
`pr` profile silently assumes a single writer to master, and nothing says how to
actually launch a parallel run.
*Change:* a launch runbook under `knowledge/reference/` (per-agent: worktree command,
working dir, the one-line prompt invoking the loop under that system's manifest, budget
per agent); one sentence in the `pr` profile normalizing a moving default branch
(another writer is normal, not an error); make step 8's sync worktree-aware (sync via
`git fetch`; skip checkout-based sync when master is checked out in another worktree).

**16. An on-ramp for framework changes discovered mid-session (F13).** The shared tier
is edited only via `MONO-` tasks, and `MONO-` work rides in trail's instance — so a
track or gateway session that discovers a framework-worthy defect has no compliant
channel (it can't edit the framework, can't write trail's planning, and the
cross-system whiteboard didn't exist until this document). Observable result: all three
framework versions trace to explicit user steers; zero agent-initiated proposals.
*Change:* in the root manifest's Shared-tier discipline: any system agent that hits a
framework-worthy defect writes a greppable `FRAMEWORK-CANDIDATE:` line (defect + the
rule that would have prevented it) in its **own** journal or whiteboard; every `MONO-`
task's orient step begins with `grep -rn 'FRAMEWORK-CANDIDATE:' systems/*/knowledge`,
triaging survivors into the `MONO-` backlog before its own work.

---

## Considered and rejected (the maze, per principle 7)

- **Model/effort routing** (route mechanical steps to cheaper models, declare delegate
  tiers in the manifest): rejected as tool-specific machinery disproportionate to a
  solo repo; the framework stays tool-agnostic. What survives of the idea are two
  one-liners: a sweep question ("any task whose actual effort blew well past its
  expected size? name the recurring cost and what script would remove it") and a
  pilot-first rule for batches of similar tasks ("treat the first as a pilot; let its
  actual-vs-expected effort resize the rest").
- **A "reading budget" trimming the manifest chain**: the chain is ~540 lines but
  safety-critical, and the auxiliary docs are already moment-of-use; the real
  inflation was CURRENT.md hygiene (#11).
- **Resurrecting MORNING.md as a live hand-off file**: the journal is the hand-off
  surface by design; the fix is a session-summary entry (#9) and deleting the stale
  pointer.
- **Absolute perf thresholds as hard gates**: brittle; a recorded baseline plus
  quote-against-baseline visibility (#6) gets the value without the flakes.
- **Instantiating `/schedule` now**: premature until #2 and #12 exist; the manual
  trigger is not the current bottleneck.

## Where we landed

Triaged 2026-07-08 as part of MONO-005 (which landed this entry): **MONO-006** =
Tier 1 (#1–#3, framework v3→v4); **MONO-007** = #4/#5c/#6/#7 (framework v4→v5);
**MONO-008** = the instance scripts (#4/#6 instance halves); **MONO-009** = the
per-system verify skills (#5b); **TASK-072** (trail) = the browser-drive tooling
(#5a). Tier 4 (#8–#16) stays parked here — promote on a user steer. The queue lives
in trail's `BACKLOG.md` (MONO- namespace), per the shared-tier discipline.

Nothing adopted into the framework yet — the tasks above are the adoption. The
original sequencing rationale stands: #1–#3 first
(they close the "unattended agent merges to sacred master with no independent check,
no stop condition, and no post-merge watch" exposure), #4–#5 next (the recurring token
burn and trail's verification blindness), #6–#7 as cheap hardening whenever a `MONO-`
task is open anyway, the rest by appetite. Framework-file edits go upstream via
`MONO-` tasks per "Changing the framework" (instance-free wording throughout — every
change above is phrased by role/capability, never by tool or project name); instance
work (trail browser tooling, track local-ci restructure, close-pr script, checked-in
settings) rides each system's own planning.

## Follow-ups

- [x] Triage each numbered item into `MONO-`/system backlog tasks (or an explicit
      won't-do note here) and update the Status line. — *Done 2026-07-08 (MONO-005):
      see Where we landed for the id map; Tier 4 is the explicit "parked, not
      won't-do" residue.*
- [x] Batch the framework-file edits into few `MONO-` PRs to amortize the framework
      version bump. — *Decided: two framework PRs — MONO-006 (v3→v4: #1–#3) and
      MONO-007 (v4→v5: #4/#5c/#6/#7).*
- Note: the review corpus (per-finding evidence, verifier verdicts, refuted
  variants) is session-transient; this document is the durable record.
