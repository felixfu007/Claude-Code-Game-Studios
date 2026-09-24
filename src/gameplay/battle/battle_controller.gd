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

## story-008-play-session-wiring.md: this battle's [CardPlaySession], or
## [code]null[/code] if no [CardDeck] was ever attached — mirrors
## [member BattleState._card_deck]'s own optionality (AC-P6: card play is
## exactly as optional as the deck it plays from). Every forwarding method
## below ([method open_hand], [method select_card], [method legal_targets],
## [method select_target], [method select_second_target], [method confirm],
## [method cancel]) checks this for [code]null[/code] first and returns a
## safe default ([code]false[/code] or an empty array) rather than crashing.
var _card_play_session: CardPlaySession = null

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

## story-018-enemy-phase-stepped-playback.md: cursor into the CURRENT pass's
## snapshot of [method TurnOrder.units_with_flags_remaining], used ONLY by
## [method step_enemy_phase] — [method run_enemy_phase] neither reads nor
## writes these two fields and is completely unaware of them. Empty/zero
## means "no pass in progress"; reset to that state the instant a pass
## finalizes the phase or the battle ends, so the next ENEMY_ACTING phase
## always starts [method step_enemy_phase] from a clean slate — regardless
## of whether the PREVIOUS phase was driven by this method or by [method
## run_enemy_phase] (which never leaves anything here to see in the first
## place, since it never touches these fields). See [method step_enemy_phase]
## for the hard rule against interleaving the two drivers mid-phase.
var _enemy_step_snapshot: Array[int] = []
var _enemy_step_index: int = 0


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
##
## [param card_deck] defaults to [code]null[/code] —
## story-006-battle-loop-wiring.md's hard requirement that card play be
## entirely optional per battle (AC-W6). When supplied, it is attached to
## [param state] via [method BattleState.attach_card_deck] and dealt its
## opening hand via [method BattleState.deal_opening_hand] — see that
## method's own doc comment for why round 1 gets exactly the opening hand
## and never one extra card drawn on top of it.
##
## story-008-play-session-wiring.md: when [param card_deck] is non-null, a
## [CardPlaySession] is also constructed over it (see [member
## _card_play_session]) — [param affinity_links] and [param write_port] are
## the last two of [method CardPlaySession._init]'s five dependencies,
## forwarded through unchanged. [param write_port] defaults to
## [code]null[/code]; when unset, a [NullAffinityWritePort] is substituted
## instead of ever handing [CardPlaySession] a literal [code]null[/code]
## (AC-P7 — see that class's own doc comment for why a bare [code]null[/code]
## there would be a crash, not a rejection, the moment a 丙類 card's pair
## passes [method PermanentAffinityWriteRules.has_canon_link]). [param
## authoritative_write_in_progress_check] defaults to an unset [Callable],
## identical to [method CardPlaySession._init]'s own default — see
## [member CardPlaySession._authoritative_write_in_progress_check] for what
## an unset value means. No [CardPlaySession] is constructed at all when
## [param card_deck] is [code]null[/code] — card play is exactly as optional
## as the deck it plays from (AC-P6).
func _init(
	state: BattleState,
	order: TurnOrder,
	phi_provider: Callable = Callable(),
	decide: Callable = Callable(),
	card_deck: CardDeck = null,
	affinity_links: Array[AffinityLink] = [],
	write_port: AffinityWritePort = null,
	authoritative_write_in_progress_check: Callable = Callable()
) -> void:
	_state = state
	_order = order
	_state.attach_turn_order(order)
	_state.attach_card_deck(card_deck)
	_state.deal_opening_hand()
	if card_deck != null:
		var effective_write_port: AffinityWritePort = (
			write_port if write_port != null else NullAffinityWritePort.new()
		)
		_card_play_session = CardPlaySession.new(
			card_deck, _state, affinity_links, effective_write_port,
			authoritative_write_in_progress_check
		)
	# story-002-modifier-lifecycle.md: a fresh controller's initial _phase is
	# already PLAYER_INPUT (see the field default above) without ever routing
	# through _order.advance_faction() — the round-1 player phase never takes
	# the transition path run_enemy_phase() ticks from. Without this call,
	# round 1 would be the one player-turn-start event in the entire battle
	# that never ticks modifiers. No modifier can exist yet at construction
	# time in current gameplay (cards are only ever played during
	# PLAYER_INPUT, which has not started until this constructor returns), so
	# this is a no-op today — it exists so this constructor and
	# run_enemy_phase() together cover every player-turn-start point, not
	# just the one that happens to already have an existing call site to hang
	# off of.
	_state.tick_all_modifiers()
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


