# CardDeck 接進戰鬥迴圈（story-006-battle-loop-wiring.md）的整合測試 ——
# 涵蓋 AC-W1 ~ AC-W6。獨立測試檔，不與其他卡牌測試檔共用，理由同專案慣例
# （一條真實失敗會讓同檔案後面的測試全部不執行，拆檔避免互相拖累）。
#
# 🔴 BattleController 與 BattleLoop 是兩條互不呼叫的獨立驅動路徑，各自在自己
# 的三個位置接上 BattleState.deal_opening_hand() / begin_player_turn() /
# return_cards_to_pool()——「只接了一條」的失敗方式是另一條測起來全綠、實際
# 靜默不發牌。因此 AC-W1 / AC-W2 / AC-W3 每一條都各測 controller 與 loop
# 兩次，不只測其中一條。
#
# 全鏈路（BattleState/BattleController/BattleLoop/TurnOrder/Unit/CardDeck/
# Card/CardModifier）都是 RefCounted，不建立任何 Node，不會留下孤兒節點。
extends GdUnitTestSuite


# 行為層的間諜卡池，只覆寫 draw_for_turn() ——在被呼叫的「當下」（委派給父類別
# 真正執行抽牌之前）記錄 unit_for_spy 此刻的 active_modifiers() 張數，再呼叫
# super.draw_for_turn() 讓抽牌行為完全不變。這是 AC-W3 唯一能在
# BattleState.begin_player_turn() 這個單一同步呼叫「進行中」取樣的方法——見
# 下面 AC-W3 兩條功能測試前的誠實揭露：呼叫返回之後才查最終狀態，兩種順序看
# 起來一樣，因為 tick_all_modifiers()（改 Unit._modifiers）與
# CardDeck.draw_for_turn()（改 CardDeck 自己的三個陣列）彼此不讀對方的資料。
# 這個間諜之所以能分辨順序，是因為它取樣的時間點是「draw 自己被呼叫的那一
# 刻」，而不是兩者都執行完之後——如果 tick 還沒跑（順序對調的錯誤實作），
# 這一刻讀到的 active_modifiers().size() 就會是 1，不是 0。
#
# GDScript 支援子類別覆寫父類別的一般方法並透過父類別型別的變數動態分派
# （不需要 virtual/override 關鍵字），且未覆寫 _init() 的子類別會自動把建構
# 參數轉呼叫父類別的 _init()——CardDeck._init(cards, rng) 因此不必在這裡重寫。
class _SpyCardDeck extends CardDeck:
	var unit_for_spy: Unit = null
	var active_modifier_count_when_drawn: int = -1

	func draw_for_turn() -> void:
		if unit_for_spy != null:
			active_modifier_count_when_drawn = unit_for_spy.active_modifiers().size()
		super.draw_for_turn()


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


# 彼此打不到、走不到的最小名冊（mp=0，射程 1 但距離遠超過 1）—— 沿用
# tests/unit/gameplay/cards/card_modifier_lifecycle_test.gd 的手法，讓測試只
# 關心回合怎麼推進、卡牌怎麼進出，不被戰鬥結算干擾。
func _far_apart_roster() -> Array[String]:
	return [
		"1,P1,PLAYER,20,5,3,0,1,1,0,0",
		"2,E1,ENEMY,20,5,3,0,1,1,12,5",
	]


# 相鄰、玩家一擊必殺的名冊，只用於 AC-W4/AC-W6 的「戰鬥結束」情境 —— 沿用
# tests/unit/gameplay/battle/battle_controller_test.gd
# test_attack_that_ends_battle_emits_battle_ended_and_finishes_phase() 的
# 現成數值（已驗證一擊必死），不自己重編一組。
func _lethal_roster() -> Array[String]:
	return [
		"1,P1,PLAYER,20,999,0,0,1,1,0,0",
		"2,E1,ENEMY,1,0,0,0,1,1,1,0",
	]


