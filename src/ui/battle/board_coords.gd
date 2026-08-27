## Pure static grid <-> pixel coordinate conversion for the battle board.
##
## Every function is [code]static[/code] and takes all its inputs as
## parameters — no node access, no autoloads, no scene-tree queries. This
## lets headless unit tests call the window-space conversions directly with
## transform values captured from a real running engine, instead of the
## logic being buried inside an [code]_input()[/code] callback where only a
## live [InputEvent] could reach it (and headless Godot delivers none — see
## [code].claude/docs/coding-standards.md[/code]).
##
## This formalizes the findings of the throwaway spike
## [code]prototypes/board-render-input-spike-2026-08-27/[/code]: the world
## layer and UI layer resolve to a single affine transform plus one constant
## offset, as long as [code]WorldViewportContainer[/code] stays anchored
## full-rect at the base canvas origin. See that spike's README for the
## 20/20 round-trip measurements this design is based on. The spike is
## dead — this is the from-scratch production rewrite of its conclusions,
## per [code].claude/rules/prototype-code.md[/code] ("the prototype code is
## NOT migrated directly — it is rewritten to production standards").
class_name BoardCoords
extends RefCounted

## Pixel edge length of one board tile at 1x (base-canvas) scale.
const CELL_SIZE: int = 32

## Board dimensions in tiles. Intentionally duplicated from
## [code]Board.BOARD_WIDTH[/code] / [code]Board.BOARD_HEIGHT[/code]
## ([code]src/gameplay/board/board.gd[/code]) rather than importing that
## class: [BoardCoords] is a presentation-layer utility and must not gain a
## gameplay-code dependency. If the board dimensions ever change, both
## constants must be updated together.
const BOARD_COLS: int = 13
const BOARD_ROWS: int = 6

## Top-left corner of the 416x192 board (13*32 x 6*32), centered inside the
## 480x270 base canvas: [code](480-416)/2 = 32[/code], [code](270-192)/2 =
## 39[/code]. Both divide evenly — no sub-pixel centering, confirmed by the
## spike's 20/20 round-trip measurements (2026-08-27).
const BOARD_ORIGIN: Vector2 = Vector2(32.0, 39.0)


## Returns the top-left corner of [param cell], in WorldViewport-local
## pixels (i.e. the 480x270 base-canvas space inside the world layer, before
## any window scaling is applied).
static func grid_to_local(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)


## Returns the center point of [param cell], in WorldViewport-local pixels.
static func grid_to_local_center(cell: Vector2i) -> Vector2:
	return grid_to_local(cell) + Vector2(CELL_SIZE, CELL_SIZE) * 0.5


## Converts a WorldViewport-local pixel position to a grid cell. May return
## a cell outside the board — callers must check [method is_in_bounds]
## before trusting the result.
static func local_to_grid(local_pos: Vector2) -> Vector2i:
	var rel: Vector2 = local_pos - BOARD_ORIGIN
	return Vector2i(floori(rel.x / float(CELL_SIZE)), floori(rel.y / float(CELL_SIZE)))


## Returns [code]true[/code] if [param cell] is within the fixed
## [code]BOARD_COLS x BOARD_ROWS[/code] grid.
static func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_COLS and cell.y >= 0 and cell.y < BOARD_ROWS


## Converts a raw OS window pixel position to a grid cell. May return a cell
## outside the board (e.g. a click landing in a letterbox bar) — callers
## must check [method is_in_bounds] before trusting the result.
##
## [param window_to_canvas] MUST be
## [code]Window.get_final_transform().affine_inverse()[/code], captured live
## from the engine immediately before use — it maps window-physical pixels
## to the 480x270 base-canvas space that [code]canvas_items[/code] stretch
## mode normalizes everything to. [b]Never hand-roll the stretch/keep/
## integer algorithm[/b] — always query the engine for this transform (see
## [code].claude/docs/technical-preferences.md[/code], "換算務必向引擎查
## Window.get_final_transform()，絕不可自己用視窗尺寸推算").
##
## [param world_viewport_canvas_origin] MUST be
## [code]WorldViewportContainer.global_position[/code] — where the world
## [SubViewport]'s local [code](0,0)[/code] lands in that same base-canvas
## space. It is a parameter rather than a hardcoded constant because it
## depends on the container staying anchored full-rect at the canvas origin;
## see the class doc comment above for what breaks if that stops being true.
static func window_to_grid(
	window_pos: Vector2,
	window_to_canvas: Transform2D,
	world_viewport_canvas_origin: Vector2
) -> Vector2i:
	var canvas_pos: Vector2 = window_to_canvas * window_pos
	var local_pos: Vector2 = canvas_pos - world_viewport_canvas_origin
	return local_to_grid(local_pos)


## Inverse of [method window_to_grid]: converts [param cell]'s center point
## to a raw OS window pixel position.
##
## [param canvas_to_window] MUST be [code]Window.get_final_transform()[/code]
## (not inverted), captured live from the engine. [param
## world_viewport_canvas_origin] is the same value described in
## [method window_to_grid].
static func grid_to_window(
	cell: Vector2i,
	canvas_to_window: Transform2D,
	world_viewport_canvas_origin: Vector2
) -> Vector2:
	var local_pos: Vector2 = grid_to_local_center(cell)
	var canvas_pos: Vector2 = local_pos + world_viewport_canvas_origin
	return canvas_to_window * canvas_pos
