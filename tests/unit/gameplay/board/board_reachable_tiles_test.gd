# Board（src/gameplay/board/board.gd）reachable_tiles() 雙開關
# （ignore_occupancy/ignore_passability）+ 有界前緣展開的單元測試。
#
# 對應 production/epics/tactical-combat/story-002-reachable-tiles-bounded-frontier.md
# 的 Acceptance Criteria 與 QA Test Cases。驗收依據為 GDD 公式三 + AC-2/AC-13/
# AC-14 原文，不以 `docs/architecture/tr-registry.yaml` 的 TR-tactical-006
# 現行文字為準（該文字尚未反映 `ignore_passability` 這第二個獨立開關，見 story
# 文件 Context 節）。
#
# ⚠️ 命名慣例：依既有範本 board_test.gd / board_passable_test.gd 沿用
# test_[scenario]_[expected]（不含 [system] 前綴）。
extends GdUnitTestSuite


## 測試專用 Board 子類：新增一個「已登記、但 passable=false」的地形字元，
## 與 board_passable_test.gd 的 _BoardWithImpassableTestTerrain 同構（GDScript
## inner class 是逐檔案作用域，兩份定義不會互相衝突，故此檔獨立宣告一份，
## 不跨檔案引用）。理由同該檔：不去動唯讀的 TERRAIN_TABLE 常數，也不把測試
## 專用地形字元塞進正式關卡資料或正式 TERRAIN_TABLE。Board._terrain_entry()
## 是專為此設計的覆寫接縫。
class _BoardWithImpassableTestTerrain extends Board:
	## 測試專用地形字元：已登記、passable=false、cost=1（合法佔位值）。
	const IMPASSABLE_CHAR: String = "Z"

	func _terrain_entry(terrain: String) -> Variant:
		if terrain == IMPASSABLE_CHAR:
			return {"cost": 1, "passable": false}
		return super._terrain_entry(terrain)


## 測試專用 Board 子類：覆寫 QA-only 診斷接縫 _on_tile_visited()，計數
## reachable_tiles() 展開時實際造訪（dequeue + 標記 visited）的格數，用以
## 證明「有界前緣展開」這項演算法特徵（TR-tactical-008/OQ-16）——造訪格數應
## 隨 mp 增長而增長，且遠低於全盤格數，而非固定等於全盤格數（先展開全盤再
## 過濾的錯誤實作特徵）。
class _BoardWithVisitCounter extends Board:
	var visit_count: int = 0

	func _on_tile_visited(_pos: Vector2i) -> void:
		visit_count += 1


# 建一份全開闊（13x6，全 '.'）的 ascii 版面，供多個測試共用起點。
func _build_open_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for _y: int in range(Board.BOARD_HEIGHT):
		rows.append(".............")
	return rows


# 依既有慣例，reachable_tiles() 回傳的陣列恆不含 origin 本身——但 GDD 定義的
# reachable_set 概念上恆含 origin（AC-13「origin 恆屬於 A」，公式三既有輸出
# 範圍保證）。本輔助函式把 origin 加回集合，讓逐格分類邏輯對齊 GDD 的集合
# 定義，而非對齊 board.gd 回傳陣列排除 origin 這項既有慣例落差（此落差已在
# story 文件標為未查證，詳見該檔 QA Test Cases 開放地形基本案例一節）。
func _to_set_with_origin(tiles: Array[Vector2i], origin: Vector2i) -> Dictionary:
	var s: Dictionary = {}
	for t: Vector2i in tiles:
		s[t] = true
	s[origin] = true
	return s


# --- AC #1：新簽章向下相容 ---------------------------------------------------

func test_reachable_tiles_default_args_match_pre_story_two_arg_call_signature() -> void:
	# Arrange — 與 board_test.gd 既有的 MP=2 內陸起點場景逐字相同，驗證新簽章
	# 在呼叫端完全不變參時，行為與 story-002 之前的舊簽章完全一致
	var board: Board = Board.from_ascii(_build_open_rows())
	var origin: Vector2i = Vector2i(6, 3)

	# Act — 呼叫端僅傳 origin、mp 兩個既有參數
	var reachable: Array[Vector2i] = board.reachable_tiles(origin, 2)

	# Assert — 與 board_test.gd 既有測試斷言一致（12 格，不含 origin）
	assert_array(reachable).has_size(12)
	assert_bool(reachable.has(origin)).is_false()


