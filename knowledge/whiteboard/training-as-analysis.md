# Training-mode vs. planner

> Status: resolved (for now) — Trail stays a race planner. Analysis features
> are admitted *only* when they sharpen the planner. HR-on-linked-actuals is
> the one concrete action we're taking; everything else waits.

## Context

User brainstorm 2026-05-18. The user noted that during training they seldom
follow a pre-planned route; they'd like to start from a past Strava
activity. The broader idea: treat training runs as ingestable artifacts for
analysis, not just race plans.

Tension: the brief is explicit — *"this is planning, not recording"* and
"No live activity tracking" is in **Out of scope**. But TASK-016
(plan-vs-actual diff) and TASK-024b (Strava activity picker) already ingest
activities; the analysis machinery exists, just gated behind an existing
race plan.

## Options considered

### A. Open the door fully — "training mode"

Start a race from a Strava activity. Activity becomes a synthetic race;
synthetic GPX derived from the streams; planning machinery either disabled
or repurposed for post-hoc analysis. Heart rate, cadence, power, etc. all
surfaced.

**Why it's tempting:** the user does train a lot, planning every training
run is overkill, and the data is right there.

**Why it's wrong:**

- Every training run becomes a "race." The index page floods. The
  planning UI becomes dead weight on most entries.
- The COROS-export workflow — the original success criterion of the
  brief — becomes one feature among many.
- "No live activity tracking" was a deliberate scope boundary. Crossing it
  without a stop-rule means the app becomes a Strava alternative.

### B. Pure planner — no training-side work

Don't ingest training runs at all. The Strava integration stays as it is:
ingest *actuals* against existing race plans only.

**Why it's safe:** the north star is preserved. Zero scope risk.

**Why it's too restrictive:** there are genuinely useful analysis additions
(HR per km on a linked actual, calibration of the predictor from past
training data) that *do* serve planning. Rejecting them all on principle
loses the leverage Strava integration provides.

### C. Admit analysis *only when it sharpens planning* (chosen)

The rule: every analysis feature has to answer the question "does this
help me plan a better race?" If yes, admit it. If no — even if it's
interesting — reject it.

Concretely:

- ✅ HR avg per km on a linked actual — helps the user see where they
  were red-lining, informs the next plan.
- ✅ Predictor calibration from past activities (TASK-022, already
  scoped) — directly improves planning outputs.
- ❌ Training-run ingestion as a first-class artifact — pulls the app
  toward "training log."
- ❌ Activity-first workflow ("start from a Strava run, generate a race
  from it") — same.
- 🤔 HR-aware predictor (zones, drift) — admit if it improves prediction
  for *races*, not if it's just analytical eye candy.

## Where we landed

Trail is a race planner. The one analysis feature we're acting on now is
**HR data on linked actuals** (the small task queued as TASK-026 in the
backlog). Everything else from the brainstorm — training mode, activity-
first workflow, additional stream metrics for their own sake — is
explicitly deferred.

The user's framing settled it:

> Whatever analysis tools we put into the tool must serve the purpose of
> understanding races and being able to plan further races better.

If we ever feel tempted to admit a training-mode feature, the test is:
*can I write a one-line sentence connecting this to better future race
plans?* If the sentence is tortured or speculative, the feature stays out.

## Follow-ups

- TASK-026 — show HR data on linked actuals. Queued in BACKLOG.
- No ADR drafted. If we later want to lock the "analysis must sharpen
  planning" rule formally, an ADR is the right place — but for now it
  lives in this whiteboard entry and in the project brief's existing
  scope statements.
- If a future request reopens this discussion, return here first.
