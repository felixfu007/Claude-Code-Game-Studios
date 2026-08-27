## Turn and action-flag bookkeeping for the tactical layer.
##
## This class knows only [int] unit ids and two factions. It has no
## knowledge of [Board], [Unit], or [CombatRules] — it never imports or
## references them. Board occupancy, unit stats, and damage math are all
## owned elsewhere; this class exists purely to answer "whose turn is it"
## and "has this unit used its move / attack flag yet".
##
## Each unit carries two independent flags — move and attack — that can be
## spent in either order, are each optional, and can each be deferred
## (spending one flag does not end the unit's turn; the other flag can
## still be used later in the same faction phase). A unit becomes "done"
## either automatically once both flags are used, or explicitly via
## [method end_unit_turn] with flags still unspent.
##
## Only the currently active faction's units may spend flags or be ended.
## [b]Reset is a faction-boundary rule, not a "done" rule[/b]: when
## [method advance_faction] rolls a faction's phase over, every unit in
## that faction has both flags — and its done state — unconditionally
## cleared, regardless of whether it ever became done, was explicitly
## ended, spent only one flag, or spent none at all.
class_name TurnOrder
extends RefCounted

## The two factions that alternate turns. Player always acts first within
## a round; a round completes (round_number increments) once the enemy
## faction's phase also rolls over.
enum Side { PLAYER, ENEMY }

# int -> Side, for every unit still tracked. Removed units are erased.
var _unit_side: Dictionary = {}

# int -> bool, whether the move / attack flag has been spent. Missing
# entries are treated as unspent (false).
var _move_used: Dictionary = {}
var _attack_used: Dictionary = {}

# int -> bool, whether the unit is done for the current faction phase
# (both flags spent, or end_unit_turn() called). Missing entries are
# treated as not done (false).
var _done: Dictionary = {}

# Insertion-ordered id lists per faction, kept in sync with _unit_side by
# remove_unit(). Used by units_with_flags_remaining() so results have a
# stable, predictable order.
var _player_ids: Array[int] = []
var _enemy_ids: Array[int] = []

var _current_side: TurnOrder.Side = TurnOrder.Side.PLAYER
var _round_number: int = 1


## Builds a fresh turn order. Player faction acts first, round_number
## starts at 1, and every listed unit starts with both flags unspent.
func _init(player_ids: Array[int], enemy_ids: Array[int]) -> void:
	for id: int in player_ids:
		_player_ids.append(id)
		_unit_side[id] = TurnOrder.Side.PLAYER
	for id: int in enemy_ids:
		_enemy_ids.append(id)
		_unit_side[id] = TurnOrder.Side.ENEMY


## Returns the faction whose units may currently spend flags.
func current_faction() -> TurnOrder.Side:
	return _current_side


## Returns the current round number (starts at 1, increments each time the
## enemy faction's phase rolls over back to the player faction).
func round_number() -> int:
	return _round_number


## Returns true if [param id] belongs to the current faction, is not done,
## and has not yet spent its move flag. False for units removed via
## [method remove_unit] or belonging to the non-active faction.
func can_move(id: int) -> bool:
	return _is_actionable(id) and not _move_used.get(id, false)


## Returns true if [param id] belongs to the current faction, is not done,
## and has not yet spent its attack flag. False for units removed via
## [method remove_unit] or belonging to the non-active faction.
func can_attack(id: int) -> bool:
	return _is_actionable(id) and not _attack_used.get(id, false)


## Spends [param id]'s move flag. Returns false and changes no state if
## [method can_move] would be false for this id (wrong faction, already
## done, already spent, or removed). If this also exhausts the attack
## flag, the unit becomes done automatically.
func use_move(id: int) -> bool:
	if not can_move(id):
		return false
	_move_used[id] = true
	_finish_if_both_flags_spent(id)
	return true


## Spends [param id]'s attack flag. Returns false and changes no state if
## [method can_attack] would be false for this id (wrong faction, already
## done, already spent, or removed). If this also exhausts the move flag,
## the unit becomes done automatically.
func use_attack(id: int) -> bool:
	if not can_attack(id):
		return false
	_attack_used[id] = true
	_finish_if_both_flags_spent(id)
	return true


## Actively ends [param id]'s turn. Valid for any unit that is still
## actionable (current faction, not already done, not removed) — neither
## flag needs to have been spent. Returns false and changes no state if
## the unit is not actionable.
func end_unit_turn(id: int) -> bool:
	if not _is_actionable(id):
		return false
	_done[id] = true
	return true


## Returns true if [param id] is done for the current faction phase
## (spent both flags, or was explicitly ended). Units removed via
## [method remove_unit], or never registered, are reported as done since
## they can never take further action.
func is_done(id: int) -> bool:
	if not _unit_side.has(id):
		return true
	return _done.get(id, false)


## Returns the ids of the current faction's units that are not yet done —
## i.e. still have at least one unspent flag and were not actively ended.
## Order matches the faction's original construction order.
func units_with_flags_remaining() -> Array[int]:
	var result: Array[int] = []
	var ids: Array[int] = _player_ids if _current_side == TurnOrder.Side.PLAYER else _enemy_ids
	for id: int in ids:
		if _is_actionable(id):
			result.append(id)
	return result


## Rolls the current faction's phase over: every unit in the ending
## faction has both flags and its done state unconditionally cleared —
## this happens regardless of whether each unit ever became done, was
## explicitly ended, spent only one flag, or spent none at all. Then the
## active faction switches; when the enemy faction hands back to the
## player faction, round_number increments.
func advance_faction() -> void:
	var ending_side: TurnOrder.Side = _current_side
	var ending_ids: Array[int] = _player_ids if ending_side == TurnOrder.Side.PLAYER else _enemy_ids
	for id: int in ending_ids:
		_move_used[id] = false
		_attack_used[id] = false
		_done[id] = false

	if ending_side == TurnOrder.Side.PLAYER:
		_current_side = TurnOrder.Side.ENEMY
	else:
		_current_side = TurnOrder.Side.PLAYER
		_round_number += 1


## Removes [param id] (permadeath) so it no longer participates in any
## query or phase-advancement decision.
func remove_unit(id: int) -> void:
	_unit_side.erase(id)
	_move_used.erase(id)
	_attack_used.erase(id)
	_done.erase(id)
	_player_ids.erase(id)
	_enemy_ids.erase(id)


# True if id is tracked, belongs to the currently active faction, and is
# not yet done. Shared gate for can_move(), can_attack(), and
# end_unit_turn().
func _is_actionable(id: int) -> bool:
	if not _unit_side.has(id):
		return false
	if _unit_side[id] != _current_side:
		return false
	return not _done.get(id, false)


# Marks id done once both its move and attack flags have been spent.
func _finish_if_both_flags_spent(id: int) -> void:
	if _move_used.get(id, false) and _attack_used.get(id, false):
		_done[id] = true
