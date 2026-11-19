# story-021 第一輪:關係三態顯示 —— 戰場資訊卡 + 手牌雙人卡 Z2/Z3(棋盤友敵線、關係圖面板留待下一輪)。
# 載入【真實】BattleScreen.tscn,讀真實節點;三態只由 AffinityRelation.state_of 判定(UI 不自判)。
#
# 檔案存取:甲類例外 —— 唯讀 assets/data/ 版控夾具(地形/名冊/牌表/旋鈕/好感度),不寫入任何檔案。
# 無法改用注入:要證的正是 BattleScreen 讀資料檔、建池、接線、更新資訊卡/手牌那條路徑。
# ⚠️ 不證明窮盡性。
#
# 注入順序:instantiate() -> set_script()(僅 mutant)-> 設 override -> add_child()
# (set_script() 必須先於設 override,見 coding-standards)。
#
# 夾具相容:vs01_terrain + vs01_roster(我方 1~5,5 = 騎牆者)+ tutorial_no_links(開局池無記錄,
# 十組皆 n==0 = 冷淡),狀態由測試用 append_record 驅動。手牌段用 test_fixture_cards_cost 的 pair_card
# (名冊 test_fixture_roster_card_cost 的 1、2 號)。
#
# 敏感度證明(常駐 test_sensitivity_proof_*,一個 mutant 一次):
#   ① 自帶門檻 k(0.5)-> AC3 情境回 false     ② 三態恆顯示同一詞(= 只換形狀/顏色不換字)-> AC1 情境回 false
#   ③ 快取顯示(只算第一次)-> AC2 情境回 false  ④ 騎牆恆顯示「有效」(自算而非讀判定)-> AC2 騎牆情境回 false
# 誠實登記未證項:
#   ⑤「手牌 Z2 只換顏色不換字」—— 本實作 Z2 沒有顏色通道可換,字與形狀由同一個三態值決定;
#   以 AC1 對手牌段直接斷言「字 + 形狀種類逐態不同」,沒有另做 mutant。
#   ⑥ 騎牆「失效 -> 再變回有效」未測:池只有 append,沒有可在測試內合法衰減的入口(衰減是時間流逝的事),
#   AC2 只證「有效 -> 失效」翻轉下一幀反映;變回有效由 straddle_valid 讀判定保證(同一個讀路徑,不快取)。
#   ⑦ 像素/灰階截圖與 Check 5 人眼確認(AC4)本輪未做;Check 4 世界層:N/A(資訊卡與手牌皆介面層)。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const _ROSTER_VS01: String = "res://assets/data/units/vs01_roster.txt"
const _ROSTER_CARD: String = "res://assets/data/units/test_fixture_roster_card_cost.txt"
const _CARDS: String = "res://assets/data/cards/test_fixture_cards_cost.txt"
const _AFFINITY: String = "res://assets/data/affinity/tutorial_no_links.txt"
const _TUNING: String = "res://assets/data/tuning/test_fixture_tuning_card_cost_nondefault.txt"

const _KEY_LINE: StringName = &"battle.tile_info.relation_line_format"
const _KEY_STRADDLE_LINE: StringName = &"battle.relation.straddle.line_format"
const _KEY_STRADDLE_ON: StringName = &"battle.relation.straddle.on"
const _KEY_STRADDLE_OFF: StringName = &"battle.relation.straddle.off"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()


func after_test() -> void:
	_host_snap.restore()
	CampaignProgress.reset_for_test()


# ---- mutants ----------------------------------------------------------------

## ① 自帶門檻:不讀 affinity_tuning,寫死 k = 0.5。
class _MutantOwnThreshold extends BattleScreen:
	func relation_state_between(a_id: int, b_id: int) -> int:
		var pair: Variant = CardCostPlan.pair_of_units(a_id, b_id)
		if pair == null:
			return -1
		return int(AffinityRelation.state_of(_affinity_pool, int(pair) as AffinityTypes.Pair, 0.5))


## ② 三態恆顯示「好感」的字與形(= 狀態不同、畫面不換字不換形)。
class _MutantSameWord extends BattleScreen:
	func _tile_info_relation_rows_for(occupant: Unit) -> Array[Dictionary]:
		var rows: Array[Dictionary] = super(occupant)
		for row: Dictionary in rows:
			if row["kind"] == RelationBadge.Kind.NONE or row["kind"] == RelationBadge.Kind.NEG:
				row["kind"] = RelationBadge.Kind.POS
				row["text"] = Loc.localize(&"battle.tile_info.relation_line_format") % [
					Loc.character_name(1), Loc.localize(&"battle.relation.state.pos")
				]
		return rows


