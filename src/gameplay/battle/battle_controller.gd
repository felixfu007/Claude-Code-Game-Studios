## Player-interaction state machine for the tactical layer: translates "the
## player clicked something" into legal operations against [BattleState] and
## [TurnOrder]. This is the only class in the project that exists purely to
## be called from a presentation layer — it owns no nodes, no [Input] or
## [InputEvent] handling, no RNG, and preloads no scenes, so it can be
## constructed with a bare [code]new()[/code] and driven entirely from a
## test (or, later, from a screen-layer script that owns the actual clicking).
##
## [method click_tile] is the single entry point a screen layer needs for
## board interaction — one click, one decision, no ambiguity about which of
## several methods to call for a given click. Priority order, applied in
## this fixed sequence:
## [br]
## 1. The clicked tile holds a unit of the currently active faction that can
##    still act this phase -> select it (switching away from any previous
##    selection).
## [br]
## 2. A unit is already selected and the clicked tile is one of its
##    [method attack_targets] -> resolve the attack.
## [br]
## 3. A unit is already selected and the clicked tile is one of its
##    [method move_targets] -> resolve the move.
## [br]
## 4. Anything else: if a unit was selected, clear the selection
##    ([code]&"deselected"[/code]); if nothing was selected, nothing happens
##    ([code]&"none"[/code]). This is a deliberate design choice, not an
##    arbitrary one: it is what keeps every value in the 5-value action
##    vocabulary reachable through this single entry point (a "clicked
##    somewhere irrelevant" bucket that only ever collapses to "none" would
##    make [code]&"deselected"[/code] dead code across the whole class, since
##    every other branch above already resolves to a different action), and
##    it matches the click-away-to-cancel convention already implied by
##    exposing an explicit [method deselect] command.
##
## Movement and attack are two independent per-unit flags, exactly as
## [TurnOrder] defines them — this class does not collapse or reorder that:
## moving never forces an attack, attacking never forces a move, and either
## can be skipped or deferred to later in the same faction phase. Reset is
## entirely [TurnOrder]'s responsibility, tied to
## [method TurnOrder.advance_faction] — this class never resets a flag
## itself.
class_name BattleController
extends RefCounted

## The three states this state machine can be in. There is no "no phase" —
## a fresh controller always starts in PLAYER_INPUT, matching [TurnOrder]
## always starting on the player faction.
enum Phase { PLAYER_INPUT, ENEMY_ACTING, FINISHED }

## Emitted whenever [method select_unit] or [method click_tile] successfully
## selects a unit (including re-selecting the same id).
signal unit_selected(id: int)

## Emitted whenever the current selection is cleared, whether by
## [method deselect], the residual branch of [method click_tile],
## [method end_unit_turn] ending the selected unit's own turn, or
## [method end_faction_phase].
signal selection_cleared()

## Emitted after a move resolved by [method click_tile] or by the enemy AI
## inside [method run_enemy_phase] actually changes a unit's position.
signal unit_moved(id: int, from: Vector2i, to: Vector2i)

## Emitted after any attack is resolved — by [method click_tile] or by the
## enemy AI inside [method run_enemy_phase].
signal attack_resolved(attacker_id: int, target_id: int, damage: int, target_died: bool)

## Emitted every time [method phase] transitions to a new value.
signal phase_changed(new_phase: Phase)

## Emitted exactly once, the moment [method BattleState.outcome] first
## leaves ONGOING. After this fires, [method phase] is permanently FINISHED
## and every command method becomes a no-op.
signal battle_ended(outcome: BattleState.Outcome)

var _state: BattleState
var _order: TurnOrder

## Injected affinity-bonus (Φ) provider — signature
## [code]func(attacker_id: int, target_id: int) -> int[/code]. Only ever
## consulted for a PLAYER-faction attacker: this matches the project
## decision that Φ never applies to enemy attacks, which
## [method BattleState.resolve_attack] already enforces independently by
## forcing phi to 0 whenever the attacker is an ENEMY unit. Re-checked with
## [method Callable.is_valid] immediately before every attack it could
## apply to — never cached — so an unset or freed provider is always
## treated as a constant 0, never as a stale value from before it broke.
## The affinity system itself does not exist yet
## ([code]production/session-state/active.md[/code] tracks this as a known
## gap), so in practice this is currently always 0; this parameter is the
## integration point for when it stops being 0.
var _phi_provider: Callable

