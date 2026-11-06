## relation-minimap story-002(第一段:棋盤)—— 純靜態函式層測試。
## AC-P1(形狀只由關係決定)/ AC-P2 字典層 / AC-P3(0 效果不畫、無 MUTED)/
## AC-P7(棋盤側單一轉換)/ AC-P8(棋盤程式不含關係詞)+ 鋸齒頂點幾何。
##
## 🔴 檔案 I/O 例外聲明(test-standards 例外 2):AC-P3 / AC-P7 / AC-P8 的三條測試唯讀
##   src/ui/battle/*.gd 的原始碼文字(只看非註解行,避免驗證字串命中註解自己)。
##   為什麼不能注入:斷言對象就是原始碼寫法。🔴 自陳:掃描不等於窮盡(反射/.tscn 不在視野)。
##   🔴 AC-P7 只涵蓋棋盤側:關係圖仍有自己的 RelationMinimap.symbol_for(下一段才收),
##   故本檔不能宣稱「全專案只有一處轉換」。
##
## 🔴 敏感度證明:AC-P1 / AC-P3 / AC-P7 的故意改壞注入見交付回報;本檔本身不留注入。
extends GdUnitTestSuite

const _BATTLE_DIR: String = "res://src/ui/battle/"
const _BOARD_VIEW_SRC: String = "res://src/ui/battle/board_view.gd"


func _status(
	polarity: AffinityLink.Polarity, state: AffinityLineStatus.State, distance: int
) -> AffinityLineStatus:
	var s: AffinityLineStatus = AffinityLineStatus.new()
	s.unit_id = 1
	s.partner_id = 2
	s.polarity = polarity
	s.distance = distance
	s.state = state
	return s


func _dicts_for(status: AffinityLineStatus) -> Array[Dictionary]:
	var positions: Dictionary[int, Vector2i] = {1: Vector2i(0, 0), 2: Vector2i(3, 0)}
	var statuses: Array[AffinityLineStatus] = [status]
	return BattleScreen.affinity_line_dicts(statuses, positions)


static func _code_lines(path: String) -> Array[String]:
	var result: Array[String] = []
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			result.append(line)
	return result


# ---- AC-P1 ---------------------------------------------------------------------

func test_ac_p1_shape_depends_only_on_polarity() -> void:
	# 好感(POSITIVE 關係):距離 1 = 加成、距離 3 = 懲罰 → 形狀都是實線
	var near_pos: Array[Dictionary] = _dicts_for(_status(AffinityLink.Polarity.POSITIVE, AffinityLineStatus.State.POSITIVE, 1))
	var far_pos: Array[Dictionary] = _dicts_for(_status(AffinityLink.Polarity.POSITIVE, AffinityLineStatus.State.NEGATIVE, 3))
	assert_int(near_pos[0]["shape"]).is_equal(BoardView.LineShape.SOLID)
	assert_int(far_pos[0]["shape"]).is_equal(BoardView.LineShape.SOLID)
	# 惡感(NEGATIVE 關係):距離 1 = 懲罰、距離 3 = 加成 → 形狀都是鋸齒
	var near_neg: Array[Dictionary] = _dicts_for(_status(AffinityLink.Polarity.NEGATIVE, AffinityLineStatus.State.NEGATIVE, 1))
	var far_neg: Array[Dictionary] = _dicts_for(_status(AffinityLink.Polarity.NEGATIVE, AffinityLineStatus.State.POSITIVE, 3))
	assert_int(near_neg[0]["shape"]).is_equal(BoardView.LineShape.ZIGZAG)
	assert_int(far_neg[0]["shape"]).is_equal(BoardView.LineShape.ZIGZAG)


# ---- AC-P2(字典層;線節點 default_color 在整合測試)--------------------------------

func test_ac_p2_colour_depends_only_on_effect_not_shape() -> void:
	var solid_red: Array[Dictionary] = _dicts_for(_status(AffinityLink.Polarity.POSITIVE, AffinityLineStatus.State.NEGATIVE, 3))
	var zigzag_red: Array[Dictionary] = _dicts_for(_status(AffinityLink.Polarity.NEGATIVE, AffinityLineStatus.State.NEGATIVE, 1))
	assert_int(solid_red[0]["tone"]).is_equal(BoardView.LineTone.NEGATIVE)
	assert_int(zigzag_red[0]["tone"]).is_equal(BoardView.LineTone.NEGATIVE)
	assert_int(solid_red[0]["shape"]).is_not_equal(zigzag_red[0]["shape"])
	assert_int(solid_red[0]["symbol"]).is_equal(BoardView.LineSymbol.MINUS)


