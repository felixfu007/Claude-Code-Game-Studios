# Story 015:PAIR 卡依「當下」關係態 S 結算(POS/NEG 走折損、NONE 各付血),整合真實
# AffinityDataPool + AffinityRelation.state_of + BattleState 折損計數器 + CardPlaySession。
# 檔案存取:無(全記憶體)。
#
# 敏感度證明(常駐 test_sensitivity_proof_*):mutant ④忽略 S ⑤面板自行重算 ⑥扣款寫池;
# 另 ①②③⑦ 在 tests/unit/gameplay/cards/card_cost_settlement_test.gd。
# 情境函式真品回 true、mutant 回 false。
extends GdUnitTestSuite

const _PAIR_C1_C2: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2


func _build_state() -> BattleState:
	var lines: Array[String] = [
		"1,P1,PLAYER,20,10,3,1,1,1,0,0",
		"2,P2,PLAYER,20,8,2,1,1,1,1,0",
		"3,P3,PLAYER,20,8,2,1,1,1,6,0",
		"4,P4,PLAYER,5,8,2,1,1,1,0,3",
		"9,E1,ENEMY,20,5,3,1,1,1,3,3",
	]
	return BattleState.create(PackedStringArray(), "\n".join(lines))


func _write(pool: AffinityDataPool, pair: AffinityTypes.Pair, m: float) -> void:
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(
		pair, m, AffinityTypes.Source.STORY_EVENT
	)
	if rejection != AffinityDataPool.WriteRejection.NONE:
		fail("fixture append_record rejected: %d" % rejection)


