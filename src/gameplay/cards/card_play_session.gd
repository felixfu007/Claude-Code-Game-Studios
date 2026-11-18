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
## in for.
##
## 🔴 [b]CORRECTED 2026-10-12 — the claim that used to sit here is now
## false.[/b] It read: "that flag has ZERO implementation anywhere in src/ as
## of 2026-09-10", backed by an embedded grep. Both halves went stale:
##   1. [b]The flag is real now.[/b] [code]BattleState.authoritative_write_in_progress[/code]
##      exists as a guarded read-only property, and THIS VERY FILE wires it —
##      see [member _authoritative_write_in_progress_check] and
##      [method _is_authoritative_write_in_progress] below.
##   2. [b]The old grep counted its own documentation.[/b] Run unfiltered today
##      and 22 of 37 hits are comment lines. Immune form:
##        grep -rn "authoritative_write_in_progress" src/ --include=*.gd | grep -v ":#"
##
## [b]What has NOT changed[/b]: this
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

# story-015: injected read source for PAIR cards' relation state S. null = no pool
# attached; a PAIR card is then unplayable (RELATION_UNRESOLVED), never silently NONE.
# The session only READS it ([method AffinityRelation.state_of]); wear never writes it.
var _affinity_pool: AffinityDataPool = null

# story-015: hp_cost_none / pair_cost_cap. Defaults until [method attach_cost_tuning].
var _cost_tuning: CardCostTuning = CardCostTuning.defaults()

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


## story-015: attaches the affinity pool PAIR cards read their relation state from
## (read-only use). Not a constructor parameter so the existing constructor call
## sites stay unchanged; production wiring is a separate step (see story hand-off).
func attach_affinity_pool(pool: AffinityDataPool) -> void:
	_affinity_pool = pool


## story-015: attaches the cost knobs ([CardCostTuning]). A null argument is ignored.
func attach_cost_tuning(tuning: CardCostTuning) -> void:
	if tuning != null:
		_cost_tuning = tuning


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


## Story U-014 連帶(2026-09-24 管理者裁決「消除重複」)—— 讀出目前選定的卡片,
## [code]null[/code] 表示尚未選定([constant Step.CLOSED] 或
## [constant Step.SELECTING_CARD])。純新增的唯讀 getter,不改變任何既有行為 ——
## 在此之前這個類別沒有任何一處記載「刻意不對外公開選取狀態」的設計理由
## (協調者查證:`grep -n "getter\|encapsul\|deliberately" card_play_session.gd`
## 零命中此類理由),本 getter 純粹是把已存在的私有欄位開一個讀的窗口。
## 這是 [code]battle_screen.gd[/code] 的確認面板(U-014)原本自行維護一份鏡像
## (`_card_confirm_card`)的原因——本 getter 讓那份鏡像變得多餘,呼叫端改讀
## 這裡,單一資料來源。
func selected_card() -> Card:
	return _selected_card


## 同 [method selected_card] 的裁決與理由——讀出第一個選定的目標 unit id,
## [code]-1[/code] 表示尚未選定。甲類唯一的目標、丙類 S2p 選定的第一人都經由
## [method select_target] 寫入這裡。
func selected_target_a() -> int:
	return _selected_target_a


## 同上——丙類 S2q 選定的第二人,經由 [method select_second_target] 寫入。
## 甲類整個 session 期間恆為 [code]-1[/code]。
func selected_target_b() -> int:
	return _selected_target_b


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
	# Story 009: a 甲類 card whose named unit is dead / not on the field is a
	# dead card -- refuse here instead of entering SELECTING_TARGET with an empty
	# legal set (BattleScreen reads "legal_targets() empty" as "CONFIRMING
	# reached", so an empty set at S2 would be misread). The card stays in hand.
	if not is_card_playable(card):
		return false
	_selected_card = card
	if _is_fixed_target_card(card):
		# story-017 (F9): the card face fixes its targets (named + partner), so there is
		# nothing to pick -- go straight to CONFIRMING with both ids recorded.
		_selected_target_a = card.named_unit_id
		_selected_target_b = card.partner_unit_id
		_step = Step.CONFIRMING
		return true
	_step = Step.SELECTING_TARGET
	return true


