---
name: project-cursor-highlight-state-review
description: 《弈緣》 cursor-highlight-state.md is on round 12+ of iterative /design-review, gated by two related-but-distinct confirmed defects in the mouse-reclaim sub-mechanism (Core Rules #3); tracks defect status and the accessibility linkage.
metadata:
  type: project
---

`design/gdd/cursor-highlight-state.md` (single global cursor/highlight authority system, Foundation-layer, no upstream dependencies) is under a long-running iterative `/design-review` cycle — round 12 as of 2026-08-11. Full round-by-round history in `design/gdd/reviews/cursor-highlight-state-review-log.md`.

**Current blocking state (as of round 12, 2026-08-11)**: The doc carries a hard gate — "不得進入垂直切片、不得標記 Approved" — tied to a Known Confirmed Defects table with two related rows, both rooted in Core Rules #3's mouse-reclaim sub-mechanism:
1. **Lock defect** (spike-confirmed 2026-08-05): sustained held direction key/analog stick input causes the same-frame veto (trigger point (d)) to fire every processed frame, permanently denying mouse reclaim. Analog stick 100% reproducible (5-10s hold → full lock). Candidate fix: filter same-frame veto by `InputEventKey.echo` (untested on D-pad/analog stick).
2. **Snap-back defect** (discovered round 12, 2026-08-11, non-engineer tester, keyboard path only): mouse successfully completes a reclaim, then is immediately reclaimed back by the *separate* reverse zero-threshold exemption rule while the key is still held. Same root cause as defect 1 (continuous/held-input treated as fresh discrete intent) but a different rule/code path — the candidate echo-filter fix for defect 1 is confirmed ineffective against this one. See [[feedback_root_cause_sibling_sweep]] for the general pattern this illustrates.

**Untested surfaces**: D-pad (both modes) and analog stick (Mode 2, candidate-fix-applied) are completely untested — the tester had no gamepad hardware available for the 2026-08-11 round. Do not treat "untested" as "clean."

**My round-12 recommendation (ux-designer)**: recommend the two defect rows be redesigned together in the next full round (not patched separately), and that the hard gate's scope be explicitly widened to require both resolved before it lifts — the doc's own text (Known Confirmed Defects row 2) already flags this as an open decision for the next round to make.

**Accessibility linkage**: `design/ux/accessibility-requirements.md` line ~30 (Motor Accessibility table) currently only names the lock symptom as relevant to switch-based assistive devices (sustained-trigger input patterns); it predates the snap-back discovery and needs updating to cover both symptoms, since switch-scanning / tremor-driven input is a plausible real-world trigger for the snap-back symptom specifically (not just the lock).
