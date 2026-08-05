---
name: feedback-mechanism-removal-sweep
description: When a design doc rewrite removes a mechanism/interface (e.g. a geometry query, a formula input), grep the WHOLE document for that mechanism's terminology and dependent concepts, not just the section that announced the removal — dependent rules elsewhere silently keep referencing the removed thing.
metadata:
  type: feedback
---

Rule: When a design-review round removes a mechanism (an interface, a query, a formula term) and the removal is announced/celebrated in one section ("this eliminates risks X and Y"), do not assume the removal fully propagated. Search the entire document for the mechanism's key terms and confirm every dependent rule, Edge Case, and Acceptance Criterion that used to rely on it has been rewritten to not need it — or flagged as newly broken.

**Why**: Found twice in `design/gdd/cursor-highlight-state.md`, same underlying failure mode both times:
- Round 9: qa-lead found AC-35's round-7 rewrite claimed "original verification purpose superseded by new version," but the new version tested something entirely different — the original assertion (accumulator reset on transfer) was silently deleted, not superseded. Fixed via AC-42 in round 9.
- Round 10: found Core Rules #3's "累積起點的重置時機" trigger (c) — "滑鼠離開目前目標的**合法命中框區域**後又返回" — still requires querying the current target's hitbox geometry to know when the mouse has left/re-entered it. But round 9's own rewrite of "奪權門檻的錨定對象" explicitly states "本系統自本輪起不存在任何形式的命中框幾何查詢介面" (no hitbox geometry query interface exists as of this round) and even asserts one sentence earlier that the accumulator field "只追蹤滑鼠自身位置的變化量,不涉及任何目標表面的幾何" (tracks only the mouse's own position, not any target-surface geometry) — directly contradicting trigger (c) in the same Core Rule. The same leftover "命中框" terminology also appears in the execution-order elaboration for trigger (c), in Edge Cases, and in AC-44/AC-45 — four separate locations that never got swept after the geometry mechanism was removed.

**How to apply**: After any round that removes a mechanism (especially in a document that has gone through many iterative rounds with dense inline revision annotations), do a full-document search for the removed mechanism's key nouns (e.g. "命中框"/hitbox, "幾何查詢"/geometry query) before signing off on the round. A section announcing "this removes risks A/B because the mechanism is gone" is a strong signal to go check every OTHER place that mechanism's vocabulary appears — those are the likely leftover contradictions. This is the same failure class as [[feedback_verify_punted_obligations]] (prose claims resolution without the diff actually reaching every dependent location) but triggered by mechanism *removal* rather than obligation *deferral*.
