## Throwaway copy of the intended production WorldViewportContainer scaler
## script. Applies WorldLayout's scale/position rules to this node every time
## the owning window resizes.
extends SubViewportContainer

const WorldLayout := preload("res://scripts/world_layout.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_apply_layout()
	get_window().size_changed.connect(_apply_layout)


func _apply_layout() -> void:
	var window_size: Vector2i = get_window().size
	var rect: Rect2i = WorldLayout.compute_rect(window_size)
	position = Vector2(rect.position)
	size = Vector2(rect.size)
	stretch_shrink = WorldLayout.compute_scale(window_size)
