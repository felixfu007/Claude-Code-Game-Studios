# 甲類修正的回合存續、到期與清除（story-002-modifier-lifecycle.md）的單元測試。
#
# 對應 production/epics/skill-card-system/story-002-modifier-lifecycle.md：
# AC-3（r=1 撐過緊接的敵方回合）、AC-4（到期早於該回合任何查詢）、AC-11a
# （戰鬥結束清除）、補測①（r=2 完整軌跡）、補測②（遞減先於補牌的順序）。
#
# 全鏈路（Unit/BattleState/TurnOrder/BattleController/BattleLoop/CardModifier/
# CardDeck/Card）都是 RefCounted，不建立任何 Node，不會留下孤兒節點。
#
# 本檔同時涵蓋 BattleController 與 BattleLoop 兩條驅動路徑各自的鉤子（見各
# 測試的註解），因為 story 明文要求兩條路徑都要接到同一個共用函式
# （BattleState.tick_all_modifiers() / clear_all_modifiers()），漏接一邊不會
# 報錯，只會讓走另一條路徑的戰鬥悄悄不遞減。
extends GdUnitTestSuite


# 建一份最小 BattleState/TurnOrder/BattleController 三件套 —— 沿用
# tests/unit/gameplay/battle/battle_controller_test.gd 的 _build() 手法。
func _build(
	roster_lines: Array[String],
	player_ids: Array[int],
	enemy_ids: Array[int],
	decide: Callable = Callable()
) -> Dictionary:
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new(player_ids, enemy_ids)
	var controller: BattleController = BattleController.new(state, order, Callable(), decide)
	return {"state": state, "order": order, "controller": controller}


# 兩邊都不動、不打 —— 用於只關心「回合怎麼推進」而不想讓任何 AI 行為干擾
# 修正存續判定的場景。單位彼此距離夠遠（見各測試的名冊），所以就算換成
# GreedyTacticalAI 的預設行為結論也不會變，但明講一個 no-op 讓測試不依賴
# AI 實作細節。
func _no_op_decide() -> Callable:
	return func(
		_state: BattleState, _unit_id: int, _can_move: bool, _can_attack: bool
	) -> Dictionary:
		return {"move_to": null, "attack": -1}


# 一組彼此打不到、走不到的最小名冊：mp=0（禁移動），射程 1 但距離遠超過 1
# （禁攻擊）。DEF 基準值刻意給 3，讓 DEF 增益/歸零的差異在斷言裡一眼可辨。
func _far_apart_roster() -> Array[String]:
	return [
		"1,P1,PLAYER,20,5,3,0,1,1,0,0",
		"2,E1,ENEMY,20,5,3,0,1,1,12,5",
	]


# ---- AC-3:r=1 撐過緊接的敵方回合,下個玩家回合開始後失效 ---------------------

func test_ac3_r1_buff_survives_immediately_following_enemy_phase_then_expires_next_player_turn() -> void:
	# Arrange
	var built: Dictionary = _build(_far_apart_roster(), [1], [2], _no_op_decide())
	var state: BattleState = built["state"]
	var controller: BattleController = built["controller"]
	var unit: Unit = state.unit_by_id(1)
	var baseline_def: int = unit.effective_def()

	# 第 1 輪玩家回合中途打出 r=1 的防禦增益
	unit.add_modifier(CardModifier.new("card_def_up", 0, 4, 1))
	assert_int(unit.effective_def()).is_equal(baseline_def + 4)

	# Act 1 — 玩家結束回合,進入緊接的（同一輪）敵方回合
	controller.end_faction_phase()

	# Assert 1 — 敵方回合中仍生效,一個字都不能少
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)
	assert_int(unit.effective_def()).is_equal(baseline_def + 4)
	assert_int(unit.active_modifiers().size()).is_equal(1)

	# Act 2 — 敵方回合跑完,回到玩家手上,第 2 輪開始
	controller.run_enemy_phase()

	# Assert 2 — 下個玩家回合開始後立即失效
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(controller.round_number()).is_equal(2)
	assert_int(unit.active_modifiers().size()).is_equal(0)
	assert_int(unit.effective_def()).is_equal(baseline_def)


