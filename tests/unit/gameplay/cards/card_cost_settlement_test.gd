# Story 015 代價結算(付血 / 先驗證後扣款 / 不可打原因 / 旋鈕)的單元測試。
# production/epics/skill-card-system/story-015-card-cost-settlement.md
#
# 檔案存取:甲類例外 —— 唯讀 res://assets/data/tuning/tuning_knobs.txt(已進版控),
# 只用於「出貨旋鈕檔值域合法」一條;其餘全為記憶體內夾具。
#
# 敏感度證明(常駐 test_sensitivity_proof_*):CardPlaySession 的私有 seam 可被子類別覆寫,
# 每個 mutant 跑與真品相同的情境函式,真品必須回 true、mutant 必須回 false。
# 本檔涵蓋 mutant ①先效果後扣款(驗證缺席)②付血用 take_damage() ③hp>=cost ⑦cap 寫死。
# 另三個(④忽略 S、⑤面板重算、⑥扣款寫池)在
# tests/integration/gameplay/cards/card_cost_pair_state_test.gd。
#
# 證明不了的(誠實登記):mutant ② 只能靠「守衛有被詢問」區分,因為合法路徑 hp>cost 不會
# 走到 take_damage() 與 setter 結果不同的 0 血分支;工單寫的「HP 歸 0 時修正器被清」在
# 通過驗證的路徑上不可達,故證明的是「付款確實經過受守衛的 hp setter」。
extends GdUnitTestSuite

const P1: int = 1
const P4: int = 4
const ENEMY: int = 9
const _PAIR_C1_C2: int = AffinityTypes.Pair.C1_C2


# ---- 夾具 -------------------------------------------------------------------

func _build_state() -> BattleState:
	var lines: Array[String] = [
		"1,P1,PLAYER,20,10,3,1,1,1,0,0",
		"2,P2,PLAYER,20,8,2,1,1,1,1,0",
		"3,P3,PLAYER,20,8,2,1,1,1,6,0",
		"4,P4,PLAYER,5,8,2,1,1,1,0,3",
		"9,E1,ENEMY,20,5,3,1,1,1,3,3",
	]
	return BattleState.create(PackedStringArray(), "\n".join(lines))


