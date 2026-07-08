#!/usr/bin/env bash
# verify.sh — track's local CI in one command (reference/local-ci.md documents it).
#
# Encodes the two hard-won lessons from local-ci.md's toolchain-moved warning:
#   1. Pin the OS: a bare destination resolves to OS:latest, where iPhone 15
#      doesn't exist (Xcode 17F113 / iOS 26.5 era).
#   2. Never trust a filtered pipeline's exit code around xcodebuild: capture the
#      full output, then read it for '** TEST SUCCEEDED **'.
# Plus the test-floor ratchet: the floors below only move UP, bumped in the same
# PR that adds tests.
set -uo pipefail

UNIT_FLOOR=71
UI_FLOOR=8

cd "$(dirname "$0")/../Track" || { echo "FAIL: cannot cd to the Track project dir"; exit 1; }
OUT="${TMPDIR:-/tmp}/track-verify-$$.log"

echo "== xcodebuild test (iPhone 15, OS=17.4) -> $OUT"
xcodebuild test -project Track.xcodeproj -scheme Track \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.4' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO >"$OUT" 2>&1
XC_EXIT=$?

if ! grep -q '\*\* TEST SUCCEEDED \*\*' "$OUT"; then
  tail -60 "$OUT"
  echo "FAIL: no '** TEST SUCCEEDED **' in the captured output (xcodebuild exit ${XC_EXIT}; full log: $OUT)"
  exit 1
fi

count_for() { # $1 = test bundle name
  grep -A1 "Test Suite '$1.xctest' passed" "$OUT" \
    | grep -o 'Executed [0-9]* tests' | head -1 | grep -o '[0-9]*'
}
UNIT=$(count_for TrackTests)
UI=$(count_for TrackUITests)
[ -n "$UNIT" ] && [ -n "$UI" ] || { echo "FAIL: could not parse suite counts (log: $OUT)"; exit 1; }

FAIL=0
[ "$UNIT" -ge "$UNIT_FLOOR" ] || { echo "FAIL: TrackTests $UNIT < floor $UNIT_FLOOR"; FAIL=1; }
[ "$UI" -ge "$UI_FLOOR" ] || { echo "FAIL: TrackUITests $UI < floor $UI_FLOOR"; FAIL=1; }
[ "$FAIL" -eq 0 ] || exit 1

echo "PASS: TEST SUCCEEDED — TrackTests ${UNIT} (floor ${UNIT_FLOOR}) · TrackUITests ${UI} (floor ${UI_FLOOR})"
