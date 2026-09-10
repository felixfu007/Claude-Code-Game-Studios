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

## story-007-forced-discard-gate.md: optional forced-discard resolver for a
## battle with no human player. Signature contract:
## [code]discard_policy.call(deck: CardDeck) -> Card[/code], returning the
## exact [Card] instance (from [method CardDeck.hand]) this run should
## discard. Unset ([code]Callable()[/code], the default) means "no policy" —
## see [method run]'s own comment for what happens then. See
## [member _resolve_forced_discard] for how an invalid [Callable], a
## [code]null[/code] return, or a card [method CardDeck.discard_card]
## rejects are all treated identically (as "still unresolved").
var _discard_policy: Callable


## Builds a loop over an already-constructed [param state] and
## [param order] (both assumed to describe the same roster), driven by
## [param decide]. See [member _decide] for the required callable
## signature.
##
## [param card_deck] defaults to [code]null[/code] —
## story-006-battle-loop-wiring.md's hard requirement that card play be
## entirely optional per battle (AC-W6). When supplied, it is attached to
## [param state] via [method BattleState.attach_card_deck] and dealt its
## opening hand via [method BattleState.deal_opening_hand] — see that
## method's own doc comment for why round 1 gets exactly the opening hand
## and never one extra card drawn on top of it.
##
## [param discard_policy] (story-007-forced-discard-gate.md) defaults to an
## unset [Callable] — see [member _discard_policy] for its signature. This
## class has no human player to ask when a forced discard becomes owed, so
## [method run] consults this policy the instant one does; if it is unset,
## invalid, or its answer is rejected, [method run] aborts the entire battle
## rather than choosing a card itself. 🔴 This class must never pick a card
## on its own initiative: [BattleLoop] is this project's balance-measurement
## harness, and a discard choice nobody decided on would silently become
## part of every measurement taken with it, exactly the kind of
## undocumented, un-owned rule [code]procedural_terrain_generation[/code]'s
## sibling project rules warn against for combat-adjacent randomness — the
## card drawn is allowed to be random (GDD Core Rules 三), but which one
## gets discarded is a decision, not a roll, and this class does not make
## decisions.
func _init(
	state: BattleState,
	order: TurnOrder,
	decide: Callable,
	card_deck: CardDeck = null,
	discard_policy: Callable = Callable()
) -> void:
	_state = state
	_order = order
	_state.attach_turn_order(order)
	_state.attach_card_deck(card_deck)
	_state.deal_opening_hand()
	# story-002-modifier-lifecycle.md: a fresh TurnOrder starts on the PLAYER
	# side without run() ever having called advance_faction() yet — round 1's
	# player phase does not go through the advance_faction() branch inside
	# run() below, so without this call it would be the one player-turn-start
	# event this class never ticks modifiers for. No modifier can exist yet
	# at construction time in current gameplay, so this is a no-op today —
	# see BattleController._init()'s matching comment for the same reasoning,
	# mirrored here because these two classes are the two independent battle
	# drivers this story's hook must cover identically.
	_state.tick_all_modifiers()
	_decide = decide
	_discard_policy = discard_policy


