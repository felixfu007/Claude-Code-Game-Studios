# 強制棄牌阻塞閘門（story-007-forced-discard-gate.md）的整合測試 —— 涵蓋
# AC-D1 ~ AC-D8。獨立測試檔，不與 card_battle_wiring_test.gd（story 006）或其他
# 卡牌測試檔共用，理由同專案慣例（一條真實失敗會讓同檔案後面的測試全部不執行，
# 拆檔避免互相拖累）。
#
# 全鏈路（BattleState/BattleController/BattleLoop/TurnOrder/Unit/CardDeck/Card/
# CardModifier）都是 RefCounted，不建立任何 Node，不會留下孤兒節點。
extends GdUnitTestSuite


# ---- fixtures ---------------------------------------------------------------

func _make_unique_cards(count: int) -> Array[Card]:
	var cards: Array[Card] = []
	for i: int in range(count):
		cards.append(Card.new_temporary_stat_modifier("c%d" % i, 1, 0, 1))
	return cards


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _no_op_decide() -> Callable:
	return func(
		_state: BattleState, _unit_id: int, _can_move: bool, _can_attack: bool
	) -> Dictionary:
		return {"move_to": null, "attack": -1}


# 彼此打不到、走不到的最小名冊（mp=0，射程 1 但距離遠超過 1）——沿用
# story-006-battle-loop-wiring.md 的 card_battle_wiring_test.gd 手法，讓測試只
# 關心強制棄牌怎麼觸發、動作怎麼被擋，不被戰鬥結算干擾。
func _far_apart_roster() -> Array[String]:
	return [
		"1,P1,PLAYER,20,5,3,0,1,1,0,0",
		"2,E1,ENEMY,20,5,3,0,1,1,12,5",
	]


# 與 _far_apart_roster() 唯一差異：玩家單位 mp=3，讓 AC-D3 的正面控制組與 AC-D4
# 有真正的「移動」可用來證明盤面會/不會改變 —— 光靠 mp=0 的名冊，click_tile()
# 的移動分支永遠不可能成功，無從證明「這個動作本來真的會動盤面」。
func _movable_far_apart_roster() -> Array[String]:
	return [
		"1,P1,PLAYER,20,5,3,3,1,1,0,0",
		"2,E1,ENEMY,20,5,3,0,1,1,12,5",
	]


func _build_controller(
	roster_lines: Array[String], deck: CardDeck, decide: Callable
) -> Dictionary:
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var controller: BattleController = BattleController.new(state, order, Callable(), decide, deck)
	return {"state": state, "order": order, "controller": controller}


func _build_loop(
	roster_lines: Array[String],
	deck: CardDeck,
	decide: Callable,
	discard_policy: Callable = Callable()
) -> Dictionary:
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var loop: BattleLoop = BattleLoop.new(state, order, decide, deck, discard_policy)
	return {"state": state, "order": order, "loop": loop}


# 把一個新建的 controller 逼進「欠棄牌」狀態：開局手牌 5（已滿，因為
# HAND_SIZE_LIMIT == OPENING_HAND_SIZE == 5），走完一輪玩家->敵人->玩家的完整
# 轉換（BattleState.begin_player_turn() 的補牌半支必定觸發強制棄牌）。回傳的
# Dictionary 多帶一個 "deck" 鍵，方便呼叫端直接檢查手牌/棄牌。
func _controller_with_pending_discard(
	roster_lines: Array[String], pool_size: int, seed_value: int
) -> Dictionary:
	var deck: CardDeck = CardDeck.new(_make_unique_cards(pool_size), _seeded_rng(seed_value))
	var built: Dictionary = _build_controller(roster_lines, deck, _no_op_decide())
	var controller: BattleController = built["controller"]
	controller.end_faction_phase()
	controller.run_enemy_phase()
	built["deck"] = deck
	return built


# ---- AC-D1：手牌已滿、玩家回合開始 -> 補牌後手牌為 6，且「欠棄牌」為真 ----------

