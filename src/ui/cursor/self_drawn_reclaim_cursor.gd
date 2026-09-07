## Self-drawn substitute cursor (ADR-0005 機制十三, Story 011, TR-cursor-017).
## Sole owner of the continuous mouse-reclaim transparency feedback — the
## native OS/engine pointer's own visibility stays strictly BINARY
## ([NativePointerVisibilityArbiter] via [member Input.mouse_mode]); this node
## is where the GDD's "與移動進度成正比的透明度漸進顯示" requirement actually
## lives (ADR-0005 機制十三: "AC-31 的驗證掛載點因此定案:斷言對象是自繪節點的
## visible/modulate.a,不是 Input.mouse_mode").
##
## [b]Attached as a child of [code]CursorStateHost[/code]'s dedicated
## [CanvasLayer][/b] (機制十二), NOT sharing a node with
## [NativePointerVisibilityArbiter] — R6-8's per-node [member CanvasItem.modulate]
## hazard is exactly why the two are siblings, not one node (see that class's
## own doc comment and [code]src/ui/cursor/cursor_state_host.gd[/code]'s class
## doc comment on [member CursorStateHost._cursor_layer]'s exclusivity).
##
## [b]F3 smoother (2026-08-19 修訂) + R4-3 修法 (2026-08-19 第四輪修訂)[/b],
## reproduced here exactly per ADR-0005's own worked pseudocode and this
## story's dispatch Implementation Notes #2/#3:
## - [b]Rising edge (progress increasing toward the target) is NEVER rate
##   limited — it syncs immediately.[/b] This is not a style preference; it is
##   the only shape under which the GDD's "達到門檻的當下透明度達 100%" can be
##   true at all, given [member CursorReclaimVisualConfig.MIN_LEGAL_MAX_FRAMES]
##   forces at least a 2-frame convergence window on the FALLING side. If
##   rising were also rate-limited, [member _presented_alpha] could not
##   possibly reach [code]1.0[/code] on the exact frame the threshold is
##   crossed (this story's dispatch calls this "純數學推導", not a preference —
##   see that document for the derivation).
## - [b]Falling edge (triggers (a)(b)(c)) converges via [method @GlobalScope.move_toward]
##   over [member CursorReclaimVisualConfig.reclaim_visual_convergence_max_frames]
##   frames[/b] — "已顯示的透明度不得瞬間跳變" (AC-41).
## - [b]Trigger (d), [constant CursorTypes.ResetTrigger.VETOED_SAME_FRAME], is
##   the ONE exception[/b]: it snaps to the judged value within the SAME frame,
##   bypassing both the rising-immediate and falling-converge paths (AC-41b) —
##   avoiding the "progress reads 100% but the transfer never happened"
##   visual contradiction the GDD calls out by name.
##
## [b]NAN handling (2026-09-07 coordinator finding, this story's own fix)[/b]:
## [method CursorState.reclaim_progress] can return [code]NAN[/code] — measured
## on this engine, [code]0.0 / 0.0[/code] (a zero-configured reclaim threshold
## with the mouse still exactly at its seed) is [code]NAN[/code], and
## [method @GlobalScope.clampf] does not coerce [code]NAN[/code] into either
## bound (see [code]src/ui/cursor/threshold_mouse_reclaim_policy.gd[/code]'s own
## doc comment for the full measured derivation). [b]Every comparison against
## [code]NAN[/code] is [code]false[/code] under IEEE-754[/b] — a
## [code]target >= _presented_alpha[/code]-style guard would silently fail to
## catch it and [code]NAN[/code] would flow straight into
## [member CanvasItem.modulate]'s alpha channel. [method @GlobalScope.is_nan]
## is checked explicitly, up front, before any branch runs, and a
## [code]NAN[/code] reading is treated as "no progress" ([code]0.0[/code]) —
## the same interim ambiguity [method CursorState.reclaim_progress]'s own doc
## comment already documents for its [code]0.0[/code] return value (both
## "genuinely idle" and "input degenerate" collapse to the same presented
## alpha; that ambiguity is not introduced here, only inherited).
class_name SelfDrawnReclaimCursor
extends Node2D

