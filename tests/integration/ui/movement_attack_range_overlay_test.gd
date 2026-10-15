# Story 014（移動範圍三態+第四態、攻擊範圍三層疊加圖）的測試——
# production/epics/tactical-combat/story-014-movement-attack-range-overlay-layers.md。
#
# 本檔涵蓋 board_view.gd 新增的兩個公開方法：
#   - set_move_unreachable_highlights(blocked_occupancy, blocked_terrain, out_of_range)
#   - set_attack_los_blocked_highlights(cells)
# 以及新增的兩個圖層節點（MoveUnreachableLayer / AttackLosBlockedLayer）的場景結構、
# 疊層順序。
#
# ⚠️ headless 不 rasterize 繪製結果——以下測試只能驗「畫了幾個節點、什麼型別、疊在
# 哪一層」這種結構性事實，驗不了「外框看起來像外框、斜線看起來像斜線」這種視覺判讀。
# 後者需要真實開視窗擷圖 + 人眼看過，依本 story 的管理者裁決批次化到 M4 完成後進行，
# 不在本檔範圍。
#
# ⚠️ 本檔只覆蓋 board_view.gd 這一層（純消費端的繪製契約）。battle_screen.gd 內
# _refresh_view() 的排除邏輯（move_breakdown_excluded 從 blocked_occupancy/
# blocked_terrain/out_of_range 扣除 attack_cells ∪ threat_cells_final）需要完整的
# BattleController/BattleState 盤面夾具才能驅動到，不在本輪範圍內——誠實登記為
# 未覆蓋，不代為斷言它已被驗證。
#
# 命名慣例依 tests/integration/ui/card_target_selection_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
#
# ============================================================================
# 敏感度證明涵蓋盤點
# ============================================================================
# | # | 測試函式名 | 判定 | 依據 |
# |---|---|------|------|
# | 1 | test_move_unreachable_layer_node_resolves_with_correct_type | A（結構存在性，見下） | .tscn 靜態節點，@onready 解析 |
# | 2 | test_move_unreachable_layer_draws_above_pieces_and_below_threat | 可證明 | 見下方 sensitivity proof |
# | 3 | test_attack_los_blocked_layer_node_resolves_with_correct_type | A | 同上 |
# | 4 | test_attack_los_blocked_layer_draws_above_attack_and_below_card_target | 可證明 | 見下方 sensitivity proof |
# | 5 | test_blocked_occupancy_draws_outline_only_no_hatch_no_dot | 可證明 | 見下方 sensitivity proof |
# | 6 | test_blocked_terrain_draws_outline_plus_three_hatch_lines | 可證明 | 見下方 sensitivity proof |
# | 7 | test_out_of_range_draws_dot_not_outline | 可證明 | 見下方 sensitivity proof |
# | 8 | test_set_move_unreachable_highlights_pass_through_cell_count_not_reshaped | 可證明 | 同組機制 |
# | 9 | test_set_move_unreachable_highlights_with_empty_arrays_clears_layer | 可證明 | 同組機制 |
# | 10 | test_set_attack_los_blocked_highlights_draws_outline_plus_one_diagonal | 可證明 | 見下方 sensitivity proof |
# | 11 | test_set_attack_los_blocked_highlights_with_empty_array_clears_layer | 可證明 | 同組機制 |
#
# 第 1/3 列判定為 A（.tscn 內靜態節點是否存在這件事本身不是「可被子類別覆寫注入」
# 的程式邏輯，與 card_target_selection_test.gd 既有判例「board_view.gd 的 _ready()
# 本體」的性質不同——這裡驗的是場景檔本身的節點樹，注入手法會是改場景檔而非寫
# mutant 子類別，故本輪不另建敏感度證明，僅記錄為結構性斷言）。其餘 9 條皆附
# 常駐 test_sensitivity_proof_* 測試。
# ============================================================================
extends GdUnitTestSuite


const _BOARD_VIEW_SCENE_PATH: String = "res://src/ui/battle/BoardView.tscn"


func _fresh_board_view() -> BoardView:
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _count_line2d_descendants(node: Node) -> int:
	var count: int = 1 if node is Line2D else 0
	for child: Node in node.get_children():
		count += _count_line2d_descendants(child)
	return count


