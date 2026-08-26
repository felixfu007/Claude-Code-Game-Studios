# Board（src/gameplay/board/board.gd）的單元測試。
#
# ⚠️ 命名慣例注意：本檔函式名依既有範本 tests/unit/core/display_pixel_settings_test.gd
# 的 test_[scenario]_[expected] 慣例撰寫（該檔本身也記載了與
# .claude/rules/test-standards.md 的 test_[system]_[scenario]_[expected_result]
# 不一致，選用前者是因為它是最直接的先例）。這個不一致不在本次任務範圍內裁決。
extends GdUnitTestSuite


# 建一份全開闊（13x6，全 '.'）的 ascii 版面，供多個測試共用起點。
func _build_open_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for _y: int in range(Board.BOARD_HEIGHT):
		rows.append(".............")
	return rows


func test_from_ascii_parses_terrain_cost_and_sight_blocking() -> void:
	# Arrange — 用規格給的 vs01 版面：中央 2x2 是倒木（#），外圈一圈灌木（,）
	var rows: PackedStringArray = PackedStringArray([
		".............",
		".....,,......",
		"....,##,.....",
		"....,##,.....",
		".....,,......",
		".............",
	])
	var board: Board = Board.from_ascii(rows)

	# Act — 無（純查詢）

	# Assert
	assert_str(board.get_terrain(Vector2i(0, 0))).is_equal(".")
	assert_int(board.get_move_cost(Vector2i(0, 0))).is_equal(1)
	assert_bool(board.blocks_sight(Vector2i(0, 0))).is_false()

	assert_str(board.get_terrain(Vector2i(5, 1))).is_equal(",")
	assert_int(board.get_move_cost(Vector2i(5, 1))).is_equal(2)
	assert_bool(board.blocks_sight(Vector2i(5, 1))).is_false()

	assert_str(board.get_terrain(Vector2i(5, 2))).is_equal("#")
	assert_int(board.get_move_cost(Vector2i(5, 2))).is_equal(3)
	assert_bool(board.blocks_sight(Vector2i(5, 2))).is_true()


func test_from_ascii_loads_vs01_terrain_file_without_crashing() -> void:
	# Arrange — 讀實際會放在 assets/data/levels 的關卡地形檔
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

	# Act
	var board: Board = Board.from_ascii(rows)

	# Assert — 中心倒木格判讀正確即可，代表整檔載入路徑沒問題
	assert_int(board.get_move_cost(Vector2i(5, 2))).is_equal(3)
	assert_bool(board.blocks_sight(Vector2i(5, 2))).is_true()


func test_is_in_bounds_accepts_grid_corners_rejects_outside() -> void:
	# Arrange
	var board: Board = Board.from_ascii(_build_open_rows())

	# Act — 無（純查詢）

	# Assert
	assert_bool(board.is_in_bounds(Vector2i(0, 0))).is_true()
	assert_bool(board.is_in_bounds(Vector2i(12, 5))).is_true()
	assert_bool(board.is_in_bounds(Vector2i(13, 0))).is_false()
	assert_bool(board.is_in_bounds(Vector2i(0, 6))).is_false()
	assert_bool(board.is_in_bounds(Vector2i(-1, 0))).is_false()


func test_occupant_set_clear_and_query_round_trip() -> void:
	# Arrange
	var board: Board = Board.from_ascii(_build_open_rows())
	var pos: Vector2i = Vector2i(3, 3)

	# Act & Assert — 空格
	assert_bool(board.has_occupant(pos)).is_false()
	assert_int(board.get_occupant(pos)).is_equal(Board.NO_OCCUPANT)

	# Act & Assert — 設定佔位
	board.set_occupant(pos, 7)
	assert_bool(board.has_occupant(pos)).is_true()
	assert_int(board.get_occupant(pos)).is_equal(7)

	# Act & Assert — 清除佔位
	board.clear_occupant(pos)
	assert_bool(board.has_occupant(pos)).is_false()
	assert_int(board.get_occupant(pos)).is_equal(Board.NO_OCCUPANT)


func test_reachable_tiles_open_terrain_interior_origin_mp2_returns_12_tiles() -> void:
	# Arrange — 全開闊版面，起點在內陸（四個方向距邊界都 >= 2），
	# 曼哈頓距離 <= 2 且不含起點的格子數應為 4（距離1）+ 8（距離2）= 12
	var board: Board = Board.from_ascii(_build_open_rows())
	var origin: Vector2i = Vector2i(6, 3)

	# Act
	var reachable: Array[Vector2i] = board.reachable_tiles(origin, 2)

	# Assert
	assert_array(reachable).has_size(12)
	assert_bool(reachable.has(origin)).is_false()
	assert_bool(reachable.has(Vector2i(6, 1))).is_true()  # 正上方距離2
	assert_bool(reachable.has(Vector2i(8, 3))).is_true()  # 正右方距離2
	assert_bool(reachable.has(Vector2i(7, 4))).is_true()  # 斜向距離2
	assert_bool(reachable.has(Vector2i(6, 0))).is_false()  # 距離3，超出 mp


func test_reachable_tiles_brush_terrain_shrinks_reachable_set() -> void:
	# Arrange — 與上一個測試相同的起點與 mp，但把起點正右方一格（7,3）
	# 換成灌木（成本2），使得原本 cost=2 可達的 (8,3) 變成不可達
	var rows: PackedStringArray = PackedStringArray([
		".............",
		".............",
		".............",
		".......,.....",
		".............",
		".............",
	])
	var board: Board = Board.from_ascii(rows)
	var origin: Vector2i = Vector2i(6, 3)

	# Act
	var reachable: Array[Vector2i] = board.reachable_tiles(origin, 2)

	# Assert — 灌木格本身（cost2）仍可達，但原本經它才到得了的下一格不再可達，
	# 整體可達格數應少於全開闊版面的 12 格
	assert_bool(reachable.has(Vector2i(7, 3))).is_true()
	assert_bool(reachable.has(Vector2i(8, 3))).is_false()
	assert_int(reachable.size()).is_less(12)


func test_reachable_tiles_occupied_tile_blocks_only_path() -> void:
	# Arrange — 起點在角落 (0,0)，唯一能以 mp=2 到達 (0,2) 的路徑是直線經過
	# (0,1)；把 (0,1) 佔位後，(0,1) 與 (0,2) 都應從可達集合消失
	var board: Board = Board.from_ascii(_build_open_rows())
	var origin: Vector2i = Vector2i(0, 0)
	board.set_occupant(Vector2i(0, 1), 42)

	# Act
	var reachable: Array[Vector2i] = board.reachable_tiles(origin, 2)

	# Assert
	assert_bool(reachable.has(Vector2i(0, 1))).is_false()  # 佔位格本身不可達
	assert_bool(reachable.has(Vector2i(0, 2))).is_false()  # 唯一通路被擋
	assert_bool(reachable.has(Vector2i(1, 0))).is_true()
	assert_bool(reachable.has(Vector2i(2, 0))).is_true()
	assert_bool(reachable.has(Vector2i(1, 1))).is_true()
	assert_array(reachable).has_size(3)


func test_reachable_tiles_out_of_bounds_origin_returns_empty_without_crashing() -> void:
	# Arrange
	var board: Board = Board.from_ascii(_build_open_rows())

	# Act
	var reachable_negative: Array[Vector2i] = board.reachable_tiles(Vector2i(-1, -1), 3)
	var reachable_too_large: Array[Vector2i] = board.reachable_tiles(Vector2i(99, 99), 3)

	# Assert
	assert_array(reachable_negative).is_empty()
	assert_array(reachable_too_large).is_empty()
