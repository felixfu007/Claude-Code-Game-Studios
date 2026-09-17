## Battle menu screen (design/ux/battle-menu.md): M0 mask + M1 panel + M2 item
## rows, using Godot's NATIVE Control focus system — explicitly permitted by
## ADR-0005's AC-60 because this surface is deliberately NOT registered with
## [CursorStateHost] (see that GDD's "焦點視覺" section, transcribed into this
## story's Implementation Notes #4).
##
## [b]Story U-007 scope only[/b] — per that story's own "Out of Scope" section,
## this file does NOT (yet):
## - call [method CursorStateHost.suspend_arbitration] / [method resume_arbitration],
##   or set [member SceneTree.paused] (U-008's job — "選單開關閘控")
## - wire the "結束回合" row's real enable/disable judgement to
##   [code]BattleController.phase() / is_card_play_in_progress()[/code] (U-009 —
##   AC-M5), so that row is unconditionally enabled today
## - build M4 (leave-confirmation) itself (U-010) — only its SIZE arithmetic is
##   verified here (see [method leave_confirm_size]), because Implementation
##   Notes #2 requires that verification regardless of M4's build status
## - open/close itself in response to the [code]battle_menu[/code] action, or
##   get instantiated anywhere in [code]BattleScreen.tscn[/code] — this scene
##   is a standalone, not-yet-wired-in deliverable; U-008 is the first caller
##
## [b]Layout math is single-sourced[/b]: every size below is expressed as a
## multiple of [method HudLayout.font_size] anchored to [method HudLayout.safe_rect]
## — this class does NOT re-derive either formula (this project's registered
## failure pattern: "same formula reimplemented twice, agreeing only today").
## The multipliers themselves (10/9/2/14/7 fpx) are [b]battle-menu.md[/b]'s own
## Layout Zones table values, transcribed as named constants so the persistent
## regression test in [code]tests/unit/ui/menu/battle_menu_layout_test.gd[/code]
## can assert against the same table without hand-copying magic numbers twice.
##
## [b]M0 mask coverage is anchor-driven, not computed[/b]: [code]Mask[/code]'s
## anchors are FULL_RECT (0,0,1,1) with zero offsets, so it always covers this
## Control's own rect by construction — and this Control itself is expected to
## be placed FULL_RECT under whatever hosts it (a CanvasLayer at native 1:1
## window space, per `design/art/screen-architecture.md`'s "介面設計基準畫布 =
## 當下螢幕實際解析度" ruling). There is deliberately no "mask_rect()" static
## function to test against — the anchor system already guarantees the
## invariant; a duplicate helper nobody consults would just be decoration.
##
## [b]Internal panel padding / divider thickness are THIS FILE's own
## placeholder choices[/b], not numbers battle-menu.md wrote down — visual
## style (BM-7: 遮罩透明度、面板邊框、焦點標記形狀、分隔線) is explicitly
## unowned pending `art-director` + `/art-bible`. Only the OUTER M1 panel size
## (10x9 fpx) and each M2 row's height (2 fpx) are spec-mandated and therefore
## regression-tested; the margin/separation/divider-thickness constants below
## exist only so the three rows + divider fit inside that mandated outer size
## without overflowing, same category of judgement call this project's own
## [code]hud_layout.gd[/code] already documents for [code]controls_hint_bg_rect[/code]
## ("This is a deliberate call, flagged in the task report, not a number the
## spec wrote down").
##
## [b]Up/down "does not wrap" is a verified engine measurement, not an
## assumption[/b] — `design/ux/battle-menu.md` Implementation Notes #3
## explicitly warns "focus_mode 的實際行為本專案從未量測過". Confirmed against
## the real Godot 4.7.1 engine (headless) in
## `prototypes/u007-focus-navigation-probe-2026-09-17/` (see that directory's
## README for the three claims and why v1's structure had to be corrected in
## v2/v3): automatic geometric focus-neighbor search already does not wrap
## (Claim 1), and this file additionally wires an EXPLICIT self-pointing
## [member Control.focus_neighbor_top] / [member Control.focus_neighbor_bottom]
## on the two boundary rows (Claim 2) as a defensive, self-documenting
## guarantee that does not depend on the automatic search continuing to behave
## this way if the surrounding layout changes later (e.g. a footer node added
## below [code]QuitRow[/code] at some future point).
class_name BattleMenu
extends Control