## True while the player owes a forced discard, delegated to [method
## BattleState.has_pending_discard] — always [code]false[/code] for a battle
## with no [CardDeck] attached. story-007-forced-discard-gate.md: this is a
## pure query, safe to call in any [enum Phase]; it is the four
## board-mutating commands below ([method select_unit], [method click_tile],
## [method end_unit_turn], [method end_faction_phase]) that gate on it, not
## this method itself. A caller wiring up a discard-prompt UI polls this to
## know whether to show one.
func has_pending_discard() -> bool:
	return _state.has_pending_discard()


## story-007-forced-discard-gate.md AC-D9/AC-D10/AC-D11 — the player-facing
## entry point for GDD's "玩家選擇後,系統棄掉該張牌" half. This is the
## counterpart to the four gated commands: they refuse everything while a
## discard is owed, and this is the one call that can actually lift that
## refusal. Returns [code]false[/code] and changes no state in either
## rejection case:
## [br]
## - [method has_pending_discard] is false right now — a discard is never
##   legal to volunteer outside the rule that requires one (there is no
##   "discard whenever you feel like it" action in the GDD).
## [br]
## - [param card] is not currently in the attached [CardDeck]'s hand.
## [br]
## On success, delegates straight to [method CardDeck.discard_card] — the
## exact same call [BattleLoop]'s injected [code]discard_policy[/code] path
## also ends at (see [method BattleLoop._resolve_forced_discard]), so the
## human-driven and simulation-driven paths converge on one discard
## implementation instead of two that could drift apart. This method never
## chooses [param card] itself — GDD Edge Cases "不得由系統代選" — the
## caller must always name the exact card; [param card] is not optional and
## has no default.
func resolve_forced_discard(card: Card) -> bool:
	if not _state.has_pending_discard():
		return false
	return _state.card_deck().discard_card(card)


## design/ux/battle-menu.md Data Requirements row 2 / AC-M5: single source of
## truth for "打牌流程是否進行中". The battle-menu screen's "結束回合" row
## MUST read this exact method rather than maintain a parallel flag — AC-M5
## tests precisely that: flipping the ground truth this method reads must
## change the menu's disabled state without the menu itself changing a
## single line, and the reverse edit (each side keeping its own copy) must
## make that test fail.
##
## Delegates straight to [method CardPlaySession.is_open] — [code]true[/code]
## from a successful [method open_hand] until the session returns to
## [constant CardPlaySession.Step.CLOSED] (via [method confirm] completing or
## [method cancel] walking all the way back out). This deliberately reuses
## the exact boundary [method CardPlaySession.is_open]'s own doc comment
## already documents as the authoritative signal for AC-14
## ("打牌介面開啟中不得發起攻擊"), rather than drawing a second, narrower line
## at [constant CardPlaySession.Step.SELECTING_CARD] (hand open, no card
## chosen yet).
##
## Cost of this choice: a player who opens the hand purely to browse — no
## card selected — cannot end their turn from the menu until they cancel
## back out of the hand first (one extra input). The alternative (treating
## SELECTING_CARD as "not in progress") was rejected: [CardPlaySession] would
## then answer "is the play interface open" two different ways depending on
## who asked, which is exactly the two-sources-of-truth drift this method
## exists to prevent — just relocated one level down instead of removed.
##
## Returns [code]false[/code] if no [CardDeck] is attached to this battle
## (AC-P6 — mirrors every other card-play forwarding method's null handling).
## Not gated on [method phase] or [method has_pending_discard] — this is a
## pure read of the session's own state, same shape as
## [method has_pending_discard] itself.
func is_card_play_in_progress() -> bool:
	if _card_play_session == null:
		return false
	return _card_play_session.is_open()


