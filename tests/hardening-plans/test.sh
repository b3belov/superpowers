#!/usr/bin/env bash
# Verifies the artifacts hardening-plans produces against the fixture plan.
# Usage:
#   bash tests/hardening-plans/test.sh <copy-of-sample-plan.md> <ledger.md>
# Exits 0 on pass, non-zero on failure.
#
# The canonical list of axes lives in skills/hardening-plans/SKILL.md
# (Concern Axes section). This script encodes the same list — keep in sync.

set -euo pipefail

PLAN="${1:?path to plan file (post-hardening) required}"
LEDGER="${2:?path to ledger file required}"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$PLAN"   ]] || fail "plan file not found at $PLAN"
[[ -f "$LEDGER" ]] || fail "ledger file not found at $LEDGER"

# 1. Ledger header sanity.
grep -q "^# Hardening Ledger:" "$LEDGER" || fail "ledger missing header"
grep -qE "^\*\*Status:\*\* (in-progress|converged|stopped-by-user)" "$LEDGER" \
  || fail "ledger missing or malformed Status line"
grep -qE "^\*\*Verified at commit:\*\* [0-9a-f]{7,40}" "$LEDGER" \
  || fail "ledger missing 'Verified at commit:' line with a sha"

# 2. At least one iteration recorded.
grep -qE "^## Iteration 1 " "$LEDGER" || fail "ledger missing Iteration 1"

# 3. Schema check: each finding heading has the required field block.
#    Heading: '#### F-N.X — [severity: H|M|L] — [<axis>] — <title>'
#    Required fields directly underneath: Location, Description, Suggested change,
#    Rationale, Decision (and Reason iff decision != applied), Plan diff.
awk '
  /^#### F-/ {
    if (in_finding) check();
    in_finding=1; loc=desc=sug=rat=dec=diff=0; reason_seen=0;
    if (! match($0, /\[severity: (high|med|low)\]/)) bad_sev=1;
    if (! match($0, /\[(ISSUES|UX|reusability|security|performance)\]/)) bad_axis=1;
    next
  }
  in_finding && /^- \*\*Location in plan:\*\*/   { loc=1 }
  in_finding && /^- \*\*Description:\*\*/        { desc=1 }
  in_finding && /^- \*\*Suggested change:\*\*/   { sug=1 }
  in_finding && /^- \*\*Rationale.*:\*\*/        { rat=1 }
  in_finding && /^- \*\*Decision:\*\* (applied|rejected|deferred)/ { dec=1; if ($0 !~ /applied/) reason_required=1 }
  in_finding && /^- \*\*Reason.*:\*\*/           { reason_seen=1 }
  in_finding && /^- \*\*Plan diff:\*\*/          { diff=1 }
  /^## / && in_finding { check(); in_finding=0 }
  END { if (in_finding) check(); if (bad_sev) { print "bad-severity"; exit 2 } if (bad_axis) { print "bad-axis"; exit 2 } }

  function check() {
    if (!(loc && desc && sug && rat && dec && diff)) {
      print "incomplete-finding-block";
      exit 2
    }
    if (reason_required && !reason_seen) {
      print "missing-reason-on-non-applied";
      exit 2
    }
    reason_required=0
  }
' "$LEDGER" \
  || fail "ledger has malformed finding blocks (see awk output above)"

# 4. At least one finding per axis raised in iteration 1
#    (axis must appear inside a Finding heading, not just anywhere in the file).
for axis in ISSUES UX reusability security performance; do
  grep -qE "^#### F-1\.[0-9]+.*\[$axis\]" "$LEDGER" \
    || fail "no '$axis' finding heading recorded in iteration 1"
done

# 5. Plan was modified — SEEDED-FLAW count must drop.
ORIG_FLAWS=6
CUR_FLAWS=$(grep -c "SEEDED-FLAW" "$PLAN" || true)
[[ "$CUR_FLAWS" -lt "$ORIG_FLAWS" ]] \
  || fail "plan does not appear to have been hardened (SEEDED-FLAW count unchanged: $CUR_FLAWS)"

# 6. If the ledger reports a second iteration, it must converge.
if grep -qE "^## Iteration 2 " "$LEDGER"; then
  awk '/^## Iteration 2 /{flag=1} flag && /^- Findings raised: /{print; exit}' "$LEDGER" \
    | grep -q "Findings raised: 0" \
    || fail "iteration 2 present but did not converge (expected 'Findings raised: 0')"
fi

echo "PASS: hardening-plans artifacts look correct"
