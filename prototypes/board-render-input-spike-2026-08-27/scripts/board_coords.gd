extends RefCounted
## Pure board-grid <-> pixel conversion utilities for the board render/input spike.
##
## Every function takes its inputs as parameters — no scene-tree access, no globals —
## so a measurement/validation harness can call it directly with numbers captured from
## the live engine, instead of the logic being embedded inside `_input()` where it can
## only be exercised by an actual InputEvent (which headless Godot never delivers).

const CELL_SIZE: int = 32
const BOARD_COLS: int = 13
const BOARD_ROWS: int = 6

## Top-left of the 416x192 board, centered inside the 480x270 base canvas:
## (480-416)/2 = 32, (270-192)/2 = 39. Both divide evenly — no sub-pixel centering.
const BOARD_ORIGIN: Vector2 = Vector2(32.0, 39.0)

## Grid cell -> its top-left corner, in WorldViewport local pixels.
static func grid_to_local(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)

## Grid cell -> its center point, in WorldViewport local pixels.
static func grid_to_local_center(cell: Vector2i) -> Vector2:
	return grid_to_local(cell) + Vector2(CELL_SIZE, CELL_SIZE) * 0.5

## WorldViewport local pixel position -> grid cell. May return an out-of-bounds cell;
## callers must check `is_in_bounds()` before trusting the result.
static func local_to_grid(local_pos: Vector2) -> Vector2i:
	var rel: Vector2 = local_pos - BOARD_ORIGIN
	return Vector2i(floori(rel.x / float(CELL_SIZE)), floori(rel.y / float(CELL_SIZE)))

static func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_COLS and cell.y >= 0 and cell.y < BOARD_ROWS

## Full chain: a raw OS window pixel position -> grid cell.
##
## window_to_canvas: `Window.get_final_transform().affine_inverse()`, captured live —
##   maps window-physical pixels to the 480x270 base-canvas space that canvas_items
##   stretch mode normalizes everything to. This is the engine's own transform, not a
##   hand-rolled reimplementation of the stretch/keep/integer algorithm.
## world_viewport_canvas_origin: WorldViewportContainer.global_position, i.e. where the
##   SubViewport's local (0,0) lands in that same base-canvas space.
static func window_to_grid(window_pos: Vector2, window_to_canvas: Transform2D, world_viewport_canvas_origin: Vector2) -> Vector2i:
	var canvas_pos: Vector2 = window_to_canvas * window_pos
	var local_pos: Vector2 = canvas_pos - world_viewport_canvas_origin
	return local_to_grid(local_pos)

## Inverse of the above: grid cell -> raw OS window pixel position (cell center).
static func grid_to_window(cell: Vector2i, canvas_to_window: Transform2D, world_viewport_canvas_origin: Vector2) -> Vector2:
	var local_pos: Vector2 = grid_to_local_center(cell)
	var canvas_pos: Vector2 = local_pos + world_viewport_canvas_origin
	return canvas_to_window * canvas_pos
