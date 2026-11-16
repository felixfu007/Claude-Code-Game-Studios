# Story 055 —— 血量文字 Label 節點寬度不得超過文字條可用寬(場上真實節點,非字型幾何)。
# 成因(C 推論,由本檔紅/綠驗證):Label 的 size 被預設 16px 字型撐成 (43,23),置中後右端被 clip 裁掉。
# 防空洞:先斷言找到的 HP Label 數 > 0。headless 不 rasterize;像素層由協調者開窗重跑
# prototypes/story-055-hp-text-width-measure-2026-11-16/driver.gd 看 REAL_LABEL 行。
# 敏感度:_MutantWideLabel 還原「Label 寬被撐大」的舊行為,對應測試必須紅(一次一個 mutant)。
extends GdUnitTestSuite


const _BOARD_VIEW_SCENE_PATH: String = "res://src/ui/battle/BoardView.tscn"
const _CELL: Vector2i = Vector2i(2, 2)


func _view(script: GDScript = null) -> BoardView:
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	if script != null:
		instance.set_script(script)
	add_child(instance)
	return instance


func _hp_labels(view: BoardView, hp: int, hp_max: int, preview: int) -> Array[Label]:
	var pieces: Array[Dictionary] = [{
		"cell": _CELL, "faction": "PLAYER", "sprite_index": 0, "label": "藍",
		"hp": hp, "hp_max": hp_max, "hp_preview": preview,
		"show_hp_text": true, "card_target_illegal": false,
	}]
	view.render_pieces(pieces)
	var found: Array[Label] = []
	_collect(view.get_node("StatsLayer"), found)
	return found


func _collect(node: Node, out: Array[Label]) -> void:
	if node is Label:
		out.append(node)
	for child: Node in node.get_children():
		_collect(child, out)


func _assert_width_fits(view: BoardView, hp: int, hp_max: int, preview: int) -> void:
	var labels: Array[Label] = _hp_labels(view, hp, hp_max, preview)
	assert_int(labels.size()).is_greater(0)
	var usable: float = BoardView.hp_text_rect_in_cell().size.x
	for label: Label in labels:
		assert_bool(label.size.x <= usable).append_failure_message(
			"HP Label '%s' size.x=%s > 文字條可用寬 %s" % [label.text, label.size.x, usable]
		).is_true()


func test_ac3_normal_30_30_label_width_within_strip() -> void:
	_assert_width_fits(_view(), 30, 30, -1)


func test_ac3_preview_longest_label_width_within_strip() -> void:
	_assert_width_fits(_view(), 30, 30, 15)


class _MutantWideLabel extends BoardView:
	func _build_hp_text(
		cell_top_left: Vector2, hp: int, hp_max: int, hp_preview: int, illegal: bool
	) -> Node2D:
		var node: Node2D = super._build_hp_text(cell_top_left, hp, hp_max, hp_preview, illegal)
		for child: Node in node.get_children():
			for l: Node in child.get_children():
				if l is Label:
					# 還原舊做法:新建 Label、離樹時用 theme 字級覆寫,最小尺寸被預設字型撐成 (43,23)
					var lab: Label = Label.new()
					lab.add_theme_font_size_override("font_size", BoardView.HP_TEXT_FONT_SIZE)
					lab.text = (l as Label).text
					lab.size = Vector2(32.0, lab.get_minimum_size().y)
					child.remove_child(l)
					l.free()
					child.add_child(lab)
					break
		return node


func test_sensitivity_wide_label_mutant_is_caught() -> void:
	var view: BoardView = _view(_MutantWideLabel)
	var labels: Array[Label] = _hp_labels(view, 30, 30, -1)
	assert_int(labels.size()).is_greater(0)
	assert_bool(labels[0].size.x > BoardView.hp_text_rect_in_cell().size.x).is_true()
