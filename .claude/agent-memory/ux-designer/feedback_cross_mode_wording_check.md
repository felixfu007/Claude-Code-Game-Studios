---
name: feedback-cross-mode-wording-check
description: When a design doc defines a UI constraint for one interaction mode (e.g. overview vs focused view), always check its exact wording against constraints already written for related/adjacent modes — mismatched scoping words (single-select vs multi-select) silently gut features approved in earlier rounds.
metadata:
  type: feedback
---

Rule: When reviewing or authoring a constraint that scopes a UI behavior to a named "mode" (e.g. "single-select focus mode", "multi-select pin mode", "full-map view"), explicitly check whether that scoping word matches or contradicts other modes' definitions already established elsewhere in the same document — especially ones added in the same round/pass.

**Why**: Found in 《弈緣》game-concept.md round 5 review — round 4 restricted live bonus/penalty preview to "單選聚焦模式" (single-select focus mode) as an anti-overload measure for the full-map view. But round 3, in the same document, had mandated "跨棋子比較能力" via "多選釘選" (multi-select pin) as one acceptable implementation of cross-piece comparison. If focus mode is strictly single-select, multi-select pin mode (a round-3-approved option) can never show live bonus/penalty preview either, silently defeating the comparison feature's tactical value — but this wasn't caught because the two rulings were written in different sections/rounds and never diffed against each other.

**How to apply**: Any time a document defines a scoped-mode UI constraint, search the doc for other mentions of "mode" or comparable interaction concepts and verify the scoping terms are mutually consistent before approving. This is especially likely to slip through in multi-round iterative reviews where each round only compares its own new edits against the immediately-preceding round, not the full cross-section wording graph.

**Recurrence (2026-08-03, cross-document)**: Pattern also appears *across* separate GDDs, not just within one doc's rounds. `design/gdd/cursor-highlight-state.md` Core Rule #7 generalizes a SINGLE-target cursor/authority state model ("任一時刻恰有一個高亮") to "any UI surface with a hover target," explicitly naming the relationship-graph minimap — but `game-concept.md` line 175 already ruled that the minimap/full-view mode uses MULTI-SELECT PINNING for cross-piece comparison. A single-target authority model cannot natively hold N pinned highlights; the new doc never reconciles "highlight" (singular, authority-owned) with "pin marker" (persistent, multi-select) as distinct visual categories. When authoring or reviewing any new infrastructure doc that claims to generalize a rule to "all UI surfaces," explicitly re-check it against prior UX rulings for every named surface it claims to cover — not just against the document it originated in.
