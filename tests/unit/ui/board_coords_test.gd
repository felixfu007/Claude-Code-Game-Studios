# BoardCoords（src/ui/battle/board_coords.gd）的單元測試。
#
# 命名慣例依 tests/unit/gameplay/board/board_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
#
# 視窗尺寸換算（window_to_grid / grid_to_window）刻意不在測試內實際 resize
# 一個真實 Window ——headless 環境下 Window.size 的行為已實測不可靠（探針顯示
# 直接賦值有時會被夾到非預期尺寸），而這正是 BoardCoords 把 transform 設計成
# 參數而不是自己抓場景樹的理由：測試改用 4 組已由
# prototypes/board-render-input-spike-2026-08-27/README.md 實機驗證過的
# `Window.get_final_transform()` 真實數值（480x270 / 960x540 / 1440x810 三種
# 皆 16:9 無黑邊；800x600 為 4:3，會產生黑邊），直接構造成 Transform2D 餵給
# 換算函式——驗證的是 BoardCoords 自己的數學，不是引擎的 resize 行為。
extends GdUnitTestSuite


# 480x270 / 960x540 / 1440x810 / 800x600 四組 canvas->window 變換，數值取自
# 上述 spike README 表格（scale 為對角線縮放，offset 為黑邊位移）。
const WINDOW_TRANSFORMS: Dictionary = {
	"480x270_scale1_no_letterbox": {
		"scale": 1.0,
		"offset": Vector2(0.0, 0.0),
	},
	"960x540_scale2_no_letterbox": {
		"scale": 2.0,
		"offset": Vector2(0.0, 0.0),
	},
	"1440x810_scale3_no_letterbox": {
		"scale": 3.0,
		"offset": Vector2(0.0, 0.0),
	},
	"800x600_scale1_letterboxed": {
		"scale": 1.0,
		"offset": Vector2(160.0, 165.0),
	},
}

# 世界層在四種尺寸下實測皆為 (0,0)（WorldViewportContainer 滿版貼齊畫布原點）。
const WORLD_VIEWPORT_CANVAS_ORIGIN: Vector2 = Vector2(0.0, 0.0)


func _canvas_to_window_transform(entry: Dictionary) -> Transform2D:
	var scale: float = entry["scale"]
	var offset: Vector2 = entry["offset"]
	return Transform2D(Vector2(scale, 0.0), Vector2(0.0, scale), offset)


func _corner_and_center_cells() -> Dictionary:
	return {
		"top_left": Vector2i(0, 0),
		"top_right": Vector2i(BoardCoords.BOARD_COLS - 1, 0),
		"bottom_left": Vector2i(0, BoardCoords.BOARD_ROWS - 1),
		"bottom_right": Vector2i(BoardCoords.BOARD_COLS - 1, BoardCoords.BOARD_ROWS - 1),
		"center": Vector2i(BoardCoords.BOARD_COLS / 2, BoardCoords.BOARD_ROWS / 2),
	}


func test_grid_to_local_and_back_round_trips_for_corners_and_center() -> void:
	# Arrange
	var cells: Dictionary = _corner_and_center_cells()

	# Act & Assert — grid -> local(top-left) -> grid 對每個角與中心都要自洽
	for label: String in cells:
		var cell: Vector2i = cells[label]
		var local_pos: Vector2 = BoardCoords.grid_to_local(cell)
		var round_trip: Vector2i = BoardCoords.local_to_grid(local_pos)
		assert_vector(round_trip).is_equal(cell)


func test_grid_to_local_center_and_back_round_trips_for_corners_and_center() -> void:
	# Arrange
	var cells: Dictionary = _corner_and_center_cells()

	# Act & Assert — grid -> local(格心) -> grid 對每個角與中心都要自洽
	for label: String in cells:
		var cell: Vector2i = cells[label]
		var local_center: Vector2 = BoardCoords.grid_to_local_center(cell)
		var round_trip: Vector2i = BoardCoords.local_to_grid(local_center)
		assert_vector(round_trip).is_equal(cell)