func _count_colorrect_descendants(node: Node) -> int:
	var count: int = 1 if node is ColorRect else 0
	for child: Node in node.get_children():
		count += _count_colorrect_descendants(child)
	return count


# ─── 場景節點存在、疊層順序正確 ─────────────────────────────────────────────────


func test_move_unreachable_layer_node_resolves_with_correct_type() -> void:
	# Arrange / Act
	var instance: BoardView = _fresh_board_view()
	var node: Node = instance.get_node("MoveUnreachableLayer")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is Node2D).is_true()


func test_attack_los_blocked_layer_node_resolves_with_correct_type() -> void:
	# Arrange / Act
	var instance: BoardView = _fresh_board_view()
	var node: Node = instance.get_node("AttackLosBlockedLayer")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is Node2D).is_true()


func test_move_unreachable_layer_draws_above_pieces_and_below_threat() -> void:
	# Arrange — Node2D 的繪製順序就是子節點順序，get_index() 越大越晚畫（越上層）
	var instance: BoardView = _fresh_board_view()

	# Act
	var pieces_index: int = instance.get_node("PiecesLayer").get_index()
	var move_unreachable_index: int = instance.get_node("MoveUnreachableLayer").get_index()
	var threat_index: int = instance.get_node("ThreatHighlightLayer").get_index()
	var attack_index: int = instance.get_node("AttackHighlightLayer").get_index()

	# Assert — 必須畫在棋子之上（blocked_by_occupancy 格依定義通常站著單位），
	# 但畫在威脅/攻擊圖層之下（那是更高優先序的資訊，見 board_view.gd 類別
	# doc comment 的 layer-order 說明）
	assert_int(move_unreachable_index).append_failure_message(
		"MoveUnreachableLayer 必須畫在 PiecesLayer 之上，否則 blocked_by_occupancy "
		+ "格上的標記會被站著的單位完全遮住"
	).is_greater(pieces_index)
	assert_int(move_unreachable_index).is_less(threat_index)
	assert_int(move_unreachable_index).is_less(attack_index)


## 敏感度證明用的間諜子類別——把 MoveUnreachableLayer 移到最前面（index 0，
## 疊在 PiecesLayer 之下），模擬「疊層順序被改壞」這個回歸。BoardView 本身未定義
## _ready()（直接 extends Node2D），故不呼叫 super._ready()——與
## card_target_selection_test.gd 已實測記載的理由相同。
class _MutantMoveUnreachableWrongLayerOrder extends BoardView:
	func _ready() -> void:
		var layer: Node = get_node_or_null("MoveUnreachableLayer")
		if layer != null:
			move_child(layer, 0)


func test_sensitivity_proof_move_unreachable_layer_wrong_order_regression_detected() -> void:
	# Arrange
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	instance.set_script(_MutantMoveUnreachableWrongLayerOrder)
	add_child(instance)

	# Act
	var pieces_index: int = instance.get_node("PiecesLayer").get_index()
	var move_unreachable_index: int = instance.get_node("MoveUnreachableLayer").get_index()

	# Assert —— mutant 把圖層移到最前面，index 必然小於 PiecesLayer，證明
	# test_move_unreachable_layer_draws_above_pieces_and_below_threat() 的
	# is_greater(pieces_index) 斷言會抓到疊層順序被改壞
	assert_int(move_unreachable_index).append_failure_message(
		"mutant 應該已經把 MoveUnreachableLayer 移到最前面，若這裡量到相反，代表" +
		"本注入手法本身有問題"
	).is_less(pieces_index)


func test_attack_los_blocked_layer_draws_above_attack_and_below_card_target() -> void:
	# Arrange
	var instance: BoardView = _fresh_board_view()

	# Act
	var attack_index: int = instance.get_node("AttackHighlightLayer").get_index()
	var los_blocked_index: int = instance.get_node("AttackLosBlockedLayer").get_index()
	var card_target_index: int = instance.get_node("CardTargetHighlightLayer").get_index()
	var stats_index: int = instance.get_node("StatsLayer").get_index()

	# Assert
	assert_int(los_blocked_index).is_greater(attack_index)
	assert_int(los_blocked_index).is_less(card_target_index)
	assert_int(los_blocked_index).append_failure_message(
		"AttackLosBlockedLayer 必須畫在 StatsLayer 之下，否則會蓋住血條/血量文字"
	).is_less(stats_index)