## Story U-014 連帶(2026-09-24 管理者裁決「消除重複」)—— 轉發
## [method CardPlaySession.selected_card],同 [method is_card_play_in_progress]
## 的形狀:純讀取,不設任何 phase 閘門(這是查詢「目前選了什麼」,不是動作)。
## 沒有 [CardDeck] 時回傳 [code]null[/code]。
func selected_card() -> Card:
	if _card_play_session == null:
		return null
	return _card_play_session.selected_card()


## 同上,轉發 [method CardPlaySession.selected_target_a]。沒有 [CardDeck] 時
## 回傳 [code]-1[/code]。
func selected_target_a() -> int:
	if _card_play_session == null:
		return -1
	return _card_play_session.selected_target_a()


## 同上,轉發 [method CardPlaySession.selected_target_b]。沒有 [CardDeck] 時
## 回傳 [code]-1[/code]。
func selected_target_b() -> int:
	if _card_play_session == null:
		return -1
	return _card_play_session.selected_target_b()


## story-008-play-session-wiring.md: forwards to [method
## CardPlaySession.open_hand]. Returns [code]false[/code] without touching
## anything if no [CardDeck] is attached to this battle (AC-P6) or the
## controller is outside PLAYER_INPUT ([CardPlaySession] itself holds no
## phase reference and documents this as the caller's obligation — see its
## own class doc comment, point 1). 🔴 NOT gated on [method
## has_pending_discard] — design/ux/skill-card-play.md S4: the hand must be
## open (and stay open) precisely while a discard is owed, so the player can
## see what to discard (AC-P3).
func open_hand() -> bool:
	if _card_play_session == null:
		return false
	if _phase != Phase.PLAYER_INPUT:
		return false
	return _card_play_session.open_hand()


## story-008-play-session-wiring.md: forwards to [method
## CardPlaySession.select_card]. Same "safe false, not gated on forced
## discard" shape as [method open_hand] — see that method's doc comment for
## why (AC-P3: browsing/selecting a card must stay available while a
## discard is owed, since that is how the player picks which one to
## discard).
func select_card(card: Card) -> bool:
	if _card_play_session == null:
		return false
	if _phase != Phase.PLAYER_INPUT:
		return false
	return _card_play_session.select_card(card)


## story-008-play-session-wiring.md: forwards to [method
## CardPlaySession.legal_targets] — a pure query, same "safe empty, not
## gated on forced discard" shape as [method open_hand] (AC-P3).
func legal_targets() -> Array[int]:
	if _card_play_session == null:
		return []
	if _phase != Phase.PLAYER_INPUT:
		return []
	return _card_play_session.legal_targets()


## story-008-play-session-wiring.md AC-P3: forwards to [method
## CardPlaySession.select_target], but — unlike [method open_hand]/[method
## select_card]/[method legal_targets] above — ALSO returns [code]false[/code]
## without touching anything while [method has_pending_discard] is true.
## Picking WHICH pending card to discard is exactly what [method
## open_hand]/[method select_card] above stay available for; picking a
## card's own PLAY target is a step toward playing it, which the forced
## discard must block (design/ux/skill-card-play.md S4: "只能選一張棄掉").
func select_target(unit_id: int) -> bool:
	if _card_play_session == null:
		return false
	if _phase != Phase.PLAYER_INPUT:
		return false
	if _state.has_pending_discard():
		return false
	return _card_play_session.select_target(unit_id)