## Injected enemy-turn decision-maker — same signature contract as
## [member BattleLoop._decide]: [code]func(state: BattleState, unit_id: int,
## can_move: bool, can_attack: bool) -> Dictionary[/code], returning exactly
## [code]"move_to"[/code] ([Vector2i] or [code]null[/code]) and
## [code]"attack"[/code] ([int] target id, or [code]-1[/code]). Re-checked
## with [method Callable.is_valid] on every call inside
## [method run_enemy_phase] — never cached — and falls back to
## [method GreedyTacticalAI.decide] whenever unset or invalid, which is the
## default behavior an unmodified constructor call gets. This exists for two
## reasons: it lets tests inject a decision-maker that deliberately ignores
## [param can_move]/[param can_attack] to prove the flag-gating in
## [method _process_enemy_unit] actually terminates the phase instead of
## spinning forever (the exact failure [code]BattleLoop[/code] hit and fixed
## — see its own comment on why an ungated request can spin forever), and it
## is the swap point for a future, less predictable enemy AI without
## touching this file's control flow.
var _decide: Callable

var _phase: Phase = Phase.PLAYER_INPUT
var _selected_unit_id: int = -1


## Builds a controller over an already-constructed [param state] and
## [param order] (both assumed to describe the same roster, and [param order]
## assumed fresh — current faction PLAYER, round 1). [param phi_provider]
## defaults to an unset [Callable]; see [member _phi_provider].
## [param decide] defaults to an unset [Callable], which means
## [method GreedyTacticalAI.decide] drives every enemy unit; see
## [member _decide]. If [param state] is already resolved (not ONGOING) at
## construction time, [method phase] is FINISHED immediately — but
## [signal battle_ended] does NOT reach any listener for that case, since no
## caller has had the chance to connect to it yet; a caller that cares must
## check [method outcome] right after construction instead of relying on
## the signal.
func _init(
	state: BattleState,
	order: TurnOrder,
	phi_provider: Callable = Callable(),
	decide: Callable = Callable()
) -> void:
	_state = state
	_order = order
	_phi_provider = phi_provider
	_decide = decide
	_check_outcome_and_finish()


## Returns the current interaction phase.
func phase() -> Phase:
	return _phase


## Returns the current round number, delegated to [method TurnOrder.round_number].
func round_number() -> int:
	return _order.round_number()


## Returns the currently selected unit's id, or -1 if nothing is selected.
func selected_unit() -> int:
	return _selected_unit_id


## Returns the ids of every unit in the currently active faction that can
## still act this phase, ascending by id. Always empty outside PLAYER_INPUT.
func selectable_units() -> Array[int]:
	var result: Array[int] = []
	if _phase != Phase.PLAYER_INPUT:
		return result
	var faction: Unit.Faction = _current_faction_as_unit_faction()
	for unit: Unit in _state.units_of(faction):
		if not _order.is_done(unit.id):
			result.append(unit.id)
	result.sort()
	return result


## Returns the legal move tiles for the currently selected unit, ordered
## ascending by (y, x). Empty if nothing is selected, the selection cannot
## move this phase, or the controller is outside PLAYER_INPUT. Always a
## freshly built array — never a reference into any internal container.
func move_targets() -> Array[Vector2i]:
	return _move_targets_for(_selected_unit_id)


## Returns the tiles occupied by every enemy the currently selected unit can
## legally attack, ordered ascending by (y, x). Empty if nothing is
## selected, the selection cannot attack this phase, or the controller is
## outside PLAYER_INPUT. Always a freshly built array — never a reference
## into any internal container.
func attack_targets() -> Array[Vector2i]:
	return _attack_targets_for(_selected_unit_id)