func test_ac_d1_full_hand_draw_sets_pending_discard_and_grows_hand_to_six() -> void:
	# Arrange / Act
	var built: Dictionary = _controller_with_pending_discard(_far_apart_roster(), 10, 101)
	var deck: CardDeck = built["deck"]
	var controller: BattleController = built["controller"]

	# Assert
	assert_int(deck.hand_size()).is_equal(6)
	assert_bool(controller.has_pending_discard()).is_true()
	assert_int(controller.round_number()).is_equal(2)
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)


# ---- AC-D2：欠棄牌時，四個動作全部被拒，且拒絕可觀測（非 &"none"） --------------

func test_ac_d2_all_four_actions_are_blocked_while_discard_pending() -> void:
	# Arrange
	var built: Dictionary = _controller_with_pending_discard(_far_apart_roster(), 10, 102)
	var controller: BattleController = built["controller"]

	# Act / Assert — select_unit()
	assert_bool(controller.select_unit(1)).is_false()
	assert_int(controller.selected_unit()).is_equal(-1)

	# Act / Assert — click_tile()：點玩家自己單位的格子，正常情況下會選取它；
	# 這裡必須被擋，且拒絕值明確不是 &"none"（&"none" 代表「點到空地」，
	# 兩者混在一起，介面就分不出「按了沒反應」與「這裡沒東西」）
	var click_result: Dictionary = controller.click_tile(Vector2i(0, 0))
	assert_that(click_result["action"]).is_equal(&"blocked_pending_discard")
	assert_bool(click_result["action"] == &"none").is_false()

	# Act / Assert — end_unit_turn()
	assert_bool(controller.end_unit_turn(1)).is_false()

	# Act / Assert — end_faction_phase()：no-op，phase/round 不變
	var round_before: int = controller.round_number()
	controller.end_faction_phase()
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(controller.round_number()).is_equal(round_before)


# ---- AC-D3：欠棄牌時盤面逐字未變 —— 先證明同一動作在不欠棄牌時確實會動盤面 ------
#
# 🔴 這是本 story 最容易寫成「永遠會通過」的一條：若只驗證「欠棄牌時盤面沒變」，
# 動作根本沒被實作（click_tile() 整個是空殼）也會通過同一條斷言。下面第一條測試
# 是正面控制組：同一份名冊、同一個動作序列，在完全不涉及卡牌系統的情況下，證明
# click_tile() 的移動分支真的會改變 BattleState.position_of()。第二條測試才是
# 「欠棄牌時同一動作不會改變盤面」——兩條合起來，訊號才完整。

func test_ac_d3_positive_control_click_tile_move_mutates_board_when_not_blocked() -> void:
	# Arrange
	var built: Dictionary = _build_controller(_movable_far_apart_roster(), null, _no_op_decide())
	var state: BattleState = built["state"]
	var controller: BattleController = built["controller"]
	assert_vector(state.position_of(1)).is_equal(Vector2i(0, 0))
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(1, 0))

	# Assert — 同一個動作，在沒有卡牌系統介入的情況下，確實會移動單位
	assert_that(result["action"]).is_equal(&"moved")
	assert_vector(state.position_of(1)).is_equal(Vector2i(1, 0))


func test_ac_d3_same_action_leaves_board_untouched_while_discard_pending() -> void:
	# Arrange — 與上一條使用同一份「可移動」名冊，逼進欠棄牌狀態後，在做任何被擋
	# 的動作之前先把整個盤面快照下來
	var built: Dictionary = _controller_with_pending_discard(_movable_far_apart_roster(), 10, 103)
	var state: BattleState = built["state"]
	var order: TurnOrder = built["order"]
	var controller: BattleController = built["controller"]

	var pos_before: Vector2i = state.position_of(1)
	var hp_before: int = state.unit_by_id(1).hp
	var can_move_before: bool = order.can_move(1)
	var can_attack_before: bool = order.can_attack(1)
	var round_before: int = controller.round_number()

	# Act — 嘗試上一條測試裡「確實會動盤面」的同一個動作序列
	assert_bool(controller.select_unit(1)).is_false()
	var result: Dictionary = controller.click_tile(Vector2i(1, 0))

	# Assert — 拒絕可觀測，且盤面逐字未變：位置、HP、行動旗標、回合數皆與
	# 補牌後（快照當下）相同
	assert_that(result["action"]).is_equal(&"blocked_pending_discard")
	assert_vector(state.position_of(1)).is_equal(pos_before)
	assert_int(state.unit_by_id(1).hp).is_equal(hp_before)
	assert_bool(order.can_move(1)).is_equal(can_move_before)
	assert_bool(order.can_attack(1)).is_equal(can_attack_before)
	assert_int(controller.round_number()).is_equal(round_before)