## Story 009: whether [param card] can currently be played at all. [code]false[/code]
## only for a 甲類 card that names a unit ([member Card.named_unit_id]) which is
## not alive on the PLAYER side right now. 丙類 and unrestricted 甲類 are always
## [code]true[/code] here (丙類 pair legality is decided at target selection,
## unchanged). Pure query; a UI may use it to render a card as unplayable.
func is_card_playable(card: Card) -> bool:
	return card_unplayable_reason(card) == CardCostPlan.Reason.NONE


## story-015: why [param card] cannot be played right now, or
## [constant CardCostPlan.Reason.NONE] (ordinal 0 = playable, the project's
## convention) if it can. Category resolvability and the 甲類 named-target check come
## first (story 009/011), then the cost checks (payer/partner present, distance,
## affordability, wear cap). For a card whose payer is chosen later (named_unit_id < 1)
## the payer-dependent checks are deferred to [method confirm].
func card_unplayable_reason(card: Card) -> CardCostPlan.Reason:
	match card.category:
		Card.Category.TEMPORARY_STAT_MODIFIER:
			if not _is_fixed_target_card(card) and _legal_targets_for_stat_card(card).is_empty():
				return CardCostPlan.Reason.NO_LEGAL_TARGET
		Card.Category.HEAL:
			if _is_fixed_target_card(card):
				# A fixed recipient who is present but not wounded cannot be healed
				# (spec rule 6); an absent one is reported by the cost plan below.
				var fixed_recipient: Unit = _state.unit_by_id(card.partner_unit_id)
				if _is_present(fixed_recipient) and fixed_recipient.hp >= fixed_recipient.hp_max:
					return CardCostPlan.Reason.NO_LEGAL_TARGET
			elif _legal_targets_for_heal(card).is_empty():
				return CardCostPlan.Reason.NO_LEGAL_TARGET
		Card.Category.PERMANENT_AFFINITY_WRITE:
			pass
		_:
			# story-011: new categories cannot be resolved yet (017~019); not playable.
			push_error("CardPlaySession.is_card_playable: unhandled category %s" % card.category)
			return CardCostPlan.Reason.UNRESOLVED_CATEGORY
	return _build_cost_plan(card, -1, true).reason


## story-015: the cost [param card] would charge if confirmed now with
## [param caster_id] as the payer for cards whose [member Card.named_unit_id] is < 1.
## This is the SAME object [method confirm] settles from (one builder,
## [method _build_cost_plan]) — a confirm panel must read this, never recompute.
func preview_cost(card: Card, caster_id: int = -1) -> CardCostPlan:
	return _build_cost_plan(card, caster_id, false)


