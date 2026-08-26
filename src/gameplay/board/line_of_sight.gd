## Grid line-of-sight utility.
##
## Determines whether a straight line between two grid cells is unobstructed.
## This module has no knowledge of any board, resource, or scene — occlusion
## is supplied entirely through the [param is_occluding] callback passed to
## [method is_clear]. No RNG, no file I/O, no nodes.
##
## Coordinate convention: cell [code](x, y)[/code] occupies the unit square
## centered on that integer point (cell centers are integers, cell edges fall
## on half-integer coordinates). The vertex shared by the four cells
## [code](x, y)[/code], [code](x+1, y)[/code], [code](x, y+1)[/code] and
## [code](x+1, y+1)[/code] sits at [code](x+0.5, y+0.5)[/code].
class_name LineOfSight
extends RefCounted


## Returns [code]true[/code] if a straight line from cell [param from] to cell
## [param to] is unobstructed.
##
## [param is_occluding] is called with a single [Vector2i] cell coordinate and
## must return a [bool]. [param from] and [param to] themselves are never
## queried. Every other cell whose interior the line explicitly passes
## through blocks line of sight on its own if occluding (logical OR across
## cells). When the line passes exactly through a corner shared by four
## cells, the line does not pass through the interior of the other two —
## those two flanking cells only block that corner if [i]both[/i] are
## occluding (logical AND for that corner, then OR'd with everything else).
static func is_clear(from: Vector2i, to: Vector2i, is_occluding: Callable) -> bool:
	if from == to:
		return true

	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	var adx: int = dx if dx >= 0 else -dx
	var ady: int = dy if dy >= 0 else -dy
	var sx: int = 1 if dx > 0 else (-1 if dx < 0 else 0)
	var sy: int = 1 if dy > 0 else (-1 if dy < 0 else 0)

	var cx: int = from.x
	var cy: int = from.y
	var k: int = 0  # next vertical (column) edge crossing index, 0..adx-1
	var j: int = 0  # next horizontal (row) edge crossing index, 0..ady-1

	while cx != to.x or cy != to.y:
		var vertical_due: bool = k < adx
		var horizontal_due: bool = j < ady

		# Compare the next vertical-edge crossing t = (2k+1)/(2*adx) against
		# the next horizontal-edge crossing t = (2j+1)/(2*ady) via
		# cross-multiplication, so the comparison stays exact-integer and
		# fully deterministic (no floats, no RNG).
		var va: int = (2 * k + 1) * ady if vertical_due else -1
		var vb: int = (2 * j + 1) * adx if horizontal_due else -1

		if vertical_due and horizontal_due and va == vb:
			# Corner event: the line passes exactly through the vertex
			# shared by the current cell, the newly entered "ahead" cell,
			# and the two flanking cells it never actually enters.
			var ahead: Vector2i = Vector2i(cx + sx, cy + sy)
			var flank_a: Vector2i = Vector2i(cx + sx, cy)
			var flank_b: Vector2i = Vector2i(cx, cy + sy)
			if bool(is_occluding.call(flank_a)) and bool(is_occluding.call(flank_b)):
				return false
			if _blocks(ahead, to, is_occluding):
				return false
			cx = ahead.x
			cy = ahead.y
			k += 1
			j += 1
		elif vertical_due and (not horizontal_due or va < vb):
			cx += sx
			if _blocks(Vector2i(cx, cy), to, is_occluding):
				return false
			k += 1
		elif horizontal_due:
			cy += sy
			if _blocks(Vector2i(cx, cy), to, is_occluding):
				return false
			j += 1
		else:
			# Unreachable: the while-condition guarantees at least one of
			# vertical_due / horizontal_due is still true whenever we get
			# here. Kept as a defensive break so a future bug fails loud
			# (returns clear) instead of looping forever.
			push_error("LineOfSight.is_clear: unreachable traversal state")
			break

	return true


## Returns [code]true[/code] if [param cell] should block line of sight,
## i.e. it is not one of the two query endpoints and [param is_occluding]
## reports it as occluding.
static func _blocks(cell: Vector2i, to: Vector2i, is_occluding: Callable) -> bool:
	return cell != to and bool(is_occluding.call(cell))