# ---- AC-4:到期早於該回合任何查詢 --------------------------------------------
#
# 🔴 這條刻意不能只靠 effective_def() 的回傳值判斷「有沒有在正確時點移除」——
# 如果實作把「移除」延後到查詢當下才做（而不是回合開始處理時就從內部清單拿掉),
# effective_def() 本身會在被呼叫的那一刻順便修正過來,回傳值照樣正確,測試會
# 誤判「沒問題」。active_modifiers() 這行斷言才是真正咬得住的那一個:它是
# Unit.gd 裡唯一一個「單純回傳 _modifiers 目前內容的複本、自己完全不做任何
# remaining_turns 篩選」的查詢（見 unit.gd 該方法的文件註解),所以只要修正
# 還躺在內部清單裡沒被真的拿掉,不管查詢過幾次,這裡都會如實回報還有一條。
# 下方「敏感度證明」章節有實際注入驗證這個說法,不是空口說白話。
func test_ac4_expiring_modifier_is_gone_before_first_query_of_the_round() -> void:
	# Arrange
	var built: Dictionary = _build(_far_apart_roster(), [1], [2], _no_op_decide())
	var state: BattleState = built["state"]
	var controller: BattleController = built["controller"]
	var unit: Unit = state.unit_by_id(1)
	var baseline_def: int = unit.effective_def()
	unit.add_modifier(CardModifier.new("card_def_up", 0, 4, 1))

	# Act — 推進到「r 遞減至 0」的那個回合開始。round_number() 進入迴圈之後，
	# 這裡是本測試對 unit 做的第一次、也是唯一一次查詢，中間沒有插入任何
	# 其他會順便觸發副作用的呼叫。
	controller.end_faction_phase()
	controller.run_enemy_phase()

	# Assert — 這是本回合對這個單位的第一次查詢
	var entries: Array[CardModifier] = unit.active_modifiers()
	var def_now: int = unit.effective_def()
	assert_int(entries.size()).is_equal(0)
	assert_int(def_now).is_equal(baseline_def)


# ---- AC-11a:戰鬥結束,所有生效中的甲類修正一併清除 ---------------------------
#
# 用 BattleController 的真實攻擊路徑（select_unit + click_tile）觸發 VICTORY，
# 而非直接呼叫 BattleState 的內部方法 —— 這樣才是 _check_outcome_and_finish()
# 實際會被呼叫到的那條路徑。

func test_ac11a_battle_end_via_battle_controller_clears_all_active_modifiers() -> void:
	# Arrange — 玩家與唯一的敵人相鄰,玩家一擊可斃敵人(atk 10 - def 0 = 10 ≥ hp 1)
	var roster_lines: Array[String] = [
		"1,P1,PLAYER,20,10,3,1,1,1,0,0",
		"2,E1,ENEMY,1,1,0,0,1,1,1,0",
	]
	var built: Dictionary = _build(roster_lines, [1], [2])
	var state: BattleState = built["state"]
	var controller: BattleController = built["controller"]
	var unit: Unit = state.unit_by_id(1)
	unit.add_modifier(CardModifier.new("card_atk_up", 3, 0, 2))
	assert_int(unit.active_modifiers().size()).is_equal(1)

	# Act — 攻擊唯一的敵人,一擊斃命 -> VICTORY,_check_outcome_and_finish()
	# 在 _apply_attack() 內同一次呼叫中觸發
	controller.select_unit(1)
	controller.click_tile(Vector2i(1, 0))

	# Assert
	assert_int(controller.phase()).is_equal(BattleController.Phase.FINISHED)
	assert_int(controller.outcome()).is_equal(BattleState.Outcome.VICTORY)
	assert_int(unit.active_modifiers().size()).is_equal(0)


# ---- 補測①:r=2 完整軌跡 -----------------------------------------------------

func test_supplementary_r2_full_trajectory_across_two_full_rounds() -> void:
	# Arrange
	var built: Dictionary = _build(_far_apart_roster(), [1], [2], _no_op_decide())
	var state: BattleState = built["state"]
	var controller: BattleController = built["controller"]
	var unit: Unit = state.unit_by_id(1)
	var baseline_def: int = unit.effective_def()
	unit.add_modifier(CardModifier.new("card_def_up_r2", 0, 4, 2))

	# 第 1 輪玩家回合 —— 本回合生效
	assert_int(unit.effective_def()).is_equal(baseline_def + 4)

	# 第 1 輪敵方回合 —— 仍生效
	controller.end_faction_phase()
	assert_int(unit.effective_def()).is_equal(baseline_def + 4)

	# 第 2 輪玩家回合開始 —— 遞減 2→1,尚未歸零,仍生效
	controller.run_enemy_phase()
	assert_int(controller.round_number()).is_equal(2)
	assert_int(unit.active_modifiers().size()).is_equal(1)
	assert_int(unit.active_modifiers()[0].remaining_turns).is_equal(1)
	assert_int(unit.effective_def()).is_equal(baseline_def + 4)

	# 第 2 輪敵方回合 —— 仍生效(r=1 涵蓋「本回合 + 緊接的敵方回合」,此刻
	# 的「本回合」就是第 2 輪)
	controller.end_faction_phase()
	assert_int(unit.effective_def()).is_equal(baseline_def + 4)

	# 第 3 輪玩家回合開始 —— 遞減 1→0,立即移除
	controller.run_enemy_phase()
	assert_int(controller.round_number()).is_equal(3)
	assert_int(unit.active_modifiers().size()).is_equal(0)
	assert_int(unit.effective_def()).is_equal(baseline_def)