## story-008-play-session-wiring.md AC-P3: forwards to [method
## CardPlaySession.select_second_target] — 丙類's second-target step. Same
## gating as [method select_target], including the forced-discard block.
func select_second_target(unit_id: int) -> bool:
	if _card_play_session == null:
		return false
	if _phase != Phase.PLAYER_INPUT:
		return false
	if _state.has_pending_discard():
		return false
	return _card_play_session.select_second_target(unit_id)


## story-008-play-session-wiring.md AC-P3: forwards to [method
## CardPlaySession.confirm] — the actual write. Same gating as [method
## select_target], including the forced-discard block: this is the single
## most load-bearing gate of the three card-play commands, mirroring why
## [method end_faction_phase] is the most load-bearing of the four
## board-mutating commands (story-007-forced-discard-gate.md) — it is the
## one call in this class that can make [method CardPlaySession] actually
## write anything.
func confirm() -> bool:
	if _card_play_session == null:
		return false
	if _phase != Phase.PLAYER_INPUT:
		return false
	if _state.has_pending_discard():
		return false
	return _card_play_session.confirm()


## story-008-play-session-wiring.md AC-P3: forwards to [method
## CardPlaySession.cancel], gated identically to [method select_target] —
## including the forced-discard block, per design/ux/skill-card-play.md S4's
## explicit rule that the cancel key does nothing while a discard is owed
## ("取消鍵在此狀態無效"). Unlike [method CardPlaySession.cancel] itself
## (which returns [code]void[/code] and is unconditionally safe to call),
## this wrapper returns [code]bool[/code] so a blocked cancel is observable
## the same way every other gated command in this class is: [code]true[/code]
## means the gate let the call through (even if [CardPlaySession.cancel]
## itself then no-ops, e.g. because nothing was open), [code]false[/code]
## means the gate itself refused it.
func cancel() -> bool:
	if _card_play_session == null:
		return false
	if _phase != Phase.PLAYER_INPUT:
		return false
	if _state.has_pending_discard():
		return false
	_card_play_session.cancel()
	return true


## Attempts to select [param id]. Returns [code]false[/code] and changes no
## state if [param id] does not exist, is dead, belongs to a faction other
## than the one currently active, is already done for this phase, the
## controller is outside PLAYER_INPUT, or a forced discard is owed (story-007-
## forced-discard-gate.md AC-D2 — see [method has_pending_discard]).
func select_unit(id: int) -> bool:
	if _phase != Phase.PLAYER_INPUT:
		return false
	if _state.has_pending_discard():
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
## [code]&"attacked"[/code], [code]&"none"[/code],
## [code]&"blocked_pending_discard"[/code]). Outside PLAYER_INPUT, always
## returns [code]{"action": &"none"}[/code] and changes no state.
##
## 🔴 story-007-forced-discard-gate.md: while [method has_pending_discard] is
## true, this method always returns
## [code]{"action": &"blocked_pending_discard"}[/code] and changes no state
## — deliberately NOT [code]&"none"[/code]. [code]&"none"[/code] already
## means "clicked somewhere irrelevant, nothing was selected" (see the
## residual branch below); reusing it here would make a screen layer unable
## to tell "the click did nothing because there was nothing to click" apart
## from "the click did nothing because the game is refusing all input right
## now" — the single worst shape a rejected input can take (a control that
## looks clickable and silently is not).
func click_tile(pos: Vector2i) -> Dictionary:
	if _phase != Phase.PLAYER_INPUT:
		return {"action": &"none"}
	if _state.has_pending_discard():
		return {"action": &"blocked_pending_discard"}

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
## (wrong faction, already done, removed), the controller is outside
## PLAYER_INPUT, or a forced discard is owed (story-007-forced-discard-
## gate.md AC-D2 — see [method has_pending_discard]). Clears the selection if
## [param id] was selected.
func end_unit_turn(id: int) -> bool:
	if _phase != Phase.PLAYER_INPUT:
		return false
	if _state.has_pending_discard():
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
## ENEMY. No-op outside PLAYER_INPUT, and no-op while a forced discard is
## owed (story-007-forced-discard-gate.md AC-D2 — see [method
## has_pending_discard]).
##
## 🔴 This is the single most load-bearing gate of the four: it is the only
## call in this class that can lead to [method run_enemy_phase] eventually
## calling [method BattleState.begin_player_turn] again for the *next*
## player turn. Blocking it here is what guarantees [method
## BattleState.begin_player_turn] can never be reached — for a
## human-driven battle — while an earlier discard is still unresolved; see
## that method's own doc comment for the full argument.
func end_faction_phase() -> void:
	if _phase != Phase.PLAYER_INPUT:
		return
	if _state.has_pending_discard():
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

	_finalize_enemy_phase()
	return log


