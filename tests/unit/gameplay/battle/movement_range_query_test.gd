# story-007-movement-range-four-state-query.md:
# BattleController.move_targets_breakdown() / BattleController._classify_move_targets()
# (src/gameplay/battle/battle_controller.gd) 的單元測試。
#
# 手法沿用既有先例 threat_range_query_test.gd:自建最小名冊,視需要疊加最小地形
# 字串,不建立任何 Node —— 全鏈路（TurnOrder/BattleState/Board/Unit）都是
# RefCounted 或 static，不會留下孤兒節點。
#
# 🔴 查證結論（直接影響下面測試的設計，寫在這裡避免下一個人重查一次）：
# src/gameplay/board/board.gd 的 TERRAIN_TABLE 目前只有 3 種地形字元
# （TERRAIN_OPEN/TERRAIN_BRUSH/TERRAIN_FALLEN_LOG），三者的 "passable" 欄位皆為
# true —— 本專案目前沒有任何一種已註冊地形是不可通行的。這代表任何用
# Board.from_ascii() 建出的真實棋盤，set_b（只忽略佔位）與 set_c（佔位+可通行性
# 皆忽略）永遠相同，C\B（blocked_by_terrain）在真實棋盤上結構性地恆為空。
# 下面對「四態分類」與其敏感度證明兩條測試因此直接呼叫純分類函式
# _classify_move_targets()，餵合成的 A/B/C 三個集合，不依賴真實地形資料 —— 其餘
# 測試（A⊆B⊆C、origin 必屬於 A、AC-14 守門、combat_state_version）則呼叫真實
# BattleState/BattleController，因為它們驗的是「本 story 有沒有正確接上
# story-002 的既有保證」，而不是分類邏輯本身。
#
# 敏感度證明涵蓋範圍（其餘測試是「呼叫真實類別、斷言真實行為」，沒有另外重新
# 實作任何規則可供植入缺陷，故未個別做突變證明 —— 與 threat_range_query_test.gd
# 的既有比例一致：6 條主測試只配 2 條敏感度證明）：
#   - test_four_states_partition... -> test_sensitivity_proof_partition_detects_missing_terrain_category
#   - test_move_confirmation_rejects... -> test_sensitivity_proof_legality_gate_detects_bypass_of_authoritative_recheck
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
# 1. 四態分類正確、互斥且窮盡（AC-13 對照）
# =============================================================================

func test_four_states_partition_grid_with_no_fifth_category_and_mutual_exclusion() -> void:
	# Arrange — 直接對純分類邏輯餵入合成的 A/B/C 三個集合（見檔頭查證結論：真實
	# 棋盤無法產生非空的 C\B，故本測試繞過 Board/BattleState）。
	var bundle: Dictionary = _build(
		["1,P1,PLAYER,20,10,0,3,1,1,0,0", "2,E1,ENEMY,20,10,0,0,1,1,12,5"], [1], [2]
	)
	var controller: BattleController = bundle["controller"]

	var origin: Vector2i = Vector2i(0, 0)
	var legal_cell: Vector2i = Vector2i(1, 0)
	var occupancy_cell: Vector2i = Vector2i(2, 0)
	var terrain_cell: Vector2i = Vector2i(3, 0)
	var out_of_range_cell: Vector2i = Vector2i(4, 0)

	var set_a: Dictionary = {legal_cell: true}
	var set_b: Dictionary = {legal_cell: true, occupancy_cell: true}
	var set_c: Dictionary = {legal_cell: true, occupancy_cell: true, terrain_cell: true}

	# Act
	var breakdown: Dictionary = controller._classify_move_targets(origin, set_a, set_b, set_c)

	# Assert — 四態分類正確
	assert_array(breakdown["legal"]).contains([origin, legal_cell])
	assert_array(breakdown["blocked_by_occupancy"]).contains([occupancy_cell])
	assert_array(breakdown["blocked_by_terrain"]).contains([terrain_cell])
	assert_array(breakdown["out_of_range"]).contains([out_of_range_cell])

	# Assert — 互斥：每格只出現在一個陣列
	assert_array(breakdown["legal"]).not_contains([occupancy_cell])
	assert_array(breakdown["legal"]).not_contains([terrain_cell])
	assert_array(breakdown["legal"]).not_contains([out_of_range_cell])
	assert_array(breakdown["blocked_by_occupancy"]).not_contains([terrain_cell])
	assert_array(breakdown["blocked_by_occupancy"]).not_contains([out_of_range_cell])
	assert_array(breakdown["blocked_by_terrain"]).not_contains([out_of_range_cell])

	# Assert — 窮盡：四者聯集 == 整個棋盤（13*6=78 格），無第五類殘留
	var total: int = (
		breakdown["legal"].size()
		+ breakdown["blocked_by_occupancy"].size()
		+ breakdown["blocked_by_terrain"].size()
		+ breakdown["out_of_range"].size()
	)
	assert_int(total).is_equal(Board.BOARD_WIDTH * Board.BOARD_HEIGHT)