## 同上手法——把 AttackLosBlockedLayer 移到最前面，模擬疊層順序被改壞。
class _MutantAttackLosBlockedWrongLayerOrder extends BoardView:
	func _ready() -> void:
		var layer: Node = get_node_or_null("AttackLosBlockedLayer")
		if layer != null:
			move_child(layer, 0)


func test_sensitivity_proof_attack_los_blocked_layer_wrong_order_regression_detected() -> void:
	# Arrange
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	instance.set_script(_MutantAttackLosBlockedWrongLayerOrder)
	add_child(instance)

	# Act
	var attack_index: int = instance.get_node("AttackHighlightLayer").get_index()
	var los_blocked_index: int = instance.get_node("AttackLosBlockedLayer").get_index()

	# Assert —— mutant 把圖層移到最前面，index 必然小於 AttackHighlightLayer，
	# 證明 is_greater(attack_index) 斷言會抓到疊層順序被改壞
	assert_int(los_blocked_index).append_failure_message(
		"mutant 應該已經把 AttackLosBlockedLayer 移到最前面，若這裡量到相反，代表" +
		"本注入手法本身有問題"
	).is_less(attack_index)


# ─── set_move_unreachable_highlights() —— 三態各自的形狀區分 ─────────────────────


func test_blocked_occupancy_draws_outline_only_no_hatch_no_dot() -> void:
	# Arrange
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("MoveUnreachableLayer")

	# Act — 1 個 blocked_occupancy 格，其餘兩態皆空
	instance.set_move_unreachable_highlights([Vector2i(2, 1)], [], [])

	# Assert — 恰好 1 個根節點（外框），其下恰好 4 個 ColorRect（四邊框）、
	# 0 條 Line2D（沒有 terrain 的 hatch 線）
	assert_int(layer.get_child_count()).append_failure_message(
		"blocked_occupancy 應只畫 1 個外框根節點，實得 %d" % layer.get_child_count()
	).is_equal(1)
	var rect_count: int = 0
	var line_count: int = 0
	for child: Node in layer.get_children():
		rect_count += _count_colorrect_descendants(child)
		line_count += _count_line2d_descendants(child)
	assert_int(rect_count).append_failure_message(
		"外框由 4 個 ColorRect 組成（上下左右），實得 %d" % rect_count
	).is_equal(4)
	assert_int(line_count).append_failure_message(
		"blocked_occupancy 不應出現任何 Line2D（那是 blocked_terrain 的 hatch 線）"
	).is_equal(0)


func test_blocked_terrain_draws_outline_plus_three_hatch_lines() -> void:
	# Arrange
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("MoveUnreachableLayer")

	# Act — 1 個 blocked_terrain 格，其餘兩態皆空
	instance.set_move_unreachable_highlights([], [Vector2i(4, 0)], [])

	# Assert — 2 個根節點（外框 + hatch），外框 4 個 ColorRect、hatch 3 條 Line2D
	assert_int(layer.get_child_count()).append_failure_message(
		"blocked_terrain 應畫「外框 + hatch」兩個根節點，實得 %d" % layer.get_child_count()
	).is_equal(2)
	var rect_count: int = 0
	var line_count: int = 0
	for child: Node in layer.get_children():
		rect_count += _count_colorrect_descendants(child)
		line_count += _count_line2d_descendants(child)
	assert_int(rect_count).is_equal(4)
	assert_int(line_count).append_failure_message(
		"blocked_terrain 應有恰好 3 條 Line2D 組成水平 hazard bar，實得 %d" % line_count
	).is_equal(3)


