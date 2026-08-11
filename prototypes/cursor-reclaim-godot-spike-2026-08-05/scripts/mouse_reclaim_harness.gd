extends Control
## Root controller for Test 2 — mouse-reclaim mixed-input instrumentation harness.
##
## Implements the GDD's CURRENT (2026-08-05, round 10) simplified reset-
## trigger model for `accumulated_net_displacement_px` / `reclaim_progress`,
## exactly as written in design/gdd/cursor-highlight-state.md, Core Rules #3
## "累積起點的重置時機" — FOUR triggers only (the old five-trigger model,
## including the removed hit-box-enter/exit trigger, is intentionally NOT
## implemented here):
##   (a) device authority transfer, any direction
##   (b) the currently highlighted target changes
##   (c) window loses/regains OS-level focus — the accumulator is completely
##       frozen (not computed at all) while unfocused, and reseeded to 0 at
##       the exact moment focus returns
##   (d) same-frame keyboard/gamepad veto — mouse crosses the threshold this
##       frame, but a keyboard/gamepad ui_* action ALSO arrived this frame;
##       fixed priority means keyboard/gamepad wins and the accumulator resets
##
## This is instrumentation only — it does NOT implement the full cursor/
## highlight-state system (no board grid, no downstream consumers, no
## per-surface-type threshold table). It exists to let a human tester answer,
## with REAL mixed mouse+gamepad hardware, the two open questions this
## harness was built for:
##   (a) does holding a gamepad direction produce a qualifying navigation
##       ui_* action on literally every processing frame? (residual risk
##       flagged in the GDD's Open Questions — if true, trigger (d) could
##       cause an indefinite mouse-reclaim lockout while a direction is held)
##   (b) rough felt-sense calibration data for reclaim_threshold_px
##
## Architecture note: per the GDD's Edge Cases "實作架構約束" (and Open
## Questions' "Agile Event Flushing" entry), this script buffers qualifying
## keyboard/gamepad ui_* events in [method _input] and resolves device
## authority once per [method _process] frame — it deliberately does NOT use
## [method _unhandled_input]. This project's project.godot does not enable
## "Input Devices → Buffering → Agile Event Flushing" (left at the engine
## default); if a human tester has changed that project setting, the
## same-frame buffering this harness relies on may no longer hold.
##
## See prototypes/cursor-reclaim-godot-spike-2026-08-05/README.md, "Test 2",
## for the exact procedure and what each open question's answer looks like.
##
## --- Round 2 addendum (2026-08-11) ---
## design/gdd/cursor-highlight-state.md "Known Confirmed Defects" now records
## the round-10 same-day fix (veto eligibility narrowed to "just pressed"
## frames only) as WITHDRAWN by round-11 adversarial review — the defect
## (holding a direction can permanently lock out mouse reclaim) remains
## 100% reproducible with NO interim containment. Before writing any fix back
## into the GDD rule body, the GDD's "候選方向(未定案)" note requires the
## candidate direction (filtering same-frame veto eligibility by
## `InputEventKey.echo` / the buffered event's "new press" status, via
## [method InputEvent.is_action_pressed] with `allow_echo=false`) to be
## tested against all three input sources (D-pad, analog stick, keyboard)
## with real hardware BEFORE it is trusted — the GDD explicitly warns not to
## assume the three sources behave consistently.
##
## This harness now supports switching between two veto-eligibility modes
## LIVE, without reopening the scene, so a tester can A/B compare directly:
##   - **Mode 1 (CURRENT_BEHAVIOR)** — the control group. Reproduces exactly
##     what shipped in the round-10 redesign that is currently live in the
##     GDD rule body: ANY qualifying keyboard/gamepad ui_* event this frame
##     (echo or not) vetoes a same-frame mouse reclaim.
##   - **Mode 2 (ECHO_FILTERED_CANDIDATE)** — the untested candidate fix
##     direction from the GDD's Known Confirmed Defects table: only events
##     where `is_action_pressed(action, false)` is true (i.e. NOT an
##     echo/repeat, per Godot's own echo bookkeeping) count toward veto
##     eligibility. Note this is a NO-OP for InputEventJoypadButton /
##     InputEventJoypadMotion, since Godot's echo flag only exists on
##     InputEventKey — whether that means Mode 2 changes gamepad behavior at
##     all is exactly what procedures B4/B5 in the README exist to answer,
##     not something this harness (or this comment) should presume.
##
## The "Held state / event rate" overlay line also now breaks down
## events/last1s PER InputEvent subclass (InputEventKey / InputEventJoypadButton
## / InputEventJoypadMotion) instead of only a combined total, so a tester can
## see on-screen whether the three input sources actually dispatch qualifying
## events at different rates while held, without having to hand-count log lines.

