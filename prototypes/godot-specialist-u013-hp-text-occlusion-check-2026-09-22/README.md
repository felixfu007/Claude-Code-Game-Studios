# Spike: does the illegal-mark X occlude the HP text? (2026-09-22)

> PROTOTYPE — NOT FOR PRODUCTION / 拋棄式驗證探針
> **Executed by**: `godot-specialist`, headless, reading back an already-accepted real PNG.

## What this is for

Coordinator opened `production/qa/evidence/u013-card-target-highlight-2026-09-22.png` by eye
and could not read the illegal cell's "5/5" HP text, while the legal and neutral cells' text
was clearly readable. `board_view.gd`'s class doc comment (~line 56-58) promises "a piece's
HP bar/text is never painted over by a threat or attack highlight" — but names only
`threat`/`attack`, not `CardTargetHighlightLayer` (U-013's new layer). Whether that gap is a
real defect, an intentional (if unstated) design choice, or a visual misread was explicitly
left open by the coordinator, who asked for pixel measurement instead of another eyeball
judgement.

## Method

Reads `production/qa/evidence/u013-card-target-highlight-CONTEXT-full-window-2026-09-22.png`
back with the `Image` API (no rendering pipeline — pure pixel read-back, same justification
prior u013 sub-investigations already used). Does **not** open the image visually.

- Scale/window rect are obtained by calling `WorldLayout.compute_scale()`/`compute_rect()`
  for the same `1280x720` window the evidence run used — not hardcoded.
- The HP-text-panel window rects are built from `BoardView`'s own public consts
  (`HP_TEXT_TOP_MARGIN`, `HP_TEXT_HEIGHT`) and `BoardCoords`' own consts — disclosed as (B),
  not (A): real constants, this script's own rect arithmetic, consistent with the disclosure
  standard used in the two prior u013 sub-investigations today.
- Compares the legal cell's HP-text panel against the illegal cell's, pixel-by-pixel, at
  identical relative offsets (both panels are the same size by construction) — this sidesteps
  the fact that `HP_TEXT_COLOR_NORMAL` (`Color.WHITE`) and `CARD_TARGET_OUTLINE_COLOR`
  (`(1,1,1,0.9)`, used for both the outline and the X) are both white/near-white, so no single
  pixel's raw colour can tell text-stroke from X-stroke apart on its own.

## How to run

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s prototypes/godot-specialist-u013-hp-text-occlusion-check-2026-09-22/check_hp_text_occlusion.gd
```

## Status

Concluded. Full raw output in `run_output.txt`; summary and judgement reported to the
coordinator directly (not duplicated here — see that conversation for the full three-question
answer and the reasoning behind the ⓐ/ⓑ/ⓒ call).

## What is deliberately NOT covered by this spike

- Whether/how to fix it — out of scope, `src/` is off-limits for this task and a fix needs its
  own authorization.
- Any cell/window size other than the one already-captured evidence image (`1280x720`,
  `LEGAL_CELL=(3,0)` vs `ILLEGAL_CELL=(5,0)`).
- The `HP_TEXT_COLOR_PREVIEW` (amber) case — this scenario only exercises the normal (white)
  HP text colour path.
