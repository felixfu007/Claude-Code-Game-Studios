# Story 061 — 鞋/劍圖示放大並移進格內右側(加深色襯底)。
# production/epics/tactical-combat/story-061-action-icons-enlarge-inside-cell.md
#
# 屬性:本檔不讀任何檔案(無 FileAccess/DirAccess);像素預言機取自 BoardView 的
# SWORD_ICON_ROWS / SHOE_ICON_ROWS 常數;游標白框粗細用 load() 取得貼圖資源後讀 alpha
# 量測(引擎資源載入,非檔案 I/O)。
#
# ⚠️ headless 不 rasterize:本檔只驗節點結構/矩形/貼圖來源。「看起來像鞋/劍」、
# 「襯底是否遮角色右半身」是 AC5 的人眼判讀,不在本檔。
#
# 🔴 AC1 明文例外(管理者 2026-11-18 裁決「接受重疊,加保護測試」;art 文件
#   docs/reviews/story-061-stamp-backdrop-conflict-art-2026-11-18.md):被擋章
#   BLOCKED_STAMP_RECT 與襯底/鞋/劍相交,因此 _obstacles() 不含被擋章;重疊量由
#   test_action_icon_blocked_stamp_overlap_exception_is_pinned_exactly 釘死,其前提(章只畫敵兵格、
#   襯底只畫我方格,永不同格)由 test_blocked_stamp_cells_and_action_icon_cells_are_mutually_exclusive_on_real_screen
#   取真實 BattleScreen 驗證。⚠️ 48 格版,或將來讓敵方也畫圖示之前,此例外必須重新裁決,
#   不得沿用。本測試檔含一支甲類讀取(載入真實 vs01 資料,唯讀;無法以注入取代,因為要驗的就是
#   真實 BattleScreen 的篩選與棋子來源);不證明窮盡 —— 只驗 vs01 預設盤面。
#
# 量測原則:幾何一律量【實際建出的節點】(襯底 ColorRect、圖示 Sprite2D)的矩形,
# 不直接讀 *_icon_rect_in_cell() 當實際值 —— 否則敏感度證明無法偏離預言機。
# 預言機(障礙矩形)取自 BoardView 的既有格內矩形函式。
#
# 敏感度證明:每個 mutant 是常駐子類別 + 一條「會通過」的 test_sensitivity_proof_*,
# 斷言偵測器確實抓到植入缺陷;mutant 一律先 set_script() 再設屬性、且在 add_child() 之前。
#   ① 圖示畫回舊位置(y<0)→ AC1   ② 襯底左緣寫死 12 → AC2   ③ 劍右緣貼格緣 → AC1
#   ④ 襯底頂蓋進 HP 文字條 → AC1  ⑤ 襯底加高蓋到血條 → AC1   ⑥ 貼圖每次重建 → AC3
#   ⑦ 圖例另畫一份(偏 1px)→ 同源測試   ⑧ 皆未用仍畫襯底 → AC4
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BoardView.tscn"
const _CELL: Vector2i = Vector2i(2, 2)
const _BACKDROP_NAME: String = "ActionIconBackdrop"
## 054 舊位置(像素尺寸 6×7 / 5×7,y<0 的頭頂突出帶);只用於「新位置 != 舊位置」防空洞。
const _OLD_SHOE_RECT: Rect2 = Rect2(0, -7, 6, 7)
const _OLD_SWORD_RECT: Rect2 = Rect2(27, -7, 5, 7)
## AC2 間諜:把首字框加寬到 18(原 12)。
const _SPY_LABEL: Rect2 = Rect2(0.0, 8.0, 18.0, 14.0)
const _EDGE_MARGIN: float = 2.0


var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


# ─── 夾具 ──────────────────────────────────────────────────────────────────────

func _make_view(mutant: Script = null) -> BoardView:
	var instance: BoardView = auto_free(load(_SCENE_PATH).instantiate())
	if mutant != null:
		instance.set_script(mutant)
	add_child(instance)
	return instance


