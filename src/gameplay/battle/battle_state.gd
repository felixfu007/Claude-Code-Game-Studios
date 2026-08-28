## Integration layer tying [Board], [Unit], and [CombatRules] together into a
## single battle state: unit positions, movement, attack legality, damage
## resolution, and win/loss detection.
##
## Turn order and per-unit action-flag bookkeeping are NOT owned here — see
## [code]TurnOrder[/code] ([code]src/gameplay/battle/turn_order.gd[/code]),
## owned by a different system. This class has no nodes, no RNG, and no
## knowledge of turns; it only tracks "where is everything, and what
## happens when things move or fight."
class_name BattleState
extends RefCounted

## Three-state battle result. Victory requires every ENEMY unit dead. Defeat
## triggers the moment any single PLAYER unit's HP reaches 0 — one lost
## protagonist ends the battle, not a full-party wipe.
enum Outcome { ONGOING, VICTORY, DEFEAT }

## The tactical grid this battle is played on. Occupancy on this board is
## kept in sync with [member _positions] at all times — every method that
## changes one updates the other in the same call.
var board: Board

# id -> Unit. One entry per unit in the battle (both factions), populated
# once in create() and never removed — dead units stay in this map so
# unit_by_id() and units_of() keep working (and correctly excluding them)
# after death.
var _units: Dictionary = {}

# id -> Vector2i, the unit's *current* position (never [member Unit.start_pos],
# which is left untouched as the original spawn value — this map is the
# thing that actually moves). Entries are removed when a unit dies,
# mirroring [member Board]'s occupancy map losing that tile's entry.
var _positions: Dictionary = {}


## Builds a [BattleState] from a terrain grid and a roster text blob: parses
## both, then places every unit on the board at its [member Unit.start_pos].
static func create(terrain_rows: PackedStringArray, roster_text: String) -> BattleState:
	var state: BattleState = BattleState.new()
	state.board = Board.from_ascii(terrain_rows)
	var roster: Array[Unit] = Unit.roster_from_text(roster_text)
	for unit: Unit in roster:
		state._units[unit.id] = unit
		state._positions[unit.id] = unit.start_pos
		state.board.set_occupant(unit.start_pos, unit.id)
	return state


## Returns the current position of the unit with the given id.
func position_of(id: int) -> Vector2i:
	return _positions[id]


## Returns the [Unit] with the given id, or [code]null[/code] if no such
## unit exists in this battle.
func unit_by_id(id: int) -> Unit:
	return _units.get(id, null)


## Returns the [Unit] occupying pos, or [code]null[/code] if the tile is
## empty.
func unit_at(pos: Vector2i) -> Unit:
	if not board.has_occupant(pos):
		return null
	return unit_by_id(board.get_occupant(pos))


## Returns every living unit belonging to faction. Dead units are excluded.
func units_of(faction: Unit.Faction) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit: Unit in _units.values():
		if unit.faction == faction and unit.is_alive():
			result.append(unit)
	return result


## Returns every tile the unit with the given id can move to this turn,
## given its current position and [member Unit.mp].
func legal_moves(id: int) -> Array[Vector2i]:
	var unit: Unit = unit_by_id(id)
	return board.reachable_tiles(position_of(id), unit.mp)


## Attempts to move the unit to dest. Returns [code]false[/code] and leaves
## every piece of state untouched if dest is not in [method legal_moves].
## On success, updates board occupancy and [member _positions] together in
## the same call so they never drift out of sync.
func move_unit(id: int, dest: Vector2i) -> bool:
	if not legal_moves(id).has(dest):
		return false
	var origin: Vector2i = position_of(id)
	board.clear_occupant(origin)
	board.set_occupant(dest, id)
	_positions[id] = dest
	return true


