# BattleController（src/gameplay/battle/battle_controller.gd）的單元測試。
#
# BattleController 是玩家互動的狀態機，把「玩家點了什麼」翻譯成對 BattleState
# 與 TurnOrder 的合法操作。大多數測試自建最小名冊（PackedStringArray() 空地形
# 讀入 → 全開闊地，13x6 棋盤邊界不變，沿用 battle_loop_test.gd 的手法），只有
# 一支測試用真實 vs01 資料（terrain + roster）驗證與正式關卡的整合，其餘用自建
# 小棋盤做邊界情境——這是規格允許的做法。
#
# 命名慣例沿用既有先例（test_[scenario]_[expected]）。不建立任何 Node ——
# BattleController 全鏈路（TurnOrder/BattleState/Board/Unit/CombatRules/
# GreedyTacticalAI）都是 RefCounted 或 static，不會留下孤兒節點；唯一的
# Object 子類別（_PhiStub，用於製造「provider 失效」情境）在每個用到它的測試
# 裡明確 free()，不留下未回收的 Object。
extends GdUnitTestSuite


# 純資料 stub，只用來製造一個可以被 Callable 綁定、且能被手動 free() 使其
# is_valid() 變 false 的 Φ 供應器。刻意 extends Object 而非 RefCounted——
# RefCounted 的 Callable 綁定會持有強參照，正常使用下不會變成失效狀態，
# 無法用來測試「provider 失效」這個規格要求的情境。
class _PhiStub extends Object:
	var value: int = 0

	func compute(_attacker_id: int, _target_id: int) -> int:
		return value


# 「敵對 decide」自我上限，只給 test_run_enemy_phase_terminates_when_
# injected_decide_ignores_flags() 用。旗標閘門正常運作時，這個上限永遠碰
# 不到（單位在被問到第 2 次就會因為兩個旗標都花完而 done）——這個數字存
# 在的唯一理由,是把「閘門失效時測試會怎樣」從「掛住」變成「失敗」。
#
# 沒有這個上限,一旦哪天有人把 _process_enemy_unit() 的旗標檢查拿掉,
# relentless 版 decide 會被無限次呼叫、run_enemy_phase() 的 while true
# 真的不會返回——GDScript 是同步執行,GdUnit4 的逾時機制攔不住一個同步無
# 限迴圈,那樣整個測試 job 會卡死等外部逾時,而不是紅燈。CI 上「卡死」跟
# 「失敗」完全不是一回事：前者不會指出是哪一條斷言錯了,甚至不一定會被
# 辨識成這支測試的問題,只會讓整個 pipeline 逾時,失去所有防護力。
#
# 加上這個上限之後,閘門失效時 decide 會被問到第 51 次才不再耍賴,
# call_counts 停在 51,`assert_int(call_counts.get(2, 0)).is_equal(2)`
# 這行會明確失敗並印出「51 != 2」——測試在跑得完的前提下失敗,而不是
# 跑不完。
const _RELENTLESS_DECIDE_CALL_LIMIT: int = 50


# ---- fixtures --------------------------------------------------------------

# 建一份最小 BattleState/TurnOrder/BattleController 三件套。地形一律空白
# PackedStringArray()（Board.from_ascii 對缺列預設回開闊地，13x6 邊界仍由
# Board 的常數決定,不受輸入列數影響),讓每個測試只需關心單位數值本身。
func _build(
	roster_lines: Array[String],
	player_ids: Array[int],
	enemy_ids: Array[int],
	phi_provider: Callable = Callable(),
	decide: Callable = Callable()
) -> Dictionary:
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new(player_ids, enemy_ids)
	var controller: BattleController = BattleController.new(state, order, phi_provider, decide)
	return {"state": state, "order": order, "controller": controller}


func _load_terrain_rows() -> PackedStringArray:
	var file: FileAccess = FileAccess.open(
		"res://assets/data/levels/vs01_terrain.txt", FileAccess.READ
	)
	assert_object(file).is_not_null()

	var rows: PackedStringArray = PackedStringArray()
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.is_empty() and file.eof_reached():
			break
		rows.append(line)
	file.close()
	return rows


func _load_roster_text() -> String:
	return FileAccess.get_file_as_string("res://assets/data/units/vs01_roster.txt")


# ---- construction with real vs01 data --------------------------------------