# --- AC #4：ignore_occupancy 差集 -------------------------------------------

func test_reachable_tiles_ignore_occupancy_recovers_tile_blocked_by_sole_occupied_path() -> void:
	# Arrange — origin (0,0)、mp=2，唯一能以 mp=2 到達 (0,2) 的路徑是直線經過
	# (0,1)（無等成本繞路，QA Test Case「佔位擋死無繞路」向量）；(0,1) 佔位
	var board: Board = Board.from_ascii(_build_open_rows())
	var origin: Vector2i = Vector2i(0, 0)
	board.set_occupant(Vector2i(0, 1), 42)

	# Act
	var default_result: Array[Vector2i] = board.reachable_tiles(origin, 2)
	var ignore_occupancy_result: Array[Vector2i] = board.reachable_tiles(origin, 2, true, false)

	# Assert — 差集非空：預設（false）不含該格，ignore_occupancy=true 含該格
	assert_bool(default_result.has(Vector2i(0, 1))).is_false()
	assert_bool(default_result.has(Vector2i(0, 2))).is_false()
	assert_bool(ignore_occupancy_result.has(Vector2i(0, 1))).is_true()
	assert_bool(ignore_occupancy_result.has(Vector2i(0, 2))).is_true()


# --- AC #3：ignore_passability 差集（endpoint + pass-through 兩種向量）------

func test_reachable_tiles_ignore_passability_recovers_impassable_destination() -> void:
	# Arrange — 目的格本身 passable=false，origin 直線可達；分別呼叫
	# ignore_passability=false 與 =true，ignore_occupancy 皆為 true 以隔離
	# 佔位因素（QA Test Case 原文明訂的隔離方式）
	var board: _BoardWithImpassableTestTerrain = _BoardWithImpassableTestTerrain.new()
	var origin: Vector2i = Vector2i(0, 0)
	var target: Vector2i = Vector2i(2, 0)
	board._terrain[target] = _BoardWithImpassableTestTerrain.IMPASSABLE_CHAR

	# Act
	var passability_enforced: Array[Vector2i] = board.reachable_tiles(origin, 2, true, false)
	var passability_ignored: Array[Vector2i] = board.reachable_tiles(origin, 2, true, true)

	# Assert
	assert_bool(passability_enforced.has(target)).is_false()
	assert_bool(passability_ignored.has(target)).is_true()


func test_reachable_tiles_impassable_terrain_blocks_pass_through_even_when_destination_itself_is_passable() -> void:
	# Arrange — GDD Formulas 公式三邊界行為表「目的格可通行，但所有路徑皆須
	# 經過至少一格 passable=false」向量（2026-09-29 新增）。origin (0,0)、
	# mp=3，唯一能以 mp<=2 到達 (2,0) 的路徑須先經過 (1,0)；(1,0) 標記為測試
	# 專用 passable=false 地形，(2,0) 本身仍是一般平地（passable=true）。
	# mp=3 時不存在繞過 (1,0) 的替代路徑（平面格點的曼哈頓距離與路徑步數同
	# 奇偶性，距離 2 的目的地不存在長度 3 的路徑）
	var board: _BoardWithImpassableTestTerrain = _BoardWithImpassableTestTerrain.new()
	var origin: Vector2i = Vector2i(0, 0)
	var pass_through: Vector2i = Vector2i(1, 0)
	var destination: Vector2i = Vector2i(2, 0)
	board._terrain[pass_through] = _BoardWithImpassableTestTerrain.IMPASSABLE_CHAR

	# Act — ignore_occupancy 皆為 true，隔離佔位因素
	var passability_enforced: Array[Vector2i] = board.reachable_tiles(origin, 3, true, false)
	var passability_ignored: Array[Vector2i] = board.reachable_tiles(origin, 3, true, true)

	# Assert — 目的格本身可通行，但唯一路徑被中繼的不可通行格擋死
	assert_bool(board.passable(destination)).is_true()
	assert_bool(passability_enforced.has(pass_through)).is_false()
	assert_bool(passability_enforced.has(destination)).is_false()
	assert_bool(passability_ignored.has(pass_through)).is_true()
	assert_bool(passability_ignored.has(destination)).is_true()


