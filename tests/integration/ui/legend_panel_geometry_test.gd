## legend_panel_geometry_test.gd
##
## story-059 圖例面板版面幾何:AC1 互不相交、AC2 文字在圖示右側、AC4 常駐敏感度證明。
##
## 預言機全部取真實版面:[method LegendPanel.apply_layout] 的結果、[method HudLayout.safe_rect]、
## [method BoardView.legend_sample_bounds](範例實際外框,不用假設尺寸)。
## 揭露:不涉及檔案 I/O;不驗像素(AC3 另以開窗實拍);不證明窮盡性(只驗四個尺寸)。
## 揭露:只測 [LegendPanel] 本體(直接 new),不經 BattleScreen。
extends GdUnitTestSuite

const _SIZES: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440),
]


## 突變 1:圖示不扣範例原點偏移(原缺陷)。
class _MutantNoOriginSubtract extends LegendPanel:
	func _sample_position(iscale: int, _ws: Vector2i) -> Vector2:
		return BoardView.LEGEND_SAMPLE_ORIGIN * float(iscale)


## 突變 2:列高降回兩行字高、無間距。
class _MutantNoRowGap extends LegendPanel:
	func _row_height(_content_h: float, _gap: float, ws: Vector2i) -> float:
		return float(HudLayout.font_size(ws)) * 2.0


## 突變 3:文字起點回到 x + 32*iscale(無間距、不看實際外框寬)。
class _MutantTextLeftOld extends LegendPanel:
	func _text_left(col_x: float, _w: float, _gap: float, iscale: int, _ws: Vector2i) -> float:
		return col_x + 32.0 * float(iscale)


## 突變 4:只在高度 >= 1080 才偏移(尺寸相依的錯誤)。
class _MutantSizeDependent extends LegendPanel:
	func _sample_position(iscale: int, ws: Vector2i) -> Vector2:
		if ws.y >= 1080:
			return BoardView.LEGEND_SAMPLE_ORIGIN * float(iscale)
		return super._sample_position(iscale, ws)


func _make(panel: LegendPanel, size: Vector2i) -> LegendPanel:
	auto_free(panel)
	add_child(panel)
	panel.apply_layout(size)
	return panel


func _icon_rect(panel: LegendPanel, kind: int) -> Rect2:
	var sample: Node2D = panel.icon_for(kind)
	var holder: Control = sample.get_parent()
	var b: Rect2 = BoardView.legend_sample_bounds(sample)
	return Rect2(holder.position + sample.position + b.position * sample.scale, b.size * sample.scale)


func _label_rect(label: Label) -> Rect2:
	return Rect2(label.position, label.size)


## 回傳違規描述(空陣列 = 通過)。mode: 1=AC1 全部, 2=AC2。
func _violations(panel: LegendPanel, size: Vector2i, check_ac1: bool, check_ac2: bool) -> Array[String]:
	var out: Array[String] = []
	var safe: Rect2 = HudLayout.safe_rect(size)
	var gap: float = LegendPanel.text_gap(size)
	var all: Array[Dictionary] = []
	for kind: int in LegendPanel.entry_kinds():
		var icon: Rect2 = _icon_rect(panel, kind)
		var nm: Rect2 = _label_rect(panel.name_label_for(kind))
		var ds: Rect2 = _label_rect(panel.desc_label_for(kind))
		all.append({"k": kind, "t": "icon", "r": icon})
		all.append({"k": kind, "t": "name", "r": nm})
		all.append({"k": kind, "t": "desc", "r": ds})
		if check_ac1:
			for e: Dictionary in [{"t": "icon", "r": icon}, {"t": "name", "r": nm}, {"t": "desc", "r": ds}]:
				if not safe.encloses(e["r"]):
					out.append("%s kind %d %s outside safe" % [str(size), kind, e["t"]])
		if check_ac2:
			if nm.position.x < icon.end.x + gap or ds.position.x < icon.end.x + gap:
				out.append("%s kind %d text left %f < icon right %f + gap %f" % [
					str(size), kind, nm.position.x, icon.end.x, gap])
	if check_ac1:
		for i: int in range(all.size()):
			for j: int in range(i + 1, all.size()):
				var a: Rect2 = all[i]["r"]
				var b: Rect2 = all[j]["r"]
				if a.intersects(b):
					out.append("%s kind %d %s x kind %d %s" % [
						str(size), all[i]["k"], all[i]["t"], all[j]["k"], all[j]["t"]])
	return out


