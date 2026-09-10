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

# This battle's CardDeck, optionally set by whichever driver (BattleController
# or BattleLoop) is constructed against this state — see attach_card_deck().
# null until a driver attaches one (or forever, if the caller never supplies
# one): unlike _turn_order, every existing test constructs both drivers
# WITHOUT a deck (story-006-battle-loop-wiring.md's hard constraint — see
# attach_card_deck()'s doc comment), so every card-facing method below must
# tolerate this staying null for this battle's entire lifetime and behave as
# a no-op when it does (AC-W6).
var _card_deck: CardDeck = null


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


## Returns the [CardDeck] attached to this battle, or [code]null[/code] if
## none was ever attached — see [method attach_card_deck]. Card play is
## entirely optional for a battle (story-006-battle-loop-wiring.md, AC-W6):
## every existing test file constructs [BattleController]/[BattleLoop]
## without a deck, so [code]null[/code] here must remain a fully supported,
## permanent state, not merely a construction-time transient.
func card_deck() -> CardDeck:
	return _card_deck


## Attaches [param deck] as this battle's [CardDeck], mirroring
## [method attach_turn_order]'s shape — see that method's doc comment for why
## a driver attaches rather than this class constructing one itself. Called
## once, from each driver's [code]_init[/code], with whatever [CardDeck] that
## constructor itself received (or [code]null[/code], the default both
## drivers' constructors fall back to when no card system is wired into a
## given battle — story-006-battle-loop-wiring.md's hard requirement that the
## card system be entirely optional, AC-W6). Passing [code]null[/code] is a
## valid, supported call, not a caller error: it is exactly what every
## pre-Story-006 test still does today, and every method that consults
## [member _card_deck] treats [code]null[/code] as "no card system for this
## battle" rather than asserting.
func attach_card_deck(deck: CardDeck) -> void:
	_card_deck = deck


## True while a player owes a forced discard for THIS battle (a [method
## CardDeck.draw_for_turn] call grew an already-full hand) — delegates to
## [method CardDeck.has_pending_discard], returning [code]false[/code]
## unconditionally when no [CardDeck] is attached (story-006-battle-loop-
## wiring.md AC-W6: card play is entirely optional per battle, and "no deck"
## can never owe a discard).
##
## This is the single query story-007-forced-discard-gate.md's gate is built
## on: [BattleController] checks this before every one of its four
## board-mutating commands ([method BattleController.select_unit], [method
## BattleController.click_tile], [method BattleController.end_unit_turn],
## [method BattleController.end_faction_phase]) — see their own doc comments
## for the enforcement side — and [BattleLoop] checks it right after every
## call it makes to [method begin_player_turn]. This method only answers the
## question; it never rejects anything itself.
func has_pending_discard() -> bool:
	if _card_deck == null:
		return false
	return _card_deck.has_pending_discard()


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


## Story 002's shared "a player turn just started" hook
## (`story-002-modifier-lifecycle.md`) — the single function both
## [BattleController] and [BattleLoop] call at every point a player faction
## phase begins, including the very first one at battle start (a fresh
## driver's initial phase is already PLAYER without ever calling
## [method TurnOrder.advance_faction] — see each driver's own comment on why
## that construction-time call exists too, not just the later
## enemy-phase-ending one). Deliberately a single call on a single shared
## object rather than two independent per-driver implementations: the story
## treats "decrement/expire, then (later) draw" as one ordered step, not two
## independently-triggered handlers, precisely to keep that order from ever
## depending on signal-connection order instead of an explicit sequence.
##
## Iterates every unit in the battle regardless of faction or side-to-move —
## a card can buff an ally or debuff an enemy, and GDD Formula 二's
## decrement is a per-modifier turn-boundary rule, not a per-faction one; it
## fires once per round (at the player-turn boundary), never a second time
## at the enemy-turn boundary. Dead units are included too: their
## [member Unit._modifiers] is already empty per [method Unit.take_damage],
## so ticking them is a harmless no-op, and skipping them here would just be
## an extra branch that changes nothing observable.
func tick_all_modifiers() -> void:
	for unit: Unit in _units.values():
		unit.tick_modifiers()


## Battle-start hook (story-006-battle-loop-wiring.md): deals the opening
## hand ([method CardDeck.deal_opening_hand]) if a [CardDeck] is attached; a
## complete no-op if [method card_deck] is [code]null[/code] (AC-W6). Called
## once, by each driver's [code]_init[/code].
##
## Deliberately NOT folded into [method begin_player_turn] below, and
## deliberately NOT paired with a [method CardDeck.draw_for_turn] call here —
## this is why round 1 always ends up with exactly
## [constant CardDeck.OPENING_HAND_SIZE] (5) cards in hand, never
## [constant CardDeck.OPENING_HAND_SIZE] +
## [constant CardDeck.CARDS_DRAWN_PER_TURN] (6): the GDD states "開局手牌 5
## 張" and "每回合開始補 1 張" as two separate rules without saying whether
## round 1 gets both, and dealing 6 into a hand whose limit is also 5 would
## force the player's very first action in the battle to be a discard. Round
## 1's player phase never calls [method begin_player_turn] at all (see that
## method's own doc comment on why the construction-time hook and the
## faction-transition hook are two different call sites) — [method
## draw_for_turn] is therefore never invoked for round 1 under either driver,
## by construction, not by a runtime check.
func deal_opening_hand() -> void:
	if _card_deck != null:
		_card_deck.deal_opening_hand()


