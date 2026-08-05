class_name HoverTargetBox
extends Control
## A single hover-feedback target used by the offset-transform spike (Test 1).
##
## On hover, this Control animates ONE of three visual transforms — translate,
## rotate, or scale — applied directly to its OWN [member Control.position] /
## [member Control.rotation] / [member Control.scale] / [member Control.pivot_offset]
## properties via a [Tween]. This is the mechanism the project's engine
## reference docs describe as Godot 4.7's "Control offset transforms"
## (see docs/engine-reference/godot/current-best-practices.md, "UI (4.7)"
## section: "Controls can now be translated, rotated, or scaled visually
## without fighting container re-layout").
##
## This node is placed inside a real Container (see offset_transform_hover_test.gd)
## so that its [member Control.position] is normally container-managed —
## exercising exactly the "without fighting container re-layout" claim.
##
## Emits [signal input_logged] every time [method _gui_input] receives a
## mouse motion or mouse button event, so the parent scene can render a live
## event log. Exposes [method get_debug_rect] for the sibling [DebugOverlay]
## to draw Godot's authoritative hit-test rect against.

## Emitted for every raw mouse InputEvent this Control's [method _gui_input]
## actually receives. [param message] is a pre-formatted, human-readable line.
signal input_logged(message: String)

## Emitted when Godot's own hover recognition ([signal Control.mouse_entered] /
## [signal Control.mouse_exited]) toggles — i.e. what the ENGINE currently
## believes is "hovered", independent of what is visually drawn.
signal hover_state_changed(is_hovered: bool)

enum TransformMode { TRANSLATE, ROTATE, SCALE }

@export var transform_mode: TransformMode = TransformMode.TRANSLATE
@export var box_color: Color = Color(0.25, 0.55, 0.85)
@export var target_label: String = "TRANSLATE"

const BOX_SIZE := Vector2(140.0, 140.0)
const TRANSLATE_OFFSET := Vector2(-30.0, -30.0)
const ROTATE_DEGREES := 20.0
const SCALE_FACTOR := 1.4
const TWEEN_DURATION := 0.18

var _box: ColorRect
var _hover_flash: ColorRect
var _caption: Label
var _tween: Tween
var _base_position: Vector2 = Vector2.ZERO
var _base_position_captured: bool = false


func _ready() -> void:
	custom_minimum_size = BOX_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

	_box = ColorRect.new()
	_box.name = "Box"
	_box.color = box_color
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_box)

	_hover_flash = ColorRect.new()
	_hover_flash.name = "HoverFlash"
	_hover_flash.color = Color(1.0, 1.0, 0.0, 0.35)
	_hover_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hover_flash.visible = false
	add_child(_hover_flash)

	_caption = Label.new()
	_caption.name = "Caption"
	_caption.text = target_label
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_caption)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Deferred by one frame so the parent Container has already assigned
	# this Control's layout-owned `position`/`size` before we start writing
	# a hover offset on top of it and before we compute `pivot_offset`.
	call_deferred("_capture_base_position")


func _capture_base_position() -> void:
	_base_position = position
	pivot_offset = size / 2.0
	_base_position_captured = true


func _on_mouse_entered() -> void:
	_hover_flash.visible = true
	hover_state_changed.emit(true)
	_play_transform(true)


func _on_mouse_exited() -> void:
	_hover_flash.visible = false
	hover_state_changed.emit(false)
	_play_transform(false)


func _play_transform(entering: bool) -> void:
	if not _base_position_captured:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	match transform_mode:
		TransformMode.TRANSLATE:
			var target_pos: Vector2 = _base_position + TRANSLATE_OFFSET if entering else _base_position
			_tween.tween_property(self, "position", target_pos, TWEEN_DURATION)
		TransformMode.ROTATE:
			var target_rot: float = deg_to_rad(ROTATE_DEGREES) if entering else 0.0
			_tween.tween_property(self, "rotation", target_rot, TWEEN_DURATION)
		TransformMode.SCALE:
			var target_scale: Vector2 = Vector2.ONE * SCALE_FACTOR if entering else Vector2.ONE
			_tween.tween_property(self, "scale", target_scale, TWEEN_DURATION)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var mouse_event := event as InputEventMouse
		var rect := get_global_rect()
		var message := "%s | _gui_input %s | local_pos=%s | get_global_rect()=%s" % [
			target_label,
			mouse_event.get_class(),
			mouse_event.position,
			rect,
		]
		input_logged.emit(message)


## Returns this box's current [method Control.get_global_rect] for the
## [DebugOverlay] to draw against. Kept as an explicit accessor (rather than
## the overlay calling [method Control.get_global_rect] directly) so the
## intent — "this is the engine's authoritative hit-test rect, independent
## of whatever visual transform is currently applied" — is documented at the
## call site.
func get_debug_rect() -> Rect2:
	return get_global_rect()