# ---- 補測②:遞減先於補牌的順序 ------------------------------------------------
#
# CardDeck（Story 003)目前沒有被接進任何戰鬥驅動迴圈 —— grep 過
# src/ 底下沒有任何地方呼叫 CardDeck.draw_for_turn()，接線是未來 story 的
# 工作。這裡能證明的是：只要未來的接線遵守「先呼叫
# BattleState.tick_all_modifiers()（本 story 已經接在兩條驅動路徑的玩家回合
# 開始點),再呼叫 CardDeck.draw_for_turn()」這個順序，玩家在強制棄牌決策點
# 看到的盤面就不會殘留一個已到期的修正 —— 不是在證明「production 已經接好
# 了」，這點在完成判準裡會再次講清楚。
func test_supplementary_decrement_happens_before_forced_discard_decision_point() -> void:
	# Arrange — r=1 的修正,推進到「遞減至 0」的那個回合開始(重用 AC-4 的手法)
	var built: Dictionary = _build(_far_apart_roster(), [1], [2], _no_op_decide())
	var state: BattleState = built["state"]
	var controller: BattleController = built["controller"]
	var unit: Unit = state.unit_by_id(1)
	unit.add_modifier(CardModifier.new("card_def_up", 0, 4, 1))
	controller.end_faction_phase()
	controller.run_enemy_phase()  # 本 story 的鉤子：遞減 + 移除,已經發生

	# Arrange — 手牌已滿(5 張),卡池還有 1 張,補牌會觸發強制棄牌
	var pool_cards: Array[Card] = []
	for i: int in range(6):
		pool_cards.append(Card.new_temporary_stat_modifier("card_%d" % i, 1, 0, 1))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var deck: CardDeck = CardDeck.new(pool_cards, rng)
	deck.deal_opening_hand()  # 手牌 5,卡池剩 1
	assert_int(deck.hand_size()).is_equal(5)

	# Act — 補牌(下一步),觸發強制棄牌
	deck.draw_for_turn()

	# Assert — 抵達棄牌決策點時(has_pending_discard() 剛變 true),盤面上
	# 已經沒有那個到期的修正,不是等玩家棄完牌才消失
	assert_bool(deck.has_pending_discard()).is_true()
	assert_int(unit.active_modifiers().size()).is_equal(0)


# ---- 補測:「第一個玩家回合」不經過 run_enemy_phase() 的轉換路徑 --------------
#
# BattleController 全新建構時 _phase 就已經是 PLAYER_INPUT,不會呼叫
# TurnOrder.advance_faction()。這個測試不是在描述真實玩法(戰鬥開打前不可能
# 已經有修正掛在單位身上),純粹是結構性驗證：證明 _init() 裡新增的
# tick_all_modifiers() 呼叫真的會在這個分支上執行,而不是只在
# run_enemy_phase() 那個看起來比較「順手」的呼叫點上執行。

func test_supplementary_battle_controller_first_round_bypass_still_ticks_preexisting_modifier() -> void:
	# Arrange — 在建構 BattleController 之前,先把修正掛到單位身上
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(_far_apart_roster()))
	var unit: Unit = state.unit_by_id(1)
	unit.add_modifier(CardModifier.new("preexisting", 0, 4, 1))
	assert_int(unit.active_modifiers().size()).is_equal(1)

	# Act — 建構走的是「全新 controller 初始 _phase 已是 PLAYER_INPUT」這個分支
	var order: TurnOrder = TurnOrder.new([1], [2])
	var _controller: BattleController = BattleController.new(state, order)

	# Assert — 建構本身就是一次玩家回合開始事件,修正已經被遞減並移除
	assert_int(unit.active_modifiers().size()).is_equal(0)


