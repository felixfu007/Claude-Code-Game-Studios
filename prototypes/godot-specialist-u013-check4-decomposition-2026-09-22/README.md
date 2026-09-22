# Spike: decomposing U-013's Check-4 194-block count (2026-09-22)

> PROTOTYPE — NOT FOR PRODUCTION / 拋棄式驗證探針
> **Executed by**: `godot-specialist`, headless, reading back an already-rendered real PNG.

## What this is for

`prototypes/u013-highlight-evidence-2026-09-22/README.md`'s open finding #4 reports
194 Check-4 (pixel-art integer-scale grid) violations on a real rendered frame of
`board_view.gd`'s `set_card_target_highlights()`, and leaves open whether that number
is entirely caused by the illegal-mark's diagonal `Line2D` X, or partly caused by the
outline's axis-aligned `ColorRect` border strips too (the same layer draws both, and
both are "primitives" rather than `Texture2D`s).

This spike does not answer the coordinator's open question itself (redraw the X as
pixel art, vs. Check 4 not applying to vector primitives — that is `art-director` +
`godot-specialist`'s joint call, made in the parent report, not here). It answers one
narrower, purely mechanical sub-question: **of the 194 violating blocks, how many sit
inside the border-strip region versus the X-mark region?** That number changes what
"fix the drawing" would even mean — if the border also violates, redrawing only the X
would not reach 0.

## Method

Reads `prototypes/u013-highlight-evidence-2026-09-22/diagnostic-context-full-window-2026-09-22-CHECK4-FAILED.png`
back with the `Image` API (no rendering pipeline involved — same justification that
directory's own `diag_scan_column.gd` already gives for doing this headless). Does
**not** re-render anything.

- Scale (`2`) and the world-layer rect (`(160,90)`-`(960,540)`) are obtained by
  **calling** `WorldLayout.compute_scale()` / `compute_rect()` for the same
  `1280x720` window the original run used — never hardcoded, per
  `technical-preferences.md`'s "不得自行計算,不得複製公式" rule.
- The grid-violation counting algorithm is copied verbatim from
  `evidence_driver.gd`'s own `_integer_grid_violations()` — not reimplemented
  independently. A "SANITY CHECK" line reproduces the original 194/229440 before
  any breakdown is trusted.
- The border-strip and X-mark bounding rects **are this script's own arithmetic**
  (disclosed as such, not claimed as (A)) — built from `BoardView`'s own public
  consts (`CARD_TARGET_OUTLINE_INSET`/`WIDTH`, `CARD_TARGET_ILLEGAL_MARK_INSET`/
  `WIDTH`) and `BoardCoords`' own public consts, applying the same arithmetic
  `board_view.gd`'s own `_build_card_target_outline()` /
  `_build_card_target_illegal_mark()` use to place these primitives in the first
  place, run in reverse to build an inspection rect instead of a drawn one. The
  border region (local x/y `[3,5)`/`[27,29)`) and the X bounding box (local x/y
  `[7,25)`) are geometrically non-overlapping (a 2-local-pixel gap between them),
  so no block can be double-counted between the two buckets.

## How to run

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s prototypes/godot-specialist-u013-check4-decomposition-2026-09-22/decompose_check4.gd
```

## Status

Concluded. See `run_output.txt` for the raw output this README's findings are drawn
from — full numbers are reported in the parent `godot-specialist` report to the
coordinator, not duplicated here.

## Findings

See `run_output.txt`. Summary: the sanity check reproduces 194/229440 exactly. The
legal cell's border-only region (no X present there) and the illegal cell's
border-only region both come back at 0 violations; effectively the entire 194 sits
inside the illegal-mark's X bounding box. This means — for this specific rendering
architecture and this specific geometry — redrawing only the X as hand-authored
pixel art would be sufficient to reach 0 on this check; the border does not need to
change.

## What is deliberately NOT covered by this spike

- Whether Check 4 should apply to vector-drawn overlay primitives at all (the
  coordinator's actual open question) — out of scope, reported separately.
- The pixel-art visual-standard question of what the X mark's shape *should* be
  (`art-director`'s territory).
- Whether the same "border clean, diagonal dirty" pattern holds for other
  window sizes / scale factors — only 1280x720 / scale=2 was measured here,
  reusing the one real diagnostic PNG that already exists.