func _lethal_attack_decide() -> Callable:
	return func(
		_state: BattleState, unit_id: int, _can_move: bool, can_attack: bool
	) -> Dictionary:
		if unit_id == 1 and can_attack:
			return {"move_to": null, "attack": 2}
		return {"move_to": null, "attack": -1}


func _build_controller(
	roster_lines: Array[String], deck: CardDeck, decide: Callable
) -> Dictionary:
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var controller: BattleController = BattleController.new(state, order, Callable(), decide, deck)
	return {"state": state, "order": order, "controller": controller}


func _build_loop(roster_lines: Array[String], deck: CardDeck, decide: Callable) -> Dictionary:
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var loop: BattleLoop = BattleLoop.new(state, order, decide, deck)
	return {"state": state, "order": order, "loop": loop}


# ---- AC-W1:開局發牌 ----------------------------------------------------------
#
# 判斷題（工作單要求的裁決,已標記待管理者確認,見本 story 的回報）：本專案選
# 「第一回合固定 5 張,不額外多補 1 張」——見
# src/gameplay/battle/battle_state.gd 的 deal_opening_hand() 文件註解。這裡
# 驗證的正是這個選擇的結果：手牌剛好是 CardDeck.OPENING_HAND_SIZE（5），不是
# 6。

func test_ac_w1_controller_construction_deals_opening_hand_of_five() -> void:
	# Arrange / Act
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), _seeded_rng(1))
	var built: Dictionary = _build_controller(_far_apart_roster(), deck, _no_op_decide())
	var state: BattleState = built["state"]

	# Assert
	assert_object(state.card_deck()).is_same(deck)
	assert_int(deck.hand_size()).is_equal(5)
	assert_int(deck.pool_size()).is_equal(5)
	assert_int(deck.used_size()).is_equal(0)


func test_ac_w1_loop_construction_deals_opening_hand_of_five() -> void:
	# Arrange / Act
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), _seeded_rng(1))
	var built: Dictionary = _build_loop(_far_apart_roster(), deck, _no_op_decide())
	var state: BattleState = built["state"]

	# Assert
	assert_object(state.card_deck()).is_same(deck)
	assert_int(deck.hand_size()).is_equal(5)
	assert_int(deck.pool_size()).is_equal(5)
	assert_int(deck.used_size()).is_equal(0)


# ---- AC-W2:敵方回合結束、轉回玩家 -> 手牌 +1 ----------------------------------

func test_ac_w2_controller_hand_grows_by_one_when_enemy_phase_ends() -> void:
	# Arrange
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), _seeded_rng(2))
	var built: Dictionary = _build_controller(_far_apart_roster(), deck, _no_op_decide())
	var controller: BattleController = built["controller"]
	assert_int(deck.hand_size()).is_equal(5)  # 前提：開局手牌已到位

	# Act
	controller.end_faction_phase()
	controller.run_enemy_phase()

	# Assert
	assert_int(controller.round_number()).is_equal(2)
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(deck.hand_size()).is_equal(6)


# 🔴 BattleLoop.run() 是原子呼叫，跑到 max_rounds 上限才返回，中途無法從外部
# 觀察。max_rounds=1 這個特定值不是隨便選的：逐步手算 TurnOrder 的推進序列
# （見本檔開發過程紀錄）確認 run(1) 會且僅會觸發「回合 2 開始」這一次
# begin_player_turn()，然後在還沒處理回合 2 任何單位動作之前，就因為
# round_number()(2) > max_rounds(1) 而返回 aborted——這正好是「補了 1 張、
# 但還沒有任何後續呼叫介入」的那個時點,不多不少。
func test_ac_w2_loop_hand_grows_by_one_at_round_two_player_turn_start() -> void:
	# Arrange
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), _seeded_rng(2))
	var built: Dictionary = _build_loop(_far_apart_roster(), deck, _no_op_decide())
	var loop: BattleLoop = built["loop"]
	assert_int(deck.hand_size()).is_equal(5)

	# Act
	var result: Dictionary = loop.run(1)

	# Assert
	assert_bool(result["aborted"]).is_true()
	assert_int(deck.hand_size()).is_equal(6)


