## Tactical grid for the board: terrain, movement cost, occupancy, and
## move-range queries. Fixed 13x6 grid (x: 0..12, y: 0..5).
##
## Line-of-sight is NOT computed here. This class only records which tiles
## are marked as sight-blocking terrain; the actual visibility check is
## owned by a different system.
class_name Board
extends RefCounted

## Grid dimensions. Coordinates outside [0, BOARD_WIDTH) x [0, BOARD_HEIGHT)
## are always out of bounds.
const BOARD_WIDTH: int = 13
const BOARD_HEIGHT: int = 6

## Terrain character constants, as used by from_ascii().
const TERRAIN_OPEN: String = "."
const TERRAIN_BRUSH: String = ","
const TERRAIN_FALLEN_LOG: String = "#"

## Cost to enter a tile of a given terrain character. Unknown/unset terrain
## defaults to TERRAIN_OPEN cost (see get_move_cost()).
const MOVE_COST: Dictionary = {
	TERRAIN_OPEN: 1,
	TERRAIN_BRUSH: 2,
	TERRAIN_FALLEN_LOG: 3,
}

## Terrain characters that block line of sight. Only the flag is recorded
## here — no visibility algorithm lives in this file.
const BLOCKS_SIGHT: Dictionary = {
	TERRAIN_FALLEN_LOG: true,
}

## Sentinel returned by get_occupant() when a tile has no occupant.
const NO_OCCUPANT: int = -1

# Vector2i -> String (single-character terrain code). Tiles not present
# default to TERRAIN_OPEN when queried.
var _terrain: Dictionary = {}

# Vector2i -> int (unit id). Tiles not present have no occupant.
var _occupants: Dictionary = {}


## Builds a Board from an ASCII grid. `rows[y]` is the row for that y
## coordinate, and each character in the row is the terrain for that x.
static func from_ascii(rows: PackedStringArray) -> Board:
	var board: Board = Board.new()
	for y: int in range(rows.size()):
		var row: String = rows[y]
		for x: int in range(row.length()):
			var pos: Vector2i = Vector2i(x, y)
			board._terrain[pos] = row.substr(x, 1)
	return board


## Returns true if pos is within the fixed board bounds.
func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_WIDTH and pos.y >= 0 and pos.y < BOARD_HEIGHT


## Returns the single-character terrain code at pos. Defaults to
## TERRAIN_OPEN if the tile was never set (e.g. incomplete from_ascii input).
func get_terrain(pos: Vector2i) -> String:
	return _terrain.get(pos, TERRAIN_OPEN)


## Returns the movement point cost to enter pos.
func get_move_cost(pos: Vector2i) -> int:
	var terrain: String = get_terrain(pos)
	return MOVE_COST.get(terrain, MOVE_COST[TERRAIN_OPEN])


## Returns true if pos is marked as sight-blocking terrain. Does not
## perform any line-of-sight calculation — flag lookup only.
func blocks_sight(pos: Vector2i) -> bool:
	var terrain: String = get_terrain(pos)
	return BLOCKS_SIGHT.get(terrain, false)


## Marks pos as occupied by unit_id, overwriting any previous occupant.
func set_occupant(pos: Vector2i, unit_id: int) -> void:
	_occupants[pos] = unit_id


## Removes any occupant recorded at pos. No-op if pos was already empty.
func clear_occupant(pos: Vector2i) -> void:
	_occupants.erase(pos)


## Returns true if a unit is recorded as occupying pos.
func has_occupant(pos: Vector2i) -> bool:
	return _occupants.has(pos)


## Returns the unit id occupying pos, or NO_OCCUPANT if the tile is empty.
func get_occupant(pos: Vector2i) -> int:
	return _occupants.get(pos, NO_OCCUPANT)


## Returns every tile reachable from origin with at most mp movement points,
## using Dijkstra's algorithm over 4-directional (orthogonal) moves. The
## origin tile itself is never included in the result. Tiles occupied by a
## unit (other than the search having started there) cannot be entered or
## passed through. Out-of-bounds tiles are never reachable.
func reachable_tiles(origin: Vector2i, mp: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_in_bounds(origin):
		return result

	# Vector2i -> int, cheapest known cost to reach that tile from origin.
	var best_cost: Dictionary = {origin: 0}
	var visited: Dictionary = {}
	var frontier: Array[Vector2i] = [origin]

	while not frontier.is_empty():
		var frontier_index: int = _index_of_cheapest(frontier, best_cost)
		var current: Vector2i = frontier[frontier_index]
		frontier.remove_at(frontier_index)

		if visited.has(current):
			continue
		visited[current] = true

		for neighbor: Vector2i in _get_orthogonal_neighbors(current):
			if not is_in_bounds(neighbor):
				continue
			if has_occupant(neighbor):
				continue

			var candidate_cost: int = best_cost[current] + get_move_cost(neighbor)
			if candidate_cost > mp:
				continue
			if not best_cost.has(neighbor) or candidate_cost < best_cost[neighbor]:
				best_cost[neighbor] = candidate_cost
				frontier.append(neighbor)

	for pos: Vector2i in best_cost:
		if pos != origin:
			result.append(pos)
	return result


# Returns the four orthogonal neighbors of pos. Neighbors may be out of
# bounds — callers must check is_in_bounds().
func _get_orthogonal_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = [
		pos + Vector2i.UP,
		pos + Vector2i.DOWN,
		pos + Vector2i.LEFT,
		pos + Vector2i.RIGHT,
	]
	return neighbors


# Returns the index within frontier whose best_cost entry is smallest.
# Linear scan is fine at this board's scale (max 78 tiles).
func _index_of_cheapest(frontier: Array[Vector2i], best_cost: Dictionary) -> int:
	var cheapest_index: int = 0
	var cheapest_cost: int = best_cost[frontier[0]]
	for i: int in range(1, frontier.size()):
		var cost: int = best_cost[frontier[i]]
		if cost < cheapest_cost:
			cheapest_cost = cost
			cheapest_index = i
	return cheapest_index
