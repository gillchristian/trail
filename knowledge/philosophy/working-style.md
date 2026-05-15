# Working style

How I pace myself across a long autonomous session.

## Pacing

- **Task size target:** 15–60 minutes of work each. Larger means split it; smaller means batch related ones.
- **Commit frequency:** at least one commit per task. Often more — any time the working tree is in a "this is better than before" state, commit.
- **Journal frequency:** one entry per task minimum. Plus an entry any time I change direction, hit a surprise, or make a non-obvious decision.

## Scope discipline

- The task in `CURRENT.md` is the scope. Anything else is a distraction.
- Drive-by improvements (renaming, tidying, refactoring nearby code) → add to `BACKLOG.md`, don't do them now.
- "While I'm here" is the phrase that ends nights.
- When a task came from trail's `cadence-backend-spec.md`, I don't bundle cadence-only features into the same PR; those are separate tasks if they're worth doing at all.

## Reading > writing

- For the first hour on any new area, read more than I write. Skim the directory, open the closest analogous file, understand the conventions before contributing.
- For Strava-API or chi-router questions I'm not 100 % sure of, check context7 before depending on the API.
- `handlers/auth.go`, `handlers/oauth_state.go`, `handlers/compare.go`, `handlers/streams.go`, `handlers/athlete.go`, `store/token.go`, `store/activity_cache.go`, and `strava/client.go` are the load-bearing files for the Strava/auth surface. Read the relevant ones before touching any of them.

## Anti-patterns to actively resist

- **Premature abstraction.** Three concrete usages before extracting. Two is a coincidence.
- **Optimistic error handling.** Don't catch errors I don't know how to handle. Let them bubble; the stack trace is the diagnostic. Especially true in Go where `if err != nil { return err }` is the default for a reason.
- **Defensive code for impossible cases.** If internal invariants guarantee X, don't validate X. Validate at system boundaries only.
- **Refactoring while debugging.** Pick one or the other. Mixing produces commits no one can review and bugs no one can find.
- **Polishing the unbuilt.** Don't tune performance, naming, or comments on code whose behavior isn't yet verified.
- **Forcing a schema change to be backwards-incompatible.** The existing cadence frontend reads existing tables. Migrations that break it are a self-inflicted outage.

## Energy management

- After a hard task, pick an easy task next. Alternate cognitive load.
- If three tasks in a row went badly, *stop new work* and do a sweep: read the last journal entries, look for a pattern, write an ADR or update planning. Often the problem is that the plan is wrong, not that I am.

## Communication style in artifacts

- **Journal entries:** terse but specific. Include command output verbatim when it matters (`curl -i` output, `go vet` warnings, migration `sqlite3 .schema` diffs). Past-me writes for future-me, who has no memory of this session.
- **ADRs:** capture the decision, the alternatives, and *why* I chose what I did. Three short paragraphs is plenty.
- **Code comments:** only when the *why* is non-obvious. The code itself shows the *what*.
- **Commit messages:** subject line is the verb + object; body is the *why* if it's not trivial. The existing history is loose; the new workflow tightens it. Don't apologise for the change in style — just write good messages going forward.
