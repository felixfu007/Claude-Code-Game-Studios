## Drives a full battle from start to finish by wiring [TurnOrder] and
## [BattleState] together behind an injected decision-maker, one unit action
## at a time, until the battle resolves or a round cap is hit.
##
## Everything below this class only answers queries or applies a single
## action when asked ([TurnOrder] tracks whose turn it is and which flags
## are spent; [BattleState] tracks positions, legality, and damage). This is
## the first thing in the project that asks on its own — it owns no
## decision logic itself: [member _decide] is injected, so the actual AI
## (or a test stub) is fully swappable without touching this file.
##
## No nodes, no RNG — this class is pure [RefCounted] glue over two other
## pure [RefCounted] systems, consistent with the project-wide
## [code]rng_in_combat_settlement[/code] rule (combat resolution never rolls
## dice).
class_name BattleLoop
extends RefCounted

var _state: BattleState
var _order: TurnOrder

## Signature contract: [code]decide.call(state, unit_id, can_move,
## can_attack) -> Dictionary[/code], returning exactly two keys —
## [code]"move_to"[/code] ([Vector2i] or [code]null[/code]) and
## [code]"attack"[/code] (target unit id [int], or [code]-1[/code]).
var _decide: Callable


## Builds a loop over an already-constructed [param state] and
## [param order] (both assumed to describe the same roster), driven by
## [param decide]. See [member _decide] for the required callable
## signature.
func _init(state: BattleState, order: TurnOrder, decide: Callable) -> void:
	_state = state
	_order = order
	_decide = decide


## Runs the battle to completion: processes one unit action at a time,
## advancing faction phases and rounds as [TurnOrder] reports them empty,
## until [method BattleState.outcome] leaves [code]ONGOING[/code] or
## [param max_rounds] is reached first (safety valve — two AIs can in
## principle stalemate forever, and this is what stops the loop from
## hanging when they do).
##
## Returns a [Dictionary] with exactly four keys: [code]"outcome"[/code]
## ([enum BattleState.Outcome]), [code]"rounds"[/code] ([int], the number of
## rounds actually elapsed), [code]"aborted"[/code] ([bool], true only if
## the round cap was hit before the battle resolved), and [code]"log"[/code]
## ([Array][String], a human-readable step-by-step trace).
func run(max_rounds: int) -> Dictionary:
	var log: Array[String] = []

	while true:
		if _order.round_number() > max_rounds:
			return _build_result(_state.outcome(), log, true, max_rounds)

		var acting_ids: Array[int] = _order.units_with_flags_remaining()
		if acting_ids.is_empty():
			_order.advance_faction()
			continue

		for id: int in acting_ids:
			if _order.is_done(id):
				continue
			_process_unit(id, log)

			var outcome: BattleState.Outcome = _state.outcome()
			if outcome != BattleState.Outcome.ONGOING:
				return _build_result(outcome, log, false, _order.round_number())

	# Unreachable — the while(true) above only exits through a return above.
	return _build_result(_state.outcome(), log, false, _order.round_number())


# Consults _decide once for id and applies whatever it asks for: a move (if
# legal), then an attack (only ever resolved after confirming
# state.can_attack — resolve_attack() itself performs no legality check by
# design). If the target dies, it is immediately removed from _order —
# skipping this is the single easiest silent bug in this file: a dead unit
# left in TurnOrder gets its flags reset at the next advance_faction() and
# resurfaces in a later units_with_flags_remaining() call, and any query
# BattleState runs against its now-erased position (legal_moves(),
# can_attack()) quietly computes from Vector2i(0,0) instead of failing.
# If id neither moved nor attacked this call, its turn is explicitly ended
# so the outer loop cannot spin on it forever.
#
# 🔴 Both requests are gated on TurnOrder's own can_move/can_attack flags
# BEFORE being applied to _state — not just checked for the log line. This
# is load-bearing, not cosmetic: BattleState.move_unit() only asks "is dest
# reachable right now", it has no idea a move flag was already spent, so a
# decide that ignores the can_move/can_attack it was handed and keeps
# requesting the same still-legal action would otherwise keep succeeding
# forever. That would set did_something = true every single call, which
# means end_unit_turn() never fires, the unit never leaves
# units_with_flags_remaining(), round_number() never advances, and the
# max_rounds safety valve in run() — which is only checked at round
# boundaries — never gets a chance to trip. Gating here turns an ignored
# flag into a no-op instead of a repeatable action, so the unit is
# guaranteed to hit did_something == false within two calls (one per flag)
# and end its turn.
func _process_unit(id: int, log: Array[String]) -> void:
	var actor: Unit = _state.unit_by_id(id)
	var can_move_flag: bool = _order.can_move(id)
	var can_attack_flag: bool = _order.can_attack(id)
	var decision: Dictionary = _decide.call(_state, id, can_move_flag, can_attack_flag)

	var did_something: bool = false

	var move_to: Variant = decision.get("move_to")
	if move_to != null and can_move_flag:
		if _state.move_unit(id, move_to):
			_order.use_move(id)
			did_something = true
			log.append(
				"R%d %s: %s moves to %s"
				% [_order.round_number(), _side_name(), actor.code_name, move_to]
			)

	var attack_target: int = int(decision.get("attack", -1))
	if attack_target != -1 and can_attack_flag:
		if _state.can_attack(id, attack_target):
			var dealt: int = _state.resolve_attack(id, attack_target, 0)
			_order.use_attack(id)
			did_something = true
			var target: Unit = _state.unit_by_id(attack_target)
			log.append(
				"R%d %s: %s attacks %s for %d damage"
				% [_order.round_number(), _side_name(), actor.code_name, target.code_name, dealt]
			)
			if not target.is_alive():
				log.append("%s is defeated" % target.code_name)
				_order.remove_unit(attack_target)

	if not did_something:
		_order.end_unit_turn(id)
		log.append(
			"R%d %s: %s ends turn without acting"
			% [_order.round_number(), _side_name(), actor.code_name]
		)


# Human-readable name for the faction currently acting, for log lines only.
func _side_name() -> String:
	return TurnOrder.Side.keys()[_order.current_faction()]


func _build_result(
	outcome: BattleState.Outcome, log: Array[String], aborted: bool, rounds: int
) -> Dictionary:
	return {
		"outcome": outcome,
		"rounds": rounds,
		"aborted": aborted,
		"log": log,
	}