func test_construction_with_vs01_data_lists_five_selectable_player_units() -> void:
	# Arrange
	var state: BattleState = BattleState.create(_load_terrain_rows(), _load_roster_text())
	var player_ids: Array[int] = [1, 2, 3, 4, 5]
	var enemy_ids: Array[int] = [6, 7, 8, 9, 10]
	var order: TurnOrder = TurnOrder.new(player_ids, enemy_ids)
	var controller: BattleController = BattleController.new(state, order)

	# Act / Assert
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(controller.round_number()).is_equal(1)
	assert_int(controller.outcome()).is_equal(BattleState.Outcome.ONGOING)
	assert_array(controller.selectable_units()).is_equal([1, 2, 3, 4, 5])


# ---- select_unit() rejection cases — 狀態不變 --------------------------------

func test_select_unit_rejects_wrong_faction_and_state_unchanged() -> void:
	# Arrange
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]

	# Act — 敵方單位在玩家階段不可選
	var selected: bool = controller.select_unit(2)

	# Assert
	assert_bool(selected).is_false()
	assert_int(controller.selected_unit()).is_equal(-1)


func test_select_unit_rejects_nonexistent_unit_and_state_unchanged() -> void:
	# Arrange
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]

	# Act
	var selected: bool = controller.select_unit(999)

	# Assert
	assert_bool(selected).is_false()
	assert_int(controller.selected_unit()).is_equal(-1)


func test_select_unit_rejects_done_unit_and_state_unchanged() -> void:
	# Arrange — 直接操作底層 TurnOrder 讓單位 1 已結束回合（白箱佈置，
	# 不透過 controller，模擬「這個單位已經 done」的情境）
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	order.end_unit_turn(1)

	# Act
	var selected: bool = controller.select_unit(1)

	# Assert
	assert_bool(selected).is_false()
	assert_int(controller.selected_unit()).is_equal(-1)


func test_select_unit_rejects_dead_unit_and_state_unchanged() -> void:
	# Arrange — 直接操作底層 BattleState 打死單位 1（白箱佈置，繞過
	# controller，只是要製造「這個 id 存在過、但已陣亡」的情境）
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]
	while state.unit_by_id(1).is_alive():
		state.resolve_attack(2, 1, 0)

	# Act
	var selected: bool = controller.select_unit(1)

	# Assert
	assert_bool(selected).is_false()
	assert_int(controller.selected_unit()).is_equal(-1)


func test_select_unit_valid_unit_selects() -> void:
	# Arrange
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]

	# Act
	var selected: bool = controller.select_unit(1)

	# Assert
	assert_bool(selected).is_true()
	assert_int(controller.selected_unit()).is_equal(1)


# ---- click_tile() — 四種 action 各一 -----------------------------------------
#
# 「其餘 → 取消選取或 &"none"」的裁決：本檔選擇有選取時回傳 &"deselected"、
# 無選取時回傳 &"none"，而不是固定回傳其中一個。理由寫在
# battle_controller.gd 的 click_tile() 類別文件註解裡——固定回傳 &"none"
# 會讓 &"deselected" 在整個類別的任何 Dictionary 回傳值裡都變成永遠打不到
# 的死碼（deselect() 的回傳型別是 void，不會出現在任何 Dictionary 裡）。

func test_click_tile_selects_own_faction_unit() -> void:
	# Arrange
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(0, 0))

	# Assert
	assert_that(result["action"]).is_equal(&"selected")
	assert_int(result["unit_id"]).is_equal(1)
	assert_int(controller.selected_unit()).is_equal(1)


func test_click_tile_moves_selected_unit_into_move_target() -> void:
	# Arrange — 單位 1 mp=3，起點 (0,0)，移動到開闊地 (1,0) 只需 1 點
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(1, 0))

	# Assert
	assert_that(result["action"]).is_equal(&"moved")
	assert_int(result["unit_id"]).is_equal(1)
	assert_vector(result["from"]).is_equal(Vector2i(0, 0))
	assert_vector(result["to"]).is_equal(Vector2i(1, 0))
	assert_vector(state.position_of(1)).is_equal(Vector2i(1, 0))
	assert_bool(order.can_move(1)).is_false()


