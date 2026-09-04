# HudLayout（src/ui/battle/hud_layout.gd）的單元測試。
#
# 覆蓋 story-002-adaptive-font-scale.md 的三條可自動驗的驗收標準：
#   - AC-S002-a（規則存在且可套用）：四種螢幕各得到一個明確數值，沒有現場判斷。
#   - AC-S002-b（點陣字整數倍）：四種螢幕的 HUD 字級皆為 Cubic 11 (11px) 的整數倍，
#     且與 WorldLayout.compute_scale() 同一個 N —— 不是另一份巧合相符的公式。
#   - AC-S002-c（不超出安全區）：safe_rect() 逐字對應規格自己的範例
#     （2560x1440 -> 2304x1296 置中），且六個既有元件的 rect 落在安全區內。
#
# 另外覆蓋規格「範圍擴充」節要求的 6 個既有元件座標退化修法，逐一以
# prototypes/story-002-font-scale-spike-2026-09-04/logs/font_scale_probe_output.txt
# 的真實 Font.get_string_size() 量測數字為回歸基準（A_board_locked 候選）：
# 每個節點的 rect 寬高都必須容得下該解析度真實會渲染出的文字，不只是「有算出
# 一個數字」。
#
# 純函式測試，不碰場景樹、不需要真實視窗 — 與 world_layout_test.gd 同一慣例。
#
# 命名慣例依 tests/unit/ui/world_layout_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
extends GdUnitTestSuite


# AC-S002-a/b/c 明文列舉的四種螢幕。
const RESOLUTIONS: Dictionary = {
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2560, 1440),
	"4K": Vector2i(3840, 2160),
	"ultrawide": Vector2i(3440, 1440),
}

# design/art/screen-architecture.md 裁決表 / world_layout_test.gd 同一組 N 值，
# 乘以 HudLayout.GLYPH_PX (11) 得到 A 案字級。
const EXPECTED_FONT_PX: Dictionary = {
	"1080p": 44,
	"2K": 55,
	"4K": 88,
	"ultrawide": 55,
}

# 額外含最小視窗 960x540（Story 001 裁決的邊界，N=2）——四個規格明文列舉的解析度
# 之外，這是本張兩份文件都拿它當「最容易撐爆」情境的一格。
const RESOLUTIONS_WITH_MIN_WINDOW: Dictionary = {
	"960x540": Vector2i(960, 540),
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2560, 1440),
	"4K": Vector2i(3840, 2160),
	"ultrawide": Vector2i(3440, 1440),
}

# prototypes/story-002-font-scale-spike-2026-09-04/logs/font_scale_probe_output.txt
# 的 A_board_locked 候選、真實 Font.get_string_size() 量測（960x540/1080p/2K/
# 4K/ultrawide 五列，寬度單位 px）。ultrawide 與 2K 同 N=5，量測數字相同。
const MEASURED_STATUS_WIDTH: Dictionary = {
	"960x540": 229.0, "1080p": 458.0, "2K": 573.0, "4K": 917.0, "ultrawide": 573.0,
}
const MEASURED_INFO_WIDTH: Dictionary = {
	"960x540": 267.0, "1080p": 535.0, "2K": 669.0, "4K": 1071.0, "ultrawide": 669.0,
}
const MEASURED_CONTROLS_HINT_WIDTH: Dictionary = {
	"960x540": 686.0, "1080p": 1375.0, "2K": 1718.0, "4K": 2750.0, "ultrawide": 1718.0,
}
const MEASURED_RESULT_WIDTH: Dictionary = {
	"960x540": 48.0, "1080p": 95.0, "2K": 119.0, "4K": 191.0, "ultrawide": 119.0,
}
const MEASURED_LINE_HEIGHT: Dictionary = {
	"960x540": 27.0, "1080p": 52.0, "2K": 65.0, "4K": 104.0, "ultrawide": 65.0,
}

# ControlsHintLabel 在 BattleScreen.tscn 裡相對 ControlsHintBg 的內縮
# （offset_left=4, offset_right=-4，見 .tscn），量測寬度必須留出這個內縮空間。
const CONTROLS_HINT_LABEL_INSET_PX: float = 8.0


