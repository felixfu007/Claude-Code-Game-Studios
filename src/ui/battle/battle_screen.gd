## Wires the presentation layer ([BoardView]) to the interaction layer
## ([BattleController]) — the only class in the project that is allowed to
## know about both. Per [code].claude/rules/ui-code.md[/code] ("UI must
## NEVER own or directly modify game state"): [BoardView] never sees a
## [BattleState] reference and [BattleController] never sees a node, so this
## screen is the translator in both directions — player input becomes
## [method BattleController.click_tile] calls, and [BattleController]'s
## signals become [BoardView] render calls.
##
## Owns [BattleState], [TurnOrder], [BattleController], and [DeviceAuthority]
## directly; the two nodes it drives ([BoardView] inside the world
## [SubViewport], and a status/result [Label] pair in [code]UILayer[/code])
## are the entire node tree this script touches.
##
## [b]Input discipline (ADR-0005 forbidden patterns, binding per
## [code]docs/registry/architecture.yaml[/code] even while that ADR is
## [code]Proposed[/code]):[/b] every input decision happens in [method _input]
## — never [method Node._unhandled_input] — and [code]InputEvent.device[/code]
## is never read. Device authority ([DeviceAuthority]) is the single
## judgment point for "whose cursor is this", fed by [method
## DeviceAuthority.note_mouse_motion] / [method DeviceAuthority.note_pad_input]
## per event and resolved once per frame via [method
## DeviceAuthority.resolve_frame] in [method _process] — never decided inline
## inside an event handler, per that class's own two-stage contract.
##
## [b]Mouse coordinate handling — measured, not assumed (2026-08-27):[/b] a
## real windowed probe confirmed that [InputEventMouseMotion] / [
## InputEventMouseButton] positions arriving at [method _input] on a node
## under the root [SceneTree] are [b]already[/b] in 480x270 base-canvas
## space — Godot applies the [code]canvas_items[/code] stretch transform
## before delivery. Injecting a synthetic event with
## [code].position = Vector2(100, 50)[/code] into a 960x540 (scale=2) window
## arrived at [method _input] as [code](50, 25)[/code]. This screen therefore
## converts mouse positions with [method BoardCoords.local_to_grid] directly
## ([code]event.position - world_viewport_canvas_origin[/code]) — [b]never[/b]
## [method BoardCoords.window_to_grid] for events reaching [method _input],
## since that would re-apply the same transform a second time. At 1x
## (480x270 window) that bug is invisible; it only shows up once the window
## is scaled. [method BoardCoords.window_to_grid] is still the correct call
## for the opposite direction — computing a raw window-physical position to
## feed into a synthetic [code]Input.parse_input_event()[/code] call (see the
## evidence script), because whatever raw value is set there is what the
## engine transforms before this screen ever sees it.
class_name BattleScreen
extends Node

## Level terrain source, read once in [method _ready] via [method
## Board.from_ascii] (through [method BattleState.create]).
const TERRAIN_PATH: String = "res://assets/data/levels/vs01_terrain.txt"

## Roster source, read once in [method _ready] via [method Unit.roster_from_text]
## (through [method BattleState.create]).
const ROSTER_PATH: String = "res://assets/data/units/vs01_roster.txt"