func test_out_of_range_draws_dot_not_outline() -> void:
	# Arrange
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("MoveUnreachableLayer")

	# Act — 1 個 out_of_range 格，其餘兩態皆空
	instance.set_move_unreachable_highlights([], [], [Vector2i(0, 5)])

	# Assert — 恰好 1 個根節點（小點），其下恰好 1 個 ColorRect（不是外框的 4 個）、
	# 0 條 Line2D —— 形狀與數量上都與另兩態不同
	assert_int(layer.get_child_count()).is_equal(1)
	var rect_count: int = 0
	var line_count: int = 0
	for child: Node in layer.get_children():
		rect_count += _count_colorrect_descendants(child)
		line_count += _count_line2d_descendants(child)
	assert_int(rect_count).append_failure_message(
		"out_of_range 應只有 1 個 ColorRect（小點），不是外框的 4 個，實得 %d" % rect_count
	).is_equal(1)
	assert_int(line_count).is_equal(0)


## 敏感度證明用的間諜子類別——三態各自故意漏畫一部分，模擬形狀區分失守。
## set_move_unreachable_highlights() 是一般 instance method（已讀簽章與本體），
## 覆寫不涉及 _ready() 時機，直接呼叫真實私有 helper，只是刻意省略其中一支呼叫。
class _MutantMoveUnreachableTerrainMissingHatch extends BoardView:
	func set_move_unreachable_highlights(
		blocked_occupancy: Array[Vector2i],
		blocked_terrain: Array[Vector2i],
		out_of_range: Array[Vector2i]
	) -> void:
		_clear_children(_move_unreachable_layer)
		for cell: Vector2i in blocked_occupancy:
			_move_unreachable_layer.add_child(_build_move_blocked_outline(cell))
		for cell: Vector2i in blocked_terrain:
			# 刻意省略 _build_move_terrain_hatch() 這支呼叫
			_move_unreachable_layer.add_child(_build_move_blocked_outline(cell))
		for cell: Vector2i in out_of_range:
			_move_unreachable_layer.add_child(_build_move_out_of_range_dot(cell))


func test_sensitivity_proof_blocked_terrain_missing_hatch_regression_detected() -> void:
	# Arrange
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	instance.set_script(_MutantMoveUnreachableTerrainMissingHatch)
	add_child(instance)
	var layer: Node2D = instance.get_node("MoveUnreachableLayer")

	# Act
	instance.set_move_unreachable_highlights([], [Vector2i(4, 0)], [])

	# Assert —— mutant 省略 hatch，Line2D 數量應為 0（非預期 3），證明
	# test_blocked_terrain_draws_outline_plus_three_hatch_lines() 的 is_equal(3)
	# 斷言會抓到 hatch 漏畫
	var line_count: int = 0
	for child: Node in layer.get_children():
		line_count += _count_line2d_descendants(child)
	assert_int(line_count).append_failure_message(
		"mutant 應該省略 hatch，Line2D 數量應為 0，若這裡量到 3，代表本注入手法本身" +
		"有問題"
	).is_equal(0)


class _MutantMoveUnreachableOccupancyDrawsDotInstead extends BoardView:
	func set_move_unreachable_highlights(
		blocked_occupancy: Array[Vector2i],
		_blocked_terrain: Array[Vector2i],
		_out_of_range: Array[Vector2i]
	) -> void:
		_clear_children(_move_unreachable_layer)
		# 刻意回歸：blocked_occupancy 錯畫成小點（本應是外框），模擬「兩態共用
		# 同一個繪製分支」這個回歸——這正是 P-F3 要求避免的「形狀區分消失」。
		for cell: Vector2i in blocked_occupancy:
			_move_unreachable_layer.add_child(_build_move_out_of_range_dot(cell))


func test_sensitivity_proof_blocked_occupancy_drawn_as_dot_regression_detected() -> void:
	# Arrange
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	instance.set_script(_MutantMoveUnreachableOccupancyDrawsDotInstead)
	add_child(instance)
	var layer: Node2D = instance.get_node("MoveUnreachableLayer")

	# Act
	instance.set_move_unreachable_highlights([Vector2i(2, 1)], [], [])

	# Assert —— mutant 把 blocked_occupancy 畫成點（1 個 ColorRect），非外框
	# （4 個 ColorRect），證明 test_blocked_occupancy_draws_outline_only_no_hatch_no_dot()
	# 的 is_equal(4) 斷言會抓到「兩態形狀混用」這個回歸
	var rect_count: int = 0
	for child: Node in layer.get_children():
		rect_count += _count_colorrect_descendants(child)
	assert_int(rect_count).append_failure_message(
		"mutant 應該把 blocked_occupancy 畫成點（1 個 ColorRect），若這裡量到 4，代表" +
		"本注入手法本身有問題"
	).is_equal(1)


