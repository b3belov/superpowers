# Hardening Ledger: 2026-05-05-verifying-plan-completion

**Plan:** [2026-05-05-verifying-plan-completion.md](./2026-05-05-verifying-plan-completion.md)
**Status:** in-progress
**Verified at commit:** caaa48b9f39b268d5b27554055f735367ff2de66

---

## Iteration 1 — 2026-05-05

**Dispatched concerns:** ISSUES, UX, reusability (security and performance skipped — plan touches markdown skill files only, no runtime code, network, or user input)
**Codebase commit at analysis:** f7682f7dd2028681a0a2e8de6a39eb89d56450ba
**Subagents dispatched:** 3 read-only Explore subagents in parallel
**Raw findings:** 34 (ISSUES: 17, UX: 10, reusability: 7)
**Triage:** 34 raw → 1 dropped as incorrect (F-N.14 — table row exists in actual file) → 1 dropped as no-change (F-1.6 author marked) → 6 dropped as noise (§-notation polish, empty-section formatting, cross-ref strengthening, MAX_ITERATIONS rationale, SDD diagram edge semantics, per-iteration history covered by escalation template) → 2 merged (ISSUES F-N.8 + UX F-N.2 → hunk-content matching; ISSUES F-N.13 + F-N.5 → adversarial testing) → **19 actionable presented** → all approved → applied as plan edits.

### Findings

#### F-1.1 — [severity: high] — [ISSUES] — Plan-execution context detection mechanism undefined
- **Location in plan:** Task 7, Step 1b
- **Description:** `finishing-a-development-branch` was instructed to gate on "plan path is in scope for this session" with no concrete signal mechanism.
- **Suggested change:** Define a marker file `.git/superpowers-plan-verification-clean` written by the verifying skill on a clean result.
- **Rationale (incl. codebase grounding):** [skills/finishing-a-development-branch/SKILL.md](../../skills/finishing-a-development-branch/SKILL.md) describes git-only inputs; no session-state mechanism exists. Without a concrete signal, Step 1b is unimplementable.
- **Decision:** applied
- **Plan diff:** Task 7 Step 1 rewritten with marker-file mechanism; SKILL.md (Task 3) gained "Clean Marker" subsection writing the marker on clean.

#### F-1.2 — [severity: high] — [ISSUES] — Verifier base_ref fallback violates READ-ONLY constraint
- **Location in plan:** Task 4 (verifier-prompt.md), SKILL Inputs section
- **Description:** Inputs allowed "else ask" fallback for base_ref but the verifier prompt forbids asking the human partner.
- **Suggested change:** Make base_ref mandatory at dispatch time; controller resolves it before invoking verifier.
- **Rationale (incl. codebase grounding):** [AGENTS.md](../../AGENTS.md) § 0.5 mandates subagent read-only constraints; [skills/hardening-plans/subagent-prompts.md](../../skills/hardening-plans/subagent-prompts.md) precedent enforces same.
- **Decision:** applied
- **Plan diff:** SKILL.md Inputs section made base_ref mandatory; verifier-prompt.md tightened to return `ERROR: <reason>` on unresolved input rather than asking.

#### F-1.3 — [severity: high] — [ISSUES] — Cycle risk between finishing and verifying skills
- **Location in plan:** Task 7 + SKILL.md Auto-Loop
- **Description:** Auto-loop "proceeds to finishing"; finishing's Step 1b "STOP and invoke verifying" → potential mutual recursion.
- **Suggested change:** Verifying skill returns control to caller; only the caller invokes finishing. Finishing's Step 1b never auto-invokes verifying.
- **Rationale (incl. codebase grounding):** Auto-recursion between two iterative skills is unbounded; pattern violation of single-responsibility.
- **Decision:** applied
- **Plan diff:** SKILL.md "When to Use" and Auto-Loop now state "returns control to caller"; Task 7 Step 1b emits a STOP message with re-invoke instructions instead of auto-invoking.

#### F-1.4 — [severity: high] — [ISSUES] — Plan-amended-mid-loop detection mechanism undefined
- **Location in plan:** SKILL.md Auto-Loop § Termination
- **Description:** "Plan amended mid-loop → re-derive plan items" lacked a detection mechanism.
- **Suggested change:** Require explicit human-partner signal; controller re-reads plan; iteration counter advances.
- **Rationale (incl. codebase grounding):** Auto-detection of external file edits is fragile; explicit signal is unambiguous.
- **Decision:** applied
- **Plan diff:** SKILL.md Auto-Loop pseudocode now branches on explicit human signal; "Termination" table updated.