## Returns the set of unit ids [method select_target] (at
## [constant Step.SELECTING_TARGET]) or [method select_second_target] (at
## [constant Step.SELECTING_TARGET_B]) would currently accept — empty outside
## those two steps.
##
## For a [constant Card.Category.TEMPORARY_STAT_MODIFIER] card, this is every
## currently-alive PLAYER unit (GDD Data Requirements: "甲類=我方單位") — or,
## if the card names a unit ([member Card.named_unit_id], story 009), ONLY that
## unit when alive, else empty; with [constant Card.NamedMode.EXCLUDE], every
## alive PLAYER unit except that one.
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
			match _selected_card.category:
				Card.Category.TEMPORARY_STAT_MODIFIER:
					return _legal_targets_for_stat_card(_selected_card)
				Card.Category.PERMANENT_AFFINITY_WRITE:
					return _s2p_legal_first_targets()
				Card.Category.HEAL:
					return _legal_targets_for_heal(_selected_card)
				_:
					push_error("CardPlaySession.legal_targets: unhandled category %s" % _selected_card.category)
					return []
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
	match _selected_card.category:
		Card.Category.PERMANENT_AFFINITY_WRITE:
			_selected_target_a = unit_id
			_step = Step.SELECTING_TARGET_B
		Card.Category.TEMPORARY_STAT_MODIFIER, Card.Category.HEAL:
			_selected_target_a = unit_id
			_step = Step.CONFIRMING
		_:
			push_error("CardPlaySession.select_target: unhandled category %s" % _selected_card.category)
			return false
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

	# story-010 / ADR-0001 path 6: every write below happens inside ONE
	# BattleState.commit_authoritative_change() call (the shared entry), so
	# combat_state_version rises by exactly 1 per confirmed card, whatever its
	# category. Everything that can be validated is validated BEFORE the
	# window opens; a failure here leaves the version untouched.
	if not _deck.hand().has(_selected_card):
		push_error(
			"CardPlaySession.confirm: selected card '%s' is no longer in the hand" % _selected_card.id
		)
		return false
	# story-011 (F3): the category is dispatched with an explicit match; any
	# category this class cannot resolve yet is rejected HERE, before the commit
	# window opens -- nothing consumed, no modifier attached, version untouched.
	var category: Card.Category = _selected_card.category
	var fixed_targets: bool = _is_fixed_target_card(_selected_card)
	var recipient_ids: Array[int] = []
	var heal_recipient: Unit = null
	match category:
		Card.Category.TEMPORARY_STAT_MODIFIER:
			recipient_ids.append(_selected_target_a)
			if fixed_targets:
				recipient_ids.append(_selected_target_b)
			for recipient_id: int in recipient_ids:
				if _state.unit_by_id(recipient_id) == null:
					push_error("CardPlaySession.confirm: target unit %d does not exist" % recipient_id)
					return false
		Card.Category.HEAL:
			heal_recipient = _state.unit_by_id(_selected_target_b if fixed_targets else _selected_target_a)
			# story-017: validated BEFORE the window (and before any cost): present and wounded.
			if not _is_present(heal_recipient) or heal_recipient.hp >= heal_recipient.hp_max:
				push_error("CardPlaySession.confirm: heal recipient is absent or not wounded")
				return false
			if not fixed_targets and not _legal_targets_for_heal(_selected_card).has(heal_recipient.id):
				push_error("CardPlaySession.confirm: heal recipient %d is not a legal target" % heal_recipient.id)
				return false
		Card.Category.PERMANENT_AFFINITY_WRITE:
			pass
		_:
			push_error(
				"CardPlaySession.confirm: category %s of card '%s' is not resolvable yet"
				% [category, _selected_card.id]
			)
			return false

	# story-015: validate the COST before the window opens (payer/partner present,
	# distance, hp > cost, wear cap, relation state S). A failure here writes nothing:
	# no hp, no wear, card stays in hand, version untouched. Nothing inside the window
	# below may fail on cost grounds -- that is what makes "pay, then the effect
	# refuses" unreachable (TD ruling 2026-11-17).
	var cost_plan: CardCostPlan = _build_cost_plan(_selected_card, _selected_target_a, false)
	if not _validate_cost_before_window(cost_plan):
		return false

	# Lambdas capture primitives by value; a one-element array carries the result out.
	var rejection_box: Array[int] = [AffinityWritePort.Rejection.NONE]
	_state.commit_authoritative_change(func() -> void:
		# 甲類 has no rejection path, so its cost is taken first (cost, then effect).
		# 丙類's affinity write stays the FIRST write of the window (it can be rejected
		# by the port) and its cost is taken only after that write was accepted.
		if category != Card.Category.PERMANENT_AFFINITY_WRITE:
			_apply_cost_in_window(cost_plan)
		match category:
			Card.Category.PERMANENT_AFFINITY_WRITE:
				# TD ruling 2026-11-17: the affinity write MUST stay the FIRST
				# write in this window for 丙類 (rejection must precede any write).
				rejection_box[0] = PermanentAffinityWriteRules.play(
					_selected_card, _selected_target_a, _selected_target_b, _links, _write_port
				)
				# The port's own rejection (liveness, magnitude) can only be
				# known by calling it, so it is decided inside the window; nothing
				# has been written yet at that point, so we simply stop here.
				if rejection_box[0] != AffinityWritePort.Rejection.NONE:
					return
				_apply_cost_in_window(cost_plan)
			Card.Category.TEMPORARY_STAT_MODIFIER:
				_attach_stat_modifiers(_selected_card, recipient_ids)
			Card.Category.HEAL:
				_apply_heal_in_window(heal_recipient, _heal_amount(heal_recipient, _selected_card.effect_value))
			_:
				# Unreachable: filtered before the window opened. Loud, writes nothing.
				push_error("CardPlaySession.confirm: unhandled category %s inside the commit window" % category)
				return
		if not _deck.play_card(_selected_card):
			push_error(
				"CardPlaySession.confirm: play_card('%s') failed inside the commit window" % _selected_card.id
			)
	)
	if rejection_box[0] != AffinityWritePort.Rejection.NONE:
		return false
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
			if _is_fixed_target_card(_selected_card):
				# F9: no target was ever picked, so cancelling steps back to the hand.
				_selected_card = null
				_selected_target_a = -1
				_selected_target_b = -1
				_step = Step.SELECTING_CARD
				return
			match _selected_card.category:
				Card.Category.PERMANENT_AFFINITY_WRITE:
					_selected_target_b = -1
					_step = Step.SELECTING_TARGET_B
				Card.Category.TEMPORARY_STAT_MODIFIER, Card.Category.HEAL:
					_selected_target_a = -1
					_step = Step.SELECTING_TARGET
				_:
					push_error("CardPlaySession.cancel: unhandled category %s" % _selected_card.category)
					_reset_to_closed()
		Step.CLOSED:
			pass