func test_click_tile_attacks_enemy_in_range() -> void:
	# Arrange — 單位 1 atk=10 def=0，射程 1；目標 2 hp=5 def=0，一擊必死；
	# 另有單位 3 站在遠處存活，避免這一擊觸發 VICTORY（讓這支測試只驗
	# "attacked" 這個 action 的資料形狀,不跟 outcome 轉場混在一起)
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,E1,ENEMY,5,0,0,0,1,1,1,0",
		"3,E2,ENEMY,20,0,0,0,1,1,10,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2, 3])
	var state: BattleState = bundle["state"]
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(1, 0))

	# Assert — 傷害、死亡旗標都對
	assert_that(result["action"]).is_equal(&"attacked")
	assert_int(result["damage"]).is_equal(10)
	assert_int(result["target_id"]).is_equal(2)
	assert_bool(result["target_died"]).is_true()

	# Assert — 陣亡單位同時離開棋盤(佔位表)與行動序(TurnOrder)
	assert_bool(state.board.has_occupant(Vector2i(1, 0))).is_false()
	assert_bool(state.unit_by_id(2).is_alive()).is_false()
	assert_bool(order.is_done(2)).is_true()  # 未被追蹤的 id 一律回報為 done

	# 戰局仍在進行(單位 3 還活著)
	assert_int(controller.outcome()).is_equal(BattleState.Outcome.ONGOING)


func test_click_tile_returns_none_when_nothing_relevant_clicked() -> void:
	# Arrange — 沒有任何選取，點一格空地
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(5, 5))

	# Assert
	assert_that(result["action"]).is_equal(&"none")
	assert_int(controller.selected_unit()).is_equal(-1)


func test_click_tile_residual_click_deselects_active_selection() -> void:
	# Arrange — 單位 1 mp=0、射程 1，選取後點一格既非移動也非攻擊目標的空地
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,0,1,1,0,0",
		"2,E1,ENEMY,20,5,0,0,1,1,10,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(6, 3))

	# Assert
	assert_that(result["action"]).is_equal(&"deselected")
	assert_int(controller.selected_unit()).is_equal(-1)


# ---- 移動與攻擊旗標互相獨立 ---------------------------------------------------

func test_move_does_not_consume_attack_flag() -> void:
	# Arrange — 單位 1 射程 1~3,移動到 (1,0) 之後距離敵方仍在射程內
	var roster: Array[String] = [
		"1,P1,PLAYER,100,10,0,5,1,3,0,0",
		"2,E1,ENEMY,500,0,0,0,1,1,2,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()
	var move_result: Dictionary = controller.click_tile(Vector2i(1, 0))
	assert_that(move_result["action"]).is_equal(&"moved")

	# Act — 移動後單位仍被選取(未 done),再點目標格應該能攻擊
	assert_bool(order.can_attack(1)).is_true()
	var attack_result: Dictionary = controller.click_tile(Vector2i(2, 0))

	# Assert
	assert_that(attack_result["action"]).is_equal(&"attacked")
	assert_bool(order.can_move(1)).is_false()
	assert_bool(order.can_attack(1)).is_false()


func test_attack_does_not_consume_move_flag() -> void:
	# Arrange — 單位 1 射程 1~3,起點即可攻擊到 (2,0) 的敵人,不需先移動
	var roster: Array[String] = [
		"1,P1,PLAYER,100,10,0,5,1,3,0,0",
		"2,E1,ENEMY,500,0,0,0,1,1,2,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()
	var attack_result: Dictionary = controller.click_tile(Vector2i(2, 0))
	assert_that(attack_result["action"]).is_equal(&"attacked")

	# Act — 攻擊後單位仍被選取(未 done),再點一格開闊地應該能移動
	assert_bool(order.can_move(1)).is_true()
	var move_result: Dictionary = controller.click_tile(Vector2i(0, 1))

	# Assert
	assert_that(move_result["action"]).is_equal(&"moved")
	assert_vector(state.position_of(1)).is_equal(Vector2i(0, 1))
	assert_bool(order.can_attack(1)).is_false()
	assert_bool(order.can_move(1)).is_false()


# ---- end_unit_turn() / end_faction_phase() ----------------------------------

func test_end_unit_turn_clears_selection_if_that_unit_was_selected() -> void:
	# Arrange
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var ended: bool = controller.end_unit_turn(1)

	# Assert
	assert_bool(ended).is_true()
	assert_int(controller.selected_unit()).is_equal(-1)
	assert_bool(order.is_done(1)).is_true()


func test_end_faction_phase_transitions_to_enemy_acting_and_clears_selection() -> void:
	# Arrange
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	controller.end_faction_phase()

	# Assert
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)
	assert_int(controller.selected_unit()).is_equal(-1)
	assert_array(controller.selectable_units()).is_empty()  # 非 PLAYER_INPUT 時恆空


# ---- run_enemy_phase() -------------------------------------------------------

func test_run_enemy_phase_returns_to_player_phase_with_flags_reset() -> void:
	# Arrange — 雙方都是零移動力、射程互不可及的被動單位,敵方階段唯一會發生
	# 的事是「什麼都不做,結束回合」,藉此把焦點放在階段轉場本身而非戰鬥細節
	var roster: Array[String] = [
		"1,P1,PLAYER,100,0,100,0,1,1,0,0",
		"2,E1,ENEMY,100,0,100,0,1,1,12,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	controller.end_faction_phase()
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)

	# Act
	var log: Array[String] = controller.run_enemy_phase()

	# Assert — 階段推回玩家、回合數推進、旗標已重置
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(controller.round_number()).is_equal(2)
	assert_bool(order.can_move(1)).is_true()
	assert_bool(order.can_attack(1)).is_true()
	assert_array(controller.selectable_units()).is_equal([1])
	assert_bool(log.is_empty()).is_false()


func test_run_enemy_phase_is_noop_outside_enemy_acting() -> void:
	# Arrange — 尚未呼叫 end_faction_phase(),仍在 PLAYER_INPUT
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]

	# Act
	var log: Array[String] = controller.run_enemy_phase()

	# Assert
	assert_array(log).is_empty()
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)


