# Story 054 — 行動狀態圖示(鞋 = 已移動、劍 = 已攻擊,做過才出現)+ 做完變暗。
# production/epics/tactical-combat/story-054-action-state-icons-sword-shoe.md
#
# 屬性:本檔不讀任何檔案(無 FileAccess/DirAccess);像素預言機取自 BoardView 的
# SWORD_ICON_ROWS / SHOE_ICON_ROWS 常數(工單 AC2 明定測試不得另設像素)。
#
# ⚠️ headless 不 rasterize,本檔只驗節點結構、位置、貼圖來源與 modulate,
# 驗不了「看起來像鞋/劍」——那是 AC8 的人眼盲測,不在本檔。
#
# ⚠️ 範圍限制(誠實登記):本檔只覆蓋 BoardView.render_pieces 的消費端契約。
# battle_screen.gd 如何把 TurnOrder 狀態翻成字典欄位,不在本檔。
#
# 敏感度證明:每個 mutant 是常駐子類別 + 一條「會通過」的 test_sensitivity_proof_*,
# 斷言偵測器(與 AC 測試相同的量測函式)確實抓到植入缺陷。mutant 一律在
# add_child() 之前 set_script()(Case A,已驗證安全的時機)。
#   ① 敵方也畫 → AC1   ② 鞋劍左右對調 → AC1   ③ 出現語意反轉 → AC1
#   ④ 變暗連 HP 一起暗 → AC4   ⑤ 貼圖每次重建 → AC2   ⑥ 圖示上移 14px 落入正上方單位血條範圍 → AC3(story-061 後圖示在格內,舊的 x 挪移已不構成重疊)
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BoardView.tscn"
const _CELL: Vector2i = Vector2i(2, 2)


# ─── 夾具 ──────────────────────────────────────────────────────────────────────

func _make_view(mutant: Script = null) -> BoardView:
	var instance: BoardView = auto_free(load(_SCENE_PATH).instantiate())
	if mutant != null:
		instance.set_script(mutant)
	add_child(instance)
	return instance


func _piece(faction: String, extra: Dictionary) -> Dictionary:
	var piece: Dictionary = {
		"cell": _CELL, "faction": faction, "sprite_index": 0, "hp": 10, "hp_max": 10,
	}
	piece.merge(extra, true)
	return piece


func _render_one(view: BoardView, faction: String, extra: Dictionary) -> void:
	var pieces: Array[Dictionary] = [_piece(faction, extra)]
	view.render_pieces(pieces)


func _icon_sprites(view: BoardView) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	_collect_sprites(view.get_node("ActionFlagLayer"), out)
	return out


func _collect_sprites(node: Node, out: Array[Sprite2D]) -> void:
	if node is Sprite2D:
		out.append(node)
	for child: Node in node.get_children():
		_collect_sprites(child, out)


func _icon_names(view: BoardView) -> Array[String]:
	var names: Array[String] = []
	for s: Sprite2D in _icon_sprites(view):
		names.append(String(s.name))
	names.sort()
	return names


# 五種情境 → 觀測到的圖示名稱集合(排序後);AC1 與敏感度證明共用同一個量測。
func _observed_table(view: BoardView) -> Array:
	var table: Array = []
	_render_one(view, "PLAYER", {"action_flag": BoardView.ActionFlag.NONE_USED})
	table.append(_icon_names(view))
	_render_one(view, "PLAYER", {"action_flag": BoardView.ActionFlag.ATTACK_ONLY})
	table.append(_icon_names(view))
	_render_one(view, "PLAYER", {"action_flag": BoardView.ActionFlag.MOVE_ONLY})
	table.append(_icon_names(view))
	_render_one(view, "PLAYER", {"action_flag": BoardView.ActionFlag.DONE})
	table.append(_icon_names(view))
	# 敵方:四種狀態逐一,全部併成一個清單
	var enemy_all: Array[String] = []
	for flag: int in [0, 1, 2, 3]:
		_render_one(view, "ENEMY", {"action_flag": flag})
		enemy_all.append_array(_icon_names(view))
	table.append(enemy_all)
	return table


# 預言機:移動已用(ATTACK_ONLY/DONE)→ 鞋;攻擊已用(MOVE_ONLY/DONE)→ 劍。
# 對應工單規則文字,不呼叫 BoardView 的推導函式。
func _expected_table() -> Array:
	var none: Array[String] = []
	var shoe: Array[String] = ["ShoeIcon"]
	var sword: Array[String] = ["SwordIcon"]
	var both: Array[String] = ["ShoeIcon", "SwordIcon"]
	var enemy: Array[String] = []
	return [none, shoe, sword, both, enemy]


