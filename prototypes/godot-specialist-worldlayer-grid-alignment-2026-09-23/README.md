# World-layer grid-alignment probe (2026-09-23)

## What hypothesis is being tested

Manager ruling (2026-09-23): for the "Route ① — redefine Check4's world-layer
exemption to read `SubViewport.get_texture().get_image()` directly instead of
cropping the container rect out of the full-window screenshot" question, do
**one round of grid-alignment investigation first**, before `lead-programmer`
touches the rule text.

The specific question handed to this probe: real world-layer content (board
tiles, unit sprites) sits at some position in the `SubViewport`'s native
480x270 coordinate system. Does that position land on a multiple of the
content's own "intended integer scale" — the number Check4's fixed,
absolute-origin block grid needs it to land on, or it reports a spurious
violation regardless of whether the pixels are actually clean?

This probe does **not** decide whether Route ① should be adopted. It only
reports what was measured. That is `lead-programmer`'s / the manager's call.

## How to run

Headless, structural/state only (this is what this probe actually ran):

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . prototypes/godot-specialist-worldlayer-grid-alignment-2026-09-23/ProbeWorldlayerGridAlignment.tscn
```

Output on disk: `run_output_headless.txt` (full raw log, tee'd at capture time).

This probe loads the real `res://src/ui/battle/BattleScreen.tscn`
(`instantiate()` → `get_tree().root.call_deferred("add_child", ...)` → wait 4
frames), per `technical-preferences.md`'s "(A) 的精確定義" point 5 — not a
stand-in scene, not a re-implementation of `BoardView`/`WorldLayout`'s layout
math. It relies on `battle_screen.gd`'s own default-data self-initialization
(no synthetic data was injected) to populate real terrain, pieces, and stat
blocks, then walks every descendant of the real `WorldViewport` node,
recording each node's actual engine-computed `.get_class()`, `.position`, and
(for `Node2D`) `.scale`.

No window was opened by this probe — see "What was reused instead of
re-measuring" below for why, and what that choice costs.

## Current status

Concluded. One combined run answered every open item this probe was
responsible for; no second pass was needed.

## Findings

### Q1 — what content is actually in the world layer, and what's each type's "intended integer scale"?

Engine-measured (not asserted) from the real loaded scene, `WorldViewport`
subtree, 142 total descendant nodes:

| Type | Count | What it is | Node2D `.scale` set anywhere in source? |
|---|---|---|---|
| `Sprite2D` | 89 | 78 terrain tiles (13×6 board) + 10 piece sprites + 1 cursor sprite | No — `board_view.gd` never assigns `.scale` on any `Sprite2D` it creates (confirmed by `grep -n "\.scale\s*="` across `src/ui/battle/*.gd` → zero hits, and by `grep -n "scale"` across `src/ui/battle/*.tscn` → zero node-property hits) |
| `Node2D` | 29 | `BoardView` itself (1) + its 8 layer-container children (`TerrainLayer`, `MoveHighlightLayer`, `AttackHighlightLayer`, `CardTargetHighlightLayer`, `ThreatHighlightLayer`, `PiecesLayer`, `AffinityLineLayer`, `StatsLayer` — structural, not drawn content) + 10 per-piece stat-block roots + 10 per-piece HP-bar roots | No |
| `ColorRect` (a `Control`, not `Node2D`) | 20 | HP bar background + fill, 2 per piece × 10 pieces | N/A — `Control` has no `.scale` the way `Node2D` does |
| `Line2D` | 4 | 2 affinity-line entries × (backing stroke + colour stroke) | No |

