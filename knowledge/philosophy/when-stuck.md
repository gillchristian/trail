# When stuck

The user is not available. I cannot ask. This document is what I do instead.

## Diagnostic ladder

Walk down this ladder when blocked. Don't skip rungs.

1. **Re-read the task.** Open `planning/CURRENT.md`. Did I drift from the acceptance criteria? Often the answer is "yes, I'm solving a problem the task didn't ask me to solve."
2. **Re-read recent journal entries.** `progress/journal.md` (last ~5 entries). Did past-me leave a hint? Did I already try this and learn something?
3. **Re-read the upstream spec.** When the task came from a trail-driven spec, the canonical source is `/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md`. If a requirement seems contradictory or unclear, the spec is canonical — not my recollection of it.
4. **Read the code.** Not the code I'm writing — the code around it. Most "I don't know how X works" questions are answered by reading 50 more lines of existing code. `handlers/auth.go`, `handlers/oauth_state.go`, `handlers/streams.go`, `handlers/athlete.go`, `store/token.go`, `store/activity_cache.go`, and `strava/client.go` are the load-bearing files for the Strava/auth surface.
5. **Read the docs.** For external libraries/APIs (Strava, chi, modernc/sqlite), fetch fresh docs via context7. Training data is stale; published docs are not.
6. **Reduce the problem.** Build the smallest possible reproduction. If I can't reproduce the bug in isolation, my mental model is wrong somewhere.
7. **Try the boring option.** When choosing between a clever path and an obvious path, pick obvious. The boring option is reversible; the clever one usually isn't.
8. **Time-box and pivot.** If 30 minutes of focused effort hasn't moved the needle, stop. Write down (a) what I tried, (b) what I observed, (c) what I currently believe, (d) what would unblock me. Move that to `progress/blockers.md` and pick a different task from the backlog.

## Classes of "stuck" and the right response

| Symptom | Response |
|---|---|
| Ambiguous requirement in the spec | Make a reasonable interpretation, log it as an ADR in `decisions/`, continue. Note in `blockers.md` only if the interpretation might be wrong in a way that wastes a lot of work. |
| Missing technical info (secret, exact data shape, library choice) | If a sane default exists, take it and log the decision. If no sane default, this is a real blocker — `blockers.md`. |
| Strava API behaves unexpectedly | Verify against published docs (context7). The Strava API has quirks; the docs are authoritative even when behavior seems different. |
| Test/run failing for unclear reasons | Reduce. Print actual vs expected at the failure point. Don't tweak the test until it passes — find the bug. |
| Cannot reproduce locally | Don't proceed on faith. Log it as a blocker and work on something else. |
| Picking between two equivalent approaches | Pick the one that's easier to undo. Note the alternative in the ADR. |
| Stuck in a refactor rabbit hole | Revert. Resume from a clean state. The original task probably didn't need the refactor. |
| Tool/permission/environment failure | One retry with diagnostics. If still failing, log to `blockers.md` and pivot. Do not bypass safety checks (e.g. `--no-verify`). |
| Migration changes break the existing `tokens.db` | **Hard stop.** A bad migration on the Fly volume is an outage. Roll back the migration, write a clearer one, verify against a copy of the live DB before retrying. |

## What I will *not* do when stuck

- Invent Strava API behavior I haven't verified.
- Write "should work" code I haven't run.
- Mark a task complete when verification failed or wasn't done.
- Delete or rewrite my own prior work to "start fresh" — the prior work is data; learn from it.
- Skip the journal entry because the task didn't go well. Failed attempts are the most useful entries.
- Modify trail's spec to make my life easier. If the spec is wrong, file a blocker; trail owns the requirements.

## The escape hatch

If everything is blocked and I cannot make forward progress on anything: write a clear status summary at the top of `progress/blockers.md` (what's blocked, what I tried, what I need), then stop. Stopping with clear blockers is strictly better than fabricating progress.
