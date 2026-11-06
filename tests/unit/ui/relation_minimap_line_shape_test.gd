## relation-minimap story-002(第二段:關係圖)—— AC-P4 / AC-P7 / AC-P9 的 headless 可測部分。
##
## 🔴 檔案 I/O 例外聲明(test-standards 例外 2,乙類):3 條測試唯讀 src/ui/battle/*.gd
##   的原始碼文字(只看非註解行,避免驗證字串命中註解自己)。為什麼不能注入:斷言對象就是
##   原始碼寫法。🔴 自陳:掃描不等於窮盡(反射/.tscn 不在視野)。
## 🔴 未驗證:畫面外觀(鋸齒是否與棋盤同語彙、0 效果線是否「髒」、符號牌大小)—— 樣張 E、F 才算。
## 🔴 N 的來源:BattleScreen 呼叫 WorldLayout.compute_scale 後傳入 configure();
##   本檔只驗「牌尺寸隨 N 而非自算」,不驗 compute_scale 本身(它有自己的測試)。
extends GdUnitTestSuite

const _DIR: String = "res://src/ui/battle/"
const _MINIMAP_SRC: String = "res://src/ui/battle/relation_minimap.gd"


static func _code_lines(path: String) -> Array[String]:
	var result: Array[String] = []
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			result.append(line)
	return result


# ---- AC-P4 ---------------------------------------------------------------------

func test_ac_p4_every_existing_relation_is_listed_including_zero_effect() -> void:
	var statuses: Array[AffinityLineStatus] = [
		AffinityLineStatus.create(1, 2, AffinityLink.Polarity.POSITIVE, 1, 1),
		AffinityLineStatus.create(1, 3, AffinityLink.Polarity.NEGATIVE, 2, 0),
		AffinityLineStatus.create(2, 4, AffinityLink.Polarity.POSITIVE, 3, -1),
	]
	var alive: Array[int] = [1, 2, 3, 4]
	var map: RelationMinimap = auto_free(RelationMinimap.new())
	map.set_lines(statuses, alive)
	assert_int(map.diagnostic_lines().size()).is_equal(3)


func test_ac_p4_no_dashed_line_or_zero_symbol_in_minimap_code() -> void:
	for line: String in _code_lines(_MINIMAP_SRC):
		for banned: String in ["draw_dashed_line", "SYMBOL_NEUTRAL", "COLOR_NEUTRAL", "symbol_for"]:
			assert_bool(line.contains(banned)).append_failure_message(line).is_false()


# ---- AC-P7 ---------------------------------------------------------------------

func test_ac_p7_whole_project_has_single_status_to_style_conversion() -> void:
	var style_defs: int = 0
	var shape_defs: int = 0
	var dir: DirAccess = DirAccess.open(_DIR)
	for file: String in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		for line: String in FileAccess.get_file_as_string(_DIR + file).split("\n"):
			if line.begins_with("static func line_style_for("):
				style_defs += 1
			if line.begins_with("static func line_shape_for("):
				shape_defs += 1
			if line.begins_with("static func symbol_for("):
				fail("第二份轉換復活:" + file)
	assert_int(style_defs).is_equal(1)
	assert_int(shape_defs).is_equal(1)


func test_ac_p7_minimap_colours_come_from_board_view_not_copies() -> void:
	for line: String in _code_lines(_MINIMAP_SRC):
		assert_bool(line.contains("const COLOR_POSITIVE") or line.contains("const COLOR_NEGATIVE")).append_failure_message(line).is_false()
	var code: String = "\n".join(_code_lines(_MINIMAP_SRC))
	assert_bool(code.contains("BoardView.AFFINITY_LINE_COLOR_POSITIVE")).is_true()
	assert_bool(code.contains("BoardView.AFFINITY_LINE_COLOR_NEGATIVE")).is_true()


func test_ac_p7_minimap_shape_equals_board_shape_for_same_status() -> void:
	var statuses: Array[AffinityLineStatus] = [
		AffinityLineStatus.create(1, 2, AffinityLink.Polarity.POSITIVE, 3, -1),
		AffinityLineStatus.create(1, 3, AffinityLink.Polarity.NEGATIVE, 1, -1),
		AffinityLineStatus.create(2, 3, AffinityLink.Polarity.NEGATIVE, 2, 0),
	]
	var alive: Array[int] = [1, 2, 3]
	var map: RelationMinimap = auto_free(RelationMinimap.new())
	map.set_lines(statuses, alive)
	var d: Array[Dictionary] = map.diagnostic_lines()
	var positions: Dictionary[int, Vector2i] = {1: Vector2i(0, 0), 2: Vector2i(1, 0), 3: Vector2i(2, 0)}
	var board: Array[Dictionary] = BattleScreen.affinity_line_dicts(statuses, positions)
	assert_int(board.size()).is_equal(2)  # 效果 0 棋盤不畫
	assert_int(d[0]["shape"]).is_equal(board[0]["shape"])
	assert_int(d[1]["shape"]).is_equal(board[1]["shape"])


# ---- AC-P9 ---------------------------------------------------------------------

func test_ac_p9_line_width_is_one_function_of_font_size_only() -> void:
	assert_float(RelationMinimap.line_width_px(22)).is_equal(RelationMinimap.line_width_px(22))
	assert_float(RelationMinimap.line_width_px(11)).is_equal(maxf(1.0, 11.0 / 6.0))
	assert_float(RelationMinimap.line_width_px(1)).is_equal(1.0)


# ---- 符號牌 / 鋸齒參數 ---------------------------------------------------------------

func test_plaque_top_left_scales_with_n_and_is_whole_pixels() -> void:
	var mid: Vector2 = Vector2(100.3, 50.6)
	for n: int in [2, 4, 8]:
		var p: Vector2 = RelationMinimap.plaque_top_left(mid, n)
		assert_vector(p).is_equal(p.round())
		assert_vector(p).is_equal((mid - Vector2(3.5 * n, 3.5 * n)).round())


func test_minimap_source_never_computes_scale_itself() -> void:
	var code: String = "\n".join(_code_lines(_MINIMAP_SRC))
	assert_bool(code.contains("compute_scale")).is_false()
	assert_bool(code.contains("font_size / 11") or code.contains("/ HudLayout.GLYPH_PX")).is_false()


func test_zigzag_parameterised_call_matches_board_defaults_pointwise() -> void:
	var a: Vector2 = Vector2(16, 16)
	var b: Vector2 = Vector2(110, 80)
	var default_pts: PackedVector2Array = BoardView.affinity_line_points(a, b, BoardView.LineShape.ZIGZAG)
	var explicit_pts: PackedVector2Array = BoardView.affinity_line_points(
		a, b, BoardView.LineShape.ZIGZAG,
		BoardView.AFFINITY_ZIGZAG_AMPLITUDE, BoardView.AFFINITY_ZIGZAG_HALF_PERIOD, true
	)
	assert_array(default_pts).is_equal(explicit_pts)
	var unrounded: PackedVector2Array = BoardView.affinity_line_points(
		a, b, BoardView.LineShape.ZIGZAG, 3.6, 7.2, false
	)
	assert_int(unrounded.size()).is_greater(2)
	var fractional: bool = false
	for p: Vector2 in unrounded:
		if p != p.round():
			fractional = true
	assert_bool(fractional).append_failure_message("關係圖頂點不應取整").is_true()