# ---- AC-W3:順序契約 ---------------------------------------------------------
#
# 🔴 誠實揭露（先讀這段,再讀下面兩條測試）：BattleState.begin_player_turn()
# 裡 tick_all_modifiers()（只讀寫 Unit._modifiers）與 CardDeck.draw_for_turn()
# （只讀寫 CardDeck 自己的三個陣列）彼此不讀對方的資料，而且兩行之間沒有任何
# signal 觸發、沒有 await——在這個前提下，對調這兩行呼叫的「最終狀態」（呼叫
# 返回之後 has_pending_discard() 與 active_modifiers() 的值）逐位元相同,不
# 論先後順序為何。這不是本檔測試寫得不夠仔細,是這兩個操作在目前的資料模型下
# 彼此因果獨立這一事實本身,讓「呼叫後才查最終狀態」這種寫法在本 story 的範圍
# 內結構性地測不出順序——已用敏感度證明實測驗證(見完成判準段落與最終回報)。
#
# 因此下面兩條「功能」測試各自證明的是「tick 與 draw 兩件事都真的發生了、且
# 在呼叫返回時已經反映在盤面上」（漏接其中一個仍抓得到——這是真實的接線
# 迴歸風險：忘記呼叫 draw_for_turn()，或忘記在有卡池時仍呼叫 tick），而不是
# 順序本身。順序契約真正的迴歸防護是再下面那一條靜態原始碼順序測試。

func test_ac_w3_controller_modifier_expires_before_forced_discard_becomes_pending() -> void:
	# Arrange — 10 張牌池，開局發 5 張手牌已滿（HAND_SIZE_LIMIT == OPENING_HAND_SIZE
	# == 5），卡池還有 5 張，補牌必定觸發強制棄牌
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), _seeded_rng(3))
	var built: Dictionary = _build_controller(_far_apart_roster(), deck, _no_op_decide())
	var state: BattleState = built["state"]
	var controller: BattleController = built["controller"]
	var unit: Unit = state.unit_by_id(1)
	unit.add_modifier(CardModifier.new("card_def_up", 0, 4, 1))  # r=1
	assert_int(unit.active_modifiers().size()).is_equal(1)

	# Act — 玩家結束回合、敵方回合跑完，觸發「回到玩家」這個轉換點——本 story
	# 唯一真正接了 tick+draw 的呼叫點（BattleState.begin_player_turn()）
	controller.end_faction_phase()
	controller.run_enemy_phase()

	# Assert — run_enemy_phase() 剛返回、玩家還沒做任何棄牌決定，就已經是
	# 「等待棄牌」狀態，而且修正已經不在 active_modifiers() 裡——這是這唯一一次
	# 呼叫裡，tick 與 draw 都跑過之後、且尚未有任何後續呼叫介入的最早可觀測時點
	assert_bool(deck.has_pending_discard()).is_true()
	assert_int(unit.active_modifiers().size()).is_equal(0)


func test_ac_w3_loop_modifier_expires_before_forced_discard_becomes_pending() -> void:
	# Arrange — 手法同 AC-W2 的 loop 測試：max_rounds=1 讓 run() 恰好在「回合 2
	# 開始」（begin_player_turn() 觸發）之後、任何回合 2 動作處理之前返回
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), _seeded_rng(3))
	var built: Dictionary = _build_loop(_far_apart_roster(), deck, _no_op_decide())
	var state: BattleState = built["state"]
	var loop: BattleLoop = built["loop"]
	var unit: Unit = state.unit_by_id(1)
	unit.add_modifier(CardModifier.new("card_def_up", 0, 4, 1))

	# Act
	var result: Dictionary = loop.run(1)

	# Assert
	assert_bool(result["aborted"]).is_true()
	assert_bool(deck.has_pending_discard()).is_true()
	assert_int(unit.active_modifiers().size()).is_equal(0)