func _render_one(view: BoardView, faction: String, extra: Dictionary) -> void:
	var piece: Dictionary = {
		"cell": _CELL, "faction": faction, "sprite_index": 0, "hp": 10, "hp_max": 10,
	}
	piece.merge(extra, true)
	var pieces: Array[Dictionary] = [piece]
	view.render_pieces(pieces)


func _render_done(view: BoardView) -> void:
	_render_one(view, "PLAYER", {"action_flag": BoardView.ActionFlag.DONE})


func _origin() -> Vector2:
	return BoardCoords.grid_to_local(_CELL)


func _flag_layer(view: BoardView) -> Node:
	return view.get_node("ActionFlagLayer")


func _backdrop_nodes(view: BoardView) -> Array[ColorRect]:
	var out: Array[ColorRect] = []
	_collect_rects(_flag_layer(view), out)
	return out


func _collect_rects(node: Node, out: Array[ColorRect]) -> void:
	if node is ColorRect and String(node.name) == _BACKDROP_NAME:
		out.append(node)
	for child: Node in node.get_children():
		_collect_rects(child, out)


func _icon_sprite(view: BoardView, node_name: String) -> Sprite2D:
	return _flag_layer(view).find_child(node_name, true, false) as Sprite2D


## 實際節點矩形(相對格左上)。找不到回 Rect2() 並由呼叫端判斷。
func _backdrop_rect(view: BoardView) -> Rect2:
	var nodes: Array[ColorRect] = _backdrop_nodes(view)
	if nodes.is_empty():
		return Rect2()
	return Rect2(nodes[0].position - _origin(), nodes[0].size)


func _sprite_rect(view: BoardView, node_name: String) -> Rect2:
	var s: Sprite2D = _icon_sprite(view, node_name)
	if s == null:
		return Rect2()
	return Rect2(s.position - _origin(), s.texture.get_size())


## 游標白框(實際貼圖量測):貼圖 alpha==1 的外圈厚度,四條帶狀矩形(格內座標,游標置中於格)。
func _cursor_frame_rects() -> Array[Rect2]:
	var img: Image = (load(BoardView.CURSOR_PATH) as Texture2D).get_image()
	var mid: int = img.get_height() / 2
	var t: int = 0
	while t < img.get_width() and img.get_pixel(t, mid).a >= 1.0:
		t += 1
	var w: float = float(img.get_width())
	var h: float = float(img.get_height())
	var tf: float = float(t)
	var rects: Array[Rect2] = []
	rects.append(Rect2(0.0, 0.0, w, tf))
	rects.append(Rect2(0.0, h - tf, w, tf))
	rects.append(Rect2(0.0, 0.0, tf, h))
	rects.append(Rect2(w - tf, 0.0, tf, h))
	return rects


## 與襯底/圖示必須不相交的障礙矩形(名稱 → 矩形)。被擋章另案(見 known_conflict 測試)。
func _obstacles() -> Dictionary:
	var out: Dictionary = {
		"piece_label": BoardView.piece_label_rect_in_cell(),
		"hp_text": BoardView.hp_text_rect_in_cell(),
		"hp_bar": BoardView.hp_bar_rect_in_cell(),
	}
	var i: int = 0
	for r: Rect2 in BoardView.attack_ring_rects_in_cell():
		out["attack_ring_%d" % i] = r
		i += 1
	i = 0
	for r: Rect2 in BoardView.threat_ring_rects_in_cell():
		out["threat_ring_%d" % i] = r
		i += 1
	i = 0
	for r: Rect2 in _cursor_frame_rects():
		out["cursor_frame_%d" % i] = r
		i += 1
	return out