# Ends the enemy phase and hands the round back to the player: rolls enemy
# flags over, ticks modifiers / draws for the player's new turn, then flips
# the phase. story-018-enemy-phase-stepped-playback.md: extracted out of
# run_enemy_phase()'s own body (this exact sequence used to sit inline,
# directly below its while loop) so that BOTH run_enemy_phase() (falling out
# of its while loop once acting_ids comes back empty) and step_enemy_phase()
# (a call whose _next_enemy_step_id() returns -1) share the one copy of the
# ORDERING RULE below, instead of one carrying this reasoning and a second
# copy silently not — see AC-E2 / Implementation Note ①③ for why that
# distinction matters here specifically.
#
# story-002-modifier-lifecycle.md: this is the ENEMY -> PLAYER transition,
# i.e. a player turn just started — tick before flipping the phase, so
# _set_phase()'s phase_changed signal (which a screen layer uses to
# refresh its view) never fires while a modifier that should already be
# expired is still sitting in a unit's active list. See
# BattleState.tick_all_modifiers()'s doc comment for why this is a single
# shared call rather than a second, independent handler.
#
# story-006-battle-loop-wiring.md: this is also the per-turn card-draw
# point — BattleState.begin_player_turn() wraps tick_all_modifiers() AND
# (if a CardDeck is attached) CardDeck.draw_for_turn(), in that fixed
# order, for exactly the reason its own doc comment gives: drawing before
# ticking could let a forced-discard decision reach the player while a
# modifier that should already be expired is still showing as active.
func _finalize_enemy_phase() -> void:
	_order.advance_faction()
	_state.begin_player_turn()
	_set_phase(Phase.PLAYER_INPUT)


