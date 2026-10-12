# story-005-threat-targets-semantic-clarification.md:
# BattleController.threat_range_for() / BattleController.threat_range_all()
# （src/gameplay/battle/battle_controller.gd）的單元測試。
#
# 背景（查證結論，另見該 story 檔 Implementation Notes 節的完整版本）：既有
# threat_targets()/_threat_targets_for() 的「起點集合 = 現在位置 + 移動延伸」結構
# 本身已符合 GDD 公式四 threat_range(e) 的定義，但有兩個真正的缺口：
#   (1) 範圍缺口 —— 被 TurnOrder.can_attack() 內的 _is_actionable() 同陣營/回合
#       閘門鎖死，玩家回合查任何敵方單位一律拿到空陣列，而那正是威脅範圍疊加圖
#       需要畫的時機（UX 規格 U-T15）。
#   (2) 視線軸缺口 —— is_attack_reachable() 會檢查視線（CombatRules.is_attack_legal
#       經由 board.blocks_sight），但 GDD 公式四明文排除視線檢查（「寧可高估、
#       絕不低估」）。
# 兩個缺口都不透過修改既有 _threat_targets_for()/threat_targets() 解決（兩者原文
# 零修改，既有測試全部維持原樣）——本 story 新增兩個不經過上述閘門、改用
# CombatRules.is_in_range()（純曼哈頓距離、無視線檢查）的查詢：
# threat_range_for()（單一單位）與 threat_range_all()（多敵聯集 + 逐敵拆分，
# TR-tactical-036 + AC-22(b)）。
#
# 手法沿用既有先例 attack_los_blocked_query_test.gd / unit_action_state_test.gd：
# 自建最小名冊、視需要疊加最小地形字串，不建立任何 Node —— 全鏈路（TurnOrder/
# BattleState/Board/Unit/CombatRules）都是 RefCounted 或 static，不會留下孤兒節點。
extends GdUnitTestSuite


# ---- fixtures --------------------------------------------------------------

