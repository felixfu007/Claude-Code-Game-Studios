## Data-layer "play a card" session for the technique-card system (好感度對話
## 卡牌) — production/epics/skill-card-system/story-005-play-session.md. Walks
## the four-step flow GDD Core Rules 四 defines — open hand -> select a card
## -> select its target(s) -> confirm — as a single stateful object with NO
## nodes, NO input handling, and NO screen concerns.
## [code]design/ux/skill-card-play.md[/code] is the interface authority for
## HOW a player triggers these calls (keys, animation, layout); this class
## only owns WHAT happens to game data once triggered.
##
## [b]Why cancel needs no rollback[/b] (GDD States and Transitions, quoted in
## this story's own work order): every step through
## [constant Step.SELECTING_CARD] / [constant Step.SELECTING_TARGET] /
## [constant Step.SELECTING_TARGET_B] is pure in-memory bookkeeping on THIS
## object — it never touches [CardDeck], never calls
## [method Unit.add_modifier], and never calls
## [method AffinityWritePort.append_record]. The ONLY method that writes
## anything is [method confirm], and it writes exactly once, synchronously, in
## one call. [method cancel] therefore never needs to undo anything; there is
## nothing to undo. An implementation that wrote at [method select_target] and
## relied on [method cancel] to undo it would violate this design — see the
## story's own explicit warning against exactly that shape.
##
## [b]Two structural facts this class deliberately does NOT enforce itself[/b],
## because the files that would let it enforce them are not among this
## story's own known dependencies:
## [br]
## 1. "僅限玩家自己的回合" (GDD Core Rules 四) — this class holds no
##    [TurnOrder]/phase reference at all and does not check whose turn it is.
##    A caller integrating this into a real battle loop MUST only invoke
##    [method open_hand] during the player's own [code]PLAYER_INPUT[/code]
##    phase; that is the caller's obligation, not this class's.
## [br]
## 2. "打牌介面開啟中不得發起攻擊" (the OTHER half of AC-14) — [method is_open]
##    is the authoritative, permanent signal for this rule, but nothing in
##    [code]src/gameplay/battle/battle_controller.gd[/code] consults it today.
##    A caller (a future UI/integration story) that gates its own attack call
##    on [code]not session.is_open()[/code] BEFORE ever reaching
##    [method BattleController.click_tile] genuinely gets the block this rule
##    requires — proven by this story's own test suite — but the production
##    attack path does not perform that gating itself yet. This is the same
##    category of documented, not-yet-wired gap [code]card_deck.gd[/code]
##    already carries for the turn-start draw sequence; it is called out here
##    rather than silently assumed fixed.
##
## [b]Structural mutual exclusion with authoritative writes (the FIRST half of
## AC-14)[/b]: [method open_hand] takes [param authoritative_write_in_progress_check]
## at construction — a [code]func() -> bool[/code] — checked synchronously, in
## the same call, before flipping [member _step] out of
## [constant Step.CLOSED]. GDD Core Rules 四 and ADR-0001's
## [code]authoritative_write_in_progress[/code] name the real flag this stands
## in for; that flag has ZERO implementation anywhere in [code]src/[/code] as
## of 2026-09-10 (verified:
## [code]grep -rn "authoritative_write_in_progress" src/ --include=*.gd[/code]
## returns only a doc-comment mention in [code]battle_state.gd[/code]). This
## class does NOT define that flag — it is ADR-0001 Mechanism One's own
## property, owned by the tactical combat system (#4). An unset [Callable]
## (the default) means "never blocked", matching this project's established
## idiom for optional injected predicates — see
## [member BattleController._phi_provider] / [member BattleController._decide]
## for the same "unset Callable = harmless default" shape.
class_name CardPlaySession
extends RefCounted