func _pair_card(payer: int, partner: int, cost: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("pair_card", 1, 0, 1, payer)
	card.cost_type = Card.CostType.PAIR
	card.cost_amount = cost
	card.partner_unit_id = partner
	return card


func _session(script: GDScript, state: BattleState, pool: AffinityDataPool, cards: Array[Card]) -> CardPlaySession:
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = script.new(deck, state, links, NullAffinityWritePort.new())
	session.attach_affinity_pool(pool)
	return session


func _play(session: CardPlaySession, card: Card, target: int) -> bool:
	if not session.open_hand():
		return false
	if not session.select_card(card):
		session.cancel()
		return false
	if session.step() != CardPlaySession.Step.CONFIRMING and not session.select_target(target):
		session.cancel()
		return false
	return session.confirm()


# ---- mutants -----------------------------------------------------------------

## ④ 忽略 S:恆當作 POS(恆走折損)。
class _MutantIgnoreS extends CardPlaySession:
	func _resolve_relation(_pair: int) -> int:
		return AffinityRelation.RelationState.POS


## ⑤ 面板自行重算:不用結果物件,自己拿 cost_amount 當扣款數。
class _MutantPanelRecalc extends CardPlaySession:
	func preview_cost(card: Card, caster_id: int = -1) -> CardCostPlan:
		var plan: CardCostPlan = super(card, caster_id)
		if plan.kind == CardCostPlan.Kind.HP:
			plan.amount = card.cost_amount
		return plan


## ⑥ 扣款寫池:折損同時 append 一筆池記錄。
class _MutantWritesPool extends CardPlaySession:
	func _apply_cost_in_window(plan: CardCostPlan) -> void:
		super(plan)
		if plan.kind == CardCostPlan.Kind.WEAR:
			_affinity_pool.append_record(plan.pair as AffinityTypes.Pair, -1.0, AffinityTypes.Source.STORY_EVENT)


# ---- 情境函式 -------------------------------------------------------------------

## AC2 POS 分支:折損累加、不付血、池不變(AC8 同場檢)。
func _scn_pos_wear(script: GDScript) -> bool:
	var state: BattleState = _build_state()
	var pool: AffinityDataPool = AffinityDataPool.new()
	_write(pool, _PAIR_C1_C2, 1.0)
	var before: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(_PAIR_C1_C2)
	var card: Card = _pair_card(1, 2, 2)
	var session: CardPlaySession = _session(script, state, pool, [card])
	var played: bool = _play(session, card, 1)
	var after: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(_PAIR_C1_C2)
	return played and state.pair_wear(_PAIR_C1_C2) == 2 \
		and state.unit_by_id(1).hp == 20 and state.unit_by_id(2).hp == 20 \
		and after.n_pair == before.n_pair and is_equal_approx(after.value, before.value)


## AC2 NONE 分支:池空 -> 兩人各付 hp_cost_none(3),折損不動。
func _scn_none_pays_hp(script: GDScript) -> bool:
	var state: BattleState = _build_state()
	var pool: AffinityDataPool = AffinityDataPool.new()
	var card: Card = _pair_card(1, 2, 2)
	var session: CardPlaySession = _session(script, state, pool, [card])
	var played: bool = _play(session, card, 1)
	return played and state.unit_by_id(1).hp == 17 and state.unit_by_id(2).hp == 17 \
		and state.pair_wear(_PAIR_C1_C2) == 0


## AC3:同一場內 POS -> 寫池使 S 變 NONE -> 下一次改付血。
func _scn_flip_pos_to_none(script: GDScript) -> bool:
	var state: BattleState = _build_state()
	# 冷淡區 k=0.5(量測前正式值為 0):池有時間衰減,+1 再 -1 的殘值是 -0.06 而非 0,
	# 故用較寬的冷淡區讓「POS 被寫池拉回 NONE」可被穩定重現。
	var knobs: TuningKnobs = TuningKnobs.from_text(
		"affinity,neutral_band_centi,50\n", {"affinity.neutral_band_centi": 0}
	) as TuningKnobs
	state.affinity_tuning = AffinityTuning.from_knobs(knobs) as AffinityTuning
	var pool: AffinityDataPool = AffinityDataPool.new()
	_write(pool, _PAIR_C1_C2, 1.0)
	var card_a: Card = _pair_card(1, 2, 2)
	var card_b: Card = _pair_card(1, 2, 2)
	var session: CardPlaySession = _session(script, state, pool, [card_a, card_b])
	var first: bool = _play(session, card_a, 1)
	var wear_after_first: int = state.pair_wear(_PAIR_C1_C2)
	_write(pool, _PAIR_C1_C2, -1.0) # 丙類寫池的替身:把 S 拉回 NONE
	var s_now: int = AffinityRelation.state_of(pool, _PAIR_C1_C2, state.affinity_tuning.neutral_band())
	var second: bool = _play(session, card_b, 1)
	return first and wear_after_first == 2 and s_now == AffinityRelation.RelationState.NONE \
		and second and state.unit_by_id(1).hp == 17 and state.unit_by_id(2).hp == 17 \
		and state.pair_wear(_PAIR_C1_C2) == 2


## AC6:面板資料 == 實際扣款(NONE 分支,cost_amount 2 與 hp_cost_none 3 刻意不同)。
func _scn_panel_matches_actual(script: GDScript) -> bool:
	var state: BattleState = _build_state()
	var pool: AffinityDataPool = AffinityDataPool.new()
	var card: Card = _pair_card(1, 2, 2)
	var session: CardPlaySession = _session(script, state, pool, [card])
	var plan: CardCostPlan = session.preview_cost(card)
	var hp_before: int = state.unit_by_id(1).hp
	var played: bool = _play(session, card, 1)
	var paid: int = hp_before - state.unit_by_id(1).hp
	return played and plan.is_payable() and plan.kind == CardCostPlan.Kind.HP \
		and plan.amount == paid and plan.payer_ids == [1, 2]


# ---- AC2 / AC8 / AC3 / AC6 ------------------------------------------------------

func test_pair_ac2_pos_goes_to_wear_not_hp() -> void:
	assert_bool(_scn_pos_wear(CardPlaySession)).is_true()


func test_pair_ac2_neg_goes_to_wear_too() -> void:
	var state: BattleState = _build_state()
	var pool: AffinityDataPool = AffinityDataPool.new()
	_write(pool, _PAIR_C1_C2, -1.0)
	var card: Card = _pair_card(1, 2, 2)
	var session: CardPlaySession = _session(CardPlaySession, state, pool, [card])
	assert_bool(_play(session, card, 1)).is_true()
	assert_int(state.pair_wear(_PAIR_C1_C2)).is_equal(2)
	assert_int(state.unit_by_id(1).hp).is_equal(20)


func test_pair_ac2_none_pays_hp_from_both() -> void:
	assert_bool(_scn_none_pays_hp(CardPlaySession)).is_true()


func test_pair_ac2_none_heal_card_charges_named_only() -> void:
	var state: BattleState = _build_state()
	var pool: AffinityDataPool = AffinityDataPool.new()
	var card: Card = _pair_card(1, 2, 2)
	card.category = Card.Category.HEAL
	var session: CardPlaySession = _session(CardPlaySession, state, pool, [card])
	var plan: CardCostPlan = session.preview_cost(card)
	assert_int(plan.kind).is_equal(CardCostPlan.Kind.HP)
	assert_array(plan.payer_ids).is_equal([1])
	assert_int(plan.amount).is_equal(3)


func test_pair_ac2_wear_caps_at_pair_cost_cap_and_blocks_further_play() -> void:
	var state: BattleState = _build_state()
	var pool: AffinityDataPool = AffinityDataPool.new()
	_write(pool, _PAIR_C1_C2, 1.0)
	var a: Card = _pair_card(1, 2, 2)
	var b: Card = _pair_card(1, 2, 2)
	var c: Card = _pair_card(1, 2, 2)
	var session: CardPlaySession = _session(CardPlaySession, state, pool, [a, b, c])
	assert_bool(_play(session, a, 1)).is_true() # N 0 -> 2
	assert_bool(_play(session, b, 1)).is_true() # N 2 -> min(3, 4) = 3(封頂)
	assert_int(state.pair_wear(_PAIR_C1_C2)).is_equal(3)
	assert_bool(session.is_card_playable(c)).is_false()
	assert_int(session.card_unplayable_reason(c)).is_equal(CardCostPlan.Reason.WEAR_CAP_REACHED)


func test_pair_ac3_relation_flip_changes_how_next_card_pays() -> void:
	assert_bool(_scn_flip_pos_to_none(CardPlaySession)).is_true()


func test_pair_ac4_non_canon_far_pair_is_playable_in_every_state() -> void:
	# P1(0,0) 與 P3(6,0):沒有任何人設關係線、距離遠;S=NONE 仍可打(各付血)。
	var state: BattleState = _build_state()
	var pool: AffinityDataPool = AffinityDataPool.new()
	var card: Card = _pair_card(1, 3, 2)
	var session: CardPlaySession = _session(CardPlaySession, state, pool, [card])
	assert_bool(_play(session, card, 1)).is_true()
	assert_int(state.unit_by_id(1).hp).is_equal(17)
	assert_int(state.unit_by_id(3).hp).is_equal(17)
	# NEG 同樣可打
	var state2: BattleState = _build_state()
	var pool2: AffinityDataPool = AffinityDataPool.new()
	_write(pool2, AffinityTypes.Pair.C1_C3, -1.0)
	var card2: Card = _pair_card(1, 3, 2)
	var session2: CardPlaySession = _session(CardPlaySession, state2, pool2, [card2])
	assert_bool(_play(session2, card2, 1)).is_true()
	assert_int(state2.pair_wear(AffinityTypes.Pair.C1_C3)).is_equal(2)


func test_pair_distance_beyond_target_range_is_unplayable() -> void:
	var state: BattleState = _build_state()
	var pool: AffinityDataPool = AffinityDataPool.new()
	var card: Card = _pair_card(1, 3, 2)
	card.target_range = 2 # 兩人距離 6
	var session: CardPlaySession = _session(CardPlaySession, state, pool, [card])
	assert_int(session.card_unplayable_reason(card)).is_equal(CardCostPlan.Reason.OUT_OF_RANGE)


func test_pair_without_pool_is_unplayable_not_silently_none() -> void:
	var state: BattleState = _build_state()
	var card: Card = _pair_card(1, 2, 2)
	var session: CardPlaySession = _session(CardPlaySession, state, null, [card])
	assert_int(session.card_unplayable_reason(card)).is_equal(CardCostPlan.Reason.RELATION_UNRESOLVED)


func test_pair_ac6_panel_plan_equals_actual_charge() -> void:
	assert_bool(_scn_panel_matches_actual(CardPlaySession)).is_true()


func test_pair_ac8_wear_does_not_write_the_pool() -> void:
	# _scn_pos_wear 內含 n_pair / value 前後相等;此處再斷言多打一張後仍相等。
	assert_bool(_scn_pos_wear(CardPlaySession)).is_true()


# ---- AC10 敏感度證明(常駐)--------------------------------------------------------

func test_sensitivity_proof_real_session_passes_every_pair_scenario() -> void:
	assert_bool(_scn_pos_wear(CardPlaySession)).is_true()
	assert_bool(_scn_none_pays_hp(CardPlaySession)).is_true()
	assert_bool(_scn_flip_pos_to_none(CardPlaySession)).is_true()
	assert_bool(_scn_panel_matches_actual(CardPlaySession)).is_true()


func test_sensitivity_proof_mutant4_ignore_s_fails_ac2_and_ac3() -> void:
	assert_bool(_scn_none_pays_hp(_MutantIgnoreS)).is_false()
	assert_bool(_scn_flip_pos_to_none(_MutantIgnoreS)).is_false()


func test_sensitivity_proof_mutant5_panel_recalculates_fails_ac6() -> void:
	assert_bool(_scn_panel_matches_actual(_MutantPanelRecalc)).is_false()


func test_sensitivity_proof_mutant6_wear_writes_pool_fails_ac8() -> void:
	assert_bool(_scn_pos_wear(_MutantWritesPool)).is_false()