## M1 panel width, in multiples of [method HudLayout.font_size] — battle-menu.md
## Layout Zones table: "M1 選單面板 | ... | 寬 10 fpx,高 9 fpx".
const PANEL_WIDTH_FPX_MULTIPLIER: float = 10.0
## M1 panel height, same table row.
const PANEL_HEIGHT_FPX_MULTIPLIER: float = 9.0
## M2 each row's height — battle-menu.md Layout Zones table: "M2 項目列 | ... | 每列高 2 fpx".
const ROW_HEIGHT_FPX_MULTIPLIER: float = 2.0
## M4 (leave-confirmation) width — SIZE ONLY, M4 itself is out of scope (U-010).
## Exists so Implementation Notes #2's table-verification obligation can call
## the SAME multiplier the eventual M4 implementation will use, rather than
## the test re-deriving it independently. battle-menu.md: "M4 離開確認 | ... | 寬 14 fpx,高 7 fpx".
const LEAVE_CONFIRM_WIDTH_FPX_MULTIPLIER: float = 14.0
## M4 height — SIZE ONLY, see above.
const LEAVE_CONFIRM_HEIGHT_FPX_MULTIPLIER: float = 7.0

## Placeholder internal spacing (this file's own judgement call, not a spec
## number — see class doc comment). Outer margin on all four sides of the
## panel's content area, in multiples of fpx.
const CONTENT_MARGIN_FPX_MULTIPLIER: float = 0.5
## Placeholder gap between consecutive rows/divider, in multiples of fpx.
const ROW_SEPARATION_FPX_MULTIPLIER: float = 0.25
## Placeholder divider thickness, in multiples of fpx.
const DIVIDER_HEIGHT_FPX_MULTIPLIER: float = 0.3

## Placeholder mask darkening — BM-7 (遮罩透明度) is explicitly unowned;
## this is a reasonable interim value, not a design-authored one.
const MASK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
## Placeholder panel background — same caveat as above.
const PANEL_BG_COLOR: Color = Color(0.10, 0.10, 0.12, 0.92)
## Placeholder divider color — same caveat as above.
const DIVIDER_COLOR: Color = Color(0.5, 0.5, 0.5, 0.8)

const HUD_FONT: FontFile = preload("res://assets/fonts/Cubic_11.ttf")

## Position-marker glyph shown before the focused row's label — the second,
## non-color channel `P-F3` requires ("須有位置標記(▸)或外框等第二通道"),
## on top of whatever native focus outline the engine's default Button theme
## already draws. Kept as a named constant so
## [code]test_focus_visual_has_position_marker_not_color_only[/code] can
## assert against this exact string rather than a hand-copied literal.
const FOCUS_MARKER: String = "▸ "
## Same-width blank filler shown when a row is NOT focused, so toggling the
## marker does not reflow the row's text horizontally by a visible amount.
const FOCUS_MARKER_BLANK: String = "  "

@onready var _mask: ColorRect = $Mask
@onready var _panel: PanelContainer = $Panel
@onready var _content_margin: MarginContainer = $Panel/ContentMargin
@onready var _rows: VBoxContainer = $Panel/ContentMargin/Rows
@onready var _return_row: Button = $Panel/ContentMargin/Rows/ReturnToBattleRow
@onready var _end_phase_row: Button = $Panel/ContentMargin/Rows/EndPhaseRow
@onready var _divider: ColorRect = $Panel/ContentMargin/Rows/Divider
@onready var _quit_row: Button = $Panel/ContentMargin/Rows/QuitRow

## Each focusable row's un-prefixed label text, captured once at [method _ready]
## so the focus-marker toggle (see [method _on_row_focus_entered] /
## [method _on_row_focus_exited]) always reconstructs from the original text
## instead of accumulating repeated prefixes.
var _row_base_text: Dictionary = {}