## Visual radius of the drawn substitute pointer, in pixels. No `/art-bible`
## shape spec exists for this system (see this story's report on AC-36/48/49 —
## registered as uncovered, no graphic spec) — a plain filled circle is this
## story's own placeholder, not a design decision.
const _RADIUS_PX: float = 6.0

var _state: CursorState
var _visual_config: CursorReclaimVisualConfig

## Smoothed value actually written to [member CanvasItem.modulate]'s alpha
## channel — independent of [method CursorState.reclaim_progress]'s own
## instantaneous value, per 機制十三's "兩個值的模型" (see class doc comment).
var _presented_alpha: float = 0.0

## Set by [method _on_reset_triggered] when [constant CursorTypes.ResetTrigger.VETOED_SAME_FRAME]
## fires; consumed and cleared on the very next [method _process] call.
var _pending_snap: bool = false


func _init(state: CursorState, visual_config: CursorReclaimVisualConfig) -> void:
	_state = state
	_visual_config = visual_config
	# R6-12 convention (also followed by CursorStateHost itself and by
	# NativePointerVisibilityArbiter): process_priority set in _init(), before
	# this node is ever add_child()-ed onto the cursor CanvasLayer.
	process_priority = 50
	# Always visible=true; the "hidden" appearance for AC-31's binary case is
	# expressed purely through modulate.a == 0.0, not through this property —
	# see class doc comment's citation of ADR-0005's own verification-anchor
	# ruling ("visible/modulate.a").
	visible = true


func _ready() -> void:
	# R5-3: subscribe to CursorState's forwarding signal, never hold a
	# MouseReclaimPolicy reference directly (機制十三之二's sibling class
	# follows the same rule for the same reason — see that file).
	_state.reclaim_reset_triggered.connect(_on_reset_triggered)
	queue_redraw()


func _on_reset_triggered(trigger: CursorTypes.ResetTrigger) -> void:
	if trigger == CursorTypes.ResetTrigger.VETOED_SAME_FRAME:
		_pending_snap = true


func _process(_delta: float) -> void:
	# This story's own placeholder for "where the substitute cursor is drawn":
	# get_global_mouse_position() (CanvasItem), deliberately NOT
	# get_viewport().get_mouse_position() — ADR-0005 Validation Criteria #16(ii)
	# restricts THAT specific call to exactly one call site in the whole
	# project (CursorStateHost._get_mouse_position()). get_global_mouse_position()
	# is a distinct engine API; under this CanvasLayer's identity transform
	# (Validation Criteria #20), the two are numerically equivalent for this
	# node's own screen-space position, but this file does not add a second
	# occurrence of the restricted call text. Flagged in this story's report as
	# this story's own engineering judgment call, not a written rule.
	global_position = get_global_mouse_position()

	var target: float = _state.reclaim_progress()
	if is_nan(target):
		# See class doc comment's NAN section. Treated as "no progress" —
		# never allowed to reach modulate.a below.
		target = 0.0

	if _pending_snap:
		# Trigger (d): same-frame snap, bypasses both rising-immediate and
		# falling-converge paths entirely (AC-41b).
		_presented_alpha = target
		_pending_snap = false
	elif target >= _presented_alpha:
		# R4-3: rising direction is NEVER rate limited.
		_presented_alpha = target
	else:
		# Falling direction only (and not trigger (d)): converge over
		# reclaim_visual_convergence_max_frames frames (AC-41).
		var max_frames: int = max(_visual_config.reclaim_visual_convergence_max_frames, 1)
		var max_step: float = 1.0 / float(max_frames)
		_presented_alpha = move_toward(_presented_alpha, target, max_step)

	modulate.a = _presented_alpha


func _draw() -> void:
	# Placeholder shape — see _RADIUS_PX's own doc comment. AC-36/48/49
	# (visual distinguishability from other highlight states) have no graphic
	# spec to implement against; registered as uncovered in this story's
	# report, not silently invented here.
	draw_circle(Vector2.ZERO, _RADIUS_PX, Color.WHITE)
