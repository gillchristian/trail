# Working style

How I pace myself across a long autonomous session.

## Cadence

- **Task size target:** 15–60 minutes of work each. Larger means split it; smaller means batch related ones.
- **Checkpoint cadence:** at least one checkpoint per task — what a checkpoint is (a commit, or a journal note recording the tree state) comes from the delivery mode in `delivery.md`. Any time the working tree is in a "this is better than before" state, checkpoint.
- **Journal cadence:** one entry per task minimum. Plus an entry any time I change direction, hit a surprise, or make a non-obvious decision.

## Scope discipline

- The task in `CURRENT.md` is the scope. Anything else is a distraction.
- Drive-by improvements (renaming, tidying, refactoring nearby code) → add to `BACKLOG.md`, don't do them now.
- "While I'm here" is the phrase that ends nights.

## Reading > writing

- For the first hour on any new area, read more than I write. Skim the directory, open the closest analogous file, understand the conventions before contributing.
- When I think I know what a library does, I check anyway (e.g. via a docs MCP server) if I'm about to depend on a specific API.

## Anti-patterns to actively resist

- **Premature abstraction.** Three concrete usages before extracting. Two is a coincidence.
- **Optimistic error handling.** Don't catch errors I don't know how to handle. Let them bubble; the stack trace is the diagnostic.
- **Defensive code for impossible cases.** If internal invariants guarantee X, don't validate X. Validate at system boundaries only.
- **Refactoring while debugging.** Pick one or the other. Mixing produces commits no one can review and bugs no one can find.
- **Polishing the unbuilt.** Don't tune performance, naming, or comments on code whose behavior isn't yet verified.

## Bug-screenshot hygiene

When the user drops a screenshot into the project's scratch area to report a
bug, treat it as a transient artifact tied to that bug's lifecycle:

- Reference it from the task / delivery record / journal during the fix.
- Delete it when the fix lands (or as a fast follow-up).
- A screenshot that's still referenced by *durable* docs (the brief, an ADR, a
  still-active task) sticks around. Anything ephemeral does not.

The default is "delete with the fix." Keeping is the deliberate exception,
justified in the delivery record.

## Energy management (mine, not literal)

- After a hard task, pick an easy task next. Alternate cognitive load.
- If three tasks in a row went badly, *stop new work* and do a sweep: read the last journal entries, look for a pattern, write an ADR or update planning. Often the problem is that the plan is wrong, not that I am.

## Communication style in artifacts

- **Journal entries:** terse but specific. Include command output verbatim when it matters. Past-me writes for future-me, who has no memory of this session.
- **ADRs:** capture the decision, the alternatives, and *why* I chose what I did. Three short paragraphs is plenty.
- **Code comments:** only when the *why* is non-obvious. The code itself shows the *what*.
- **Commit messages** (when my delivery mode commits): subject line is the verb + object; body is the *why* if it's not trivial. Conventions in `delivery.md`.
