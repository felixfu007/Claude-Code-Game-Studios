# story-016 接線測試:真實 BattleScreen.tscn(load -> instantiate -> add_child)。
#
# 折損 N>0 時,畫面的預覽 Φ(_guess_delta_for_cell 走 AffinityRules.bonus_for_at)必須與
# 戰鬥實際用的 Φ(AffinityPhiProvider.phi_of)同源、都含扣減。mutant:battle_screen 的預覽呼叫
# 不傳 pair_wear Callable -> 預覽差值少算折損,本測試紅(見 _MutantNoWearCallable)。
# 不讀檔;資料全來自場景自己載入的真實 vs01 資料(不注入合成資料)。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


## mutant:預覽呼叫不帶 pair_wear(模擬「忘了接線」)。
class _MutantNoWearCallable extends BattleScreen:
	func _guess_delta_for_cell(unit_id: int, cell: Vector2i) -> int:
		var positions: Dictionary[int, Vector2i] = _phi.positions()
		var links: Array[AffinityLink] = _phi.links()
		var hypo: Dictionary[int, Vector2i] = _phi.positions_with(unit_id, cell)
		return AffinityRules.bonus_for_at(unit_id, cell, hypo, links, _state.affinity_tuning) \
			- AffinityRules.bonus_for(unit_id, positions, links, _state.affinity_tuning)


func _wear_first_link_pair(inst: BattleScreen, amount: int) -> AffinityLink:
	var link: AffinityLink = inst._phi.links()[0]
	var ca: AffinityTypes.Character = AffinityRosterCharacterMapper.character_for_roster_id(link.unit_a)
	var cb: AffinityTypes.Character = AffinityRosterCharacterMapper.character_for_roster_id(link.unit_b)
	var pair: int = int(AffinityTypes.pair_of(ca, cb))
	var st: BattleState = inst._state
	st.commit_authoritative_change(func() -> void: st.add_pair_wear(pair, amount, 3))
	return link


## 候選格偏移(相對夥伴):至少有一個會讓折損改變預覽差值,視當前站位而定。
const _OFFSETS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(4, 0), Vector2i(0, 4)]


## 取第一個「折損確實改變預覽值」的偏移;找不到回傳 Vector2i(99,99)。
func _effective_offset(inst: BattleScreen, link: AffinityLink, at_side_only: bool) -> Vector2i:
	for off: Vector2i in _OFFSETS:
		var cell: Vector2i = inst._phi.positions()[link.unit_b] + off
		var hypo: Dictionary[int, Vector2i] = inst._phi.positions_with(link.unit_a, cell)
		var links: Array[AffinityLink] = inst._phi.links()
		var tuning: AffinityTuning = inst._state.affinity_tuning
		# 折損必須改變【候選格那一側】的值,否則只動「當前格」側的 mutant 抓不到
		var at_differs: bool = AffinityRules.bonus_for_at(link.unit_a, cell, hypo, links, tuning, inst._phi.wear_callable()) != AffinityRules.bonus_for_at(link.unit_a, cell, hypo, links, tuning)
		# at_side_only=false:改要求整體預覽差值不同(給「兩側都不傳」的間諜用)
		var r: Array[int] = _preview_and_expected(inst, link, off)
		if (at_side_only and at_differs) or (not at_side_only and r[1] != r[2]):
			return off
	return Vector2i(99, 99)


## 預覽差值(畫面實際回報)與用同一個 wear 來源算出的期望值。回傳 [實際, 期望, 無折損期望]。
func _preview_and_expected(inst: BattleScreen, link: AffinityLink, offset: Vector2i) -> Array[int]:
	var a: int = link.unit_a
	var positions: Dictionary[int, Vector2i] = inst._phi.positions()
	var cell: Vector2i = positions[link.unit_b] + offset
	var hypo: Dictionary[int, Vector2i] = inst._phi.positions_with(a, cell)
	var links: Array[AffinityLink] = inst._phi.links()
	var tuning: AffinityTuning = inst._state.affinity_tuning
	var expected: int = AffinityRules.bonus_for_at(a, cell, hypo, links, tuning, inst._phi.wear_callable()) - inst._phi.phi_of(a)
	var no_wear: int = AffinityRules.bonus_for_at(a, cell, hypo, links, tuning) - AffinityRules.bonus_for(a, positions, links, tuning)
	return [inst._guess_delta_for_cell(a, cell), expected, no_wear]


func test_screen_preview_phi_includes_wear_same_source_as_battle_phi() -> void:
	var inst: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(inst)
	var link: AffinityLink = _wear_first_link_pair(inst, 1)
	var off: Vector2i = _effective_offset(inst, link, true)
	assert_bool(off != Vector2i(99, 99)).is_true()  # 夾具有效:存在折損會改變預覽值的格
	var r: Array[int] = _preview_and_expected(inst, link, off)
	assert_int(r[0]).is_equal(r[1])


func test_sensitivity_proof_screen_without_wear_callable_is_caught() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	var mutant: BattleScreen = scene.instantiate()
	mutant.set_script(_MutantNoWearCallable)
	auto_free(mutant)
	add_child(mutant)
	var link: AffinityLink = _wear_first_link_pair(mutant, 1)
	var off: Vector2i = _effective_offset(mutant, link, false)
	assert_bool(off != Vector2i(99, 99)).is_true()
	var r: Array[int] = _preview_and_expected(mutant, link, off)
	assert_int(r[0]).is_not_equal(r[1])  # mutant 的預覽與正確期望不同 => 上一條測試對它會紅