## AC1 偵測器:回傳違規描述清單(空 = 全部成立)。AC1 測試與敏感度證明共用。
func _geometry_violations(view: BoardView) -> Array[String]:
	var v: Array[String] = []
	var backdrop: Rect2 = _backdrop_rect(view)
	var shoe: Rect2 = _sprite_rect(view, "ShoeIcon")
	var sword: Rect2 = _sprite_rect(view, "SwordIcon")
	if backdrop == Rect2() or shoe == Rect2() or sword == Rect2():
		v.append("missing node (backdrop/shoe/sword)")
		return v
	var cell: float = float(BoardCoords.CELL_SIZE)
	var named: Dictionary = {"backdrop": backdrop, "shoe": shoe, "sword": sword}
	var obstacles: Dictionary = _obstacles()
	for n: String in named:
		var r: Rect2 = named[n]
		for o: String in obstacles:
			if r.intersects(obstacles[o]):
				v.append("%s intersects %s" % [n, o])
		# 正上方一格的血條(平移 -CELL 高)
		var bar_above: Rect2 = BoardView.hp_bar_rect_in_cell()
		bar_above.position.y -= cell
		if r.intersects(bar_above):
			v.append("%s intersects hp bar of cell above" % n)
		# 格內界:y >= 0(已離開頭頂突出帶),右側離格緣 >= 2px
		if r.position.x < 0.0 or r.position.y < 0.0 or r.end.y > cell:
			v.append("%s outside cell" % n)
		if r.end.x > cell - _EDGE_MARGIN:
			v.append("%s closer than %.0fpx to right cell edge" % [n, _EDGE_MARGIN])
	if not backdrop.encloses(shoe) or not backdrop.encloses(sword):
		v.append("backdrop does not enclose icons")
	if shoe.intersects(sword):
		v.append("shoe intersects sword")
	if not shoe.end.x <= sword.position.x:
		v.append("shoe not strictly left of sword")
	return v


# ─── AC1 幾何互不相交 ──────────────────────────────────────────────────────────

func test_action_icon_geometry_disjoint_from_neighbours_and_inside_cell() -> void:
	var view: BoardView = _make_view()
	_render_done(view)
	var violations: Array[String] = _geometry_violations(view)
	assert_array(violations).append_failure_message("AC1 違規:%s" % [violations]).is_empty()


func test_action_icon_geometry_values_for_32px_cell() -> void:
	# 工單預期值(32 格):襯底 x12~30 y9~21;鞋 (13,10) 9×10;劍 (22,10) 7×10。
	var view: BoardView = _make_view()
	_render_done(view)
	assert_object(_backdrop_rect(view)).is_equal(Rect2(12, 9, 18, 12))
	assert_object(_sprite_rect(view, "ShoeIcon")).is_equal(Rect2(13, 10, 9, 10))
	assert_object(_sprite_rect(view, "SwordIcon")).is_equal(Rect2(22, 10, 7, 10))


func test_action_icon_cursor_frame_thickness_measured_from_real_texture() -> void:
	# 記錄當場量測值:游標白框(alpha==1 外圈)厚度。若 >=2 則襯底右緣(x30)會與之相接,須回 art。
	var frame: Array[Rect2] = _cursor_frame_rects()
	assert_float(frame[3].size.x).append_failure_message(
		"游標白框厚度改變,AC1 的相容性假設須重審").is_equal(1.0)


func test_action_icon_new_rects_differ_from_054_old_positions() -> void:
	var view: BoardView = _make_view()
	_render_done(view)
	assert_bool(_sprite_rect(view, "ShoeIcon").position == _OLD_SHOE_RECT.position).is_false()
	assert_bool(_sprite_rect(view, "SwordIcon").position == _OLD_SWORD_RECT.position).is_false()
	assert_bool(_sprite_rect(view, "ShoeIcon").position.y >= 0.0).is_true()


func test_action_icon_blocked_stamp_overlap_exception_is_pinned_exactly() -> void:
	# 管理者 2026-11-18 裁決「接受重疊,加保護測試」:被擋章 BLOCKED_STAMP_RECT (21,8,6,6)
	# 與襯底、鞋、劍的相交量逐項釘死(取自實際矩形函式,不寫死襯底/圖示座標)。
	# 常數(章、襯底、圖示任一)一動,下列任一相交量改變即紅 —— 此時須重新裁決,不得只改數字。
	var stamp: Rect2 = BoardView.BLOCKED_STAMP_RECT
	assert_object(BoardView.action_icon_backdrop_rect_in_cell().intersection(stamp)).is_equal(Rect2(21, 9, 6, 5))
	assert_object(BoardView.sword_icon_rect_in_cell().intersection(stamp)).is_equal(Rect2(22, 10, 5, 4))
	assert_object(BoardView.shoe_icon_rect_in_cell().intersection(stamp)).is_equal(Rect2(21, 10, 1, 4))