func test_set_move_unreachable_highlights_pass_through_cell_count_not_reshaped() -> void:
	# Arrange — 這組測試是「單一快照 / 不重新計算查詢結果」契約的呈現層對應：
	# BoardView 必須忠實畫出呼叫端給的每一格，不得依任何幾何規則過濾或改形狀——
	# 曼哈頓菱形的正確性完全由上游查詢（Board.reachable_tiles() 等）保證，本層
	# 只負責「給幾格、畫幾格」。餵一組刻意不成任何規則形狀的座標，驗證三態
	# 各自的根節點數與輸入格數一一對應。
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("MoveUnreachableLayer")
	var blocked_occupancy: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 3)]
	var blocked_terrain: Array[Vector2i] = [Vector2i(1, 1)]
	var out_of_range: Array[Vector2i] = [Vector2i(7, 2), Vector2i(8, 2), Vector2i(0, 5)]

	# Act
	instance.set_move_unreachable_highlights(blocked_occupancy, blocked_terrain, out_of_range)

	# Assert — 2 個 occupancy（各 1 根）+ 1 個 terrain（1 根，outline+hatch 算一組，
	# 但 outline 與 hatch 是兩個分開 add_child 的根節點，故 terrain 每格佔 2 根）
	# + 3 個 out_of_range（各 1 根）= 2*1 + 1*2 + 3*1 = 7
	var expected_root_count: int = (
		blocked_occupancy.size() * 1 + blocked_terrain.size() * 2 + out_of_range.size() * 1
	)
	assert_int(layer.get_child_count()).append_failure_message(
		"根節點數應與輸入格數一一對應（occupancy 1 根/格、terrain 2 根/格、" +
		"out_of_range 1 根/格），預期 %d，實得 %d" % [expected_root_count, layer.get_child_count()]
	).is_equal(expected_root_count)


func test_set_move_unreachable_highlights_with_empty_arrays_clears_layer() -> void:
	# Arrange — 先畫一些東西
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("MoveUnreachableLayer")
	instance.set_move_unreachable_highlights([Vector2i(0, 0)], [Vector2i(1, 1)], [Vector2i(2, 2)])
	assert_int(layer.get_child_count()).is_greater(0)

	# Act
	instance.set_move_unreachable_highlights([], [], [])

	# Assert
	assert_int(layer.get_child_count()).is_equal(0)


class _MutantMoveUnreachableClearSkippedWhenAllEmpty extends BoardView:
	func set_move_unreachable_highlights(
		blocked_occupancy: Array[Vector2i],
		blocked_terrain: Array[Vector2i],
		out_of_range: Array[Vector2i]
	) -> void:
		if blocked_occupancy.is_empty() and blocked_terrain.is_empty() and out_of_range.is_empty():
			return
		_clear_children(_move_unreachable_layer)
		for cell: Vector2i in blocked_occupancy:
			_move_unreachable_layer.add_child(_build_move_blocked_outline(cell))
		for cell: Vector2i in blocked_terrain:
			_move_unreachable_layer.add_child(_build_move_blocked_outline(cell))
			_move_unreachable_layer.add_child(_build_move_terrain_hatch(cell))
		for cell: Vector2i in out_of_range:
			_move_unreachable_layer.add_child(_build_move_out_of_range_dot(cell))