# ─── AC1 顯示表 ────────────────────────────────────────────────────────────────

func test_action_icons_display_table_matches_oracle() -> void:
	# Arrange / Act
	var view: BoardView = _make_view()
	var observed: Array = _observed_table(view)

	# Assert — 逐格
	assert_array(observed).append_failure_message(
		"顯示表 {皆未用,只移動,只攻擊,兩者皆做,敵方任何} 與預言機不符:%s" % [observed]
	).is_equal(_expected_table())
	# 防空洞:四個我方集合彼此不同,且鞋與劍至少各出現過一次
	for i: int in range(4):
		for j: int in range(i + 1, 4):
			assert_bool(observed[i] == observed[j]).is_false()
	assert_bool((observed[1] as Array).has("ShoeIcon")).is_true()
	assert_bool((observed[2] as Array).has("SwordIcon")).is_true()


func test_action_icons_shoe_is_strictly_left_of_sword() -> void:
	var view: BoardView = _make_view()
	_render_one(view, "PLAYER", {"action_flag": BoardView.ActionFlag.DONE})
	var shoe: Sprite2D = view.get_node("ActionFlagLayer").find_child("ShoeIcon", true, false)
	var sword: Sprite2D = view.get_node("ActionFlagLayer").find_child("SwordIcon", true, false)
	assert_object(shoe).is_not_null()
	assert_object(sword).is_not_null()
	var shoe_right: float = shoe.position.x + shoe.texture.get_width()
	# story-061:art 規定鞋劍 0px 緊接(外框自成分隔線)→ 由 is_less 放寬為 is_less_equal;
	# 「鞋在劍左、不重疊」的性質不變,嚴格不相交另由 enlarge 測試的矩形相交斷言保證。
	assert_float(shoe_right).is_less_equal(sword.position.x)
	assert_float(shoe.position.x).is_less(sword.position.x)


func test_sensitivity_proof_enemy_also_drawn_detected() -> void:
	var view: BoardView = _make_view(_MutantEnemyAlsoDrawn)
	assert_bool(_observed_table(view) == _expected_table()).append_failure_message(
		"mutant① 應讓顯示表偏離預言機"
	).is_false()


func test_sensitivity_proof_shoe_sword_swapped_detected() -> void:
	var view: BoardView = _make_view(_MutantSwapped)
	assert_bool(_observed_table(view) == _expected_table()).append_failure_message(
		"mutant② 應讓顯示表偏離預言機"
	).is_false()


func test_sensitivity_proof_appearance_inverted_detected() -> void:
	var view: BoardView = _make_view(_MutantInverted)
	assert_bool(_observed_table(view) == _expected_table()).append_failure_message(
		"mutant③ 應讓顯示表偏離預言機"
	).is_false()


# ─── AC2 貼圖來源與重用 ────────────────────────────────────────────────────────

# 量測:把貼圖逐像素與字元陣列預言機比對,回傳不符像素數(-1 = 尺寸不符)。
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
			else:
				if px.a != 1.0 or px.to_html(false) != palette[ch]:
					bad += 1
	return bad


func test_action_icon_textures_match_art_addendum_arrays_and_sizes() -> void:
	# story-061:6×7/5×7 → 9×10/7×10(art 2026-11-17 陣列)
	assert_int(BoardView.shoe_texture().get_width()).is_equal(9)
	assert_int(BoardView.shoe_texture().get_height()).is_equal(10)
	assert_int(BoardView.sword_texture().get_width()).is_equal(7)
	assert_int(BoardView.sword_texture().get_height()).is_equal(10)
	assert_int(_texture_mismatches(
		BoardView.shoe_texture(), BoardView.SHOE_ICON_ROWS, "b0a897")).is_equal(0)
	assert_int(_texture_mismatches(
		BoardView.sword_texture(), BoardView.SWORD_ICON_ROWS, "a9b2bd")).is_equal(0)


# 量測:重畫 100 次,圖示 Sprite 用的貼圖是否始終是同一個物件。
func _texture_ids_stable(view: BoardView) -> bool:
	var seen: Dictionary = {}
	for i: int in range(100):
		_render_one(view, "PLAYER", {"action_flag": BoardView.ActionFlag.DONE})
		for s: Sprite2D in _icon_sprites(view):
			seen[s.texture.get_instance_id()] = true
	# 鞋、劍各一張 → 恰好 2 個物件 id,且都等於共用貼圖
	return seen.size() == 2 \
		and seen.has(BoardView.shoe_texture().get_instance_id()) \
		and seen.has(BoardView.sword_texture().get_instance_id())


