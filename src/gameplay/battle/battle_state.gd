## Integration layer tying [Board], [Unit], and [CombatRules] together into a
## single battle state: unit positions, movement, attack legality, damage
## resolution, and win/loss detection.
##
## Also holds this battle's [TurnOrder] instance
## ([code]src/gameplay/battle/turn_order.gd[/code]) once a driver
## ([code]BattleController[/code] or [code]BattleLoop[/code]) attaches it via
## [method attach_turn_order] — see that method's doc comment for why this
## class, rather than either driver, must be the object able to answer
## queries about all three pieces of battle state (board, units, turn order)
## as a whole (ADR-0001, 2026-09-09 revision, "為什麼計數器不能留在 Board").
## [TurnOrder] itself still owns every rule about whose turn it is and which
## flags are spent — this class only holds the reference. This class has no
## nodes, no RNG, and makes no turn-order decisions of its own.
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

# This battle's TurnOrder, set once by whichever driver (BattleController or
# BattleLoop) is constructed against this state — see attach_turn_order().
# null until a driver attaches one: create() deliberately does not construct
# a TurnOrder itself.
#
# The reason is call-site compatibility, not a duplication concern — verified
# 2026-09-09 via `grep -rn "TurnOrder.new(" src/`: production code builds
# exactly one TurnOrder (src/ui/battle/battle_screen.gd), and it is the call
# site that does it, not either driver — BattleController and BattleLoop only
# ever *receive* an already-built TurnOrder through their constructors, they
# never call TurnOrder.new() themselves. Every existing test file follows the
# same explicit-construct-then-pass shape, each choosing its own
# player_ids/enemy_ids arrays (not derived from create()'s roster parse, and
# not guaranteed to match it one-for-one across every test scenario) before
# handing the result to a driver constructor. Attaching after the fact —
# instead of having create() build the TurnOrder itself, or having the driver
# constructors stop accepting an order parameter — is what lets every one of
# those existing call sites keep compiling and behaving identically. In
# particular, tests/unit/gameplay/affinity/affinity_phi_provider_test.gd
# constructs its own TurnOrder this same way and is out of scope to modify in
# this change; a design that required touching it would not be viable here.
var _turn_order: TurnOrder = null


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


## Returns the [TurnOrder] attached to this battle, or [code]null[/code] if
## no driver has attached one yet — see [method attach_turn_order].
func turn_order() -> TurnOrder:
	return _turn_order


## Attaches [param order] as this battle's authoritative [TurnOrder],
## establishing [BattleState] as the single object able to answer queries
## about board, units, and turn order together (ADR-0001's 2026-09-09
## revision — see the "為什麼計數器不能留在 Board" section for the full
## reasoning). Called once, from [method BattleController._init] and
## [method BattleLoop._init], with the same [TurnOrder] instance each
## constructor was itself given — this method does not construct anything,
## it only records the reference.
##
## ⚠️ Overwrites any previously attached [TurnOrder] without warning. This
## class does not yet guard against two drivers attaching different
## instances to the same state; that guard belongs to the write-window
## mechanism ADR-0001 defines (`authoritative_write_in_progress` +
## `commit_authoritative_change()`), which is out of scope for this change —
## see the ADR's five hard obligations under Mechanism One.
func attach_turn_order(order: TurnOrder) -> void:
	_turn_order = order


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
##
## The damage number itself comes from [method _compute_attack_damage] —
## the same private helper [method preview_damage] calls — so a UI preview
## and the real settlement can never drift apart on ATK/DEF/phi: there is
## exactly one formula, not two that currently happen to agree.
func resolve_attack(attacker_id: int, target_id: int, phi: int) -> int:
	var dealt: int = _compute_attack_damage(attacker_id, target_id, phi)
	var target: Unit = unit_by_id(target_id)
	target.take_damage(dealt)
	if not target.is_alive():
		board.clear_occupant(position_of(target_id))
		_positions.erase(target_id)
	return dealt


## Returns the damage a hypothetical attack from attacker_id on target_id
## would deal for the given [param phi], WITHOUT resolving it — no HP
## change, no occupancy change, safe to call any number of times (e.g. once
## per frame while a cursor hovers a target). This is the query a
## damage-preview UI must call instead of recomputing
## [method CombatRules.damage] itself: it delegates to the exact same
## private helper [method resolve_attack] uses, so the previewed number is
## structurally guaranteed to match what resolving the attack would deal,
## not merely coincidentally equal to it today.
func preview_damage(attacker_id: int, target_id: int, phi: int) -> int:
	return _compute_attack_damage(attacker_id, target_id, phi)


# Shared by resolve_attack() and preview_damage(): computes the damage a
# hypothetical or actual attack would deal, applying the same enemy-phi-
# zeroing rule both paths must honor (phi only ever applies for a PLAYER
# attacker — see resolve_attack()'s own doc comment). Never mutates
# anything; the mutation itself (take_damage(), occupancy cleanup) is
# resolve_attack()'s own responsibility, not this helper's.
func _compute_attack_damage(attacker_id: int, target_id: int, phi: int) -> int:
	var attacker: Unit = unit_by_id(attacker_id)
	var target: Unit = unit_by_id(target_id)
	var effective_phi: int = phi
	if attacker.faction == Unit.Faction.ENEMY:
		effective_phi = 0
	return CombatRules.damage(attacker.effective_atk(), target.effective_def(), effective_phi)


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
