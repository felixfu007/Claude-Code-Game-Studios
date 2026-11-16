# Story 015（單位行動旗標持久非色彩標記 + 不可通行地形呈現）的測試——
# production/epics/tactical-combat/story-015-action-flag-marker-impassable-terrain-render.md。
#
# 本檔涵蓋 board_view.gd 新增的兩個公開方法：
#   - render_pieces() 的新 OPTIONAL "action_flag" 欄位（四態持久角標）
#   - set_impassable_terrain_highlights(cells) （地形不可通行棋盤格標記）
# 以及新增的兩個圖層節點（ActionFlagLayer / ImpassableTerrainLayer）的場景結構、疊層順序。
#
# ⚠️ headless 不 rasterize 繪製結果——以下測試只能驗「畫了幾個節點、什麼型別、疊在
# 哪一層、哪個 pip 填滿」這種結構性事實，驗不了「看起來像什麼」這種視覺判讀。後者需要
# 真實開視窗擷圖 + 人眼看過，依本 story 的管理者裁決批次化到 M4 完成後進行，不在本檔範圍。
#
# ⚠️ 本檔只覆蓋 board_view.gd 這一層（純消費端的繪製契約）。battle_screen.gd 內
# _action_flag_for_state() 的列舉映射與 _ready() 內的不可通行格掃描邏輯需要完整的
# BattleController/BattleState 盤面夾具才能驅動到，不在本輪範圍內——誠實登記為未覆蓋，
# 不代為斷言它已被驗證。
#
# 命名慣例依 tests/integration/ui/movement_attack_range_overlay_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
#
# ============================================================================
# 敏感度證明涵蓋盤點
# ============================================================================
# | # | 測試函式名 | 判定 | 依據 |
# |---|---|------|------|
# | 1 | test_action_flag_layer_node_resolves_with_correct_type | A（結構存在性） | .tscn 靜態節點 |
# | 2 | test_impassable_terrain_layer_node_resolves_with_correct_type | A | 同上 |
# | 3 | test_action_flag_layer_draws_above_stats_and_below_cursor | 可證明 | 見下方 sensitivity proof |
# | 4 | test_impassable_terrain_layer_draws_above_terrain_and_below_move_highlight | 可證明 | 見下方 sensitivity proof |
# | 11 | test_set_impassable_terrain_highlights_draws_two_quadrant_rects_per_cell | 可證明 | 見下方 sensitivity proof |
# | 12 | test_set_impassable_terrain_highlights_with_empty_array_clears_layer | 可證明 | 同組機制 |
# （story-054：原 5~10 列的小方塊形狀測試已移除/改寫，由
#  board_view_action_state_icons_test.gd 接手，不在本表。）
#
# 第 1/2 列判定為 A（.tscn 內靜態節點是否存在這件事本身不是「可被子類別覆寫注入」的
# 程式邏輯——與 movement_attack_range_overlay_test.gd 既有判例性質相同，這裡驗的是場景
# 檔本身的節點樹，注入手法會是改場景檔而非寫 mutant 子類別，故本輪不另建敏感度證明，
# 僅記錄為結構性斷言）。其餘 10 條皆附常駐 test_sensitivity_proof_* 測試。
# ============================================================================
extends GdUnitTestSuite


const _BOARD_VIEW_SCENE_PATH: String = "res://src/ui/battle/BoardView.tscn"


func _fresh_board_view() -> BoardView:
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _count_colorrect_descendants(node: Node) -> int:
	var count: int = 1 if node is ColorRect else 0
	for child: Node in node.get_children():
		count += _count_colorrect_descendants(child)
	return count


# ─── 場景節點存在、疊層順序正確 ─────────────────────────────────────────────────


func test_action_flag_layer_node_resolves_with_correct_type() -> void:
	# Arrange / Act
	var instance: BoardView = _fresh_board_view()
	var node: Node = instance.get_node("ActionFlagLayer")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is Node2D).is_true()


func test_impassable_terrain_layer_node_resolves_with_correct_type() -> void:
	# Arrange / Act
	var instance: BoardView = _fresh_board_view()
	var node: Node = instance.get_node("ImpassableTerrainLayer")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is Node2D).is_true()


func test_action_flag_layer_draws_above_stats_and_below_cursor() -> void:
	# Arrange — Node2D 的繪製順序就是子節點順序，get_index() 越大越晚畫（越上層）
	var instance: BoardView = _fresh_board_view()

	# Act
	var stats_index: int = instance.get_node("StatsLayer").get_index()
	var action_flag_index: int = instance.get_node("ActionFlagLayer").get_index()
	var cursor_index: int = instance.get_node("CursorSprite").get_index()

	# Assert — AC-1 要求「常駐、不被任何東西蓋住」，必須是 CursorSprite 之外
	# 最上層的圖層
	assert_int(action_flag_index).append_failure_message(
		"ActionFlagLayer 必須畫在 StatsLayer 之上，否則角標會被 HP 高亮蓋住的風險更高"
	).is_greater(stats_index)
	assert_int(action_flag_index).is_less(cursor_index)