func test_action_icon_stamp_overlap_exception_pin_follows_instance_nodes() -> void:
	# 同一相交量也用實際建出的節點量一次(防「函式沒變、節點畫在別處」)。
	var view: BoardView = _make_view()
	_render_done(view)
	var stamp: Rect2 = BoardView.BLOCKED_STAMP_RECT
	assert_object(_backdrop_rect(view).intersection(stamp)).is_equal(Rect2(21, 9, 6, 5))
	assert_object(_sprite_rect(view, "SwordIcon").intersection(stamp)).is_equal(Rect2(22, 10, 5, 4))
	assert_object(_sprite_rect(view, "ShoeIcon").intersection(stamp)).is_equal(Rect2(21, 10, 1, 4))


# ─── 例外成立的前提:敵/我方格互斥(取真實 BattleScreen 與 BoardView) ───────────

func _all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in range(32):
		for y: int in range(32):
			cells.append(Vector2i(x, y))
	return cells


func test_blocked_stamp_cells_and_action_icon_cells_are_mutually_exclusive_on_real_screen() -> void:
	# 甲類(讀真實 vs01 資料,唯讀)。前提:被擋章只畫在存活敵兵格(battle_screen 的篩選函式),
	# 襯底/圖示只畫在我方格(BoardView.render_pieces 的 PLAYER 判斷)→ 兩者永不同格,上面釘死的重疊才無害。
	var screen: BattleScreen = auto_free(load("res://src/ui/battle/BattleScreen.tscn").instantiate())
	add_child(screen)
	var stamp_cells: Array[Vector2i] = screen._filter_blocked_to_enemy_cells(_all_cells())
	var enemy_cells: Array[Vector2i] = []
	var player_cells: Array[Vector2i] = []
	var pieces: Array[Dictionary] = []
	for unit: Unit in screen._state.units_of(Unit.Faction.ENEMY):
		enemy_cells.append(screen._state.position_of(unit.id))
	for unit: Unit in screen._state.units_of(Unit.Faction.PLAYER):
		player_cells.append(screen._state.position_of(unit.id))
	for c: Vector2i in enemy_cells:
		pieces.append({"cell": c, "faction": "ENEMY", "sprite_index": 0, "hp": 1, "hp_max": 1,
			"action_flag": BoardView.ActionFlag.DONE})
	for c: Vector2i in player_cells:
		pieces.append({"cell": c, "faction": "PLAYER", "sprite_index": 0, "hp": 1, "hp_max": 1,
			"action_flag": BoardView.ActionFlag.DONE})
	var board: BoardView = screen.get_node("WorldViewportContainer/WorldViewport/BoardView")
	board.render_pieces(pieces)
	# 防空洞:兩邊都非空
	assert_bool(stamp_cells.is_empty()).is_false()
	assert_bool(player_cells.is_empty()).is_false()
	# 被擋章格 = 全為敵兵格、且不含任何我方格
	for c: Vector2i in stamp_cells:
		assert_bool(enemy_cells.has(c)).is_true()
		assert_bool(player_cells.has(c)).is_false()
	# 襯底節點:數量 = 我方格數,位置恰為我方格的襯底位置,沒有任何一個落在敵兵格
	var backdrop_pos: Array[Vector2] = []
	var layer: Node = board.get_node("ActionFlagLayer")
	var found: Array[ColorRect] = []
	_collect_rects(layer, found)
	for n: ColorRect in found:
		backdrop_pos.append(n.position)
	var rel: Vector2 = BoardView.action_icon_backdrop_rect_in_cell().position
	assert_int(backdrop_pos.size()).is_equal(player_cells.size())
	for c: Vector2i in player_cells:
		assert_bool(backdrop_pos.has(BoardCoords.grid_to_local(c) + rel)).is_true()
	for c: Vector2i in enemy_cells:
		assert_bool(backdrop_pos.has(BoardCoords.grid_to_local(c) + rel)).is_false()


