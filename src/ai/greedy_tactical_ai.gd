## Deterministic, intentionally simple tactical decision-maker shared by both
## factions — not an enemy-only AI. It exists so a battle can be played out
## end-to-end by code, in order to measure how many turns a level actually
## takes; that number is currently only estimated on paper.
##
## Decision policy is fixed and never tuned: prefer a candidate tile that can
## land a legal attack this turn, breaking ties by Manhattan distance to the
## nearest living enemy and then by lexicographic [code](y, x)[/code] tile
## order; among enemies attackable from the chosen tile, always strike the
## lowest-HP target, ties broken by lowest unit id. No randomness anywhere —
## this project forbids RNG in combat settlement
## ([code]rng_in_combat_settlement[/code] in
## [code].claude/docs/technical-preferences.md[/code]), and this decider is
## part of that settlement path.
##
## Read-only: [method decide] never mutates [param state]. Executing the
## returned move/attack is the caller's responsibility.
class_name GreedyTacticalAI
extends RefCounted


## Decides unit_id's action for this turn. Returns a [Dictionary] with two
## fixed keys: [code]"move_to"[/code] ([Vector2i], or [code]null[/code]
## meaning "stay put") and [code]"attack"[/code] ([int] target unit id, or
## [code]-1[/code] meaning "don't attack"). When [param can_move] is
## [code]false[/code], only the unit's current tile is ever considered; when
## [param can_attack] is [code]false[/code], [code]"attack"[/code] is always
## [code]-1[/code]. Returns [code]{"move_to": null, "attack": -1}[/code]
## immediately if the opposing faction has no living units.
static func decide(
	state: BattleState, unit_id: int, can_move: bool, can_attack: bool
) -> Dictionary:
	var unit: Unit = state.unit_by_id(unit_id)
	var enemies: Array[Unit] = state.units_of(_opposing_faction(unit.faction))
	if enemies.is_empty():
		return {"move_to": null, "attack": -1}

	var origin: Vector2i = state.position_of(unit_id)
	var candidates: Array[Vector2i] = [origin]
	if can_move:
		candidates.append_array(state.legal_moves(unit_id))

	var chosen_tile: Vector2i = candidates[0]
	var chosen_attackable: Array[Unit] = _attackable_from(state, unit, chosen_tile, enemies)
	var chosen_distance: int = _distance_to_nearest(chosen_tile, state, enemies)

	for i: int in range(1, candidates.size()):
		var tile: Vector2i = candidates[i]
		var attackable: Array[Unit] = _attackable_from(state, unit, tile, enemies)
		var distance: int = _distance_to_nearest(tile, state, enemies)
		if _is_better_tile(
			tile, not attackable.is_empty(), distance,
			chosen_tile, not chosen_attackable.is_empty(), chosen_distance
		):
			chosen_tile = tile
			chosen_attackable = attackable
			chosen_distance = distance

	var move_to: Variant = null
	if can_move and chosen_tile != origin:
		move_to = chosen_tile

	var attack_target: int = -1
	if can_attack:
		attack_target = _best_target(chosen_attackable)

	return {"move_to": move_to, "attack": attack_target}


## Returns the faction opposing faction. Only two factions exist, so this is
## a straight flip.
static func _opposing_faction(faction: Unit.Faction) -> Unit.Faction:
	if faction == Unit.Faction.PLAYER:
		return Unit.Faction.ENEMY
	return Unit.Faction.PLAYER


# Returns every member of enemies that unit could legally attack while
# standing at tile. Only terrain (Board.blocks_sight) is ever treated as
# sight-blocking — units never occlude, matching the project rule already
# enforced by BattleState.can_attack().
static func _attackable_from(
	state: BattleState, unit: Unit, tile: Vector2i, enemies: Array[Unit]
) -> Array[Unit]:
	var is_occluding: Callable = func(cell: Vector2i) -> bool:
		return state.board.blocks_sight(cell)
	var attackable: Array[Unit] = []
	for enemy: Unit in enemies:
		if CombatRules.is_attack_legal(
			tile, state.position_of(enemy.id), unit.min_range, unit.max_range, is_occluding
		):
			attackable.append(enemy)
	return attackable


# Among attackable, returns the lowest-HP unit's id, ties broken by lowest
# unit id. Returns -1 if attackable is empty.
static func _best_target(attackable: Array[Unit]) -> int:
	var best_id: int = -1
	var best_hp: int = 0
	for enemy: Unit in attackable:
		if best_id == -1 or enemy.hp < best_hp or (enemy.hp == best_hp and enemy.id < best_id):
			best_id = enemy.id
			best_hp = enemy.hp
	return best_id


# Smallest Manhattan distance from tile to any living enemy's current
# position (not just the attackable ones — used both to steer movement
# toward the fight and to break ties among tiles that can already attack).
static func _distance_to_nearest(tile: Vector2i, state: BattleState, enemies: Array[Unit]) -> int:
	var nearest: int = -1
	for enemy: Unit in enemies:
		var enemy_pos: Vector2i = state.position_of(enemy.id)
		var distance: int = absi(enemy_pos.x - tile.x) + absi(enemy_pos.y - tile.y)
		if nearest == -1 or distance < nearest:
			nearest = distance
	return nearest


# Returns true if candidate_tile should replace chosen_tile as the pick:
# attack-capable tiles always beat non-attack-capable ones; among tiles with
# the same attack-capability, the smaller Manhattan distance wins; any
# remaining tie is broken by (y, x) lexicographic order. The comparison is
# symmetric and never relies on iteration order, so the result never depends
# on how legal_moves() happens to enumerate tiles.
static func _is_better_tile(
	candidate_tile: Vector2i, candidate_can_attack: bool, candidate_distance: int,
	chosen_tile: Vector2i, chosen_can_attack: bool, chosen_distance: int
) -> bool:
	if candidate_can_attack != chosen_can_attack:
		return candidate_can_attack
	if candidate_distance != chosen_distance:
		return candidate_distance < chosen_distance
	if candidate_tile.y != chosen_tile.y:
		return candidate_tile.y < chosen_tile.y
	return candidate_tile.x < chosen_tile.x
