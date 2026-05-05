# Verifying Plan Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `verifying-plan-completion` skill that audits plan-vs-implementation at the end of plan execution, with a subagent-preferred verifier and inline fallback, an auto-loop that drives fixes, and integration hooks in the two execution skills and `finishing-a-development-branch`.

**Architecture:** New skill folder under `skills/verifying-plan-completion/` containing `SKILL.md` (procedure + integration notes) and `verifier-prompt.md` (subagent template). Four existing skills get integration edits. A fixture-driven test under `tests/verifying-plan-completion/` validates the report shape, the convergence behavior, and the integration touchpoints by structural assertions — matching the pattern used by `tests/hardening-plans/`.

**Tech Stack:** Markdown skill files, bash test harness (`set -euo pipefail`, `awk`, `grep`), git for fixture branches.

---

## Spec

Source spec: `docs/superpowers/specs/2026-05-05-verifying-plan-completion-design.md`. Re-read it before starting.

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `skills/verifying-plan-completion/SKILL.md` | Create | Skill content: process, inline procedure, classification rules, auto-loop, integration. |
| `skills/verifying-plan-completion/verifier-prompt.md` | Create | Subagent prompt: inputs, output schema, classification rules. Read-only research role. |
| `skills/executing-plans/SKILL.md` | Modify | Insert Step 2.5 invoking the new skill before Step 3. |
| `skills/subagent-driven-development/SKILL.md` | Modify | Replace "Dispatch final code reviewer subagent" with `superpowers:verifying-plan-completion`. Clarify per-task `spec-reviewer-prompt.md` is unchanged. |
| `skills/finishing-a-development-branch/SKILL.md` | Modify | Add Step 1b: when invoked from a plan-execution context, require plan-completion verification has run with `clean` status. |
| `skills/verification-before-completion/SKILL.md` | Modify | One-line cross-reference under "Requirements met" row pointing to the new skill. |
| `tests/verifying-plan-completion/sample-plan.md` | Create | Fixture plan with multiple tasks of varying shape. |
| `tests/verifying-plan-completion/seeded-implementation/` | Create | Directory of fixture files representing a branch state with seeded MISSING / PARTIAL / scope-creep / incidental-fix / refactor seeds. |
| `tests/verifying-plan-completion/expected-report.md` | Create | The report a correct verifier should produce against the seeded fixture. Used by `test.sh` for structural assertions. |
| `tests/verifying-plan-completion/test.sh` | Create | Fixture-driven structural assertions, mirroring `tests/hardening-plans/test.sh` style. |

Each task below produces a self-contained, committable change.

---

## Task 1: Create the test fixture (sample plan + seeded implementation)

**Files:**
- Create: `tests/verifying-plan-completion/sample-plan.md`
- Create: `tests/verifying-plan-completion/seeded-implementation/feature-a.txt`
- Create: `tests/verifying-plan-completion/seeded-implementation/feature-b.txt`
- Create: `tests/verifying-plan-completion/seeded-implementation/incidental-bugfix.txt`
- Create: `tests/verifying-plan-completion/seeded-implementation/scope-creep.txt`
- Create: `tests/verifying-plan-completion/seeded-implementation/refactor-covered.txt`
- Create: `tests/verifying-plan-completion/seeded-implementation/README.md` (explains seeds; not consumed by test.sh)

The fixture is text files (not real code) — the verifier's job is to map plan items to file changes regardless of language. Each file is marked at the top with a `FIXTURE ONLY` banner, so a future agent doesn't accidentally treat them as production artifacts.

- [ ] **Step 1: Write the sample plan**

Path: `tests/verifying-plan-completion/sample-plan.md`

```markdown
<!-- FIXTURE ONLY — consumed by tests/verifying-plan-completion/test.sh. Not a real plan. -->
# Sample Plan (Fixture)

**Goal:** Two-feature fixture for the verifying-plan-completion skill.

## Task 1: Implement feature A

**Files:**
- Create: `feature-a.txt`

- [ ] Add a file `feature-a.txt` whose first line is `feature-a: implemented`.

## Task 2: Implement feature B with acceptance criterion

**Files:**
- Create: `feature-b.txt`

- [ ] Add a file `feature-b.txt` whose first line is `feature-b: implemented` AND whose second line is `acceptance: AC-2 satisfied`.

## Task 3: Implement feature C

**Files:**
- Create: `feature-c.txt`

- [ ] Add a file `feature-c.txt` whose first line is `feature-c: implemented`.
  This task is intentionally NOT implemented in the seeded fixture (MISSING seed).
```

