extends GdUnitTestSuite
## story-053 AC4:第三顆按鈕(結束角色行動)的矩形與提示列可用寬度。
## 檔案存取(登記例外①,唯讀):讀 assets/data/units/vs01_roster.txt 取單位起始格(欄位 9、10),
## 不證明窮盡 —— 只涵蓋 vs01 名冊的起始格,不涵蓋戰鬥中移動後的位置。

const _WINDOWS: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const _TEXT: String = "結束角色行動"
const _ROSTER_PATH: String = "res://assets/data/units/vs01_roster.txt"


func test_third_button_does_not_intersect_the_other_two() -> void:
	for ws: Vector2i in _WINDOWS:
		var r2: Rect2 = HudLayout.hud_action_button_rect(ws, HudLayout.END_ACTION_BUTTON_INDEX)
		for i: int in [0, 1]:
			assert_bool(r2.intersects(HudLayout.hud_action_button_rect(ws, i))).append_failure_message("%s index %d" % [ws, i]).is_false()
		var bar: Rect2 = HudLayout.controls_hint_bg_rect(ws)
		assert_bool(bar.encloses(r2)).append_failure_message("%s 按鈕應在說明列內" % ws).is_true()


func test_existing_two_buttons_keep_five_em_width() -> void:
	for ws: Vector2i in _WINDOWS:
		var fpx: float = float(HudLayout.font_size(ws))
		assert_float(HudLayout.hud_action_button_rect(ws, 0).size.x).is_equal(fpx * 5.0)
		assert_float(HudLayout.hud_action_button_rect(ws, 1).size.x).is_equal(fpx * 5.0)


func test_text_fits_inside_button_rect_with_real_hud_font() -> void:
	for ws: Vector2i in _WINDOWS:
		var fpx: int = HudLayout.font_size(ws)
		var w: float = HudLayoutScaler.HUD_FONT.get_string_size(_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
		var rect: Rect2 = HudLayout.hud_action_button_rect(ws, HudLayout.END_ACTION_BUTTON_INDEX)
		print("MEASURED end_action text width ws=%s fpx=%d text=%.1f rect=%.1f em=%.3f" % [ws, fpx, w, rect.size.x, w / float(fpx)])
		assert_float(w).append_failure_message("%s 文字 %.1f 應 ≤ 矩形 %.1f 扣兩側外框" % [ws, w, rect.size.x]).is_less_equal(
			rect.size.x - 2.0 * float(BattleScreen.HUD_BUTTON_BORDER_WIDTH))


func test_compact_hint_available_width_ends_at_leftmost_button() -> void:
	for ws: Vector2i in _WINDOWS:
		var bar: Rect2 = HudLayout.controls_hint_bg_rect(ws)
		var leftmost: float = INF
		for i: int in [0, 1, HudLayout.END_ACTION_BUTTON_INDEX]:
			leftmost = minf(leftmost, HudLayout.hud_action_button_rect(ws, i).position.x)
		var expected: float = leftmost - bar.position.x - HudLayout.COMPACT_HINT_LABEL_INSET_PX
		assert_float(HudLayout.compact_hint_available_width(ws)).is_equal(expected)


func test_sensitivity_proof_old_formula_would_draw_text_under_button() -> void:
	# 舊寫法(只扣到 index 1 左緣)的寬度會大於「到最左按鈕左緣」的寬度 → 文字會畫到第三顆底下。
	for ws: Vector2i in _WINDOWS:
		var bar: Rect2 = HudLayout.controls_hint_bg_rect(ws)
		var old_w: float = HudLayout.hud_action_button_rect(ws, 1).position.x - bar.position.x - HudLayout.COMPACT_HINT_LABEL_INSET_PX
		assert_float(old_w).is_greater(HudLayout.compact_hint_available_width(ws))


func test_third_button_does_not_cover_any_start_cell() -> void:
	var cells: Array[Vector2i] = []
	for line: String in FileAccess.get_file_as_string(_ROSTER_PATH).split("\n"):
		var t: String = line.strip_edges()
		if t == "" or t.begins_with("#"):
			continue
		var f: PackedStringArray = t.split(",")
		if f.size() >= 11 and f[9].is_valid_int() and f[10].is_valid_int():
			cells.append(Vector2i(int(f[9]), int(f[10])))
	assert_int(cells.size()).append_failure_message("PRECONDITION: 解析出起始格").is_greater(0)
	for ws: Vector2i in _WINDOWS:
		var r: Rect2 = HudLayout.hud_action_button_rect(ws, HudLayout.END_ACTION_BUTTON_INDEX)
		for c: Vector2i in cells:
			assert_bool(HudLayout.cell_overlaps_frame(HudLayout.cell_window_rect(c, ws), r)).append_failure_message(
				"%s 格 %s 被第三顆蓋到" % [ws, c]).is_false()