func test_action_icon_textures_reused_across_100_redraws() -> void:
	assert_bool(_texture_ids_stable(_make_view())).is_true()


func test_sensitivity_proof_texture_rebuilt_each_time_detected() -> void:
	assert_bool(_texture_ids_stable(_make_view(_MutantTextureRebuilt))).append_failure_message(
		"mutant⑤ 每次重建貼圖,物件 id 應不穩定"
	).is_false()


# ─── AC3 位置與零重疊 ──────────────────────────────────────────────────────────

# 量測:實際圖示節點相對於格左上角的矩形(不取常數),以及與「正上方單位血條」的交集。
func _icon_rects_in_cell(view: BoardView) -> Array[Rect2]:
	var origin: Vector2 = BoardCoords.grid_to_local(_CELL)
	var rects: Array[Rect2] = []
	for s: Sprite2D in _icon_sprites(view):
		rects.append(Rect2(s.position - origin, s.texture.get_size()))
	return rects


func _overlaps_bar_above(rects: Array[Rect2]) -> bool:
	var bar: Rect2 = BoardView.hp_bar_rect_in_cell()
	for r: Rect2 in rects:
		var shifted: Rect2 = Rect2(r.position + Vector2(0.0, BoardCoords.CELL_SIZE), r.size)
		if shifted.intersects(bar):
			return true
	return false


func test_action_icons_positions_and_zero_overlap_with_bar_above() -> void:
	var view: BoardView = _make_view()
	_render_one(view, "PLAYER", {"action_flag": BoardView.ActionFlag.DONE})
	var rects: Array[Rect2] = _icon_rects_in_cell(view)
	assert_int(rects.size()).is_equal(2)
	# 位置 = 函式(常數)給的矩形
	assert_bool(rects.has(BoardView.shoe_icon_rect_in_cell())).is_true()
	assert_bool(rects.has(BoardView.sword_icon_rect_in_cell())).is_true()
	# story-061 取代 054 數字:鞋 (13,10,9,10)、劍 (22,10,7,10)
	# (互不相交等完整幾何見 board_view_action_icon_enlarge_test.gd)
	assert_bool(rects.has(Rect2(13, 10, 9, 10))).is_true()
	assert_bool(rects.has(Rect2(22, 10, 7, 10))).is_true()
	# 與正上方單位血條零交集
	assert_bool(_overlaps_bar_above(rects)).is_false()
	# 與本格 HP 文字條、首字框不相交
	for r: Rect2 in rects:
		assert_bool(r.intersects(BoardView.hp_text_rect_in_cell())).is_false()
		assert_bool(r.intersects(BoardView.piece_label_rect_in_cell())).is_false()


func test_sensitivity_proof_icon_moved_into_bar_range_detected() -> void:
	var view: BoardView = _make_view(_MutantIconIntoBarRange)
	_render_one(view, "PLAYER", {"action_flag": BoardView.ActionFlag.DONE})
	assert_bool(_overlaps_bar_above(_icon_rects_in_cell(view))).append_failure_message(
		"mutant⑥ 把圖示上移進正上方單位血條範圍,量測應判為重疊"
	).is_true()


# ─── AC4 變暗(觸發 = is_done;manager 2026-11-16 裁決) ───────────────────────

func _piece_sprite_modulate(view: BoardView) -> Color:
	return (view.get_node("PiecesLayer").get_child(0) as Sprite2D).modulate


# 量測:所有「不應暗」的東西是否全為 WHITE。
func _non_piece_nodes_all_white(view: BoardView) -> bool:
	for layer_name: String in ["StatsLayer", "ActionFlagLayer"]:
		if not _all_white(view.get_node(layer_name)):
			return false
	return true


func _all_white(node: Node) -> bool:
	if node is CanvasItem and (node as CanvasItem).modulate != Color.WHITE:
		return false
	for child: Node in node.get_children():
		if not _all_white(child):
			return false
	return true


