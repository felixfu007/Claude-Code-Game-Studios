---
name: project-game-concept-review
description: 《弈緣》game-concept.md is under an iterative multi-round adversarial /design-review cycle; tracks round history and a recurring UX gap pattern found across rounds.
metadata:
  type: project
---

`design/gdd/game-concept.md` (single-player tactics/narrative game, working title 弈緣) has gone through 5 rounds of `/design-review` as of 2026-07-29. Full history in `design/gdd/reviews/game-concept-review-log.md`. As ux-designer I contributed findings in rounds 3, 4, and 5.

**Recurring pattern to watch for in future rounds**: this document repeatedly introduces UI constraints for one interaction mode (e.g. full-map/overview view, or a newly-approved permanent feature) without cross-checking the exact wording against constraints already written for a *related* mode in an earlier round. Round 4 did this to itself within the same edit pass — see [[feedback_cross_mode_wording_check]]. When reviewing future rounds of this doc (or similar dual-mode UI docs), always diff new mode-scoped wording (e.g. "single-select focus" vs "multi-select pin") against prior rulings on adjacent modes before signing off.

**Key UX rulings already established (do not re-litigate unless internally contradicted)**: cross-piece comparison capability (round 3), full-map view shows only polarity/strength not live bonus/penalty preview (round 4), colorblind-safe connection lines (round 3), console readability spec requirement (round 3), dual-focus highlight authority = last-input-device wins (round 4, scoped to "棋盤格" board-tile highlighting), five-layer UI teaching-order (round 4), prediction mode (預判模式) confirmed as permanent feature, role within core loop still open (round 4).
