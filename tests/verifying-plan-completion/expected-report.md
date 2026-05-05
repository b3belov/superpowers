<!-- FIXTURE ONLY — what a correct verifier should produce against seeded-implementation/. -->

STATUS: both

MISSING:
- Task 3 (feature C): "Add a file feature-c.txt whose first line is 'feature-c: implemented'"
  evidence searched:
    files: seeded-implementation/feature-c.txt
    symbols/strings: "feature-c: implemented"
    commits: (none — file absent in diff)

PARTIAL:
- Task 2 (feature B): missing line "acceptance: AC-2 satisfied"

EXTRA:
- seeded-implementation/incidental-bugfix.txt:1-5
  classification: incidental-fix
  rationale: bug-not-feature, small (5 lines), same area as feature-a, no new public surface
- seeded-implementation/scope-creep.txt:1-3
  classification: scope-creep
  rationale: introduces a new public capability not in the plan
- seeded-implementation/refactor-covered.txt:1-5
  classification: refactor
  rationale: behavior-unchanged, plan-touched file (feature-a area), no new public API

EVIDENCE TABLE:
| Plan item | Status | Commit(s) | File(s) |
| Task 1 (feature A) | satisfied | (fixture) | seeded-implementation/feature-a.txt |
| Task 2 (feature B) | partial   | (fixture) | seeded-implementation/feature-b.txt |
| Task 3 (feature C) | missing   | (none)    | (none) |
