# Verifying Plan Completion — Design

**Date:** 2026-05-05
**Status:** Approved by human partner; ready for implementation planning.

## Problem

After executing an implementation plan, no skill performs a holistic audit that *every* plan item was implemented and *only* plan items were implemented. The current state:

- `executing-plans` runs verifications defined inside the plan, but never re-reads the plan to confirm completeness.
- `subagent-driven-development` has a per-task spec-reviewer (`spec-reviewer-prompt.md`) and a vague "final code reviewer" pass — no structured plan-vs-implementation audit.
- `finishing-a-development-branch` only verifies that tests pass; it does not check whether the work matches the plan.
- `verification-before-completion` is a general "evidence before claims" gate, not a structured plan-completion procedure.

Result: silent gaps (missed plan items) and silent scope creep (code added that the plan never asked for) reach merge/PR.

## Goal

Introduce a single, shared end-of-plan completeness audit that both execution paths invoke before finishing. Per-task verification (already strong inside SDD) is out of scope and unchanged.

## Non-Goals

- Replacing or modifying SDD's per-task `spec-reviewer-prompt.md`.
- Generalizing `verification-before-completion`. It remains a general gate; the new skill is the specific procedure for plan completion.
- Verifying acceptance criteria of individual tasks beyond what the plan states (the plan's own per-task verification commands cover that).

## Solution Overview

A new skill `verifying-plan-completion` runs once at the end of plan execution. It compares the written plan against the branch diff (merge-base → HEAD) and emits a structured report classifying every plan item and every diff hunk. An auto-loop drives fixes until the report is clean, or escalates to the human partner after a bounded number of iterations.

The skill is subagent-preferred: when subagents are available, a fresh verifier subagent is dispatched with `verifier-prompt.md`. When subagents are unavailable (the `executing-plans` path), the controller follows an inline procedure defined in the SKILL.

## Architecture

### New Files

- `skills/verifying-plan-completion/SKILL.md` — skill content, inline procedure, integration notes.
- `skills/verifying-plan-completion/verifier-prompt.md` — subagent prompt template.

### Modified Files

| File | Change |
|---|---|
| `skills/executing-plans/SKILL.md` | Insert **Step 2.5: Verify Plan Completion** before Step 3. Required sub-skill invocation. |
| `skills/subagent-driven-development/SKILL.md` | Replace the existing "Dispatch final code reviewer subagent for entire implementation" node with `superpowers:verifying-plan-completion`. Clarify the per-task `spec-reviewer-prompt.md` is unchanged and distinct. |
| `skills/finishing-a-development-branch/SKILL.md` | Step 1 gains a sibling check: when invoked from a plan-execution context (plan path known), require that plan-completion verification has run with `clean` status in this session. If not, abort with a pointer to the new skill. |
| `skills/verification-before-completion/SKILL.md` | Add a one-line cross-reference under the "Requirements met" row of the Common Failures table pointing at `verifying-plan-completion`. Do not duplicate logic. |

## Verifier Contract

### Inputs

- `plan_path` — path to the plan file (passed by invoker; if absent, most recent under `docs/superpowers/plans/`).
- `spec_path` — optional, derived from the plan's front-matter or first link if present.
- `base_ref` — merge-base of branch with its base branch (auto-detected: `main` then `master`, else ask).
- `head_ref` — current HEAD.
- `branch_name`, `commit_list` — for evidence reporting.

### Output (structured report)

```
STATUS: clean | gaps | scope-creep | both

MISSING (plan items with no corresponding implementation):
- <plan §/task ref>: <quoted requirement>
  evidence searched: <files/symbols/commits checked>

EXTRA (changes not traceable to a plan item):
- <file:lines>: <one-line description>
  classification: incidental-fix | refactor | scope-creep | unknown
  rationale: <one line>

PARTIAL (plan item present but acceptance criteria unmet):
- <plan §>: <what is missing>

EVIDENCE TABLE:
| Plan item | Status | Commit(s) | File(s) |
| ...       | ...    | ...       | ...     |
```

### Extras Classification Rules

| Class | Definition | Verdict |
|---|---|---|
| `incidental-fix` | Bug uncovered while implementing a plan item; small; same area; no new public surface. Rationale must justify all four. | Pass |
| `refactor` | Restructuring without behavior change, in code touched by the plan. | Pass only if covered by existing tests; otherwise fail. |
| `scope-creep` | New features, new files, new public APIs not mentioned in the plan. | Fail. |
| `unknown` | Cannot trace to plan, not clearly incidental. | Treated as `scope-creep`. |

Every `incidental-fix` and `refactor` classification MUST include a one-line rationale satisfying the definition. Unjustified classifications are automatically promoted to `scope-creep`.

## Auto-Loop

```
MAX_ITERATIONS = 3
iteration = 0

loop:
    report = verify(plan, base..head)

    if report.status == "clean":
        proceed to finishing-a-development-branch

    iteration += 1
    if iteration > MAX_ITERATIONS:
        escalate to human with full report and per-iteration history
        STOP

    for item in report.MISSING + report.PARTIAL:
        dispatch implementer (SDD) or fix inline (executing-plans)

    for item in report.EXTRA where classification ∈ {scope-creep, unknown}:
        revert hunk OR ask human to amend plan

    commit fixes
    # next iteration
```

### Termination

| Condition | Action |
|---|---|
| `STATUS: clean` | Proceed to `finishing-a-development-branch`. |
| Loop budget exhausted | STOP. Surface full report + per-iteration history to human. Do not proceed. |
| Human chooses to amend plan | Update plan document, commit, re-verify (consumes one iteration). |

## Data Flow

```
plan file ──┐
            ├─► verifier (subagent or inline) ─► structured report
git diff ──┘                                         │
                                                     ▼
                                         clean? ──yes─► finishing
                                           │
                                           no
                                           ▼
                                       fix loop ─► (re-verify)
                                           │
                                  budget exhausted
                                           ▼
                                       escalate
```

## Error Handling

- **No plan path resolvable** → STOP with a clear error pointing at `writing-plans`.
- **No base branch resolvable** → ask human partner; do not guess.
- **Diff empty** but plan non-empty → MISSING for every plan item; report normally.
- **Plan amended mid-loop** → re-derive plan items; counts as one iteration.
- **Verifier subagent fails / times out** → fall back to inline procedure; if that also fails, escalate.

## Testing

Following the repository convention used by `tests/hardening-plans/`:

- `tests/verifying-plan-completion/sample-plan.md` — fixture plan with multiple tasks of varying shape.
- `tests/verifying-plan-completion/seeded-implementation/` — a branch state seeded with:
  - one MISSING plan task
  - one PARTIAL task (implemented but acceptance criteria unmet)
  - one `scope-creep` file (new feature not in plan)
  - one legitimate `incidental-fix`
  - one `refactor` covered by existing tests
- `tests/verifying-plan-completion/test.sh` — runs the verifier against the fixture and asserts:
  - structured report classifies each seeded item correctly
  - auto-loop converges to `clean` when seeds are fixable
  - loop-budget exhaustion surfaces correctly when seeds are intentionally unfixable
  - inline-mode and subagent-mode produce equivalent reports on the same fixture

## Integration Summary

```
executing-plans ──────────────► verifying-plan-completion ──► finishing-a-development-branch
subagent-driven-development ──►              (shared)              (gated)
```

Per-task verification inside SDD (`spec-reviewer-prompt.md`) is unchanged.

## Open Questions

None at design time. Implementation plan will surface any.