- [ ] **Step 2: Write feature A seed (satisfies Task 1)**

Path: `tests/verifying-plan-completion/seeded-implementation/feature-a.txt`

```
FIXTURE ONLY
feature-a: implemented
```

- [ ] **Step 3: Write feature B seed (PARTIAL — missing acceptance criterion)**

Path: `tests/verifying-plan-completion/seeded-implementation/feature-b.txt`

```
FIXTURE ONLY
feature-b: implemented
```

(No `acceptance: AC-2 satisfied` line — this is the PARTIAL seed.)

- [ ] **Step 4: Write incidental-bugfix seed**

Path: `tests/verifying-plan-completion/seeded-implementation/incidental-bugfix.txt`

```
FIXTURE ONLY
incidental: typo fixed in adjacent area while implementing feature-a
classification-hint: incidental-fix
rationale-hint: small, same area as feature-a, no new public surface, no new behavior
```

- [ ] **Step 5: Write scope-creep seed**

Path: `tests/verifying-plan-completion/seeded-implementation/scope-creep.txt`

```
FIXTURE ONLY
unsolicited-feature: added a brand-new public capability not in the plan
classification-hint: scope-creep
```

- [ ] **Step 6: Write refactor-covered seed**

Path: `tests/verifying-plan-completion/seeded-implementation/refactor-covered.txt`

```
FIXTURE ONLY
refactor: extracted a constant in code touched by feature-a; covered by existing tests
classification-hint: refactor
rationale-hint: behavior unchanged; existing tests still pass
```

- [ ] **Step 7: Write README explaining the seeds**

Path: `tests/verifying-plan-completion/seeded-implementation/README.md`

```markdown
<!-- FIXTURE ONLY — explanatory notes for the seeded implementation. -->

# Seeded Implementation (Fixture)

This directory simulates a branch state after executing `sample-plan.md`.
Each file is a seed for a specific verifier outcome:

| File | Plan task | Expected verifier finding |
|---|---|---|
| `feature-a.txt` | Task 1 | satisfied |
| `feature-b.txt` | Task 2 | PARTIAL (missing AC-2 line) |
| (none for feature-c) | Task 3 | MISSING |
| `incidental-bugfix.txt` | — | EXTRA, classification: incidental-fix |
| `scope-creep.txt` | — | EXTRA, classification: scope-creep |
| `refactor-covered.txt` | — | EXTRA, classification: refactor |
```

- [ ] **Step 8: Commit**

```bash
git add tests/verifying-plan-completion/sample-plan.md tests/verifying-plan-completion/seeded-implementation/
git commit -m "test(verifying-plan-completion): add sample plan and seeded implementation fixture"
```

---

## Task 2: Write the expected report and the failing test harness

**Files:**
- Create: `tests/verifying-plan-completion/expected-report.md`
- Create: `tests/verifying-plan-completion/test.sh`

- [ ] **Step 1: Write the expected report**

Path: `tests/verifying-plan-completion/expected-report.md`

```markdown
<!-- FIXTURE ONLY — what a correct verifier should produce against seeded-implementation/. -->

STATUS: both

MISSING:
- Task 3 (feature C): "Add a file feature-c.txt whose first line is 'feature-c: implemented'"
  evidence searched: seeded-implementation/feature-c.txt (absent)

PARTIAL:
- Task 2 (feature B): missing line "acceptance: AC-2 satisfied"

EXTRA:
- seeded-implementation/incidental-bugfix.txt
  classification: incidental-fix
  rationale: small, same area as feature-a, no new public surface, no new behavior
- seeded-implementation/scope-creep.txt
  classification: scope-creep
  rationale: introduces a new public capability not in the plan
- seeded-implementation/refactor-covered.txt
  classification: refactor
  rationale: behavior unchanged; existing tests still pass

EVIDENCE TABLE:
| Plan item | Status | File(s) |
| Task 1 (feature A) | satisfied | seeded-implementation/feature-a.txt |
| Task 2 (feature B) | partial   | seeded-implementation/feature-b.txt |
| Task 3 (feature C) | missing   | (none) |
```