# ---- BattleLoop 也要接到同一個共用鉤子,不是各寫一份 --------------------------

func _battle_loop_far_apart_roster() -> Array[String]:
	return _far_apart_roster()


# 用 r=2 的修正驗證 BattleLoop 每輪只在「進入玩家回合」的那次 advance_faction()
# 遞減一次 —— 如果誤植成兩個轉換點都遞減(玩家→敵方,以及敵方→玩家都算一次),
# r=2 撐不到 run(1) 回傳就會被遞減兩次而歸零;如果完全沒接上,r 會維持 2 不變。
# 兩種錯誤這個斷言都抓得到。
func test_battle_loop_ticks_modifier_exactly_once_per_round_at_player_turn_start() -> void:
	# Arrange — modifier 必須在 BattleLoop 建構「之後」才掛上去,否則會被
	# _init() 本身的「第一個玩家回合」鉤子先吃掉一次遞減,汙染這裡想單獨量測
	# 的「run() 內部那一次」(這正是本測試最初版本踩到的坑:先掛 r=2 再建構,
	# 結果建構時的鉤子先扣一次變 r=1,run(1) 裡的鉤子又扣一次直接歸零,
	# 於是斷言「還剩 1」失敗,實際是 0 —— 已修正為下面這個順序)。
	var roster_lines: Array[String] = _battle_loop_far_apart_roster()
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var decide: Callable = func(
		_s: BattleState, _id: int, _can_move: bool, _can_attack: bool
	) -> Dictionary:
		return {"move_to": null, "attack": -1}
	var loop: BattleLoop = BattleLoop.new(state, order, decide)
	var unit: Unit = state.unit_by_id(1)
	unit.add_modifier(CardModifier.new("card_def_up_r2", 0, 4, 2))

	# Act — max_rounds=1:round_number 在第 2 輪玩家階段開始那一刻變成 2,
	# 下一次迴圈頂端的 round_number() > max_rounds 判定為真,安全閥觸發返回。
	# 這代表「進入第 2 輪玩家回合」的遞減,已經在 run() 返回前發生過恰好一次。
	var result: Dictionary = loop.run(1)

	# Assert
	assert_bool(result["aborted"]).is_true()
	assert_int(unit.active_modifiers().size()).is_equal(1)
	assert_int(unit.active_modifiers()[0].remaining_turns).is_equal(1)


# 鏡射 BattleController 那條「第一個玩家回合不經過轉換路徑」的分支驗證,
# 換成 BattleLoop 的建構子。
func test_supplementary_battle_loop_first_round_bypass_still_ticks_preexisting_modifier() -> void:
	# Arrange
	var state: BattleState = BattleState.create(
		PackedStringArray(), "\n".join(_battle_loop_far_apart_roster())
	)
	var unit: Unit = state.unit_by_id(1)
	unit.add_modifier(CardModifier.new("preexisting", 0, 4, 1))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var decide: Callable = func(
		_s: BattleState, _id: int, _can_move: bool, _can_attack: bool
	) -> Dictionary:
		return {"move_to": null, "attack": -1}

	# Act
	var _loop: BattleLoop = BattleLoop.new(state, order, decide)

	# Assert
	assert_int(unit.active_modifiers().size()).is_equal(0)


# AC-11a 的 BattleLoop 對照組 —— 證明清除鉤子不是只接在 BattleController 那條
# 路徑上。
func test_battle_loop_clears_all_active_modifiers_on_battle_end() -> void:
	# Arrange — 玩家與唯一的敵人相鄰,玩家一擊可斃敵人
	var roster_lines: Array[String] = [
		"1,P1,PLAYER,20,10,3,1,1,1,0,0",
		"2,E1,ENEMY,1,1,0,0,1,1,1,0",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var unit: Unit = state.unit_by_id(1)
	unit.add_modifier(CardModifier.new("card_def_up", 0, 4, 2))
	var decide: Callable = func(
		_s: BattleState, unit_id: int, _can_move: bool, can_attack: bool
	) -> Dictionary:
		if unit_id == 1 and can_attack:
			return {"move_to": null, "attack": 2}
		return {"move_to": null, "attack": -1}
	var loop: BattleLoop = BattleLoop.new(state, order, decide)

	# Act
	var result: Dictionary = loop.run(20)

	# Assert
	assert_int(result["outcome"]).is_equal(BattleState.Outcome.VICTORY)
	assert_int(unit.active_modifiers().size()).is_equal(0)
