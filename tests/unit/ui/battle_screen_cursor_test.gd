# BattleScreen（src/ui/battle/battle_screen.gd）唯一被抽出的節點無關純函式的測試：
# clamp_cursor_move()。輸入處理本身（_input()/_process())無法在 headless 下測到
# （引擎不送 InputEvent，見 .claude/docs/coding-standards.md），但方向鍵移動後的
# 夾邊界計算不依賴節點或場景樹，抽成 static 函式後可以在這裡直接測。
#
# 命名慣例依 tests/unit/ui/board_coords_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
extends GdUnitTestSuite


func test_move_within_bounds_applies_delta() -> void:
	# Arrange — 板中央的一格，往右移動應該就是單純加法
	var cell: Vector2i = Vector2i(6, 3)

	# Act
	var result: Vector2i = BattleScreen.clamp_cursor_move(cell, Vector2i.RIGHT)

	# Assert
	assert_vector(result).is_equal(Vector2i(7, 3))


func test_move_left_past_west_edge_clamps_to_zero() -> void:
	# Arrange — 已經在最左欄
	var cell: Vector2i = Vector2i(0, 3)

	# Act
	var result: Vector2i = BattleScreen.clamp_cursor_move(cell, Vector2i.LEFT)

	# Assert
	assert_vector(result).is_equal(Vector2i(0, 3))


func test_move_right_past_east_edge_clamps_to_last_column() -> void:
	# Arrange — 已經在最右欄（BOARD_COLS - 1 = 12）
	var cell: Vector2i = Vector2i(BoardCoords.BOARD_COLS - 1, 2)

	# Act
	var result: Vector2i = BattleScreen.clamp_cursor_move(cell, Vector2i.RIGHT)

	# Assert
	assert_vector(result).is_equal(Vector2i(BoardCoords.BOARD_COLS - 1, 2))


func test_move_up_past_north_edge_clamps_to_zero() -> void:
	# Arrange — 已經在最上一列
	var cell: Vector2i = Vector2i(5, 0)

	# Act
	var result: Vector2i = BattleScreen.clamp_cursor_move(cell, Vector2i.UP)

	# Assert
	assert_vector(result).is_equal(Vector2i(5, 0))


func test_move_down_past_south_edge_clamps_to_last_row() -> void:
	# Arrange — 已經在最下一列（BOARD_ROWS - 1 = 5）
	var cell: Vector2i = Vector2i(5, BoardCoords.BOARD_ROWS - 1)

	# Act
	var result: Vector2i = BattleScreen.clamp_cursor_move(cell, Vector2i.DOWN)

	# Assert
	assert_vector(result).is_equal(Vector2i(5, BoardCoords.BOARD_ROWS - 1))


func test_move_from_corner_toward_center_applies_delta() -> void:
	# Arrange — 左上角往右下方向各移一格，確認不是永遠回傳角落值
	var cell: Vector2i = Vector2i(0, 0)

	# Act
	var result: Vector2i = BattleScreen.clamp_cursor_move(cell, Vector2i.DOWN)

	# Assert
	assert_vector(result).is_equal(Vector2i(0, 1))