## ③ 快取:第一次算出的列內容永遠沿用。
class _MutantCached extends BattleScreen:
	var _cached: Array[Dictionary] = []
	var _has_cache: bool = false

	func _tile_info_relation_rows_for(occupant: Unit) -> Array[Dictionary]:
		if not _has_cache:
			_cached = super(occupant)
			_has_cache = true
		return _cached


## ④ 騎牆自算:恆為有效,不讀判定。
class _MutantStraddleAlwaysOn extends BattleScreen:
	func _tile_info_relation_rows_for(occupant: Unit) -> Array[Dictionary]:
		var rows: Array[Dictionary] = super(occupant)
		for row: Dictionary in rows:
			if row["kind"] == RelationBadge.Kind.STRADDLE_OFF:
				row["kind"] = RelationBadge.Kind.STRADDLE_ON
				row["text"] = Loc.localize(_KEY_STRADDLE_LINE) % Loc.localize(_KEY_STRADDLE_ON)
		return rows


# ---- 夾具/輔助 ---------------------------------------------------------------

func _load_screen(script: GDScript = null, roster: String = _ROSTER_VS01) -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	if script != null:
		instance.set_script(script)
	instance.terrain_path_override = _TERRAIN
	instance.roster_path_override = roster
	instance.cards_path_override = _CARDS
	instance.affinity_path_override = _AFFINITY
	instance.tuning_path_override = _TUNING
	add_child(instance)
	return instance


func _discard(instance: BattleScreen) -> void:
	remove_child(instance)
	instance.free()


func _pair_of(a: int, b: int) -> AffinityTypes.Pair:
	return CardCostPlan.pair_of_units(a, b) as AffinityTypes.Pair


func _write(screen: BattleScreen, a: int, b: int, m: float) -> bool:
	var rejection: AffinityDataPool.WriteRejection = screen._affinity_pool.append_record(
		_pair_of(a, b), m, AffinityTypes.Source.STORY_EVENT
	)
	return rejection == AffinityDataPool.WriteRejection.NONE


## 選取 selected_id、游標停在 cursor_id 的格子,刷新資訊卡並回傳其關係列。
func _rows(screen: BattleScreen, selected_id: int, cursor_id: int) -> Array[Dictionary]:
	if selected_id != -1 and screen._controller.selected_unit() != selected_id:
		screen._controller.select_unit(selected_id)
	screen._cursor_cell = screen._state.position_of(cursor_id)
	screen._cursor_active = true
	screen._tile_info_cursor_valid = true
	screen._update_tile_info_panel()
	return screen.diagnostic_tile_info_relation_rows()


func _line(selected_id: int, state_key: StringName) -> String:
	return Loc.localize(_KEY_LINE) % [Loc.character_name(selected_id), Loc.localize(state_key)]


func _oracle(screen: BattleScreen, a: int, b: int) -> int:
	return int(AffinityRelation.state_of(
		screen._affinity_pool, _pair_of(a, b), screen._state.affinity_tuning.neutral_band()
	))


# ---- 情境函式(真品回 true;mutant 回 false)---------------------------------------

## AC1 + AC2(資訊卡):冷淡 -> 好感 -> 敵意,每態文字與徽記形狀皆專屬,且每次變動下一次刷新即反映。
func _scn_info_card_three_states(script: GDScript = null) -> bool:
	var s: BattleScreen = _load_screen(script)
	if s._load_failed or s._controller == null:
		_discard(s)
		return false
	var ok: bool = true
	var seen_kinds: Array[int] = []
	var seen_texts: Array[String] = []
	var steps: Array = [
		[null, &"battle.relation.state.none", RelationBadge.Kind.NONE],
		[1.0, &"battle.relation.state.pos", RelationBadge.Kind.POS],
		[-1.0, &"battle.relation.state.neg", RelationBadge.Kind.NEG],
	]
	for step: Array in steps:
		if step[0] != null:
			# 敵意:持續寫入負記錄直到判定翻成 NEG(以判定本身為準,不假設單筆即翻轉)。
			var guard: int = 0
			while _oracle(s, 1, 2) != AffinityRelation.RelationState.NEG and step[0] < 0.0 and guard < 12:
				ok = _write(s, 1, 2, step[0]) and ok
				guard += 1
			if step[0] > 0.0:
				ok = _write(s, 1, 2, step[0]) and ok
		var rows: Array[Dictionary] = _rows(s, 1, 2)
		if rows.size() != 1:
			ok = false
			continue
		ok = (rows[0]["text"] == _line(1, step[1])) and ok
		ok = (rows[0]["kind"] == step[2]) and ok
		seen_kinds.append(int(rows[0]["kind"]))
		seen_texts.append(String(rows[0]["text"]))
	_discard(s)
	var distinct_kinds: Dictionary = {}
	for k: int in seen_kinds:
		distinct_kinds[k] = true
	var distinct_texts: Dictionary = {}
	for t: String in seen_texts:
		distinct_texts[t] = true
	return ok and distinct_kinds.size() == 3 and distinct_texts.size() == 3