# ---- story-015: cost settlement ---------------------------------------------
# Every method below up to _apply_cost_in_window is a deliberate seam: tests'
# sensitivity-proof subclasses override exactly one of them to plant a defect.

## The ONE builder both [method preview_cost] and [method confirm] use. Pure read:
## writes nothing. [param allow_unknown_payer]: for a card whose named_unit_id < 1
## and no caster yet (card selection stage) the payer-dependent checks are deferred.
func _build_cost_plan(card: Card, caster_id: int, allow_unknown_payer: bool) -> CardCostPlan:
	match card.cost_type:
		Card.CostType.NONE:
			return CardCostPlan.new()
		Card.CostType.HP, Card.CostType.PAIR:
			pass
		_:
			return CardCostPlan.rejected(CardCostPlan.Reason.UNSUPPORTED_COST_TYPE)
	var payers: Array[int] = CardCostPlan.payers_of(card, caster_id)
	if payers.is_empty():
		if allow_unknown_payer and card.named_unit_id < 1:
			return CardCostPlan.new()
		return CardCostPlan.rejected(CardCostPlan.Reason.PAYER_MISSING)
	var is_pair: bool = card.cost_type == Card.CostType.PAIR
	var present: Array[int] = payers.duplicate()
	if is_pair and not present.has(card.partner_unit_id):
		present.append(card.partner_unit_id)
	for unit_id: int in present:
		if not _is_present(_state.unit_by_id(unit_id)):
			return CardCostPlan.rejected(CardCostPlan.Reason.PARTNER_ABSENT)
	var plan: CardCostPlan = CardCostPlan.new()
	plan.payer_ids = payers
	if not is_pair:
		plan.kind = CardCostPlan.Kind.HP
		plan.amount = card.cost_amount
		return _check_affordable(plan)
	if card.target_range >= 1:
		var distance: int = AffinityRules.manhattan_distance(
			_state.position_of(payers[0]), _state.position_of(card.partner_unit_id)
		)
		if not _within_range(distance, card.target_range):
			return CardCostPlan.rejected(CardCostPlan.Reason.OUT_OF_RANGE)
	var pair: Variant = CardCostPlan.pair_of_units(payers[0], card.partner_unit_id)
	if pair == null or _affinity_pool == null:
		return CardCostPlan.rejected(CardCostPlan.Reason.RELATION_UNRESOLVED)
	plan.pair = int(pair)
	plan.relation = _resolve_relation(plan.pair)
	if plan.relation == AffinityRelation.RelationState.NONE:
		plan.kind = CardCostPlan.Kind.HP
		plan.amount = _hp_cost_none()
		return _check_affordable(plan)
	if _state.pair_wear(plan.pair) >= _pair_cost_cap():
		return CardCostPlan.rejected(CardCostPlan.Reason.WEAR_CAP_REACHED)
	plan.kind = CardCostPlan.Kind.WEAR
	plan.amount = card.cost_amount
	return plan


