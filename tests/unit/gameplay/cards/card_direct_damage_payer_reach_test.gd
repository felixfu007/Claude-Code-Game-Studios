# Story 020 / story-027 缺陷修正:直傷卡「付款人由玩家自選」時,可不可打與付款人清單必須同一份定義
# (存活我方 ∧ 需要時 2 格內有隊友 ∧ 此人自己打得到敵人)。
# production/epics/skill-card-system/story-020-card-confirm-panel-cost-and-unplayable-reason.md
#
# 檔案存取:無(記憶體內夾具,仿 card_unplayable_reason_engine_test.gd)。
# 敏感度證明(常駐):mutant 把付款人清單改回「不看敵人」,test_sensitivity_proof_* 斷言 mutant 清單
# 含打不到的人、真品不含。證明不了的:confirm 再驗路徑(以公開 API 走不到「選完付款人後再被改局面」)。
extends GdUnitTestSuite


## 付款人清單退化回舊行為(只看隊友條件、不看敵人)的 mutant。
class _MutantPayersIgnoreEnemy extends CardPlaySession:
	func _legal_payers(card: Card) -> Array[int]:
		var out: Array[int] = []
		for id: int in _alive_player_unit_ids():
			if not _needs_ally_nearby(card) or _ally_within_proximity(id, card.target_range):
				out.append(id)
		return out


func _terrain() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for i: int in range(6):
		rows.append(".............")
	return rows


## players: Array of [id, x, rmax];敵人固定 id 9。
func _state(players: Array, enemy_x: int) -> BattleState:
	var lines: Array[String] = []
	for p: Array in players:
		lines.append("%d,P%d,PLAYER,20,10,3,1,1,%d,%d,0" % [p[0], p[0], p[2], p[1]])
	lines.append("9,E1,ENEMY,30,5,50,1,1,1,%d,0" % enemy_x)
	return BattleState.create(_terrain(), "\n".join(lines))


func _session(script: GDScript, state: BattleState, card: Card) -> CardPlaySession:
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = script.new(deck, state, links, NullAffinityWritePort.new())
	session.attach_affinity_pool(AffinityDataPool.new())
	session.open_hand()
	return session


func _direct(target_range: int) -> Card:
	var card: Card = Card.new()
	card.id = "t_payer_reach"
	card.category = Card.Category.DIRECT_DAMAGE
	card.cost_type = Card.CostType.NONE
	card.effect_value = 5
	card.named_unit_id = -1
	card.target_range = target_range
	return card


## A(1)+C(2) 相鄰但夠不到敵人;B(3) 夠得到敵人但 2 格內沒隊友。
func _split_state() -> BattleState:
	return _state([[1, 0, 1], [2, 1, 1], [3, 8, 3]], 10)


func test_payer_reach_split_fixture_card_is_unplayable() -> void:
	var card: Card = _direct(2)
	var session: CardPlaySession = _session(CardPlaySession, _split_state(), card)
	assert_int(session.card_unplayable_reason(card)).is_not_equal(CardCostPlan.Reason.NONE)
	assert_bool(session.select_card(card)).is_false()


func test_payer_reach_split_fixture_reason_is_about_reach_not_ally() -> void:
	var card: Card = _direct(2)
	var session: CardPlaySession = _session(CardPlaySession, _split_state(), card)
	assert_int(session.card_unplayable_reason(card)).is_equal(CardCostPlan.Reason.NO_ENEMY_IN_RANGE)


func test_payer_reach_nobody_has_ally_keeps_need_ally_nearby() -> void:
	# 三人都離很遠:隊友條件無人滿足,原因維持 NEED_ALLY_NEARBY(即使 B 打得到敵人)。
	var card: Card = _direct(2)
	var state: BattleState = _state([[1, 0, 1], [2, 5, 1], [3, 10, 3]], 12)
	var session: CardPlaySession = _session(CardPlaySession, state, card)
	assert_int(session.card_unplayable_reason(card)).is_equal(CardCostPlan.Reason.NEED_ALLY_NEARBY)


func test_payer_reach_c03_payers_need_both_ally_and_enemy() -> void:
	# B(2)+D(3) 相鄰且 B 夠得到敵人;A(1) 孤立也打不到。清單只剩 B、D 中打得到者 = B。
	var card: Card = _direct(2)
	var state: BattleState = _state([[1, 0, 1], [2, 8, 3], [3, 9, 1]], 11)
	var session: CardPlaySession = _session(CardPlaySession, state, card)
	assert_bool(session.select_card(card)).is_true()
	assert_array(session.legal_targets()).contains_exactly([2])


func test_payer_reach_non_c03_payers_exclude_unreachable_units() -> void:
	var card: Card = _direct(-1)
	var state: BattleState = _state([[1, 0, 1], [2, 5, 6]], 8)
	var session: CardPlaySession = _session(CardPlaySession, state, card)
	assert_bool(session.select_card(card)).is_true()
	assert_array(session.legal_targets()).contains_exactly([2])


func test_payer_reach_every_listed_payer_has_a_legal_enemy() -> void:
	# 付款人清單的每個人,選下去後選敵清單都非空(原缺陷:選完清單為空)。
	var card: Card = _direct(-1)
	var state: BattleState = _state([[1, 0, 1], [2, 5, 6], [3, 7, 3]], 8)
	var session: CardPlaySession = _session(CardPlaySession, state, card)
	assert_bool(session.select_card(card)).is_true()
	for payer_id: int in session.legal_targets():
		var s2: CardPlaySession = _session(CardPlaySession, state, card)
		assert_bool(s2.select_card(card)).is_true()
		assert_bool(s2.select_target(payer_id)).is_true()
		assert_array(s2.legal_targets()).is_not_empty()


func test_sensitivity_proof_payer_list_mutant_lists_unreachable_payer() -> void:
	var card: Card = _direct(-1)
	var state: BattleState = _state([[1, 0, 1], [2, 5, 6]], 8)
	var mutant: CardPlaySession = _session(_MutantPayersIgnoreEnemy, state, card)
	var real: CardPlaySession = _session(CardPlaySession, state, card)
	assert_bool(mutant.select_card(card)).is_true()
	assert_bool(real.select_card(card)).is_true()
	assert_array(mutant.legal_targets()).contains_exactly_in_any_order([1, 2])
	assert_array(real.legal_targets()).contains_exactly([2])