- [ ] **Step 2: Write the test harness**

Path: `tests/verifying-plan-completion/test.sh`

```bash
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

  # Verifier prompt structural markers.
  for marker in \
    "READ-ONLY" \
    "STATUS:" \
    "MISSING" "EXTRA" "PARTIAL" "EVIDENCE TABLE" \
    "incidental-fix" "scope-creep" "refactor" "unknown"; do
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
```

- [ ] **Step 3: Make the harness executable and run static mode — expect FAIL**

Run: `chmod +x tests/verifying-plan-completion/test.sh && bash tests/verifying-plan-completion/test.sh static`
Expected: FAIL with `missing SKILL.md` (because the skill files do not exist yet).

- [ ] **Step 4: Validate against `expected-report.md` — expect PASS**

Run: `bash tests/verifying-plan-completion/test.sh report tests/verifying-plan-completion/expected-report.md`
Expected: `OK: report matches expected classification shape`.

This proves the harness's `report` mode is correctly tuned to the expected output before any skill content is written.

- [ ] **Step 5: Commit**

```bash
git add tests/verifying-plan-completion/expected-report.md tests/verifying-plan-completion/test.sh
git commit -m "test(verifying-plan-completion): add expected report and test harness"
```

---

## Task 3: Author SKILL.md (procedure + classification + auto-loop + integration)

**Files:**
- Create: `skills/verifying-plan-completion/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

Path: `skills/verifying-plan-completion/SKILL.md`

```markdown
---
name: verifying-plan-completion
description: Use at the end of plan execution, before finishing-a-development-branch, to audit that every plan item was implemented and only plan items were implemented
---

# Verifying Plan Completion

## Overview

End-of-plan completeness audit. Compares the written plan against the branch diff (merge-base → HEAD). Emits a structured report and drives a bounded fix-loop until the report is `clean` or escalates.

**Announce at start:** "I'm using the verifying-plan-completion skill to audit plan-vs-implementation."

**Per-task verification is out of scope.** SDD's `spec-reviewer-prompt.md` continues to handle that. This skill runs once, at the end.

## When to Use

- Invoked by `superpowers:executing-plans` after all tasks complete, before `finishing-a-development-branch`.
- Invoked by `superpowers:subagent-driven-development` after the per-task loop completes, replacing the "final code reviewer" step.
- Required precondition for `superpowers:finishing-a-development-branch` when invoked from a plan-execution context.

## Inputs

- `plan_path` — passed by the invoker. If absent, use the most recent file under `docs/superpowers/plans/`.
- `spec_path` — optional; derive from the plan if linked.
- `base_ref` — merge-base with the base branch (try `main`, then `master`, else ask the human partner).
- `head_ref` — current `HEAD`.
- `branch_name`, `commit_list` — for the evidence table.

## Mode Selection

- **Subagent mode (preferred):** if subagents are available, dispatch a fresh verifier subagent using `./verifier-prompt.md`. The subagent is READ-ONLY (search, read, analyze; no writes, no human prompts).
- **Inline mode (fallback):** if subagents are unavailable, the controller follows the inline procedure in this file.

## Output: Structured Report

```
STATUS: clean | gaps | scope-creep | both

MISSING:
- <plan §/task ref>: <quoted requirement>
  evidence searched: <files/symbols/commits checked>

PARTIAL:
- <plan §>: <what is missing>

EXTRA:
- <file:lines>: <one-line description>
  classification: incidental-fix | refactor | scope-creep | unknown
  rationale: <one line>

EVIDENCE TABLE:
| Plan item | Status | Commit(s) | File(s) |
```

## Classification Rules (EXTRA)

| Class | Definition | Verdict |
|---|---|---|
| `incidental-fix` | Bug uncovered while implementing a plan item; small; same area; no new public surface. Rationale must justify all four. | Pass |
| `refactor` | Restructuring without behavior change, in code touched by the plan. | Pass only if covered by existing tests; otherwise fail. |
| `scope-creep` | New features, new files, or new public APIs not mentioned in the plan. | Fail. |
| `unknown` | Cannot trace to plan; not clearly incidental. | Treated as `scope-creep`. |