func test_sensitivity_proof_icons_at_old_position_detected() -> void:
	var view: BoardView = _make_view(_MutantOldPosition)
	_render_done(view)
	assert_bool(_geometry_violations(view).is_empty()).append_failure_message(
		"mutant① 圖示在 y<0,AC1 偵測器應報違規").is_false()


func test_sensitivity_proof_icon_touching_cell_edge_detected() -> void:
	var view: BoardView = _make_view(_MutantSwordAtEdge)
	_render_done(view)
	var violations: Array[String] = _geometry_violations(view)
	assert_bool(violations.is_empty()).append_failure_message("mutant③ 應報違規").is_false()


func test_sensitivity_proof_backdrop_into_hp_text_detected() -> void:
	var view: BoardView = _make_view(_MutantBackdropIntoHpText)
	_render_done(view)
	var violations: Array[String] = _geometry_violations(view)
	assert_bool(violations.has("backdrop intersects hp_text")).append_failure_message(
		"mutant④ 應報 backdrop intersects hp_text;實得 %s" % [violations]).is_true()


func test_sensitivity_proof_backdrop_into_hp_bar_detected() -> void:
	var view: BoardView = _make_view(_MutantBackdropTooTall)
	_render_done(view)
	var violations: Array[String] = _geometry_violations(view)
	assert_bool(violations.has("backdrop intersects hp_bar")).append_failure_message(
		"mutant⑤ 應報 backdrop intersects hp_bar;實得 %s" % [violations]).is_true()


# ─── AC2 算式同源(相對首字框) ────────────────────────────────────────────────

## AC2 偵測器:在「首字框被間諜改成 _SPY_LABEL」的 view 上,襯底/圖示是否跟著首字框走。
func _follow_violations(view: BoardView) -> Array[String]:
	var v: Array[String] = []
	var backdrop: Rect2 = _backdrop_rect(view)
	var shoe: Rect2 = _sprite_rect(view, "ShoeIcon")
	var hp_text: Rect2 = BoardView.hp_text_rect_in_cell()
	if backdrop.position.x != _SPY_LABEL.end.x:
		v.append("backdrop left %f != label right %f" % [backdrop.position.x, _SPY_LABEL.end.x])
	if backdrop.position.y != hp_text.end.y + 1.0:
		v.append("backdrop top %f != hp_text bottom + 1" % backdrop.position.y)
	if shoe.position != backdrop.position + Vector2(1.0, 1.0):
		v.append("shoe not at backdrop + (1,1)")
	return v


func test_action_icon_layout_derives_from_label_rect_default() -> void:
	# 預設(真首字框):襯底左緣 == 首字框右緣、頂 == HP 文字條下緣 + 1(皆取自函式)。
	var view: BoardView = _make_view()
	_render_done(view)
	var backdrop: Rect2 = _backdrop_rect(view)
	assert_float(backdrop.position.x).is_equal(BoardView.piece_label_rect_in_cell().end.x)
	assert_float(backdrop.position.y).is_equal(BoardView.hp_text_rect_in_cell().end.y + 1.0)
	assert_float(backdrop.end.x).is_equal(float(BoardCoords.CELL_SIZE) - BoardView.ACTION_ICON_BACKDROP_RIGHT_MARGIN)


func test_action_icon_layout_follows_widened_label_rect_instance_path() -> void:
	var view: BoardView = _make_view(_SpyWideLabel)
	_render_done(view)
	var violations: Array[String] = _follow_violations(view)
	assert_array(violations).append_failure_message("AC2 違規:%s" % [violations]).is_empty()