## Returns every in-bounds board cell the currently selected unit could
## legally attack this turn, counting both "attack from where I stand" and
## "move first, then attack" — the union, over the unit's current tile plus
## every tile in [method move_targets], of the cells legally attackable from
## that tile. Ordered ascending by (y, x). Empty if nothing is selected, the
## selection cannot attack this phase, or the controller is outside
## PLAYER_INPUT — the same gating [method attack_targets] applies (a unit
## that already attacked threatens nothing further this turn). Always a
## freshly built array — never a reference into any internal container.
##
## This is a reach envelope, not a per-target legality list: enemy-occupied
## and ally-occupied cells are both included when legally reachable from
## some origin. The selected unit's own current tile is deliberately
## excluded from the result even though it may otherwise satisfy
## range/line-of-sight from some other origin tile — a unit can never
## attack the tile it is standing on, and drawing it as attackable would
## make the display say "you can attack yourself"; this is a deliberate,
## documented exclusion, not an oversight. [method attack_targets] remains
## the separate "which enemies can I actually hit right now" query — the
## two answer different questions and both stay.
func threat_targets() -> Array[Vector2i]:
	return _threat_targets_for(_selected_unit_id)


## Returns the current battle outcome, delegated to [method BattleState.outcome].
func outcome() -> BattleState.Outcome:
	return _state.outcome()


## Attempts to select [param id]. Returns [code]false[/code] and changes no
## state if [param id] does not exist, is dead, belongs to a faction other
## than the one currently active, is already done for this phase, or the
## controller is outside PLAYER_INPUT.
func select_unit(id: int) -> bool:
	if _phase != Phase.PLAYER_INPUT:
		return false
	return _select_unit_internal(id)


## Clears the current selection. No-op (does not emit) if nothing was
## selected.
func deselect() -> void:
	if _selected_unit_id == -1:
		return
	_clear_selection_internal()


## Single entry point for board clicks — see the class-level doc comment for
## the full priority order this method applies. Returns a [Dictionary] with
## at least an [code]"action"[/code] key ([StringName], one of
## [code]&"selected"[/code], [code]&"deselected"[/code], [code]&"moved"[/code],
## [code]&"attacked"[/code], [code]&"none"[/code]). Outside PLAYER_INPUT,
## always returns [code]{"action": &"none"}[/code] and changes no state.
func click_tile(pos: Vector2i) -> Dictionary:
	if _phase != Phase.PLAYER_INPUT:
		return {"action": &"none"}

	var occupant: Unit = _state.unit_at(pos)
	if occupant != null and occupant.faction == _current_faction_as_unit_faction():
		if _select_unit_internal(occupant.id):
			return {"action": &"selected", "unit_id": occupant.id}

	if _selected_unit_id != -1:
		if occupant != null and _attack_targets_for(_selected_unit_id).has(pos):
			return _apply_attack(_selected_unit_id, occupant.id)
		if _move_targets_for(_selected_unit_id).has(pos):
			return _apply_move(_selected_unit_id, pos)
		_clear_selection_internal()
		return {"action": &"deselected"}

	return {"action": &"none"}


## Actively ends [param id]'s turn via [method TurnOrder.end_unit_turn].
## Returns [code]false[/code] and changes no state if that call would fail
## (wrong faction, already done, removed) or the controller is outside
## PLAYER_INPUT. Clears the selection if [param id] was selected.
func end_unit_turn(id: int) -> bool:
	if _phase != Phase.PLAYER_INPUT:
		return false
	if not _order.end_unit_turn(id):
		return false
	if _selected_unit_id == id:
		_clear_selection_internal()
	return true


## Ends the player faction phase and advances to ENEMY_ACTING: clears any
## selection, then calls [method TurnOrder.advance_faction] (resetting every
## player unit's flags for the *next* player phase, per [TurnOrder]'s own
## reset-on-boundary rule) and flips [method current_faction] over to
## ENEMY. No-op outside PLAYER_INPUT.
func end_faction_phase() -> void:
	if _phase != Phase.PLAYER_INPUT:
		return
	if _selected_unit_id != -1:
		_clear_selection_internal()
	_order.advance_faction()
	_set_phase(Phase.ENEMY_ACTING)