Every `incidental-fix` and `refactor` MUST include a one-line rationale that satisfies the definition. Unjustified classifications are automatically promoted to `scope-creep`.

## Inline Procedure

When subagents are not available, the controller does this:

1. Read the plan. Enumerate every task and acceptance criterion as a line-item list.
2. Compute the diff range: `git merge-base HEAD <base-branch>` → `HEAD`. Capture file list and per-file hunks.
3. For each plan line-item: locate corresponding hunks/files. Mark `satisfied`, `partial`, or `missing`. Record evidence.
4. For each diff hunk not claimed by a plan line-item: classify per the table above. Record file/lines, classification, and rationale.
5. Emit the structured report.

## Auto-Loop

```
MAX_ITERATIONS = 3
iteration = 0

loop:
    report = verify(plan, base..head)
    if report.STATUS == "clean":
        proceed to finishing-a-development-branch
        break

    iteration += 1
    if iteration > MAX_ITERATIONS:
        escalate to human partner with full report and per-iteration history
        STOP

    for each MISSING / PARTIAL:
        dispatch implementer (SDD) or fix inline (executing-plans)

    for each EXTRA where classification ∈ {scope-creep, unknown}:
        revert hunk, OR ask human partner to amend the plan

    commit fixes
    # next iteration
```

### Termination

| Condition | Action |
|---|---|
| `STATUS: clean` | Proceed to `finishing-a-development-branch`. |
| Loop budget exhausted | STOP. Surface full report + per-iteration history. Do not proceed. |
| Human chooses to amend plan | Update plan doc, commit, re-verify (consumes one iteration). |

## Error Handling

- No plan path resolvable → STOP. Point at `superpowers:writing-plans`.
- No base branch resolvable → ask human partner; do not guess.
- Diff empty, plan non-empty → MISSING for every plan item; report normally.
- Plan amended mid-loop → re-derive plan items; counts as one iteration.
- Subagent verifier fails or times out → fall back to inline procedure; if that also fails, escalate.

## Integration

**Required workflow skills:**
- **superpowers:writing-plans** — produces the plan this skill audits.
- **superpowers:executing-plans** — invokes this skill before finishing.
- **superpowers:subagent-driven-development** — invokes this skill in place of the prior "final code reviewer" step.
- **superpowers:finishing-a-development-branch** — gated by a `clean` result from this skill when invoked from a plan-execution context.