func test_action_icon_layout_follows_widened_label_rect_static_path() -> void:
	# 圖例走的靜態路徑:同一組函式吃同一個注入的首字框。
	assert_float(BoardView.action_icon_backdrop_rect_in_cell(_SPY_LABEL).position.x).is_equal(18.0)
	assert_float(BoardView.shoe_icon_rect_in_cell(_SPY_LABEL).position.x).is_equal(19.0)
	assert_float(BoardView.sword_icon_rect_in_cell(_SPY_LABEL).position.x).is_equal(28.0)


func test_sensitivity_proof_hardcoded_backdrop_left_detected() -> void:
	var view: BoardView = _make_view(_MutantHardcodedLeft)
	_render_done(view)
	assert_bool(_follow_violations(view).is_empty()).append_failure_message(
		"mutant② 襯底左緣寫死 12,間諜改首字框後應不跟著走").is_false()


# ─── AC3 貼圖來源與重用 ────────────────────────────────────────────────────────

func _texture_mismatches(tex: Texture2D, rows: PackedStringArray, light: String) -> int:
	var img: Image = tex.get_image()
	if img.get_width() != rows[0].length() or img.get_height() != rows.size():
		return -1
	var palette: Dictionary = {"O": "26303d", "L": light, "G": "7d766a"}
	var bad: int = 0
	for y: int in range(rows.size()):
		for x: int in range(rows[0].length()):
			var ch: String = rows[y][x]
			var px: Color = img.get_pixel(x, y)
			if ch == ".":
				if px.a != 0.0:
					bad += 1
			elif px.a != 1.0 or px.to_html(false) != palette[ch]:
				bad += 1
	return bad


func test_action_icon_textures_9x10_shoe_7x10_sword_match_art_arrays() -> void:
	assert_int(BoardView.shoe_texture().get_width()).is_equal(9)
	assert_int(BoardView.shoe_texture().get_height()).is_equal(10)
	assert_int(BoardView.sword_texture().get_width()).is_equal(7)
	assert_int(BoardView.sword_texture().get_height()).is_equal(10)
	assert_int(_texture_mismatches(BoardView.shoe_texture(), BoardView.SHOE_ICON_ROWS, "b0a897")).is_equal(0)
	assert_int(_texture_mismatches(BoardView.sword_texture(), BoardView.SWORD_ICON_ROWS, "a9b2bd")).is_equal(0)


func _texture_ids_stable(view: BoardView) -> bool:
	var seen: Dictionary = {}
	for i: int in range(100):
		_render_done(view)
		for node_name: String in ["ShoeIcon", "SwordIcon"]:
			var s: Sprite2D = _icon_sprite(view, node_name)
			seen[s.texture.get_instance_id()] = true
	return seen.size() == 2 \
		and seen.has(BoardView.shoe_texture().get_instance_id()) \
		and seen.has(BoardView.sword_texture().get_instance_id())


func test_action_icon_textures_reused_across_100_redraws() -> void:
	assert_bool(_texture_ids_stable(_make_view())).is_true()


func test_sensitivity_proof_texture_rebuilt_each_time_detected() -> void:
	assert_bool(_texture_ids_stable(_make_view(_MutantTextureRebuilt))).append_failure_message(
		"mutant⑥ 每次重建貼圖,物件 id 應不穩定").is_false()


# ─── AC4 襯底可見性(任一圖示出現才有襯底) ───────────────────────────────────

## 四個我方狀態 + 敵方四狀態併成一格的襯底節點數:[none, move_only(ATTACK_ONLY), attack_only(MOVE_ONLY), done, enemy]
func _backdrop_count_table(view: BoardView) -> Array[int]:
	var table: Array[int] = []
	for flag: int in [BoardView.ActionFlag.NONE_USED, BoardView.ActionFlag.ATTACK_ONLY,
			BoardView.ActionFlag.MOVE_ONLY, BoardView.ActionFlag.DONE]:
		_render_one(view, "PLAYER", {"action_flag": flag})
		table.append(_backdrop_nodes(view).size())
	var enemy_total: int = 0
	for flag: int in [0, 1, 2, 3]:
		_render_one(view, "ENEMY", {"action_flag": flag})
		enemy_total += _backdrop_nodes(view).size()
	table.append(enemy_total)
	return table


