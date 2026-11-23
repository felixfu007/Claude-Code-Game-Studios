# 2026-11-23 午休截圖疊字缺陷修正(story-029 Z3、story-021 縮圖關係字樣與資訊卡關係行)。
# 判準是「矩形不相交 / 可見性」,沒有像素量測(headless 取不到像素;Check 5 人眼仍待管理者)。
# 檔案存取:資訊卡段讀版控夾具 assets/data/(甲類例外,只讀);手牌段無檔案存取。
# 手牌段載入的是 production 的 HandBar.tscn(BattleScreen 內實際實例化的同一份場景),
# 不是 BattleScreen.tscn 整張 —— 因 Z3 的輸入只是 render() 的 card_faces,不經 BattleScreen 的資料路徑;
# 資訊卡段則走真實 BattleScreen.tscn。
# 敏感度證明:以暫時回退修正、逐條只留一個 test_ 函式各跑一次取得紅燈(原始行在交付回報);
# 未做常駐 mutant(被測對象是節點版面矩形,屬「斷言對象為既有版面計算」那一類,誠實登記)。
extends GdUnitTestSuite

const _HAND_SCENE: String = "res://src/ui/battle/HandBar.tscn"
const _SCREEN_SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const _ROSTER: String = "res://assets/data/units/vs01_roster.txt"
const _CARDS: String = "res://assets/data/cards/test_fixture_cards_cost.txt"
const _AFFINITY: String = "res://assets/data/affinity/tutorial_no_links.txt"
const _TUNING: String = "res://assets/data/tuning/test_fixture_tuning_card_cost_nondefault.txt"
const _MAX_SLOTS: int = 5
const _SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1920, 1080)]
const _LONG_EFFECT: String = "兩名單位本回合都打得到同一個目標時這張牌才會生效並造成額外傷害"
const _REASON: String = "射程內沒有敵人"

var _host_snap: CursorHostSnapshot = null
var _orig_size: Vector2i = Vector2i.ZERO


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()
	_orig_size = get_window().size


func after_test() -> void:
	get_window().size = _orig_size
	_host_snap.restore()
	CampaignProgress.reset_for_test()


# ---- 手牌 Z3 ------------------------------------------------------------------

func _expanded_bar(kind: HandBar.SlotKind, face: Dictionary) -> HandBar:
	var bar: HandBar = auto_free(load(_HAND_SCENE).instantiate())
	add_child(bar)
	var kinds: Array[HandBar.SlotKind] = [kind]
	var faces: Array[Dictionary] = [face]
	bar.render(kinds, _MAX_SLOTS, HandBar.Availability.NORMAL, true, faces)
	bar._set_expand_progress(1.0)
	return bar


## 三個 Label 中可見者的面板內矩形。
func _z3_label_rects(bar: HandBar) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for label: Label in [bar._detail_text_label, bar._detail_effect_label, bar._detail_reason_label]:
		if label.visible:
			out.append(Rect2(label.position, label.size))
	return out


func _long_face() -> Dictionary:
	return {
		"card_name": "並肩合擊", "flavor_text": _LONG_EFFECT,
		"delta_atk": 0, "delta_def": 0, "duration_rounds": 0,
		"unplayable_reason": _REASON,
	}


func _check_z3_no_overlap(bar: HandBar, ws: Vector2i) -> void:
	var rects: Array[Rect2] = _z3_label_rects(bar)
	var panel_local: Rect2 = Rect2(Vector2.ZERO, bar._detail_panel.size)
	assert_int(rects.size()).append_failure_message("%s PRECONDITION: 至少牌面+原因兩行可見" % ws).is_greater_equal(2)
	for i: int in range(rects.size()):
		assert_bool(panel_local.encloses(rects[i])).append_failure_message(
			"%s: 第%d行 %s 溢出框 %s" % [ws, i, rects[i], panel_local]).is_true()
		for j: int in range(i + 1, rects.size()):
			assert_bool(rects[i].intersects(rects[j])).append_failure_message(
				"%s: 第%d行 %s 與第%d行 %s 相交" % [ws, i, rects[i], j, rects[j]]).is_false()
	for label: Label in [bar._detail_text_label, bar._detail_effect_label, bar._detail_reason_label]:
		if label.visible:
			assert_float(label.size.y).append_failure_message(
				"%s: Label 高度 %s 小於文字實際高度 %s(文字會畫出框外)" % [ws, label.size.y, label.get_minimum_size().y]
			).is_greater_equal(label.get_minimum_size().y - 0.5)
	# 規格矩形 detail_panel_rect 是最小矩形:面板下緣仍貼著它的下緣、不得比它矮。
	var base: Rect2 = HandBar.detail_panel_rect(0, ws)
	assert_float(bar._detail_panel.position.y + bar._detail_panel.size.y).is_equal_approx(base.end.y, 0.5)
	assert_float(bar._detail_panel.size.y).is_greater_equal(base.size.y - 0.5)