#### F-1.5 — [severity: high] — [ISSUES, merged with F-N.13] — Test harness `report` mode is structural-only; AGENTS.md adversarial testing missing
- **Location in plan:** Task 2, plus a new task
- **Description:** `test.sh report` validates expected-report counts only, never runs a real verifier. AGENTS.md § "Skill Changes Require Evaluation" mandates adversarial pressure testing for every skill change.
- **Suggested change:** Add explicit comment in test.sh that `report` mode is structural; add new Task 10 that defines and records adversarial scenarios.
- **Rationale (incl. codebase grounding):** [AGENTS.md](../../AGENTS.md) "Skill Changes Require Evaluation" is non-negotiable for skill modifications.
- **Decision:** applied
- **Plan diff:** test.sh header comment expanded; new Task 10 added with five adversarial scenarios.

#### F-1.6 — [severity: high] — [reusability] — Structured-report schema duplicated in three files
- **Location in plan:** spec, SKILL.md, verifier-prompt.md
- **Description:** Output schema appeared three times, risking drift.
- **Suggested change:** SKILL.md owns canonical "Output Schema" section; verifier-prompt.md and spec reference it.
- **Rationale (incl. codebase grounding):** [skills/hardening-plans/SKILL.md](../../skills/hardening-plans/SKILL.md) precedent: canonical "Concern Axes" lives in SKILL; tests/hardening-plans/test.sh comments "keep in sync".
- **Decision:** applied
- **Plan diff:** SKILL.md gained a "(canonical)" Output Schema section; verifier-prompt.md slimmed to reference it.

#### F-1.7 — [severity: high] — [reusability] — Classification rules duplicated in three files
- **Location in plan:** same as F-1.6
- **Description:** Same drift risk for the EXTRA classification table.
- **Suggested change:** SKILL.md owns canonical "Classification Rules for EXTRA Items" section.
- **Rationale (incl. codebase grounding):** Same as F-1.6.
- **Decision:** applied
- **Plan diff:** SKILL.md gained a "(canonical)" Classification Rules section; verifier-prompt.md slimmed to reference it.

#### F-1.8 — [severity: high] — [UX] — Missing process diagram in SKILL.md
- **Location in plan:** Task 3, Step 1
- **Description:** Sibling skills include `dot` process diagrams; this plan's SKILL.md did not.
- **Suggested change:** Add a `dot` digraph showing input resolution → mode select → verify → validation → loop budget → escalate/proceed.
- **Rationale (incl. codebase grounding):** [skills/subagent-driven-development/SKILL.md](../../skills/subagent-driven-development/SKILL.md) and [skills/hardening-plans/SKILL.md](../../skills/hardening-plans/SKILL.md) precedent.
- **Decision:** applied
- **Plan diff:** Task 3 Step 1 SKILL.md content gained a Process Flow `dot` diagram.

#### F-1.9 — [severity: med] — [ISSUES] — Self-graded classification needs controller-side rationale validation
- **Location in plan:** SKILL.md Classification section
- **Description:** "Unjustified classifications auto-promote to scope-creep" lacked an enforcement step.
- **Suggested change:** Controller validates each `incidental-fix` rationale covers four conditions and each `refactor` rationale covers three. Promote on failure.
- **Rationale (incl. codebase grounding):** Self-graded judgments are weak; explicit controller-side validation is the standard defense.
- **Decision:** applied
- **Plan diff:** SKILL.md Classification section gained an explicit "controller MUST validate" subsection.

#### F-1.10 — [severity: med] — [ISSUES] — Refactor classification's "covered by tests" requirement underspecified
- **Location in plan:** SKILL.md Classification table
- **Description:** Verifier cannot reliably run tests; "covered by existing tests" was unenforceable.
- **Suggested change:** Drop the test-coverage requirement; replace with structural rules. Test suite has already passed at this stage.
- **Rationale (incl. codebase grounding):** [skills/finishing-a-development-branch/SKILL.md](../../skills/finishing-a-development-branch/SKILL.md) Step 1 verifies tests before this skill's gate.
- **Decision:** applied
- **Plan diff:** Classification table refactor row reworded; rationale-hint in `refactor-covered.txt` fixture updated to match.

#### F-1.11 — [severity: med] — [ISSUES, merged with UX F-N.2] — Verifier matching procedure must require hunk-content match
- **Location in plan:** SKILL.md Inline Procedure / verifier-prompt.md
- **Description:** "Locate corresponding hunks/files" risked false positives from file-name-only matches.
- **Suggested change:** Add a "Plan-vs-Diff Matching Procedure" canonical section with five steps and a worked example.
- **Rationale (incl. codebase grounding):** Without content-level matching, the verifier conflates "file touched" with "feature implemented".
- **Decision:** applied
- **Plan diff:** SKILL.md gained a canonical "Plan-vs-Diff Matching Procedure" section.

