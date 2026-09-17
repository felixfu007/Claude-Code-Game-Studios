---
name: reference-layout-authority-files
description: which file owns which layout/scaling fact, and where the single-source-of-truth scaling function lives — check these before writing any HUD/screen spec
metadata:
  type: reference
---

- `design/art/art-direction.md` — canvas size, palette (64-color budget), outline
  (1px convention), font strategy authority. **art-director owns this file.**
  Has a self-imposed ≤150 line cap (process-dosage rule); deliberately excludes
  engine scaling/layout, which was split out 2026-09-01.
- `design/art/screen-architecture.md` — engine stretch mode, world-layer integer
  scale factor `N`, HUD font-size rule (`11 × N`), interface-layer-vs-world-layer
  split, safe-area rules. **Also art-director-owned**, split out from
  art-direction.md specifically because it's engine/scaling territory, not
  palette/canvas territory.
- `src/ui/battle/world_layout.gd`'s `compute_scale()` — the ONLY place `N` may be
  computed. `src/ui/battle/hud_layout.gd`'s `font_size()` derives HUD fpx from it.
  Any new HUD spec must express sizes as multiples of this fpx unit, never a raw
  pixel number, and must never re-derive the `N` formula independently (this
  project has a registered failure pattern of "the same formula reimplemented
  twice, agreeing only today").
- `design/ux/battle-menu.md` and `design/ux/skill-card-play.md` — **owned by
  ux-designer**, not art-director, but contain the accessibility clauses
  (`P-F3`, the S5/S6 four-channel table) that constrain what visual fixes are
  even legal. Always read the exact clause wording in these files before
  deciding a fix direction — a paraphrase in a `.gd` doc comment can drop a
  load-bearing "or" vs "and" (this happened 2026-09-17: a code comment
  paraphrased `P-F3`'s "position marker (▸) or outline" as if both were
  required, when the source doc says either alone suffices — that "or" is what
  made "just remove the marker" a valid, spec-compliant fix).
