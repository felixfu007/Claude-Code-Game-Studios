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

## story-003b-atomicity-write-guard-consolidation.md / ADR-0001 "連帶裁決一":
## optional write-window guard. Unset by default ([code]Callable()[/code], an
## invalid Callable) — in that state every occupancy mutator below behaves
## EXACTLY as it did before this guard existed, unconditionally. This is a
## deliberate selective-mount contract, not an implementation convenience:
## [Board] remains a fully standalone, directly-constructible [RefCounted]
## for every existing [code]Board.from_ascii()[/code] / [code]Board.new()[/code]
## test fixture that never goes through [BattleState] at all — see
## [method attach_write_guard].
var _write_guard: Callable = Callable()


## Attaches [param checker] (signature [code]func() -> bool[/code]) as this
## board's write-window guard — called by [method set_occupant]/[method
## clear_occupant] before mutating, rejecting the call if it returns
## [code]false[/code]. [method BattleState.create] is the only production
## caller, passing [code]Callable(state, "write_window_is_open")[/code] —
## a [Callable] injection, deliberately NOT a reference to [BattleState]
## itself, so [Board] never gains a dependency on the class that composes it
## (ADR-0001's layering: [Board] "does not hold the flag"). Passing an
## unset/invalid [Callable] restores the pre-guard default (always permitted)
## — this is a legitimate, supported call, not an edge case to avoid.
func attach_write_guard(checker: Callable) -> void:
	_write_guard = checker


# Shared by set_occupant()/clear_occupant(): true if this mutation may
# proceed — no guard attached (selective mount) or the attached guard
# reports the write window open.
func _write_allowed() -> bool:
	return not _write_guard.is_valid() or bool(_write_guard.call())


## Builds a Board from an ASCII grid. `rows[y]` is the row for that y
## coordinate, and each character in the row is the terrain for that x.
##
## Performs load-time validation as two independent, additive diagnostic
## checks on top of the existing storage/parse behavior (defense-in-depth
## alongside get_move_cost()/passable()'s query-time checks below — Story
## 016, TR-tactical-002 "並有載入時驗證"):
##   1. Structural: rows.size() must equal BOARD_HEIGHT; each row's length()
##      must equal BOARD_WIDTH.
##   2. Compositional: every cell's character must have an entry in
##      TERRAIN_TABLE, checked through the same _terrain_entry() seam
##      get_move_cost()/passable() use (see that method's doc comment).
## Every violation triggers its own push_error() call and the scan never
## stops at the first one — a hand-edited ASCII level file's mistakes tend
## to repeat (a whole mistyped row, a copy-paste error), and one load that
## reports every problem at once is more useful than a fix-one/reload loop
## for this data's hand-authored, occasionally-wrong usage pattern.
##
## Deliberately does NOT use assert() to guard any of this: a failed
## assert() aborts the caller and yields ordinal 0 of the declared return
## type, which here would silently produce a seemingly-valid empty Board —
## see .claude/docs/coding-standards.md, 2026-09-15 entry, and the same
## reasoning already documented on get_move_cost()/passable() below.
##
## Deliberately does NOT reject construction, return null, or throw on
## failure: this project has no "construction can fail" convention
## anywhere (Board/TurnOrder/Unit are all build-always-succeeds,
## query-time-explicit-failure, exactly like get_move_cost()/passable()
## below). Storage/parse behavior is completely unchanged by any of these
## checks — a too-short/too-long row's existing characters are still
## stored exactly as before, and an unregistered character is still stored
## as-is (get_move_cost()/passable() already handle it at query time, same
## as before this validation existed).
static func from_ascii(rows: PackedStringArray) -> Board:
	var board: Board = Board.new()
	if rows.size() != BOARD_HEIGHT:
		push_error("Board.from_ascii: expected %d rows, got %d" % [BOARD_HEIGHT, rows.size()])
	for y: int in range(rows.size()):
		var row: String = rows[y]
		if row.length() != BOARD_WIDTH:
			push_error("Board.from_ascii: row %d has length %d, expected %d" % [y, row.length(), BOARD_WIDTH])
		for x: int in range(row.length()):
			var pos: Vector2i = Vector2i(x, y)
			var terrain: String = row.substr(x, 1)
			if board._terrain_entry(terrain) == null:
				push_error("Board.from_ascii: unregistered terrain character '%s' at %s" % [terrain, pos])
			board._terrain[pos] = terrain
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
##
## 🔴 story-003b (ADR-0001 硬性義務第 4 條): renamed with a leading
## underscore — no longer public API, same "not enforced by the language,
## enforced by convention" status as [method _terrain_entry] below. Intended
## callers are [BattleState]'s own mutators running inside a
## [method BattleState.commit_authoritative_change] window. This board's own
## test fixtures (constructed without a guard attached, never going through
## [BattleState]) call this directly too — that is expected and unaffected
## by the rename or by the guard: both are orthogonal, selective-mount
## mechanisms (see [member _write_guard]) that leave a directly-constructed
## [Board] behaving exactly as it did before this story.
## Rejected (via [method push_error], state left unchanged) if a guard IS
## attached and reports the write window closed.
func _set_occupant(pos: Vector2i, unit_id: int) -> void:
	if not _write_allowed():
		push_error("Board._set_occupant: rejected at %s — write window is not open" % pos)
		return
	_occupants[pos] = unit_id


## Removes any occupant recorded at pos. No-op if pos was already empty.
## Same gated-mutator contract as [method _set_occupant] — see its doc comment.
func _clear_occupant(pos: Vector2i) -> void:
	if not _write_allowed():
		push_error("Board._clear_occupant: rejected at %s — write window is not open" % pos)
		return
	_occupants.erase(pos)