## The states GDD names up to S7 collapse, at the data layer, into these five.
## S4 (forced discard), S5 (enemy turn), S6 (authoritative write in progress),
## and S7 (empty hand) are deliberately NOT separate [enum Step] values: S4/S7
## are [CardDeck]'s own concerns ([method CardDeck.has_pending_discard],
## [method CardDeck.hand_size]), and S5/S6 are gating decisions made before or
## inside [method open_hand] rather than states this object sits in.
enum Step {
	CLOSED,             ## S0 — nothing selected, nothing to cancel.
	SELECTING_CARD,     ## S1 — hand open, no card chosen yet.
	SELECTING_TARGET,   ## S2 / S2p — a card is chosen; picking its first
	                    ## (and, for 甲類, ONLY) target.
	SELECTING_TARGET_B, ## S2q — 丙類 only: first character chosen, now
	                    ## picking the second from that character's own legal
	                    ## partners.
	CONFIRMING,         ## S3 — every target chosen; only confirm() or
	                    ## cancel() are valid from here.
}

# Injected — the hand this session plays cards from. Not owned by this class;
# see the class doc comment's point 1 for why this class never itself decides
# WHEN it is legal to call into it (whose turn it is).
var _deck: CardDeck

# Injected — used only to look up currently-alive units for 甲類's legal
# target set (units_of()) and 丙類's is_alive predicate
# (unit_by_id().is_alive()), and, on confirm, to attach a CardModifier to the
# chosen 甲類 target. Never consulted for whose turn it is or any phase
# concern — see the class doc comment's point 1.
var _state: BattleState

# Injected — the canon relationship-line table 丙類's legal-pairing
# derivation reads (PermanentAffinityWriteRules.legal_pairs() / .play()). A
# snapshot handed in at construction time, not re-read from any file by this
# class — matching every other class in this system (card.gd, card_deck.gd)
# that never touches FileAccess itself.
var _links: Array[AffinityLink]

# Injected — the narrow write port 丙類's confirm() writes through
# (story-004-permanent-write-port.md). See that story's own header comment
# for why this is not a literal AffinityDataPool.
var _write_port: AffinityWritePort

# Injected — func() -> bool, "is an authoritative write in progress right
# now". See the class doc comment's "Structural mutual exclusion" section for
# why an unset Callable means "never blocked".
var _authoritative_write_in_progress_check: Callable

var _step: Step = Step.CLOSED
var _selected_card: Card = null
var _selected_target_a: int = -1
var _selected_target_b: int = -1


func _init(
	deck: CardDeck,
	state: BattleState,
	links: Array[AffinityLink],
	write_port: AffinityWritePort,
	authoritative_write_in_progress_check: Callable = Callable()
) -> void:
	_deck = deck
	_state = state
	_links = links
	_write_port = write_port
	_authoritative_write_in_progress_check = authoritative_write_in_progress_check


## Returns the current [enum Step]. [constant Step.CLOSED] is the only step
## in which [method is_open] is false.
func step() -> Step:
	return _step


## True from a successful [method open_hand] until the session returns to
## [constant Step.CLOSED] (via [method confirm] completing, or [method cancel]
## walking all the way back out of [constant Step.SELECTING_CARD]). The
## authoritative signal for AC-14's "打牌介面開啟中不得發起攻擊" half — see the
## class doc comment's point 2 for what this class does, and does not, do
## with that signal.
func is_open() -> bool:
	return _step != Step.CLOSED


## Step 1 (S0 -> S1). Returns [code]false[/code] and leaves [member _step] at
## [constant Step.CLOSED] if [param authoritative_write_in_progress_check]
## (given at construction) reports [code]true[/code] — checked synchronously
## in this same call, satisfying AC-14's "同一次函式呼叫內同步回傳可觀測的拒絕
## 結果" requirement. No-op (returns [code]false[/code]) if already open —
## re-opening an already-open session is not a defined GDD transition.
func open_hand() -> bool:
	if _step != Step.CLOSED:
		return false
	if _is_authoritative_write_in_progress():
		return false
	_step = Step.SELECTING_CARD
	return true


## Step 2' (S1 -> S2/S2p). [param card] must currently be in the injected
## [CardDeck]'s hand — this is the only legality check this method performs;
## it does not care which [enum Card.Category] the card is, since legal
## target computation ([method legal_targets]) branches on that instead.
## Returns [code]false[/code] and changes nothing if not currently at
## [constant Step.SELECTING_CARD] or [param card] is not in hand.
func select_card(card: Card) -> bool:
	if _step != Step.SELECTING_CARD:
		return false
	if not _deck.hand().has(card):
		return false
	_selected_card = card
	_step = Step.SELECTING_TARGET
	return true


