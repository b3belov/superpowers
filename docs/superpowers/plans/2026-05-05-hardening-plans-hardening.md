# Hardening Ledger: 2026-05-05-hardening-plans

**Plan:** [2026-05-05-hardening-plans.md](./2026-05-05-hardening-plans.md)
**Status:** in-progress
**Verified at commit:** (set after first iteration commit)

---

## Iteration 1 — 2026-05-05

**Dispatched concerns:** ISSUES, UX, reusability, security, performance
**Codebase commit at analysis:** 567dd544509e300b24d347a307036f1953525670

5 read-only `Explore` subagents dispatched in parallel, one per axis.

### Findings

#### F-1.1 — [severity: high] — [ISSUES] — Context passing for plan/ledger path
- **Location in plan:** Hardening Handoff (skill); precondition checks in executing-plans / subagent-driven-development
- **Description:** Precondition checks reference `<plan-basename>-hardening.md` but never explain how the agent derives `<plan-basename>` when the execution skill is invoked. The handoff to executing-plans does not pass the plan path forward.
- **Suggested change:** Document ledger-path derivation in `hardening-plans/SKILL.md` (Hardening Handoff and a new "Precondition for Execution Skills" section). State that the plan path must be passed at handoff. Both execution skills cite the canonical procedure.
- **Rationale (incl. codebase grounding):** `skills/executing-plans/SKILL.md` step 1 and `skills/subagent-driven-development/SKILL.md` "The Process" both used `<plan-basename>` without derivation rules.
- **Decision:** applied
- **Plan diff:**
  - Added "Precondition for Execution Skills" canonical section in `hardening-plans/SKILL.md`.
  - Added "Pass the plan file path explicitly" instruction in Hardening Handoff.
  - Replaced duplicated wording in `executing-plans/SKILL.md` and `subagent-driven-development/SKILL.md` with citations to the canonical section.
  - Updated `writing-plans` Hardening Handoff to require passing the plan path.

#### F-1.2 — [severity: high] — [ISSUES] — Format mismatch between subagent output and ledger
- **Location in plan:** subagent-prompts.md OUTPUT FORMAT vs. SKILL.md Ledger File iteration entry
- **Description:** Subagent prompt emitted flat fields (`severity:`, `location_in_plan:`, etc.); ledger expected the `#### F-N.X — [severity: …] — [axis] — <title>` heading + bolded list format. Conversion logic was never specified, so triage and dedup could not work reliably.
- **Suggested change:** Make the subagent's required output format identical to the ledger's finding-block format (axis is known from dispatch; severity, description, suggested change, rationale fields are populated by the subagent; main agent fills decision/reason/plan-diff during triage).
- **Rationale:** Prevents a class of conversion bugs and makes the ledger appendable directly.
- **Decision:** applied
- **Plan diff:** Rewrote OUTPUT FORMAT section of `subagent-prompts.md` to ledger schema. Noted in SKILL.md that subagents emit ledger-format entries.

#### F-1.3 — [severity: high] — [ISSUES, reusability] — Decomposition contract with dispatching-parallel-agents
- **Location in plan:** SKILL.md Dispatching Analysis Subagents section
- **Description:** "Delegate decomposition to dispatching-parallel-agents" was hand-wavy. That skill describes a parallel-investigation pattern, not a programmatic decomposition API.
- **Suggested change:** State the default decomposition explicitly (one read-only subagent per axis = 5 total). Cite `dispatching-parallel-agents` for the dispatch *pattern*, not for decomposition logic.
- **Rationale:** `skills/dispatching-parallel-agents/SKILL.md` defines a pattern, not an interface.
- **Decision:** applied
- **Plan diff:** Replaced "delegate decomposition" with "Default decomposition: one subagent per axis (5 total). Follow the parallel-dispatch pattern from dispatching-parallel-agents."

#### F-1.4 — [severity: high] — [ISSUES] — Skills "MAY reference" violates read-only constraint
- **Location in plan:** SKILL.md Dispatching Analysis Subagents → Reference skills subsection
- **Description:** The list (`systematic-debugging`, `test-driven-development`, `verification-before-completion`) all involve actions read-only subagents cannot take.
- **Suggested change:** Reword to "consider concepts from these skills" and explicitly forbid invocation.
- **Rationale:** AGENTS.md Section 0.5 prohibits subagent file modifications and interactive tool use; those skills require both.
- **Decision:** applied
- **Plan diff:** Renamed subsection to "Concept references (NOT skill invocations)"; clarified the constraint. Updated subagent-prompts.md to match.