## Returns true if a unit is recorded as occupying pos.
func has_occupant(pos: Vector2i) -> bool:
	return _occupants.has(pos)


## Returns the unit id occupying pos, or NO_OCCUPANT if the tile is empty.
func get_occupant(pos: Vector2i) -> int:
	return _occupants.get(pos, NO_OCCUPANT)


## Returns every tile reachable from origin with at most mp movement points,
## using Dijkstra's algorithm over 4-directional (orthogonal) moves. The
## origin tile itself is never included in the result. Out-of-bounds tiles
## are never reachable.
##
## Two independent boolean switches (design/gdd/tactical-combat-system.md
## Formulas 公式三, Story 002 — `reachable_set(u, ignore_occupancy=false,
## ignore_passability=false)`) select which of four collectively-exhaustive,
## pairwise-disjoint sets this describes (GDD AC-13: `A ⊆ B ⊆ C`, and
## `A ∪ (B\A) ∪ (C\B) ∪ (Grid\C) = Grid` with no tile in more than one of the
## four). Callers that do not pass either switch (both default false) get
## byte-for-byte the same output as before this story existed — this is the
## sole meaning of "reachable" this method uses when acting as a movement
## legality check:
##   - ignore_occupancy=false, ignore_passability=false -> `A` (the only set
##     that is ever a legal movement target set)
##   - ignore_occupancy=true,  ignore_passability=false -> `B` (`A` plus every
##     tile whose only obstruction is occupancy)
##   - ignore_occupancy=true,  ignore_passability=true  -> `C` (`B` plus every
##     tile whose only remaining obstruction is impassable terrain)
##   - `Grid \ C` is never returned by this method under any parameter
##     combination — every tile in it is unreachable regardless of which
##     switches are set, because it takes more than `mp` accumulated cost to
##     reach even with both switches ignoring their respective obstruction
##
## 🔴 `ignore_occupancy=true`/`ignore_passability=true` outputs exist ONLY so a
## caller (story-007's move-range query interface) can label WHY a tile is
## unreachable (blocked by occupancy vs. terrain vs. insufficient MP) for UI
## display. This method itself never treats a `B`- or `C`-only result as a
## legal move target, and deliberately has no method name, parameter name, or
## return value that implies "legal move set" when either switch is true —
## that judgment is the caller's responsibility (GDD Formulas 公式三: 「此參數
## 僅供 UI Requirements 標示不可達成因使用……不得作為移動合法性判定依據」).
##
## Occupied tiles are excluded as both path-through tiles AND as the
## destination itself (unless ignore_occupancy=true); impassable
## (`passable()=false`) tiles are likewise excluded both as path-through
## tiles and as the destination itself (unless ignore_passability=true) —
## reaching a tile requires every tile ALONG the path, not just the
## destination, to clear whichever of these two checks is currently active
## (GDD AC-2, Story 002 Implementation Notes #2/#3: passability must gate
## traversal independently of and prior to cost accumulation, never be
## expressed by an inflated cost value).
##
## Regardless of which combination is requested, the underlying search is a
## bounded frontier expansion: it early-exits once a candidate's accumulated
## cost exceeds mp and never floods every board tile before filtering
## (TR-tactical-008, GDD Open Questions OQ-16).
func reachable_tiles(
	origin: Vector2i,
	mp: int,
	ignore_occupancy: bool = false,
	ignore_passability: bool = false
) -> Array[Vector2i]:
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
		_on_tile_visited(current)

		for neighbor: Vector2i in _get_orthogonal_neighbors(current):
			if not is_in_bounds(neighbor):
				continue
			if not ignore_occupancy and has_occupant(neighbor):
				continue
			if not ignore_passability and not passable(neighbor):
				continue

			# Story 016 AC6: an unregistered-terrain cost sentinel must never
			# be folded into the cost sum — treat it as if passable()==false
			# for this neighbor, independent of whether ignore_passability
			# already filtered it (it does not when true, which is exactly
			# the case story-007's `C` set computation relies on; see
			# board.gd Story 016 doc comment on from_ascii() and the
			# story-016 design doc "決策三" for the full history of this gap).
			var move_cost: int = get_move_cost(neighbor)
			if not _is_move_cost_usable(move_cost):
				continue

			var candidate_cost: int = best_cost[current] + move_cost
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


# QA-only instrumentation seam (Story 002, TR-tactical-008/OQ-16 "bounded
# frontier expansion" characteristic) — a no-op in production, called exactly
# once per tile popped from reachable_tiles()'s frontier and marked visited.
# Overridable only by a test-only subclass (same pattern as _terrain_entry()
# above — see its doc comment for the precedent), which counts invocations so
# a test can assert the algorithm visits fewer tiles than the full board for
# a small mp, and more tiles as mp grows — proving early termination rather
# than "flood-fill the whole board, then filter afterward".
func _on_tile_visited(_pos: Vector2i) -> void:
	pass


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


# Returns true if move_cost (as returned by get_move_cost()) is safe to fold
# into reachable_tiles()'s running cost sum (Story 016, AC6). The production
# body IS the AC6 protection itself — not a pass-through to be deleted —
# rejecting MOVE_COST_UNKNOWN_TERRAIN exactly as if the neighbor had failed
# passable(). Overridable only by a test-only mutant subclass (same pattern
# as _terrain_entry() and _on_tile_visited() below/above — see their doc
# comments for the precedent): a sensitivity-proof test overrides this to
# always return true, reproducing — without editing this file — exactly
# what reachable_tiles() does if AC6's protection were removed, so the test
# can prove the regression it guards against actually turns the test red.
func _is_move_cost_usable(move_cost: int) -> bool:
	return move_cost != MOVE_COST_UNKNOWN_TERRAIN


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