#### F-1.12 — [severity: med] — [ISSUES] — Auto-loop commit message format unspecified
- **Location in plan:** SKILL.md Auto-Loop
- **Description:** "Commit fixes" was unspecified.
- **Suggested change:** Stable format `fix: resolve plan-verification gaps (iteration N)`; run tests pre-commit.
- **Rationale (incl. codebase grounding):** [skills/writing-plans/SKILL.md](../../skills/writing-plans/SKILL.md) emphasizes consistent commit messages.
- **Decision:** applied
- **Plan diff:** Auto-Loop pseudocode now includes the commit format and a test-pre-commit gate.

#### F-1.13 — [severity: med] — [ISSUES] — Scope-creep response decision rule missing
- **Location in plan:** SKILL.md Auto-Loop
- **Description:** "Revert hunk OR ask human partner to amend the plan" was ambiguous.
- **Suggested change:** Decision rule: human-explicitly-requested → ask to amend; otherwise → revert; doubt → ask.
- **Rationale (incl. codebase grounding):** Default-revert silently discards work; default-ask is safer.
- **Decision:** applied
- **Plan diff:** SKILL.md Auto-Loop gained a "Scope-Creep Decision Rule" subsection with explicit revert command and never-silently-delete default.

#### F-1.14 — [severity: med] — [ISSUES] — `spec_path` linking format undefined
- **Location in plan:** SKILL.md Inputs
- **Description:** Optional `spec_path` had no defined link format.
- **Suggested change:** Drop `spec_path` from inputs.
- **Rationale (incl. codebase grounding):** YAGNI; reduces ambiguity.
- **Decision:** applied
- **Plan diff:** SKILL.md Inputs section explicitly states `spec_path is NOT an input`; verifier-prompt.md inputs list omits it.

#### F-1.15 — [severity: med] — [ISSUES] — `evidence searched` format unspecified
- **Location in plan:** SKILL.md output schema
- **Description:** Required level of detail for the `evidence searched` field was unclear.
- **Suggested change:** Sub-fields: `files:`, `symbols/strings:`, `commits:`.
- **Rationale (incl. codebase grounding):** Auditability requires explicit structure.
- **Decision:** applied
- **Plan diff:** Output Schema rewritten with three sub-fields; expected-report.md fixture updated to match.

#### F-1.16 — [severity: med] — [UX] — Verifier output validation grammar + malformed-output fallback unspecified
- **Location in plan:** SKILL.md Error Handling
- **Description:** "Subagent fails or times out → fall back to inline" did not define what counts as failure.
- **Suggested change:** Add an "Output Validation (controller-side)" section listing parse rules; on failure, fall back to inline; if inline also fails, emit verbatim escalation message.
- **Rationale (incl. codebase grounding):** Defense in depth.
- **Decision:** applied
- **Plan diff:** SKILL.md gained an "Output Validation (controller-side)" section.

#### F-1.17 — [severity: med] — [UX] — Escalation message template missing
- **Location in plan:** SKILL.md Auto-Loop
- **Description:** "Surface full report + per-iteration history" was unspecified.
- **Suggested change:** Verbatim multi-line escalation template.
- **Rationale (incl. codebase grounding):** [skills/executing-plans/SKILL.md](../../skills/executing-plans/SKILL.md) precedent uses concrete STOP messages.
- **Decision:** applied
- **Plan diff:** SKILL.md Auto-Loop section gained an "Escalation Message Template" subsection.

#### F-1.18 — [severity: med] — [UX] — Test fixture metadata hints not labeled as scaffolding
- **Location in plan:** Task 1, seed files + README
- **Description:** `classification-hint` and `rationale-hint` fields could be misread as part of the verifier's input contract.
- **Suggested change:** Add `<!-- metadata below is test scaffolding, not verifier input -->` to seed files and a clarifying paragraph to README.md.
- **Rationale (incl. codebase grounding):** Avoid contributor confusion.
- **Decision:** applied
- **Plan diff:** Task 1 Steps 4–6 each gained the scaffolding comment; Step 7 README gained an explanatory paragraph.

#### F-1.19 — [severity: med] — [reusability] — No-ledger design choice undocumented
- **Location in plan:** SKILL.md
- **Description:** Sibling `hardening-plans` uses a persistent ledger; this skill does not. Future readers would ask why.
- **Suggested change:** One-paragraph rationale in SKILL.md.
- **Rationale (incl. codebase grounding):** [skills/hardening-plans/SKILL.md](../../skills/hardening-plans/SKILL.md) § Ledger File contrast.
- **Decision:** applied
- **Plan diff:** SKILL.md gained a "Design Note: No Persistent Ledger" section.

### Iteration summary

- Findings raised: 34 (raw) | After triage: 24 actionable | Presented to user: 19 (some pre-merged) | Applied: 19 | Rejected: 0 | Deferred: 0
- Plan commit: caaa48b9f39b268d5b27554055f735367ff2de66