# ---- AC-D4：棄掉一張 -> 手牌回到 5、欠棄牌為假 -> 四個動作全部恢復可用 ------------

func test_ac_d4_discarding_resolves_gate_and_all_four_actions_resume() -> void:
	# Arrange
	var built: Dictionary = _controller_with_pending_discard(_movable_far_apart_roster(), 10, 104)
	var deck: CardDeck = built["deck"]
	var controller: BattleController = built["controller"]
	var card_to_discard: Card = deck.hand()[0]

	# Act — 玩家指定哪一張的入口：BattleController.resolve_forced_discard()
	# （不是直接戳 CardDeck.discard_card()——玩家其餘每一個動作都經過
	# controller，解閘動作沒有理由是唯一繞過它、直接碰 CardDeck 的一個；否則
	# 閘門「擋」在 controller、「解」卻散在 deck，介面層還得多知道
	# BattleState.card_deck() 這條路徑，而 controller 存在的意義就是它不必知道）
	assert_bool(controller.resolve_forced_discard(card_to_discard)).is_true()

	# Assert — 棄牌半支
	assert_int(deck.hand_size()).is_equal(5)
	assert_bool(deck.used().has(card_to_discard)).is_true()
	assert_bool(controller.has_pending_discard()).is_false()

	# Assert — 四個動作全部恢復可用：select_unit -> click_tile(移動) ->
	# end_unit_turn -> end_faction_phase，一路串起來，任何一個仍被擋都會在這裡斷掉
	assert_bool(controller.select_unit(1)).is_true()
	var move_result: Dictionary = controller.click_tile(Vector2i(1, 0))
	assert_that(move_result["action"]).is_equal(&"moved")
	assert_bool(controller.end_unit_turn(1)).is_true()
	controller.end_faction_phase()
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)


# ---- AC-D9/AC-D10/AC-D11：BattleController.resolve_forced_discard() 本身的
# 三條拒絕/成功條件 ------------------------------------------------------------
#
# AC-D9 與上面 AC-D4 重疊一部分：AC-D4 現在也是透過
# controller.resolve_forced_discard() 解閘（見上方的修改與註解），所以「解閘
# 後四個動作恢復可用」那個組合已經被 AC-D4 覆蓋。這裡的 AC-D9 刻意只驗
# resolve_forced_discard() 自己回傳值與手牌/閘門狀態這一小圈——真正的重點是
# AC-D10（不欠棄牌時呼叫）與 AC-D11（欠棄牌但牌不在手上），這兩者是
# resolve_forced_discard() 專屬、AC-D4 不會經過的兩條拒絕路徑。

func test_ac_d9_resolve_forced_discard_succeeds_and_clears_the_gate() -> void:
	# Arrange
	var built: Dictionary = _controller_with_pending_discard(_far_apart_roster(), 10, 109)
	var deck: CardDeck = built["deck"]
	var controller: BattleController = built["controller"]
	var card_to_discard: Card = deck.hand()[0]

	# Act
	var resolved: bool = controller.resolve_forced_discard(card_to_discard)

	# Assert
	assert_bool(resolved).is_true()
	assert_int(deck.hand_size()).is_equal(5)
	assert_bool(deck.used().has(card_to_discard)).is_true()
	assert_bool(controller.has_pending_discard()).is_false()


