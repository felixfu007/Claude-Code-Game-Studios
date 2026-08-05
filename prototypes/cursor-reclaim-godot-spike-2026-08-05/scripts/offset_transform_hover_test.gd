extends Control
## Root controller for Test 1 — Control offset transform vs. hover hit-testing.
##
## Builds three [HoverTargetBox] instances inside a real [HBoxContainer]
## (translate / rotate / scale hover feedback respectively) plus a
## [DebugOverlay] that draws each box's live [method Control.get_global_rect].
## A scrolling event log at the bottom shows every raw [InputEvent] each
## box's `_gui_input` actually received.
##
## This scene answers the open question registered in
## design/gdd/cursor-highlight-state.md (Open Questions, godot-specialist row,
## "Control offset transforms 對本系統的風險範圍是命中測試本身"): does
## `_gui_input` mouse routing / `get_global_rect()` follow a Control's visual
## offset transform in Godot 4.7.1, or does hit-testing stay anchored to the
## pre-transform layout rect?
##
## See prototypes/cursor-reclaim-godot-spike-2026-08-05/README.md, "Test 1",
## for the exact procedure and what a pass/fail looks like.

const MAX_LOG_LINES := 200

var _log_lines: Array[String] = []
var _log_label: RichTextLabel
var _rect_readout: Label
var _boxes: Array[HoverTargetBox] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	set_process(true)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.08, 0.09, 0.11)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 12)
	add_child(root_vbox)

	var instructions := Label.new()
	instructions.text = (
		"Test 1: Control offset transform vs. hover hit-testing. Hover each box below slowly, " +
		"approaching from outside. Watch: (1) the box's VISUAL position/rotation/scale, " +
		"(2) the YELLOW hover-flash tint (fires on Control.mouse_entered/exited), " +
		"(3) the GREEN outline below (DebugOverlay, drawn from get_global_rect()). " +
		"See README.md 'Test 1' for what confirms vs. refutes the open question."
	)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.custom_minimum_size = Vector2(0.0, 70.0)
	root_vbox.add_child(instructions)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 90)
	row.custom_minimum_size = Vector2(0.0, 220.0)
	root_vbox.add_child(row)

	_boxes.append(_make_box(row, HoverTargetBox.TransformMode.TRANSLATE, Color(0.25, 0.55, 0.85), "TRANSLATE"))
	_boxes.append(_make_box(row, HoverTargetBox.TransformMode.ROTATE, Color(0.85, 0.55, 0.25), "ROTATE"))
	_boxes.append(_make_box(row, HoverTargetBox.TransformMode.SCALE, Color(0.55, 0.85, 0.25), "SCALE"))

	_rect_readout = Label.new()
	_rect_readout.custom_minimum_size = Vector2(0.0, 80.0)
	root_vbox.add_child(_rect_readout)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = false
	_log_label.scroll_following = true
	_log_label.custom_minimum_size = Vector2(0.0, 260.0)
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_log_label)

	# Added after everything else so it draws on top of the target row.
	var overlay := DebugOverlay.new()
	add_child(overlay)
	for box in _boxes:
		overlay.register_box(box)
		box.input_logged.connect(_on_box_input_logged)


func _make_box(parent: Node, mode: int, color: Color, label_text: String) -> HoverTargetBox:
	# `mode` is typed `int` (rather than `HoverTargetBox.TransformMode`) so this
	# file doesn't need to statically reference a nested enum type declared in
	# another script — enums are plain ints under the hood, so assigning an
	# int value to the enum-typed `transform_mode` property below is valid.
	var box := HoverTargetBox.new()
	box.transform_mode = mode
	box.box_color = color
	box.target_label = label_text
	parent.add_child(box)
	return box


func _on_box_input_logged(message: String) -> void:
	_append_log("[%dms] %s" % [Time.get_ticks_msec(), message])


func _append_log(line: String) -> void:
	_log_lines.append(line)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)


func _process(_delta: float) -> void:
	var readout_lines: Array[String] = []
	for box in _boxes:
		readout_lines.append("%s get_global_rect() = %s" % [box.target_label, box.get_debug_rect()])
	_rect_readout.text = "\n".join(readout_lines)