## AC3:十組各自顯示 == state_of 輸出;其中兩組以 ±0.3 的小記錄驅動(讓自帶門檻者與判定分歧)。
func _scn_ten_pairs_match_state_of(script: GDScript = null) -> bool:
	var s: BattleScreen = _load_screen(script)
	if s._load_failed or s._controller == null:
		_discard(s)
		return false
	var ok: bool = _write(s, 1, 2, 0.3) and _write(s, 3, 5, -0.3) and _write(s, 2, 4, 1.0)
	for a: int in range(1, 6):
		for b: int in range(a + 1, 6):
			ok = (s.relation_state_between(a, b) == _oracle(s, a, b)) and ok
	_discard(s)
	return ok


## AC2(騎牆):全冷淡 = 有效;寫入任一組非冷淡 -> 下一次刷新變失效;非騎牆者(單位 1)永遠沒有騎牆列。
func _scn_straddle_flips(script: GDScript = null) -> bool:
	var s: BattleScreen = _load_screen(script)
	if s._load_failed or s._controller == null:
		_discard(s)
		return false
	var on_line: String = Loc.localize(_KEY_STRADDLE_LINE) % Loc.localize(_KEY_STRADDLE_ON)
	var off_line: String = Loc.localize(_KEY_STRADDLE_LINE) % Loc.localize(_KEY_STRADDLE_OFF)
	var ok: bool = s._phi.straddle_valid(5)
	var rows: Array[Dictionary] = _rows(s, -1, 5)
	ok = (rows.size() == 1 and rows[0]["text"] == on_line and rows[0]["kind"] == RelationBadge.Kind.STRADDLE_ON) and ok
	ok = _write(s, 5, 3, 1.0) and ok
	ok = (not s._phi.straddle_valid(5)) and ok
	rows = _rows(s, -1, 5)
	ok = (rows.size() == 1 and rows[0]["text"] == off_line and rows[0]["kind"] == RelationBadge.Kind.STRADDLE_OFF) and ok
	rows = _rows(s, -1, 1)
	ok = rows.is_empty() and ok
	_discard(s)
	return ok


# ---- 測試 ---------------------------------------------------------------------

func test_ac1_info_card_three_states_have_exclusive_text_and_shape() -> void:
	assert_bool(_scn_info_card_three_states()).is_true()


func test_ac2_info_card_updates_next_refresh_after_pool_write() -> void:
	# _scn_info_card_three_states 內每次寫池後只呼叫一次 _update_tile_info_panel() 就斷言新內容。
	assert_bool(_scn_info_card_three_states()).is_true()


func test_ac3_ten_pairs_display_equals_state_of() -> void:
	assert_bool(_scn_ten_pairs_match_state_of()).is_true()


func test_ac2_straddle_shown_only_on_straddler_and_flips_to_invalid() -> void:
	assert_bool(_scn_straddle_flips()).is_true()


func test_info_card_no_relation_row_when_nothing_selected() -> void:
	var s: BattleScreen = _load_screen()
	var rows: Array[Dictionary] = _rows(s, -1, 2)
	_discard(s)
	assert_array(rows).is_empty()