func _check_affordable(plan: CardCostPlan) -> CardCostPlan:
	for unit_id: int in plan.payer_ids:
		if not _hp_affordable(_state.unit_by_id(unit_id).hp, plan.amount):
			return CardCostPlan.rejected(CardCostPlan.Reason.CANNOT_AFFORD_HP)
	return plan


## Paying HP must leave the payer alive: hp > cost, strictly (spec 4.1 / 6.1).
func _hp_affordable(hp: int, amount: int) -> bool:
	return hp > amount


## Relation state S of the pair, via the single shared judgment (never re-derived here).
func _resolve_relation(pair: int) -> int:
	return AffinityRelation.state_of(
		_affinity_pool, pair as AffinityTypes.Pair, _state.affinity_tuning.neutral_band()
	)


func _pair_cost_cap() -> int:
	return _cost_tuning.pair_cost_cap()


func _hp_cost_none() -> int:
	return _cost_tuning.hp_cost_none()


## Pre-window gate: false (nothing written anywhere) if the cost is not payable.
func _validate_cost_before_window(plan: CardCostPlan) -> bool:
	return plan.is_payable()


## Charges [param plan] INSIDE the commit window. Cannot fail on cost grounds: the plan
## was validated before the window opened.
func _apply_cost_in_window(plan: CardCostPlan) -> void:
	if not plan.is_payable():
		push_error("CardPlaySession._apply_cost_in_window: unpayable plan reached the commit window")
		return
	match plan.kind:
		CardCostPlan.Kind.HP:
			for unit_id: int in plan.payer_ids:
				_pay_hp(_state.unit_by_id(unit_id), plan.amount)
		CardCostPlan.Kind.WEAR:
			_state.add_pair_wear(plan.pair, plan.amount, _pair_cost_cap())
		_:
			pass


## HP payment goes through the GUARDED hp setter (not take_damage(), which bypasses the
## guard and would run death cleanup).
func _pay_hp(unit: Unit, amount: int) -> void:
	unit.hp = unit.hp - amount


# ---- story-017: heal and two-person buff cards ---------------------------------
# The seams below (_within_range / _is_present / _heal_amount / _apply_heal_in_window /
# _attach_stat_modifiers) are where tests plant one defect each.

## F9: true when the card face fixes its targets -- a PAIR-cost card (HEAL or 甲類) with
## both [member Card.named_unit_id] (payer) and [member Card.partner_unit_id] set. Such a
## card has no target-selection step: the session goes straight to CONFIRMING.
func _is_fixed_target_card(card: Card) -> bool:
	if card.cost_type != Card.CostType.PAIR:
		return false
	if card.named_unit_id < 1 or card.partner_unit_id < 1:
		return false
	return card.category == Card.Category.TEMPORARY_STAT_MODIFIER or card.category == Card.Category.HEAL


