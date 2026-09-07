## Concrete mouse-reclaim strategy (ADR-0005 機制八, Story 014) implementing
## GDD Core Rules #3「滑鼠奪回權威的空間門檻與漸進回饋」— the表面類型-anchored
## fixed-pixel-threshold design, current as of GDD 第十六輪 Approved.
##
## 🔴 [b]This submechanism's REDESIGN is user-frozen[/b] (GDD 第十二輪,
## 2026-08-11): this file implements the design AS SPECIFIED and does not
## attempt to mitigate either of its two known, accepted defects. Do not
## "fix" them here — see
## `production/epics/cursor-highlight-state/story-014-mouse-reclaim-frozen.md`'s
## own "凍結區" notice.
## [br]
## [b]Known confirmed, deliberately unmitigated defects (E1/E2)[/b]:
## - [b]E1[/b]: holding a directional key / analog stick down so that every
##   processed frame produces another NAVIGATION-class `ui_*` action can veto
##   the mouse's reclaim claim indefinitely (ADR-0005 Consequences → Risks,
##   [code]prototypes/cursor-reclaim-godot-spike-2026-08-05/[/code], 100%
##   reproducible). This is [b]outside this file's contract entirely[/b] —
##   whether a same-frame veto happens at all is Story 005's arbitration
##   decision (機制六); this class only implements what happens to the
##   accumulator WHEN [method reset] is called with
##   [constant CursorTypes.ResetTrigger.VETOED_SAME_FRAME].
## - [b]E2[/b]: a reverse-direction zero-threshold exemption can immediately
##   reclaim authority back from a freshly-transferred mouse (real-observed,
##   keyboard path only). Also outside this file's contract — that exemption
##   is part of Core Rules #3's device-authority arbitration (機制六), not
##   this policy's threshold math.
##
## [b]Data-driven tuning, not hardcoded[/b]: the per-surface-type threshold
## table is injected as a [MouseReclaimThresholdConfig] (dependency injection
## over singleton, per project coding standards) — never constructed
## internally, so callers (and tests) control every threshold value
## explicitly. See that class's doc comment for why its defaults are
## provisional and must not be relied upon by name.
class_name ThresholdMouseReclaimPolicy
extends MouseReclaimPolicy

var _config: MouseReclaimThresholdConfig

## Accumulator's seed position (root viewport space — see ADR-0005
## Constraints「單一根 Viewport 假設」and [MouseReclaimPolicy]'s own doc
## comment). Written ONLY by [method reset]; never touched by [method evaluate].
var _seed: Vector2 = Vector2.ZERO

## Cached result of the last [method evaluate] call. Returned by
## [method reclaim_progress] and zeroed by [method reset] — GDD Formulas:
## `reclaim_progress = clamp(accumulated_net_displacement_px / reclaim_threshold_px, 0.0, 1.0)`.
var _last_progress: float = 0.0


func _init(config: MouseReclaimThresholdConfig) -> void:
	_config = config


