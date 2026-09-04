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
## offset. See that spike's README for the 20/20 round-trip measurements this
## design is based on. The spike is dead — this is the from-scratch
## production rewrite of its conclusions, per
## [code].claude/rules/prototype-code.md[/code] ("the prototype code is NOT
## migrated directly — it is rewritten to production standards").
##
## [b]2026-09-04 (Story 001, screen-scaling epic) — the transform's SOURCE
## changed, this file's own math did not.[/b] The 2026-08-27 spike (and this
## file's function docs, until this note) assumed [code]window/stretch/mode
## = "canvas_items"[/code], where the engine itself computed the affine
## transform via [code]Window.get_final_transform()[/code] and
## [code]WorldViewportContainer[/code] stayed anchored full-rect at the base
## canvas origin (so the "constant offset" term was always
## [code]Vector2.ZERO[/code] in practice). Both premises are gone:
## [code]window/stretch/mode[/code] is now [code]"disabled"[/code] (the
## engine performs no scaling of its own — see
## [code]project.godot[/code]), [code]WorldViewportContainer[/code] is now
## manually centered rather than full-rect (see
## [code]world_viewport_scaler.gd[/code]), and the sole source of the
## transform is now [WorldLayout], not the engine. [b]This file's own pure
## functions did not need to change at all[/b] — they were always
## parameterized on a transform + an origin, never on how either was
## produced, which is exactly what let the switch happen without touching
## this file's logic. Only the function docs below, which named the specific
## call [code]Window.get_final_transform()[/code], needed correcting to name
## the new call, [code]WorldLayout.canvas_to_window_transform()[/code]/
## [code]window_to_canvas_transform()[/code] instead — see those methods'
## own doc comments for why call sites must go through [WorldLayout] and
## never re-derive the scale/offset math themselves.
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
## [code]WorldLayout.window_to_canvas_transform(window_size)[/code] —
## [b]2026-09-04 correction, see class doc comment[/b]: this used to be
## [code]Window.get_final_transform().affine_inverse()[/code] under the
## retired [code]"canvas_items"[/code] stretch mode; under the current
## [code]"disabled"[/code] mode the engine no longer computes any transform
## of its own, so [WorldLayout] is the sole source of it now. [b]Never
## hand-roll the scale/centering math[/b] — always call [WorldLayout] for
## this transform, for the same reason the old discipline said never to
## hand-roll [code]stretch[/code]/[code]keep[/code]/[code]integer[/code]: a
## hand-rolled copy that drifts from [WorldLayout]'s copy will disagree
## silently, not loudly, and only at boundary window sizes.
##
## [param world_viewport_canvas_origin] MUST be [code]Vector2.ZERO[/code]
## when [param window_to_canvas] came from [WorldLayout] — [b]2026-09-04
## correction[/b]: this used to be [code]WorldViewportContainer
## .global_position[/code] (the offset between a separate, full-rect UI
## base-canvas space and the world [SubViewport]'s local origin). That
## intermediate UI-canvas space no longer exists as a distinct thing — the
## UI layer's own basis is now 1:1 with real window pixels (`NATIVE`, per
## `design/art/screen-architecture.md` §1), so
## [method WorldLayout.canvas_to_window_transform]/[method
## WorldLayout.window_to_canvas_transform] already fold the centering offset
## directly into the returned transform. Leaving this parameter in the
## signature (rather than dropping it) is deliberate: it is still a real
## input this pure function needs in principle, and a caller feeding it a
## transform from some other source (e.g. a future UI-layer conversion) is
## free to pass a non-zero value.
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
## [param canvas_to_window] MUST be
## [code]WorldLayout.canvas_to_window_transform(window_size)[/code] (not
## inverted) — [b]2026-09-04 correction, see class doc comment and
## [method window_to_grid][/b]: this used to be
## [code]Window.get_final_transform()[/code]. [param
## world_viewport_canvas_origin] is the same value described in
## [method window_to_grid] (pass [code]Vector2.ZERO[/code] alongside a
## [WorldLayout] transform).
static func grid_to_window(
	cell: Vector2i,
	canvas_to_window: Transform2D,
	world_viewport_canvas_origin: Vector2
) -> Vector2:
	var local_pos: Vector2 = grid_to_local_center(cell)
	var canvas_pos: Vector2 = local_pos + world_viewport_canvas_origin
	return canvas_to_window * canvas_pos
