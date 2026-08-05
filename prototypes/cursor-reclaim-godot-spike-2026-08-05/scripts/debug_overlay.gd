class_name DebugOverlay
extends Control
## Draws a live outline over every registered [HoverTargetBox], using each
## box's [method HoverTargetBox.get_debug_rect] (i.e. Godot's own
## [method Control.get_global_rect]) every frame.
##
## This overlay never receives mouse input itself ([member Control.mouse_filter]
## is IGNORE) and never applies any transform of its own — it fills the whole
## window with no rotation/scale/offset — so a rectangle drawn here in
## [method _draw] is always in true global/screen space. If the drawn outline
## visibly lags behind, or fails to track, a target box that is being scaled,
## rotated, or translated on hover, that is direct on-screen evidence that
## [method Control.get_global_rect] (and therefore Godot's hit-testing) is
## NOT following the visual offset transform applied to that box.

@export var outline_color: Color = Color(0.0, 1.0, 0.4, 1.0)
@export var outline_width: float = 3.0

var _tracked_boxes: Array[HoverTargetBox] = []


## Registers a box whose [method Control.get_global_rect] should be drawn
## every frame. Call once per box, after both nodes are in the tree.
func register_box(box: HoverTargetBox) -> void:
	_tracked_boxes.append(box)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for box in _tracked_boxes:
		if not is_instance_valid(box):
			continue
		var global_rect := box.get_debug_rect()
		# This DebugOverlay itself has no position/rotation/scale offset and
		# covers the full window, so its local drawing space is identical to
		# global/window space — drawing at `global_rect` directly (no
		# transform math) is correct.
		draw_rect(global_rect, outline_color, false, outline_width)

	var mouse_pos := get_global_mouse_position()
	var crosshair_half_size := 8.0
	draw_line(mouse_pos - Vector2(crosshair_half_size, 0.0), mouse_pos + Vector2(crosshair_half_size, 0.0), Color.WHITE, 2.0)
	draw_line(mouse_pos - Vector2(0.0, crosshair_half_size), mouse_pos + Vector2(0.0, crosshair_half_size), Color.WHITE, 2.0)