func _build(
	roster_lines: Array[String],
	player_ids: Array[int],
	enemy_ids: Array[int],
	terrain: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var state: BattleState = BattleState.create(terrain, "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new(player_ids, enemy_ids)
	var controller: BattleController = BattleController.new(state, order)
	return {"state": state, "order": order, "controller": controller}


# =============================================================================
# 1. 單一單位的威脅範圍（AC-21 向量 1：曼哈頓環）
# =============================================================================

func test_threat_range_for_single_unit_returns_manhattan_ring_from_static_origin() -> void:
	# Arrange — 敵方單位 2 站 (0,0)，mp=0（無法移動，reachable_set(e)={(0,0)}），
	# 射程 [2,4]。棋盤為 13(寬) x 6(高)（Board.BOARD_WIDTH/BOARD_HEIGHT）。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,10,5",
		"2,E1,ENEMY,20,10,0,0,2,4,0,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]

	# Act
	var result: Array[Vector2i] = controller.threat_range_for(2)

	# Assert — 獨立量尺：窮舉整張棋盤，凡曼哈頓距離 (0,0) 落在 [2,4] 者都該在
	# 輸出中，其餘都不該在。不重用受測函式的任何一行邏輯，只用純算術。
	for y: int in range(Board.BOARD_HEIGHT):
		for x: int in range(Board.BOARD_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var dist: int = absi(cell.x) + absi(cell.y)
			var should_be_in_range: bool = dist >= 2 and dist <= 4
			if should_be_in_range:
				assert_array(result).contains([cell])
			else:
				assert_array(result).not_contains([cell])


# =============================================================================
# 2. 視線刻意不檢查（AC-21 向量 2，公式四明文排除視線檢查）
# =============================================================================

func test_threat_range_for_ignores_line_of_sight_per_formula_four() -> void:
	# Arrange — 場景取自既有 attack_los_blocked_query_test.gd 測試 1 的同一佈局：
	# 倒木在 (2,0) 擋視線，敵方單位 2 站 (0,0)、射程 [1,4]，目標格 (4,0) 距離 4、
	# 直線穿過 (2,0) → 視線被擋。那支既有測試證明 attack_targets()/
	# is_attack_reachable() 會把 (4,0) 排除；本測試證明 threat_range_for() 相反地
	# 一定要保留它。
	var terrain: PackedStringArray = PackedStringArray(["..#.........."])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,10,5",
		"2,E1,ENEMY,20,10,0,0,1,4,0,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2], terrain)
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]

	# Sanity — 先確認 (4,0) 真的是被既有、已獨立驗證過的判定式認定為視線遮蔽，
	# 否則本測試驗不到它聲稱要驗的東西。
	assert_bool(state.is_attack_reachable(2, Vector2i(0, 0), Vector2i(4, 0))).is_false()

	# Act
	var result: Array[Vector2i] = controller.threat_range_for(2)

	# Assert
	assert_array(result).contains([Vector2i(4, 0)])


# =============================================================================
# 3. 核心缺口修復：敵方單位在玩家回合也能查到威脅範圍（UX 規格 U-T15）
# =============================================================================

func test_threat_range_for_works_for_enemy_unit_during_player_input_phase() -> void:
	# Arrange — 控制器一建立就是 PLAYER_INPUT（BattleController 類別文件註解：
	# 「There is no "no phase" — a fresh controller always starts in
	# PLAYER_INPUT」）。敵方單位 2 不可能被 select_unit() 選取（陣營檢查會拒絕），
	# 證明舊路徑（threat_targets() 依賴 _selected_unit_id）結構上碰不到它。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,10,5",
		"2,E1,ENEMY,20,10,0,0,1,2,0,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]

	# Sanity
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_bool(controller.select_unit(2)).is_false()

	# Act
	var result: Array[Vector2i] = controller.threat_range_for(2)

	# Assert — 非空:新查詢不受「必須是目前選取、當前陣營、尚可攻擊的單位」這道
	# 閘門限制。
	assert_bool(result.is_empty()).is_false()


func test_threat_range_for_empty_for_nonexistent_unit_id() -> void:
	# Arrange — 不存在的 id 必須回傳空陣列，不得觸發例外（防禦性保護，對應
	# threat_range_for() 文件註解「Returns an empty array if unit_id does not
	# exist or is dead」）。
	var roster: Array[String] = ["1,P1,PLAYER,20,10,0,0,1,1,10,5"]
	var bundle: Dictionary = _build(roster, [1], [])
	var controller: BattleController = bundle["controller"]

	# Act / Assert
	assert_array(controller.threat_range_for(999)).is_empty()


# =============================================================================
# 4. 既有 threat_targets()（選取單位語意)完全未受影響 —— 回歸保護
# =============================================================================

func test_existing_threat_targets_selected_unit_behavior_unchanged() -> void:
	# Arrange — 沿用既有 battle_controller_threat_test.gd 風格的最小場景：單位 1
	# 選取後，既有 threat_targets() 的回傳集合必須與新 threat_range_for(1) 在
	# 「不含視線遮蔽格」這件事上不同（因為兩者刻意是不同語意），但在無遮蔽場景下
	# （本測試不放地形)結果應當一致 —— 證明本 story 沒有改動 _threat_targets_for()
	# 的既有程式碼一個字元。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,2,4,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,10,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var old_result: Array[Vector2i] = controller.threat_targets().cells
	var new_result: Array[Vector2i] = controller.threat_range_for(1)

	# Assert — 全開闊地（無視線遮蔽）下兩者應描述同一個集合。
	assert_int(old_result.size()).is_equal(new_result.size())
	for cell: Vector2i in old_result:
		assert_array(new_result).contains([cell])


# =============================================================================
# 5. 多敵扁平聯集與逐敵拆分同時回傳（TR-tactical-036）
# =============================================================================

func test_threat_range_all_returns_union_and_per_unit_breakdown_in_one_call() -> void:
	# Arrange — 3 名存活敵方單位（故事 QA 測試規格原文：「E 含 3 名存活敵方單位」）。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,10,5",
		"2,E1,ENEMY,20,10,0,0,1,1,0,0",
		"3,E2,ENEMY,20,10,0,0,1,1,5,5",
		"4,E3,ENEMY,20,10,0,0,1,1,12,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2, 3, 4])
	var controller: BattleController = bundle["controller"]

	# Act — 單一次呼叫。
	var combined: Dictionary = controller.threat_range_all([2, 3, 4])

	# Assert — 兩個切面都在同一次呼叫的回傳值裡，且各自非空（確認真的測到東西）。
	assert_bool(combined.has("union")).is_true()
	assert_bool(combined.has("per_unit")).is_true()
	var union_cells: Array[Vector2i] = combined["union"]
	var per_unit: Dictionary = combined["per_unit"]
	assert_bool(union_cells.is_empty()).is_false()
	assert_int(per_unit.size()).is_equal(3)
	for id: int in [2, 3, 4]:
		assert_bool(per_unit.has(id)).is_true()
		var cells: Array[Vector2i] = per_unit[id]
		assert_bool(cells.is_empty()).is_false()


# =============================================================================
# 6. 多敵共用同一份快照的原子性可觀測後果（AC-22(b)）
# =============================================================================

func test_threat_range_all_union_equals_dedup_of_per_unit_cells() -> void:
	# Arrange — AC-22(b) 的可觀測後果:扁平聯集在數學上必須恰好等於「逐敵拆分各自
	# 集合的聯集」，不能是兩段獨立計算、各自對到不同時刻盤面而產生落差的結果。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,10,5",
		"2,E1,ENEMY,20,10,0,0,1,1,0,0",
		"3,E2,ENEMY,20,10,0,0,1,1,5,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2, 3])
	var controller: BattleController = bundle["controller"]

	# Act
	var combined: Dictionary = controller.threat_range_all([2, 3])
	var union_cells: Array[Vector2i] = combined["union"]
	var per_unit: Dictionary = combined["per_unit"]

	# Assert — 從逐敵拆分重建聯集（去重），須與回傳的聯集完全相同（忽略排序）。
	var rebuilt: Dictionary = {}
	for id: int in per_unit:
		var cells: Array[Vector2i] = per_unit[id]
		for cell: Vector2i in cells:
			rebuilt[cell] = true
	assert_int(union_cells.size()).is_equal(rebuilt.size())
	for cell: Vector2i in union_cells:
		assert_bool(rebuilt.has(cell)).is_true()


# =============================================================================
# 敏感度證明
# =============================================================================

# 間諜子類別 1 —— 刻意把 threat_range_for() 改回呼叫
# BattleState.is_attack_reachable()（會檢查視線），重現本 story AC-21「視線刻意
# 不檢查」這條規則最可能被意外踩回去的寫法——例如日後有人「順手重用既有邏輯」
# 卻忘記公式四刻意不查視線。藉此證明上面
# test_threat_range_for_ignores_line_of_sight_per_formula_four() 真的會對這種
# 植入缺陷敏感，而不是兩者剛好同值。
class _MutantThreatRangeChecksSight extends BattleController:
	func threat_range_for(unit_id: int) -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		var unit: Unit = _state.unit_by_id(unit_id)
		if unit == null or not unit.is_alive():
			return result
		var current_pos: Vector2i = _state.position_of(unit_id)
		var origins: Array[Vector2i] = _move_reach_for(unit_id)
		origins.append(current_pos)
		var threatened: Dictionary = {}
		for origin: Vector2i in origins:
			for y: int in range(Board.BOARD_HEIGHT):
				for x: int in range(Board.BOARD_WIDTH):
					var cell: Vector2i = Vector2i(x, y)
					if cell == current_pos:
						continue
					# 錯誤實作：沿用 is_attack_reachable()（含視線檢查），而非
					# CombatRules.is_in_range()（公式四要求的純幾何，無視線）。
					if _state.is_attack_reachable(unit_id, origin, cell):
						threatened[cell] = true
		for cell: Vector2i in threatened:
			result.append(cell)
		result.sort_custom(_tile_less)
		return result


func test_sensitivity_proof_sight_check_mutant_breaks_los_ignored_assertion() -> void:
	# Arrange — 與 test_threat_range_for_ignores_line_of_sight_per_formula_four()
	# 完全相同的場景，只是改用會重現錯誤實作形狀的間諜子類別。
	var terrain: PackedStringArray = PackedStringArray(["..#.........."])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,10,5",
		"2,E1,ENEMY,20,10,0,0,1,4,0,0",
	]
	var state: BattleState = BattleState.create(terrain, "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var mutant: _MutantThreatRangeChecksSight = _MutantThreatRangeChecksSight.new(state, order)

	# Act
	var result: Array[Vector2i] = mutant.threat_range_for(2)

	# Assert — 視線被擋的 (4,0) 必須「不在」錯誤實作的輸出裡，證明正式測試斷言
	# 「(4,0) 必須在輸出裡」真的會抓到這個植入缺陷，不是巧合同值。
	assert_array(result).not_contains([Vector2i(4, 0)])


# 間諜子類別 2 —— 刻意讓 threat_range_all() 的「聯集」只取第一個單位的結果，
# 而非真正對全部輸入單位取聯集，重現 TR-tactical-036 / AC-22(b) 要防的「兩個
# 切面各自獨立計算、彼此可能不一致」這個錯誤形狀。
class _MutantThreatRangeAllInconsistentUnion extends BattleController:
	func threat_range_all(unit_ids: Array[int]) -> Dictionary:
		var per_unit: Dictionary = {}
		for id: int in unit_ids:
			per_unit[id] = threat_range_for(id)
		var union_result: Array[Vector2i] = []
		if unit_ids.size() > 0:
			# 錯誤實作：只取第一個單位的集合當作聯集，忽略其餘單位。
			var first_cells: Array[Vector2i] = per_unit[unit_ids[0]]
			union_result = first_cells.duplicate()
		return {"union": union_result, "per_unit": per_unit}


func test_sensitivity_proof_inconsistent_union_mutant_breaks_union_consistency_assertion() -> void:
	# Arrange — 兩名敵方單位站在不重疊的威脅範圍位置，確保聯集理應包含兩者各自
	# 專屬的格子。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,10,5",
		"2,E1,ENEMY,20,10,0,0,1,1,0,0",
		"3,E2,ENEMY,20,10,0,0,1,1,12,5",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2, 3])
	var mutant: _MutantThreatRangeAllInconsistentUnion = (
		_MutantThreatRangeAllInconsistentUnion.new(state, order)
	)

	# Act
	var combined: Dictionary = mutant.threat_range_all([2, 3])
	var union_cells: Array[Vector2i] = combined["union"]
	var per_unit: Dictionary = combined["per_unit"]

	# Assert — 重建「正確」聯集（逐敵拆分去重），證明錯誤實作回傳的聯集比正確
	# 聯集少（遺漏了單位 3 專屬的格子），即
	# test_threat_range_all_union_equals_dedup_of_per_unit_cells() 的一致性斷言
	# 真的會抓到這個植入缺陷。
	var rebuilt: Dictionary = {}
	for id: int in per_unit:
		var cells: Array[Vector2i] = per_unit[id]
		for cell: Vector2i in cells:
			rebuilt[cell] = true
	assert_int(union_cells.size()).is_less(rebuilt.size())