func test_ac_d10_resolve_forced_discard_rejects_when_no_discard_is_owed() -> void:
	# Arrange — 一個從未滿手過的正常控制器（開局手牌 5，未觸發強制棄牌）
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), _seeded_rng(110))
	var built: Dictionary = _build_controller(_far_apart_roster(), deck, _no_op_decide())
	var controller: BattleController = built["controller"]
	assert_bool(controller.has_pending_discard()).is_false()
	var card_in_hand: Card = deck.hand()[0]

	# Act — 玩家在沒被要求棄牌時，不能隨便棄一張（手牌上限規則之外沒有棄牌動作）
	var resolved: bool = controller.resolve_forced_discard(card_in_hand)

	# Assert — 拒絕，手牌逐字未變
	assert_bool(resolved).is_false()
	assert_int(deck.hand_size()).is_equal(5)
	assert_bool(deck.hand().has(card_in_hand)).is_true()
	assert_bool(deck.used().has(card_in_hand)).is_false()


func test_ac_d11_resolve_forced_discard_rejects_a_card_not_in_hand() -> void:
	# Arrange — 欠棄牌狀態，但傳一張完全不屬於這副牌的 Card 實例（連 identity
	# 都對不上任何一張，CardDeck._move_hand_card_to_used() 的 find() 必定找不到）
	var built: Dictionary = _controller_with_pending_discard(_far_apart_roster(), 10, 111)
	var deck: CardDeck = built["deck"]
	var controller: BattleController = built["controller"]
	var stray_card: Card = Card.new_temporary_stat_modifier("not_in_this_deck", 1, 0, 1)
	assert_bool(deck.hand().has(stray_card)).is_false()
	var hand_size_before: int = deck.hand_size()

	# Act
	var resolved: bool = controller.resolve_forced_discard(stray_card)

	# Assert — 拒絕，手牌逐字未變，閘門依然生效
	assert_bool(resolved).is_false()
	assert_int(deck.hand_size()).is_equal(hand_size_before)
	assert_bool(controller.has_pending_discard()).is_true()


# ---- AC-D5：唯讀查詢在欠棄牌期間仍正常，不被閘門攔截 ---------------------------
#
# 誠實揭露：move_targets() / attack_targets() / threat_targets() 都是以
# _selected_unit_id 為準的查詢，而選取本身在欠棄牌時被 select_unit() 擋下——
# 所以這三個查詢在欠棄牌狀態下必然回傳空陣列，不論有沒有額外的閘門。這條測試對
# 這三者能證明的，只是「呼叫不會崩潰、也沒有被閘門攔成別的值」，訊號比
# selectable_units() 弱——selectable_units() 不依賴選取，可以直接跟一個
# 「同名冊、同回合、但完全沒有卡牌系統」的基準控制器比較，兩者必須逐字相同，
# 這才是本條真正有辨識力的斷言。

func test_ac_d5_selectable_units_unaffected_by_pending_discard() -> void:
	# Arrange — 欠棄牌的控制器
	var pending_built: Dictionary = _controller_with_pending_discard(_far_apart_roster(), 10, 105)
	var pending_controller: BattleController = pending_built["controller"]
	assert_bool(pending_controller.has_pending_discard()).is_true()

	# Arrange — 同名冊、同樣走一輪玩家->敵人->玩家，但完全沒有卡池的基準控制器
	var baseline_built: Dictionary = _build_controller(_far_apart_roster(), null, _no_op_decide())
	var baseline_controller: BattleController = baseline_built["controller"]
	baseline_controller.end_faction_phase()
	baseline_controller.run_enemy_phase()
	assert_bool(baseline_controller.has_pending_discard()).is_false()

	# Assert — 唯讀查詢完全不受「有沒有欠棄牌」影響
	assert_array(pending_controller.selectable_units()).is_equal(
		baseline_controller.selectable_units()
	)
	assert_array(pending_controller.selectable_units()).is_equal([1])
	assert_int(pending_controller.outcome()).is_equal(baseline_controller.outcome())

	# 弱訊號但仍記錄：三個依賴選取的查詢在欠棄牌時不崩潰、回傳空陣列（因為選取
	# 本身在欠棄牌時就不可能發生，這是預期行為，不是本條的重點）
	assert_array(pending_controller.move_targets()).is_equal([])
	assert_array(pending_controller.attack_targets()).is_equal([])
	assert_array(pending_controller.threat_targets()).is_equal([])