func test_z3_bonus_card_long_text_bonus_and_reason_do_not_overlap() -> void:
	for ws: Vector2i in _SIZES:
		get_window().size = ws
		var bar: HandBar = _expanded_bar(HandBar.SlotKind.TEMPORARY_MODIFIER, _long_face())
		assert_bool(bar._detail_effect_label.visible).append_failure_message(
			"%s PRECONDITION: 加成類牌要有加成行" % ws).is_true()
		_check_z3_no_overlap(bar, ws)


func test_z3_damage_and_heal_cards_have_no_bonus_line() -> void:
	for kind: HandBar.SlotKind in [HandBar.SlotKind.DAMAGE, HandBar.SlotKind.HEAL]:
		var bar: HandBar = _expanded_bar(kind, _long_face())
		assert_str(bar.diagnostic_detail_effect_text()).append_failure_message(
			"傷害/補血牌不該顯示 ATK/DEF/剩N回合,實得 '%s'" % bar.diagnostic_detail_effect_text()).is_empty()
		assert_bool(bar._detail_effect_label.visible).is_false()


func test_z3_damage_card_long_text_and_reason_do_not_overlap() -> void:
	for ws: Vector2i in _SIZES:
		get_window().size = ws
		var bar: HandBar = _expanded_bar(HandBar.SlotKind.DAMAGE, _long_face())
		_check_z3_no_overlap(bar, ws)


# ---- 收合縮圖不放關係字樣 ----------------------------------------------------------

func test_collapsed_thumbnail_has_no_relation_marks_expanded_does() -> void:
	var kinds: Array[HandBar.SlotKind] = [HandBar.SlotKind.PERMANENT_WRITE]
	var faces: Array[Dictionary] = [{"relation_state": 0, "pair_names": "甲×乙"}]
	var bar: HandBar = auto_free(load(_HAND_SCENE).instantiate())
	add_child(bar)
	bar.render(kinds, _MAX_SLOTS, HandBar.Availability.NORMAL, false, faces)
	var panel: Panel = bar._slot_nodes[0]
	var label: Label = panel.get_node("RelationLabel") as Label
	var badge: Control = panel.get_node("RelationBadge") as Control
	assert_float(bar.diagnostic_expand_progress()).append_failure_message("PRECONDITION: 收合").is_equal(0.0)
	assert_bool(label.visible or badge.visible).append_failure_message(
		"收合縮圖不該畫關係字樣/徽記(UX 規格:Z1 縮圖不放)").is_false()
	bar._set_expand_progress(1.0)
	assert_bool(label.visible and badge.visible).append_failure_message("展開 Z2 要有").is_true()


# ---- 資訊卡關係行 ------------------------------------------------------------------

func test_info_card_text_does_not_run_into_relation_row() -> void:
	for ws: Vector2i in _SIZES:
		get_window().size = ws
		var s: BattleScreen = load(_SCREEN_SCENE).instantiate()
		s.terrain_path_override = _TERRAIN
		s.roster_path_override = _ROSTER
		s.cards_path_override = _CARDS
		s.affinity_path_override = _AFFINITY
		s.tuning_path_override = _TUNING
		add_child(s)
		assert_bool(s._load_failed).is_false()
		s._controller.select_unit(1)
		s._cursor_cell = s._state.position_of(2)
		s._cursor_active = true
		s._tile_info_cursor_valid = true
		s._update_tile_info_panel()
		# 造出截圖當時的 9 行(含減傷列)情境:走與正式路徑相同的旗標與版面函式。
		s._tile_info_panel_label.text += "\n減傷：2"
		s._set_tile_info_extra_line(true)
		var rows: Array[Dictionary] = s.diagnostic_tile_info_relation_rows()
		assert_int(rows.size()).append_failure_message("%s PRECONDITION: 有關係行" % ws).is_equal(1)
		var label: Label = s._tile_info_panel_label
		var text_bottom: float = label.get_global_rect().position.y + label.get_minimum_size().y
		var row: Control = s._tile_info_relation_row_nodes[0]
		var row_top: float = row.get_global_rect().position.y
		var bg: Rect2 = s._tile_info_panel_bg.get_global_rect()
		assert_float(text_bottom).append_failure_message(
			"%s: 資訊卡文字底 %s 壓進關係行頂 %s" % [ws, text_bottom, row_top]).is_less_equal(row_top + 0.5)
		assert_float(row.get_global_rect().end.y).append_failure_message(
			"%s: 關係行超出資訊卡下緣" % ws).is_less_equal(bg.end.y + 0.5)
		remove_child(s)
		s.free()
