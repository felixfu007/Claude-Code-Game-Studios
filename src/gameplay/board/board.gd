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

## Per-terrain-character data table: movement cost and passability, as two
## independent columns of the SAME table
## (design/gdd/tactical-combat-system.md Tuning Knobs #4 — Story 001). A
## future impassable terrain (wall/water/cliff) is added as a new row with
## "passable": false and a legal placeholder "cost" (never leave "cost" out —
## see passable() doc comment for why); it is NEVER modeled by a fourth
## terrain tier and NEVER by an oversized "cost" value (both explicitly ruled
## out by Story 001 Implementation Notes #3).
##
## A terrain character with no entry here is NOT covered by a default value —
## see _terrain_entry() / get_move_cost() / passable() for the
## explicit-failure behavior this requires (Story 001 R1: an unregistered
## terrain character must never silently read as "cheap and walkable").
const TERRAIN_TABLE: Dictionary = {
	TERRAIN_OPEN: {"cost": 1, "passable": true},
	TERRAIN_BRUSH: {"cost": 2, "passable": true},
	TERRAIN_FALLEN_LOG: {"cost": 3, "passable": true},
}

## Terrain characters that block line of sight. Only the flag is recorded
## here — no visibility algorithm lives in this file. Deliberately its OWN
## table, not a third column of TERRAIN_TABLE: sight-blocking and passability
## are two independent terrain properties that must never be merged into one
## query or one table column (Story 001 Implementation Notes #4).
const BLOCKS_SIGHT: Dictionary = {
	TERRAIN_FALLEN_LOG: true,
}

## Sentinel returned by get_move_cost() when pos's terrain character has no
## entry in TERRAIN_TABLE. Never a legitimate cost (real costs are always
## >= 1) — a push_error() is also emitted; see get_move_cost().
const MOVE_COST_UNKNOWN_TERRAIN: int = -1

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
##
## If pos's terrain character has no entry in TERRAIN_TABLE, this is an
## explicit failure, not a silent fallback: push_error() is emitted and
## MOVE_COST_UNKNOWN_TERRAIN (-1) is returned. This never uses assert() to
## guard the branch — a failed assert() aborts the caller and yields ordinal
## 0 of the declared return type, which for a plain int would silently read
## back as "cost 0", an even more dangerous silent success than the fallback
## this method replaces (see .claude/docs/coding-standards.md, 2026-09-15 entry).
func get_move_cost(pos: Vector2i) -> int:
	var terrain: String = get_terrain(pos)
	var entry: Variant = _terrain_entry(terrain)
	if entry == null:
		push_error("Board.get_move_cost: unregistered terrain character '%s' at %s" % [terrain, pos])
		return MOVE_COST_UNKNOWN_TERRAIN
	return entry["cost"]


## Returns true if pos is marked as sight-blocking terrain. Does not
## perform any line-of-sight calculation — flag lookup only.
func blocks_sight(pos: Vector2i) -> bool:
	var terrain: String = get_terrain(pos)
	return BLOCKS_SIGHT.get(terrain, false)


## Returns true if pos's terrain permits a unit to enter it. Passability is
## independent of get_move_cost() (design/gdd/tactical-combat-system.md Core
## Rules #2, Formulas 公式三) — a tile can be expensive AND passable, or
## cheap AND impassable; neither is derived from the other.
##
## If pos's terrain character has no entry in TERRAIN_TABLE, this is an
## explicit failure, not a silent fallback: push_error() is emitted and
## false is returned — the conservative direction, since an unregistered
## terrain character must never silently read as passable (Story 001 R1).
## This never uses assert() to guard the branch — see get_move_cost() doc
## comment and .claude/docs/coding-standards.md, 2026-09-15 entry.
##
## Design tradeoff (deliberate, see story-001 QA Test Case 3 Edge Cases): AC #1
## fixes this method's return type at `bool`, so unlike get_move_cost() (whose
## sentinel -1 can never collide with a legitimate cost), `false` here is
## reachable by BOTH a legitimate "registered, passable=false" tile AND the
## unregistered-terrain error path — a bare return-value comparison cannot
## tell them apart, and (per the coding-standards.md 2026-09-15 entry) neither
## could a caller that mistakenly used assert() instead, since a failed
## assert() also yields `false` (ordinal 0 of bool). This method deliberately
## does NOT carry its own independent error signal in its return value.
## Callers/tests that must distinguish "false because impassable" from "false
## because unregistered" have two options, both used in
## board_passable_test.gd: (1) call get_move_cost() on the same pos and check
## for MOVE_COST_UNKNOWN_TERRAIN, or (2) assert that push_error() (not a
## SCRIPT_ERROR from assert()) was actually raised via GdUnit4's
## `assert_error(<callable>).is_push_error(...)`, which structurally
## distinguishes the two failure mechanisms regardless of return value.
func passable(pos: Vector2i) -> bool:
	var terrain: String = get_terrain(pos)
	var entry: Variant = _terrain_entry(terrain)
	if entry == null:
		push_error("Board.passable: unregistered terrain character '%s' at %s" % [terrain, pos])
		return false
	return entry["passable"]


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


# Returns the TERRAIN_TABLE entry ({"cost": int, "passable": bool}) for a
# terrain character, or null if the character is unregistered. get_move_cost()
# and passable() both read through this single seam — never TERRAIN_TABLE
# directly — for two reasons:
#   1. They must agree on which characters are registered, so an
#      unregistered character fails the same way (same push_error + sentinel
#      convention) for both queries instead of each re-implementing its own
#      null-check.
#   2. It gives tests a seam to exercise a "registered but passable=false"
#      terrain character without ever mutating TERRAIN_TABLE itself — a
#      GDScript `const Dictionary` is read-only at runtime (see
#      docs/engine-reference/godot/modules/scripting-typing.md, "const
#      Dictionary 是唯讀") — and without adding fixture-only terrain to the
#      production table (see tests/unit/gameplay/board/board_passable_test.gd,
#      _BoardWithImpassableTestTerrain).
# Not "private" in an enforced sense — GDScript has no access control — but
# by convention: overridable only for the test-only subclass described above.
func _terrain_entry(terrain: String) -> Variant:
	return TERRAIN_TABLE.get(terrain)
