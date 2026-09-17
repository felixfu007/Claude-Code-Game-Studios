---
name: feedback-formula-must-match-worked-example
description: when a spec states both a symbolic formula and a numeric worked example, derive the formula BY expanding the worked example's reasoning, then check the two arrive at the same number — don't let one be "correct in prose" while the other is a shortcut that was never re-derived
metadata:
  type: feedback
---

Caught 2026-09-17 (by an implementer building from `battle-ui-glyph-spec.md`,
confirmed by re-deriving the numbers myself): I wrote a scrim rect's left/top
edges as a naive `0 − padding`, while the SAME section's "N=2 驗算" paragraph and
the adjacent section's cross-reference both correctly used the extended value
(`-(glyph_size + glyph_gap + padding)`, `-(caption_gap + caption_height +
padding)`). The prose reasoning was right; the formula line was a leftover
shortcut that never got updated when I worked out the real dependency. Since
this scrim's coverage was the stated precondition for an earlier section's own
"why" (the lock glyph's cutout only reads correctly if it's inside the scrim),
the wrong formula would have silently invalidated that earlier section too —
not a cosmetic typo.

**Why this class of error is easy to produce and hard to self-catch:** a spec
often gets its formula and its worked numeric example at different points in
drafting (the formula first, as a quick placeholder; the worked example later,
once you actually reason through what the element needs to cover). If you
don't go back and re-derive the formula FROM the worked example's logic, they
silently diverge, and both look plausible in isolation — the formula looks like
a formula, the worked number looks like a worked number, and nothing about
either one screams "these don't match." This is the same shape as this
project's registered "two independently-written copies of the same fact, only
today's values happen to agree" failure pattern, just occurring within a single
document I wrote alone rather than across two files by two people.

**How to apply:** Before finalizing any section that has both a formula and a
plugged-in numeric example, substitute the formula's own symbols with the
example's numbers and confirm the arithmetic actually lands on the stated
result — do this as an explicit last pass, not as part of first drafting the
formula. If a downstream section's numbers depend on an upstream section's
values (e.g. one constant changed between sections), re-substitute that changed
value into every formula that uses it, not just the prose that mentions it.