func _ready() -> void:
	_row_base_text = {
		_return_row: _return_row.text,
		_end_phase_row: _end_phase_row.text,
		_quit_row: _quit_row.text,
	}

	for row: Button in _row_base_text.keys():
		row.focus_mode = Control.FOCUS_ALL
		row.focus_entered.connect(_on_row_focus_entered.bind(row))
		row.focus_exited.connect(_on_row_focus_exited.bind(row))
		_apply_unfocused_text(row)

	_divider.focus_mode = Control.FOCUS_NONE

	# 🔴 Corrected during this story's own test-writing pass (not assumed up
	# front): ALL row-to-row transitions are wired EXPLICITLY here, not left to
	# Godot's automatic geometric focus-neighbor search — even the "normal"
	# (non-boundary) transitions this project initially expected to rely on
	# automatic search for. Reason, discovered empirically while writing
	# `tests/unit/ui/menu/battle_menu_layout_test.gd`'s down-navigation test:
	# immediately after this Control enters the tree (the same frame
	# [method _ready] runs), [VBoxContainer]'s child layout pass has NOT run
	# yet — every row's [method Control.get_rect] reads (0,0,0,0) until at
	# least one process frame has elapsed (measured directly: a throwaway
	# probe printed [P: (0,0), S: (0,0)] for all three rows immediately after
	# [method Node.add_child], and real, distinct positions only after 3
	# awaited [signal SceneTree.process_frame] cycles). Automatic geometric
	# search depends on real geometry, so a player who navigates before that
	# first layout pass completes could hit a genuine "down does nothing"
	# defect in production, not just a test-timing artifact — this is why the
	# fix is here, not just "await more frames in the test". Explicit
	# NodePath wiring has no such dependency: it is resolved once, by name,
	# regardless of whether any layout pass has run.
	#
	# battle-menu.md Implementation Notes #3's second decision ("到底停住")
	# only requires the top/bottom BOUNDARY behavior (AC-M13 tests the top
	# edge only); wiring the two INTERIOR transitions explicitly as well is
	# this file's own extension, made for the layout-timing reason above, not
	# a design-mandated requirement.
	_return_row.focus_neighbor_top = _return_row.get_path_to(_return_row)
	_return_row.focus_neighbor_bottom = _return_row.get_path_to(_end_phase_row)
	_end_phase_row.focus_neighbor_top = _end_phase_row.get_path_to(_return_row)
	_end_phase_row.focus_neighbor_bottom = _end_phase_row.get_path_to(_quit_row)
	_quit_row.focus_neighbor_top = _quit_row.get_path_to(_end_phase_row)
	_quit_row.focus_neighbor_bottom = _quit_row.get_path_to(_quit_row)

	_apply_layout()
	get_window().size_changed.connect(_apply_layout)

	# AC-M13's GIVEN precondition ("焦點在「回到遊戲」(第一列)") — default
	# focus per battle-menu.md Component Inventory: "「回到遊戲」列 | ... | ✅ 預設焦點".
	_return_row.grab_focus()


func _apply_layout() -> void:
	var window_size: Vector2i = get_window().size
	var fpx: float = float(HudLayout.font_size(window_size))

	_mask.color = MASK_COLOR

	var panel_r: Rect2 = panel_rect(window_size)
	_panel.offset_left = panel_r.position.x
	_panel.offset_top = panel_r.position.y
	_panel.offset_right = panel_r.end.x
	_panel.offset_bottom = panel_r.end.y
	_panel.add_theme_stylebox_override(&"panel", _panel_stylebox())

	var content_margin_px: int = int(fpx * CONTENT_MARGIN_FPX_MULTIPLIER)
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_content_margin.add_theme_constant_override(side, content_margin_px)

	_rows.add_theme_constant_override(&"separation", int(fpx * ROW_SEPARATION_FPX_MULTIPLIER))

	var row_h: float = row_height(window_size)
	for row: Button in _row_base_text.keys():
		row.custom_minimum_size = Vector2(0, row_h)
		row.add_theme_font_override(&"font", HUD_FONT)
		row.add_theme_font_size_override(&"font_size", int(fpx))

	_divider.color = DIVIDER_COLOR
	_divider.custom_minimum_size = Vector2(0, fpx * DIVIDER_HEIGHT_FPX_MULTIPLIER)


func _panel_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG_COLOR
	return style


func _apply_unfocused_text(row: Button) -> void:
	row.text = FOCUS_MARKER_BLANK + String(_row_base_text[row])


func _on_row_focus_entered(row: Button) -> void:
	row.text = FOCUS_MARKER + String(_row_base_text[row])


func _on_row_focus_exited(row: Button) -> void:
	_apply_unfocused_text(row)


## M1 panel rect in window-pixel space (top-left anchored, matching
## [HudLayout]'s established convention for four of its five nodes — see that
## class's own doc comment). Centered within [method HudLayout.safe_rect].
static func panel_rect(window_size: Vector2i) -> Rect2:
	var fpx: float = float(HudLayout.font_size(window_size))
	var safe: Rect2 = HudLayout.safe_rect(window_size)
	var size: Vector2 = Vector2(fpx * PANEL_WIDTH_FPX_MULTIPLIER, fpx * PANEL_HEIGHT_FPX_MULTIPLIER)
	var pos: Vector2 = safe.position + (safe.size - size) / 2.0
	return Rect2(pos, size)


## Each M2 row's height in window pixels.
static func row_height(window_size: Vector2i) -> float:
	return float(HudLayout.font_size(window_size)) * ROW_HEIGHT_FPX_MULTIPLIER


## M4 (leave-confirmation) SIZE ONLY — see class doc comment for why M4 itself
## is not built by this story.
static func leave_confirm_size(window_size: Vector2i) -> Vector2:
	var fpx: float = float(HudLayout.font_size(window_size))
	return Vector2(fpx * LEAVE_CONFIRM_WIDTH_FPX_MULTIPLIER, fpx * LEAVE_CONFIRM_HEIGHT_FPX_MULTIPLIER)
