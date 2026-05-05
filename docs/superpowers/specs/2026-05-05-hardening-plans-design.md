# Hardening Plans Skill — Design Spec

**Date:** 2026-05-05
**Status:** Approved (pending user review)
**Type:** New skill + integration into existing workflow

---

## 1. Purpose & Scope

Add a new skill, `hardening-plans`, that runs after a plan is written (by `writing-plans`) and before it is executed (by `executing-plans` or `subagent-driven-development`). Its job: produce the maximally-detailed plan ready for handoff to implementation.

It analyzes the plan across two axes:

- **ISSUES** — architectural gaps and introduced bugs.
- **IMPROVEMENTS** — UX, reusability, security, performance.

Analysis is delegated to parallel subagents (via the existing `dispatching-parallel-agents` skill, which decides decomposition). Findings are triaged by the main agent, approved by the user, and applied as in-place edits to the plan file. The process iterates until convergence (zero new actionable findings) or the user stops it.

## 2. Workflow Integration

- **`writing-plans`** invokes `hardening-plans` as its terminal step (instead of handing directly to execution).
- **`executing-plans`** and **`subagent-driven-development`** verify hardening ran by checking for a ledger file with status `converged` or `stopped-by-user`. If missing, they invoke `hardening-plans` before executing.

## 3. Process Flow

1. Announce: "I'm using the hardening-plans skill to harden the implementation plan."
2. Locate the plan file. If not provided, use the most recently modified file in `docs/superpowers/plans/`. If ambiguous, ask the user.
3. Initialize or load the ledger at `docs/superpowers/plans/<plan-basename>-hardening.md`.
   - If it exists: read prior iterations to dedupe against rejected/applied findings.
   - If new: create with the header described in §4.
4. Run an iteration (loop):
   1. Dispatch parallel analysis subagents (delegated to `dispatching-parallel-agents`). Each receives:
      - Full plan content.
      - Their concern axis (ISSUES, UX, reusability, security, or performance — exact decomposition decided by `dispatching-parallel-agents`).
      - Instruction to read the actual codebase, not just the plan, so findings are grounded in current code.
      - Ledger summary of previously rejected findings (do not re-raise verbatim).
      - Reference to relevant superpowers skills (e.g. `systematic-debugging`, `test-driven-development`, `verification-before-completion`).
      - Required output format: structured findings list (see §5).
      - Read-only constraint (per Section 0.5 of repo instructions): no file edits, no user interaction.
   2. Collect findings.
   3. Main-agent triage:
      - Drop duplicates of ledger-rejected items.
      - Merge overlapping findings across axes.
      - Drop low-signal noise.
   4. If zero actionable findings remain → record a convergence iteration entry, set ledger status to `converged`, announce convergence, exit loop.
   5. Present the filtered findings list to the user. User approves/rejects each (or batches).
   6. Apply approved findings: edit the plan in place — revise tasks, add notes, fix gaps, expand detail.
   7. Append the iteration entry to the ledger (timestamp, dispatched concerns, raw findings, triage decisions, applied diff summary).
   8. Commit plan + ledger together.
   9. Ask the user: "Run another hardening iteration?"
      - Yes → loop to (1).
      - No → set ledger status to `stopped-by-user`, exit loop.
5. Final state: announce next step (executing-plans or subagent-driven-development).

## 4. Ledger File Format

Path: `docs/superpowers/plans/<plan-basename>-hardening.md`

```markdown
# Hardening Ledger: <plan-name>

**Plan:** [<plan-name>.md](./<plan-name>.md)
**Status:** in-progress | converged | stopped-by-user

---

## Iteration N — YYYY-MM-DD HH:MM

**Dispatched concerns:** ISSUES, UX, reusability, security, performance
**Codebase commit at analysis:** <git-sha>

### Findings

#### F-N.1 — [severity: high|med|low] — [axis] — <short title>
- **Location in plan:** Task 3, Step 2
- **Description:** ...
- **Suggested change:** ...
- **Rationale (incl. codebase grounding):** ...
- **Decision:** applied | rejected | deferred
- **Reason (if rejected/deferred):** ...
- **Plan diff:** <one-line summary of edit, or "n/a">

### Iteration summary
- Findings raised: X | applied: Y | rejected: Z | deferred: W
- Plan commit: <sha>
```