## Runs the battle to completion: processes one unit action at a time,
## advancing faction phases and rounds as [TurnOrder] reports them empty,
## until [method BattleState.outcome] leaves [code]ONGOING[/code] or
## [param max_rounds] is reached first (safety valve — two AIs can in
## principle stalemate forever, and this is what stops the loop from
## hanging when they do), or a forced discard cannot be resolved (story-007-
## forced-discard-gate.md — see the loop body below).
##
## Returns a [Dictionary] with exactly five keys: [code]"outcome"[/code]
## ([enum BattleState.Outcome]), [code]"rounds"[/code] ([int], the number of
## rounds actually elapsed), [code]"aborted"[/code] ([bool], true if the
## round cap was hit OR a forced discard could not be resolved before the
## battle resolved), [code]"abort_reason"[/code] ([StringName],
## [code]&""[/code] unless [code]aborted[/code] is true, in which case one
## of [code]&"max_rounds_reached"[/code] or
## [code]&"forced_discard_unresolved"[/code]), and [code]"log"[/code]
## ([Array][String], a human-readable step-by-step trace).
func run(max_rounds: int) -> Dictionary:
	var log: Array[String] = []

	while true:
		if _order.round_number() > max_rounds:
			return _build_result(_state.outcome(), log, true, max_rounds, &"max_rounds_reached")

		var acting_ids: Array[int] = _order.units_with_flags_remaining()
		if acting_ids.is_empty():
			_order.advance_faction()
			# story-002-modifier-lifecycle.md: this branch fires for BOTH
			# faction transitions (PLAYER -> ENEMY and ENEMY -> PLAYER) — the
			# tick only ever belongs to the latter, since GDD Formula 二's
			# decrement is a once-per-round, player-turn-start rule, not a
			# per-faction-boundary one. Gating on current_faction() here
			# (rather than ticking unconditionally) is what keeps a
			# PLAYER -> ENEMY boundary from double-counting a round's
			# decrement.
			#
			# story-006-battle-loop-wiring.md: this is also the per-turn
			# card-draw point — BattleState.begin_player_turn() wraps
			# tick_all_modifiers() AND (if a CardDeck is attached)
			# CardDeck.draw_for_turn(), tick always before draw, for the
			# same reason begin_player_turn()'s own doc comment gives.
			#
			# 🔴 story-007-forced-discard-gate.md: this class has no human
			# player, so nothing else here blocks progress the way
			# BattleController's four gated commands do for a human-driven
			# battle (see BattleState.begin_player_turn()'s own doc comment
			# on that split responsibility). The instant begin_player_turn()
			# leaves a discard pending, this loop must resolve it via
			# _discard_policy or abort outright — it must NEVER fall through
			# to `continue` and let another unit act while a discard is
			# owed, because the next ENEMY -> PLAYER transition would call
			# begin_player_turn() -> CardDeck.draw_for_turn() a second time
			# with the first discard still unresolved, which is that
			# method's own documented precondition violation (its assert
			# would fire). Checked every single time this branch runs, not
			# only on the very first — a battle that resolves a discard and
			# later fills its hand again a second time must be caught here
			# again, not assumed already handled.
			if _order.current_faction() == TurnOrder.Side.PLAYER:
				_state.begin_player_turn()
				if _state.has_pending_discard():
					if not _resolve_forced_discard():
						return _build_result(
							_state.outcome(), log, true, _order.round_number(),
							&"forced_discard_unresolved"
						)
			continue

		for id: int in acting_ids:
			if _order.is_done(id):
				continue
			_process_unit(id, log)

			var outcome: BattleState.Outcome = _state.outcome()
			if outcome != BattleState.Outcome.ONGOING:
				# AC-11a (story-002-modifier-lifecycle.md): see
				# BattleController._check_outcome_and_finish()'s matching
				# comment — cleared before the result is handed back so no
				# caller can observe a modifier that should not survive past
				# this battle.
				_state.clear_all_modifiers()
				# AC-W4 (story-006-battle-loop-wiring.md): every card still
				# in hand or the used pile returns to the pool at the same
				# battle-end moment, if a CardDeck is attached — no-op
				# otherwise (AC-W6).
				_state.return_cards_to_pool()
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


# story-007-forced-discard-gate.md: resolves a forced discard using the
# injected _discard_policy (see its own doc comment for the signature and
# the reasoning against this class ever picking a card itself). Returns
# true only if a card was actually discarded; false for every other case —
# no policy supplied, an invalid Callable, a null return, or a card
# CardDeck.discard_card() rejects because it is not actually in hand — so
# the caller (run()) can treat every one of those uniformly as "still
# unresolved" and abort, never retrying or guessing on this class's behalf.
func _resolve_forced_discard() -> bool:
	if not _discard_policy.is_valid():
		return false
	var deck: CardDeck = _state.card_deck()
	var card: Card = _discard_policy.call(deck)
	if card == null:
		return false
	return deck.discard_card(card)


func _build_result(
	outcome: BattleState.Outcome,
	log: Array[String],
	aborted: bool,
	rounds: int,
	abort_reason: StringName = &""
) -> Dictionary:
	return {
		"outcome": outcome,
		"rounds": rounds,
		"aborted": aborted,
		"abort_reason": abort_reason,
		"log": log,
	}