# ---- AC-P3 ---------------------------------------------------------------------

func test_ac_p3_neutral_effect_is_not_emitted() -> void:
	for polarity: AffinityLink.Polarity in [AffinityLink.Polarity.POSITIVE, AffinityLink.Polarity.NEGATIVE]:
		assert_array(_dicts_for(_status(polarity, AffinityLineStatus.State.NEUTRAL, 2))).is_empty()


func test_ac_p3_board_has_no_muted_tone_or_stroke() -> void:
	assert_int(BoardView.LineTone.size()).is_equal(2)
	for line: String in _code_lines(_BOARD_VIEW_SRC):
		assert_bool(line.contains("MUTED")).append_failure_message(line).is_false()


# ---- AC-P7(棋盤側)------------------------------------------------------------

func test_ac_p7_board_side_has_single_status_to_style_conversion() -> void:
	var defs: int = 0
	var dir: DirAccess = DirAccess.open(_BATTLE_DIR)
	for file: String in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		for line: String in FileAccess.get_file_as_string(_BATTLE_DIR + file).split("\n"):
			if line.begins_with("static func line_style_for("):
				defs += 1
	assert_int(defs).is_equal(1)
	# BoardView 刻意不認識 AffinityLineStatus(只吃已轉換的字典)
	for line: String in _code_lines(_BOARD_VIEW_SRC):
		assert_bool(line.contains("AffinityLineStatus")).append_failure_message(line).is_false()


# ---- AC-P8(棋盤程式不含關係詞;節點層無 Label 在整合測試)---------------------------

func test_ac_p8_board_view_code_has_no_relation_words() -> void:
	for line: String in _code_lines(_BOARD_VIEW_SRC):
		for banned: String in ["好感", "惡感", "relation.kind"]:
			assert_bool(line.contains(banned)).append_failure_message(line).is_false()


# ---- 鋸齒頂點幾何 -----------------------------------------------------------------

func test_solid_points_are_just_the_two_endpoints() -> void:
	var pts: PackedVector2Array = BoardView.affinity_line_points(Vector2(16, 16), Vector2(48, 16), BoardView.LineShape.SOLID)
	assert_int(pts.size()).is_equal(2)


func test_zigzag_segment_count_is_odd_min_three_and_ties_go_larger() -> void:
	for length: float in [4.0, 12.0, 32.0, 45.25, 64.0, 96.0, 160.0]:
		var pts: PackedVector2Array = BoardView.affinity_line_points(Vector2(0, 0), Vector2(length, 0), BoardView.LineShape.ZIGZAG)
		var segments: int = pts.size() - 1
		assert_int(segments % 2).append_failure_message("L=%s" % length).is_equal(1)
		assert_int(segments).append_failure_message("L=%s" % length).is_greater_equal(3)
	# L = 32:7 與 9 平手,取較大者 9
	var tie: PackedVector2Array = BoardView.affinity_line_points(Vector2(0, 0), Vector2(32, 0), BoardView.LineShape.ZIGZAG)
	assert_int(tie.size() - 1).is_equal(9)


func test_zigzag_horizontal_vertices_alternate_by_amplitude_and_ends_are_zero_offset() -> void:
	var from_pos: Vector2 = Vector2(16, 16)
	var pts: PackedVector2Array = BoardView.affinity_line_points(from_pos, Vector2(48, 16), BoardView.LineShape.ZIGZAG)
	assert_vector(pts[0]).is_equal(from_pos)
	assert_vector(pts[pts.size() - 1]).is_equal(Vector2(48, 16))
	var last_sign: float = 0.0
	for i: int in range(1, pts.size() - 1):
		var offset: float = pts[i].y - 16.0
		assert_float(absf(offset)).is_equal(BoardView.AFFINITY_ZIGZAG_AMPLITUDE)
		assert_float(offset * last_sign).is_less_equal(0.0)  # 與前一頂點反號
		last_sign = offset
	for p: Vector2 in pts:
		assert_vector(p).is_equal(p.round())