## story-018-enemy-phase-stepped-playback.md: presentation-layer entry point
## that advances **exactly one** step of the enemy phase per call, instead of
## draining the whole phase synchronously the way [method run_enemy_phase]
## does. Both methods resolve one unit's action through the exact same
## private helper, [method _process_enemy_unit] — this method does not
## reimplement any AI decision or turn-flag rule, it only reimplements the
## OUTER iteration shape (which unit goes next), and even that shape reads
## straight off [TurnOrder] via [method TurnOrder.units_with_flags_remaining]
## and [method TurnOrder.is_done] — the exact two queries [method
## run_enemy_phase]'s own loop already uses. The phase-finalize step (rolling
## the round over and returning to PLAYER_INPUT) is likewise shared, via
## [method _finalize_enemy_phase] — see that method's doc comment for the
## ordering rule it carries. Per AC-E2 (this story), [method run_enemy_phase]
## keeps its own SIGNATURE AND OBSERVABLE BEHAVIOR unchanged (proven by the 6
## existing test files that call it staying green) even though its BODY was
## edited once, to extract [method _finalize_enemy_phase] out of it — an
## extraction is not the same claim as "not one character changed", and this
## story's own work order conflated the two; the manager ruling that
## resolved the conflation is recorded in this story's Test Evidence section.
##
## No-op (returns [code]{"log": [], "has_next": false}[/code]) unless
## [method phase] is already ENEMY_ACTING — same phase-guard [method
## run_enemy_phase] itself applies.
##
## Returns a [Dictionary] with exactly two keys:
## [br]
## - [code]"log"[/code] ([Array][String]): the log lines this ONE call
##   produced — either exactly what a single [method _process_enemy_unit]
##   call appended, or empty if this call only finalized the phase (see
##   below) or found nothing left to do.
## [br]
## - [code]"has_next"[/code] ([bool]): [code]true[/code] iff a following call
##   to this method would find another unit to advance. Callers drive the
##   whole phase with a loop shaped like:
##   [codeblock]
##   while controller.phase() == BattleController.Phase.ENEMY_ACTING:
##       var step := controller.step_enemy_phase()
##       # ... use step.log, await a pause, refresh the view, etc.
##   [/codeblock]
##   [method phase] itself (not a field on this Dictionary) is how a caller
##   learns whether a call finalized the enemy phase (phase becomes
##   PLAYER_INPUT) or ended the battle (phase becomes FINISHED) — this
##   mirrors how [method run_enemy_phase]'s own callers already learn the
##   outcome, so callers of the two methods check the same thing.
##
## 🔴 MUST NOT be interleaved with [method run_enemy_phase] on the SAME
## ENEMY_ACTING phase — call exactly one of the two for a phase's entire
## duration. [method run_enemy_phase] neither reads nor clears this method's
## cursor, so switching drivers mid-phase would silently strand a stale
## cursor for the NEXT phase to trip over. Production code only ever calls
## this method (see battle_screen.gd); [method run_enemy_phase] remains the
## whole-phase entry point for tests and any future non-presentation driver.
##
## 🔴 Fully synchronous — contains no [code]await[/code], no
## [code]call_deferred()[/code], and no [code]CONNECT_DEFERRED[/code] signal
## connection anywhere in its call chain (it only ever calls
## [method _process_enemy_unit], [method _finalize_enemy_phase],
## [method TurnOrder.units_with_flags_remaining], [method TurnOrder.is_done],
## [method TurnOrder.advance_faction], and [method BattleState.begin_player_turn]
## — all synchronous). This is what AC-E1's requirement ("no authoritative
## write is left in-progress across the call boundary") reduces to in this
## codebase today: ADR-0001's own [code]authoritative_write_in_progress[/code]
## flag has NO field anywhere in [code]src/[/code] yet (verified:
## [CardPlaySession]'s own doc comment records this same finding, dated
## 2026-09-10, and this story re-verified it unchanged on 2026-09-17) — it is
## a documented gap owned by the not-yet-built tactical-combat-system write
## guard, not something this story builds.
##
## 🔴 THIS IS A WEAKER GUARANTEE THAN THE ORIGINAL AC WORDING, NOT AN
## EQUIVALENT ONE — say so plainly rather than treating them as the same
## claim. The synchronous-call-chain proof above covers exactly one thing:
## TODAY, nothing in this call chain yields, so a caller pausing (via
## [code]await[/code] in its OWN code, never in this method) between two
## calls to this method is provably pausing between two fully-committed
## writes, never mid-write. It does NOT cover tomorrow: it cannot detect a
## FUTURE change that introduces a yield point into this call chain the way a
## real deadlock-detecting flag would (ADR-0001 Mechanism Two's own
## "not true across two consecutive _process frames" check catches exactly
## that class of regression, structurally, for free — a source-text scan
## does not). 🔴 OBLIGATION FOR WHOEVER BUILDS THAT FLAG: when
## [code]authoritative_write_in_progress[/code] gains a real implementation,
## come back and bring [method step_enemy_phase]'s cross-call boundary under
## its deadlock-detection coverage — this method's synchronous-today proof
## must not be mistaken for "already covered" and quietly left outside it.
func step_enemy_phase() -> Dictionary:
	var log: Array[String] = []
	if _phase != Phase.ENEMY_ACTING:
		return {"log": log, "has_next": false}

	var id: int = _next_enemy_step_id()
	if id == -1:
		_finalize_enemy_phase()
		return {"log": log, "has_next": false}

	_process_enemy_unit(id, log)

	if _phase == Phase.FINISHED:
		_enemy_step_snapshot = []
		_enemy_step_index = 0
		return {"log": log, "has_next": false}

	var has_next: bool = (
		_enemy_step_index < _enemy_step_snapshot.size()
		or not _order.units_with_flags_remaining().is_empty()
	)
	return {"log": log, "has_next": has_next}