func test_done_player_piece_dims_only_the_piece_sprite() -> void:
	var view: BoardView = _make_view()
	# 防空洞:未做完 → WHITE
	_render_one(view, "PLAYER", {"action_flag": BoardView.ActionFlag.ATTACK_ONLY})
	assert_object(_piece_sprite_modulate(view)).is_equal(Color.WHITE)
	# 兩旗標都用 → 變暗
	_render_one(view, "PLAYER", {"action_flag": BoardView.ActionFlag.DONE, "show_hp_text": true})
	var c: float = BoardView.DONE_PIECE_DIM
	assert_object(_piece_sprite_modulate(view)).is_equal(Color(c, c, c, 1.0))
	assert_float(c).is_between(0.60, 0.70)
	assert_bool(_non_piece_nodes_all_white(view)).append_failure_message(
		"HP 文字/血條/圖示不得變暗"
	).is_true()


func test_ended_early_with_no_flags_used_dims_but_draws_no_icons() -> void:
	# 被「結束角色行動」、兩旗標都沒用:is_done 真 → 變暗;圖示忠實反映旗標 → 無圖示
	var view: BoardView = _make_view()
	_render_one(view, "PLAYER", {
		"action_flag": BoardView.ActionFlag.DONE,
		"done": true, "move_used": false, "attack_used": false,
	})
	var c: float = BoardView.DONE_PIECE_DIM
	assert_object(_piece_sprite_modulate(view)).is_equal(Color(c, c, c, 1.0))
	assert_int(_icon_sprites(view).size()).is_equal(0)
	# 被結束、只移動過 → 變暗、只有鞋
	_render_one(view, "PLAYER", {
		"action_flag": BoardView.ActionFlag.DONE,
		"done": true, "move_used": true, "attack_used": false,
	})
	assert_object(_piece_sprite_modulate(view)).is_equal(Color(c, c, c, 1.0))
	assert_array(_icon_names(view)).is_equal(["ShoeIcon"])


func test_enemy_piece_never_dims() -> void:
	var view: BoardView = _make_view()
	_render_one(view, "ENEMY", {"action_flag": BoardView.ActionFlag.DONE, "done": true})
	assert_object(_piece_sprite_modulate(view)).is_equal(Color.WHITE)


func test_sensitivity_proof_dim_also_hits_hp_text_detected() -> void:
	var view: BoardView = _make_view(_MutantDimsStatsToo)
	_render_one(view, "PLAYER", {"action_flag": BoardView.ActionFlag.DONE, "show_hp_text": true})
	assert_bool(_non_piece_nodes_all_white(view)).append_failure_message(
		"mutant④ 連血量一起暗,量測應偵測到非 WHITE"
	).is_false()


# ─── Mutants ──────────────────────────────────────────────────────────────────

class _MutantEnemyAlsoDrawn extends BoardView:
	func render_pieces(pieces: Array[Dictionary]) -> void:
		super.render_pieces(pieces)
		for p: Dictionary in pieces:
			if p.get("faction", "PLAYER") != "PLAYER":
				_action_flag_layer.add_child(_build_action_icons(p["cell"], p))


class _MutantSwapped extends BoardView:
	func _build_action_icons(cell: Vector2i, piece: Dictionary) -> Node2D:
		var q: Dictionary = piece.duplicate()
		q["move_used"] = BoardView.piece_attack_used(piece)
		q["attack_used"] = BoardView.piece_move_used(piece)
		return super._build_action_icons(cell, q)


class _MutantInverted extends BoardView:
	func _build_action_icons(cell: Vector2i, piece: Dictionary) -> Node2D:
		var q: Dictionary = piece.duplicate()
		q["move_used"] = not BoardView.piece_move_used(piece)
		q["attack_used"] = not BoardView.piece_attack_used(piece)
		return super._build_action_icons(cell, q)


class _MutantTextureRebuilt extends BoardView:
	func _build_icon_sprite(tex: Texture2D, top_left: Vector2, node_name: String) -> Sprite2D:
		return super._build_icon_sprite(tex.duplicate(), top_left, node_name)


class _MutantIconIntoBarRange extends BoardView:
	func _build_icon_sprite(tex: Texture2D, top_left: Vector2, node_name: String) -> Sprite2D:
		return super._build_icon_sprite(tex, top_left + Vector2(0.0, -14.0), node_name)


class _MutantDimsStatsToo extends BoardView:
	func render_pieces(pieces: Array[Dictionary]) -> void:
		super.render_pieces(pieces)
		for child: Node in _stats_layer.get_children():
			if child is CanvasItem:
				(child as CanvasItem).modulate = Color(0.65, 0.65, 0.65, 1.0)
