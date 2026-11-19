# Story 027 c03 站位條件(直傷卡 target_range >= 1:付款人範圍內須有另一名存活我方)。
# production/epics/skill-card-system/story-027-c03-ally-proximity-condition.md
#
# 檔案存取:無(記憶體內夾具)。
#
# 敏感度證明(常駐 test_sensitivity_proof_*):CardPlaySession 的私有 seam 可被子類別覆寫,
# 一個 mutant 一條獨立測試:
#  ① _ally_within_proximity 恆真(拿掉檢查) -> 「3 格拒」情境必須變紅
#  ② _proximity_candidates 把陣亡隊友也納入候選 -> 「陣亡拒」情境必須變紅
extends GdUnitTestSuite

const _ROW_OPEN: String = "............."


## 我方 1 (0,0);我方 2 在 (ally_x,0);敵人 9 在 (0,1)(射程內可視)。
func _build_state(ally_x: int, ally_alive: bool = true, far_unit: bool = false) -> BattleState:
	var rows: PackedStringArray = PackedStringArray()
	for i: int in range(6):
		rows.append(_ROW_OPEN)
	var lines: Array[String] = []
	lines.append("1,P1,PLAYER,20,10,3,1,1,1,0,0")
	lines.append("2,P2,PLAYER,22,10,3,1,1,1,%d,0" % ally_x)
	if far_unit:
		lines.append("3,P3,PLAYER,20,10,3,1,1,1,12,5")
	lines.append("9,E1,ENEMY,30,5,50,1,1,1,0,1")
	var state: BattleState = BattleState.create(rows, "\n".join(lines))
	if not ally_alive:
		state.commit_authoritative_change(func() -> void:
			state.unit_by_id(2).hp = 0
		)
	return state


## c03 型直傷卡:付款人由玩家選(named_unit_id = -1),target_range = [param range_limit]。
func _c03_card(range_limit: int) -> Card:
	var card: Card = Card.new()
	card.id = "c03_test"
	card.category = Card.Category.DIRECT_DAMAGE
	card.cost_type = Card.CostType.HP
	card.cost_amount = 3
	card.effect_value = 10
	card.target_range = range_limit
	return card


func _session(script: GDScript, state: BattleState, card: Card) -> CardPlaySession:
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = script.new(deck, state, links, NullAffinityWritePort.new())
	session.attach_affinity_pool(AffinityDataPool.new())
	return session


func _reason(script: GDScript, ally_x: int, ally_alive: bool = true) -> CardCostPlan.Reason:
	var card: Card = _c03_card(2)
	var session: CardPlaySession = _session(script, _build_state(ally_x, ally_alive), card)
	session.open_hand()
	return session.card_unplayable_reason(card)


# ---- AC1 / AC3 --------------------------------------------------------------------

func test_ally_within_two_cells_is_playable() -> void:
	assert_int(_reason(CardPlaySession, 2)).is_equal(CardCostPlan.Reason.NONE)


func test_ally_three_cells_away_is_rejected_with_readable_reason() -> void:
	assert_int(_reason(CardPlaySession, 3)).is_equal(CardCostPlan.Reason.NEED_ALLY_NEARBY)


func test_only_nearby_ally_dead_is_rejected() -> void:
	assert_int(_reason(CardPlaySession, 1, false)).is_equal(CardCostPlan.Reason.NEED_ALLY_NEARBY)


func test_select_card_refuses_when_condition_fails() -> void:
	var card: Card = _c03_card(2)
	var session: CardPlaySession = _session(CardPlaySession, _build_state(3), card)
	session.open_hand()
	assert_bool(session.select_card(card)).is_false()


## 夾具多一名離所有隊友都 > 2 格的我方 3(12,5):付款人候選必須排除它。
func _payer_candidates(script: GDScript) -> Array[int]:
	var card: Card = _c03_card(2)
	var session: CardPlaySession = _session(script, _build_state(1, true, true), card)
	session.open_hand()
	if not session.select_card(card):
		return []
	var targets: Array[int] = session.legal_targets()
	targets.sort()
	return targets


func test_payer_pick_only_offers_units_with_a_nearby_ally() -> void:
	assert_array(_payer_candidates(CardPlaySession)).is_equal([1, 2])


func test_full_play_succeeds_within_range_and_writes() -> void:
	var card: Card = _c03_card(2)
	var state: BattleState = _build_state(2)
	var session: CardPlaySession = _session(CardPlaySession, state, card)
	session.open_hand()
	var ok: bool = session.select_card(card)
	ok = ok and session.select_target(1)
	ok = ok and session.select_target(9)
	ok = ok and session.confirm()
	assert_bool(ok).is_true()
	assert_int(state.unit_by_id(9).hp).is_equal(20)


# ---- AC2 --------------------------------------------------------------------------

func test_range_minus_one_has_no_condition() -> void:
	var card: Card = _c03_card(-1)
	var session: CardPlaySession = _session(CardPlaySession, _build_state(12, false), card)
	session.open_hand()
	assert_int(session.card_unplayable_reason(card)).is_equal(CardCostPlan.Reason.NONE)


# ---- AC4 敏感度證明 -----------------------------------------------------------------

class _MutantNoProximityCheck extends CardPlaySession:
	func _ally_within_proximity(_payer_id: int, _range_limit: int) -> bool:
		return true


class _MutantDeadAllyCounts extends CardPlaySession:
	func _proximity_candidates() -> Array[Unit]:
		var result: Array[Unit] = []
		for id: int in [1, 2]:
			result.append(_state.unit_by_id(id))
		return result


func test_sensitivity_proof_removed_check_is_caught() -> void:
	assert_int(_reason(CardPlaySession, 3)).is_equal(CardCostPlan.Reason.NEED_ALLY_NEARBY)
	assert_int(_reason(_MutantNoProximityCheck, 3)).is_not_equal(CardCostPlan.Reason.NEED_ALLY_NEARBY)


func test_sensitivity_proof_unfiltered_payer_pick_is_caught() -> void:
	assert_array(_payer_candidates(CardPlaySession)).is_equal([1, 2])
	assert_array(_payer_candidates(_MutantNoProximityCheck)).is_equal([1, 2, 3])


func test_sensitivity_proof_dead_ally_counted_is_caught() -> void:
	assert_int(_reason(CardPlaySession, 1, false)).is_equal(CardCostPlan.Reason.NEED_ALLY_NEARBY)
	assert_int(_reason(_MutantDeadAllyCounts, 1, false)).is_not_equal(CardCostPlan.Reason.NEED_ALLY_NEARBY)