# ─── AC-S002-a: 規則存在且可套用（沒有現場判斷）───────────────────────────


func test_font_size_matches_expected_value_at_every_defined_resolution() -> void:
	for label: String in RESOLUTIONS:
		var font_px: int = HudLayout.font_size(RESOLUTIONS[label])
		assert_int(font_px).append_failure_message(
			"%s (%s): expected font_px %d, got %d" % [
				label, RESOLUTIONS[label], EXPECTED_FONT_PX[label], font_px
			]
		).is_equal(EXPECTED_FONT_PX[label])


# ─── AC-S002-b: 點陣字整數倍 —— 且與 WorldLayout 同一個 N，不是另一份公式 ──


func test_font_size_is_integer_multiple_of_glyph_px_at_every_defined_resolution() -> void:
	for label: String in RESOLUTIONS:
		var font_px: int = HudLayout.font_size(RESOLUTIONS[label])
		assert_int(font_px % HudLayout.GLYPH_PX).append_failure_message(
			"%s: font_px %d is not an integer multiple of GLYPH_PX %d" % [
				label, font_px, HudLayout.GLYPH_PX
			]
		).is_equal(0)


# 這是「必須直接呼叫 world_layout.gd,不得複製一份公式」這條紀律唯一驗得到的
# 地方 —— 兩份巧合相符的公式在這條測試下無法通過:任何一邊的 N 算法只要漂移，
# 這條就會紅。
func test_font_size_equals_glyph_px_times_world_layout_compute_scale() -> void:
	for label: String in RESOLUTIONS_WITH_MIN_WINDOW:
		var window_size: Vector2i = RESOLUTIONS_WITH_MIN_WINDOW[label]
		var expected: int = HudLayout.GLYPH_PX * WorldLayout.compute_scale(window_size)
		assert_int(HudLayout.font_size(window_size)).append_failure_message(
			"%s: HudLayout.font_size() = %d does not equal GLYPH_PX * WorldLayout.compute_scale() = %d — the single source of truth has diverged" % [
				label, HudLayout.font_size(window_size), expected
			]
		).is_equal(expected)


# ─── AC-S002-c: 不超出安全區 ───────────────────────────────────────────────


func test_safe_rect_matches_ac_s002_c_worked_example_at_2560x1440() -> void:
	# AC-S002-c 原文範例：2560x1440 -> 2304x1296 置中。
	var rect: Rect2 = HudLayout.safe_rect(Vector2i(2560, 1440))
	assert_vector(rect.position).is_equal(Vector2(128.0, 72.0))
	assert_vector(rect.size).is_equal(Vector2(2304.0, 1296.0))


func test_safe_rect_insets_five_percent_of_each_axis_at_every_defined_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var rect: Rect2 = HudLayout.safe_rect(window_size)
		var expected_inset: Vector2 = Vector2(window_size) * 0.05
		assert_vector(rect.position).append_failure_message(
			"%s: expected safe-rect inset %s, got position %s" % [label, expected_inset, rect.position]
		).is_equal(expected_inset)
		assert_vector(rect.size).append_failure_message(
			"%s: expected safe-rect size %s, got %s" % [
				label, Vector2(window_size) - expected_inset * 2.0, rect.size
			]
		).is_equal(Vector2(window_size) - expected_inset * 2.0)


func test_status_label_rect_is_anchored_at_safe_rect_top_left_at_every_defined_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var status: Rect2 = HudLayout.status_label_rect(window_size)
		assert_vector(status.position).append_failure_message(
			"%s: StatusLabel should start at the safe rect's top-left corner %s, got %s" % [
				label, safe.position, status.position
			]
		).is_equal(safe.position)


