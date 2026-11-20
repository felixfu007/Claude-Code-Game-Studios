# Story 020d 第 1 項:引擎補的 4 種不可打原因(UX 1.3 #6~#9)與補血預覽。
# production/epics/skill-card-system/story-020-card-confirm-panel-cost-and-unplayable-reason.md
#
# 檔案存取:無(記憶體內夾具,仿 card_combo_damage_test.gd)。
# 敏感度證明(常駐):mutant 讓「射程內有敵人但被擋」也回 NO_ENEMY_IN_RANGE(分不出 #6/#7),
# 真品情境必 true、mutant 必 false。其餘斷言為直接比對引擎回傳。
# 證明不了的:優先序疊加(成本原因先於 #6~#9)只測一對(夥伴不在場先於射程內無敵人),未逐對窮舉。
extends GdUnitTestSuite


## 讓 #7 退化成 #6 的 mutant。
class _MutantNoLosDistinction extends CardPlaySession:
	func _enemy_reach_reason(casters: Array[int]) -> CardCostPlan.Reason:
		if super(casters) != CardCostPlan.Reason.NONE:
			return CardCostPlan.Reason.NO_ENEMY_IN_RANGE
		return CardCostPlan.Reason.NONE


func _terrain(logs: Array[int]) -> PackedStringArray:
	var row: String = ""
	for x: int in range(13):
		row += "#" if logs.has(x) else "."
	var rows: PackedStringArray = PackedStringArray()
	rows.append(row)
	for i: int in range(5):
		rows.append(".............")
	return rows


func _state(p1x: int, p2x: int, enemy_x: int, rmax1: int, rmax2: int, logs: Array[int] = []) -> BattleState:
	var lines: Array[String] = []
	lines.append("1,P1,PLAYER,20,10,3,1,1,%d,%d,0" % [rmax1, p1x])
	lines.append("2,P2,PLAYER,20,10,3,1,1,%d,%d,0" % [rmax2, p2x])
	lines.append("9,E1,ENEMY,30,5,50,1,1,1,%d,0" % enemy_x)
	return BattleState.create(_terrain(logs), "\n".join(lines))


func _session(script: GDScript, state: BattleState, card: Card) -> CardPlaySession:
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = script.new(deck, state, links, NullAffinityWritePort.new())
	session.attach_affinity_pool(AffinityDataPool.new())
	return session


func _direct() -> Card:
	var card: Card = Card.new()
	card.id = "t020d_direct"
	card.category = Card.Category.DIRECT_DAMAGE
	card.cost_type = Card.CostType.NONE
	card.effect_value = 5
	card.named_unit_id = 1
	card.target_range = -1
	return card


func _combo() -> Card:
	var card: Card = Card.new()
	card.id = "t020d_combo"
	card.category = Card.Category.COMBO_DAMAGE
	card.cost_type = Card.CostType.PAIR
	card.cost_amount = 2
	card.effect_value = 6
	card.named_unit_id = 1
	card.partner_unit_id = 2
	card.target_range = -1
	return card


func _heal(effect: int) -> Card:
	var card: Card = Card.new()
	card.id = "t020d_heal"
	card.category = Card.Category.HEAL
	card.cost_type = Card.CostType.PAIR
	card.cost_amount = 1
	card.effect_value = effect
	card.named_unit_id = 1
	card.partner_unit_id = 2
	card.target_range = 3
	return card


func _reason(script: GDScript, state: BattleState, card: Card) -> CardCostPlan.Reason:
	return _session(script, state, card).card_unplayable_reason(card)


func _scn_los_blocked(script: GDScript) -> bool:
	# 敵人在 x=3、付款人 x=0 射程 6、倒木 x=1 擋線;P2 放遠處。
	var state: BattleState = _state(0, 5, 3, 6, 6, [1])
	return _reason(script, state, _direct()) == CardCostPlan.Reason.LOS_BLOCKED


func test_direct_no_enemy_in_range() -> void:
	var state: BattleState = _state(0, 5, 3, 1, 6)
	assert_int(_reason(CardPlaySession, state, _direct())).is_equal(CardCostPlan.Reason.NO_ENEMY_IN_RANGE)