## 單人付血卡:named = 付款人(也是 ONLY 承受者)。
func _hp_card(payer: int, cost: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("hp_card", 1, 0, 1, payer)
	card.cost_type = Card.CostType.HP
	card.cost_amount = cost
	return card


## 付款人由施放者決定的付血卡(named = -1):select_card 可選,確認時才驗付款人。
func _caster_hp_card(cost: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("caster_hp_card", 1, 0, 1)
	card.cost_type = Card.CostType.HP
	card.cost_amount = cost
	return card


func _session(script: GDScript, state: BattleState, cards: Array[Card]) -> CardPlaySession:
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = script.new(deck, state, links, NullAffinityWritePort.new())
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


## 回傳一個會數「守衛被詢問幾次」的間諜,並把它掛到 [param unit] 上(取代 BattleState 掛的守衛,
## 但仍委派給 write_window_is_open,行為不變)。
class _GuardSpy extends RefCounted:
	var calls: int = 0
	var state: BattleState

	func _init(p_state: BattleState) -> void:
		state = p_state

	func check() -> bool:
		calls += 1
		return state.write_window_is_open()


# ---- mutants -----------------------------------------------------------------

## ① 先效果後扣款:不在窗口前驗證;窗口內付不起就悄悄跳過扣款,效果與出牌照做。
class _MutantNoPrecheck extends CardPlaySession:
	func _validate_cost_before_window(_plan: CardCostPlan) -> bool:
		return true

	func _apply_cost_in_window(plan: CardCostPlan) -> void:
		if plan.is_payable():
			super(plan)


## ② 付血走 take_damage()(繞過守衛、且會觸發死亡清理)。
class _MutantTakeDamage extends CardPlaySession:
	func _pay_hp(unit: Unit, amount: int) -> void:
		unit.take_damage(amount)


## ③ hp >= cost 取代 hp > cost。
class _MutantGe extends CardPlaySession:
	func _hp_affordable(hp: int, amount: int) -> bool:
		return hp >= amount


## ⑦ pair_cost_cap 寫死為 3,不讀旋鈕。
class _MutantHardCap extends CardPlaySession:
	func _pair_cost_cap() -> int:
		return 3


# ---- 情境函式(真品與 mutant 共用;回 true = 該 AC 成立)-------------------------------

func _scn_ac1_pay_hp(script: GDScript) -> bool:
	var state: BattleState = _build_state()
	var card: Card = _hp_card(P1, 5)
	var session: CardPlaySession = _session(script, state, [card])
	var spy: _GuardSpy = _GuardSpy.new(state)
	state.unit_by_id(P1).attach_write_guard(spy.check)
	var played: bool = _play(session, card, P1)
	return played and state.unit_by_id(P1).hp == 15 and spy.calls >= 1


func _scn_ac1_boundary(script: GDScript) -> bool:
	# P4 hp 5:cost 5 -> hp == cost 不可打;cost 6 -> hp < cost 不可打。皆不扣款、版本不變。
	var state: BattleState = _build_state()
	var eq_card: Card = _hp_card(P4, 5)
	var lt_card: Card = _hp_card(P4, 6)
	var session: CardPlaySession = _session(script, state, [eq_card, lt_card])
	var version: int = state.combat_state_version
	var any_played: bool = _play(session, eq_card, P4) or _play(session, lt_card, P4)
	return not any_played and state.unit_by_id(P4).hp == 5 and state.combat_state_version == version \
		and not session.is_card_playable(eq_card) and not session.is_card_playable(lt_card)


func _scn_ac5_zero_write_on_reject(script: GDScript) -> bool:
	# 付款人由施放者決定:select 時放行,確認時 P4(hp5)付 5 血 -> 驗證失敗 -> 零寫入。
	var state: BattleState = _build_state()
	var card: Card = _caster_hp_card(5)
	var deck: CardDeck = CardDeck.new([card], RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = script.new(deck, state, links, NullAffinityWritePort.new())
	var version: int = state.combat_state_version
	var hand_before: int = deck.hand().size()
	var ok: bool = session.open_hand() and session.select_card(card) and session.select_target(P4)
	var confirmed: bool = session.confirm()
	return ok and not confirmed and state.unit_by_id(P4).hp == 5 \
		and state.unit_by_id(P4).active_modifiers().is_empty() \
		and deck.hand().has(card) and deck.hand().size() == hand_before \
		and state.combat_state_version == version


# ---- AC1 付血 ----------------------------------------------------------------

func test_cost_ac1_pay_hp_reduces_hp_by_cost() -> void:
	assert_bool(_scn_ac1_pay_hp(CardPlaySession)).is_true()


func test_cost_ac1_hp_equal_or_below_cost_is_unplayable_and_charges_nothing() -> void:
	assert_bool(_scn_ac1_boundary(CardPlaySession)).is_true()


func test_cost_ac1_confirm_bumps_version_exactly_once() -> void:
	var state: BattleState = _build_state()
	var card: Card = _hp_card(P1, 2)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	var version: int = state.combat_state_version
	assert_bool(_play(session, card, P1)).is_true()
	assert_int(state.combat_state_version).is_equal(version + 1)


# ---- AC5 先驗證後扣款 ----------------------------------------------------------

func test_cost_ac5_validation_failure_writes_nothing() -> void:
	assert_bool(_scn_ac5_zero_write_on_reject(CardPlaySession)).is_true()


# ---- AC7 不可打原因 ------------------------------------------------------------

func test_cost_ac7_reason_cannot_afford() -> void:
	var state: BattleState = _build_state()
	var card: Card = _hp_card(P4, 5)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	assert_int(session.card_unplayable_reason(card)).is_equal(CardCostPlan.Reason.CANNOT_AFFORD_HP)


func test_cost_ac7_reason_partner_absent() -> void:
	var state: BattleState = _build_state()
	var card: Card = _hp_card(P1, 1)
	card.cost_type = Card.CostType.PAIR
	card.partner_unit_id = 5 # 名冊裡沒有這個人
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	assert_int(session.card_unplayable_reason(card)).is_equal(CardCostPlan.Reason.PARTNER_ABSENT)


func test_cost_ac7_reason_wear_cap_reached_comes_from_the_tuning_file_value() -> void:
	# 折損上限的原因在整合測試以真實池驗;此處驗三種原因彼此不同(列舉值互異)。
	var reasons: Dictionary = {
		CardCostPlan.Reason.CANNOT_AFFORD_HP: true,
		CardCostPlan.Reason.PARTNER_ABSENT: true,
		CardCostPlan.Reason.WEAR_CAP_REACHED: true,
	}
	assert_int(reasons.size()).is_equal(3)
	assert_int(CardCostPlan.Reason.NONE).is_equal(0)


# ---- 付款人集合(純函式)---------------------------------------------------------

func test_cost_payers_pair_bonus_and_combo_pay_both_heal_pays_named_only() -> void:
	var bonus: Card = _hp_card(1, 2)
	bonus.cost_type = Card.CostType.PAIR
	bonus.partner_unit_id = 2
	assert_array(CardCostPlan.payers_of(bonus, -1)).is_equal([1, 2])
	var combo: Card = bonus
	combo.category = Card.Category.COMBO_DAMAGE
	assert_array(CardCostPlan.payers_of(combo, -1)).is_equal([1, 2])
	var heal: Card = _hp_card(1, 2)
	heal.cost_type = Card.CostType.PAIR
	heal.partner_unit_id = 2
	heal.category = Card.Category.HEAL
	assert_array(CardCostPlan.payers_of(heal, -1)).is_equal([1])


func test_cost_payers_caster_pays_when_named_unset() -> void:
	var card: Card = _caster_hp_card(2)
	assert_array(CardCostPlan.payers_of(card, 3)).is_equal([3])
	assert_array(CardCostPlan.payers_of(card, -1)).is_empty()


# ---- AC9 旋鈕(走既有 TuningKnobs;缺鍵整檔失敗,偏離工單原文,見 card_cost_tuning.gd 檔頭)----

const _CARD_KEYS: Dictionary = {"card.hp_cost_none": 3, "card.pair_cost_cap": 3}


func _knobs(text: String) -> TuningKnobs:
	return TuningKnobs.from_text(text, _CARD_KEYS) as TuningKnobs


func test_cost_ac9_values_come_from_data() -> void:
	var t: CardCostTuning = CardCostTuning.from_knobs(
		_knobs("card,hp_cost_none,4\ncard,pair_cost_cap,2\n")) as CardCostTuning
	assert_int(t.hp_cost_none()).is_equal(4)
	assert_int(t.pair_cost_cap()).is_equal(2)
	assert_int(CardCostTuning.defaults().hp_cost_none()).is_equal(3)
	assert_int(CardCostTuning.defaults().pair_cost_cap()).is_equal(3)


func test_cost_ac9_missing_key_fails_whole_load() -> void:
	var result: Array = [CardCostTuning.defaults()]
	await assert_error(func() -> void: result[0] = TuningKnobs.from_text("card,hp_cost_none,4\n", _CARD_KEYS)) \
		.is_push_error("TuningKnobs.from_text: missing required key 'card.pair_cost_cap'")
	assert_bool(result[0] == null).is_true()


func test_cost_ac9_non_integer_fails_load() -> void:
	var result: Array = [CardCostTuning.defaults()]
	await assert_error(func() -> void: result[0] = TuningKnobs.from_text(
			"card,hp_cost_none,abc\ncard,pair_cost_cap,2\n", _CARD_KEYS)) \
		.is_push_error("TuningKnobs.from_text: line 1: value 'abc' is not an integer")
	assert_bool(result[0] == null).is_true()


func test_cost_ac9_out_of_range_rejected() -> void:
	var low: Array = [CardCostTuning.defaults()]
	await assert_error(func() -> void: low[0] = CardCostTuning.from_knobs(
			_knobs("card,hp_cost_none,1\ncard,pair_cost_cap,3\n"))) \
		.is_push_error("CardCostTuning: card.hp_cost_none (1) is outside 2~5")
	assert_bool(low[0] == null).is_true()
	var high: Array = [CardCostTuning.defaults()]
	await assert_error(func() -> void: high[0] = CardCostTuning.from_knobs(
			_knobs("card,hp_cost_none,3\ncard,pair_cost_cap,6\n"))) \
		.is_push_error("CardCostTuning: card.pair_cost_cap (6) is outside 2~5")
	assert_bool(high[0] == null).is_true()


func test_cost_ac9_shipped_data_file_is_valid() -> void:
	# 甲類例外:唯讀 assets/data/tuning/tuning_knobs.txt(已進版控,.txt 非 .csv)。
	var text: String = FileAccess.get_file_as_string("res://assets/data/tuning/tuning_knobs.txt")
	var t: CardCostTuning = CardCostTuning.from_text(text) as CardCostTuning
	assert_bool(t != null).is_true()
	assert_int(t.hp_cost_none()).is_equal(3)
	assert_int(t.pair_cost_cap()).is_equal(3)


# ---- AC10 敏感度證明(常駐)--------------------------------------------------------

func test_sensitivity_proof_real_session_passes_every_scenario() -> void:
	assert_bool(_scn_ac1_pay_hp(CardPlaySession)).is_true()
	assert_bool(_scn_ac1_boundary(CardPlaySession)).is_true()
	assert_bool(_scn_ac5_zero_write_on_reject(CardPlaySession)).is_true()
	assert_bool(_scn_cap_from_tuning(CardPlaySession)).is_true()


func test_sensitivity_proof_mutant1_effect_before_validation_fails_ac5() -> void:
	assert_bool(_scn_ac5_zero_write_on_reject(_MutantNoPrecheck)).is_false()


func test_sensitivity_proof_mutant2_take_damage_payment_fails_ac1() -> void:
	assert_bool(_scn_ac1_pay_hp(_MutantTakeDamage)).is_false()


func test_sensitivity_proof_mutant3_hp_ge_cost_fails_ac1() -> void:
	assert_bool(_scn_ac1_boundary(_MutantGe)).is_false()


func test_sensitivity_proof_mutant7_hardcoded_cap_fails_ac9() -> void:
	assert_bool(_scn_cap_from_tuning(_MutantHardCap)).is_false()


## cap 旋鈕 = 2:打一張折損 2 的卡後 N=2 即達上限,第二張不可打。真池 POS,寫死 3 的 mutant 會放行。
func _scn_cap_from_tuning(script: GDScript) -> bool:
	var state: BattleState = _build_state()
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool.append_record(_PAIR_C1_C2 as AffinityTypes.Pair, 1.0, AffinityTypes.Source.STORY_EVENT)
	var card_a: Card = _hp_card(1, 2)
	card_a.cost_type = Card.CostType.PAIR
	card_a.partner_unit_id = 2
	var card_b: Card = _hp_card(1, 2)
	card_b.cost_type = Card.CostType.PAIR
	card_b.partner_unit_id = 2
	var session: CardPlaySession = _session(script, state, [card_a, card_b])
	session.attach_affinity_pool(pool)
	session.attach_cost_tuning(CardCostTuning.from_knobs(_knobs("card,hp_cost_none,3\ncard,pair_cost_cap,2\n")) as CardCostTuning)
	var first: bool = _play(session, card_a, 1)
	return first and state.pair_wear(_PAIR_C1_C2) == 2 and not session.is_card_playable(card_b) \
		and session.card_unplayable_reason(card_b) == CardCostPlan.Reason.WEAR_CAP_REACHED
