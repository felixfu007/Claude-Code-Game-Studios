# LineOfSight 單元測試
#
# 對應 src/gameplay/board/line_of_sight.gd 與 design/gdd/tactical-combat-system.md
# 的視線判定規則。本模組完全不認識棋盤，occlusion 一律透過測試自建的
# Callable（用 Dictionary[Vector2i, bool] 當假資料）餵入 — 不 mock 任何節點，
# 不建立任何 Node，符合 LineOfSight 本身「不建節點」的限制。
#
# 命名慣例：依任務指示仿 tests/unit/core/display_pixel_settings_test.gd 的
# test_[scenario]_[expected] 寫法（不含 [system] 前綴）。
extends GdUnitTestSuite


## 建立一個 is_occluding Callable，回報 occluded_cells 裡列出的格子為遮蔽、
## 其餘一律不遮蔽。
func _occluder(occluded_cells: Array[Vector2i]) -> Callable:
	var occluded: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in occluded_cells:
		occluded[cell] = true
	return func(cell: Vector2i) -> bool:
		return occluded.get(cell, false)


func test_horizontal_ray_blocked_by_middle_cell() -> void:
	# Arrange — 同列水平射線，中間一格 (1,0) 遮蔽
	var is_occluding: Callable = _occluder([Vector2i(1, 0)])

	# Act
	var result: bool = LineOfSight.is_clear(Vector2i(0, 0), Vector2i(3, 0), is_occluding)

	# Assert
	assert_bool(result).is_false()


func test_horizontal_ray_all_clear() -> void:
	# Arrange — 同列水平射線，沿線沒有任何遮蔽格
	var is_occluding: Callable = _occluder([])

	# Act
	var result: bool = LineOfSight.is_clear(Vector2i(0, 0), Vector2i(3, 0), is_occluding)

	# Assert
	assert_bool(result).is_true()


func test_diagonal_corner_blocked_when_both_sides_occlude() -> void:
	# Arrange — (0,0) 到 (1,1) 恰好穿過角點 (0.5,0.5)，兩側格 (1,0) 與 (0,1) 都遮蔽
	var is_occluding: Callable = _occluder([Vector2i(1, 0), Vector2i(0, 1)])

	# Act
	var result: bool = LineOfSight.is_clear(Vector2i(0, 0), Vector2i(1, 1), is_occluding)

	# Assert
	assert_bool(result).is_false()


func test_diagonal_corner_clear_when_only_one_side_occludes() -> void:
	# Arrange — 同一條對角射線，兩側格只有 (1,0) 遮蔽，(0,1) 不遮蔽
	var is_occluding: Callable = _occluder([Vector2i(1, 0)])

	# Act
	var result: bool = LineOfSight.is_clear(Vector2i(0, 0), Vector2i(1, 1), is_occluding)

	# Assert
	assert_bool(result).is_true()


func test_adjacent_cells_always_clear() -> void:
	# Arrange — 曼哈頓距離 1（正交相鄰），沒有中繼格，理論上不會查詢任何遮蔽格。
	# 用一個永遠回報 true 的 is_occluding 來證明它從未被呼叫到會影響結果的格子上。
	var is_occluding: Callable = func(_cell: Vector2i) -> bool:
		return true

	# Act
	var result: bool = LineOfSight.is_clear(Vector2i(2, 2), Vector2i(3, 2), is_occluding)

	# Assert
	assert_bool(result).is_true()


func test_same_cell_is_clear() -> void:
	# Arrange
	var is_occluding: Callable = func(_cell: Vector2i) -> bool:
		return true

	# Act
	var result: bool = LineOfSight.is_clear(Vector2i(5, 5), Vector2i(5, 5), is_occluding)

	# Assert
	assert_bool(result).is_true()


func test_result_is_symmetric_for_forward_and_reverse_query() -> void:
	# Arrange — 混合斜率射線（2:1），中間依序經過 (1,0) 與 (1,1) 兩個普通格，
	# 不經過任何角點；只讓 (1,1) 遮蔽。
	var is_occluding: Callable = _occluder([Vector2i(1, 1)])
	var from: Vector2i = Vector2i(0, 0)
	var to: Vector2i = Vector2i(2, 1)

	# Act
	var forward: bool = LineOfSight.is_clear(from, to, is_occluding)
	var reverse: bool = LineOfSight.is_clear(to, from, is_occluding)

	# Assert
	assert_bool(forward).is_false()
	assert_bool(reverse).is_equal(forward)


func test_shallow_diagonal_checks_both_intermediate_cells_when_clear() -> void:
	# Arrange — 同一條 2:1 射線，完全不遮蔽，驗證普通格合併邏輯本身不會誤擋。
	var is_occluding: Callable = _occluder([])

	# Act
	var result: bool = LineOfSight.is_clear(Vector2i(0, 0), Vector2i(2, 1), is_occluding)

	# Assert
	assert_bool(result).is_true()