## Returns [code]true[/code] if attacker_id may legally attack target_id:
## the target must be alive and on the opposing faction, and the attack must
## satisfy [method CombatRules.is_attack_legal]. Only terrain
## ([method Board.blocks_sight]) is ever treated as sight-blocking here —
## units never occlude, dead or alive, friend or foe, regardless of where
## they stand between attacker and target. This is a project rule, not an
## incidental omission.
##
## The final legality step (range + line of sight) is delegated to
## [method is_attack_reachable], queried with attacker_id's and target_id's
## actual current positions. The alive check and faction check above are
## this method's own responsibility and are deliberately NOT duplicated in
## [method is_attack_reachable] — that method answers a narrower,
## occupant-agnostic question so it can also be asked about a hypothetical
## origin tile or an unoccupied cell, which this method's target_id
## parameter cannot express.
func can_attack(attacker_id: int, target_id: int) -> bool:
	var attacker: Unit = unit_by_id(attacker_id)
	var target: Unit = unit_by_id(target_id)
	if target == null or not target.is_alive():
		return false
	if target.faction == attacker.faction:
		return false
	return is_attack_reachable(attacker_id, position_of(attacker_id), position_of(target_id))


## Returns [code]true[/code] if attacker_id, hypothetically standing at
## [param from], could legally attack the cell [param to] — [method
## CombatRules.is_attack_legal] evaluated against attacker_id's own
## [member Unit.min_range]/[member Unit.max_range], with the same
## terrain-only occlusion callable [method can_attack] builds ([method
## Board.blocks_sight]).
##
## This is a pure predicate with no side effects. [param from] is allowed to
## be a tile attacker_id is not currently standing on — it need not equal
## [method position_of](attacker_id). It performs no faction check, no alive
## check, and does not care whether [param to] is occupied at all: those are
## the caller's business, not this method's. The answer is independent of
## unit occupancy, because only terrain ever occludes (see the note on
## [method can_attack] that units never occlude) — this is exactly what
## makes it safe to query from a hypothetical origin, since the check never
## consults who is standing where, only the two endpoints and the terrain
## between them.
func is_attack_reachable(attacker_id: int, from: Vector2i, to: Vector2i) -> bool:
	var attacker: Unit = unit_by_id(attacker_id)
	var is_occluding: Callable = func(cell: Vector2i) -> bool:
		return board.blocks_sight(cell)
	return CombatRules.is_attack_legal(
		from, to,
		attacker.min_range, attacker.max_range,
		is_occluding
	)


## Resolves an attack and returns the damage actually dealt. [param phi] is
## only ever honored for a PLAYER attacker — if attacker_id belongs to an
## ENEMY unit, phi is forced to 0 before it reaches [method CombatRules.damage],
## regardless of what the caller passed in. If the target's HP reaches 0, it
## is removed from the board and [member _positions] immediately, so its
## tile becomes passable and it stops being a legal target as of this same
## call — callers do not need a separate cleanup step.
func resolve_attack(attacker_id: int, target_id: int, phi: int) -> int:
	var attacker: Unit = unit_by_id(attacker_id)
	var target: Unit = unit_by_id(target_id)
	var effective_phi: int = phi
	if attacker.faction == Unit.Faction.ENEMY:
		effective_phi = 0
	var dealt: int = CombatRules.damage(attacker.atk, target.def, effective_phi)
	target.take_damage(dealt)
	if not target.is_alive():
		board.clear_occupant(position_of(target_id))
		_positions.erase(target_id)
	return dealt


## Returns the current battle [enum Outcome]. Defeat is checked before
## victory: if any PLAYER unit has died, the result is DEFEAT even if every
## ENEMY unit also happens to be dead at the same time.
func outcome() -> Outcome:
	for unit: Unit in _units.values():
		if unit.faction == Unit.Faction.PLAYER and not unit.is_alive():
			return Outcome.DEFEAT
	for unit: Unit in _units.values():
		if unit.faction == Unit.Faction.ENEMY and unit.is_alive():
			return Outcome.ONGOING
	return Outcome.VICTORY
