---
name: project-hud-glyphs-are-code-not-images
description: this project's battle-HUD glyphs (lock icon, focus outline, slot borders) are built from Panel/StyleBoxFlat/ColorRect primitives in GDScript, not PNG assets — art-director specs for them are coordinate/color tables, not mockup images, until explicitly decided otherwise
metadata:
  type: project
---

As of 2026-09-17, `assets/art/` contains only `placeholder/` — there is no real
pixel-art asset in the project yet. HUD elements that might look like "icons"
(the hand-bar lock glyph, card-slot outlines, the battle-menu focus indicator)
are all composed at runtime from engine primitives (`Panel` + `StyleBoxFlat`,
`ColorRect`) directly inside `src/ui/battle/hand_bar.gd` and
`src/ui/menu/battle_menu.gd`, explicitly per those files' own doc comments
("no custom `_draw()` anywhere in this file... compose from primitive nodes").

**Why this matters:** When a HUD glyph reads poorly (e.g. the lock icon read as
an anvil because its "shackle" was two solid overlapping rects with no cutout),
the first-choice fix is almost always "recompose the primitives correctly"
(e.g. add more rects and leave a deliberate gap for negative space), not
"commission a real pixel-art PNG." A real image asset is the fallback, not the
default — it adds import-pipeline scope (texture_filter, integer scaling vs. the
project's HUD layer explicitly NOT being pixel-grid-aligned per
`art-direction.md` §6) that isn't justified while the primitive approach still
has headroom. This project would treat such a PNG as its *first* real pixel-art
asset, which is itself a small precedent-setting decision worth flagging
explicitly if it ever becomes necessary.

**How to apply:** Before recommending a new image asset for a small HUD glyph,
check whether the "not enough primitives, or primitives placed with no gap
between them" failure mode explains the defect — that was true both times this
came up (lock icon, and — architecturally similar — needing a background scrim
so a foreground outline has a *known* backdrop instead of an arbitrary one).
Also see [[feedback-spec-only-no-src-edits]] — since these are code, not assets,
the deliverable for a fix is always a spec document, never a direct edit.
