## Pure, node-independent rules for the manually-managed world layer scaling
## and centering (2026-09-01 screen-architecture decision). This is a
## throwaway copy of the intended production file
## (`src/ui/battle/world_layout.gd`) used only to verify the design before
## writing it into the real project — per `.claude/rules/prototype-code.md`,
## prototypes are self-contained and not imported by production code.
class_name WorldLayout
extends RefCounted

const BASE_WIDTH: int = 480
const BASE_HEIGHT: int = 270


## Largest integer scale that fits window_size without exceeding it, floored
## at 1.
static func compute_scale(window_size: Vector2i) -> int:
	var scale_x: int = window_size.x / BASE_WIDTH
	var scale_y: int = window_size.y / BASE_HEIGHT
	return maxi(1, mini(scale_x, scale_y))


## World layer rect in window-pixel space: sized to BASE_WIDTH/HEIGHT *
## compute_scale(window_size), centered inside window_size.
static func compute_rect(window_size: Vector2i) -> Rect2i:
	var scale: int = compute_scale(window_size)
	var world_size: Vector2i = Vector2i(BASE_WIDTH * scale, BASE_HEIGHT * scale)
	var margin: Vector2i = (window_size - world_size) / 2
	return Rect2i(margin, world_size)


## Base-canvas (480x270) -> window-pixel transform for window_size.
static func canvas_to_window_transform(window_size: Vector2i) -> Transform2D:
	var scale: int = compute_scale(window_size)
	var rect: Rect2i = compute_rect(window_size)
	return Transform2D(Vector2(scale, 0.0), Vector2(0.0, scale), Vector2(rect.position))


## Window-pixel -> base-canvas (480x270) transform for window_size.
static func window_to_canvas_transform(window_size: Vector2i) -> Transform2D:
	return canvas_to_window_transform(window_size).affine_inverse()