## Mirrors design/gdd/cursor-highlight-state.md "States and Transitions".
enum DeviceAuthority { UNINITIALIZED, MOUSE, KEYBOARD_GAMEPAD }

## Round 2 addendum (2026-08-11) — see file header. Mirrors the two
## same-frame-veto-eligibility rules being A/B compared; CURRENT_BEHAVIOR is
## what design/gdd/cursor-highlight-state.md's rule body currently specifies,
## ECHO_FILTERED_CANDIDATE is the untested candidate fix from that GDD's
## Known Confirmed Defects table.
enum VetoFilterMode { CURRENT_BEHAVIOR, ECHO_FILTERED_CANDIDATE }

const NAV_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]
const CONFIRM_ACTIONS: Array[StringName] = [&"ui_accept", &"ui_cancel"]
const MAX_LOG_LINES := 300
const TARGET_COUNT := 5
const PROGRESS_BAR_MAX_WIDTH := 400.0

## Stand-in for the GDD's per-surface-type table
## (`mouse_reclaim_threshold_px_by_surface_type`) — this harness has exactly
## one synthetic "surface", so a single live-editable knob is enough for
## felt-sense calibration testing.
@export var reclaim_threshold_px: float = 80.0

var device_authority: DeviceAuthority = DeviceAuthority.UNINITIALIZED
## Round 2 addendum (2026-08-11) — live-switchable, see file header. Defaults
## to CURRENT_BEHAVIOR (the control group / what the GDD rule body currently
## says) so the default first impression of the harness is unchanged from
## round 1.
var veto_filter_mode: VetoFilterMode = VetoFilterMode.CURRENT_BEHAVIOR
var accumulated_net_displacement_px: float = 0.0
var reclaim_progress: float = 0.0
var reclaim_origin_px: Vector2 = Vector2.ZERO
var has_os_focus: bool = true
var current_target_index: int = 0

var _last_mouse_pos: Vector2 = Vector2.ZERO
## Buffered per-frame keyboard/gamepad ui_* events. Each entry:
## {"action": StringName, "is_nav": bool, "class": String, "device": int,
##  "is_echo": bool, "pressed_no_echo": bool}
## Intentionally loosely typed (Array[Dictionary]) — this is throwaway
## instrumentation, not a data model other systems depend on.
var _frame_kbgp_events: Array[Dictionary] = []
## action (StringName) -> Array[int] of Time.get_ticks_msec() values for
## qualifying events received in roughly the last 1000ms, used to display a
## live combined (all-classes) event-rate reading per action (see Open
## Question (a)).
var _recent_action_ticks: Dictionary = {}
## Round 2 addendum (2026-08-11). Key is "%s|%s" % [action, event.get_class()]
## (e.g. "ui_right|InputEventJoypadMotion") -> Array[int] of
## Time.get_ticks_msec() values in roughly the last 1000ms. Same rolling-
## window bookkeeping as _recent_action_ticks, but split per InputEvent
## subclass so the overlay can show D-pad / analog stick / keyboard rates
## separately instead of only a combined total — see file header.
var _recent_action_ticks_by_class: Dictionary = {}

var _log_lines: Array[String] = []
var _log_label: RichTextLabel
var _authority_label: Label
var _focus_label: Label
var _accum_label: Label
var _progress_label: Label
var _progress_bar_fill: ColorRect
var _held_state_label: Label
## Round 2 addendum (2026-08-11) — displays the currently active
## VetoFilterMode in plain language, kept in sync by
## _on_veto_filter_mode_selected(). Separate from the OptionButton itself so
## screenshots/recordings of the overlay unambiguously show which mode was
## active during a given test procedure, without needing to also capture the
## dropdown widget's own rendering.
var _veto_filter_mode_label: Label
var _target_boxes: Array[ColorRect] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_last_mouse_pos = get_viewport().get_mouse_position()
	_build_ui()
	set_process(true)
	_log("Harness ready. device_authority=UNINITIALIZED. Move the mouse, or press a keyboard/gamepad ui_* action, to begin.")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			has_os_focus = false
			_log("[FOCUS] Application FOCUS_OUT — accumulator computation frozen (GDD 'this field's live-compute range').")
		NOTIFICATION_APPLICATION_FOCUS_IN:
			has_os_focus = true
			_reset_accumulator("(c) refocus reseed")
			_log("[FOCUS] Application FOCUS_IN — accumulator reseeded to 0 at current mouse position.")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		# Mouse device-authority logic is resolved every _process frame by
		# polling get_viewport().get_mouse_position() directly (see
		# _process below) — per the GDD's front-matter precondition, no
		# ui_* action should be bound to mouse buttons/motion, so there is
		# no InputMap action for a mouse event to qualify for here.
		return

	var is_kbgp_event := event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion
	if not is_kbgp_event:
		return

	for action in NAV_ACTIONS:
		_check_action(event, action, true)
	for action in CONFIRM_ACTIONS:
		_check_action(event, action, false)