## 敏感度證明——把 ActionFlagLayer 移到最前面，模擬疊層順序被改壞。
class _MutantActionFlagWrongLayerOrder extends BoardView:
	func _ready() -> void:
		var layer: Node = get_node_or_null("ActionFlagLayer")
		if layer != null:
			move_child(layer, 0)


func test_sensitivity_proof_action_flag_layer_wrong_order_regression_detected() -> void:
	# Arrange
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	instance.set_script(_MutantActionFlagWrongLayerOrder)
	add_child(instance)

	# Act
	var stats_index: int = instance.get_node("StatsLayer").get_index()
	var action_flag_index: int = instance.get_node("ActionFlagLayer").get_index()

	# Assert —— mutant 把圖層移到最前面，index 必然小於 StatsLayer，證明
	# test_action_flag_layer_draws_above_stats_and_below_cursor() 的 is_greater()
	# 斷言會抓到疊層順序被改壞
	assert_int(action_flag_index).append_failure_message(
		"mutant 應該已經把 ActionFlagLayer 移到最前面，若這裡量到相反，代表本注入手法" +
		"本身有問題"
	).is_less(stats_index)


func test_impassable_terrain_layer_draws_above_terrain_and_below_move_highlight() -> void:
	# Arrange
	var instance: BoardView = _fresh_board_view()

	# Act
	var terrain_index: int = instance.get_node("TerrainLayer").get_index()
	var impassable_index: int = instance.get_node("ImpassableTerrainLayer").get_index()
	var move_highlight_index: int = instance.get_node("MoveHighlightLayer").get_index()

	# Assert
	assert_int(impassable_index).append_failure_message(
		"ImpassableTerrainLayer 必須畫在 TerrainLayer 之上，否則標記會被地形貼圖蓋住"
	).is_greater(terrain_index)
	assert_int(impassable_index).is_less(move_highlight_index)


## 敏感度證明——把 ImpassableTerrainLayer 移到最後面，模擬疊層順序被改壞。
class _MutantImpassableTerrainWrongLayerOrder extends BoardView:
	func _ready() -> void:
		var layer: Node = get_node_or_null("ImpassableTerrainLayer")
		if layer != null:
			move_child(layer, get_child_count() - 1)


func test_sensitivity_proof_impassable_terrain_layer_wrong_order_regression_detected() -> void:
	# Arrange
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	instance.set_script(_MutantImpassableTerrainWrongLayerOrder)
	add_child(instance)

	# Act
	var move_highlight_index: int = instance.get_node("MoveHighlightLayer").get_index()
	var impassable_index: int = instance.get_node("ImpassableTerrainLayer").get_index()

	# Assert —— mutant 把圖層移到最後面，index 必然大於 MoveHighlightLayer，證明
	# test_impassable_terrain_layer_draws_above_terrain_and_below_move_highlight() 的
	# is_less() 斷言會抓到疊層順序被改壞
	assert_int(impassable_index).append_failure_message(
		"mutant 應該已經把 ImpassableTerrainLayer 移到最後面，若這裡量到相反，代表" +
		"本注入手法本身有問題"
	).is_greater(move_highlight_index)


# ─── render_pieces() 的 "action_flag" 欄位 —— story-054 起改為鞋/劍圖示 ─────────
# （story-054 取代 story-015 的兩顆小方塊;逐格顯示表/位置/變暗/敏感度證明在
#  board_view_action_state_icons_test.gd。本檔保留的是「常駐、不受選取門控、
#  每次重畫會清空」這三個 story-015 性質,改以新圖示節點斷言。）


func _one_piece(cell: Vector2i, action_flag: int) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	pieces.append({
		"cell": cell,
		"faction": "PLAYER",
		"sprite_index": 0,
		"hp": 10,
		"hp_max": 10,
		"action_flag": action_flag,
	})
	return pieces


func _count_sprite_descendants(node: Node) -> int:
	var count: int = 1 if node is Sprite2D else 0
	for child: Node in node.get_children():
		count += _count_sprite_descendants(child)
	return count


func test_action_flag_drawn_for_every_piece_not_gated_on_show_hp_text() -> void:
	# Arrange — 「常駐於棋盤上，不需要選取或開啟面板才看得到」。刻意不設 show_hp_text。
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("ActionFlagLayer")
	var pieces: Array[Dictionary] = [{
		"cell": Vector2i(0, 0),
		"faction": "PLAYER",
		"sprite_index": 0,
		"hp": 10,
		"hp_max": 10,
		"show_hp_text": false,
		"action_flag": BoardView.ActionFlag.DONE,
	}]

	# Act
	instance.render_pieces(pieces)

	# Assert — DONE（移動、攻擊都已用）= 鞋 + 劍 兩個圖示,不被 show_hp_text 門控
	assert_int(_count_sprite_descendants(layer)).append_failure_message(
		"action_flag 不應被 show_hp_text 門控——未選取/未聚焦的單位也該畫出圖示"
	).is_equal(2)


