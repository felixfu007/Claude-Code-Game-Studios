# Story 018 直傷卡 -> BattleController 的整合測試:擊殺最後一個敵人 -> 勝利,
# 以及 card_damage_resolved 訊號參數。
# production/epics/skill-card-system/story-018-direct-damage-card-and-kill-chain.md
#
# 檔案存取:無(全為記憶體內夾具,無節點)。
#
# 敏感度證明(常駐):
#  ③ test_sensitivity_proof_mutant_without_outcome_check:BattleController 子類別把
#    _check_outcome_and_finish 覆寫為空 -> 同一情境下戰鬥不會結束(真品必結束)。
# 證明不了的(誠實登記):無 —— 本檔只有一個機制(勝負判定被呼叫)與一個訊號,各有斷言。
extends GdUnitTestSuite


## 與真品相同、只把勝負判定拿掉的 mutant(mutant ③)。
class _MutantNoOutcomeCheck extends BattleController:
	func _check_outcome_and_finish() -> void:
		pass


func _terrain() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for i: int in range(6):
		rows.append(".............")
	return rows


## 我方 1 在 (0,0)(射程 1~1),唯一敵人 2 在 (1,0),hp 5。
func _roster() -> String:
	var lines: Array[String] = [
		"1,P1,PLAYER,20,10,3,1,1,1,0,0",
		"2,E1,ENEMY,5,5,3,1,1,1,1,0",
	]
	return "\n".join(lines)


func _card(damage: int) -> Card:
	var card: Card = Card.new()
	card.id = "dd_kill_chain"
	card.category = Card.Category.DIRECT_DAMAGE
	card.cost_type = Card.CostType.HP
	card.cost_amount = 3
	card.effect_value = damage
	card.named_unit_id = 1
	return card


## 跑一次完整出牌;回傳 {controller, damage_events, ended_outcomes, confirmed}。
func _run(script: GDScript, damage: int) -> Dictionary:
	var state: BattleState = BattleState.create(_terrain(), _roster())
	var order: TurnOrder = TurnOrder.new([1], [2])
	var cards: Array[Card] = [_card(damage)]
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	var links: Array[AffinityLink] = []
	var controller: BattleController = script.new(
		state, order, Callable(), Callable(), deck, links, null, Callable(), AffinityDataPool.new(), null
	)
	var damage_events: Array[Array] = []
	var ended: Array[int] = []
	controller.card_damage_resolved.connect(
		func(caster: int, target: int, dealt: int, died: bool) -> void:
			damage_events.append([caster, target, dealt, died])
	)
	controller.battle_ended.connect(func(result: BattleState.Outcome) -> void:
		ended.append(result)
	)
	var ok: bool = controller.open_hand()
	ok = ok and controller.select_card(deck.hand()[0])
	ok = ok and controller.select_target(2)
	ok = ok and controller.confirm()
	return {"controller": controller, "damage_events": damage_events, "ended": ended, "confirmed": ok}


func test_card_kills_last_enemy_battle_finishes_with_victory() -> void:
	var r: Dictionary = _run(BattleController, 12)
	var controller: BattleController = r["controller"]
	assert_bool(r["confirmed"]).is_true()
	assert_int(controller.phase()).is_equal(BattleController.Phase.FINISHED)
	assert_int(controller.outcome()).is_equal(BattleState.Outcome.VICTORY)
	assert_array(r["ended"]).has_size(1)


func test_card_damage_resolved_signal_carries_caster_target_dealt_and_died() -> void:
	var r: Dictionary = _run(BattleController, 12)
	# 12 傷害打 hp 5 的敵人 -> 實際造成 5(截斷到現有 hp),擊殺。
	assert_array(r["damage_events"]).is_equal([[1, 2, 5, true]])


func test_card_non_lethal_damage_keeps_battle_going() -> void:
	var r: Dictionary = _run(BattleController, 2)
	var controller: BattleController = r["controller"]
	assert_array(r["damage_events"]).is_equal([[1, 2, 2, false]])
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_array(r["ended"]).is_empty()


func test_sensitivity_proof_mutant_without_outcome_check() -> void:
	# 真品:戰鬥結束;mutant ③:同一情境戰鬥不結束(敵人已死但沒人判勝負)。
	var real: BattleController = _run(BattleController, 12)["controller"]
	var mutant: BattleController = _run(_MutantNoOutcomeCheck, 12)["controller"]
	assert_int(real.phase()).is_equal(BattleController.Phase.FINISHED)
	assert_int(mutant.phase()).is_not_equal(BattleController.Phase.FINISHED)