## UI-facing display strings, centralized here as the single point a future
## localization pass has to touch. Per [code].claude/rules/ui-code.md[/code]
## ("all UI text must go through the localization system — no hardcoded
## user-facing strings") this project does not yet have one (task brief,
## 2026-08-27) — building one is explicitly out of scope for this change.
## Every read site below uses one of these constants instead of a literal;
## when a localization system exists, each constant becomes a
## [method tr] call and this is the only block that has to change.
const TEXT_STATUS_FORMAT: String = "第 %d 回合．%s"
const TEXT_FACTION_PLAYER: String = "我方行動"
const TEXT_FACTION_ENEMY: String = "敵方行動"
const TEXT_RESULT_VICTORY: String = "勝利"
const TEXT_RESULT_DEFEAT: String = "戰敗"
## Always-on control hint, drawn in the bottom margin strip below the board
## (board occupies y=[39,231) per [member BoardCoords.BOARD_ORIGIN] and its
## 192px height — this strip starts at y=231, so it can never overlap a
## board tile no matter what the text says). Deliberately one line covering
## all three input devices rather than a togglable full panel: a toggle
## would need its own input action bound on both keyboard and gamepad, and
## a 2026-08-27 [InputMap] probe against this exact project found no
## built-in action with both bindings that isn't already claimed by
## [code]battle_confirm[/code]/[code]battle_end_phase[/code] (the only
## keyboard+gamepad-bound candidate, [code]ui_select[/code], shares its
## Space keybinding with [code]battle_confirm[/code] — reusing it would fire
## both actions on the same keypress). Width measured against
## [code]ThemeDB.fallback_font[/code] at size 16 (452px, see task report) —
## fits inside the ~464px usable width of the 480px-wide strip with margin.
const TEXT_CONTROLS_HINT: String = "移動 方向鍵/十字鍵/滑鼠　確認 Enter/A/左鍵　結束回合 Esc/B"

## Keyboard/gamepad directional actions this screen listens for, mapped to the
## grid delta they apply to the pad-tracked cursor cell. All four are Godot's
## built-in [code]ui_*[/code] actions — verified (2026-08-27, headless
## [InputMap] query against this exact project) to already carry both
## keyboard (arrow keys) and gamepad (D-pad + left-stick axis) bindings by
## default, so no [code]project.godot[/code] change was needed for movement.
const _DIRECTION_VECTORS: Dictionary = {
	&"ui_up": Vector2i.UP,
	&"ui_down": Vector2i.DOWN,
	&"ui_left": Vector2i.LEFT,
	&"ui_right": Vector2i.RIGHT,
}

@onready var _world_viewport_container: SubViewportContainer = $WorldViewportContainer
@onready var _board_view: BoardView = $WorldViewportContainer/WorldViewport/BoardView
@onready var _status_label: Label = $UILayer/StatusLabel
@onready var _result_label: Label = $UILayer/ResultLabel
@onready var _controls_hint_label: Label = $UILayer/ControlsHintBg/ControlsHintLabel

var _state: BattleState
var _order: TurnOrder
var _controller: BattleController
var _device: DeviceAuthority

## Pad-authority cursor cell — moved one tile per directional press, clamped
## to the board. Also doubles as the last-known cell under mouse authority
## (kept in sync by [method _update_cursor_visual]) so a device switch never
## has to guess a starting cell.
var _cursor_cell: Vector2i = Vector2i.ZERO

## Last mouse position seen in [method _input], in base-canvas (480x270)
## space — see the class doc comment on why this is NOT raw window pixels.
## Starts off-canvas so the cursor stays hidden under mouse authority until a
## real mouse-motion event has actually arrived.
var _last_mouse_canvas_pos: Vector2 = Vector2(-1000.0, -1000.0)

## Edge-detection state for [member _DIRECTION_VECTORS], keyed by action name.
## Needed because [method InputEvent.is_action_pressed] on a raw event does
## not by itself debounce a held gamepad stick — [InputEventJoypadMotion] is
## re-delivered every frame while the axis stays past the deadzone, and
## without this the cursor would race across the board instead of moving one
## tile per press. Tracked manually via [method Input.is_action_pressed]
## polling rather than [method Input.is_action_just_pressed] so the edge
## logic is self-contained and easy to verify by reading this file alone.
var _direction_was_pressed: Dictionary = {}


