# BattleController.threat_targets()（src/gameplay/battle/battle_controller.gd）的
# 單元測試。
#
# 背景：玩家反映「沒有顯示角色的攻擊範圍，這樣我無法得知角色該如何移動才能攻擊」
# ——attack_targets() 只回報「站在原地能打到誰」，threat_targets() 補上「原地
# 加上每個移動候選格，合計能打到哪些格子」這個更大的集合。threat_targets() 內部
# 完全委派給 BattleState.is_attack_reachable()（純幾何/視線查詢，不看陣營、
# 存活、佔位），因此本檔的測試重點不是重新驗證射程/視線數學本身（那些已經在
# battle_state_test.gd 驗過），而是驗證 threat_targets() 這一層「收集哪些起點、
# 排除哪些格子、怎麼排序」的組裝邏輯有沒有做對。
#
# 大多數測試沿用 battle_controller_test.gd 的手法：自建最小名冊、空地形
# PackedStringArray()（Board.from_ascii 對缺列預設回開闊地，13x6 邊界不受影響）。
# 只有「反說謊」測試（見下方最後一支）改用真實 vs01 資料，因為規格書明確指出
# 這支測試的前提已經用真實關卡資料做過探針驗證（365 組 origin-敵人配對，
# 假設值 vs 實際走過去，0 處不符）。
#
# 命名慣例沿用既有先例（test_[scenario]_[expected]）。不建立任何 Node ——
# 全鏈路（TurnOrder/BattleState/Board/Unit/CombatRules）都是 RefCounted 或
# static，不會留下孤兒節點。
extends GdUnitTestSuite


# ---- fixtures --------------------------------------------------------------

# 建一份最小 BattleState/TurnOrder/BattleController 三件套，地形一律空白
# （全開闊地），沿用 battle_controller_test.gd 的 _build() 手法。
func _build(
	roster_lines: Array[String], player_ids: Array[int], enemy_ids: Array[int]
) -> Dictionary:
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new(player_ids, enemy_ids)
	var controller: BattleController = BattleController.new(state, order)
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


# Ascending (y, x) comparator matching BattleController._tile_less — kept as
# a local copy rather than calling the private static, since tests should not
# reach into another class's private implementation details.
static func _tile_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


# ---- (1) 原地就在射程內，不需要移動 --------------------------------------------

func test_threat_targets_current_tile_already_in_range_without_moving() -> void:
	# Arrange — 單位 1 mp=0（無法移動）、射程 1，起點 (0,0)；敵方站在 (1,0)，
	# 距離 1，原地就打得到
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,1,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var threats: Array[Vector2i] = controller.threat_targets()

	# Assert — 唯一起點是原地 (0,0)，射程 1 只碰得到四個正交鄰格，
	# 敵方所在的 (1,0) 必須在裡面
	assert_array(threats).contains([Vector2i(1, 0)])
	assert_array(controller.move_targets()).is_empty()  # mp=0，佐證這是「原地」而非「移動後」


# ---- (2) 只有移動後才打得到 —— 本檔最重要的一支測試 ----------------------------

func test_threat_targets_includes_cell_only_reachable_after_moving_and_absent_from_attack_targets() -> void:
	# Arrange — 單位 1 mp=3、射程 1，起點 (0,0)；敵方在 (4,0)，距離 4，原地
	# 打不到（attack_targets() 應為空），但單位 1 沿開闊地走到 (3,0)（成本 3，
	# 剛好用完 mp）之後，距離敵方只剩 1，打得到。這正是這個功能要補的落差：
	# UI 過去只看得到 attack_targets()，玩家完全不知道「往哪走就打得到」。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,3,1,1,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,4,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()
	assert_array(controller.move_targets()).contains([Vector2i(3, 0)])

	# Act
	var threats: Array[Vector2i] = controller.threat_targets()
	var attacks: Array[Vector2i] = controller.attack_targets()

	# Assert — 原地打不到（attack_targets 不含敵方格），但 threat_targets 含
	assert_array(attacks).not_contains([Vector2i(4, 0)])
	assert_array(threats).contains([Vector2i(4, 0)])


