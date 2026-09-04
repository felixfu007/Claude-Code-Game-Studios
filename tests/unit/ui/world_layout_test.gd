# WorldLayout（src/ui/battle/world_layout.gd）的單元測試。
#
# 覆蓋 AC-S001-a（倍率正確：1080p/2K/4K/超寬分別 4x/5x/8x/5x）與 AC-S001-b
# （永遠置中：左右邊區相等、上下邊區相等，邊區為零時亦成立）。數字來源：
# design/art/screen-architecture.md 的裁決表，2K 與超寬兩列另外由
# prototypes/story-001-manual-scaling-verification-2026-09-04/ 的真實 GPU、
# 非 headless 擷圖實測覆核過。
#
# 純函式測試，不碰場景樹、不需要真實視窗 — 與 board_coords_test.gd 同一慣例。
#
# 命名慣例依 tests/unit/ui/board_coords_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
extends GdUnitTestSuite


const RESOLUTIONS: Dictionary = {
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2560, 1440),
	"4K": Vector2i(3840, 2160),
	"ultrawide": Vector2i(3440, 1440),
}

# design/art/screen-architecture.md 裁決表逐項數字。
const EXPECTED_SCALE: Dictionary = {
	"1080p": 4,
	"2K": 5,
	"4K": 8,
	"ultrawide": 5,
}

const EXPECTED_WORLD_SIZE: Dictionary = {
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2400, 1350),
	"4K": Vector2i(3840, 2160),
	"ultrawide": Vector2i(2400, 1350),
}

const EXPECTED_MARGIN: Dictionary = {
	"1080p": Vector2i(0, 0),
	"2K": Vector2i(80, 45),
	"4K": Vector2i(0, 0),
	"ultrawide": Vector2i(520, 45),
}


# ─── AC-S001-a: 倍率正確 ──────────────────────────────────────────────────


func test_compute_scale_matches_decision_table_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var scale: int = WorldLayout.compute_scale(RESOLUTIONS[label])
		assert_int(scale).append_failure_message(
			"%s (%s): expected scale %d, got %d" % [
				label, RESOLUTIONS[label], EXPECTED_SCALE[label], scale
			]
		).is_equal(EXPECTED_SCALE[label])


func test_compute_rect_world_size_matches_decision_table_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var rect: Rect2i = WorldLayout.compute_rect(RESOLUTIONS[label])
		assert_vector(Vector2(rect.size)).append_failure_message(
			"%s: expected world size %s, got %s" % [
				label, EXPECTED_WORLD_SIZE[label], rect.size
			]
		).is_equal(Vector2(EXPECTED_WORLD_SIZE[label]))


# ─── AC-S001-b: 永遠置中 ──────────────────────────────────────────────────


func test_compute_rect_left_and_right_margins_are_equal_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var rect: Rect2i = WorldLayout.compute_rect(window_size)
		var left_margin: int = rect.position.x
		var right_margin: int = window_size.x - (rect.position.x + rect.size.x)
		assert_int(right_margin).append_failure_message(
			"%s: left margin %d != right margin %d — not centered" % [
				label, left_margin, right_margin
			]
		).is_equal(left_margin)


func test_compute_rect_top_and_bottom_margins_are_equal_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var rect: Rect2i = WorldLayout.compute_rect(window_size)
		var top_margin: int = rect.position.y
		var bottom_margin: int = window_size.y - (rect.position.y + rect.size.y)
		assert_int(bottom_margin).append_failure_message(
			"%s: top margin %d != bottom margin %d — not centered" % [
				label, top_margin, bottom_margin
			]
		).is_equal(top_margin)


func test_compute_rect_margin_matches_decision_table_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var rect: Rect2i = WorldLayout.compute_rect(RESOLUTIONS[label])
		assert_vector(Vector2(rect.position)).append_failure_message(
			"%s: expected top-left margin %s, got %s" % [
				label, EXPECTED_MARGIN[label], rect.position
			]
		).is_equal(Vector2(EXPECTED_MARGIN[label]))


func test_compute_rect_zero_margin_resolutions_fill_the_window_exactly() -> void:
	# 1080p / 4K 兩者剛好整除 480x270，AC-S001-b「邊區為零時亦成立」的具體案例。
	for label: String in ["1080p", "4K"]:
		var window_size: Vector2i = RESOLUTIONS[label]
		var rect: Rect2i = WorldLayout.compute_rect(window_size)
		assert_vector(Vector2(rect.position)).is_equal(Vector2.ZERO)
		assert_vector(Vector2(rect.size)).is_equal(Vector2(window_size))


# ─── Transform 正確性與互逆 ────────────────────────────────────────────────


func test_canvas_to_window_transform_maps_origin_to_rect_position() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var rect: Rect2i = WorldLayout.compute_rect(window_size)
		var t: Transform2D = WorldLayout.canvas_to_window_transform(window_size)
		assert_vector(t * Vector2.ZERO).append_failure_message(
			"%s: canvas (0,0) should map to the rect's top-left corner %s" % [
				label, rect.position
			]
		).is_equal_approx(Vector2(rect.position), Vector2(0.01, 0.01))


func test_canvas_to_window_transform_scale_matches_compute_scale() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var t: Transform2D = WorldLayout.canvas_to_window_transform(window_size)
		var expected_scale: float = float(WorldLayout.compute_scale(window_size))
		assert_vector(t.get_scale()).append_failure_message(
			"%s: transform scale %s does not match compute_scale() %f" % [
				label, t.get_scale(), expected_scale
			]
		).is_equal_approx(Vector2(expected_scale, expected_scale), Vector2(0.001, 0.001))


func test_window_to_canvas_transform_is_inverse_of_canvas_to_window_transform() -> void:
	var test_points: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(479.0, 269.0), Vector2(240.0, 135.0), Vector2(32.0, 39.0)
	]
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var c2w: Transform2D = WorldLayout.canvas_to_window_transform(window_size)
		var w2c: Transform2D = WorldLayout.window_to_canvas_transform(window_size)
		for p: Vector2 in test_points:
			var window_pos: Vector2 = c2w * p
			var round_trip: Vector2 = w2c * window_pos
			assert_vector(round_trip).append_failure_message(
				"%s: round-trip canvas=%s -> window=%s -> canvas=%s did not match" % [
					label, p, window_pos, round_trip
				]
			).is_equal_approx(p, Vector2(0.01, 0.01))


# ─── 邊界防呆（不是 AC 要求的正常路徑，defense in depth）──────────────────


func test_compute_scale_floors_at_1_when_window_smaller_than_base_canvas() -> void:
	# 正常遊玩不會走到這裡（project.godot 的 min_size 已把它擋在引擎層，見
	# prototypes/story-010-headless-resolution-probe-2026-09-04/），這裡只驗證
	# compute_scale() 自己的防呆邏輯不會算出 0 或負數。
	var scale: int = WorldLayout.compute_scale(Vector2i(100, 50))
	assert_int(scale).is_equal(1)
