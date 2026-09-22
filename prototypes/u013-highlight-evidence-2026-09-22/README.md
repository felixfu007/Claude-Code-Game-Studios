# Spike: U-013 card-target three-state highlight evidence driver (2026-09-22)

> PROTOTYPE — NOT FOR PRODUCTION / 拋棄式驗證探針
> **Executed by**: `ui-programmer` (1st–3rd revisions), `godot-specialist` (4th revision), on
> this development machine, real GPU (non-headless)
> **Engine**: `Godot_v4.7.1-stable_win64_console.exe` (`Godot Engine v4.7.1.stable.official.a13da4feb`)

> 🔴 **RESOLVED, 4th revision (2026-09-22, manager ruling: "重寫成走真正的管線(推薦)").**
> The 3rd revision's "open, undecided finding" below (194 Check-4 violations, later measured
> as 178 real distinct blocks after a counting-bug fix) is **closed**: it was a measurement
> artifact of this driver's own architecture, not a `board_view.gd` defect and not a
> Check-4-applicability question. The 3rd revision instantiated `BoardView` **directly**
> under the root `Window` and hand-applied `WorldLayout`'s scale
> (`_instance.scale = Vector2(_scale, _scale)`) — bypassing the real `SubViewport` +
> `SubViewportContainer` (`world_viewport_scaler.gd`) pipeline `src/ui/battle/BattleScreen.tscn`
> actually uses. Verified in
> `prototypes/godot-specialist-u013-subviewport-pipeline-check-2026-09-22/` that the real
> pipeline (`SubViewport.stretch_shrink` forcing internal rendering at the fixed 480×270 base
> canvas, then nearest-upscaled) produces **0/229440 Check-4 violations** on the identical
> scenario. The 4th revision of this driver (below) rebuilds the real pipeline and confirms
> the same **0** result live end-to-end, including the production-evidence write this driver
> gates on it. **The original finding text further down is kept verbatim, unmarked-up, as the
> historical record of what was measured and why it looked unresolved at the time** — see
> "### 4." for the closure note inline at that point, and
> `prototypes/godot-specialist-u013-check4-decomposition-2026-09-22/README.md` /
> `prototypes/godot-specialist-u013-subviewport-pipeline-check-2026-09-22/README.md` for the
> full investigation.

## What this is for

`production/session-state/active.md`'s 2026-09-22 handoff table lists four items that
need real-GPU screenshot evidence + human eyes because headless does not rasterize
`Control`/`Node2D` drawing. This spike covers exactly one of the four:

> **`board_view.gd` 三態高亮的畫面正確性** — U-013's `set_card_target_highlights()`
> (legal cell = hollow outline; illegal cell = same outline + X mark; neither = nothing
> drawn) only has structural tests (does the right node/type exist), not a check that it
> **looks** like an outline / an X / nothing.

The other three items on that table (menu grayscale disabled-state, enemy-turn
step-by-step animation, "confirm key really fires the action") are **out of scope for
this spike** — the coordinator explicitly asked for this one item only, done properly,
before touching the other three.

## Hypothesis

`BoardView.set_card_target_highlights(legal_cells, illegal_cells)` — called exactly as
`battle_screen.gd` would call it, on the real `res://src/ui/battle/BoardView.tscn` scene,
never a copy or re-implementation — produces three visually distinguishable states on a
real rendered GPU frame:

1. A cell in `legal_cells` → a hollow white square outline, piece still visible through it.
2. A cell in `illegal_cells` → the same outline **plus** a diagonal X mark, same colour
   (P-F3: shape distinguishes, not colour).
3. A cell in neither array → nothing drawn at all (the third state is silence, not a
   third visual).

