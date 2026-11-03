extends GdUnitTestSuite

# battle-hud story-004 AC1 / AC3 / AC4 的純函式與結構斷言(不進場景樹)。
# 檔案存取:無(不屬甲/乙類例外)。
# 敏感度:HudLayout 的 static 函式沒有繼承鏈可覆寫(test-standards 敏感度證明 A 類,
# 證明不了);改以常駐 test_sensitivity_proof_* 證明「測試夾具分得出缺陷版偵測器」:
# 缺陷版只看格子左上角點 / 把邊緣相接當重疊。手動注入記錄在交付回報。

const _SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const _MIN_WINDOW: Vector2i = Vector2i(960, 540)


# ---- AC1:重疊判斷 --------------------------------------------------------------------

func test_overlap_detects_cell_inside_frame() -> void:
	var frame: Rect2 = Rect2(100, 100, 200, 50)
	assert_bool(HudLayout.cell_overlaps_frame(Rect2(120, 110, 32, 32), frame)).is_true()


func test_overlap_detects_partial_overlap_at_frame_edge() -> void:
	var frame: Rect2 = Rect2(100, 100, 200, 50)
	assert_bool(HudLayout.cell_overlaps_frame(Rect2(90, 90, 32, 32), frame)).is_true()


func test_overlap_false_when_cell_is_apart_or_only_touches_edge() -> void:
	var frame: Rect2 = Rect2(100, 100, 200, 50)
	assert_bool(HudLayout.cell_overlaps_frame(Rect2(400, 400, 32, 32), frame)).is_false()
	assert_bool(HudLayout.cell_overlaps_frame(Rect2(68, 100, 32, 32), frame)).append_failure_message(
		"邊緣相接不算重疊").is_false()


func test_frame_alpha_is_fade_value_only_when_overlapping_and_has_cell() -> void:
	var frame: Rect2 = Rect2(100, 100, 200, 50)
	var over: Rect2 = Rect2(120, 110, 32, 32)
	assert_float(HudLayout.frame_alpha_for_cell(true, over, frame)).is_equal(HudLayout.OVERLAP_FADE_ALPHA)
	assert_float(HudLayout.frame_alpha_for_cell(true, Rect2(500, 500, 32, 32), frame)).is_equal(1.0)
	assert_float(HudLayout.frame_alpha_for_cell(false, over, frame)).is_equal(1.0)


func test_fade_alpha_within_spec_range() -> void:
	assert_float(HudLayout.OVERLAP_FADE_ALPHA).is_between(0.3, 0.4)


func test_cell_window_rect_matches_board_coords_grid_to_window_center() -> void:
	for size: Vector2i in _SIZES + [_MIN_WINDOW]:
		for cell: Vector2i in [Vector2i(0, 0), Vector2i(12, 5), Vector2i(6, 3)]:
			var rect: Rect2 = HudLayout.cell_window_rect(cell, size)
			var center: Vector2 = BoardCoords.grid_to_window(
				cell, WorldLayout.canvas_to_window_transform(size), Vector2.ZERO)
			assert_vector(rect.get_center()).append_failure_message("%s %s" % [size, cell]).is_equal_approx(center, Vector2(0.01, 0.01))


func test_bottom_left_cell_overlaps_counter_and_bottom_row_overlaps_hint_bar_where_expected() -> void:
	# 1080p:左上角格子在左上計數框之下(棋盤滿版),最下列不碰說明列(AC4)。
	var size: Vector2i = Vector2i(1920, 1080)
	var counter: Rect2 = HudLayout.consistency_counter_rect(size)
	var top_left_cell: Rect2 = HudLayout.cell_window_rect(Vector2i(0, 0), size)
	assert_bool(HudLayout.cell_overlaps_frame(top_left_cell, counter)).is_true()
	var far_cell: Rect2 = HudLayout.cell_window_rect(Vector2i(12, 5), size)
	assert_bool(HudLayout.cell_overlaps_frame(far_cell, counter)).is_false()