func _ready() -> void:
	_controls_hint_label.text = TEXT_CONTROLS_HINT

	var terrain_rows: PackedStringArray = _read_terrain_rows(TERRAIN_PATH)
	var roster_text: String = FileAccess.get_file_as_string(ROSTER_PATH)
	_state = BattleState.create(terrain_rows, roster_text)

	var player_ids: Array[int] = []
	var enemy_ids: Array[int] = []
	for unit: Unit in _state.units_of(Unit.Faction.PLAYER):
		player_ids.append(unit.id)
	for unit: Unit in _state.units_of(Unit.Faction.ENEMY):
		enemy_ids.append(unit.id)
	_order = TurnOrder.new(player_ids, enemy_ids)
	_controller = BattleController.new(_state, _order)
	_device = DeviceAuthority.new()

	_controller.unit_selected.connect(func(_id: int) -> void: _refresh_view())
	_controller.selection_cleared.connect(func() -> void: _refresh_view())
	_controller.unit_moved.connect(func(_id: int, _from: Vector2i, _to: Vector2i) -> void: _refresh_view())
	_controller.attack_resolved.connect(
		func(_attacker_id: int, _target_id: int, _damage: int, _target_died: bool) -> void:
			_refresh_view()
	)
	_controller.phase_changed.connect(func(_new_phase: BattleController.Phase) -> void: _update_status_label())
	_controller.battle_ended.connect(_on_battle_ended)

	_board_view.render_terrain(terrain_rows)
	if not player_ids.is_empty():
		_cursor_cell = _state.position_of(player_ids[0])
	_refresh_view()


func _process(_delta: float) -> void:
	_device.resolve_frame()
	_update_cursor_visual()


func _input(event: InputEvent) -> void:
	if _controller.phase() == BattleController.Phase.FINISHED:
		return

	if event is InputEventMouseMotion:
		_last_mouse_canvas_pos = (event as InputEventMouseMotion).position
		_device.note_mouse_motion()
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		return

	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_handle_directional(event)
		if event.is_action_pressed(&"battle_confirm"):
			_device.note_pad_input()
			_confirm_at_cursor()
			return
		if event.is_action_pressed(&"battle_end_phase"):
			_device.note_pad_input()
			_end_faction_phase_pressed()
			return


## Pure, node-independent helper: clamps [param cell] moved by [param delta]
## to stay inside the board. Extracted as a [code]static[/code] function per
## the task brief ("若能把任何一段邏輯抽成不依賴節點的純函式,請抽出來並補測試")
## so directional-cursor clamping is testable headless without a live window
## or [InputEvent] — see [code]tests/unit/ui/battle_screen_cursor_test.gd[/code].
static func clamp_cursor_move(cell: Vector2i, delta: Vector2i) -> Vector2i:
	var moved: Vector2i = cell + delta
	return Vector2i(
		clampi(moved.x, 0, BoardCoords.BOARD_COLS - 1),
		clampi(moved.y, 0, BoardCoords.BOARD_ROWS - 1)
	)


# Reads a terrain data file into the PackedStringArray Board.from_ascii()
# (via BattleState.create()) expects: one row per line, blank lines dropped.
# Strips \r defensively in case the file is ever saved with CRLF endings.
static func _read_terrain_rows(path: String) -> PackedStringArray:
	var text: String = FileAccess.get_file_as_string(path)
	var rows: PackedStringArray = PackedStringArray()
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.replace("\r", "")
		if line.is_empty():
			continue
		rows.append(line)
	return rows


# Left-click handling: computes the clicked cell directly from the event's
# own (already canvas-space, per the class doc comment) position rather than
# waiting for the next _process() cursor refresh, so the click always resolves
# against the exact tile the player saw the cursor on when they clicked.
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	_last_mouse_canvas_pos = event.position
	_device.note_mouse_motion()
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var local_pos: Vector2 = event.position - _world_viewport_container.global_position
	var cell: Vector2i = BoardCoords.local_to_grid(local_pos)
	if not BoardCoords.is_in_bounds(cell):
		return
	_cursor_cell = cell
	_board_view.set_cursor(cell)
	_controller.click_tile(cell)


# Edge-triggered directional cursor movement — see _direction_was_pressed's
# doc comment for why this cannot just be event.is_action_pressed().
func _handle_directional(_event: InputEvent) -> void:
	for action: StringName in _DIRECTION_VECTORS:
		var pressed_now: bool = Input.is_action_pressed(action)
		var was_pressed: bool = _direction_was_pressed.get(action, false)
		_direction_was_pressed[action] = pressed_now
		if pressed_now and not was_pressed:
			_device.note_pad_input()
			_cursor_cell = clamp_cursor_move(_cursor_cell, _DIRECTION_VECTORS[action])
			_board_view.set_cursor(_cursor_cell)