func test_info_label_rect_sits_right_of_status_label_and_ends_at_safe_rect_right_edge() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var status: Rect2 = HudLayout.status_label_rect(window_size)
		var info: Rect2 = HudLayout.info_label_rect(window_size)
		assert_float(info.position.x).append_failure_message(
			"%s: InfoLabel (left=%.1f) overlaps StatusLabel (right=%.1f)" % [
				label, info.position.x, status.end.x
			]
		).is_greater(status.end.x)
		assert_float(info.end.x).append_failure_message(
			"%s: InfoLabel should end at the safe rect's right edge %.1f, got %.1f" % [
				label, safe.end.x, info.end.x
			]
		).is_equal_approx(safe.end.x, 0.01)


func test_controls_hint_bg_rect_spans_full_safe_width_and_bottom_edge_matches_safe_rect() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var bg: Rect2 = HudLayout.controls_hint_bg_rect(window_size)
		assert_float(bg.position.x).append_failure_message(
			"%s: ControlsHintBg left edge should match safe rect's left edge" % label
		).is_equal_approx(safe.position.x, 0.01)
		assert_float(bg.end.x).append_failure_message(
			"%s: ControlsHintBg right edge should match safe rect's right edge" % label
		).is_equal_approx(safe.end.x, 0.01)
		assert_float(bg.end.y).append_failure_message(
			"%s: ControlsHintBg bottom edge should match safe rect's bottom edge %.1f, got %.1f" % [
				label, safe.end.y, bg.end.y
			]
		).is_equal_approx(safe.end.y, 0.01)


func test_load_error_label_rect_equals_safe_rect_at_every_defined_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var rect: Rect2 = HudLayout.load_error_label_rect(window_size)
		assert_vector(rect.position).is_equal(safe.position)
		assert_vector(rect.size).is_equal(safe.size)


func test_result_label_offset_rect_stays_within_safe_rect_half_extents() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var result: Rect2 = HudLayout.result_label_offset_rect(window_size)
		var half_safe_width: float = safe.size.x / 2.0
		var half_safe_height: float = safe.size.y / 2.0
		assert_float(-result.position.x).append_failure_message(
			"%s: ResultLabel half-width %.1f exceeds half the safe rect's width %.1f" % [
				label, -result.position.x, half_safe_width
			]
		).is_less_equal(half_safe_width)
		assert_float(-result.position.y).append_failure_message(
			"%s: ResultLabel half-height %.1f exceeds half the safe rect's height %.1f" % [
				label, -result.position.y, half_safe_height
			]
		).is_less_equal(half_safe_height)


# ─── 回歸基準:真實量測過的文字必須放得進算出來的框 ─────────────────────────
# 數字來源:prototypes/story-002-font-scale-spike-2026-09-04/logs/
# font_scale_probe_output.txt,A_board_locked 候選,Font.get_string_size() 實測。


func test_status_label_rect_fits_measured_text_width_and_height() -> void:
	for label: String in RESOLUTIONS_WITH_MIN_WINDOW:
		var window_size: Vector2i = RESOLUTIONS_WITH_MIN_WINDOW[label]
		var rect: Rect2 = HudLayout.status_label_rect(window_size)
		assert_float(rect.size.x).append_failure_message(
			"%s: StatusLabel box width %.1f is narrower than the spike's measured text width %.1f — text would clip" % [
				label, rect.size.x, MEASURED_STATUS_WIDTH[label]
			]
		).is_greater_equal(MEASURED_STATUS_WIDTH[label])
		assert_float(rect.size.y).append_failure_message(
			"%s: StatusLabel box height %.1f is shorter than the spike's measured line height %.1f" % [
				label, rect.size.y, MEASURED_LINE_HEIGHT[label]
			]
		).is_greater_equal(MEASURED_LINE_HEIGHT[label])


func test_info_label_rect_fits_measured_text_width_and_height() -> void:
	for label: String in RESOLUTIONS_WITH_MIN_WINDOW:
		var window_size: Vector2i = RESOLUTIONS_WITH_MIN_WINDOW[label]
		var rect: Rect2 = HudLayout.info_label_rect(window_size)
		assert_float(rect.size.x).append_failure_message(
			"%s: InfoLabel box width %.1f is narrower than the spike's measured text width %.1f — text would clip" % [
				label, rect.size.x, MEASURED_INFO_WIDTH[label]
			]
		).is_greater_equal(MEASURED_INFO_WIDTH[label])
		assert_float(rect.size.y).append_failure_message(
			"%s: InfoLabel box height %.1f is shorter than the spike's measured line height %.1f" % [
				label, rect.size.y, MEASURED_LINE_HEIGHT[label]
			]
		).is_greater_equal(MEASURED_LINE_HEIGHT[label])