# =============================================================================
# 2. A ⊆ B ⊆ C 恆成立（公式三既有保證，驗本 story 有沒有正確接上 story-002）
# =============================================================================

func test_a_subset_b_subset_c_on_real_board() -> void:
	# Arrange — 單位 1 於 (6,3)，mp=3；單位 2（敵方）站在 (8,3)，距離 2，開闊地
	# 全通行，使 B 嚴格大於 A（佔位格只在 B 以上出現）。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,3,1,1,6,3",
		"2,E1,ENEMY,20,10,0,0,1,1,8,3",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]

	# Act
	var set_a: Array[Vector2i] = state.legal_moves(1)
	var set_b: Array[Vector2i] = state.legal_moves_relaxed(1, true, false)
	var set_c: Array[Vector2i] = state.legal_moves_relaxed(1, true, true)

	# Assert — 包含關係
	for cell: Vector2i in set_a:
		assert_array(set_b).contains([cell])
	for cell: Vector2i in set_b:
		assert_array(set_c).contains([cell])

	# Sanity — 確認這個場景真的讓 B 嚴格大於 A，不是三者剛好相等的退化情況，
	# 否則上面的包含關係斷言驗不到它聲稱要驗的東西。
	assert_array(set_b).contains([Vector2i(8, 3)])
	assert_array(set_a).not_contains([Vector2i(8, 3)])


# =============================================================================
# 3. origin 恆屬於 A，不落入任何不可達分類
# =============================================================================

func test_origin_always_classified_as_legal() -> void:
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,3,1,1,6,3",
		"2,E1,ENEMY,20,10,0,0,1,1,8,3",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()
	var origin: Vector2i = Vector2i(6, 3)

	# Act
	var breakdown: Dictionary = controller.move_targets_breakdown()

	# Assert
	assert_array(breakdown["legal"]).contains([origin])
	assert_array(breakdown["blocked_by_occupancy"]).not_contains([origin])
	assert_array(breakdown["blocked_by_terrain"]).not_contains([origin])
	assert_array(breakdown["out_of_range"]).not_contains([origin])


# =============================================================================
# 4. 合法性守門（AC-14 禁止型，回歸測試）
# =============================================================================

func test_move_confirmation_rejects_tile_flagged_blocked_by_occupancy() -> void:
	# Arrange — (8,3) 被敵方佔據，距離 2（在 mp=3 內），攻擊射程 [1,1] 打不到
	# （距離 2），所以 click_tile() 既不會解成攻擊，也不該解成移動。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,3,1,1,6,3",
		"2,E1,ENEMY,20,10,0,0,1,1,8,3",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	var blocked_tile: Vector2i = Vector2i(8, 3)
	var breakdown: Dictionary = controller.move_targets_breakdown()
	# Sanity — 先確認這格真的被新查詢標示為「僅佔位擋死」，否則本測試驗不到它
	# 聲稱要驗的東西。
	assert_array(breakdown["blocked_by_occupancy"]).contains([blocked_tile])

	# Act
	var click_result: Dictionary = controller.click_tile(blocked_tile)

	# Assert — AC-14 禁止型：即使該格被新查詢標示了不可達成因，移動確認仍必須拒絕。
	assert_bool(click_result["action"] == &"moved").is_false()
	assert_bool(click_result["action"] == &"deselected").is_true()
	assert_bool(state.position_of(1) == Vector2i(6, 3)).is_true()