func test_action_icon_backdrop_exists_iff_any_icon_drawn() -> void:
	var table: Array[int] = _backdrop_count_table(_make_view())
	assert_array(table).is_equal([0, 1, 1, 1, 0])


func test_sensitivity_proof_backdrop_drawn_when_nothing_used_detected() -> void:
	var table: Array[int] = _backdrop_count_table(_make_view(_MutantAlwaysBackdrop))
	assert_bool(table == [0, 1, 1, 1, 0]).append_failure_message(
		"mutant⑧ 皆未用仍畫襯底,表應偏離;實得 %s" % [table]).is_false()


func test_action_icon_backdrop_lies_below_icons_in_draw_order() -> void:
	var view: BoardView = _make_view()
	_render_done(view)
	var backdrop: Node = _backdrop_nodes(view)[0]
	var shoe: Node = _icon_sprite(view, "ShoeIcon")
	assert_bool(backdrop.get_index() < shoe.get_index()).is_true()


# ─── 圖例同源(story-059 範例走同一組函式) ───────────────────────────────────

func _legend_sample(kind: int) -> Node2D:
	return auto_free(BoardView.build_legend_sample(kind))


## 圖例範例根(格在 (0,0))下的襯底與鞋矩形,與棋盤實物(格 _CELL,扣掉格原點)是否一致。
func _legend_rects(sample: Node2D) -> Dictionary:
	var out: Dictionary = {}
	for n: Node in sample.find_children("*", "", true, false):
		if n is ColorRect and String(n.name) == _BACKDROP_NAME:
			out["backdrop"] = Rect2((n as ColorRect).position, (n as ColorRect).size)
		elif n is Sprite2D and (String(n.name) == "ShoeIcon" or String(n.name) == "SwordIcon"):
			out[String(n.name)] = Rect2((n as Sprite2D).position, (n as Sprite2D).texture.get_size())
	return out


func _legend_same_source_violations(legend_rects: Dictionary, view: BoardView) -> Array[String]:
	var v: Array[String] = []
	var o: Vector2 = BoardCoords.grid_to_local(Vector2i.ZERO)
	var board: Dictionary = {
		"backdrop": _backdrop_rect(view),
		"ShoeIcon": _sprite_rect(view, "ShoeIcon"),
		"SwordIcon": _sprite_rect(view, "SwordIcon"),
	}
	for k: String in board:
		if not legend_rects.has(k):
			v.append("legend lacks %s" % k)
			continue
		var lr: Rect2 = legend_rects[k]
		if Rect2(lr.position - o, lr.size) != board[k]:
			v.append("%s differs between legend and board" % k)
	return v


func test_legend_action_samples_share_geometry_with_board() -> void:
	var view: BoardView = _make_view()
	_render_one(view, "PLAYER", {"move_used": true, "attack_used": true})
	# 圖例「已移動」只有鞋、「已攻擊」只有劍;兩者襯底相同。逐一對棋盤(兩者皆做)比。
	var moved: Dictionary = _legend_rects(_legend_sample(BoardView.MarkerKind.ACTION_MOVED))
	var attacked: Dictionary = _legend_rects(_legend_sample(BoardView.MarkerKind.ACTION_ATTACKED))
	assert_bool(moved.has("backdrop") and moved.has("ShoeIcon") and not moved.has("SwordIcon")).is_true()
	assert_bool(attacked.has("backdrop") and attacked.has("SwordIcon") and not attacked.has("ShoeIcon")).is_true()
	var merged: Dictionary = {"backdrop": moved["backdrop"], "ShoeIcon": moved["ShoeIcon"], "SwordIcon": attacked["SwordIcon"]}
	assert_array(_legend_same_source_violations(merged, view)).is_empty()
	assert_bool(attacked["backdrop"] == moved["backdrop"]).is_true()