# ---- AC-W3 補充：行為層的間諜證明（不只查最終狀態，直接在 draw 發生的當下取樣）--
#
# 上面兩條測試已經誠實揭露：查「呼叫返回後」的最終狀態測不出順序。這兩條改用
# _SpyCardDeck（見本檔頂部類別定義）在 draw_for_turn() 被呼叫的那一刻——而不是
# 之後——讀 unit.active_modifiers().size()。正確順序（先 tick 後 draw）下這裡
# 必須是 0；若順序對調，draw 被呼叫時 tick 還沒發生，這裡會讀到 1。

func test_ac_w3_controller_spy_deck_observes_modifier_already_removed_when_draw_is_called() -> void:
	# Arrange
	var deck: _SpyCardDeck = _SpyCardDeck.new(_make_unique_cards(10), _seeded_rng(3))
	var built: Dictionary = _build_controller(_far_apart_roster(), deck, _no_op_decide())
	var state: BattleState = built["state"]
	var controller: BattleController = built["controller"]
	var unit: Unit = state.unit_by_id(1)
	deck.unit_for_spy = unit
	unit.add_modifier(CardModifier.new("card_def_up", 0, 4, 1))  # r=1
	assert_int(unit.active_modifiers().size()).is_equal(1)

	# Act — 觸發 begin_player_turn()；deck.draw_for_turn() 內部會在委派給父類別
	# 執行抽牌之前，先把 unit.active_modifiers().size() 記錄下來
	controller.end_faction_phase()
	controller.run_enemy_phase()

	# Assert — draw 被呼叫的那一刻，修正已經被 tick_all_modifiers() 移除
	assert_int(deck.active_modifier_count_when_drawn).is_equal(0)
	assert_bool(deck.has_pending_discard()).is_true()  # 前提：draw 真的發生了


func test_ac_w3_loop_spy_deck_observes_modifier_already_removed_when_draw_is_called() -> void:
	# Arrange — 手法同前面 AC-W2/AC-W3 的 loop 測試：max_rounds=1
	var deck: _SpyCardDeck = _SpyCardDeck.new(_make_unique_cards(10), _seeded_rng(3))
	var built: Dictionary = _build_loop(_far_apart_roster(), deck, _no_op_decide())
	var state: BattleState = built["state"]
	var loop: BattleLoop = built["loop"]
	var unit: Unit = state.unit_by_id(1)
	deck.unit_for_spy = unit
	unit.add_modifier(CardModifier.new("card_def_up", 0, 4, 1))

	# Act
	var result: Dictionary = loop.run(1)

	# Assert
	assert_bool(result["aborted"]).is_true()
	assert_int(deck.active_modifier_count_when_drawn).is_equal(0)
	assert_bool(deck.has_pending_discard()).is_true()


# 🔴 順序契約的真正迴歸防護：直接檢查 begin_player_turn() 的原始碼裡
# tick_all_modifiers() 是否確實出現在 draw_for_turn() 之前。上面兩條功能測試
# 已經證明無法用最終狀態區分順序（見本節開頭的誠實揭露）——這條測試存在的
# 唯一理由，就是給「有人把這兩行對調」這個具體錯誤一個會變紅的斷言。敏感度
# 證明：把 src/gameplay/battle/battle_state.gd 裡這兩行對調後重跑，本測試從
# 綠轉紅（見本 story 最終回報的敏感度證明段落）；對調之後已還原。
func test_ac_w3_begin_player_turn_calls_tick_before_draw_in_source_order() -> void:
	# Arrange
	var source: String = FileAccess.get_file_as_string(
		"res://src/gameplay/battle/battle_state.gd"
	)
	var func_start: int = source.find("func begin_player_turn")
	assert_int(func_start).is_greater(-1)
	var next_func_start: int = source.find("\nfunc ", func_start + 1)
	var body: String = source.substr(func_start, next_func_start - func_start)

	# Act
	var tick_pos: int = body.find("tick_all_modifiers()")
	var draw_pos: int = body.find("draw_for_turn()")

	# Assert
	assert_int(tick_pos).is_greater(-1)
	assert_int(draw_pos).is_greater(-1)
	assert_bool(tick_pos < draw_pos).is_true()


