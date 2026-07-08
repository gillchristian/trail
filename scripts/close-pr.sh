#!/usr/bin/env bash
# close-pr.sh — the close-PR mechanical shell (framework/delivery.md, profile `pr`).
#
# Wraps ONLY the mechanics: branch, commit, push, open, merge, sync. The authored
# parts — the DONE.md entry, the BACKLOG tick, the journal entry, the next task in
# CURRENT.md — must already sit in the working tree before this runs. This script
# never touches a task PR: it creates and merges its own docs/<task-id>-close PR,
# which is the one PR class exempt from the fresh-context review (verification
# gate 7).
set -euo pipefail

usage() {
  cat <<'EOF'
usage: scripts/close-pr.sh <task-id> <task-pr-number> <merge-sha> [title-suffix]

Run from the repo root, on master, AFTER writing the close edits (DONE.md,
BACKLOG.md, journal, CURRENT.md) into the working tree. Only knowledge-area
files may be dirty. Example:

  scripts/close-pr.sh MONO-008 185 abc1234 "orient MONO-009"

Steps performed (each printed): guard checks -> branch docs/<task-id>-close ->
commit -> push -> gh pr create -> gh pr merge --squash --delete-branch ->
checkout master + pull --ff-only.

If gh fails mid-flow the close edits are already committed on the docs branch —
nothing is lost. Finish manually from that branch (gh pr create / gh pr merge
--squash --delete-branch, then git checkout master && git pull --ff-only); the
master guard intentionally blocks re-running the script from that state.
EOF
}

[ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ] && { usage; exit 0; }
[ $# -lt 3 ] && { usage; exit 2; }

TASK_ID="$1"; PR_NUM="$2"; SHA="$3"; SUFFIX="${4:-}"
BRANCH="docs/$(echo "$TASK_ID" | tr '[:upper:]' '[:lower:]')-close"
TITLE="docs: close ${TASK_ID} (merged ${SHA})${SUFFIX:+; ${SUFFIX}}"

echo "== guards"
[ "$(git rev-parse --abbrev-ref HEAD)" = "master" ] || { echo "FAIL: not on master"; exit 1; }
# One path per line; --no-renames lists both sides of a rename so a
# knowledge -> non-knowledge move can't slip past the filter.
DIRTY=$( { git diff --name-only --no-renames HEAD; git ls-files --others --exclude-standard; } | sort -u )
[ -n "$DIRTY" ] || { echo "FAIL: nothing to close — the authored edits must be in the tree"; exit 1; }
BAD=$(echo "$DIRTY" | grep -vE '^(knowledge/|systems/[^/]+/knowledge/)' || true)
[ -z "$BAD" ] || { echo "FAIL: non-knowledge files dirty:"; echo "$BAD"; exit 1; }

echo "== branch $BRANCH"
git checkout -b "$BRANCH"
echo "== commit"
git add -A
git commit -m "$TITLE" -m "Close PR for ${TASK_ID} (task PR #${PR_NUM}, merged ${SHA}): DONE.md entry, BACKLOG tick, journal entry${SUFFIX:+, ${SUFFIX}}."
echo "== push"
git push -u origin "$BRANCH"
echo "== open close PR"
gh pr create --title "$TITLE" --body "Post-merge bookkeeping for ${TASK_ID} (task PR #${PR_NUM}, merged \`${SHA}\`)${SUFFIX:+ + ${SUFFIX}}. Close PR — carries no acceptance criteria of its own; exempt from the fresh-context review (verification gate 7)."
echo "== merge"
gh pr merge --squash --delete-branch
echo "== sync master"
git checkout master
git pull --ff-only
echo "== done: ${TASK_ID} closed"