## GDD Formulas: net displacement is the STRAIGHT-LINE distance from
## [member _seed] to [param current_mouse_position] — never a path-sum of
## per-frame deltas (AC-45's whole reason for existing, and the whole reason
## [MouseReclaimPolicy.evaluate]'s signature takes an absolute position and
## not a delta — see that base method's own doc comment / ADR-0005's "F2 修法").
## Returns whether this frame's mouse position carries a valid reclaim claim
## (AC-28 / AC-28b: `>=` the threshold, not strictly greater — GDD 原文
## "達...以上").
##
## 🔴 [b]2026-09-07 fix (coordinator review): the boolean is derived from
## [member _last_progress] ([code]_last_progress >= 1.0[/code]), NOT from a
## separate [code]net_displacement_px >= threshold_px[/code] comparison.[/b]
## The old, separate comparison was a real bug: for a LEGAL (strictly
## positive) threshold the two forms are mathematically equivalent
## (`net >= threshold` ⟺ `clamp(net / threshold, 0, 1) >= 1.0`), so this
## change alone does not alter any correct-configuration behaviour — but for
## the two ILLEGAL configurations GDD Formulas 邊界值
## (`design/gdd/cursor-highlight-state.md` lines 143-144) documents, the old
## separate comparison directly CONTRADICTED what the GDD says happens.
## Concretely, with the old code, a negative threshold made [b]any[/b]
## non-negative net displacement satisfy `net >= threshold` and return
## [code]true[/code] — i.e. instant reclaim on the very first frame — while
## GDD line 144 documents the opposite: a permanent, silent lockout.
## Deriving from progress instead makes this method's illegal-input
## behaviour agree with the GDD's own account of it:
## [br]
## - [b]Negative threshold[/b] (GDD line 144): `net / negative <= 0`,
##   `clampf(..., 0.0, 1.0)` floors it to `0.0` — [method reclaim_progress]
##   permanently reads `0.0` and this method permanently returns
##   [code]false[/code], REGARDLESS of how far the mouse moves. This is the
##   GDD's own documented "比除以零更難察覺的靜默死鎖" (a silent deadlock, harder
##   to notice than a divide-by-zero) — NOT mitigated here. Story 006's
##   AC-46 startup rejection is still the only thing meant to prevent this
##   configuration from existing at all; this class only stops disagreeing
##   with the GDD about what happens if it does.
## - [b]Zero threshold[/b] (GDD line 143) — [b]measured, not inferred[/b],
##   on this engine (Godot 4.7.1, editor/debug binary, throwaway
##   [code]--headless --script[/code] probes run during this fix, not
##   committed to the repo): GDScript's `float / 0.0` is `INF` for a
##   positive numerator and `NAN` for a `0.0` numerator (`0.0 / 0.0`), and
##   the two behave DIFFERENTLY once clamped and compared — this is a
##   second, separate illegal-input split the GDD prose does not spell out:
##   - [code]net_displacement_px > 0.0[/code]: `net / 0.0` = `INF`,
##     measured `clampf(INF, 0.0, 1.0)` = `1.0` → this method returns
##     [code]true[/code] — the very FIRST frame with ANY mouse movement
##     immediately claims authority. This is a DIFFERENT failure shape than
##     the negative case's permanent lockout — the two illegal
##     configurations do not fail the same way.
##   - [code]net_displacement_px == 0.0[/code] (mouse has not moved from the
##     seed at all): `0.0 / 0.0` = `NAN`, and — measured —
##     `clampf(NAN, 0.0, 1.0)` returns `NAN` UNCHANGED (`clampf` does not
##     coerce `NAN` into either clamp bound). [method reclaim_progress]
##     would then hand `NAN` to any caller (e.g. Story 011's smoother), and
##     this method returns [code]false[/code] only because every comparison
##     against `NAN` (including `NAN >= 1.0`) is `false` under IEEE-754 —
##     not because anything here specifically detects or handles `NAN`.
## [br]
## [b]In this editor/debug build, [member _config]'s own boundary
## [method Object.assert] on
## [method MouseReclaimThresholdConfig.threshold_for_surface] intercepts
## both illegal configurations before either reaches this method at all —
## but the negative case is NOT intercepted cleanly.[/b] Measured (same
## probes as above, nested-call variant): a failed [method Object.assert]
## aborts only the function it is in and does not propagate to the caller,
## and GDScript then returns that function's declared return type's
## zero-value default — so a negative
## [member MouseReclaimThresholdConfig.board_tile_threshold_px]-style field
## does not reach here as a negative number at all; the assert silently
## substitutes `0.0`, and this method observes the ZERO-threshold behaviour
## above instead of the negative one. Only an export-release build (where
## [method Object.assert] is stripped, per this project's tech-debt
## register) would let a configured negative value reach this method
## unaltered and produce the permanent-lockout behaviour GDD line 144
## describes — no test in this repository runs against that build
## configuration today. See
## [code]tests/unit/cursor/mouse_reclaim_test.gd[/code]'s
## [code]test_negative_threshold_permanently_clamps_progress_to_zero_per_gdd_line_144[/code]
## for how that test reaches the negative case anyway (a bypass double, not
## a real [MouseReclaimThresholdConfig]).
func evaluate(current_mouse_position: Vector2, surface: CursorTypes.SurfaceType) -> bool:
	var threshold_px: float = _config.threshold_for_surface(surface)
	var net_displacement_px: float = _seed.distance_to(current_mouse_position)
	_last_progress = clampf(net_displacement_px / threshold_px, 0.0, 1.0)
	return _last_progress >= 1.0


func reclaim_progress() -> float:
	return _last_progress


## Reseeds the accumulator at [param seed_position] and zeroes progress.
## Emits [signal MouseReclaimPolicy.reset_triggered] with [param trigger] so
## the presentation layer (機制十三 / Story 011) can tell
## [constant CursorTypes.ResetTrigger.VETOED_SAME_FRAME] (the only trigger
## allowed to snap to zero within a single frame, AC-41b) apart from the
## other four (which must converge instead, AC-41) — this class does not
## decide which trigger applies; it only records and forwards whichever one
## its caller passes.
func reset(seed_position: Vector2, trigger: CursorTypes.ResetTrigger) -> void:
	_seed = seed_position
	_last_progress = 0.0
	reset_triggered.emit(trigger)


func diagnostic_seed_position() -> Vector2:
	return _seed