# ---- (3) 三種「空集合」情境 ----------------------------------------------------

func test_threat_targets_empty_when_nothing_selected() -> void:
	# Arrange — 沒有呼叫 select_unit()
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,3,1,1,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,4,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]

	# Act / Assert
	assert_array(controller.threat_targets()).is_empty()


func test_threat_targets_empty_when_attack_flag_already_consumed() -> void:
	# Arrange — 白箱佈置：直接操作 TurnOrder 花掉單位 1 的攻擊旗標，模擬
	# 「這個單位這回合已經攻擊過」的情境（沿用 battle_controller_test.gd
	# 「order.end_unit_turn(1)」式的白箱手法）。單位仍有 mp 可以移動，
	# 但攻擊旗標已經花掉的單位這回合不再威脅任何格子。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,3,1,1,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,4,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()
	assert_bool(order.use_attack(1)).is_true()

	# Act / Assert
	assert_array(controller.threat_targets()).is_empty()


func test_threat_targets_empty_when_no_cell_on_board_falls_within_range_of_any_origin() -> void:
	# Arrange — 單位 1 mp=0、射程 18-20；棋盤是 13x6，任兩格間的最大曼哈頓
	# 距離是 (13-1)+(6-1)=17，永遠碰不到 18，因此無論從哪個起點都打不到
	# 棋盤上的任何一格
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,18,20,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,12,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act / Assert
	assert_array(controller.threat_targets()).is_empty()


# ---- (4) 中央倒木堆擋住視線（距離 ≥2 的假設查詢）--------------------------------

