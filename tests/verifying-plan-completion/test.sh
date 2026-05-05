#!/usr/bin/env bash
# Verifies the artifacts the verifying-plan-completion skill produces against the
# seeded fixture under tests/verifying-plan-completion/.
#
# Two modes:
#   bash tests/verifying-plan-completion/test.sh static
#       Validates fixture files, expected-report.md, and the SKILL/prompt files
#       for required structural markers.
#   bash tests/verifying-plan-completion/test.sh report <path-to-actual-report.md>
#       Compares an actual verifier-produced report against expected-report.md
#       on classification (counts per STATUS bucket and per EXTRA classification).
#
# NOTE: This harness validates structural properties only. It does NOT prove
# verifier correctness end-to-end. End-to-end correctness is established by the
# adversarial testing task (see plan Task 10) which runs real agent sessions
# against the seeded fixture and records before/after eval results.
#
# Exits 0 on pass, non-zero on failure.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
FIXTURE_DIR="$ROOT/tests/verifying-plan-completion"
SKILL_DIR="$ROOT/skills/verifying-plan-completion"

fail() { echo "FAIL: $*" >&2; exit 1; }

mode="${1:?usage: test.sh <static|report> [args]}"

static_checks() {
  # Fixture sanity.
  [[ -f "$FIXTURE_DIR/sample-plan.md" ]] || fail "missing sample-plan.md"
  [[ -f "$FIXTURE_DIR/expected-report.md" ]] || fail "missing expected-report.md"
  [[ -d "$FIXTURE_DIR/seeded-implementation" ]] || fail "missing seeded-implementation/"
  for f in feature-a.txt feature-b.txt incidental-bugfix.txt scope-creep.txt refactor-covered.txt; do
    [[ -f "$FIXTURE_DIR/seeded-implementation/$f" ]] || fail "missing seed: $f"
    grep -q "FIXTURE ONLY" "$FIXTURE_DIR/seeded-implementation/$f" || fail "$f missing FIXTURE ONLY banner"
  done
  # feature-c.txt MUST NOT exist (it is the MISSING seed).
  [[ ! -f "$FIXTURE_DIR/seeded-implementation/feature-c.txt" ]] || fail "feature-c.txt must be absent (MISSING seed)"

  # Skill artifacts present and structurally complete.
  [[ -f "$SKILL_DIR/SKILL.md" ]] || fail "missing SKILL.md"
  [[ -f "$SKILL_DIR/verifier-prompt.md" ]] || fail "missing verifier-prompt.md"

  for marker in \
    "^name: verifying-plan-completion" \
    "^# Verifying Plan Completion" \
    "STATUS: clean | gaps | scope-creep | both" \
    "MISSING" "EXTRA" "PARTIAL" "EVIDENCE TABLE" \
    "incidental-fix" "scope-creep" "refactor" "unknown" \
    "MAX_ITERATIONS"; do
    grep -q "$marker" "$SKILL_DIR/SKILL.md" || fail "SKILL.md missing marker: $marker"
  done

  # Verifier prompt structural markers — the prompt references SKILL.md as the
  # canonical source for schema/classification/matching, so we check the references
  # exist (not the duplicated content).
  for marker in \
    "READ-ONLY" \
    "Output Schema" \
    "Classification Rules for EXTRA Items" \
    "Plan-vs-Diff Matching Procedure" \
    "ERROR:"; do
    grep -q "$marker" "$SKILL_DIR/verifier-prompt.md" || fail "verifier-prompt.md missing marker: $marker"
  done

  # Integration hooks present in caller skills.
  grep -q "verifying-plan-completion" "$ROOT/skills/executing-plans/SKILL.md" \
    || fail "executing-plans/SKILL.md missing verifying-plan-completion hook"
  grep -q "verifying-plan-completion" "$ROOT/skills/subagent-driven-development/SKILL.md" \
    || fail "subagent-driven-development/SKILL.md missing verifying-plan-completion hook"
  grep -q "verifying-plan-completion" "$ROOT/skills/finishing-a-development-branch/SKILL.md" \
    || fail "finishing-a-development-branch/SKILL.md missing verifying-plan-completion hook"
  grep -q "verifying-plan-completion" "$ROOT/skills/verification-before-completion/SKILL.md" \
    || fail "verification-before-completion/SKILL.md missing cross-reference"

  echo "OK: static checks pass"
}

report_checks() {
  local actual="${1:?usage: test.sh report <path-to-actual-report.md>}"
  [[ -f "$actual" ]] || fail "actual report not found: $actual"

  # STATUS line
  grep -qE "^STATUS: (clean|gaps|scope-creep|both)$" "$actual" || fail "actual report missing STATUS line"

  # Counts: 1 MISSING, 1 PARTIAL, 3 EXTRA, classifications: incidental-fix, scope-creep, refactor.
  awk '
    /^MISSING:/ { sec="MISSING"; next }
    /^PARTIAL:/ { sec="PARTIAL"; next }
    /^EXTRA:/   { sec="EXTRA"; next }
    /^EVIDENCE TABLE:/ { sec="EV"; next }
    sec=="MISSING" && /^- / { miss++ }
    sec=="PARTIAL" && /^- / { part++ }
    sec=="EXTRA"   && /^- / { extra++ }
    sec=="EXTRA" && /classification: incidental-fix/ { c_inc++ }
    sec=="EXTRA" && /classification: scope-creep/    { c_scope++ }
    sec=="EXTRA" && /classification: refactor/       { c_ref++ }
    END {
      if (miss != 1) { print "expected 1 MISSING, got " miss+0; exit 2 }
      if (part != 1) { print "expected 1 PARTIAL, got " part+0; exit 2 }
      if (extra != 3) { print "expected 3 EXTRA, got " extra+0; exit 2 }
      if (c_inc != 1)   { print "expected 1 incidental-fix EXTRA, got " c_inc+0; exit 2 }
      if (c_scope != 1) { print "expected 1 scope-creep EXTRA, got " c_scope+0; exit 2 }
      if (c_ref != 1)   { print "expected 1 refactor EXTRA, got " c_ref+0; exit 2 }
    }
  ' "$actual" || fail "report counts/classifications do not match expectations"

  echo "OK: report matches expected classification shape"
}

case "$mode" in
  static) static_checks ;;
  report) shift; report_checks "$@" ;;
  *) fail "unknown mode: $mode (use 'static' or 'report')" ;;
esac