# ---- AC-W4:戰鬥結束 -> 手牌與已用區全部回到卡池 -------------------------------

func test_ac_w4_controller_battle_end_returns_all_cards_to_pool() -> void:
	# Arrange
	var deck: CardDeck = CardDeck.new(_make_unique_cards(8), _seeded_rng(4))
	var built: Dictionary = _build_controller(_lethal_roster(), deck, _no_op_decide())
	var controller: BattleController = built["controller"]
	assert_int(deck.hand_size()).is_equal(5)
	assert_int(deck.total_card_count()).is_equal(8)
	assert_bool(controller.select_unit(1)).is_true()

	# Act — 相鄰、一擊必死，戰鬥當場結束
	var result: Dictionary = controller.click_tile(Vector2i(1, 0))

	# Assert
	assert_that(result["action"]).is_equal(&"attacked")
	assert_int(controller.outcome()).is_equal(BattleState.Outcome.VICTORY)
	assert_int(controller.phase()).is_equal(BattleController.Phase.FINISHED)
	assert_int(deck.hand_size()).is_equal(0)
	assert_int(deck.used_size()).is_equal(0)
	assert_int(deck.pool_size()).is_equal(8)
	assert_int(deck.total_card_count()).is_equal(8)


func test_ac_w4_loop_battle_end_returns_all_cards_to_pool() -> void:
	# Arrange
	var deck: CardDeck = CardDeck.new(_make_unique_cards(8), _seeded_rng(4))
	var built: Dictionary = _build_loop(_lethal_roster(), deck, _lethal_attack_decide())
	var loop: BattleLoop = built["loop"]
	assert_int(deck.hand_size()).is_equal(5)
	assert_int(deck.total_card_count()).is_equal(8)

	# Act
	var result: Dictionary = loop.run(5)

	# Assert
	assert_int(result["outcome"]).is_equal(BattleState.Outcome.VICTORY)
	assert_bool(result["aborted"]).is_false()
	assert_int(deck.hand_size()).is_equal(0)
	assert_int(deck.used_size()).is_equal(0)
	assert_int(deck.pool_size()).is_equal(8)
	assert_int(deck.total_card_count()).is_equal(8)


# ---- AC-W5:敵方回合不補牌 ----------------------------------------------------
#
# 手法：讓注入的 decide 本身順手記錄「敵方單位被問到決策的那一刻」手牌張數
# ——這是一個貨真價實的呼叫中點觀察窗（decide 本來就會在 run_enemy_phase()
# 執行途中被呼叫），不像 AC-W3 那樣受限於「呼叫返回後才能查」。