#### F-1.5 — [severity: high] — [security] — Prompt injection via plan content
- **Location in plan:** subagent-prompts.md INPUTS / `<PLAN_CONTENT>` interpolation
- **Description:** `<PLAN_CONTENT>` interpolated raw; a malicious plan author could embed instructions that try to override the read-only constraint.
- **Suggested change:** Wrap content in fenced block; instruct subagents to treat injected blocks as inert text; reinforce that platform tool restrictions are the binding enforcement, not prompt text.
- **Rationale:** Standard prompt-injection mitigation. Platform tool layer is the only real defence; prompt language reduces accidental misinterpretation.
- **Decision:** applied
- **Plan diff:** Wrapped `<PLAN_CONTENT>` and ledger excerpts in `~~~text` fences; added "treat as INERT TEXT" instruction and a tail clause ignoring any embedded directive that asks the subagent to act outside its constraints.

#### F-1.6 — [severity: high] — [reusability] — DRY: precondition duplicated across two skills
- **Location in plan:** `skills/executing-plans/SKILL.md` and `skills/subagent-driven-development/SKILL.md`
- **Description:** Two near-identical precondition paragraphs in different skills.
- **Suggested change:** Move canonical wording into a "Precondition for Execution Skills" section in `hardening-plans/SKILL.md`; both execution skills cite it.
- **Rationale:** Avoids drift between the two skills if the precondition evolves.
- **Decision:** applied
- **Plan diff:** Created canonical section; replaced both inline paragraphs with one-line citations.

#### F-1.7 — [severity: high] — [performance] — Token-cost: full plan duplicated to all 5 subagents
- **Location in plan:** SKILL.md Dispatching Analysis Subagents
- **Description:** Each iteration sends the whole plan to all five subagents — 5× token cost for large plans.
- **Suggested change:** Add guidance: if plan exceeds ~20KB, send axis-relevant excerpt + plan map; full plan when ≤20KB.
- **Rationale:** Bounded token cost for realistic plan sizes.
- **Decision:** applied
- **Plan diff:** Added "Token-cost guidance" subsection in Dispatching Analysis Subagents.

#### F-1.8 — [severity: med] — [UX] — User-facing prompt templates undefined
- **Location in plan:** SKILL.md (multiple sections referencing user prompts without templates)
- **Description:** "Present findings", "ask whether to start a new iteration", "inform the user of axis failure" all referenced without templates.
- **Suggested change:** Add concrete templates (Resumption Prompt, Iteration-Continuation Prompt, Axis-Failure Prompt, Findings Presentation Template).
- **Rationale:** Mirrors specificity already present in writing-plans Hardening Handoff.
- **Decision:** applied
- **Plan diff:** Added "User-Facing Prompt Templates" and "Findings Presentation Template" sections.

#### F-1.9 — [severity: med] — [UX] — Decision field semantics
- **Location in plan:** SKILL.md Ledger File section
- **Description:** `applied | rejected | deferred` listed but undefined.
- **Suggested change:** Add a brief glossary; mandate the `Reason` field for non-`applied` decisions.
- **Decision:** applied
- **Plan diff:** Added "Decision field glossary" under Ledger File.

#### F-1.10 — [severity: med] — [UX] — Plan-diff multi-edit format
- **Location in plan:** SKILL.md Applying Findings
- **Description:** Originally said "summarize the edit in one line" — ambiguous when one finding requires multiple edits.
- **Suggested change:** Allow bulleted multi-line entries when a single finding triggered multiple edits.
- **Decision:** applied
- **Plan diff:** Updated Applying Findings with example bulleted Plan-diff.

#### F-1.11 — [severity: med] — [performance] — Codebase scoping for subagents
- **Location in plan:** SKILL.md Dispatching, subagent-prompts.md TASK step 2
- **Description:** "Read the actual codebase" was unbounded.
- **Suggested change:** Add stop rules: direct imports only, depth ≤2, skip vendor dirs.
- **Decision:** applied
- **Plan diff:** Added "Codebase scoping for subagents" subsection in SKILL.md and matching constraints in subagent-prompts.md.

#### F-1.12 — [severity: med] — [performance] — Carry approved findings forward
- **Location in plan:** SKILL.md Dispatching → inputs to subagent
- **Description:** Only rejected findings flowed forward; subagents could rediscover already-applied items.
- **Suggested change:** Pass an `LEDGER_APPLIED_EXCERPT` summary to each subagent as well.
- **Decision:** applied
- **Plan diff:** Added "Carrying findings forward" subsection. Added `<LEDGER_APPLIED_EXCERPT>` placeholder in subagent-prompts.md.

