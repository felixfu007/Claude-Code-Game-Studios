---
name: feedback-sensitivity-proof-via-pure-function-decomposition
description: When a test's only meaningful injection point is a real file/directory you're forbidden to modify (test-standards.md Type D) or real data content (Type A′), try decomposing the detector into a pure function before concluding "can't prove it."
metadata:
  type: feedback
---

This project's `.claude/rules/test-standards.md` registers five shapes of test that
structurally cannot carry a sensitivity proof (spy-subclass + `test_sensitivity_proof_*`),
including **Type D** ("唯一有意義的注入點在受限範圍外" — the only injection point is outside
the restricted area, e.g. proving a `src/`-scanning test catches a defect would require
planting a defect in real `src/`) and **Type A′** (asserting facts about real version-controlled
data file content — no class to swap in a corrupted version).

**The technique that worked (story-003, localization-infrastructure epic, 2026-10-13)**:
before accepting "this falls in a known-unprovable category, write up why and stop," check
whether the detection logic can be split into two layers:

1. A pure function that takes **text/data as a parameter** (a string blob, a parsed row list)
   and does the actual comparison/detection logic — zero file I/O.
2. A thin wrapper that does the **only** file-I/O (walk the real directory / read the real
   CSV) and hands the result to layer 1.

The real test (BLOCKING, exercises the real file/directory) still can't be proven this way —
that part honestly stays in Type D / A′. But the sensitivity proof test can call layer 1
directly with an **in-memory fixture containing a deliberately injected defect** (a duplicate
key, an empty value, a bare-CJK `const` line mixed with decoy lines that must NOT trigger),
and assert the detector fires correctly on the exact same code path the real test uses.

**Why this is not cheating**: it proves the comparison *logic* is correct, which is most of
what a sensitivity proof is for. What it does *not* prove — and must be disclosed, not
glossed over — is that the file-I/O layer itself (the `DirAccess`/`FileAccess` walk, or the
CSV read) has no bugs. State that gap explicitly in the test file header rather than implying
full coverage.

**How to apply**: before writing "6 of N tests have no sensitivity proof, Type D/A′, done,"
check each one for whether a pure-function split is possible. It usually is, for any test
whose core claim is "this comparison/scan logic is correct" rather than "this specific
execution environment has no bugs."

Related: [[feedback_file_write_permission_rules]] (the "forbidden to touch src/" constraint
that makes Type D bite in the first place comes from the same dispatch-scope discipline).