func test_reachable_tiles_impassable_destination_excluded_regardless_of_mp_size() -> void:
	# Arrange — AC-2 向量：目的格 passable=false，MP 任意大依然恆不在集合中，
	# 不歸類為移動力不足（AC-13 第四類分類向量：此格屬 C\B，不屬 Grid\C）
	var board: _BoardWithImpassableTestTerrain = _BoardWithImpassableTestTerrain.new()
	var origin: Vector2i = Vector2i(0, 0)
	var destination: Vector2i = Vector2i(3, 3)
	board._terrain[destination] = _BoardWithImpassableTestTerrain.IMPASSABLE_CHAR

	# Act — mp 遠大於任何合理值，仍遠小於全盤展開成本，證明「不歸類為移動力
	# 不足」而非單純沒展開到
	var generous_mp_result: Array[Vector2i] = board.reachable_tiles(origin, 999, true, false)
	var fully_permissive_result: Array[Vector2i] = board.reachable_tiles(origin, 999, true, true)

	# Assert — 即使 ignore_occupancy=true 且 mp 極大，passable=false 仍恆
	# 排除；唯有同時 ignore_passability=true 才能納入
	assert_bool(generous_mp_result.has(destination)).is_false()
	assert_bool(fully_permissive_result.has(destination)).is_true()


# --- AC #5：origin 恆屬於 A（隱性不變量）------------------------------------

func test_reachable_tiles_origin_always_conceptually_in_a_even_when_origin_tile_itself_is_occupied() -> void:
	# Arrange — AC-13「origin 恆屬於 A」的隱性不變量：演算法從不檢查 origin
	# 自身的 passable()/has_occupant()，只檢查鄰居——本測試驗證即使 origin
	# 自身所在格被標記佔位，這條不變量依然成立（origin 週邊格不受影響地
	# 正常可達）
	var board: Board = Board.from_ascii(_build_open_rows())
	var origin: Vector2i = Vector2i(6, 3)
	board.set_occupant(origin, 1)

	# Act
	var default_result: Array[Vector2i] = board.reachable_tiles(origin, 2, false, false)

	# Assert — origin 自身佔位完全不影響鄰近格的可達性判定，範圍與既有的
	# 「內陸 origin、mp=2」場景（12 格）完全相同
	assert_array(default_result).has_size(12)
	assert_bool(default_result.has(Vector2i(6, 4))).is_true()
	assert_bool(default_result.has(Vector2i(7, 3))).is_true()


# --- AC #6：MP=0 邊界 ---------------------------------------------------

func test_reachable_tiles_mp_zero_returns_empty_array_under_all_flag_combinations() -> void:
	# Arrange — GDD AC-2/AC-13 邊界向量：MP=0 時 reachable_set={origin}，
	# 依既有慣例（回傳陣列恆不含 origin）即為空陣列，四種布林組合皆同
	var board: Board = Board.from_ascii(_build_open_rows())
	var origin: Vector2i = Vector2i(6, 3)

	# Act & Assert
	assert_array(board.reachable_tiles(origin, 0, false, false)).is_empty()
	assert_array(board.reachable_tiles(origin, 0, true, false)).is_empty()
	assert_array(board.reachable_tiles(origin, 0, false, true)).is_empty()
	assert_array(board.reachable_tiles(origin, 0, true, true)).is_empty()


# --- AC #2：四種布林組合皆良定義，A ⊆ B ⊆ C；四集合聯集窮盡且無殘留 ----------