func test_sensitivity_proof_legend_drawn_separately_detected() -> void:
	var view: BoardView = _make_view()
	_render_one(view, "PLAYER", {"move_used": true, "attack_used": true})
	var moved: Dictionary = _legend_rects(_legend_sample(BoardView.MarkerKind.ACTION_MOVED))
	var attacked: Dictionary = _legend_rects(_legend_sample(BoardView.MarkerKind.ACTION_ATTACKED))
	var tampered_shoe: Rect2 = moved["ShoeIcon"]
	tampered_shoe.position.x += 1.0   # 另畫一份、偏 1px
	var merged: Dictionary = {"backdrop": moved["backdrop"], "ShoeIcon": tampered_shoe, "SwordIcon": attacked["SwordIcon"]}
	assert_bool(_legend_same_source_violations(merged, view).is_empty()).append_failure_message(
		"mutant⑦ 圖例鞋偏 1px,同源偵測器應報違規").is_false()


# ─── Mutants / Spies ──────────────────────────────────────────────────────────

class _SpyWideLabel extends BoardView:
	func _label_rect_for_icons() -> Rect2:
		return Rect2(0.0, 8.0, 18.0, 14.0)


class _MutantOldPosition extends BoardView:
	func _build_action_icons(cell: Vector2i, piece: Dictionary) -> Node2D:
		var root: Node2D = super._build_action_icons(cell, piece)
		var origin: Vector2 = BoardCoords.grid_to_local(cell)
		for n: Node in root.get_children():
			if n.name == "ShoeIcon":
				(n as Sprite2D).position = origin + Vector2(0.0, -7.0)
			elif n.name == "SwordIcon":
				(n as Sprite2D).position = origin + Vector2(27.0, -7.0)
		return root


class _MutantHardcodedLeft extends BoardView:
	func _label_rect_for_icons() -> Rect2:
		return Rect2(0.0, 8.0, 18.0, 14.0)   # 間諜:首字框變寬

	func _build_action_icons(cell: Vector2i, piece: Dictionary) -> Node2D:
		var root: Node2D = super._build_action_icons(cell, piece)
		var origin: Vector2 = BoardCoords.grid_to_local(cell)
		for n: Node in root.get_children():
			if n is ColorRect:
				(n as ColorRect).position.x = origin.x + 12.0   # 寫死 12,不跟首字框走
			elif n.name == "ShoeIcon":
				(n as Sprite2D).position.x = origin.x + 13.0
		return root


class _MutantSwordAtEdge extends BoardView:
	func _build_action_icons(cell: Vector2i, piece: Dictionary) -> Node2D:
		var root: Node2D = super._build_action_icons(cell, piece)
		var sword: Node = root.find_child("SwordIcon", true, false)
		if sword != null:
			(sword as Sprite2D).position.x += 3.0   # 右緣貼到格緣 (32)
		return root


class _MutantBackdropIntoHpText extends BoardView:
	func _build_action_icons(cell: Vector2i, piece: Dictionary) -> Node2D:
		var root: Node2D = super._build_action_icons(cell, piece)
		for n: Node in root.get_children():
			if n is ColorRect:
				(n as ColorRect).position.y -= 2.0   # 頂 = 文字條下緣 - 1
		return root


class _MutantBackdropTooTall extends BoardView:
	func _build_action_icons(cell: Vector2i, piece: Dictionary) -> Node2D:
		var root: Node2D = super._build_action_icons(cell, piece)
		for n: Node in root.get_children():
			if n is ColorRect:
				(n as ColorRect).size.y = 20.0   # 蓋到血條
		return root


class _MutantTextureRebuilt extends BoardView:
	func _build_icon_sprite(tex: Texture2D, top_left: Vector2, node_name: String) -> Sprite2D:
		return super._build_icon_sprite(tex.duplicate(), top_left, node_name)


class _MutantAlwaysBackdrop extends BoardView:
	func _build_action_icons(cell: Vector2i, piece: Dictionary) -> Node2D:
		var root: Node2D = super._build_action_icons(cell, piece)
		if root.find_child("ActionIconBackdrop", true, false) == null:
			var r: Rect2 = BoardView.action_icon_backdrop_rect_in_cell()
			root.add_child(BoardView._make_icon_backdrop(Rect2(BoardCoords.grid_to_local(cell) + r.position, r.size)))
		return root