# Shared by step_enemy_phase() only (run_enemy_phase() has its own inline
# while/for and does not call this). Returns the next enemy unit id to
# advance, or -1 if the current pass's snapshot AND a freshly taken one are
# both exhausted — i.e. the phase itself is over. Mirrors run_enemy_phase()'s
# "while true: snapshot; for id in snapshot: skip if done" shape, just spread
# across separate calls instead of one straight run: a snapshot is taken
# lazily the first time it is needed and re-taken whenever the current one
# runs out, and exactly one candidate index is examined per outer-loop
# iteration (not a nested inner loop) — this flatter, single-loop-with-break
# shape is deliberate, not stylistic: GDScript's "not all code paths return a
# value" check does not accept the nested while-inside-while-true form this
# method originally used (confirmed on-engine, 2026-09-17 — see this story's
# Test Evidence section), so this shape mirrors run_enemy_phase()'s own
# proven-compiling pattern (a while loop that only ever exits via break,
# followed by a trailing, unconditional statement) instead.
func _next_enemy_step_id() -> int:
	var result: int = -1
	while true:
		if _enemy_step_index >= _enemy_step_snapshot.size():
			_enemy_step_snapshot = _order.units_with_flags_remaining()
			_enemy_step_index = 0
			if _enemy_step_snapshot.is_empty():
				break
		var candidate: int = _enemy_step_snapshot[_enemy_step_index]
		_enemy_step_index += 1
		# Defense in depth, matching _apply_attack()'s own "re-check
		# immediately before settling" discipline — TurnOrder's own
		# units_with_flags_remaining() already excludes done ids today (see
		# its doc comment). This mirrors run_enemy_phase()'s identical
		# `if _order.is_done(id): continue` rather than assuming that will
		# always stay true.
		#
		# 🔴 CORRECTED 2026-09-17 by the independent reviewer's probe. This
		# comment previously claimed the branch "is not currently reachable".
		# That is FALSE and the correction matters, because the claim was the
		# stated reason for leaving it untested.
		#
		# Measured: prototypes/step-enemy-phase-removal-parity-probe-2026-09-17/
		# (probe_removal_parity.gd, Godot 4.7.1 headless, exit 0) drives this
		# exact branch — any caller of TurnOrder.remove_unit() can invalidate
		# an id that a live _enemy_step_snapshot has not walked to yet, and
		# the probe's call #3 takes this branch, skips the removed id and
		# returns -1 correctly.
		#
		# What IS true, and is the narrower fact the old wording overshot:
		# COMBAT SETTLEMENT cannot reach it today. BattleState.can_attack()
		# rejects same-faction targets unconditionally, and that check gates
		# the project's only production call site of remove_unit() — so no
		# legal enemy action can remove another enemy mid-phase. The probe
		# therefore had to call remove_unit() directly, bypassing settlement.
		#
		# Behavior is correct either way (both paths skip the dead id
		# identically — that parity is what the probe measured). Still not
		# covered by an automated test; the gap is real, the stated reason
		# for it was not.
		if not _order.is_done(candidate):
			result = candidate
			break
	return result


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
	# AC-11a (story-002-modifier-lifecycle.md): every active CardModifier is
	# cleared the instant the battle resolves, win or lose — before
	# battle_ended fires, so any listener that reacts to that signal by
	# reading unit state never observes a modifier that should not survive
	# past this battle.
	_state.clear_all_modifiers()
	# AC-W4 (story-006-battle-loop-wiring.md): every card still in hand or
	# the used pile returns to the pool at the same battle-end moment, if a
	# CardDeck is attached — no-op otherwise (AC-W6).
	_state.return_cards_to_pool()
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
