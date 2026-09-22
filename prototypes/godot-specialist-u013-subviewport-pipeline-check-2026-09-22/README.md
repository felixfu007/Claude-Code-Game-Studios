# Spike: does U-013's Check-4 failure survive the REAL SubViewport pipeline? (2026-09-22)

> PROTOTYPE — NOT FOR PRODUCTION / 拋棄式驗證探針
> **Executed by**: `godot-specialist`, on this development machine, real GPU (non-headless).
> **Engine**: `Godot_v4.7.1-stable_win64_console.exe` (`Godot Engine v4.7.1.stable.official.a13da4feb`)

## What this is for

`prototypes/u013-highlight-evidence-2026-09-22/evidence_driver.gd` instantiated the real
`res://src/ui/battle/BoardView.tscn` **directly under the root `Window`** and applied
`WorldLayout`'s scale by hand (`_instance.scale = Vector2(_scale, _scale)`). That is **not**
how production actually renders `BoardView`: `src/ui/battle/BattleScreen.tscn` puts
`BoardView` inside a real `SubViewport`, wrapped in a `SubViewportContainer` driven by the
real `src/ui/battle/world_viewport_scaler.gd` script (`stretch_shrink = WorldLayout
.compute_scale(...)`, `position`/`size` from `WorldLayout.compute_rect(...)`,
`texture_filter = 1` i.e. Nearest — all read directly from `BattleScreen.tscn`).

Per `SubViewportContainer.stretch_shrink`'s own documented semantics, a container sized to
`BASE*scale` with `stretch_shrink = scale` forces its child `SubViewport` to render
internally at **exactly `BASE_WIDTH x BASE_HEIGHT` (480x270)**, regardless of window size —
then the container upscales that fixed low-res texture with **nearest-neighbour** filtering.
If that is right, the diagonal `Line2D` (and the outline `ColorRect`s) get rasterized
**once, at native 480x270**, with `Line2D.antialiased = false` already set — i.e. a hard,
binary per-source-pixel decision, exactly what "pixel art" means — and the nearest-upscale
of a *fixed* low-res image by an *integer* factor is block-clean by construction, the same
guarantee that already makes every `Texture2D`-based highlight layer (move/attack/threat)
pass Check 4. This spike tests that hypothesis directly, on the exact rendering path
production uses, instead of reasoning about it.

## Method

Builds the **real** `SubViewportContainer` → `SubViewport` → `BoardView` subtree
programmatically: same node types, `texture_filter = 1` / `stretch = true` (both copied from
`BattleScreen.tscn`'s literal values, not invented), and the **real**
`world_viewport_scaler.gd` script attached to the container (not reimplemented) — so
`stretch_shrink`/`position`/`size` come from the actual production code calling
`WorldLayout.compute_scale()`/`compute_rect()`, not from this script's own math. Deliberately
**not** a copy of the full `BattleScreen.tscn` (no `UILayer`/`HandBar`/etc.) — those are
irrelevant to this question and would only add unrelated failure surface; this is the minimal
real subtree the question is actually about.

Runs the identical three-cell scenario `evidence_driver.gd` used (`LEGAL_CELL=(3,0)`,
`ILLEGAL_CELL=(5,0)`, `NEUTRAL_CELL=(7,0)`, same terrain/piece data,
`set_card_target_highlights([LEGAL_CELL], [ILLEGAL_CELL])`) and re-runs a Check-4
measurement on the resulting full-window capture.

🔴 **Uses a corrected single-count-per-block algorithm**, not `evidence_driver.gd`'s original
one. See `prototypes/godot-specialist-u013-check4-decomposition-2026-09-22/README.md` for the
bug: that function's inner `break` only exits the `dx` loop, not the `dy` loop, so a block
whose violating pixel appears in more than one row gets counted more than once. This does not
change a `0` result (nothing to double-count), but is disclosed for anyone reusing this code.

## How to run

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . prototypes/godot-specialist-u013-subviewport-pipeline-check-2026-09-22/PipelineDriver.tscn
```

Non-headless (real GPU). Full raw stdout of the run these findings are drawn from is saved
alongside this README as `run_output.txt`.

## Status

Concluded.

## Findings

Raw output (`run_output.txt`):

```
PIPELINE PROBE -- SubViewportContainer.stretch_shrink = 2
PIPELINE PROBE -- SubViewport.size (should be exactly BASE_WIDTHxBASE_HEIGHT = 480x270 if the stretch_shrink hypothesis is right) = (480, 270)
PIPELINE PROBE -- full window image size = (1280, 720)
PIPELINE PROBE -- SubViewport's OWN internal texture size = (480, 270)
PIPELINE PROBE -- Check 4 (corrected single-count algorithm) on REAL SubViewport pipeline, full window = 0 / 229440
```

1. **The `stretch_shrink` hypothesis is confirmed exactly**: the `SubViewport`'s own internal
   render resolution is `(480, 270)` — bit-for-bit `WorldLayout.BASE_WIDTH x BASE_HEIGHT` —
   regardless of the `1280x720` window size feeding into `WorldLayout.compute_scale()` = 2.
2. **Check 4 measures 0/229440 violations** on the exact same `set_card_target_highlights()`
   call, exact same cells, exact same board region, that
   `prototypes/u013-highlight-evidence-2026-09-22/` measured as 194 violations (178 after
   fixing the double-count bug) through its own direct-Node2D-scale bypass of the
   `SubViewport`.
3. **Conclusion: the 194/178 violations `u013-highlight-evidence-2026-09-22` measured are an
   artifact of that spike's own evidence-capture driver skipping the real rendering pipeline
   — not a defect in `board_view.gd`'s drawing method, and not something Check 4 needs an
   exemption for.** Under the pipeline production actually uses, both the outline
   `ColorRect`s and the illegal-mark `Line2D` diagonal are already pixel-grid-clean, for the
   same structural reason every texture-based highlight already is: they get resolved to a
   fixed low-resolution image once, before any integer nearest-neighbour upscale happens.
4. This also resolves `prototypes/godot-specialist-u013-check4-decomposition-2026-09-22`'s own
   unexplained ~124/178-violation "other" bucket (the HP-bar top/bottom edge mismatch present
   even at the untouched neutral cell) — that too disappears to 0 under the real pipeline,
   confirming it was likewise an artifact of bypassing the `SubViewport`, not a pre-existing
   `board_view.gd` defect either.

## What is deliberately NOT covered by this spike

- Whether `evidence_driver.gd` itself should be rewritten to go through a real
  `SubViewportContainer`/`SubViewport` (so future evidence captures for this and other
  `BoardView`-based stories reflect the real pipeline) — that is a process/tooling
  recommendation for the coordinator, not something this spike implements.
- Any window size or scenario other than `1280x720` / the one three-cell layout reused from
  `u013-highlight-evidence-2026-09-22` — not re-measured here.
- Whether the same 480x270-native-render-then-nearest-upscale guarantee holds for content
  that straddles the `SubViewport`'s own edge (off-board UI, camera effects, etc.) — out of
  scope, this spike only exercises `BoardView` content well inside the board region.