## Drives the entire enemy faction phase with [member _decide] (defaulting
## to [GreedyTacticalAI] when unset — see [member _decide]), one unit action
## at a time, exactly as [BattleLoop] drives a full battle — except scoped
## to a single faction pass, not spanning rounds, and wired into this
## controller's signals and [enum Phase] instead of returning a final result
## Dictionary. No-op (returns an empty array) unless [method phase] is
## already ENEMY_ACTING (i.e. [method end_faction_phase] was called first).
## Stops immediately and transitions to FINISHED if the battle resolves
## mid-phase; otherwise, once every enemy unit has no flags left, calls
## [method TurnOrder.advance_faction] again (rolling enemy flags over and
## handing the round back to the player, incrementing
## [method TurnOrder.round_number]) and returns to PLAYER_INPUT. Returns a
## human-readable log, one line per action taken.
func run_enemy_phase() -> Array[String]:
	var log: Array[String] = []
	if _phase != Phase.ENEMY_ACTING:
		return log

	while true:
		var acting_ids: Array[int] = _order.units_with_flags_remaining()
		if acting_ids.is_empty():
			break
		for id: int in acting_ids:
			if _order.is_done(id):
				continue
			_process_enemy_unit(id, log)
			if _phase == Phase.FINISHED:
				return log

	_order.advance_faction()
	_set_phase(Phase.PLAYER_INPUT)
	return log


# Returns the Unit.Faction matching TurnOrder's currently active Side.
func _current_faction_as_unit_faction() -> Unit.Faction:
	if _order.current_faction() == TurnOrder.Side.PLAYER:
		return Unit.Faction.PLAYER
	return Unit.Faction.ENEMY


# Only two factions exist, so this is a straight flip — mirrors
# GreedyTacticalAI._opposing_faction().
static func _opposing_faction(faction: Unit.Faction) -> Unit.Faction:
	if faction == Unit.Faction.PLAYER:
		return Unit.Faction.ENEMY
	return Unit.Faction.PLAYER


# Shared selection logic for select_unit() and click_tile() — neither public
# method calls the other; both call this private helper instead, so no
# public entry point ever invokes another public entry point. Rejects for
# exactly the reasons documented on select_unit(); phase is NOT checked here
# since callers apply that guard themselves before calling in.
func _select_unit_internal(id: int) -> bool:
	var unit: Unit = _state.unit_by_id(id)
	if unit == null:
		return false
	if not unit.is_alive():
		return false
	if unit.faction != _current_faction_as_unit_faction():
		return false
	if _order.is_done(id):
		return false
	_selected_unit_id = id
	unit_selected.emit(id)
	return true


# Shared deselection logic for deselect(), click_tile()'s residual branch,
# end_unit_turn(), and end_faction_phase() — always leaves _selected_unit_id
# at -1 and emits selection_cleared exactly once.
func _clear_selection_internal() -> void:
	_selected_unit_id = -1
	selection_cleared.emit()