func test_ac_w5_controller_hand_size_unchanged_while_enemy_unit_is_deciding() -> void:
	# Arrange — 🔴 GDScript 的 lambda 對外部區域變數是「建立當下拷貝值」,在
	# lambda 內對它賦值不會反映回外層變數(這是本檔第一版撞到的真實坑:第一次
	# 寫成 `var hand_size_during_enemy_decide: int = -1`,斷言永遠讀到初始值
	# -1,即使 decide 確實被呼叫過)。改用單元素 Array 當「輸出參數」——Array
	# 本身是參照型別,lambda 對其元素賦值會反映回外層看到的同一個 Array。
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), _seeded_rng(5))
	var hand_size_during_enemy_decide: Array = [-1]
	var decide: Callable = func(
		_state: BattleState, unit_id: int, _can_move: bool, _can_attack: bool
	) -> Dictionary:
		if unit_id == 2:
			hand_size_during_enemy_decide[0] = deck.hand_size()
		return {"move_to": null, "attack": -1}
	var built: Dictionary = _build_controller(_far_apart_roster(), deck, decide)
	var controller: BattleController = built["controller"]
	assert_int(deck.hand_size()).is_equal(5)

	# Act
	controller.end_faction_phase()
	controller.run_enemy_phase()

	# Assert — 敵方單位 2 被問到決策的那一刻，手牌仍是開局的 5 張，補牌邏輯
	# 完全沒有在敵方回合中途動過它
	assert_int(hand_size_during_enemy_decide[0]).is_equal(5)
	# 事後（轉回玩家）確實補了 1 張，證明上面量到的「5」是「接對了時序」而不是
	# 「補牌邏輯根本沒被接上」
	assert_int(deck.hand_size()).is_equal(6)


func test_ac_w5_loop_hand_size_unchanged_while_enemy_unit_is_deciding() -> void:
	# Arrange — 同上一條的說明：用單元素 Array 繞過 lambda 對外部純量變數
	# 賦值不會外溢的限制。
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), _seeded_rng(5))
	var hand_size_during_enemy_decide: Array = [-1]
	var decide: Callable = func(
		_state: BattleState, unit_id: int, _can_move: bool, _can_attack: bool
	) -> Dictionary:
		if unit_id == 2:
			hand_size_during_enemy_decide[0] = deck.hand_size()
		return {"move_to": null, "attack": -1}
	var built: Dictionary = _build_loop(_far_apart_roster(), deck, decide)
	var loop: BattleLoop = built["loop"]
	assert_int(deck.hand_size()).is_equal(5)

	# Act
	loop.run(1)

	# Assert
	assert_int(hand_size_during_enemy_decide[0]).is_equal(5)
	assert_int(deck.hand_size()).is_equal(6)


# ---- AC-W6:未附卡池時,建構與整場戰鬥皆不崩潰 ---------------------------------

func test_ac_w6_controller_without_deck_does_not_crash_and_card_deck_is_null() -> void:
	# Arrange / Act
	var built: Dictionary = _build_controller(_far_apart_roster(), null, _no_op_decide())
	var state: BattleState = built["state"]
	var controller: BattleController = built["controller"]

	# Assert — 建構本身不崩潰，且卡池查詢誠實回報「沒有」
	assert_object(state.card_deck()).is_null()

	# Act 2 — 跑完一輪轉換，行為與接線前逐字相同（round 前進、phase 正確）
	controller.end_faction_phase()
	controller.run_enemy_phase()

	# Assert 2
	assert_int(controller.round_number()).is_equal(2)
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)


func test_ac_w6_loop_without_deck_does_not_crash_and_card_deck_is_null() -> void:
	# Arrange / Act
	var built: Dictionary = _build_loop(_far_apart_roster(), null, _no_op_decide())
	var state: BattleState = built["state"]
	var loop: BattleLoop = built["loop"]

	# Assert
	assert_object(state.card_deck()).is_null()

	var result: Dictionary = loop.run(1)
	assert_bool(result["aborted"]).is_true()


func test_ac_w6_controller_without_deck_battle_end_does_not_crash() -> void:
	# Arrange
	var built: Dictionary = _build_controller(_lethal_roster(), null, _no_op_decide())
	var controller: BattleController = built["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(1, 0))

	# Assert — return_cards_to_pool() 的 no-op 半支在無卡池時不崩潰，戰鬥照樣
	# 正常分出勝負
	assert_that(result["action"]).is_equal(&"attacked")
	assert_int(controller.outcome()).is_equal(BattleState.Outcome.VICTORY)
	assert_int(controller.phase()).is_equal(BattleController.Phase.FINISHED)