## Story 006's shared "a player turn just started, cards included" hook — the
## single function both [BattleController] and [BattleLoop] call at every
## faction-transition point a player phase begins (everywhere [method
## tick_all_modifiers] was called directly before this story; construction
## time is NOT one of these points — see [method deal_opening_hand]'s doc
## comment for why round 1 is handled separately).
##
## 🔴 Ordering is the entire reason this method exists rather than staying
## two independent calls at each call site: [method tick_all_modifiers] is
## called FIRST, [method CardDeck.draw_for_turn] SECOND, always, in every
## caller, because this is a single shared method rather than two statements
## copy-pasted at four call sites. If a player's hand is already full when a
## card-driven modifier is due to expire this same turn, drawing before
## ticking would let the forced-discard flag ([method
## CardDeck.has_pending_discard]) turn true while the soon-to-expire modifier
## is still sitting in [method Unit.active_modifiers] — the player would be
## asked to make an irreversible discard choice against a board state that
## is about to become stale. Ticking first guarantees that by the moment
## [method CardDeck.has_pending_discard] can possibly read true from this
## call, every modifier due to expire this turn is already gone.
##
## The draw half is skipped — silently, not an error — only when no deck is
## attached (AC-W6).
##
## 🔴 story-007-forced-discard-gate.md removed the second guard story 006 had
## here (also skipping the draw whenever a forced discard from a previous
## turn was never resolved). That guard existed only because, at the time,
## nothing else in the project stopped a battle from reaching a second call
## into this method with the first discard still pending — [constant
## CardDeck.HAND_SIZE_LIMIT] and [constant CardDeck.OPENING_HAND_SIZE] are
## both 5 in the current tuning data, so the round-2 draw already fills the
## hand and sets [method has_pending_discard], and neither driver gated
## further turn progression on that flag yet. Silently skipping the draw
## avoided the alternative — [method CardDeck.draw_for_turn]'s own
## documented precondition assert firing — but left the hand stuck below its
## rightful size for as long as the discard stayed unresolved, which is
## exactly the "silent swallow" [code].claude/docs/coding-standards.md[/code]
## warns against.
##
## As of story 007, nothing reaches this method with a discard still pending
## any more, by construction rather than by a runtime check here:
## [br]
## - [BattleController] gates every one of its four board-mutating commands
##   ([method BattleController.select_unit], [method
##   BattleController.click_tile], [method BattleController.end_unit_turn],
##   [method BattleController.end_faction_phase]) on [method has_pending_discard]
##   — in particular [method BattleController.end_faction_phase] itself, the
##   one call that leads to the next enemy-phase-ending call into this
##   method, cannot succeed while a discard is owed. A human-driven battle
##   can therefore never reach a second call here with the first discard
##   still pending.
## [br]
## - [BattleLoop] (no human player exists in that driver) checks [method
##   has_pending_discard] itself immediately after every call it makes to
##   this method, and either resolves it through an injected
##   [code]discard_policy[/code] or aborts the run outright — see [method
##   BattleLoop.run]'s own comment. It, too, never lets a second call reach
##   this method with the first discard still pending.
##
## If either caller's obligation above is ever violated, this method now
## surfaces that as a loud [method CardDeck.draw_for_turn] assert failure
## instead of silently skipping the draw — deliberate, not an oversight.
func begin_player_turn() -> void:
	tick_all_modifiers()
	if _card_deck != null:
		_card_deck.draw_for_turn()


## AC-11a's battle-end hook (`story-002-modifier-lifecycle.md`): discards
## every unit's active [CardModifier]s unconditionally, regardless of
## [member CardModifier.remaining_turns] — called exactly once by each
## driver, at the moment [method outcome] is first observed to have left
## ONGOING (win or lose, the rule does not distinguish). Iterates every unit
## regardless of faction, same reasoning as [method tick_all_modifiers].
func clear_all_modifiers() -> void:
	for unit: Unit in _units.values():
		unit.clear_modifiers()


## AC-W4's battle-end hook (story-006-battle-loop-wiring.md): returns every
## card still in hand or the used pile back to the pool ([method
## CardDeck.return_all_to_pool]) if a [CardDeck] is attached; a complete
## no-op if [method card_deck] is [code]null[/code] (AC-W6). Called exactly
## once by each driver, immediately after [method clear_all_modifiers], at
## the same battle-end moment — mirroring how [method clear_all_modifiers]
## and [method CardDeck.return_all_to_pool] are the two independent
## battle-end resets Story 002 and Story 003 each already owned before this
## story existed to wire the second one in.
func return_cards_to_pool() -> void:
	if _card_deck != null:
		_card_deck.return_all_to_pool()


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