func test_ac1_icons_names_descs_pairwise_disjoint_and_inside_safe_rect() -> void:
	for size: Vector2i in _SIZES:
		var panel: LegendPanel = _make(LegendPanel.new(), size)
		var v: Array[String] = _violations(panel, size, true, false)
		assert_array(v).append_failure_message(str(v.slice(0, 5))).is_empty()


func test_ac1_adjacent_rows_same_column_have_positive_vertical_gap() -> void:
	for size: Vector2i in _SIZES:
		var panel: LegendPanel = _make(LegendPanel.new(), size)
		var kinds: Array[int] = LegendPanel.entry_kinds()
		var rows: int = ceili(float(kinds.size()) / float(LegendPanel.COLUMNS))
		for i: int in range(kinds.size() - 1):
			if (i + 1) % rows == 0:
				continue  # 換欄
			var upper: Rect2 = _label_rect(panel.desc_label_for(kinds[i]))
			var lower: Rect2 = _label_rect(panel.name_label_for(kinds[i + 1]))
			assert_bool(lower.position.y > upper.end.y).append_failure_message(
				"%s row %d desc bottom %f vs next name top %f" % [str(size), i, upper.end.y, lower.position.y]).is_true()


func test_ac2_text_starts_right_of_icon_plus_gap() -> void:
	for size: Vector2i in _SIZES:
		var panel: LegendPanel = _make(LegendPanel.new(), size)
		var v: Array[String] = _violations(panel, size, false, true)
		assert_array(v).append_failure_message(str(v.slice(0, 5))).is_empty()
		assert_float(LegendPanel.text_gap(size)).is_greater(0.0)


func test_ac2_name_label_height_is_at_least_real_font_line_height() -> void:
	for size: Vector2i in _SIZES:
		var panel: LegendPanel = _make(LegendPanel.new(), size)
		var kind: int = LegendPanel.entry_kinds()[0]
		assert_float(panel.name_label_for(kind).size.y).is_greater_equal(LegendPanel.label_height(size))


func test_sensitivity_proof_icon_without_origin_subtract_turns_ac1_red() -> void:
	var size: Vector2i = Vector2i(1920, 1080)
	var panel: LegendPanel = _make(_MutantNoOriginSubtract.new(), size)
	assert_array(_violations(panel, size, true, false)).is_not_empty()


func test_sensitivity_proof_no_row_gap_turns_ac1_red() -> void:
	# 只驗列間距斷言(相鄰列垂直間距)會紅:列高降回 2*fpx 後內容高不再放得下。
	var size: Vector2i = Vector2i(1920, 1080)
	var panel: LegendPanel = _make(_MutantNoRowGap.new(), size)
	assert_array(_violations(panel, size, true, false)).is_not_empty()


func test_sensitivity_proof_text_left_old_formula_turns_ac2_red() -> void:
	var size: Vector2i = Vector2i(1920, 1080)
	var panel: LegendPanel = _make(_MutantTextLeftOld.new(), size)
	assert_array(_violations(panel, size, false, true)).is_not_empty()


func test_sensitivity_proof_size_dependent_error_green_small_red_large() -> void:
	var small: Vector2i = Vector2i(960, 540)
	var large: Vector2i = Vector2i(1920, 1080)
	var p_small: LegendPanel = _make(_MutantSizeDependent.new(), small)
	assert_array(_violations(p_small, small, true, true)).is_empty()
	var p_large: LegendPanel = _make(_MutantSizeDependent.new(), large)
	assert_array(_violations(p_large, large, true, false)).is_not_empty()