# =============================================================================
# 5. ADR-0001 即時性義務（AC-20）：輸出攜帶當下的 combat_state_version
# =============================================================================

func test_query_output_carries_current_combat_state_version() -> void:
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,3,1,1,6,3",
		"2,E1,ENEMY,20,10,0,0,1,1,8,3",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act / Assert — 尚未有任何已提交的變化：版本號為 0。
	var breakdown_before: Dictionary = controller.move_targets_breakdown()
	assert_int(breakdown_before["combat_state_version"]).is_equal(state.combat_state_version)
	assert_int(breakdown_before["combat_state_version"]).is_equal(0)

	# Act — 觸發一次已提交的變化（移動到合法格，bump 版本號）。單位移動後
	# TurnOrder 會標記其已用完本回合的移動，move_targets_breakdown() 因此落入
	# 「無選取可用內容」的早退路徑 —— 這正是本測試要驗的：即使是這個早退路徑，
	# 回傳的 combat_state_version 仍必須是最新值，不得沿用呼叫當下之前的舊值
	# （AC-22(a)：至少須標記為過期）。
	var legal_tile: Vector2i = Vector2i(6, 1)
	assert_array(breakdown_before["legal"]).contains([legal_tile])
	controller.click_tile(legal_tile)

	# Assert
	var breakdown_after: Dictionary = controller.move_targets_breakdown()
	assert_int(breakdown_after["combat_state_version"]).is_equal(state.combat_state_version)
	assert_int(breakdown_after["combat_state_version"]).is_greater(
		int(breakdown_before["combat_state_version"])
	)


# =============================================================================
# 敏感度證明
# =============================================================================

# 間諜子類別 1 —— 重現 Implementation Notes #2 明文禁止的「效能捷徑」：放棄 C\B
# 的成因區分，直接併入 out_of_range，而非正確地檢查 set_c。
class _MutantCollapsesTerrainIntoOutOfRange extends BattleController:
	func _classify_move_targets(
		origin: Vector2i, set_a: Dictionary, set_b: Dictionary, set_c: Dictionary
	) -> Dictionary:
		var legal: Array[Vector2i] = []
		var blocked_by_occupancy: Array[Vector2i] = []
		var out_of_range: Array[Vector2i] = []
		for y: int in range(Board.BOARD_HEIGHT):
			for x: int in range(Board.BOARD_WIDTH):
				var cell: Vector2i = Vector2i(x, y)
				if cell == origin or set_a.has(cell):
					legal.append(cell)
				elif set_b.has(cell):
					blocked_by_occupancy.append(cell)
				else:
					# 錯誤實作：從未檢查 set_c，C\B 的格子全部落入這裡。
					out_of_range.append(cell)
		legal.sort_custom(_tile_less)
		blocked_by_occupancy.sort_custom(_tile_less)
		out_of_range.sort_custom(_tile_less)
		return {
			"legal": legal,
			"blocked_by_occupancy": blocked_by_occupancy,
			"blocked_by_terrain": [] as Array[Vector2i],
			"out_of_range": out_of_range,
		}