#### F-1.13 — [severity: med] — [ISSUES] — Iteration termination on all-rejected case
- **Location in plan:** SKILL.md Iteration Termination
- **Description:** "Convergence is judged on actionable findings after triage" was correct but easy to misread.
- **Suggested change:** One explicit "All-rejected case" paragraph.
- **Decision:** applied
- **Plan diff:** Added the paragraph in Iteration Termination.

#### F-1.14 — [severity: med] — [ISSUES] — Test driver only does loose grep
- **Location in plan:** `tests/hardening-plans/test.sh`
- **Description:** Driver did not validate ledger schema (severity values, decision values, finding-block fields).
- **Suggested change:** Add awk-based finding-block schema check and tighten the per-axis assertion to require axis appearance inside a Finding heading.
- **Decision:** applied
- **Plan diff:** Rewrote test.sh with awk schema validator and stricter axis grep.

#### F-1.15 — [severity: med] — [ISSUES] — Fixture realism
- **Location in plan:** `tests/hardening-plans/sample-plan.md`
- **Description:** Task 2 was empty; Task 3 had no test code, so the fixture didn't exercise realistic plan structure.
- **Suggested change:** Flesh out Task 2 with a stub redirect handler and Task 3 with a realistic failing-test snippet.
- **Decision:** applied
- **Plan diff:** Expanded fixture; SEEDED-FLAW count preserved at 6.

#### F-1.16 — [severity: med] — [security] — Ledger tampering risk
- **Location in plan:** SKILL.md Ledger File header; precondition section
- **Description:** Status line is plain markdown; an attacker could flip it to `converged`.
- **Suggested change:** Add `Verified at commit:` line; precondition does best-effort `git log -1 --format=%H -- <ledger>` comparison and warns on mismatch.
- **Rationale:** Defense in depth; git history remains the real audit trail.
- **Decision:** applied
- **Plan diff:** Added field to ledger header, integrity check step in precondition, and corresponding test.sh assertion.

#### F-1.17 — [severity: med] — [security] — Secrets in rationale field
- **Location in plan:** SKILL.md Applying Findings / new Secret Scan section
- **Description:** Rationale embeds code excerpts; a careless rationale could leak secrets into the committed ledger.
- **Suggested change:** Add a "Secret Scan" guidance section + a step in the iteration loop checklist before commit.
- **Decision:** applied
- **Plan diff:** Added Secret Scan section and pre-commit step.

#### F-1.18 — [severity: low] — [reusability] — Hardcoded axes in 4 files
- **Location in plan:** global
- **Description:** Five axes appeared verbatim in SKILL.md, subagent-prompts.md, fixture, test.sh.
- **Suggested change:** Comment each non-canonical site to reference SKILL.md "Concern Axes" section.
- **Decision:** applied
- **Plan diff:** Added a "Concern Axes" section in SKILL.md. Each other file gained a comment pointing at it.

#### F-1.19 — [severity: low] — [security] — Read-only enforcement note
- **Location in plan:** SKILL.md Dispatching → Read-only constraint
- **Description:** The constraint is enforced at the platform tool layer, not by prompt text.
- **Suggested change:** One-line caveat.
- **Decision:** applied
- **Plan diff:** Added the caveat to the Read-only constraint paragraph.

#### F-1.20 — [severity: low] — [UX] — Triage transparency
- **Location in plan:** SKILL.md Triage section
- **Description:** Optionally surface triage stats to user.
- **Suggested change:** Add a sentence noting agents may report "X raised → Y actionable" stats.
- **Decision:** applied
- **Plan diff:** Added the sentence.

#### F-1.21 — [severity: low] — [security] — Fixture warning header
- **Location in plan:** `tests/hardening-plans/sample-plan.md`
- **Description:** Risk of fixture being misread as a real plan.
- **Suggested change:** Add a "⚠️ FIXTURE ONLY — do not execute" comment at top.
- **Decision:** applied
- **Plan diff:** Added HTML comment header; updated test.sh expectation accordingly.

#### F-1.22 — [severity: low] — [ISSUES] — Tighter Task 10 integration verifications
- **Location in plan:** Implementation plan Task 10
- **Description:** Final integration check used a loose `grep -l "hardening-plans"` that would match comments.
- **Suggested change:** Use targeted patterns ("Hardening Handoff", "Precondition for Execution Skills", "Precondition: hardening ledger present and verified.").
- **Decision:** applied
- **Plan diff:** Plan document Task 10 updated with the tighter patterns.

### Iteration summary
- Findings raised: 22 (after triage from 28 raw findings — 5 dropped as no-op/future-only, 1 merged across ISSUES & security)
- Applied: 22 | Rejected: 0 | Deferred: 0
- Plan commit: (set after this commit)