func test_sensitivity_proof_point_only_detector_misses_partial_overlap() -> void:
	# 缺陷版:只看格子左上角點。部分重疊的案例會被它漏掉,而真函式抓得到。
	var frame: Rect2 = Rect2(100, 100, 200, 50)
	var cell: Rect2 = Rect2(90, 90, 32, 32)
	assert_bool(frame.has_point(cell.position)).is_false()
	assert_bool(HudLayout.cell_overlaps_frame(cell, frame)).is_true()


func test_sensitivity_proof_edge_touch_counted_as_overlap_by_inclusive_detector() -> void:
	# 缺陷版:把邊緣相接也算重疊(intersects(…, true))。真函式判為不重疊。
	var frame: Rect2 = Rect2(100, 100, 200, 50)
	var cell: Rect2 = Rect2(68, 100, 32, 32)
	assert_bool(cell.intersects(frame, true)).is_true()
	assert_bool(HudLayout.cell_overlaps_frame(cell, frame)).is_false()


# ---- AC3:單行 ---------------------------------------------------------------------------

func test_hint_bar_is_single_line_at_every_scale() -> void:
	for size: Vector2i in _SIZES + [_MIN_WINDOW, Vector2i(1280, 720), Vector2i(1366, 768)]:
		assert_bool(HudLayout.is_compact_hint_bar(size)).append_failure_message("%s" % size).is_true()
		var fpx: float = float(HudLayout.font_size(size))
		assert_float(HudLayout.controls_hint_bg_rect(size).size.y).is_equal_approx(
			fpx * HudLayout.COMPACT_HINT_BG_HEIGHT_MULTIPLIER, 0.01)


func test_compact_hint_text_has_no_newline_and_fits_at_big_sizes() -> void:
	var full: String = Loc.localize(BattleScreen.TEXT_CONTROLS_HINT)
	for size: Vector2i in _SIZES:
		var text: String = HudLayout.compact_hint_text(full, size)
		assert_bool(text.is_empty() or text.contains("\n")).is_false()
		var width: float = HudLayoutScaler.HUD_FONT.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, HudLayout.font_size(size)).x
		assert_float(width).is_less_equal(HudLayout.compact_hint_available_width(size))


# ---- AC4:說明列不蓋棋盤最下一列 -----------------------------------------------------------

func test_hint_bar_does_not_overlap_any_bottom_row_cell_at_three_big_sizes() -> void:
	for size: Vector2i in _SIZES:
		var bar: Rect2 = HudLayout.controls_hint_bg_rect(size)
		for col: int in range(BoardCoords.BOARD_COLS):
			var cell: Rect2 = HudLayout.cell_window_rect(Vector2i(col, BoardCoords.BOARD_ROWS - 1), size)
			assert_bool(HudLayout.cell_overlaps_frame(cell, bar)).append_failure_message(
				"%s 說明列 %s 蓋到最下列第 %d 格 %s" % [size, bar, col, cell]).is_false()


func test_sensitivity_proof_two_line_bar_would_overlap_bottom_row_at_1080p() -> void:
	# 缺陷版:仍用兩行高度(3.2 倍)。AC4 的偵測器必須抓到蓋住。
	var size: Vector2i = Vector2i(1920, 1080)
	var safe: Rect2 = HudLayout.safe_rect(size)
	var h: float = float(HudLayout.font_size(size)) * HudLayout.CONTROLS_HINT_BG_HEIGHT_MULTIPLIER
	var bad_bar: Rect2 = Rect2(safe.position.x, safe.end.y - h, safe.size.x, h)
	var any: bool = false
	for col: int in range(BoardCoords.BOARD_COLS):
		if HudLayout.cell_overlaps_frame(HudLayout.cell_window_rect(Vector2i(col, BoardCoords.BOARD_ROWS - 1), size), bad_bar):
			any = true
	assert_bool(any).is_true()