func _check_action(event: InputEvent, action: StringName, is_nav: bool) -> void:
	# allow_echo=true so any OS keyboard-repeat / engine-level repeat is
	# captured too — the whole point of this harness is to reveal whether
	# such repeats exist for gamepad input and how often they fire (GDD
	# Open Question: "does holding a gamepad direction produce a qualifying
	# ui_* action on literally every processing frame?").
	var pressed_with_echo := event.is_action_pressed(action, true)
	if not pressed_with_echo:
		return

	var pressed_no_echo := event.is_action_pressed(action, false)
	var is_echo := event is InputEventKey and (event as InputEventKey).echo

	_frame_kbgp_events.append({
		"action": action,
		"is_nav": is_nav,
		"class": event.get_class(),
		"device": event.device,
		"is_echo": is_echo,
		"pressed_no_echo": pressed_no_echo,
	})
	_record_action_tick(action, event.get_class())

	_log("[%dms][frame %d] %s action=%s is_nav=%s device=%d is_echo=%s is_action_pressed(no-echo)=%s is_action_pressed(allow-echo)=%s" % [
		Time.get_ticks_msec(), Engine.get_process_frames(), event.get_class(), action, is_nav,
		event.device, is_echo, pressed_no_echo, pressed_with_echo,
	])


## Round 2 addendum (2026-08-11) — now takes event_class so ticks can be
## bucketed both by action (combined, unchanged from round 1) and by
## action+InputEvent-subclass (new, see _recent_action_ticks_by_class).
func _record_action_tick(action: StringName, event_class: String) -> void:
	var now := Time.get_ticks_msec()

	if not _recent_action_ticks.has(action):
		_recent_action_ticks[action] = []
	var ticks: Array = _recent_action_ticks[action]
	ticks.append(now)
	while ticks.size() > 0 and now - ticks[0] > 1000:
		ticks.pop_front()

	var class_key := "%s|%s" % [action, event_class]
	if not _recent_action_ticks_by_class.has(class_key):
		_recent_action_ticks_by_class[class_key] = []
	var class_ticks: Array = _recent_action_ticks_by_class[class_key]
	class_ticks.append(now)
	while class_ticks.size() > 0 and now - class_ticks[0] > 1000:
		class_ticks.pop_front()


## Round 2 addendum (2026-08-11). Returns the events/last1s count for one
## action+class combination, used by _update_overlay's per-class breakdown.
func _class_tick_count(action: StringName, event_class: String) -> int:
	var class_key := "%s|%s" % [action, event_class]
	var class_ticks: Array = _recent_action_ticks_by_class.get(class_key, [])
	return class_ticks.size()