## How to run

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . prototypes/u013-highlight-evidence-2026-09-22/EvidenceDriver.tscn
```

Non-headless (opens a real 1280×720 window, real Vulkan/Forward+ GPU). Exits 0 only if
both images independently pass every check for their own screenshot-classification
category (see `.claude/docs/coding-standards.md`'s "Screenshot classification" section);
exits 1 otherwise, in which case **nothing is written to `production/qa/evidence/`** —
see "Validate-before-write" below. Full stdout of the actual run this README describes
is saved alongside it as `run_output.txt`.

🔴 **4th-revision update**: this now builds the REAL `SubViewportContainer`/`SubViewport`
pipeline (see "### 4." below) instead of hand-scaling `BoardView` directly — the command
above is unchanged, but what it renders through changed. The 4th-revision run exits **0**;
both images passed and both were written to `production/qa/evidence/`.

A companion headless diagnostic, `diag_scan_column.gd`, was used mid-investigation to
read pixel values back out of an already-saved PNG (pure `Image` API, no rendering
pipeline involved, so headless is fine for that one specific purpose) — see its own
header comment and the "Findings" section below for what it was for.

## Coordinate disclosure

The driver calls `BoardView.set_card_target_highlights([LEGAL_CELL], [ILLEGAL_CELL])`
with `LEGAL_CELL=(3,0)`, `ILLEGAL_CELL=(5,0)`; `NEUTRAL_CELL=(7,0)` is passed to neither
array. All three are on terrain row 0, which is all `"."` (plain ground) in the real
level file `assets/data/levels/vs01_terrain.txt`, and all three carry the IDENTICAL piece
(PLAYER faction, `sprite_index=0`) so that any measured pixel difference between the
three cells can only be caused by the highlight call itself, never by different piece
art or terrain underneath it.

## Status

🔴 **Concluded, 4th revision (2026-09-22).** All four screenshot checks pass on both images
through the real `SubViewport` production pipeline; both images were written to
`production/qa/evidence/`. See "### 4." below for the closure note. The paragraph directly
below this one describes the 3rd revision's status and is kept as historical record — it was
true of that revision, at that time, through that revision's own (non-representative)
rendering path.

> **3rd-revision status (superseded, kept for history):** In progress — one open, undecided
> finding (see below). Two of the four screenshot checks a human needs (dimensions/coordinate
> correctness, and the outline/X/nothing distinction itself) pass cleanly and are supported by
> both mechanical checks and direct visual inspection of the saved images. The fourth check
> (pixel-art integer-scale grid integrity) does not currently pass, and whether that is a real
> defect or a check-applicability question has been left for the coordinator to decide (see
> below) — this driver does not decide it, and does not exclude anything to force it to pass.

## Findings

### 1. Centering — this run's own driver mistake, not a `src/` defect

The first two revisions of this driver scaled the `BoardView` instance by a hardcoded,
invented `SCALE_FACTOR = 4` and left its position at the node default `(0,0)` — neither
number came from the project's real scaling authority. `technical-preferences.md` is
explicit that world-layer scale "必須呼叫 `world_layout.gd` 的 `compute_scale()`,不得自行
計算,不得複製公式" (must be obtained by calling `WorldLayout.compute_scale()`, never
self-computed). The 3rd revision (the one this README describes) calls the real API
instead. Raw output from this run:

```
CENTERING ANSWER -- WorldLayout.compute_scale((1280, 720)) = 2
CENTERING ANSWER -- WorldLayout.compute_rect((1280, 720)) = [P: (160, 90), S: (960, 540)]
```

This matches `technical-preferences.md`'s own decision table exactly (1280×720 → 2×,
though the table's own rows only list 1080p/2K/4K/ultrawide — 1280×720 is this driver's
own arbitrary window choice, not one of the four named resolutions). The board is
correctly centered with equal 160px left/right and 90px top/bottom margins once the real
API is used. **The earlier "board looks off-center" observation (raised by the
coordinator against the 2nd revision's screenshot) was correct as an observation — the
board really was not centered in that screenshot — but the cause was this driver's own
omission (it had never called the real centering authority in the first place), not a
defect in `board_view.gd` or any other `src/` file.**

🔴 **This is the same shape of failure `technical-preferences.md` already has a
registered case of**, and it is worth naming explicitly because it happened again here:
a throwaway/analysis script re-implemented a piece of production math itself (a
"driver-only camera zoom" scale factor plus an implicit `(0,0)` position) instead of
calling the one real production function, and — being "only for analysis, not shipped
code" — nothing caught it until a human looked at the resulting image and noticed
something looked wrong. The registered precedent (`technical-preferences.md`, "🔴 (A) 的
精確定義" section) is the 2026-08-31 awk board-measurement spike that assumed `#`
terrain was impassable when `board.gd`'s real `MOVE_COST` table says it is passable
(cost 3) — a different re-implemented rule, the same failure shape: *a script that is
"just for analysis" reimplements a rule instead of calling the real one, runs cleanly,
and produces a wrong-looking result with no error of its own to flag it.* Nothing in
this spike's tooling would have caught the `SCALE_FACTOR = 4` mistake either, if the
coordinator had not looked at the screenshot and asked "is that centered?" — the fix
came from a human eye, not from a check.

