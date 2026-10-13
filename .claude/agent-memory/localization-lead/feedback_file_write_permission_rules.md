---
name: feedback-file-write-permission-rules
description: This project's CLAUDE.md overrides the default "ask before Write/Edit" collaboration protocol in specific, dated ways — know which case applies before pausing to ask.
metadata:
  type: feedback
---

This project's root `CLAUDE.md` has two manager rulings that narrow the normally-strict
"ask before Write/Edit" rule from this agent's own system prompt:

- **2026-10-05 ruling**: a brand-new file is written directly, as the first action, with no
  prior "may I write this to [filepath]?" question. The failure mode it prevents is a full
  turn of tool calls producing zero disk output ("23 次工具呼叫、磁碟零產出" was measured on
  this project).
- **2026-10-12 ruling**: an *existing* **code file** (not a doc/ADR/story file) may also be
  edited directly, *if* the edit is within the explicit scope of a `Ready`-status story's
  Affected Files / dispatch brief. Existing docs, ADRs, `CLAUDE.md`, `.claude/docs/*`,
  EPIC/story files still require asking first — code and docs are split precisely because
  "broken code gets caught by tests; broken docs get caught by nothing" on this project.

**Why this matters**: `SubagentHandback`-style dispatch briefs on this project are written by
a coordinator who has already done the read-only investigation and often explicitly says
"新檔直接寫,不必問" — that instruction is consistent with the CLAUDE.md ruling, not an
attempt to bypass approval. Don't default to asking in that case; it stalls work the project
has already decided doesn't need a pause.

**How to apply**: Before writing, classify the target: (a) new file → write directly;
(b) existing code file within a Ready story's named scope → edit directly, but then run the
**full** test suite and report the engine's raw `ENGINE EXIT` and `Overall Summary` lines
(not just "tests passed") — this obligation is non-negotiable and attached specifically to
the 2026-10-12 relaxation; (c) existing doc/ADR/story/EPIC file, or a code file *outside* the
dispatched scope → ask first, every time, regardless of how confident the change seems.

See [[feedback_sensitivity_proof_via_pure_function_decomposition]] for a related technique
used when a test needs to prove something about files this agent is told not to touch.