**Every type's "intended integer scale" for content drawn directly inside the
`SubViewport` is 1.0.** `BoardCoords.CELL_SIZE = 32` and
`board_view.gd`'s piece anchoring math (`_piece_anchor`,
`PIECE_SPRITE_HEIGHT = 40`) are pixel-count constants for a 480×270-space
layout — they are not `Node2D.scale` values. The actual integer-multiple
scaling this project's screen-architecture decision cares about (4×/5×/8× per
`WorldLayout.compute_scale()`) happens entirely **outside** the `SubViewport`,
at the `WorldViewportContainer.stretch_shrink` level (measured this run:
`stretch_shrink=2`, container `size=(960.0, 540.0)`, `WorldViewport.size=(480,
270)` — i.e. this run's window was sized for a 2× shrink/expand factor, not
one of the four production target resolutions; `WorldLayout.compute_scale()`
itself was not re-invoked by this probe, so this run's own container-level
factor is not being claimed as one of the table's four rows).

Zero synthetic content was added — Q1/Q2 are entirely about what
`battle_screen.gd`'s real default-data path already draws.

### Q2 — do real positions align to multiples of that scale? (core question)

**Measured directly, not inferred: 0 out of 142 real `Node2D` descendants
have `.scale != Vector2(1, 1)`.** (`run_output_headless.txt`, line `Q2: nodes
with .scale != Vector2(1,1) = 0`.)

Because block size in Check4's algorithm equals the scale being tested, and
every real node's scale is exactly 1, the block size for every one of them is
1×1 — a single pixel compared against itself. That comparison cannot fail by
construction, regardless of the pixel's position, integer or not. This is not
a new claim: the sibling probe
`prototypes/godot-specialist-check4-subviewport-readback-2026-09-23/` already
measured this exact real-scene case at the pixel level (see "What was reused"
below) and got `0 / 129600` — this probe's structural finding (0 non-unit
scales) is the reason that pixel result cannot be anything but 0, on any
future re-run, for any window size, as long as no real content adds a
non-unit `Node2D.scale`.

**So, answered precisely**: the question "do real positions align to
multiples of the intended scale" has the answer **"yes — trivially, because
the intended scale is 1 for every single node currently drawn in the world
layer, and any position aligns to a multiple of 1."** There is currently no
real content for which this alignment question has a non-trivial answer.

One incidental, informational-only finding surfaced along the way: 10 of the
29 `Node2D` (the per-piece HP-bar root nodes) have a **fractional** position —
e.g. `position=(48.0, 130.5)` — from `board_view.gd`'s
`bar_center_y = cell_top_left.y + CELL_SIZE - HP_BAR_BOTTOM_MARGIN -
HP_BAR_HEIGHT * 0.5` (the `* 0.5` on an odd `HP_BAR_HEIGHT = 3` forces a
`.5`). This is listed in `run_output_headless.txt` as `Q2-EVIDENCE` lines and
does **not** affect Check4 at scale=1 for the reason above — it is recorded
because "position is fractional" and "position is misaligned relative to an
intended scale" are two different things, and this probe was asked about the
second, not the first. Whether a fractional position matters for some *other*
check (e.g. sub-pixel rendering of the `ColorRect` fill it positions) was not
evaluated here — out of scope for this probe's question.

### Q3 — if not aligned, how large is the false-positive rate? (measured, not estimated)

**Not applicable to any currently-existing real content** — Q2 found zero
instances of the precondition ("scale != 1") that this question depends on.

For the record, the magnitude for a genuine instance of this defect shape
(synthetic, already engine-measured by the sibling probe, not re-derived
here): a non-integer-scale (3.3×) sprite, checked at its own nominal integer
scale (3), measured **21 / 25 blocks (84%) flagged** —
`prototypes/godot-specialist-check4-subviewport-readback-2026-09-23/run_output_windowed.txt`,
line `CHECK4-REGION [Q3B-BAD-nonint-scale-3.3-aligned] = 21 / 25`. That
probe's own first attempt (not the number above) also demonstrated the
*origin*-misalignment failure mode this probe was asked to check for
separately: a genuinely clean, integer-scale (3.0×) sprite positioned at a
coordinate that was not itself a multiple of 3 was **100% (16/16) falsely
flagged**, purely because Check4's grid is anchored at the buffer's absolute
`(0,0)`, not at the sprite's own origin. Repositioning to a multiple of the
scale (not changing the sprite itself) took that same clean sprite to `0/16`.
**This probe's contribution is establishing that this failure mode has no
current real-world instance to trigger it** — it is not saying the failure
mode itself doesn't exist, only that nothing in `board_view.gd` today has the
non-unit scale required to expose it.

### Q4 — is there a measurement method that avoids the false positive? Is it validated?