A convergence iteration uses the same structure with `Findings raised: 0`; status flips to `converged`.

## 5. Subagent Prompt Template

Stored at `skills/hardening-plans/subagent-prompts.md` and referenced from `SKILL.md`:

```
ROLE: Plan-hardening analyst — <axis> concern.

INPUTS:
- Plan: <full content>
- Codebase root: <path>
- Previously-rejected findings (do NOT re-raise verbatim):
  <ledger excerpt>

TASK:
1. Read the plan thoroughly.
2. READ THE ACTUAL CODEBASE — open files the plan touches, follow imports,
   check existing patterns. Findings must be grounded in current code,
   not in plan text alone.
3. Apply your concern lens:
   - ISSUES: architectural gaps, missing tasks, ordering bugs, test coverage
     gaps, race conditions, breaking changes, integration mismatches.
   - UX: developer/end-user experience surfaced by the plan's deliverables —
     clarity of errors, defaults, accessibility, friction.
   - reusability: code the plan duplicates that already exists; opportunities
     to extract shared modules; unnecessary new abstractions.
   - security: OWASP Top 10, input validation, authn/authz, secret handling,
     dependency risks introduced.
   - performance: O(N) regressions, N+1 queries, blocking I/O, missing
     caching/batching, large-file/list handling.
4. Reference relevant superpowers skills if they sharpen analysis
   (systematic-debugging, test-driven-development, verification-before-completion).

OUTPUT: structured findings list. Each finding:
- severity (high|med|low)
- location_in_plan (task/step ref)
- description
- suggested_change
- rationale (with specific codebase evidence: file paths, line refs)

CONSTRAINTS (READ-ONLY): Do NOT modify files. Do NOT ask the user questions.
Search/read/analyze only. Return findings in your final report.
```

## 6. Files to Create / Modify

**Create:**

- `skills/hardening-plans/SKILL.md` — main skill content (name, description frontmatter, announce phrase, checklist, process flow, key principles).
- `skills/hardening-plans/subagent-prompts.md` — dispatch prompt template (§5).

**Modify:**

- `skills/writing-plans/SKILL.md` — terminal step invokes `hardening-plans` instead of routing directly to execution.
- `skills/executing-plans/SKILL.md` — Step 1 adds a precondition: ledger file exists with status `converged` or `stopped-by-user`; if missing, invoke `hardening-plans` first.
- `skills/subagent-driven-development/SKILL.md` — same precondition check as `executing-plans`.
- `skills/using-superpowers/SKILL.md` — only if it lists skills explicitly (verify during implementation).

## 7. Edge Cases & Error Handling

- **No plan file specified:** pick most recently modified file in `docs/superpowers/plans/`; ask user if ambiguous.
- **Plan modified mid-iteration outside the skill:** detect via file hash at iteration start; if changed, restart iteration with fresh read.
- **Subagent fails or returns malformed findings:** log the failure in ledger, retry that axis once; if it fails again, record as `axis-failed` and continue with other axes (user is informed).
- **User rejects every finding in an iteration:** convergence check uses *actionable findings after triage*, so a fully-rejected iteration can still mark `converged` if no new actionable items remain.
- **Session resumed later:** ledger contains all state; skill loads it, shows status, asks whether to run another iteration.
- **Plan radically changed by hardening:** plan and ledger are committed together each iteration so all changes are reversible via git.

## 8. Testing Strategy

- Fixture: `tests/hardening-plans/sample-plan.md` — a deliberately-flawed sample plan with seeded issues across all five axes.
- End-to-end script: `tests/hardening-plans/test.sh` — invokes the skill against the fixture in a sandbox and asserts:
  - Ledger file is created.
  - At least one finding per axis is raised on iteration 1.
  - Second iteration converges (or near-converges) after applying findings.
  - Plan diff is non-empty.

Mirrors the pattern used in `tests/skill-triggering/` and `tests/explicit-skill-requests/`.

## 9. Key Principles

- **Grounded findings** — every finding must cite specific codebase evidence; the codebase is re-read each iteration.
- **User in control** — main agent triages but never auto-applies findings without user approval.
- **Auditable iteration** — the ledger is the source of truth for convergence and dedup.
- **Read-only subagents** — analysis subagents never modify files or interact with the user, per Section 0.5 of the repo's master instructions.
- **YAGNI** — convergence stops the loop; do not invent findings to keep iterating.
