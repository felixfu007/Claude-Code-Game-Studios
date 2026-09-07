## Native OS/engine mouse-pointer binary visibility arbiter (ADR-0005 機制十三
## + 機制十三之二, Story 011, Core Rules #5). Owns the ONLY write to
## [member Input.mouse_mode] in this system.
##
## [b]Binary only — no continuous alpha here.[/b] The connection between this
## class and [SelfDrawnReclaimCursor] is siblinghood under the same
## [CanvasLayer], not shared state: this class decides whether the REAL OS
## pointer is shown or hidden (機制十三's "僅二元顯示/隱藏"); the continuous
## mouse-reclaim transparency feedback lives entirely on the other node. Per
## ADR-0005's own verification-anchor ruling (機制十三: "Input.mouse_mode 的斷言
## 仍用於驗證原生指標的二元抑制〔Core Rules #5〕,兩者是兩個不同的驗證目標"),
## this class's own output stays HIDDEN throughout an in-progress mouse-reclaim
## attempt (`0 < reclaim_progress < 1`) — it does not read
## [method CursorState.reclaim_progress] at all, matching ADR-0005's own
## illustrative pseudocode for 機制十三之二, which branches only on device
## authority and the hover whitelist.
##
## [b]Attached as a distinct sibling node[/b] under [code]CursorStateHost[/code]'s
## [CanvasLayer] (機制十二), NOT the same node as [SelfDrawnReclaimCursor]
## (R6-8): [member CanvasItem.modulate] is a per-node property, and
## [SelfDrawnReclaimCursor]'s [code]modulate.a = _presented_alpha[/code] write
## every frame would otherwise drag this node's own visibility along with the
## reclaim fade — a real behavioral bug, not a style concern (see that class's
## own doc comment and ADR-0005's own "為何必須拆" note under 機制十三之二).
##
## [b]Whitelist, not blacklist[/b] (R5-6 + 專家發現 F, 2026-08-19 第三次修訂):
## the default answer for ANY hover target that is not explicitly registered as
## an AC-60 exception is HIDDEN (when authority is not mouse) — never VISIBLE.
## This makes every failure mode (an unregistered surface's ancestor chain set
## to [constant Control.MOUSE_FILTER_IGNORE], a non-[Control] registered
## surface, a forgotten exception registration) fail toward the SAFE side (Core
## Rules #5's hard rule) rather than the convenience side (AC-60's exception).
##
## [b]Hover-source is injected, not called inline[/b]
## ([param hovered_control_provider]) — this story's own engineering judgment
## call, not written anywhere in ADR-0005 (whose own illustrative pseudocode
## calls [method Viewport.gui_get_hovered_control] directly inline). Chosen for
## the same reason [code]cursor_state.gd[/code]'s
## [member CursorState._mouse_position_provider] is a [Callable] rather than an
## inline call: [method Viewport.gui_get_hovered_control] requires a real GUI
## hover pipeline to exercise headlessly, which this project's unit-test layer
## cannot drive deterministically without simulating actual mouse motion over a
## live [Control] tree. Injecting the query as a named-method [Callable] (never
## a lambda literal, matching this system's S-1 convention) lets
## [code]tests/unit/cursor/native_pointer_visibility_arbiter_test.gd[/code]
## substitute an arbitrary [Control] (or [code]null[/code]) without needing a
## real hover event. Flagged explicitly in this story's report as a
## self-judged deviation from the ADR's illustrative code shape, not a change
## to what the code actually decides.
class_name NativePointerVisibilityArbiter
extends Node

var _state: CursorState
var _registry: CursorSurfaceRegistry
var _hovered_control_provider: Callable

## QA/test-only diagnostic (機制十五 convention, same shape as
## [method MouseReclaimPolicy.diagnostic_seed_position]) — [b]downstream
## gameplay logic must not depend on this[/b]. Records this arbiter's OWN
## decision from the most recent [method _process] call, independent of
## whether the engine actually applied it to [member Input.mouse_mode].
##
## [b]Why this exists (2026-09-07 coordinator finding)[/b]: measured directly
## on this engine, headless (`--headless -s`), a throwaway probe: assigning
## [member Input.mouse_mode] to either [constant Input.MOUSE_MODE_HIDDEN] or
## [constant Input.MOUSE_MODE_VISIBLE] and reading it back BOTH report
## [code]0[/code] (the enum's [code]MOUSE_MODE_VISIBLE[/code] default) — the
## engine does not apply the write at all without a real window/display
## server. This makes a headless assertion of "[member Input.mouse_mode]
## should read HIDDEN" always fail (loud, at least) and one of "should read
## VISIBLE" always pass REGARDLESS of what this class actually decided (a
## silent false-green — the dangerous direction, since it is indistinguishable
## from a correct pass). [code]tests/unit/cursor/native_pointer_visibility_arbiter_test.gd[/code]
## asserts against THIS field headless; the real [member Input.mouse_mode]
## write is verified only in this story's windowed manual-verification
## evidence (`production/qa/evidence/`), where the engine can actually apply
## it. Both checks are required — this diagnostic proves the DECISION logic;
## the windowed check proves the engine applied it.
var diagnostic_last_desired_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _init(
	state: CursorState,
	registry: CursorSurfaceRegistry,
	hovered_control_provider: Callable
) -> void:
	_state = state
	_registry = registry
	_hovered_control_provider = hovered_control_provider
	# R6-12 convention: set before add_child(), matching CursorStateHost and
	# SelfDrawnReclaimCursor. Same value as SelfDrawnReclaimCursor's 50 — R6-9's
	# "same presentation-layer role, no ordering guarantee needed between
	# multiple instances of that role" explicitly covers this pair: this class
	# never reads anything SelfDrawnReclaimCursor writes (and vice versa), and
	# neither writes to CursorState, so no same-frame race exists between them.
	process_priority = 50


## S-2 (2026-08-19 第三次修訂): guard the assignment — only write
## [member Input.mouse_mode] when the desired value actually differs from the
## current one, rather than unconditionally every frame regardless of change.
func _process(_delta: float) -> void:
	var desired: Input.MouseMode = Input.MOUSE_MODE_HIDDEN
	if _state.get_device_authority() == CursorTypes.Authority.MOUSE:
		desired = Input.MOUSE_MODE_VISIBLE
	else:
		var hovered: Variant = _hovered_control_provider.call()
		if hovered != null and _registry.is_native_pointer_exception(hovered):
			desired = Input.MOUSE_MODE_VISIBLE  # AC-60 exception, explicitly registered

	diagnostic_last_desired_mouse_mode = desired

	if Input.mouse_mode != desired:
		Input.mouse_mode = desired