func test_sensitivity_proof_move_unreachable_clear_skipped_regression_detected() -> void:
	# Arrange
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	instance.set_script(_MutantMoveUnreachableClearSkippedWhenAllEmpty)
	add_child(instance)
	var layer: Node2D = instance.get_node("MoveUnreachableLayer")
	instance.set_move_unreachable_highlights([Vector2i(0, 0)], [], [])
	assert_int(layer.get_child_count()).append_failure_message(
		"PRECONDITION: mutant 建構初始高亮失敗——夾具本身有問題，不是在驗證回歸"
	).is_greater(0)

	# Act
	instance.set_move_unreachable_highlights([], [], [])

	# Assert —— mutant 遇三者皆空時直接 return（不清空），殘留節點應仍大於 0，
	# 證明 test_set_move_unreachable_highlights_with_empty_arrays_clears_layer() 的
	# is_equal(0) 斷言會抓到清空失敗
	assert_int(layer.get_child_count()).append_failure_message(
		"mutant 應該保留殘影（不清空），若這裡量到 0，代表本注入手法本身有問題"
	).is_greater(0)


# ─── set_attack_los_blocked_highlights() —— 外框 + 單斜線 ───────────────────────


func test_set_attack_los_blocked_highlights_draws_outline_plus_one_diagonal() -> void:
	# Arrange
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("AttackLosBlockedLayer")

	# Act — 2 個範圍內但視線被擋的格
	instance.set_attack_los_blocked_highlights([Vector2i(3, 3), Vector2i(6, 1)])

	# Assert — 每格 2 個根節點（外框 + 斜線），共 4；外框共 4*2=8 個 ColorRect；
	# 斜線共 2 條 Line2D（每格恰 1 條，不是 X 記號的 2 條）
	assert_int(layer.get_child_count()).append_failure_message(
		"2 個格應各畫「外框 + 斜線」兩個根節點，共 4，實得 %d" % layer.get_child_count()
	).is_equal(4)
	var rect_count: int = 0
	var line_count: int = 0
	for child: Node in layer.get_children():
		rect_count += _count_colorrect_descendants(child)
		line_count += _count_line2d_descendants(child)
	assert_int(rect_count).is_equal(8)
	assert_int(line_count).append_failure_message(
		"每格應恰有 1 條 Line2D（單斜線，非 X 記號的 2 條），2 格共應為 2，實得 %d"
		% line_count
	).is_equal(2)


func test_set_attack_los_blocked_highlights_with_empty_array_clears_layer() -> void:
	# Arrange
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("AttackLosBlockedLayer")
	instance.set_attack_los_blocked_highlights([Vector2i(1, 1)])
	assert_int(layer.get_child_count()).is_greater(0)

	# Act
	instance.set_attack_los_blocked_highlights([])

	# Assert
	assert_int(layer.get_child_count()).is_equal(0)


## 敏感度證明——故意只畫外框、省略斜線，模擬「第三層被畫成與無疊加相同」這個
## GDD Core Rules #4 明文禁止的回歸的一個子情形（外框尚在、但少了能和純外框的
## blocked_occupancy 區分開的斜線標記）。
class _MutantAttackLosBlockedMissingSlash extends BoardView:
	func set_attack_los_blocked_highlights(cells: Array[Vector2i]) -> void:
		_clear_children(_attack_los_blocked_layer)
		for cell: Vector2i in cells:
			_attack_los_blocked_layer.add_child(_build_attack_los_blocked_outline(cell))


func test_sensitivity_proof_attack_los_blocked_missing_slash_regression_detected() -> void:
	# Arrange
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	instance.set_script(_MutantAttackLosBlockedMissingSlash)
	add_child(instance)
	var layer: Node2D = instance.get_node("AttackLosBlockedLayer")

	# Act
	instance.set_attack_los_blocked_highlights([Vector2i(3, 3), Vector2i(6, 1)])

	# Assert —— mutant 省略斜線，Line2D 數量應為 0（非預期 2），證明
	# test_set_attack_los_blocked_highlights_draws_outline_plus_one_diagonal() 的
	# is_equal(2) 斷言會抓到斜線漏畫
	var line_count: int = 0
	for child: Node in layer.get_children():
		line_count += _count_line2d_descendants(child)
	assert_int(line_count).append_failure_message(
		"mutant 應該省略斜線，Line2D 數量應為 0，若這裡量到 2，代表本注入手法本身" +
		"有問題"
	).is_equal(0)
