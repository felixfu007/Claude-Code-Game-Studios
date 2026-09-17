---
name: feedback-spec-only-no-src-edits
description: art-director produces spec documents only, never edits src/ files — even for purely visual bugs, because many "graphics" in this project are engine-drawn primitives in files other specialists are actively modifying
metadata:
  type: feedback
---

When a visual defect is reported (e.g. a HUD glyph looks wrong, a menu row's text
jumps), the correct deliverable is a spec document under `design/art/`, never an
edit to the `.gd` file that draws it — even when the fix is conceptually simple
(e.g. "add two more ColorRects").

**Why:** Manager ruling (2026-09-17): "美術只出規格,實作併進工作單." The reason
given is structural, not just role purity: much of this project's "art" for HUD
elements (lock icons, focus outlines, empty-slot borders) is not an image asset —
it is composed at runtime from `Panel`/`StyleBoxFlat`/`ColorRect` primitives
directly inside `.gd` files (e.g. `src/ui/battle/hand_bar.gd`,
`src/ui/menu/battle_menu.gd`). Those same files are frequently being edited
concurrently by other specialists (godot-gdscript-specialist, ui-programmer) as
part of unrelated story work — a direct edit from art-director risks a merge
collision on a file it doesn't own.

**How to apply:** Write the spec as exact, implementable numbers (fpx-multiplier
constants, `Color(...)` values, anchor fractions, StyleBox properties) referencing
the target file's existing constants/functions by name, so the actual implementer
needs zero follow-up questions. Never open the target `.gd`/`.tscn` file with
Write/Edit — Read is fine for verifying current values, but the deliverable stops
at the spec file. See [[project-hud-glyphs-are-code-not-images]] for why this
"spec, not asset" shape is the norm for this project's HUD layer specifically.