# Shared move-target computation for move_targets() and click_tile(); takes
# unit_id explicitly rather than reading _selected_unit_id so it can be
# reused if a caller ever needs a different unit's targets. Returns a fresh
# Array[Vector2i] built from BattleState.legal_moves() (itself already a
# fresh array per call), sorted ascending by (y, x) so the result never
# depends on Board's internal Dictionary iteration order.
func _move_targets_for(unit_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _phase != Phase.PLAYER_INPUT or unit_id == -1:
		return result
	if not _order.can_move(unit_id):
		return result
	result = _state.legal_moves(unit_id)
	result.sort_custom(_tile_less)
	return result


# Shared attack-target computation for attack_targets() and click_tile().
# Same "fresh array, explicit sort, never depend on Dictionary order" logic
# as _move_targets_for().
func _attack_targets_for(unit_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _phase != Phase.PLAYER_INPUT or unit_id == -1:
		return result
	if not _order.can_attack(unit_id):
		return result
	var attacker: Unit = _state.unit_by_id(unit_id)
	var opposing: Unit.Faction = _opposing_faction(attacker.faction)
	for enemy: Unit in _state.units_of(opposing):
		if _state.can_attack(unit_id, enemy.id):
			result.append(_state.position_of(enemy.id))
	result.sort_custom(_tile_less)
	return result


# Shared threat-cell computation for threat_targets(). Same gating as
# _attack_targets_for() (phase, selection, TurnOrder.can_attack()) — a unit
# that has already attacked threatens nothing further this turn even if it
# still has movement left. The origin set is the unit's current tile plus
# every tile in _move_targets_for(unit_id); _move_targets_for() already
# returns [] when TurnOrder.can_move() is false, which is correct here too
# — a unit that already moved can only threaten from where it stands.
# Board.reachable_tiles() never includes the origin tile itself, which is
# why the current tile has to be added to the origin set explicitly. Every
# in-bounds cell is tried as a candidate against every origin via
# BattleState.is_attack_reachable() (pure geometry/LoS, no occupancy or
# faction check), and the unit's own current tile is excluded from the
# result regardless of which origin would have "reached" it — see
# threat_targets()'s doc comment for why. Deduplicated via a Dictionary
# used purely as a set; the final array is still explicitly sorted, never
# relying on Dictionary iteration order.
func _threat_targets_for(unit_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _phase != Phase.PLAYER_INPUT or unit_id == -1:
		return result
	if not _order.can_attack(unit_id):
		return result

	var current_pos: Vector2i = _state.position_of(unit_id)
	var origins: Array[Vector2i] = _move_targets_for(unit_id)
	origins.append(current_pos)

	var threatened: Dictionary = {}
	for origin: Vector2i in origins:
		for y: int in range(Board.BOARD_HEIGHT):
			for x: int in range(Board.BOARD_WIDTH):
				var cell: Vector2i = Vector2i(x, y)
				if cell == current_pos:
					continue
				if _state.is_attack_reachable(unit_id, origin, cell):
					threatened[cell] = true

	for cell: Vector2i in threatened:
		result.append(cell)
	result.sort_custom(_tile_less)
	return result


# Ascending (y, x) comparator shared by every sorted Array[Vector2i] this
# class returns.
static func _tile_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


# Resolves a player-initiated attack for click_tile(). Re-checks both
# TurnOrder.can_attack() and BattleState.can_attack() immediately before
# resolving, even though callers only reach this via _attack_targets_for()
# (which already filtered on both) — defense in depth, matching the same
# "always ask right before settling" discipline BattleLoop already applies,
# per the project rule that resolve_attack() performs no legality check of
# its own by design.
func _apply_attack(attacker_id: int, target_id: int) -> Dictionary:
	if not _order.can_attack(attacker_id) or not _state.can_attack(attacker_id, target_id):
		return {"action": &"none"}

	var phi: int = _compute_phi(attacker_id, target_id)
	var damage: int = _state.resolve_attack(attacker_id, target_id, phi)
	_order.use_attack(attacker_id)
	var target: Unit = _state.unit_by_id(target_id)
	var target_died: bool = not target.is_alive()
	if target_died:
		_order.remove_unit(target_id)
	attack_resolved.emit(attacker_id, target_id, damage, target_died)
	_check_outcome_and_finish()
	return {
		"action": &"attacked",
		"damage": damage,
		"target_id": target_id,
		"target_died": target_died,
	}


# Resolves a player-initiated move for click_tile(). Re-checks
# TurnOrder.can_move() immediately before applying, same defense-in-depth
# reasoning as _apply_attack().
func _apply_move(unit_id: int, dest: Vector2i) -> Dictionary:
	if not _order.can_move(unit_id):
		return {"action": &"none"}
	var origin: Vector2i = _state.position_of(unit_id)
	if not _state.move_unit(unit_id, dest):
		return {"action": &"none"}
	_order.use_move(unit_id)
	unit_moved.emit(unit_id, origin, dest)
	return {"action": &"moved", "unit_id": unit_id, "from": origin, "to": dest}


# Drives one enemy unit's action inside run_enemy_phase(), mirroring
# BattleLoop._process_unit(): consults _decide_for() once (the injected
# _decide, or GreedyTacticalAI as its fallback), gates both the move and the
# attack it asks for on TurnOrder's own flags BEFORE applying them to
# BattleState (load-bearing, not cosmetic — see BattleLoop's own comment on
# why an ungated request can spin forever), removes the target from
# TurnOrder the instant it dies, and ends the unit's turn outright if it
# did nothing this call so the outer while-loop in run_enemy_phase() cannot
# spin on it. Phi is always the literal 0 here, never _compute_phi() —
# BattleState.resolve_attack() already forces phi to 0 for an ENEMY
# attacker regardless, and the project decision is that Φ never applies to
# enemy attacks in the first place, so there is nothing for the provider to
# contribute on this path.
func _process_enemy_unit(id: int, log: Array[String]) -> void:
	var actor: Unit = _state.unit_by_id(id)
	var can_move_flag: bool = _order.can_move(id)
	var can_attack_flag: bool = _order.can_attack(id)
	var decision: Dictionary = _decide_for(id, can_move_flag, can_attack_flag)

	var did_something: bool = false

	var move_to: Variant = decision.get("move_to")
	if move_to != null and can_move_flag:
		var origin: Vector2i = _state.position_of(id)
		if _state.move_unit(id, move_to):
			_order.use_move(id)
			did_something = true
			unit_moved.emit(id, origin, move_to)
			log.append(
				"R%d ENEMY: %s moves to %s" % [_order.round_number(), actor.code_name, move_to]
			)

	var attack_target: int = int(decision.get("attack", -1))
	if attack_target != -1 and can_attack_flag:
		if _order.can_attack(id) and _state.can_attack(id, attack_target):
			var dealt: int = _state.resolve_attack(id, attack_target, 0)
			_order.use_attack(id)
			did_something = true
			var target: Unit = _state.unit_by_id(attack_target)
			var target_died: bool = not target.is_alive()
			attack_resolved.emit(id, attack_target, dealt, target_died)
			log.append(
				"R%d ENEMY: %s attacks %s for %d damage"
				% [_order.round_number(), actor.code_name, target.code_name, dealt]
			)
			if target_died:
				log.append("%s is defeated" % target.code_name)
				_order.remove_unit(attack_target)
			_check_outcome_and_finish()

	if not did_something:
		_order.end_unit_turn(id)
		log.append(
			"R%d ENEMY: %s ends turn without acting" % [_order.round_number(), actor.code_name]
		)


# Consults _phi_provider for a player-initiated attack. Checked with
# is_valid() on every single call — never cached — so a provider that goes
# invalid between two attacks is caught on the very next attack, not just
# at construction time.
func _compute_phi(attacker_id: int, target_id: int) -> int:
	if not _phi_provider.is_valid():
		return 0
	return int(_phi_provider.call(attacker_id, target_id))


# Resolves the enemy-turn decision for one unit: the injected _decide if
# still valid, else GreedyTacticalAI.decide(). Checked with is_valid() on
# every single call, exactly like _compute_phi() — never cached — so this
# never keeps calling a decision-maker that has gone invalid mid-phase.
func _decide_for(unit_id: int, can_move: bool, can_attack: bool) -> Dictionary:
	if _decide.is_valid():
		return _decide.call(_state, unit_id, can_move, can_attack)
	return GreedyTacticalAI.decide(_state, unit_id, can_move, can_attack)


# Shared by _apply_attack() and _process_enemy_unit(): if the battle just
# resolved, transitions to FINISHED and emits battle_ended exactly once.
# No-op if already FINISHED or the battle is still ONGOING.
func _check_outcome_and_finish() -> void:
	if _phase == Phase.FINISHED:
		return
	var result: BattleState.Outcome = _state.outcome()
	if result == BattleState.Outcome.ONGOING:
		return
	_set_phase(Phase.FINISHED)
	battle_ended.emit(result)


# Central phase setter — every _phase assignment in this file goes through
# here except the field's own default, so phase_changed always fires
# exactly once per real transition and never fires for a no-op "change" to
# the same value.
func _set_phase(new_phase: Phase) -> void:
	if new_phase == _phase:
		return
	_phase = new_phase
	phase_changed.emit(_phase)
