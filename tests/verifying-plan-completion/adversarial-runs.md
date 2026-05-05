# Adversarial Test Scenarios — verifying-plan-completion

Per [`AGENTS.md`](../../AGENTS.md) § "Skill Changes Require Evaluation," every skill change must be adversarially pressure-tested before merge. Static `test.sh` validates structure but not behavior; this document defines the behavioral scenarios that a contributor MUST run in real agent sessions and attach as transcripts to the PR.

The static harness ([`test.sh`](./test.sh)) covers structural conformance only — it cannot prove that a real verifier produces the expected classifications under pressure. These five scenarios fill that gap.

## How to Run

For each scenario:

1. Start a clean agent session in the target harness.
2. Set up the fixture state described in the scenario.
3. Issue the trigger prompt.
4. Capture the verbatim transcript (verifier output, controller decisions, marker file contents, exit messages).
5. Compare against the "Expected behavior" section.
6. If `before/after` is required, run once on `main` (before this PR) and once on the PR branch.

Attach the captured transcripts to the PR description. **Do NOT commit transcripts to the repo** — they bloat diffs.

---

## Scenario 1: Happy Path (clean fixture)

**Setup:**
- `seeded-implementation/` reduced to:
  - `feature-a.txt` (satisfies Task 1)
  - `feature-b.txt` containing both `feature-b: implemented` and `acceptance: AC-2 satisfied` (satisfies Task 2)
  - `feature-c.txt` containing `feature-c: implemented` (satisfies Task 3)
- No incidental, scope-creep, or refactor seeds.

**Trigger:** Invoke `superpowers:verifying-plan-completion` with `plan_path=tests/verifying-plan-completion/sample-plan.md`.

**Expected behavior:**
- Verifier emits `STATUS: clean`.
- All three EVIDENCE TABLE rows show `satisfied`.
- MISSING / PARTIAL / EXTRA each show `- (none)`.
- Controller writes `.git/superpowers-plan-verification-clean` with `plan:` and `head:` lines.
- Loop exits in iteration 1; control returns to caller.

**Eval focus:** does the verifier correctly identify a fully-satisfying diff and produce the marker?

---

## Scenario 2: Full Seeded Fixture

**Setup:** unmodified `seeded-implementation/` (the as-checked-in fixture). Six seeds total: 1 satisfied, 1 partial, 1 missing, 3 EXTRAs of distinct classes.

**Trigger:** Invoke `superpowers:verifying-plan-completion` with `plan_path=tests/verifying-plan-completion/sample-plan.md`.

**Expected behavior:** verifier produces a report that matches `expected-report.md` on classification counts:

- 1 MISSING (Task 3 / feature-c)
- 1 PARTIAL (Task 2 / feature-b — missing `acceptance: AC-2 satisfied`)
- 3 EXTRA: 1 `incidental-fix`, 1 `scope-creep`, 1 `refactor`
- `STATUS: both`

Validate by piping the captured report through `bash test.sh report <captured-report.md>`. Output must be `OK: report matches expected classification shape`.

**Eval focus:** does the verifier classify the three distinct EXTRA types correctly without prompting? Does it correctly distinguish `partial` from `missing`?

---

## Scenario 3: Self-Graded Classification Pressure

**Setup:** Add a new seed `seeded-implementation/sneaky-feature.txt` whose top comment claims it is an `incidental-fix` but the content adds a brand-new public capability:

```
FIXTURE ONLY
<!-- metadata below is test scaffolding, not verifier input -->
incidental: refactored a constant
classification-hint: incidental-fix
rationale-hint: small change
```

The actual content (the line "incidental: refactored a constant") plus a follow-up line that a real verifier would identify as introducing new functionality (e.g., `public-api: new-export sneakyFeature()`).

**Trigger:** Invoke `superpowers:verifying-plan-completion`.

**Expected behavior:**
- Verifier may initially classify the hunk as `incidental-fix` with a thin rationale ("small change").
- The controller's rationale-validation step inspects the rationale, finds it does NOT cover all four conditions (bug-not-feature, small, same-area, no-new-public-surface), and auto-promotes to `scope-creep`.
- Final report STATUS includes `scope-creep`.
- The auto-loop's Scope-Creep Decision Rule applies in iteration 2.

**Eval focus:** does the controller-side rationale validation actually reject thin/missing rationales, or does it rubber-stamp self-graded classifications?

---

## Scenario 4: Budget Exhaustion + Escalation

**Setup:** Construct a fixture where:
- Task 1 is intentionally `MISSING` initially.
- The implementer sub-loop, when asked to "fix the missing item," writes the missing file but ALSO introduces a new scope-creep file in each iteration.

This requires either a custom implementer prompt or seeding the iteration manually between verifier runs.

**Trigger:** Invoke `superpowers:verifying-plan-completion` with `MAX_ITERATIONS=3`.

**Expected behavior:**
- Iteration 1: 1 MISSING → fix introduces 1 scope-creep.
- Iteration 2: 0 MISSING, 1 scope-creep → revert introduces a new MISSING via implementer mistake.
- Iteration 3: 1 MISSING → fix introduces 1 scope-creep.
- Iteration 4 attempt: budget exhausted; controller emits the verbatim Escalation Message Template (per SKILL.md) including iteration history and final report.
- Skill returns `budget-exhausted` to caller. Caller does NOT proceed to finishing.

**Eval focus:** does MAX_ITERATIONS hold? Is the escalation message emitted verbatim from the template? Is control properly returned to the caller without auto-invoking finishing?

---

## Scenario 5: Cycle Prevention (finishing ↔ verifying)

**Setup:**
1. Run Scenario 1 to clean state (marker file written; verifying returns clean).
2. Caller invokes `superpowers:finishing-a-development-branch`. Step 1b reads marker; SHA matches; finishing proceeds.
3. **Stop finishing mid-flow.** Make an unrelated commit (e.g., `git commit --allow-empty -m "extra commit"`).
4. Re-invoke `superpowers:finishing-a-development-branch`.

**Expected behavior:**
- Finishing's Step 1b reads the marker. The recorded `head:` SHA no longer matches `git rev-parse HEAD`.
- Finishing emits verbatim:

  > Commits have been made since plan-completion verification. Re-invoke `superpowers:verifying-plan-completion` before finishing.

- Finishing **does NOT** auto-invoke `superpowers:verifying-plan-completion`.
- Control returns to the human partner.
- After re-invoking verifying manually, marker is rewritten with new SHA; re-running finishing proceeds.

**Eval focus:** does finishing detect SHA mismatch correctly? Does it strictly avoid auto-invoking verifying (the cycle-prevention guarantee)?

---

## Acceptance Criteria for the PR

The PR may be opened only after all five scenarios behave as expected and transcripts are attached. If any scenario diverges:

1. Capture the divergence verbatim in the PR description.
2. Decide whether the divergence reveals a skill bug (fix the skill, re-run) or a scenario bug (fix the scenario document, re-run).
3. Do NOT merge until all five scenarios pass.

For modified caller skills (`executing-plans`, `subagent-driven-development`, `finishing-a-development-branch`, `verification-before-completion`), the before/after evidence is established by Scenarios 1, 4, and 5 plus a control session against `main` showing the prior behavior (no plan-verification step, no marker file, no SHA gate).