func test_is_in_bounds_accepts_grid_corners_rejects_outside() -> void:
	# Arrange — 無（純查詢常數）

	# Act — 無

	# Assert
	assert_bool(BoardCoords.is_in_bounds(Vector2i(0, 0))).is_true()
	assert_bool(BoardCoords.is_in_bounds(Vector2i(12, 5))).is_true()
	assert_bool(BoardCoords.is_in_bounds(Vector2i(13, 0))).is_false()
	assert_bool(BoardCoords.is_in_bounds(Vector2i(0, 6))).is_false()
	assert_bool(BoardCoords.is_in_bounds(Vector2i(-1, 0))).is_false()


func test_local_pixel_outside_board_bounds_maps_to_out_of_bounds_cell() -> void:
	# Arrange — 棋盤原點是 (32, 39)，畫布左上角 (0,0) 落在棋盤外（棋盤外圈邊界之外）
	var outside_local_pos: Vector2 = Vector2(0.0, 0.0)

	# Act
	var cell: Vector2i = BoardCoords.local_to_grid(outside_local_pos)

	# Assert
	assert_bool(BoardCoords.is_in_bounds(cell)).is_false()


func test_window_to_grid_and_back_round_trips_for_every_measured_window_size() -> void:
	# Arrange — 四組 spike 實測過的 canvas->window 變換,涵蓋四角+中心 = 20 次來回換算
	var cells: Dictionary = _corner_and_center_cells()

	# Act & Assert
	for size_label: String in WINDOW_TRANSFORMS:
		var canvas_to_window: Transform2D = _canvas_to_window_transform(WINDOW_TRANSFORMS[size_label])
		var window_to_canvas: Transform2D = canvas_to_window.affine_inverse()

		for cell_label: String in cells:
			var cell: Vector2i = cells[cell_label]
			var window_pos: Vector2 = BoardCoords.grid_to_window(
				cell, canvas_to_window, WORLD_VIEWPORT_CANVAS_ORIGIN
			)
			var round_trip: Vector2i = BoardCoords.window_to_grid(
				window_pos, window_to_canvas, WORLD_VIEWPORT_CANVAS_ORIGIN
			)
			assert_vector(round_trip).is_equal(cell)


func test_window_to_grid_letterbox_corner_is_out_of_bounds() -> void:
	# Arrange — 800x600(4:3)在 aspect="keep" 下會產生黑邊,視窗物理座標 (0,0)
	# 落在黑邊裡。數值與 spike README 的黑邊探測一致（basecanvas=(-160,-165)）。
	var entry: Dictionary = WINDOW_TRANSFORMS["800x600_scale1_letterboxed"]
	var canvas_to_window: Transform2D = _canvas_to_window_transform(entry)
	var window_to_canvas: Transform2D = canvas_to_window.affine_inverse()

	# Act
	var cell: Vector2i = BoardCoords.window_to_grid(
		Vector2.ZERO, window_to_canvas, WORLD_VIEWPORT_CANVAS_ORIGIN
	)

	# Assert
	assert_bool(BoardCoords.is_in_bounds(cell)).is_false()


func test_window_to_grid_960x540_center_of_window_maps_to_board_center_cell() -> void:
	# Arrange — 960x540 是 480x270 的整數 2 倍、無黑邊,視窗正中央理當落在棋盤附近
	# 的格子内,可與 grid_to_window 算出的同一格互相印證（非黑邊情境下的健全性檢查）。
	var entry: Dictionary = WINDOW_TRANSFORMS["960x540_scale2_no_letterbox"]
	var canvas_to_window: Transform2D = _canvas_to_window_transform(entry)
	var window_to_canvas: Transform2D = canvas_to_window.affine_inverse()
	var center_cell: Vector2i = Vector2i(BoardCoords.BOARD_COLS / 2, BoardCoords.BOARD_ROWS / 2)

	# Act
	var window_pos: Vector2 = BoardCoords.grid_to_window(
		center_cell, canvas_to_window, WORLD_VIEWPORT_CANVAS_ORIGIN
	)
	var cell: Vector2i = BoardCoords.window_to_grid(
		window_pos, window_to_canvas, WORLD_VIEWPORT_CANVAS_ORIGIN
	)

	# Assert
	assert_vector(cell).is_equal(center_cell)
	assert_bool(BoardCoords.is_in_bounds(cell)).is_true()