func test_direct_los_blocked_is_distinct_from_no_enemy() -> void:
	assert_bool(_scn_los_blocked(CardPlaySession)).is_true()


func test_direct_enemy_reachable_is_playable() -> void:
	var state: BattleState = _state(0, 5, 3, 6, 6)
	assert_int(_reason(CardPlaySession, state, _direct())).is_equal(CardCostPlan.Reason.NONE)


func test_combo_only_one_attacker_reaches_names_the_other() -> void:
	var state: BattleState = _state(0, 5, 3, 6, 1)
	var card: Card = _combo()
	var session: CardPlaySession = _session(CardPlaySession, state, card)
	assert_int(session.card_unplayable_reason(card)).is_equal(CardCostPlan.Reason.COMBO_CANNOT_REACH)
	assert_int(session.combo_unreachable_unit_id(card)).is_equal(2)


func test_combo_both_reach_is_playable() -> void:
	var state: BattleState = _state(0, 1, 3, 6, 6)
	var card: Card = _combo()
	var session: CardPlaySession = _session(CardPlaySession, state, card)
	assert_int(session.card_unplayable_reason(card)).is_equal(CardCostPlan.Reason.NONE)
	assert_int(session.combo_unreachable_unit_id(card)).is_equal(-1)


func test_cost_reason_outranks_target_reason() -> void:
	# 夥伴(P2)倒下 + 射程內無敵人:優先序 #1 夥伴不在場 先於 #6。
	var state: BattleState = _state(0, 5, 3, 1, 6)
	state.commit_authoritative_change(func() -> void: state.unit_by_id(2).take_damage(20))
	assert_int(_reason(CardPlaySession, state, _combo())).is_equal(CardCostPlan.Reason.PARTNER_ABSENT)


func test_heal_full_hp_recipient_reason() -> void:
	var state: BattleState = _state(0, 1, 3, 1, 1)
	assert_int(_reason(CardPlaySession, state, _heal(5))).is_equal(CardCostPlan.Reason.TARGET_HP_FULL)


func test_preview_heal_before_after_and_cap_flag() -> void:
	var state: BattleState = _state(0, 1, 3, 1, 1)
	state.commit_authoritative_change(func() -> void: state.unit_by_id(2).hp = 15)
	var uncapped: Card = _heal(3)
	var s1: CardPlaySession = _session(CardPlaySession, state, uncapped)
	var p1: Dictionary = s1.preview_heal(uncapped, 2)
	assert_int(int(p1["before"])).is_equal(15)
	assert_int(int(p1["after"])).is_equal(18)
	assert_bool(bool(p1["capped"])).is_false()
	var capped: Card = _heal(12)
	var s2: CardPlaySession = _session(CardPlaySession, state, capped)
	var p2: Dictionary = s2.preview_heal(capped, 2)
	assert_int(int(p2["after"])).is_equal(20)
	assert_bool(bool(p2["capped"])).is_true()


func test_sensitivity_proof_los_distinction_mutant_is_caught() -> void:
	assert_bool(_scn_los_blocked(CardPlaySession)).is_true()
	assert_bool(_scn_los_blocked(_MutantNoLosDistinction)).append_failure_message(
		"mutant 分不出 #6/#7,應被 LOS 情境抓出"
	).is_false()


func test_battle_screen_maps_new_reasons_to_ux_keys() -> void:
	assert_str(String(BattleScreen.unplayable_reason_key(CardCostPlan.Reason.NO_ENEMY_IN_RANGE))).is_equal("battle.card_reason.no_enemy_in_range")
	assert_str(String(BattleScreen.unplayable_reason_key(CardCostPlan.Reason.LOS_BLOCKED))).is_equal("battle.tile_info.attack_reason_los_blocked")
	assert_str(String(BattleScreen.unplayable_reason_key(CardCostPlan.Reason.COMBO_CANNOT_REACH))).is_equal("battle.card_reason.cannot_reach_format")
	assert_str(String(BattleScreen.unplayable_reason_key(CardCostPlan.Reason.TARGET_HP_FULL))).is_equal("battle.card_reason.target_hp_full")