func test_threat_targets_excludes_cell_blocked_by_terrain_but_includes_unblocked_cell_at_same_distance() -> void:
	# Arrange — 自建一塊只在 row0 的 x=2 放倒木的地形，其餘格子一律開闊地
	# （Board.from_ascii 對缺列/缺字元一律預設 TERRAIN_OPEN）。單位 1 mp=0、
	# 射程 1-4，起點 (0,0)：
	# - 打 (4,0)：距離 4，直線穿過 (1,0)/(2,0)/(3,0)，(2,0) 是倒木 → 應被擋
	# - 打 (0,4)：距離同樣是 4，沿 y 軸走、全程開闊地 → 應合法
	# 用同距離的一擋一不擋，證明真的是視線邏輯在運作，不是單純射程判斷。
	var terrain: PackedStringArray = PackedStringArray(["..#.........."])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,4,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,12,5",
	]
	var state: BattleState = BattleState.create(terrain, "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var controller: BattleController = BattleController.new(state, order)
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var threats: Array[Vector2i] = controller.threat_targets()

	# Assert
	assert_array(threats).not_contains([Vector2i(4, 0)])
	assert_array(threats).contains([Vector2i(0, 4)])


# ---- (5) 排序：升冪 (y, x) --------------------------------------------------

func test_threat_targets_sorted_ascending_by_y_then_x() -> void:
	# Arrange — 單位 1 mp=0、射程 1，起點 (5,3)（全開闊地，空地形），唯一
	# 起點就是原地，能碰到的四個正交鄰格答案已知，可以直接驗證完整排序
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,5,3",
		"2,E1,ENEMY,20,10,0,0,1,1,12,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var threats: Array[Vector2i] = controller.threat_targets()

	# Assert — 升冪 (y, x)：先比 y 再比 x
	assert_array(threats).is_equal(
		[Vector2i(5, 2), Vector2i(4, 3), Vector2i(6, 3), Vector2i(5, 4)]
	)


# ---- (6) 排除單位自己目前站的那一格 --------------------------------------------

func test_threat_targets_excludes_selected_units_own_current_tile_even_from_a_move_origin() -> void:
	# Arrange — 單位 1 mp=2、射程 1，起點 (0,0)；移動候選格包含 (1,0)（成本
	# 1）。從假設起點 (1,0) 回頭看，距離原地 (0,0) 恰好是 1，落在射程內——
	# 如果沒有明確排除「目前站的那一格」，(0,0) 就會被誤判成「可攻擊」，
	# 畫面上等於在說「你可以攻擊自己」。用 (2,0)（同樣從起點 (1,0) 量測，
	# 距離 1）當正面對照，證明起點 (1,0) 真的有被納入計算，這不是靠射程
	# 或視線本身就會排除的巧合，而是 threat_targets() 明確的排除邏輯生效。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,2,1,1,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,12,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()
	assert_array(controller.move_targets()).contains([Vector2i(1, 0)])

	# Act
	var threats: Array[Vector2i] = controller.threat_targets()

	# Assert
	assert_array(threats).not_contains([Vector2i(0, 0)])
	assert_array(threats).contains([Vector2i(2, 0)])  # 佐證起點 (1,0) 確實被納入計算


# ---- (7) 反說謊測試：對每個移動候選格，跟「真的走過去」的結果做比對 -----------------

func test_threat_targets_per_move_target_matches_ground_truth_of_actually_moving_there() -> void:
	# Arrange — 用真實 vs01 地形 + 名冊。對單位 1（甲）的每一個 move_targets()
	# 候選格 t，先用 BattleState.is_attack_reachable() 算出「假設站在 t，
	# 打得到哪些敵方格」，再重新建一整套全新的 BattleState/TurnOrder/
	# BattleController（不共用可變狀態），把單位 1 實際 move_unit() 走到 t，
	# 選取後呼叫 attack_targets()（會經過完整的 can_attack()：存活/陣營/
	# is_attack_reachable() 三關）驗證同一組敵方格真的打得到。
	#
	# 這是防止畫面說謊的測試：如果這裡兜不起來，代表 UI 會畫出「站這裡可以
	# 打到這裡」的高亮，但玩家實際走過去按下攻擊卻被拒絕。規格書作者已經
	# 用同一份 vs01 資料對全部 5 個玩家單位做過標頭式探針，365 組
	# (起點, 敵人) 配對、0 處不符；這支測試把同樣的斷言收斂成一支可重複
	# 執行、可進 CI 的自動化測試。
	var terrain: PackedStringArray = _load_terrain_rows()
	var roster_text: String = _load_roster_text()
	var player_ids: Array[int] = [1, 2, 3, 4, 5]
	var enemy_ids: Array[int] = [6, 7, 8, 9, 10]

	var state: BattleState = BattleState.create(terrain, roster_text)
	var order: TurnOrder = TurnOrder.new(player_ids, enemy_ids)
	var controller: BattleController = BattleController.new(state, order)
	assert_bool(controller.select_unit(1)).is_true()

	var move_target_list: Array[Vector2i] = controller.move_targets()
	assert_bool(move_target_list.is_empty()).is_false()

	for t: Vector2i in move_target_list:
		# 假設值：從 t 出發，用純幾何/視線查詢算出打得到的敵方格
		var hypothetical_hits: Array[Vector2i] = []
		for enemy_id: int in enemy_ids:
			var enemy_pos: Vector2i = state.position_of(enemy_id)
			if state.is_attack_reachable(1, t, enemy_pos):
				hypothetical_hits.append(enemy_pos)
		hypothetical_hits.sort_custom(_tile_less)

		# Act — 全新一套狀態，真的把單位 1 走到 t
		var fresh_state: BattleState = BattleState.create(terrain, roster_text)
		var fresh_order: TurnOrder = TurnOrder.new(player_ids, enemy_ids)
		var fresh_controller: BattleController = BattleController.new(fresh_state, fresh_order)
		assert_bool(fresh_state.move_unit(1, t)).is_true()
		assert_bool(fresh_controller.select_unit(1)).is_true()
		var actual_hits: Array[Vector2i] = fresh_controller.attack_targets()

		# Assert — 假設值與「真的站上去」的結果必須完全一致
		assert_array(actual_hits).is_equal(hypothetical_hits)