## Returns the set of unit ids [method select_target] (at
## [constant Step.SELECTING_TARGET]) or [method select_second_target] (at
## [constant Step.SELECTING_TARGET_B]) would currently accept — empty outside
## those two steps.
##
## For a [constant Card.Category.TEMPORARY_STAT_MODIFIER] card, this is every
## currently-alive PLAYER unit (GDD Data Requirements: "甲類=我方單位") — no
## further legality check exists for 甲類.
##
## For a [constant Card.Category.PERMANENT_AFFINITY_WRITE] card at
## [constant Step.SELECTING_TARGET] (S2p), this is every unit appearing in
## [method PermanentAffinityWriteRules.legal_pairs] (canon-linked AND alive).
## At [constant Step.SELECTING_TARGET_B] (S2q), this narrows to only the
## partners the already-chosen first character shares a legal link with
## (design/ux/skill-card-play.md S2q: "垂直切片通常僅 1 個").
func legal_targets() -> Array[int]:
	match _step:
		Step.SELECTING_TARGET:
			if _selected_card.category == Card.Category.TEMPORARY_STAT_MODIFIER:
				return _alive_player_unit_ids()
			return _s2p_legal_first_targets()
		Step.SELECTING_TARGET_B:
			return _s2q_legal_second_targets(_selected_target_a)
		_:
			return []


## Step 3 (S2 -> S3 for 甲類; S2p -> S2q for 丙類). Returns [code]false[/code]
## and changes nothing if not currently at [constant Step.SELECTING_TARGET] or
## [param unit_id] is not in [method legal_targets]. On success: for 甲類,
## moves directly to [constant Step.CONFIRMING] (甲類 has only one target);
## for 丙類, moves to [constant Step.SELECTING_TARGET_B] (丙類's second pick,
## S2q).
func select_target(unit_id: int) -> bool:
	if _step != Step.SELECTING_TARGET:
		return false
	if not legal_targets().has(unit_id):
		return false
	_selected_target_a = unit_id
	if _selected_card.category == Card.Category.PERMANENT_AFFINITY_WRITE:
		_step = Step.SELECTING_TARGET_B
	else:
		_step = Step.CONFIRMING
	return true


## Step 3' — 丙類 only (S2q -> S3). Returns [code]false[/code] and changes
## nothing if not currently at [constant Step.SELECTING_TARGET_B] or
## [param unit_id] is not in [method legal_targets].
func select_second_target(unit_id: int) -> bool:
	if _step != Step.SELECTING_TARGET_B:
		return false
	if not legal_targets().has(unit_id):
		return false
	_selected_target_b = unit_id
	_step = Step.CONFIRMING
	return true


## Step 4 (S3 -> S0). The ONLY method in this class that writes anything —
## see the class doc comment for why every earlier step is pure bookkeeping.
## Returns [code]false[/code] and changes nothing if not currently at
## [constant Step.CONFIRMING].
##
## [b]Dedup guard (this story's own hard requirement)[/b]: a second call made
## immediately after a successful one cannot re-apply anything, because a
## successful call always leaves [constant Step.CLOSED] behind before
## returning — the very next call finds [member _step] already
## [constant Step.CLOSED] (not [constant Step.CONFIRMING]) and returns
## [code]false[/code] at the first line, applying nothing a second time. No
## separate dedup flag is needed; the state transition itself is the guard.
##
## For [constant Card.Category.TEMPORARY_STAT_MODIFIER]: attaches a new
## [CardModifier] to the chosen target unit — [member CardModifier.source_name]
## is [member Card.id], [member CardModifier.remaining_turns] is
## [member Card.duration_rounds] (copied out once, per [Card]'s own doc
## comment on that field), and the ATK/DEF deltas are copied verbatim from the
## card. Always succeeds — there is no rejection path for 甲類.
##
## For [constant Card.Category.PERMANENT_AFFINITY_WRITE]: calls
## [method PermanentAffinityWriteRules.play] with the player-selected pair
## ([member _selected_target_a], [member _selected_target_b]) — NOT any field
## read off [param card] itself, per the 2026-09-10 manager ruling both that
## method and [Card]'s own field doc comments describe. If the port rejects
## the write (any [enum AffinityWritePort.Rejection] other than
## [constant AffinityWritePort.Rejection.NONE]), this method returns
## [code]false[/code], the card is NOT moved to the used pile, and
## [member _step] stays [constant Step.CONFIRMING] — the session is left
## exactly where it was, so a caller can still [method cancel] out of it. This
## path is not expected during normal play (target selection already filters
## to canon-linked, alive pairs via [method legal_targets]), but is not
## asserted-impossible either, since nothing in this class's own state
## prevents a target from dying between selection and confirmation.
func confirm() -> bool:
	if _step != Step.CONFIRMING:
		return false

	if _selected_card.category == Card.Category.PERMANENT_AFFINITY_WRITE:
		var rejection: AffinityWritePort.Rejection = PermanentAffinityWriteRules.play(
			_selected_card, _selected_target_a, _selected_target_b, _links, _write_port
		)
		if rejection != AffinityWritePort.Rejection.NONE:
			return false
	else:
		var target: Unit = _state.unit_by_id(_selected_target_a)
		target.add_modifier(CardModifier.new(
			_selected_card.id,
			_selected_card.delta_atk,
			_selected_card.delta_def,
			_selected_card.duration_rounds
		))

	var moved: bool = _deck.play_card(_selected_card)
	assert(
		moved,
		(
			"CardPlaySession.confirm: selected card '%s' was not found in the hand " +
			"at confirm time -- something outside this session moved it away " +
			"between select_card() and confirm(), which no caller in this system's " +
			"synchronous flow should ever do"
		) % _selected_card.id
	)
	_reset_to_closed()
	return true