# ---- phi_provider ------------------------------------------------------------

func test_click_tile_attack_uses_phi_provider_when_valid() -> void:
	# Arrange — atk10 def0,provider 恆回傳 7,傷害應為 10-0+7=17
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,E1,ENEMY,500,0,0,0,1,1,1,0",
	]
	var stub: _PhiStub = _PhiStub.new()
	stub.value = 7
	var provider: Callable = Callable(stub, "compute")
	var bundle: Dictionary = _build(roster, [1], [2], provider)
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(1, 0))

	# Assert
	assert_int(result["damage"]).is_equal(17)
	stub.free()


func test_click_tile_attack_missing_phi_provider_defaults_to_zero() -> void:
	# Arrange — 建構子未傳 phi_provider(用預設值),傷害應為 10-0+0=10
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,E1,ENEMY,500,0,0,0,1,1,1,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(1, 0))

	# Assert
	assert_int(result["damage"]).is_equal(10)


func test_click_tile_attack_invalid_phi_provider_defaults_to_zero() -> void:
	# Arrange — provider 綁定的物件在使用前就已經被 free(),is_valid() 應為
	# false,傷害應視同沒有 provider,10-0+0=10,而不是靜默沿用舊值
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,E1,ENEMY,500,0,0,0,1,1,1,0",
	]
	var stub: _PhiStub = _PhiStub.new()
	var provider: Callable = Callable(stub, "compute")
	stub.free()
	assert_bool(provider.is_valid()).is_false()
	var bundle: Dictionary = _build(roster, [1], [2], provider)
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(1, 0))

	# Assert
	assert_int(result["damage"]).is_equal(10)


# ---- construction with an already-resolved state -----------------------------

func test_construction_with_already_resolved_state_finishes_immediately() -> void:
	# Arrange — 先直接操作 BattleState 把玩家單位打死,製造「state 傳進
	# BattleController 建構子時,戰局其實已經結束」的情境;再才建構 controller
	var roster: Array[String] = [
		"1,P1,PLAYER,10,0,0,3,1,1,0,0",
		"2,E1,ENEMY,20,10,0,3,1,1,10,0",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2])
	while state.unit_by_id(1).is_alive():
		state.resolve_attack(2, 1, 0)

	# Act
	var controller: BattleController = BattleController.new(state, order)

	# Assert — 不需要呼叫任何指令方法,建構完成當下 phase() 就已經是 FINISHED。
	# battle_ended 訊號本身不驗證(建構子當下不可能有人已連接上這個訊號),
	# 這裡驗的是「查詢方法回報的狀態正確」,對照 battle_controller.gd 建構子
	# 文件註解裡寫明的那個限制
	assert_int(controller.phase()).is_equal(BattleController.Phase.FINISHED)
	assert_int(controller.outcome()).is_equal(BattleState.Outcome.DEFEAT)


# ---- injected _decide (enemy-turn decision-maker) -----------------------------

func test_run_enemy_phase_default_decide_falls_back_to_greedy_tactical_ai() -> void:
	# Arrange — 不傳 decide(用預設值),敵方 2 與玩家 1 相鄰且在射程內,
	# GreedyTacticalAI 應該主動選擇攻擊而不是站著不動 —— 用實際傷害數字
	# (10-0+0=10)證明真的是 GreedyTacticalAI 在做決策,而不是一個空轉的 stub
	var roster: Array[String] = [
		"1,P1,PLAYER,100,0,0,0,1,1,0,0",
		"2,E1,ENEMY,100,10,0,0,1,1,1,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]
	controller.end_faction_phase()

	# Act
	controller.run_enemy_phase()

	# Assert
	assert_int(state.unit_by_id(1).hp).is_equal(90)
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)