# ==== 其餘呼叫點:移動預覽(兩行)、hover 資訊、_displayed_guard_at ======================
# 做法:對真實 BattleScreen 驅動既有游標狀態 -> _refresh_view() -> 讀 _info_label.text;
# 預言機只用 AffinityRules + _phi.wear_callable()(+公開 static 格式化函式),不重寫扣減規則。
# 夾具先搜尋「折損確實改變該呼叫點輸出」的 (單位, 格),找不到就紅(不靜默通過)。

func _boot_worn() -> BattleScreen:
	var inst: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(inst)
	# 對每條現存線的配對都加滿折損(cap 3),讓 POS 相鄰與 NEG 都有牙。
	var st: BattleState = inst._state
	for link: AffinityLink in inst._phi.links():
		var ca: AffinityTypes.Character = AffinityRosterCharacterMapper.character_for_roster_id(link.unit_a)
		var cb: AffinityTypes.Character = AffinityRosterCharacterMapper.character_for_roster_id(link.unit_b)
		var pair: int = int(AffinityTypes.pair_of(ca, cb))
		st.commit_authoritative_change(func() -> void: st.add_pair_wear(pair, 3, 3))
	return inst


func _drive(inst: BattleScreen, cell: Vector2i) -> String:
	inst._cursor_cell = cell
	inst._cursor_active = true
	inst._refresh_view()
	return inst._info_label.text


func _linked_player_ids(inst: BattleScreen) -> Array[int]:
	var ids: Array[int] = []
	for link: AffinityLink in inst._phi.links():
		if not ids.has(link.unit_a):
			ids.append(link.unit_a)
		if not ids.has(link.unit_b):
			ids.append(link.unit_b)
	return ids


func test_move_preview_lines_include_wear_both_current_and_preview_side() -> void:
	var inst: BattleScreen = _boot_worn()
	assert_bool(inst.is_hide_affinity_display_for_this_battle()).is_false()
	var links: Array[AffinityLink] = inst._phi.links()
	var tuning: AffinityTuning = inst._state.affinity_tuning
	var w: Callable = inst._phi.wear_callable()
	var found: bool = false
	for a: int in _linked_player_ids(inst):
		if not inst._controller.select_unit(a):
			continue
		var positions: Dictionary[int, Vector2i] = inst._phi.positions()
		for cell: Vector2i in inst._controller.move_targets().cells:
			var hypo: Dictionary[int, Vector2i] = inst._phi.positions_with(a, cell)
			var cur: int = AffinityRules.bonus_for(a, positions, links, tuning, w)
			var prev: int = AffinityRules.bonus_for_at(a, cell, hypo, links, tuning, w)
			var cur_nw: int = AffinityRules.bonus_for(a, positions, links, tuning)
			var prev_nw: int = AffinityRules.bonus_for_at(a, cell, hypo, links, tuning)
			var text: String = BattleScreen.format_affinity_preview(cur, prev)
			# 兩行各自被拿掉都要能被抓到:兩個單邊 mutant 的輸出都必須與正解不同。
			if text == BattleScreen.format_affinity_preview(cur_nw, prev) or text == BattleScreen.format_affinity_preview(cur, prev_nw):
				continue
			found = true
			assert_bool(_drive(inst, cell).contains(text)).is_true()
			return
	assert_bool(found).is_true()  # 夾具:存在一組讓兩側折損都可見的 (單位, 格)


func test_hover_info_includes_wear() -> void:
	var inst: BattleScreen = _boot_worn()
	var links: Array[AffinityLink] = inst._phi.links()
	var tuning: AffinityTuning = inst._state.affinity_tuning
	var w: Callable = inst._phi.wear_callable()
	var positions: Dictionary[int, Vector2i] = inst._phi.positions()
	var found: bool = false
	for u: int in _linked_player_ids(inst):
		var with_w: int = AffinityRules.bonus_for(u, positions, links, tuning, w)
		if with_w == AffinityRules.bonus_for(u, positions, links, tuning):
			continue
		found = true
		assert_int(inst._controller.selected_unit()).is_equal(-1)
		assert_str(_drive(inst, positions[u])).is_equal(BattleScreen.format_affinity_current(with_w))
		break
	assert_bool(found).is_true()


func test_displayed_guard_in_move_preview_includes_wear() -> void:
	var inst: BattleScreen = _boot_worn()
	var links: Array[AffinityLink] = inst._phi.links()
	var tuning: AffinityTuning = inst._state.affinity_tuning
	var ct: CombatTuning = inst._state.combat_tuning
	var w: Callable = inst._phi.wear_callable()
	var found: bool = false
	for a: int in _linked_player_ids(inst):
		if not inst._controller.select_unit(a):
			continue
		var positions: Dictionary[int, Vector2i] = inst._phi.positions()
		for cell: Vector2i in inst._controller.move_targets().cells:
			var hypo: Dictionary[int, Vector2i] = inst._phi.positions_with(a, cell)
			var lone_now: int = inst._state.lone_guard_if_at(a, positions[a])
			var lone_after: int = inst._state.lone_guard_if_at(a, cell)
			var now_w: int = BattleScreen.displayed_guard(AffinityRules.bonus_for(a, positions, links, tuning, w), lone_now, false, ct)
			var after_w: int = BattleScreen.displayed_guard(AffinityRules.bonus_for_at(a, cell, hypo, links, tuning, w), lone_after, false, ct)
			var now_nw: int = BattleScreen.displayed_guard(AffinityRules.bonus_for(a, positions, links, tuning), lone_now, false, ct)
			var after_nw: int = BattleScreen.displayed_guard(AffinityRules.bonus_for_at(a, cell, hypo, links, tuning), lone_after, false, ct)
			var gt: String = BattleScreen.format_guard_move(now_w, after_w)
			if gt == "" or gt == BattleScreen.format_guard_move(now_nw, after_nw):
				continue
			found = true
			assert_bool(_drive(inst, cell).contains(gt)).is_true()
			return
	assert_bool(found).is_true()