func _process(_delta: float) -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var had_nav_this_frame := false
	var had_any_kbgp_action_this_frame := _frame_kbgp_events.size() > 0
	for ev in _frame_kbgp_events:
		if ev["is_nav"]:
			had_nav_this_frame = true

	match device_authority:
		DeviceAuthority.UNINITIALIZED:
			if had_any_kbgp_action_this_frame:
				_set_authority(DeviceAuthority.KEYBOARD_GAMEPAD, "uninitialized -> first keyboard/gamepad ui_* action")
			elif mouse_pos != _last_mouse_pos:
				_set_authority(DeviceAuthority.MOUSE, "uninitialized -> first mouse motion")

		DeviceAuthority.MOUSE:
			if had_nav_this_frame:
				_set_authority(DeviceAuthority.KEYBOARD_GAMEPAD, "mouse -> keyboard/gamepad (nav action, zero threshold, GDD reverse-direction exemption)")
			# Confirm-class kbgp actions while mouse holds authority: logged
			# already via _check_action, but per the GDD do NOT transfer
			# authority ("確認類動作與裝置權威的關係") — no further action here.

		DeviceAuthority.KEYBOARD_GAMEPAD:
			if has_os_focus:
				accumulated_net_displacement_px = reclaim_origin_px.distance_to(mouse_pos)
				reclaim_progress = clampf(accumulated_net_displacement_px / reclaim_threshold_px, 0.0, 1.0)
			# else: frozen — accumulated_net_displacement_px / reclaim_progress
			# are left untouched, matching the GDD's "此欄位的即時運算範圍".

			if had_nav_this_frame:
				_move_target(_nav_direction_from_frame_events())

			if has_os_focus and accumulated_net_displacement_px >= reclaim_threshold_px:
				if _frame_has_veto_qualifying_event():
					_reset_accumulator("(d) same-frame keyboard/gamepad veto")
					_log("VETOED [%s]: mouse reached reclaim_threshold_px this frame but a keyboard/gamepad ui_* action also qualified for veto this frame — fixed priority keeps authority." % _veto_filter_mode_name())
				else:
					_set_authority(DeviceAuthority.MOUSE, "keyboard/gamepad -> mouse (reclaim threshold met, no same-frame veto [%s])" % _veto_filter_mode_name())

	_last_mouse_pos = mouse_pos
	_frame_kbgp_events.clear()
	_update_overlay()


## Round 2 addendum (2026-08-11) — the A/B-compared decision point. See file
## header and design/gdd/cursor-highlight-state.md "Known Confirmed Defects"
## for what each mode reproduces.
func _frame_has_veto_qualifying_event() -> bool:
	match veto_filter_mode:
		VetoFilterMode.CURRENT_BEHAVIOR:
			# Mode 1 / control group: any qualifying keyboard/gamepad ui_*
			# event this frame vetoes, echo or not — exactly what
			# design/gdd/cursor-highlight-state.md's rule body currently
			# specifies (Core Rules #3 trigger (d)).
			return _frame_kbgp_events.size() > 0
		VetoFilterMode.ECHO_FILTERED_CANDIDATE:
			# Mode 2 / candidate fix under test: only events where Godot's
			# own is_action_pressed(action, allow_echo=false) says "yes" —
			# i.e. NOT an echo/repeat — count toward veto eligibility. For
			# InputEventKey this filters out OS-level key-repeat. For
			# InputEventJoypadButton / InputEventJoypadMotion there is no
			# echo flag in Godot, so pressed_no_echo is expected to equal
			# pressed_with_echo for those classes — whether that means this
			# mode changes gamepad/analog-stick lockout behavior at all is
			# exactly what README procedures B4/B5 exist to answer, not
			# something to assume here.
			for ev in _frame_kbgp_events:
				if ev["pressed_no_echo"]:
					return true
			return false
	return false


## Round 2 addendum (2026-08-11).
func _veto_filter_mode_name() -> String:
	match veto_filter_mode:
		VetoFilterMode.CURRENT_BEHAVIOR:
			return "Mode 1: current behavior"
		VetoFilterMode.ECHO_FILTERED_CANDIDATE:
			return "Mode 2: echo-filtered candidate fix"
	return "Mode ?: unknown"


## Round 2 addendum (2026-08-11). Longer-form text for the overlay label.
func _veto_filter_mode_description() -> String:
	match veto_filter_mode:
		VetoFilterMode.CURRENT_BEHAVIOR:
			return "Veto filter mode: Mode 1 — CURRENT_BEHAVIOR (control group; any qualifying event vetoes, echo or not)"
		VetoFilterMode.ECHO_FILTERED_CANDIDATE:
			return "Veto filter mode: Mode 2 — ECHO_FILTERED_CANDIDATE (only non-echo/new-press events veto; no-op for D-pad/stick, which have no echo flag)"
	return "Veto filter mode: unknown"


func _nav_direction_from_frame_events() -> int:
	for ev in _frame_kbgp_events:
		if ev["is_nav"]:
			match ev["action"]:
				&"ui_left":
					return -1
				&"ui_right":
					return 1
	return 0


func _move_target(direction: int) -> void:
	if direction == 0:
		return
	var new_index: int = clampi(current_target_index + direction, 0, TARGET_COUNT - 1)
	if new_index != current_target_index:
		current_target_index = new_index
		_reset_accumulator("(b) highlighted target changed (keyboard/gamepad navigation)")
		_refresh_target_highlight()


