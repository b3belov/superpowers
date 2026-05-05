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

**Note on metadata fields.** The `classification-hint` and `rationale-hint` fields in the seed files are **test scaffolding only** — they are not part of the real verifier's input contract. A real verifier sees only diffs and must infer classification from code and commit messages. The test harness uses these hints to seed the fixture and validate classification rules.