# ---- AC-D6：未附卡池的戰鬥 -> 行為與 Story 006 之後逐字相同（閘門永不觸發） ------

func test_ac_d6_battle_without_card_deck_never_triggers_the_gate() -> void:
	# Arrange / Act
	var built: Dictionary = _build_controller(_far_apart_roster(), null, _no_op_decide())
	var controller: BattleController = built["controller"]
	assert_bool(controller.has_pending_discard()).is_false()

	controller.end_faction_phase()
	controller.run_enemy_phase()

	# Assert — 走完一整輪轉換，閘門從未觸發，四個動作正常可用
	assert_bool(controller.has_pending_discard()).is_false()
	assert_int(controller.round_number()).is_equal(2)
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_bool(controller.select_unit(1)).is_true()


# ---- AC-D7：BattleLoop 未提供棄牌策略、且欠棄牌 -> run() 立刻中止並帶明確原因 ----

func test_ac_d7_loop_without_discard_policy_aborts_with_reason_before_max_rounds() -> void:
	# Arrange — max_rounds 遠高於觸發棄牌所需的回合數（第 2 輪的玩家轉換點就會
	# 觸發），確保「中止」不是因為撞到回合上限
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), _seeded_rng(107))
	var built: Dictionary = _build_loop(_far_apart_roster(), deck, _no_op_decide())
	var loop: BattleLoop = built["loop"]

	# Act
	var result: Dictionary = loop.run(1000)

	# Assert — 不崩潰、不卡到上限，帶明確原因
	assert_bool(result["aborted"]).is_true()
	assert_that(result["abort_reason"]).is_equal(&"forced_discard_unresolved")
	assert_int(result["rounds"]).is_equal(2)
	assert_bool(deck.has_pending_discard()).is_true()
	assert_int(deck.hand_size()).is_equal(6)


# ---- AC-D8：BattleLoop 提供棄牌策略 -> 模擬正常跑完，棄掉的是策略選的那一張 ------

func test_ac_d8_loop_with_discard_policy_discards_exactly_the_chosen_card() -> void:
	# Arrange — 策略永遠選手牌的第一張，並記錄每一次它選了什麼，供事後逐張核對
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), _seeded_rng(108))
	var discarded_cards: Array[Card] = []
	var policy: Callable = func(policy_deck: CardDeck) -> Card:
		var chosen: Card = policy_deck.hand()[0]
		discarded_cards.append(chosen)
		return chosen
	var built: Dictionary = _build_loop(_far_apart_roster(), deck, _no_op_decide(), policy)
	var loop: BattleLoop = built["loop"]

	# Act — 僵局名冊（双方 mp=0、打不到），3 輪跑完必定撞回合上限，不是因為棄牌
	# 未解決——這正是本條要證明的：有策略時，戰鬥能正常跑到 max_rounds 為止，
	# 而不是在第一次滿手就中止
	var result: Dictionary = loop.run(3)

	# Assert — 中止原因是回合上限，不是強制棄牌未解決
	assert_bool(result["aborted"]).is_true()
	assert_that(result["abort_reason"]).is_equal(&"max_rounds_reached")
	assert_int(result["outcome"]).is_equal(BattleState.Outcome.ONGOING)

	# Assert — 每一次策略選中的牌，最終都確實落在已用區、不再留在手牌，且手牌
	# 從未被允許長期停在超過上限的 6 張
	assert_bool(deck.has_pending_discard()).is_false()
	assert_int(deck.hand_size()).is_less_equal(CardDeck.HAND_SIZE_LIMIT)
	assert_int(discarded_cards.size()).is_greater(0)
	for card: Card in discarded_cards:
		assert_bool(deck.used().has(card)).is_true()
		assert_bool(deck.hand().has(card)).is_false()
