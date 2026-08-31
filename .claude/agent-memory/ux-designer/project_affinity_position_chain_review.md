---
name: project-affinity-position-chain-review
description: 《盲目於微光》affinity-position-chain.md (#5, good感度—位置連鎖系統) adversarial UX review round 1 (2026-08-31) — key findings on d-pad preview parity, panel-count drift vs. tactical-combat-system.md, and a third recurrence of the singular-vs-plural requirement gap.
metadata:
  type: project
---

`design/gdd/affinity-position-chain.md` — round 1 adversarial `/design-review` pass (2026-08-31),
focused on UI/UX constraints for the future `/ux-design` pass this GDD explicitly defers to.

**Key findings (all BLOCKING-NOW unless noted)**:

1. **d-pad preview dwell-time dependency, unregistered**: the doc's UI Requirement fires the itemized
   Φ-breakdown preview at input-event granularity ("游標移動即觸發預覽"). Mouse hover can dwell
   indefinitely; d-pad/analog step-throttle rate is explicitly out-of-scope and unresolved in
   `cursor-highlight-state.md`'s own Open Questions. Nobody has registered that itemized-line
   legibility (up to 4 lines + total) must fit inside whatever throttle window gets decided later.
2. **This system is the first high-stakes consumer of untested d-pad/analog cursor movement** — see
   [[project_cursor_highlight_state_review]]'s "New consumer risk" note. Not previously true of any
   other consumer of that system.
3. **Panel-count drift**: `tactical-combat-system.md` OQ-6 tracks exactly 3 undecided HUD panels
   (傷害拆解面板/格位資訊面板/預判面板). This doc's itemized per-relationship-line breakdown is a
   *4th* distinct surface (more granular than the single aggregate `Φ` already in the damage-breakdown
   panel), triggered on cursor movement like the tile-info panel — but OQ-6 was never updated to say
   "four panels." Recommend patching `tactical-combat-system.md` OQ-6 directly.
4. **Third recurrence of "written for the singular case, breaks under the plural case"**: the
   Visual/Audio requirement "death feedback + affected-unit Φ-change feedback = two sequential visual
   events" is inherited verbatim from `tactical-combat-system.md` (which itself already says "其他存活
   單位", plural, in the same paragraph — the plurality was already visible upstream and still not
   resolved). This doc's own R5 ("sacrifice one") mechanic + R4's uncapped stacking + N=4 line cap
   guarantee up to 4 units can change `Φ` simultaneously from one death, and neither doc specifies
   batched-vs-serialized reveal or a cap on serialized length. Same failure class as
   [[feedback_root_cause_sibling_sweep]] / `project_tactical_combat_review`'s "enumerated-checklist
   drift" (now seen a third time, across a third document, this time inherited across a doc boundary
   rather than within one doc).
5. **Ownership gap**: R10 makes this system stateless (no history). But the two-step death/Φ-change
   sequence needs a before/after delta to render "changed by X" — nobody (this system, per R10
   correctly; but also no downstream system) is assigned to snapshot the pre-death value. Needs an
   explicit Dependency/OQ line.
6. **Not a finding, verified clean**: the "戊 shows 'not applicable' not '0'" requirement is genuinely
   meaningful (mirrors an existing precedent in `tactical-combat-system.md` line ~558 for "Φ=0 must not
   be hidden") — but the doc doesn't address a third state (panel mid-refresh/unresolved) that could
   collide visually with "not applicable" and reintroduce the "資訊斷裂" failure mode a sibling doc
   already named.
7. **Verified clean, not orphaned**: the doc's "上游已裁決...見 tactical-combat-system.md" punt for the
   two Visual/Audio hard constraints (Φ readability, death-sequencing) checked out on file-read — both
   actually exist upstream. Good example of [[feedback_verify_punted_obligations]]'s check passing.