### 2. Occlusion — StatsLayer draws above CardTargetHighlightLayer

The 1st revision's mechanical checks sampled a point near each cell's top edge expecting
to find the outline's white border there, and got background/HP-panel colours instead.
Root cause, confirmed by reading `board_view.gd`'s own layer-order doc comment and
geometry constants: `StatsLayer` (the HP bar + HP text panel) draws **above**
`CardTargetHighlightLayer`, and the HP text panel is a full-cell-width box sitting at the
very top of the cell — it visually covers the outline's top border and the upper part of
its left/right borders. This is real, working-as-designed z-ordering (confirmed earlier
by an existing structural test, `card_target_selection_test.gd`'s layer-order check), not
a bug. Fix: sample a vertical band that `board_view.gd`'s own constants
(`HP_TEXT_TOP_MARGIN`, `HP_TEXT_HEIGHT`, `HP_BAR_BOTTOM_MARGIN`, `HP_BAR_HEIGHT`)
guarantee is clear of both the text panel and the bar. Diagnosed using
`diag_scan_column.gd` (headless read of an already-saved PNG's raw pixel column) before
writing the fix — see that file.

### 3. The three-state distinction itself — passes, both mechanically and visually

From this run's raw output (`run_output.txt`):

```
Category C Check 2 -- left-border clear-zone max brightness: legal=0.949... illegal=0.949... neutral=0.509...
Category C Check 3(b) -- center-pixel brightness: legal=0.509... illegal=0.994...
```

Legal and illegal cells both show the outline (clear-zone brightness ≈0.95, well above
the 0.75 threshold); the neutral cell does not (≈0.51). Only the illegal cell's centre
is bright (≈0.99, where the X's two diagonals cross); the legal cell's centre is not
(≈0.51, hollow). This matches visual inspection of both saved diagnostic PNGs (see
"Diagnostic images" below) — left piece: hollow white square, piece and `5/5` visible
inside it; middle piece: same outline plus a clear corner-to-corner X; right piece: no
mark at all.

### 4. ✅ RESOLVED (4th revision, 2026-09-22) — Check 4 (pixel-art integer-scale grid) does not pass through this driver's original rendering path; passes cleanly through the real one

🔴 **Closure note, read this first.** The rest of this section (below the closure note) is
the 3rd revision's original text, **kept verbatim and unmarked-up as the historical
record** — it was an honest, correctly-measured finding at the time, about the rendering
path this driver used at the time. It is superseded, not wrong.

**What was actually wrong: this driver's own rendering path, not `board_view.gd`.** The 3rd
revision instantiated `BoardView` **directly under the root `Window`** and hand-applied
`WorldLayout`'s scale (`_instance.scale = Vector2(_scale, _scale)`, `_instance.position =
Vector2(_world_rect.position)`). Production never does this: `src/ui/battle/BattleScreen.tscn`
puts `BoardView` inside a real `SubViewport`, wrapped in a `SubViewportContainer` driven by
the real `src/ui/battle/world_viewport_scaler.gd` script. Per `SubViewportContainer
.stretch_shrink`'s documented semantics, a container sized to `BASE*scale` with
`stretch_shrink = scale` forces its child `SubViewport` to render internally at **exactly
`WorldLayout.BASE_WIDTH x BASE_HEIGHT` (480×270)** regardless of window size, then upscales
that FIXED low-resolution texture with nearest-neighbour filtering
(`WorldViewportContainer.texture_filter = 1` in `BattleScreen.tscn`). Under that pipeline the
diagonal `Line2D` (`Line2D.antialiased` already `false`) is rasterized ONCE at native 480×270
— a hard, binary per-source-pixel decision, i.e. genuinely "pixel art" already — and the
nearest-upscale of a fixed low-res image by an integer factor is block-clean by construction,
the same guarantee that already made every `Texture2D`-based highlight (move/attack/threat)
pass Check 4. **The vector-primitive outline/X-mark never needed to become a texture; the
evidence-capture driver needed to stop bypassing the `SubViewport`.**

**Verification, in two steps:**

1. `prototypes/godot-specialist-u013-subviewport-pipeline-check-2026-09-22/` built the real
   `SubViewportContainer`/`SubViewport`/`BoardView` subtree standalone and re-ran the exact
   same three-cell scenario: **`Check 4 (corrected single-count algorithm) on REAL
   SubViewport pipeline, full window = 0 / 229440`** (see that directory's `run_output.txt`).
2. This driver's own 4th revision (below) rebuilds that same real pipeline in place of the
   direct-`Node2D.scale` approach and reproduces the same result live, end-to-end, including
   the `production/qa/evidence/` write it gates on passing:
   `Category A Check 4 ... = 0 / 229440` / `Category C Check 4 ... = 0 / 7488` — see this
   run's own `run_output.txt`.

**A related, separate bug was also found and fixed along the way** (not the cause of the 194,
but inflated its reported size): `_integer_grid_violations()`'s inner `break` only exited the
`dx` loop, not the `dy` loop, so a block whose violating pixel appeared on more than one row
got counted more than once. The 194 originally reported was **178** real distinct violating
blocks once that bug was fixed and measured against the ORIGINAL (bypassing) rendering path —
see `prototypes/godot-specialist-u013-check4-decomposition-2026-09-22/README.md`. That same
investigation also found that ~124 of those 178 blocks were an unrelated HP-bar top/bottom
edge artifact present even on the untouched `NEUTRAL_CELL` (no card-target highlight drawn
there at all) — independent confirmation that most of the original 194/178 had nothing to do
with the X mark specifically, and (per step 1 above) **all of it, X mark included, disappears
under the real pipeline.** The 4th revision's `_integer_grid_violations()` (below) carries the
single-count fix regardless, since it is correct independent of which pipeline is used.

**Net effect on the open question originally posed** ("should the X be redrawn as
hand-authored pixel art, or does Check 4 not apply to vector primitives?"): **neither.** The
question presupposed the 194 was caused by how `board_view.gd` draws the X, and it was not —
it was caused by how this driver rendered the scene for measurement. No `src/` change and no
`coding-standards.md` change were needed.

---

**3rd-revision original text (superseded, kept for history) begins here:**

Raw output:

```
Category A Check 4 -- ... = 194 / 229440
Category C Check 4 -- ... = 194 / 7488
```

(HP text panels are excluded from this count already, per the same antialiased-text
carve-out `coding-standards.md` already documents for a real gameplay frame's Chinese UI
labels — that exclusion is pre-existing project policy, not something invented for this
spike.) Per `coding-standards.md`'s calibration on a real gameplay frame, the clean value
in the board region is **0** violations; 194 is not that.

**This driver deliberately does NOT exclude the illegal-mark's own diagonal-line region
to make this pass**, on the coordinator's explicit instruction: `coding-standards.md`'s
Category C Check 2 discipline states "a check that fails on a real screen does not get
replaced by a metric... because it looks reasonable at the time" — inventing an
exclusion region the moment a check goes red is the same shape of move that section
already names and rejects (this project's own U-011 precedent: switching to whole-image
colour count when the blind 12-point grid failed, withdrawn before shipping). So the
number stands, unmodified, for a human to judge.

🔴 **The actual open question, stated as narrowly as the coordinator framed it, is
deliberately left unanswered here — it is not this spike's question to answer:**

> In a 480×270-base, integer-scale-only pixel-art project, a `Line2D` diagonal drawn as a
> vector primitive can never land on a clean N×N block boundary — a *pixel-art* diagonal
> is a staircase of individual pixels authored at the 480×270 canvas, not a scaled-up
> vector stroke. So: **do these 194 blocks mean the illegal-mark's X should be redrawn as
> hand-authored stepped pixels on the 480×270 canvas instead of a `Line2D`, or do they
> mean Check 4 does not apply to vector-drawn overlay primitives at all?**

This spans two domains at once — the pixel-art visual standard the X mark would need to
answer to (`art-director`'s territory) and how Godot is being asked to draw it
(`godot-specialist`'s territory) — and one of the two possible answers is a change to
`coding-standards.md` itself, a load-bearing file loaded at the start of every session.
**Neither of those is a call this spike, or the agent that ran it, should make alone.**
This finding — the 194/7488 (and 194/229440) numbers, what was excluded (HP text panels,
pre-existing policy) and what was deliberately NOT excluded (the illegal-mark region,
per explicit instruction this run), and the registered comparison point (0 violations is
the known-clean value for the board region on a real gameplay frame) — is handed to
whichever next agent owns that decision, unresolved, with no lean recorded either way.

### 5. Retry loop measured its own limit (3rd revision) — 🔴 4th-revision update: the retry loop mattered this time

**3rd-revision text (superseded for this specific claim, kept for history):** All 5 retry
attempts produced byte-identical numbers (194 violations, 0.6500 dominant share, 3 distinct
blind-sample colours) — see the 3rd revision's saved output. The scene is fully static
(nothing animates, no font/texture streams observed across attempts), so retrying cannot
change a structurally-caused failure; it only costs wall-clock time. Recorded here so the
next capture-tool author does not assume a retry loop buys anything against a
non-timing-related failure.

🔴 **4th-revision correction: this specific claim ("retries never help here") does not hold
under the real `SubViewport` pipeline.** This run's `attempt 1` measured **12/229440** Category
A Check 4 violations (Category C crop was already clean at 0/7488); `attempt 2` measured
**0/229440** on both. `RETRY-LOOP FINDING: ... attempts_identical = false` — see this run's own
`run_output.txt`. The most likely explanation is a one-frame timing gap between the
`SubViewportContainer`'s layout/resize taking effect and the `SubViewport`'s internal texture
fully catching up to it — not measured further here since the retry loop already exists
precisely to absorb exactly this kind of transient and did so correctly on the second attempt.
**Net lesson reversed from the 3rd revision's**: for THIS pipeline, retrying is not free
insurance against nothing — it caught a real one-frame settle delay the first attempt hit.

### 6. Unrelated side item, resolved earlier this session: was `prototypes/u009-menu-pause-input-probe-2026-09-22/`'s "3 methods can't fire `Button.pressed`" result a `--headless` artifact?

Not part of this spike's own scope, but the coordinator asked this be verified and
written down. Earlier this session, before this README's own investigation began, the
existing probe `prototypes/u009-menu-pause-input-probe-2026-09-22/probe_action_press.gd`
(a `SceneTree` script, not a scene — unrelated code, not modified) was re-run twice by
hand, once with `--headless` and once without, to check whether headless mode itself was
why all three of that probe's input-simulation techniques failed to trigger
`Button.pressed`:

```
=== headless run (reproduce prior claim) ===
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

after Input.action_press(ui_accept): a_pressed_count = 0
after Input.action_release(ui_accept): a_pressed_count = 0

=== windowed run (no --headless) ===
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org
Vulkan 1.4.325 - Forward+ - Using Device #0: Intel - Intel(R) Graphics

after Input.action_press(ui_accept): a_pressed_count = 0
after Input.action_release(ui_accept): a_pressed_count = 0
```

**Byte-identical result in both modes.** This rules out `--headless` as the explanation:
a real windowed run with a real Vulkan/Forward+ GPU device active produces the exact same
`a_pressed_count = 0` as the headless run. Whatever is preventing
`Input.action_press(&"ui_accept")` from reaching `Button.pressed` on a programmatically-
created, focused `Button`, it is not the `coding-standards.md`-documented
`Input.mouse_mode`-under-`--headless` no-op failure mode the coordinator asked this be
checked against — that specific risk does not apply here, confirmed by direct
side-by-side reproduction rather than by reasoning about it. This has a direct
consequence for the still-untouched "confirm key really fires" item on `active.md`'s
four-item table: simulated-input techniques inside the engine (headless OR windowed) are
not the way to prove that AC — it would need real OS-level input delivered to a real
window, the more expensive route the coordinator named and asked to be flagged before
committing to, not started this session.

## Evidence (4th revision, 2026-09-22) — production/qa/evidence/ DOES now have files

🔴 **This section supersedes "Diagnostic images (NOT evidence)" below, which describes only
the 3rd revision's (pre-pipeline-fix) run and is kept for history.** The 4th revision passed
all checks on both images (see "### 4." above); `production/qa/evidence/` received:

- `u013-card-target-highlight-2026-09-22.png` (352×192 — Category C crop)
- `u013-card-target-highlight-CONTEXT-full-window-2026-09-22.png` (1280×720 — Category A)

Per the standing rule (unchanged by this revision), these are gated writes — validate-before-
write ran the full check suite on the live captured images before either file was written,
retried once (see "### 5." above), and only wrote once both categories passed independently.

The diagnostic-copy mechanism (always writes to this directory regardless of pass/fail, never
gated) also ran and produced `diagnostic-*-CHECK4-PASSED.png` alongside this run. The 3rd
revision's `diagnostic-*-CHECK4-FAILED.png` files are **deliberately left in place, not
deleted** — same "keep the historical record" instruction that applies to this README's text
— so the before/after is visible side by side to the next person who opens this directory.

## Diagnostic images (3rd revision, superseded — kept for history)

Because Check 4 did not pass, `production/qa/evidence/` received **nothing** this run
(validate-before-write: no PNG is written there unless every check for that image's own
classification category passes — see `evidence_driver.gd`'s class doc comment). Per the
coordinator's explicit instruction, the two images from the last attempt were instead
saved here, in the prototype directory, with the filename stating Check 4's status:

- `diagnostic-crop-2026-09-22-CHECK4-FAILED.png` (352×192 — Category C crop)
- `diagnostic-context-full-window-2026-09-22-CHECK4-FAILED.png` (1280×720 — Category A)

**These are diagnostic material for judging the open Check 4 question above, not
accepted evidence.** They have been opened and looked at by this agent (`ui-programmer`)
— "代看", not "簽核" per this project's own distinction between the two. Manager/
coordinator sign-off is separate and has not happened.

## What is deliberately NOT covered by this spike

- The other three items on `active.md`'s four-item table (menu grayscale, enemy-turn
  animation, confirm-key-really-fires) — out of scope per explicit instruction.
- ~~Whether Check 4's 194 violations should gate this story's Done state — that is the open
  question above, left to the coordinator.~~ 🔴 Resolved by the 4th revision: see "### 4."
  above — there were no real violations to gate on once the real pipeline was used.
- Gamepad/keyboard input into this scene — this driver only calls `BoardView`'s public
  draw methods directly; no input is simulated or required.
- Any window size other than `1280x720`, or any scenario other than the one three-cell
  layout this spike has always used — not re-measured at other resolutions/scale factors by
  any revision of this driver.