**Out of scope:**
- Per-task spec compliance (handled by SDD's `spec-reviewer-prompt.md`, unchanged).
- General "evidence before claims" gating (handled by `superpowers:verification-before-completion`).
```

- [ ] **Step 2: Run static check — expect partial improvement**

Run: `bash tests/verifying-plan-completion/test.sh static`
Expected: still FAIL — `verifier-prompt.md` is still missing and integration hooks are not in place yet.

- [ ] **Step 3: Commit**

```bash
git add skills/verifying-plan-completion/SKILL.md
git commit -m "feat(skills): add verifying-plan-completion SKILL.md"
```

---

## Task 4: Author verifier-prompt.md (subagent template)

**Files:**
- Create: `skills/verifying-plan-completion/verifier-prompt.md`

- [ ] **Step 1: Write the prompt**

Path: `skills/verifying-plan-completion/verifier-prompt.md`

```markdown
# Verifier Subagent Prompt

This is a READ-ONLY research task. Do NOT create, edit, or delete any files. Do NOT ask the human partner questions. Only search, read, and analyze. Return your findings in your final report.

## Inputs you will receive

- `plan_path`: absolute path to the plan file.
- `base_ref`: git ref or SHA representing the merge-base with the base branch.
- `head_ref`: current `HEAD` ref or SHA.
- (Optional) `spec_path`: absolute path to the spec file.

## What to do

1. Read the plan file in full. Enumerate every task and every acceptance criterion as a flat line-item list.
2. Compute the diff range `<base_ref>..<head_ref>`. Capture the list of changed files and per-file hunks.
3. For each plan line-item, search the diff for evidence it was implemented. Mark each as `satisfied`, `partial`, or `missing`. Record the files/symbols you searched.
4. For each diff hunk not claimed by a plan line-item, classify it using the rules below. Record file/lines, classification, and a one-line rationale.
5. Produce the structured report exactly in the schema below.

## Classification rules (EXTRA hunks)

| Class | Definition | Verdict |
|---|---|---|
| `incidental-fix` | Bug uncovered while implementing a plan item; small; same area; no new public surface. Rationale must justify all four. | Pass |
| `refactor` | Restructuring without behavior change, in code touched by the plan. | Pass only if covered by existing tests; otherwise fail. |
| `scope-creep` | New features, new files, or new public APIs not in the plan. | Fail |
| `unknown` | Cannot trace to plan; not clearly incidental. | Treat as `scope-creep` |

Every `incidental-fix` and `refactor` MUST include a one-line rationale satisfying the definition. Unjustified classifications are automatically promoted to `scope-creep`.

## Output schema

Emit exactly this shape, with no surrounding prose:

```
STATUS: clean | gaps | scope-creep | both

MISSING:
- <plan §/task ref>: <quoted requirement>
  evidence searched: <files/symbols/commits checked>

PARTIAL:
- <plan §>: <what is missing>

EXTRA:
- <file:lines>: <one-line description>
  classification: incidental-fix | refactor | scope-creep | unknown
  rationale: <one line>

EVIDENCE TABLE:
| Plan item | Status | Commit(s) | File(s) |
```

`STATUS` must be:
- `clean` if MISSING and PARTIAL are empty AND every EXTRA is `incidental-fix` or `refactor` (with valid rationale).
- `gaps` if any MISSING or PARTIAL is non-empty AND no `scope-creep`/`unknown` EXTRA.
- `scope-creep` if any EXTRA is `scope-creep` or `unknown` AND MISSING and PARTIAL are empty.
- `both` if both kinds of issue are present.

Return only the report. No commentary, no apologies, no recommendations beyond the report itself.
```

- [ ] **Step 2: Run static check — expect partial improvement**

Run: `bash tests/verifying-plan-completion/test.sh static`
Expected: FAIL — integration hooks still missing in caller skills.

- [ ] **Step 3: Commit**

```bash
git add skills/verifying-plan-completion/verifier-prompt.md
git commit -m "feat(skills): add verifying-plan-completion verifier prompt"
```

---

## Task 5: Wire `executing-plans` integration

**Files:**
- Modify: `skills/executing-plans/SKILL.md`

- [ ] **Step 1: Insert Step 2.5 between current Step 2 and Step 3**

Open `skills/executing-plans/SKILL.md`. Locate the heading `### Step 3: Complete Development`. Insert immediately before it:

```markdown
### Step 2.5: Verify Plan Completion

After all tasks are complete and individually verified, audit the whole plan against the implementation:

- Announce: "I'm using the verifying-plan-completion skill to audit plan-vs-implementation."
- **REQUIRED SUB-SKILL:** Use `superpowers:verifying-plan-completion`. Pass the plan path explicitly.
- Do NOT proceed to Step 3 until the skill reports `STATUS: clean`. If the loop budget is exhausted, stop and surface the report to your human partner.

```

- [ ] **Step 2: Run static check — expect partial improvement**

Run: `bash tests/verifying-plan-completion/test.sh static`
Expected: still FAIL — SDD, finishing, and verification cross-ref still missing.

- [ ] **Step 3: Commit**

```bash
git add skills/executing-plans/SKILL.md
git commit -m "feat(skills): wire verifying-plan-completion into executing-plans"
```

---

## Task 6: Wire `subagent-driven-development` integration

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md`

- [ ] **Step 1: Replace the "final code reviewer" terminal node**

Open `skills/subagent-driven-development/SKILL.md`. In the process diagram and prose, replace every reference to:

> "Dispatch final code reviewer subagent for entire implementation"

with:

> "Invoke `superpowers:verifying-plan-completion` for the whole plan"

Update the diagram so the node `"Dispatch final code reviewer subagent for entire implementation"` becomes `"Invoke superpowers:verifying-plan-completion for the whole plan"`, preserving all incoming and outgoing edges.

Add a single clarifying sentence immediately after the diagram (or at the top of the "Process" section): 

```markdown
> Per-task spec compliance is unchanged — `./spec-reviewer-prompt.md` still runs after each task. The skill `superpowers:verifying-plan-completion` runs once at the end and audits the whole plan.
```

- [ ] **Step 2: Run static check — expect partial improvement**

Run: `bash tests/verifying-plan-completion/test.sh static`
Expected: still FAIL — finishing and cross-ref still missing.

- [ ] **Step 3: Commit**

```bash
git add skills/subagent-driven-development/SKILL.md
git commit -m "feat(skills): wire verifying-plan-completion into subagent-driven-development"
```

---

## Task 7: Wire `finishing-a-development-branch` gate

**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md`

- [ ] **Step 1: Add Step 1b after Step 1 (Verify Tests)**

Open `skills/finishing-a-development-branch/SKILL.md`. Immediately after the `### Step 1: Verify Tests` block (and its "If tests fail / If tests pass" subsections), insert:

```markdown
### Step 1b: Verify Plan Completion (when invoked from a plan-execution context)

If this skill was invoked from `superpowers:executing-plans` or `superpowers:subagent-driven-development` (i.e., a plan path is in scope for this session), the plan-completion audit MUST have already run and reported `STATUS: clean`.

- If you cannot confirm a `clean` plan-completion audit ran in this session, STOP and invoke `superpowers:verifying-plan-completion` before proceeding to Step 2.
- If this skill was invoked outside a plan-execution context (no plan in scope), skip this step.

```

- [ ] **Step 2: Run static check — expect partial improvement**

Run: `bash tests/verifying-plan-completion/test.sh static`
Expected: still FAIL — `verification-before-completion` cross-ref still missing.

- [ ] **Step 3: Commit**

```bash
git add skills/finishing-a-development-branch/SKILL.md
git commit -m "feat(skills): gate finishing-a-development-branch on plan completion"
```

---

## Task 8: Cross-reference in `verification-before-completion`

**Files:**
- Modify: `skills/verification-before-completion/SKILL.md`

- [ ] **Step 1: Update the "Requirements met" row of the Common Failures table**

Open `skills/verification-before-completion/SKILL.md`. Locate the row:

```markdown
| Requirements met | Line-by-line checklist | Tests passing |
```

Replace it with:

```markdown
| Requirements met | Line-by-line checklist (or `superpowers:verifying-plan-completion` for full plans) | Tests passing |
```

Do not duplicate the new skill's logic into this file. The cross-reference is intentionally minimal.

- [ ] **Step 2: Run static check — expect PASS**

Run: `bash tests/verifying-plan-completion/test.sh static`
Expected: `OK: static checks pass`.

- [ ] **Step 3: Run report-mode check — expect PASS**

Run: `bash tests/verifying-plan-completion/test.sh report tests/verifying-plan-completion/expected-report.md`
Expected: `OK: report matches expected classification shape`.

- [ ] **Step 4: Commit**

```bash
git add skills/verification-before-completion/SKILL.md
git commit -m "docs(skills): cross-reference verifying-plan-completion from verification-before-completion"
```

---

## Task 9: Final verification pass

**Files:** none

- [ ] **Step 1: Re-run both test modes from the repo root**

```bash
bash tests/verifying-plan-completion/test.sh static
bash tests/verifying-plan-completion/test.sh report tests/verifying-plan-completion/expected-report.md
```

Both must print `OK: ...`.

- [ ] **Step 2: Visual smoke test — read each modified skill end-to-end**

Open each of:
- `skills/verifying-plan-completion/SKILL.md`
- `skills/verifying-plan-completion/verifier-prompt.md`
- `skills/executing-plans/SKILL.md`
- `skills/subagent-driven-development/SKILL.md`
- `skills/finishing-a-development-branch/SKILL.md`
- `skills/verification-before-completion/SKILL.md`

Confirm: integration prose is coherent end-to-end; the per-task vs. end-of-plan distinction is unambiguous in SDD; `finishing-a-development-branch` correctly skips the gate when no plan is in scope.

- [ ] **Step 3: Spec coverage walk**

Re-open `docs/superpowers/specs/2026-05-05-verifying-plan-completion-design.md`. For each section (Architecture, Verifier Contract, Auto-Loop, Data Flow, Error Handling, Testing), point at the task that implements it. Note any gap. If a gap exists, add a follow-up task; do not silently move on.

- [ ] **Step 4: No commit needed if Steps 1–3 pass clean.** Otherwise fix and commit per-issue.
```