func _on_target_hovered(index: int) -> void:
	if device_authority != DeviceAuthority.MOUSE:
		return
	if index != current_target_index:
		current_target_index = index
		_reset_accumulator("(b) highlighted target changed (mouse hover)")
		_refresh_target_highlight()


func _set_authority(new_authority: DeviceAuthority, reason: String) -> void:
	var old_authority := device_authority
	device_authority = new_authority
	_reset_accumulator("(a) device authority transfer: %s" % reason)
	_log("AUTHORITY CHANGE: %s -> %s (%s)" % [DeviceAuthority.keys()[old_authority], DeviceAuthority.keys()[new_authority], reason])


func _reset_accumulator(reason: String) -> void:
	accumulated_net_displacement_px = 0.0
	reclaim_progress = 0.0
	reclaim_origin_px = get_viewport().get_mouse_position()
	_log("ACCUMULATOR RESET (%s) — new origin=%s" % [reason, reclaim_origin_px])


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.08, 0.09, 0.11)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 10)
	add_child(root_vbox)

	var instructions := Label.new()
	instructions.text = (
		"Test 2: mouse-reclaim mixed-input harness. Nav = ui_up/down/left/right, " +
		"Confirm = ui_accept/ui_cancel. See README.md 'Test 2' for the full procedure " +
		"(authority handoff sanity check, held-direction lockout risk, focus-loss reseed, calibration)."
	)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.custom_minimum_size = Vector2(0.0, 50.0)
	root_vbox.add_child(instructions)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 24)
	root_vbox.add_child(status_row)

	_authority_label = Label.new()
	status_row.add_child(_authority_label)
	_focus_label = Label.new()
	status_row.add_child(_focus_label)
	_accum_label = Label.new()
	status_row.add_child(_accum_label)
	_progress_label = Label.new()
	status_row.add_child(_progress_label)

	_held_state_label = Label.new()
	_held_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_held_state_label.custom_minimum_size = Vector2(0.0, 20.0)
	root_vbox.add_child(_held_state_label)

	var progress_bg := ColorRect.new()
	progress_bg.color = Color(0.2, 0.2, 0.22)
	progress_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bg.custom_minimum_size = Vector2(PROGRESS_BAR_MAX_WIDTH, 20.0)
	progress_bg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root_vbox.add_child(progress_bg)
	_progress_bar_fill = ColorRect.new()
	_progress_bar_fill.color = Color(0.3, 0.8, 0.3)
	_progress_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar_fill.position = Vector2.ZERO
	_progress_bar_fill.size = Vector2(0.0, 20.0)
	progress_bg.add_child(_progress_bar_fill)

	var calibration_row := HBoxContainer.new()
	calibration_row.add_theme_constant_override("separation", 8)
	root_vbox.add_child(calibration_row)
	var calibration_label := Label.new()
	calibration_label.text = "reclaim_threshold_px (live-editable, for felt-sense calibration):"
	calibration_row.add_child(calibration_label)
	var threshold_spinbox := SpinBox.new()
	threshold_spinbox.min_value = 1.0
	threshold_spinbox.max_value = 2000.0
	threshold_spinbox.step = 1.0
	threshold_spinbox.value = reclaim_threshold_px
	threshold_spinbox.value_changed.connect(_on_threshold_changed)
	calibration_row.add_child(threshold_spinbox)

	var reset_button := Button.new()
	reset_button.text = "Force reset to UNINITIALIZED"
	reset_button.pressed.connect(_on_force_reset_pressed)
	calibration_row.add_child(reset_button)

	# Round 2 addendum (2026-08-11) — Mode 1 / Mode 2 live toggle. See file
	# header and README "第二輪補測" section for what each mode is and the
	# procedures that use this switch.
	var veto_mode_row := HBoxContainer.new()
	veto_mode_row.add_theme_constant_override("separation", 8)
	root_vbox.add_child(veto_mode_row)
	var veto_mode_caption := Label.new()
	veto_mode_caption.text = "Same-frame veto eligibility (switch live, no scene reload needed):"
	veto_mode_row.add_child(veto_mode_caption)
	var veto_mode_option := OptionButton.new()
	veto_mode_option.add_item("Mode 1: current behavior (control group)", VetoFilterMode.CURRENT_BEHAVIOR)
	veto_mode_option.add_item("Mode 2: echo-filtered candidate fix", VetoFilterMode.ECHO_FILTERED_CANDIDATE)
	veto_mode_option.selected = VetoFilterMode.CURRENT_BEHAVIOR
	veto_mode_option.item_selected.connect(_on_veto_filter_mode_selected)
	veto_mode_row.add_child(veto_mode_option)

	_veto_filter_mode_label = Label.new()
	_veto_filter_mode_label.text = _veto_filter_mode_description()
	root_vbox.add_child(_veto_filter_mode_label)

	var target_row := HBoxContainer.new()
	target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	target_row.add_theme_constant_override("separation", 16)
	target_row.custom_minimum_size = Vector2(0.0, 100.0)
	root_vbox.add_child(target_row)

	for i in range(TARGET_COUNT):
		var box := ColorRect.new()
		box.custom_minimum_size = Vector2(80.0, 80.0)
		box.color = Color(0.3, 0.3, 0.34)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		var index := i
		box.mouse_entered.connect(func() -> void: _on_target_hovered(index))
		target_row.add_child(box)
		_target_boxes.append(box)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = false
	_log_label.scroll_following = true
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.custom_minimum_size = Vector2(0.0, 280.0)
	root_vbox.add_child(_log_label)

	_refresh_target_highlight()
	_update_overlay()