func test_render_pieces_with_no_action_flag_field_draws_no_icons() -> void:
	# Arrange — 不帶 "action_flag" 欄位 = NONE_USED = 沒做過任何事 → 不畫任何圖示
	# （story-054「做過才出現」;story-015 時是兩個中空 pip）
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("ActionFlagLayer")
	var pieces: Array[Dictionary] = [{
		"cell": Vector2i(0, 0),
		"faction": "PLAYER",
		"sprite_index": 0,
		"hp": 10,
		"hp_max": 10,
	}]

	# Act
	instance.render_pieces(pieces)

	# Assert
	assert_int(_count_sprite_descendants(layer)).append_failure_message(
		"缺少 action_flag 欄位應預設 NONE_USED,不畫任何圖示"
	).is_equal(0)


func test_render_pieces_clears_action_flag_layer_between_calls() -> void:
	# Arrange — 先畫一個 DONE 單位(有圖示)
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("ActionFlagLayer")
	instance.render_pieces(_one_piece(Vector2i(0, 0), BoardView.ActionFlag.DONE))
	assert_int(_count_sprite_descendants(layer)).is_equal(2)

	# Act — 畫一個空陣列（棋盤上沒有任何存活單位）
	instance.render_pieces([])

	# Assert
	assert_int(layer.get_child_count()).is_equal(0)



# ─── set_impassable_terrain_highlights() —— 棋盤格層級的持久地形標記 ─────────────


func test_set_impassable_terrain_highlights_draws_two_quadrant_rects_per_cell() -> void:
	# Arrange — 2 個不可通行格（測試用合成座標，不依賴任何真實關卡地形資料——
	# vs01_terrain.txt 目前三種地形皆 passable=true，見本 story Implementation Note 3）
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("ImpassableTerrainLayer")

	# Act
	instance.set_impassable_terrain_highlights([Vector2i(3, 2), Vector2i(7, 4)])

	# Assert — 每格 1 個根節點（內含 2 個象限 ColorRect），共 2 個根節點、4 個 ColorRect
	assert_int(layer.get_child_count()).append_failure_message(
		"2 個不可通行格應各畫 1 個根節點，共 2，實得 %d" % layer.get_child_count()
	).is_equal(2)
	var rect_count: int = _count_colorrect_descendants(layer)
	assert_int(rect_count).append_failure_message(
		"每格棋盤格標記由 2 個象限 ColorRect 組成（左上+右下），2 格共應為 4，實得 %d"
		% rect_count
	).is_equal(4)


func test_set_impassable_terrain_highlights_with_empty_array_clears_layer() -> void:
	# Arrange
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("ImpassableTerrainLayer")
	instance.set_impassable_terrain_highlights([Vector2i(1, 1)])
	assert_int(layer.get_child_count()).is_greater(0)

	# Act
	instance.set_impassable_terrain_highlights([])

	# Assert
	assert_int(layer.get_child_count()).is_equal(0)


## 敏感度證明——故意只畫 1 個象限（而非 2 個），模擬「checkerboard 形狀被簡化成普通
## 單一填滿」這個回歸（會讓它退化成與其他「實心填滿」語彙混淆）。
class _MutantImpassableTerrainSingleQuadrant extends BoardView:
	func set_impassable_terrain_highlights(cells: Array[Vector2i]) -> void:
		_clear_children(_impassable_terrain_layer)
		for cell: Vector2i in cells:
			var root: Node2D = Node2D.new()
			var top_left: Vector2 = BoardCoords.grid_to_local(cell)
			var half: float = BoardCoords.CELL_SIZE * 0.5
			var only_quadrant: ColorRect = ColorRect.new()
			only_quadrant.color = IMPASSABLE_TERRAIN_CHECKER_COLOR
			only_quadrant.position = top_left
			only_quadrant.size = Vector2(half, half)
			root.add_child(only_quadrant)
			_impassable_terrain_layer.add_child(root)


func test_sensitivity_proof_impassable_terrain_single_quadrant_regression_detected() -> void:
	# Arrange
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	instance.set_script(_MutantImpassableTerrainSingleQuadrant)
	add_child(instance)
	var layer: Node2D = instance.get_node("ImpassableTerrainLayer")

	# Act
	instance.set_impassable_terrain_highlights([Vector2i(3, 2), Vector2i(7, 4)])

	# Assert —— mutant 每格只畫 1 個象限，2 格共 2 個 ColorRect（非預期的 4），證明
	# test_set_impassable_terrain_highlights_draws_two_quadrant_rects_per_cell() 的
	# is_equal(4) 斷言會抓到「象限畫少了」這個回歸
	var rect_count: int = _count_colorrect_descendants(layer)
	assert_int(rect_count).append_failure_message(
		"mutant 應該每格只畫 1 個象限（2 格共 2 個 ColorRect），若這裡量到 4，代表" +
		"本注入手法本身有問題"
	).is_equal(2)