func test_controls_hint_bg_rect_fits_measured_text_width_including_child_label_inset() -> void:
	for label: String in RESOLUTIONS_WITH_MIN_WINDOW:
		var window_size: Vector2i = RESOLUTIONS_WITH_MIN_WINDOW[label]
		var rect: Rect2 = HudLayout.controls_hint_bg_rect(window_size)
		var usable_width: float = rect.size.x - CONTROLS_HINT_LABEL_INSET_PX
		assert_float(usable_width).append_failure_message(
			"%s: ControlsHintBg usable width %.1f (after ControlsHintLabel's %d px inset) is narrower than the spike's measured text width %.1f" % [
				label, usable_width, int(CONTROLS_HINT_LABEL_INSET_PX), MEASURED_CONTROLS_HINT_WIDTH[label]
			]
		).is_greater_equal(MEASURED_CONTROLS_HINT_WIDTH[label])


func test_result_label_offset_rect_fits_measured_text_width_and_height() -> void:
	for label: String in RESOLUTIONS_WITH_MIN_WINDOW:
		var window_size: Vector2i = RESOLUTIONS_WITH_MIN_WINDOW[label]
		var rect: Rect2 = HudLayout.result_label_offset_rect(window_size)
		assert_float(rect.size.x).append_failure_message(
			"%s: ResultLabel box width %.1f is narrower than the spike's measured text width %.1f" % [
				label, rect.size.x, MEASURED_RESULT_WIDTH[label]
			]
		).is_greater_equal(MEASURED_RESULT_WIDTH[label])
		assert_float(rect.size.y).append_failure_message(
			"%s: ResultLabel box height %.1f is shorter than the spike's measured line height %.1f" % [
				label, rect.size.y, MEASURED_LINE_HEIGHT[label]
			]
		).is_greater_equal(MEASURED_LINE_HEIGHT[label])


# ─── LoadErrorLabel 換行後總高度(派工單第五節)──────────────────────────────
# 不重刻換行規則 —— 直接呼叫真實 Cubic_11.ttf 的 Font.get_multiline_string_size()
# 與 BattleScreen 自己的 load_failure_message() 真實訊息文字，在規格與 Story 001
# 都點名「最容易撐爆」的最小視窗 960x540 下量測。


func test_load_error_label_wrapped_message_fits_within_rect_height_at_minimum_window() -> void:
	# Arrange
	var window_size: Vector2i = Vector2i(960, 540)
	var font: FontFile = load("res://assets/fonts/Cubic_11.ttf")
	assert_object(font).append_failure_message("Cubic_11.ttf 載入失敗").is_not_null()

	var font_px: int = HudLayout.font_size(window_size)
	var rect: Rect2 = HudLayout.load_error_label_rect(window_size)
	# 用真實的 BattleScreen.load_failure_message()——不是杜撰句子，是 _fail_load()
	# 實際會顯示的同一段文字（LoadFailure.MISSING + 真實的 TERRAIN_PATH）。
	var message: String = BattleScreen.load_failure_message(
		BattleScreen.LoadFailure.MISSING, BattleScreen.TERRAIN_PATH
	)

	# Act — WORD_SMART 自動換行的寬度就是這個 rect 的寬度
	# （LoadErrorLabel 本身沒有額外內縮）。
	var wrapped_size: Vector2 = font.get_multiline_string_size(
		message, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_px
	)

	# Assert
	assert_float(wrapped_size.y).append_failure_message(
		"960x540 (font_px=%d): LoadErrorLabel 換行後總高度 %.1f 超出可用高度 %.1f — 訊息會溢出安全區/被裁切" % [
			font_px, wrapped_size.y, rect.size.y
		]
	).is_less_equal(rect.size.y)