Yes, and it was already validated with a control by the sibling probe, not
invented fresh here: **anchor the block grid to the content's own local
origin (or equivalently, only test block-grid alignment at coordinates that
are themselves multiples of the scale being tested relative to the content's
origin), rather than to the buffer's absolute `(0,0)`.** Validation evidence
(both directions, same sibling probe):
- Correctly-scaled content, position aligned to the scale → `0/16` (no false
  positive).
- Genuinely non-integer-scaled content, same alignment discipline applied →
  `21/25` (still caught — the fix does not blind the check to real defects).

This probe adds one thing to that: **the fix is currently moot for
`board_view.gd`**, because there is no non-unit-scale content in the world
layer for a grid-origin choice to matter to. The choice between
"anchor at buffer origin" and "anchor at content origin" only produces
different results when a node's scale differs from 1 — this run confirms
zero such nodes exist today.

## What was reused instead of re-measuring (and why)

Q3 and Q4's supporting pixel numbers above are **cited from**, not
re-captured by, the sibling probe
`prototypes/godot-specialist-check4-subviewport-readback-2026-09-23/`
(`run_output_windowed.txt`). That probe already: (a) loaded the same real
`BattleScreen.tscn` the same way, (b) measured Check4 at scale=1 on the real
native buffer (`0/129600`, corroborating this probe's structural 0-count
finding at the pixel level), and (c) ran and validated the good/bad synthetic
control for the origin-alignment question. Re-running that windowed capture
today would have reproduced the same numbers a third time and cost the user's
foreground window for no new information — this was a judgement call by this
probe's author, not a rule; the raw numbers being cited are on disk at the
path above and are independently checkable.

**What this probe did NOT do, and does not claim to have done**: it did not
itself open a window, did not itself capture new pixels, and did not itself
re-run the synthetic good/bad control. Everything pixel-level in this README
is either (a) cross-cited from the sibling probe's own on-disk log, or (b) a
direct logical consequence of this probe's own headless, engine-measured
0-non-unit-scale finding (the tautology argument: block size 1 cannot fail,
independent of which run measures it).

## What is not known / not covered by this probe

- **Only the world layer's own drawn content was inspected — not the
  container-level (`WorldViewportContainer.stretch_shrink`) upscale step
  itself.** Whether that external nearest-neighbor upscale is *itself*
  always clean for every real window size (not just the `stretch_shrink=2`
  this run happened to run under) was not re-verified here; it is the
  subject of the `2026-09-23` "worldlayer-attribution" probe referenced in
  `.claude/docs/coding-standards.md`, not this one.
- **This run's own window/container scale (`stretch_shrink=2`,
  `WorldViewport.size=(480,270)`, container `size=(960,540)`) was whatever
  the engine's default headless viewport size produced — this probe did not
  set or verify a target window size, and did not itself call
  `WorldLayout.compute_scale()` to confirm which of the four production
  target-resolution rows (1080p/4×, 2K/5×, 4K/8×, ultrawide/5×) it
  corresponds to, if any.** Do not read the `stretch_shrink=2` figure above
  as one of those four rows.
- **Future content is not covered.** If a later story adds `Node2D` content
  inside the `SubViewport` with a non-unit `.scale` (a decorative parallax
  layer, a scaled VFX sprite, etc.), this probe's "trivially aligned" finding
  stops applying to that new content the moment it exists, and the
  origin-anchoring question in Q4 becomes live again for it specifically.
  This probe took no position on how such future content should be checked
  beyond citing the already-validated alternative method.
- **The 10 fractional-position HP-bar-root nodes were not checked against any
  rendering-quality concern other than Check4's block-grid test** (e.g.
  whether a `ColorRect` at a `.5`-pixel offset produces a visible seam under
  the project's `Nearest`-filter pixel-art discipline). That is a different
  question from the one this probe was dispatched to answer.
- **No conclusion is offered on whether Route ① should be adopted.** That is
  explicitly out of this probe's scope per the dispatch brief.

## Files in this directory

- `probe_worldlayer_grid_alignment.gd` — the probe script (structural/state
  walk of the real loaded scene's `WorldViewport` subtree).
- `ProbeWorldlayerGridAlignment.tscn` — minimal wrapper scene (root `Node`
  with the script attached) used to run the probe via a scene path rather
  than `-s` (the script is `extends Node`, not `extends SceneTree`).
- `run_output_headless.txt` — full raw console output from the headless run
  this README's findings are drawn from.
