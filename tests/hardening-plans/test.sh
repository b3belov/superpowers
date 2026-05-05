#!/usr/bin/env bash
# Verifies the artifacts hardening-plans produces against the fixture plan.
# Usage:
#   bash tests/hardening-plans/test.sh <copy-of-sample-plan.md> <ledger.md>
# Exits 0 on pass, non-zero on failure.

set -euo pipefail

PLAN="${1:?path to plan file (post-hardening) required}"
LEDGER="${2:?path to ledger file required}"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$PLAN"   ]] || fail "plan file not found at $PLAN"
[[ -f "$LEDGER" ]] || fail "ledger file not found at $LEDGER"

# 1. Ledger header sanity.
grep -q "^# Hardening Ledger:" "$LEDGER" || fail "ledger missing header"
grep -qE "^\*\*Status:\*\* (in-progress|converged|stopped-by-user)" "$LEDGER" \
  || fail "ledger missing Status line"

# 2. At least one iteration recorded.
grep -qE "^## Iteration 1 " "$LEDGER" || fail "ledger missing Iteration 1"

# 3. At least one finding per axis raised in iteration 1.
for axis in ISSUES UX reusability security performance; do
  grep -q "$axis" "$LEDGER" || fail "no '$axis' finding recorded in ledger"
done

# 4. Plan was modified — at least one SEEDED-FLAW comment should be addressed
#    (i.e., the plan diff should reduce the SEEDED-FLAW count or the surrounding
#    code should have changed). We use the count as a coarse signal.
ORIG_FLAWS=6
CUR_FLAWS=$(grep -c "SEEDED-FLAW" "$PLAN" || true)
[[ "$CUR_FLAWS" -lt "$ORIG_FLAWS" ]] \
  || fail "plan does not appear to have been hardened (SEEDED-FLAW count unchanged: $CUR_FLAWS)"

# 5. If the ledger reports a second iteration, it must converge.
if grep -qE "^## Iteration 2 " "$LEDGER"; then
  awk '/^## Iteration 2 /{flag=1} flag && /^- Findings raised: /{print; exit}' "$LEDGER" \
    | grep -q "Findings raised: 0" \
    || fail "iteration 2 present but did not converge (expected 'Findings raised: 0')"
fi

echo "PASS: hardening-plans artifacts look correct"