## Step "取消" — valid from any of [constant Step.SELECTING_CARD],
## [constant Step.SELECTING_TARGET], [constant Step.SELECTING_TARGET_B], or
## [constant Step.CONFIRMING]. Steps back exactly one stage
## (design/ux/skill-card-play.md Interaction Map: "退回上一步"), clearing
## whichever selection belonged to the stage being left. Writes nothing at
## any stage — see the class doc comment for why no rollback is needed.
## No-op if already at [constant Step.CLOSED].
func cancel() -> void:
	match _step:
		Step.SELECTING_CARD:
			_reset_to_closed()
		Step.SELECTING_TARGET:
			_selected_card = null
			_selected_target_a = -1
			_step = Step.SELECTING_CARD
		Step.SELECTING_TARGET_B:
			_selected_target_a = -1
			_step = Step.SELECTING_TARGET
		Step.CONFIRMING:
			if _selected_card.category == Card.Category.PERMANENT_AFFINITY_WRITE:
				_selected_target_b = -1
				_step = Step.SELECTING_TARGET_B
			else:
				_selected_target_a = -1
				_step = Step.SELECTING_TARGET
		Step.CLOSED:
			pass


func _is_authoritative_write_in_progress() -> bool:
	if not _authoritative_write_in_progress_check.is_valid():
		return false
	return bool(_authoritative_write_in_progress_check.call())


func _alive_player_unit_ids() -> Array[int]:
	var ids: Array[int] = []
	for unit: Unit in _state.units_of(Unit.Faction.PLAYER):
		ids.append(unit.id)
	return ids


func _is_alive_check() -> Callable:
	return func(unit_id: int) -> bool:
		var unit: Unit = _state.unit_by_id(unit_id)
		return unit != null and unit.is_alive()


func _s2p_legal_first_targets() -> Array[int]:
	var legal: Array[AffinityLink] = PermanentAffinityWriteRules.legal_pairs(_links, _is_alive_check())
	var seen: Dictionary = {}
	for link: AffinityLink in legal:
		seen[link.unit_a] = true
		seen[link.unit_b] = true
	var result: Array[int] = []
	for id: int in seen.keys():
		result.append(id)
	result.sort()
	return result


func _s2q_legal_second_targets(first: int) -> Array[int]:
	var legal: Array[AffinityLink] = PermanentAffinityWriteRules.legal_pairs(_links, _is_alive_check())
	var result: Array[int] = []
	for link: AffinityLink in legal:
		if link.involves(first):
			result.append(link.partner_of(first))
	result.sort()
	return result


func _reset_to_closed() -> void:
	_step = Step.CLOSED
	_selected_card = null
	_selected_target_a = -1
	_selected_target_b = -1