func test_reachable_tiles_four_way_partition_is_exhaustive_and_disjoint() -> void:
	# Arrange — 13x6（78 格）全開闊版面，origin 在角落 (0,0)，mp=2：
	#   - (0,1) 佔位，擋死 (0,2) 的唯一路徑（唯一長度 2 路徑即直線經過它）
	#   - (1,1) 有等成本繞路（經 (1,0)），不受 (0,1) 佔位影響（AC-2「有等成本
	#     繞路」向量）
	#   - (2,0) 標記為測試專用地形字元 IMPASSABLE_CHAR（已登記、passable=
	#     false），擋死自己，唯有 ignore_passability=true 才能解除
	# 逐格掃描全盤 78 格，驗證每格恰好屬於 A、B\A、C\B、Grid\C 四者之一，
	# 且 A ⊆ B ⊆ C 恆成立
	var board: _BoardWithImpassableTestTerrain = _BoardWithImpassableTestTerrain.new()
	var origin: Vector2i = Vector2i(0, 0)
	var mp: int = 2
	board.set_occupant(Vector2i(0, 1), 99)
	board._terrain[Vector2i(2, 0)] = _BoardWithImpassableTestTerrain.IMPASSABLE_CHAR

	# Act
	var set_a: Dictionary = _to_set_with_origin(board.reachable_tiles(origin, mp, false, false), origin)
	var set_b: Dictionary = _to_set_with_origin(board.reachable_tiles(origin, mp, true, false), origin)
	var set_c: Dictionary = _to_set_with_origin(board.reachable_tiles(origin, mp, true, true), origin)

	# Assert — 逐格掃描，四類恰好各一次，且驗證子集關係 A ⊆ B ⊆ C
	var classified_a: int = 0
	var classified_b_minus_a: int = 0
	var classified_c_minus_b: int = 0
	var classified_grid_minus_c: int = 0
	for x: int in range(Board.BOARD_WIDTH):
		for y: int in range(Board.BOARD_HEIGHT):
			var pos: Vector2i = Vector2i(x, y)
			var in_a: bool = set_a.has(pos)
			var in_b: bool = set_b.has(pos)
			var in_c: bool = set_c.has(pos)
			if in_a:
				classified_a += 1
				assert_bool(in_b).is_true()  # A ⊆ B
				assert_bool(in_c).is_true()  # A ⊆ C（遞移）
			elif in_b:
				classified_b_minus_a += 1
				assert_bool(in_c).is_true()  # B ⊆ C
			elif in_c:
				classified_c_minus_b += 1
			else:
				classified_grid_minus_c += 1

	var total_tiles: int = Board.BOARD_WIDTH * Board.BOARD_HEIGHT
	assert_int(
		classified_a + classified_b_minus_a + classified_c_minus_b + classified_grid_minus_c
	).is_equal(total_tiles)
	assert_int(classified_a).is_equal(3)  # origin + (1,0) + (1,1)
	assert_int(classified_b_minus_a).is_equal(2)  # (0,1) + (0,2)
	assert_int(classified_c_minus_b).is_equal(1)  # (2,0)
	assert_int(classified_grid_minus_c).is_equal(total_tiles - 3 - 2 - 1)


# --- AC #7：有界前緣展開 -----------------------------------------------------

func test_reachable_tiles_bounded_frontier_expansion_visits_more_tiles_as_mp_grows() -> void:
	# Arrange — 全開闊版面（13x6=78 格，_BoardWithVisitCounter 未寫入 _terrain
	# 時各格預設 TERRAIN_OPEN，等同全開闊），origin 為內陸格
	var origin: Vector2i = Vector2i(6, 3)
	var total_tiles: int = Board.BOARD_WIDTH * Board.BOARD_HEIGHT
	var board_mp1: _BoardWithVisitCounter = _BoardWithVisitCounter.new()
	var board_mp3: _BoardWithVisitCounter = _BoardWithVisitCounter.new()

	# Act
	board_mp1.reachable_tiles(origin, 1)
	board_mp3.reachable_tiles(origin, 3)

	# Assert — 造訪節點數應隨 mp 增長而增長，且兩者都遠低於全盤格數，證明
	# 演算法是提前終止的有界展開，不是「全盤展開後再過濾」
	assert_int(board_mp1.visit_count).is_greater(0)
	assert_int(board_mp1.visit_count).is_less(total_tiles)
	assert_int(board_mp3.visit_count).is_greater(board_mp1.visit_count)
	assert_int(board_mp3.visit_count).is_less(total_tiles)