# Confirm action bound to the project-level "battle_confirm" input action
# (project.godot [input]: keyboard Enter/KP-Enter/Space, gamepad Bottom
# Action button — Xbox A / Sony Cross / Switch B). Added 2026-08-27 because
# no built-in ui_* action alone covers both devices for a confirm/select
# semantic: ui_accept has no default gamepad binding, and ui_select's only
# gamepad binding is the Top Action button (Y/Triangle/X), an unusual choice
# for "confirm" — see the class doc comment / task report for the full
# measured InputMap gap this closed.
func _confirm_at_cursor() -> void:
	if not BoardCoords.is_in_bounds(_cursor_cell):
		return
	_controller.click_tile(_cursor_cell)


# "End my faction phase", bound to the project-level "battle_end_phase"
# input action (project.godot [input]: keyboard Escape, gamepad Right Action
# button — Xbox B / Sony Circle / Switch A). Added 2026-08-27 alongside
# battle_confirm: the built-in ui_cancel this used to be bound to has no
# default gamepad binding, which would otherwise leave a gamepad-only player
# unable to ever hand the turn to the enemy. Synchronous by design: both
# BattleController calls below return only after their work is fully done,
# so there is no async/deferred window for FINISHED or a mid-phase state to
# leak into an _input() call — matches the "no call_deferred() in the
# settlement path" forbidden pattern.
func _end_faction_phase_pressed() -> void:
	if _controller.phase() != BattleController.Phase.PLAYER_INPUT:
		return
	_controller.end_faction_phase()
	_controller.run_enemy_phase()
	_refresh_view()


# Repositions/toggles the self-drawn cursor sprite based on current device
# authority — never native Control hover/focus, per the class doc comment.
func _update_cursor_visual() -> void:
	if _device.current() == DeviceAuthority.Device.MOUSE:
		var local_pos: Vector2 = _last_mouse_canvas_pos - _world_viewport_container.global_position
		var cell: Vector2i = BoardCoords.local_to_grid(local_pos)
		if BoardCoords.is_in_bounds(cell):
			_cursor_cell = cell
			_board_view.set_cursor(cell)
		else:
			_board_view.clear_cursor()
	else:
		_board_view.set_cursor(_cursor_cell)


# Full redraw from BattleState — pieces, then highlights for whatever is
# currently selected (both empty when nothing is selected). Simpler and
# safer than incremental patching for a 13x6 board with 10 units: every
# signal BattleController emits (select/deselect/move/attack) triggers this,
# so there is exactly one code path that can ever go stale.
func _refresh_view() -> void:
	var pieces: Array[Dictionary] = []
	for unit: Unit in _state.units_of(Unit.Faction.PLAYER):
		pieces.append({
			"cell": _state.position_of(unit.id),
			"faction": "PLAYER",
			# Roster ids 1-5 are exactly the five player units in order, so
			# id-1 lines up with ALLY_SPRITE_PATHS' 0-4 index. Clamped
			# defensively in case the roster data ever changes shape.
			"sprite_index": clampi(unit.id - 1, 0, 4),
			"hp": unit.hp,
			"hp_max": unit.hp_max,
		})
	for unit: Unit in _state.units_of(Unit.Faction.ENEMY):
		pieces.append({
			"cell": _state.position_of(unit.id),
			"faction": "ENEMY",
			"sprite_index": 0,
			"hp": unit.hp,
			"hp_max": unit.hp_max,
		})
	_board_view.render_pieces(pieces)

	var selected: int = _controller.selected_unit()
	if selected != -1:
		_board_view.set_move_highlights(_controller.move_targets())
		_board_view.set_attack_highlights(_controller.attack_targets())
	else:
		_board_view.set_move_highlights([])
		_board_view.set_attack_highlights([])

	_update_status_label()


func _update_status_label() -> void:
	var faction_text: String = TEXT_FACTION_PLAYER if _order.current_faction() == TurnOrder.Side.PLAYER else TEXT_FACTION_ENEMY
	_status_label.text = TEXT_STATUS_FORMAT % [_order.round_number(), faction_text]


func _on_battle_ended(outcome: BattleState.Outcome) -> void:
	_result_label.visible = true
	_result_label.text = TEXT_RESULT_VICTORY if outcome == BattleState.Outcome.VICTORY else TEXT_RESULT_DEFEAT