func test_sensitivity_proof_partition_detects_missing_terrain_category() -> void:
	# Arrange — 與正式分類測試相同手法的合成集合，只是換成會重現「放棄 C\B 區分」
	# 這個錯誤形狀的間諜子類別。
	var bundle: Dictionary = _build(
		["1,P1,PLAYER,20,10,0,3,1,1,0,0", "2,E1,ENEMY,20,10,0,0,1,1,12,5"], [1], [2]
	)
	var mutant: _MutantCollapsesTerrainIntoOutOfRange = (
		_MutantCollapsesTerrainIntoOutOfRange.new(bundle["state"], bundle["order"])
	)
	var origin: Vector2i = Vector2i(0, 0)
	var terrain_cell: Vector2i = Vector2i(3, 0)
	var set_a: Dictionary = {}
	var set_b: Dictionary = {}
	var set_c: Dictionary = {terrain_cell: true}

	# Act
	var breakdown: Dictionary = mutant._classify_move_targets(origin, set_a, set_b, set_c)

	# Assert — 證明若真的出現這種錯誤實作，上面
	# test_four_states_partition_grid_with_no_fifth_category_and_mutual_exclusion()
	# 斷言「terrain_cell 必須出現在 blocked_by_terrain」真的會被踩中，不是巧合同值：
	# 這裡它被錯誤地併入 out_of_range。
	assert_array(breakdown["blocked_by_terrain"]).not_contains([terrain_cell])
	assert_array(breakdown["out_of_range"]).contains([terrain_cell])


# 間諜子類別 2 —— 重現 AC-14 真正會失效的寫法：直接開權威寫入視窗、繞過
# BattleState.move_unit() 的 legal_moves() 檢查。查證結論（寫在這裡避免下一個人
# 重查一次）：單獨放寬 BattleController._move_targets_for()（第一道閘門）不足以
# 構成可觀測的繞過 —— click_tile() 仍會呼叫 _apply_move() -> BattleState.move_unit()，
# 而 move_unit() 內部獨立地用真正的 legal_moves() 再驗一次（battle_state.gd:338
# `if not legal_moves(id).has(dest): return false`），所以第一道閘門被放寬時，
# 第二道閘門仍會攔下來，不會產生可供偵測的缺陷。真正會讓 AC-14 失效的寫法，
# 是繞過 move_unit() 本身（例如：未來有人把新查詢的輸出直接接到一條跳過權威
# 入口的路徑）——本間諜子類別重現這個寫法。
class _MutantBypassesMoveLegalityCheck extends BattleController:
	func click_tile(pos: Vector2i) -> Dictionary:
		if _phase != Phase.PLAYER_INPUT or _selected_unit_id == -1:
			return {"action": &"none"}
		var moved_id: int = _selected_unit_id
		var origin: Vector2i = _state.position_of(moved_id)
		_state.commit_authoritative_change(func() -> void:
			_state.board._clear_occupant(origin)
			_state.board._set_occupant(pos, moved_id)
			_state._positions[moved_id] = pos
		)
		return {"action": &"moved", "unit_id": moved_id, "from": origin, "to": pos}


func test_sensitivity_proof_legality_gate_detects_bypass_of_authoritative_recheck() -> void:
	# Arrange — 與上方 AC-14 回歸測試完全相同的場景，改用繞過
	# BattleState.move_unit() 權威檢查的間諜子類別。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,3,1,1,6,3",
		"2,E1,ENEMY,20,10,0,0,1,1,8,3",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var mutant: _MutantBypassesMoveLegalityCheck = (
		_MutantBypassesMoveLegalityCheck.new(state, order)
	)
	assert_bool(mutant.select_unit(1)).is_true()

	# Act
	var click_result: Dictionary = mutant.click_tile(Vector2i(8, 3))

	# Assert — 證明若真的出現「繞過 move_unit() 檢查」這種寫法，
	# test_move_confirmation_rejects_tile_flagged_blocked_by_occupancy() 的斷言
	# （action 必須是 "deselected"，不是 "moved"）真的會被踩中，不是巧合同值。
	assert_bool(click_result["action"] == &"moved").is_true()
	assert_bool(state.position_of(1) == Vector2i(8, 3)).is_true()