func test_run_enemy_phase_terminates_when_injected_decide_ignores_flags() -> void:
	# Arrange — 對照 BattleLoop 的回歸測試
	# test_battle_aborts_when_decide_ignores_can_move_flag：這裡注入一個
	# 「無視 can_move/can_attack、永遠回傳同一個當下仍合法的動作」的敵對
	# decide,單位 2 在 (0,0)/(1,0) 兩格之間來回,mp=1 兩格互相可達,
	# state.move_unit() 每次都會合法成功,完全不管旗標是否已花掉。
	# 這正是 _process_enemy_unit() 的旗標閘門要擋下的情境——閘門若失效,
	# run_enemy_phase() 就會像修好前的 BattleLoop.run() 一樣真的無限迴圈。
	#
	# decide 本身帶了 _RELENTLESS_DECIDE_CALL_LIMIT 這個自我上限(見該常數
	# 的完整說明)：耍賴滿 50 次之後,第 51 次起改回傳「什麼都不做」,讓
	# 迴圈必然終止。這不是為了讓測試「通過」而妥協——旗標閘門正常運作時,
	# 這個上限永遠碰不到:單位在第 2 次就會因為兩個旗標都已花掉而
	# did_something 為 false、觸發 end_unit_turn(),語意與行為完全不變。
	# 上限只在閘門失效那一分支才有意義:它把「run_enemy_phase() 永遠不
	# 返回」變成「run_enemy_phase() 會返回,但 call_counts 是 51 不是 2」
	# ——讓下面這行 assert 真的執行得到、真的能印出「哪一條斷言、期望值
	# 是什麼、實際值是什麼」,而不是讓整個測試 job 卡死等外部逾時。
	var roster: Array[String] = [
		"1,P1,PLAYER,999,0,999,0,1,1,5,5",
		"2,E1,ENEMY,100,0,100,1,1,1,0,0",
	]
	var call_counts: Dictionary = {}
	var relentless_move: Callable = func(
		decide_state: BattleState, unit_id: int, _can_move: bool, _can_attack: bool
	) -> Dictionary:
		call_counts[unit_id] = call_counts.get(unit_id, 0) + 1
		if call_counts[unit_id] > _RELENTLESS_DECIDE_CALL_LIMIT:
			return {"move_to": null, "attack": -1}
		var current_pos: Vector2i = decide_state.position_of(unit_id)
		var target_pos: Vector2i = (
			Vector2i(1, 0) if current_pos == Vector2i(0, 0) else Vector2i(0, 0)
		)
		return {"move_to": target_pos, "attack": -1}
	var bundle: Dictionary = _build(roster, [1], [2], Callable(), relentless_move)
	var controller: BattleController = bundle["controller"]
	controller.end_faction_phase()

	# Act — 旗標閘門生效的話,無論 decide 怎麼耍賴,run_enemy_phase() 必須
	# 在 call_counts 遠低於自我上限的第 2 次呼叫就正常返回;閘門若失效,
	# 這行仍然會返回(因為自我上限保底),但下面的斷言會清楚失敗
	var log: Array[String] = controller.run_enemy_phase()

	# Assert
	assert_int(call_counts.get(2, 0)).is_equal(2)
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(controller.round_number()).is_equal(2)
	assert_bool(log.is_empty()).is_false()


# ---- signals ------------------------------------------------------------------

func test_select_unit_emits_unit_selected_signal() -> void:
	# Arrange
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = monitor_signals(bundle["controller"])

	# Act
	controller.select_unit(1)

	# Assert
	await assert_signal(controller).is_emitted("unit_selected", 1)


func test_attack_that_ends_battle_emits_battle_ended_and_finishes_phase() -> void:
	# Arrange — 單位 2 是敵方唯一單位,一擊必死即觸發 VICTORY
	var roster: Array[String] = [
		"1,P1,PLAYER,20,999,0,0,1,1,0,0",
		"2,E1,ENEMY,1,0,0,0,1,1,1,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = monitor_signals(bundle["controller"])
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(1, 0))

	# Assert
	assert_that(result["action"]).is_equal(&"attacked")
	assert_int(controller.phase()).is_equal(BattleController.Phase.FINISHED)
	assert_int(controller.outcome()).is_equal(BattleState.Outcome.VICTORY)
	await assert_signal(controller).is_emitted("battle_ended", BattleState.Outcome.VICTORY)