func test_badge_shapes_are_pairwise_distinct_and_color_independent() -> void:
	# 形狀通道:五種徽記的源像素集合兩兩不同;NONE(冷淡)不含任何橫線(連續兩格同列)。
	var kinds: Array[RelationBadge.Kind] = [
		RelationBadge.Kind.POS, RelationBadge.Kind.NEG, RelationBadge.Kind.NONE,
		RelationBadge.Kind.STRADDLE_ON, RelationBadge.Kind.STRADDLE_OFF,
	]
	var seen: Dictionary = {}
	for k: RelationBadge.Kind in kinds:
		var cells: Array[Vector2i] = RelationBadge.pixels_of(k)
		var sorted_cells: Array[String] = []
		for c: Vector2i in cells:
			sorted_cells.append("%d,%d" % [c.x, c.y])
		sorted_cells.sort()
		seen["|".join(PackedStringArray(sorted_cells))] = true
	assert_int(seen.size()).is_equal(5)
	var none_cells: Array[Vector2i] = RelationBadge.pixels_of(RelationBadge.Kind.NONE)
	for c: Vector2i in none_cells:
		# 環不是線:任何橫向連續段 <= 3 格(3 連 = 本格 + 右側 1、2 格再加 3 格 = 4 連才算違規),短於 POS 實線 7 格。
		assert_bool(
			none_cells.has(c + Vector2i(1, 0)) and none_cells.has(c + Vector2i(2, 0))
			and none_cells.has(c + Vector2i(3, 0))
		).is_false()


# ---- 手牌 Z2 / Z3 ---------------------------------------------------------------

func _hand_index_of(s: BattleScreen, card_id: String) -> int:
	var hand: Array[Card] = s._state.card_deck().hand()
	for i: int in range(hand.size()):
		if hand[i].id == card_id:
			return i
	return -1


func test_hand_pair_card_z2_shows_state_word_and_shape_per_state_z3_shows_names() -> void:
	var s: BattleScreen = _load_screen(null, _ROSTER_CARD)
	assert_bool(s._load_failed).is_false()
	var idx: int = _hand_index_of(s, "pair_card")
	assert_int(idx).append_failure_message("PRECONDITION: pair_card 在手牌").is_greater_equal(0)
	var expect: Array = [
		[&"battle.relation.state.none", RelationBadge.Kind.NONE],
		[&"battle.relation.state.pos", RelationBadge.Kind.POS],
	]
	for step: Array in expect:
		s._refresh_view()
		var mark: Dictionary = s._hand_bar.diagnostic_slot_relation(idx)
		assert_bool(mark["has"]).is_true()
		assert_str(mark["text"]).is_equal(Loc.localize(step[0]))
		assert_int(mark["badge_kind"]).is_equal(step[1])
		assert_bool(_write(s, 1, 2, 1.0)).is_true()
	# Z3:姓名行 + 原卡面文字(020b 的三段分區不動:原因行仍是原因行)。
	var face: Dictionary = s._hand_bar._card_faces[idx]
	assert_str(face["pair_names"]).is_equal(Loc.character_name(1) + "×" + Loc.character_name(2))
	s._hand_bar._expand_progress = 1.0
	s._hand_bar._cursor_index = idx
	s._hand_bar._update_detail_panel_content()
	assert_str(s._hand_bar.diagnostic_detail_panel_text()).starts_with(String(face["pair_names"]) + "\n")
	assert_str(s._hand_bar.diagnostic_detail_reason_text()).is_equal(String(face["unplayable_reason"]))
	_discard(s)


func test_hand_single_person_card_has_no_relation_mark() -> void:
	var s: BattleScreen = _load_screen(null, _ROSTER_CARD)
	var idx: int = _hand_index_of(s, "hp_card")
	if idx >= 0:
		assert_bool(s._hand_bar.diagnostic_slot_relation(idx)["has"]).is_false()
		assert_str(String(s._hand_bar._card_faces[idx]["pair_names"])).is_empty()
	_discard(s)


# ---- 敏感度證明 -----------------------------------------------------------------

func test_sensitivity_proof_own_threshold_is_caught_by_ten_pairs_scenario() -> void:
	assert_bool(_scn_ten_pairs_match_state_of(_MutantOwnThreshold)).is_false()


func test_sensitivity_proof_same_word_for_all_states_is_caught_by_ac1_scenario() -> void:
	assert_bool(_scn_info_card_three_states(_MutantSameWord)).is_false()


func test_sensitivity_proof_cached_display_is_caught_by_ac2_scenario() -> void:
	assert_bool(_scn_info_card_three_states(_MutantCached)).is_false()


func test_sensitivity_proof_straddle_always_on_is_caught_by_straddle_scenario() -> void:
	assert_bool(_scn_straddle_flips(_MutantStraddleAlwaysOn)).is_false()