func _on_threshold_changed(value: float) -> void:
	reclaim_threshold_px = value
	_log("reclaim_threshold_px recalibrated to %.1f px" % value)


func _on_force_reset_pressed() -> void:
	device_authority = DeviceAuthority.UNINITIALIZED
	_reset_accumulator("manual test-harness reset button")
	_log("MANUAL RESET: device_authority forced back to UNINITIALIZED for repeat testing.")


## Round 2 addendum (2026-08-11). `index` is the OptionButton's selected
## index, which was set up in _build_ui to match the VetoFilterMode enum
## values 1:1 (via add_item's id parameter), so it can be cast directly.
func _on_veto_filter_mode_selected(index: int) -> void:
	veto_filter_mode = index as VetoFilterMode
	_veto_filter_mode_label.text = _veto_filter_mode_description()
	_log("VETO FILTER MODE CHANGED -> %s (switched live, no scene reload)" % _veto_filter_mode_name())


func _refresh_target_highlight() -> void:
	for i in range(_target_boxes.size()):
		_target_boxes[i].color = Color(0.9, 0.75, 0.2) if i == current_target_index else Color(0.3, 0.3, 0.34)


func _update_overlay() -> void:
	_authority_label.text = "device_authority = %s" % DeviceAuthority.keys()[device_authority]
	_focus_label.text = "OS focus = %s" % ("YES" if has_os_focus else "NO (frozen)")

	if device_authority == DeviceAuthority.KEYBOARD_GAMEPAD and has_os_focus:
		_accum_label.text = "accumulated_net_displacement_px = %.1f" % accumulated_net_displacement_px
		_progress_label.text = "reclaim_progress = %.2f" % reclaim_progress
	else:
		_accum_label.text = "accumulated_net_displacement_px = N/A (not computed in this state, per GDD)"
		_progress_label.text = "reclaim_progress = N/A"

	_progress_bar_fill.size = Vector2(PROGRESS_BAR_MAX_WIDTH * reclaim_progress, 20.0)

	var held_parts: Array[String] = []
	for action in NAV_ACTIONS:
		var held := Input.is_action_pressed(action)
		var recent_ticks: Array = _recent_action_ticks.get(action, [])
		var rate := recent_ticks.size()
		if held or rate > 0:
			# Round 2 addendum (2026-08-11) — per-class breakdown so a tester
			# can see, on this one line, whether keyboard (echo/OS repeat),
			# D-pad (InputEventJoypadButton), and analog stick
			# (InputEventJoypadMotion) actually dispatch qualifying events at
			# different rates while held — the core question procedures
			# B2-B5 exist to answer. Combined total kept alongside the
			# breakdown for continuity with round-1 log lines/screenshots.
			var key_rate := _class_tick_count(action, "InputEventKey")
			var dpad_rate := _class_tick_count(action, "InputEventJoypadButton")
			var stick_rate := _class_tick_count(action, "InputEventJoypadMotion")
			held_parts.append("%s held=%s total_events/last1s=%d [Key=%d D-pad=%d Stick=%d]" % [
				action, held, rate, key_rate, dpad_rate, stick_rate,
			])
	_held_state_label.text = "Held state / event rate: " + (", ".join(held_parts) if held_parts.size() > 0 else "(none)")


func _log(line: String) -> void:
	_log_lines.append(line)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
