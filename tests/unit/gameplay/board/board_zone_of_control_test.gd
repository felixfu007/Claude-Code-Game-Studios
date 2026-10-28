# Board.reachable_tiles() 的 stop_cells(阻擋區)與 Board.path_to() 單元測試。
# 來源:2026-10-28 管理者試玩回饋「敵方不可穿越我方腳色移動」,選項「兩個都做」
# (阻擋規則 + 逐格移動動畫)。阻擋區格子由 BattleState.zone_of_control_cells() 算出,
# 本檔只測 Board 層:可以走進阻擋格,但不能從那裡再往外走;起點不受限。
#
# ⚠️ 命名慣例:沿用 board_test.gd 的 test_[scenario]_[expected]。
extends GdUnitTestSuite


func _build_open_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for _y: int in range(Board.BOARD_HEIGHT):
		rows.append(".............")
	return rows


func test_stop_cell_can_be_entered_but_not_passed_through() -> void:
	# Arrange — 一排直線:起點 (0,0),阻擋格 (1,0),MP 3
	var board: Board = Board.from_ascii(_build_open_rows())
	var stop_cells: Dictionary = {Vector2i(1, 0): true}

	# Act
	var reach: Array[Vector2i] = board.reachable_tiles(Vector2i(0, 0), 3, false, false, stop_cells)

	# Assert
	assert_bool(reach.has(Vector2i(1, 0))).append_failure_message("阻擋格本身應可走進").is_true()
	assert_bool(reach.has(Vector2i(2, 0))).append_failure_message(
		"(2,0) 只能經由阻擋格 (1,0) 在 2 步內到達(繞路要 4 步 > MP 3),應不可達"
	).is_false()


func test_without_stop_cells_the_same_tile_is_reachable() -> void:
	# Arrange — 對照組:同一盤面不給阻擋格
	var board: Board = Board.from_ascii(_build_open_rows())

	# Act
	var reach: Array[Vector2i] = board.reachable_tiles(Vector2i(0, 0), 3)

	# Assert
	assert_bool(reach.has(Vector2i(2, 0))).is_true()


func test_unit_starting_inside_a_stop_cell_can_still_leave() -> void:
	# Arrange — 起點本身就在阻擋區
	var board: Board = Board.from_ascii(_build_open_rows())
	var stop_cells: Dictionary = {Vector2i(5, 3): true}

	# Act
	var reach: Array[Vector2i] = board.reachable_tiles(Vector2i(5, 3), 2, false, false, stop_cells)

	# Assert
	assert_bool(reach.has(Vector2i(7, 3))).is_true()


func test_path_to_lists_each_cell_from_first_step_to_destination() -> void:
	# Arrange
	var board: Board = Board.from_ascii(_build_open_rows())

	# Act
	var path: Array[Vector2i] = board.path_to(Vector2i(0, 0), Vector2i(3, 0), 5)

	# Assert
	assert_array(path).contains_exactly([Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])


func test_path_to_detours_around_a_stop_cell() -> void:
	# Arrange — 直線上的 (1,0) 是阻擋格,路線必須繞開它(不能經過後繼續走)
	var board: Board = Board.from_ascii(_build_open_rows())
	var stop_cells: Dictionary = {Vector2i(1, 0): true}

	# Act
	var path: Array[Vector2i] = board.path_to(Vector2i(0, 0), Vector2i(2, 0), 6, stop_cells)

	# Assert
	assert_bool(path.has(Vector2i(1, 0))).is_false()
	assert_that(path.back()).is_equal(Vector2i(2, 0))
	assert_int(path.size()).is_equal(4)


func test_path_to_unreachable_destination_is_empty() -> void:
	# Arrange
	var board: Board = Board.from_ascii(_build_open_rows())

	# Act
	var path: Array[Vector2i] = board.path_to(Vector2i(0, 0), Vector2i(12, 5), 3)

	# Assert
	assert_array(path).is_empty()