## 2026-11-18 ruling: an HP-cost card with a fixed payer, no partner and target_range >= 1
## (c04, c07) lets the player pick ONE ally within range of the payer; the payer is excluded.
func _is_ranged_pick_card(card: Card) -> bool:
	if card.cost_type != Card.CostType.HP:
		return false
	if card.named_unit_id < 1 or card.partner_unit_id >= 1 or card.target_range < 1:
		return false
	return card.category == Card.Category.TEMPORARY_STAT_MODIFIER or card.category == Card.Category.HEAL


## Alive PLAYER allies, not the payer, within target_range of the payer (distance from the
## single shared [method AffinityRules.manhattan_distance]). [param wounded_only]: heal rule 6.
func _ranged_pick_candidates(card: Card, wounded_only: bool) -> Array[int]:
	var result: Array[int] = []
	var payer: Unit = _state.unit_by_id(card.named_unit_id)
	if not _is_present(payer) or payer.faction != Unit.Faction.PLAYER:
		return result
	var origin: Vector2i = _state.position_of(payer.id)
	for ally: Unit in _state.units_of(Unit.Faction.PLAYER):
		if ally.id == payer.id:
			continue
		if wounded_only and ally.hp >= ally.hp_max:
			continue
		var distance: int = AffinityRules.manhattan_distance(origin, _state.position_of(ally.id))
		if _within_range(distance, card.target_range):
			result.append(ally.id)
	return result


## Legal heal recipients. Fixed-recipient card: the partner when present and wounded.
## Ranged-pick card: wounded allies in range, payer excluded. Any other HEAL shape has no
## legal recipient (data error -> unplayable, never a silent self-heal).
func _legal_targets_for_heal(card: Card) -> Array[int]:
	var result: Array[int] = []
	if _is_fixed_target_card(card):
		var fixed: Unit = _state.unit_by_id(card.partner_unit_id)
		if _is_present(fixed) and fixed.hp < fixed.hp_max:
			result.append(fixed.id)
		return result
	if _is_ranged_pick_card(card):
		return _ranged_pick_candidates(card, true)
	return result


func _within_range(distance: int, range_limit: int) -> bool:
	return distance <= range_limit


func _is_present(unit: Unit) -> bool:
	return unit != null and unit.is_alive()


## Spec rule 8: min(effect_value, hp_max - hp).
func _heal_amount(unit: Unit, effect_value: int) -> int:
	return mini(effect_value, unit.hp_max - unit.hp)


## Heal goes through the GUARDED hp setter (inside the commit window), never take_damage().
func _apply_heal_in_window(unit: Unit, amount: int) -> void:
	unit.hp = unit.hp + amount


## One CardModifier per recipient (a fresh instance each; fields copied from the card).
func _attach_stat_modifiers(card: Card, unit_ids: Array[int]) -> void:
	for unit_id: int in unit_ids:
		_state.unit_by_id(unit_id).add_modifier(CardModifier.new(
			card.id, card.delta_atk, card.delta_def, card.duration_rounds
		))


func _is_authoritative_write_in_progress() -> bool:
	if not _authoritative_write_in_progress_check.is_valid():
		return false
	return bool(_authoritative_write_in_progress_check.call())


func _legal_targets_for_stat_card(card: Card) -> Array[int]:
	if _is_ranged_pick_card(card):
		return _ranged_pick_candidates(card, false)
	var alive: Array[int] = _alive_player_unit_ids()
	if card.named_unit_id == Card.UNRESTRICTED_TARGET:
		return alive
	if card.named_mode == Card.NamedMode.EXCLUDE:
		# 排除模式:存活我方 − 點名者。點名者倒下不影響其他人可選。
		var others: Array[int] = []
		for unit_id: int in alive:
			if unit_id != card.named_unit_id:
				others.append(unit_id)
		return others
	var restricted: Array[int] = []
	if alive.has(card.named_unit_id):
		restricted.append(card.named_unit_id)
	return restricted


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
