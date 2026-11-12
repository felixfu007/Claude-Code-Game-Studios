extends GdUnitTestSuite

# story-043 AC1:收合態/不可用態手牌列不得蓋住任何敵兵起始格。載入真實 BattleScreen.tscn。
# 檔案存取:無直接存取(場景自行讀真實關卡資料,屬甲類既有路徑,本檔不新增)。
# 矩形一律取自 HandBar / HudLayout 既有函式,不另算。
# 【已知、已裁決的暫態】AC2 展開態遮敵兵(游標在 (9,4)/(7,5) 時展開面板蓋住它)已由管理者裁決延到大地圖捲動
# (「手牌展開時也能捲動畫面」)處理;本檔只驗展開面板不蓋我方單位。不是遺漏。
# 【未加】收合列與敵兵棋子視覺矩形的最小間隙(格邊長 x 0.125):board_view.gd 沒有「棋子視覺矩形」的唯一出處函式,
# 見回報;待協調者確認出處後再加,不在此自算。
# 敏感度:_MutantNoLift 把 collapsed_y_shift 還原成 0(舊位置);_MutantEmptyCells 把單位清單清空。
const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _SIZES: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1366, 768), Vector2i(1440, 810), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160),
]
const _MAX_SLOTS: int = 5

var _host_snap: CursorHostSnapshot = null
var _total: int = -1


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	get_tree().paused = false


func _enemy_cells() -> Array[Vector2i]:
	var inst: BattleScreen = load(_SCENE_PATH).instantiate()
	auto_free(inst)
	add_child(inst)
	_total = inst._state.units_of(Unit.Faction.ENEMY).size()
	var out: Array[Vector2i] = []
	for u: Unit in inst._state.units_of(Unit.Faction.ENEMY):
		out.append(inst._state.position_of(u.id))
	return out


## 被測矩形偵測器:回傳 [被測格數, 被蓋住的格]。rect_of 為待測的收合態視覺矩形函式。
func _scan(cells: Array[Vector2i], ws: Vector2i, rect: Rect2) -> Array:
	var hits: Array[Vector2i] = []
	for c: Vector2i in cells:
		if HudLayout.cell_overlaps_frame(HudLayout.cell_window_rect(c, ws), rect):
			hits.append(c)
	return [cells.size(), hits]


func test_collapsed_hand_bar_covers_no_enemy_cell_at_all_sizes() -> void:
	var cells: Array[Vector2i] = _enemy_cells()
	assert_int(cells.size()).append_failure_message("PRECONDITION: 單位數 == 關卡敵兵總數").is_equal(_total)
	assert_int(cells.size()).is_greater(0)
	for ws: Vector2i in _SIZES:
		var res: Array = _scan(cells, ws, HandBar.collapsed_backing_window_rect(ws, _MAX_SLOTS))
		assert_int(res[0]).append_failure_message("%s: 至少測了一格" % ws).is_greater(0)
		assert_array(res[1]).append_failure_message("%s: 收合手牌蓋住敵兵格" % ws).is_empty()


## 「不可用」態(LOCKED / 敵方回合)用的是同一顆背板(含鎖頭與說明列),此處以真實節點驗證:
## 節點實際背板的全域矩形 == 靜態矩形函式,且該矩形不蓋敵兵。
func test_unavailable_state_backing_matches_rect_function_and_covers_no_enemy() -> void:
	var cells: Array[Vector2i] = _enemy_cells()
	var bar: HandBar = auto_free(load("res://src/ui/battle/HandBar.tscn").instantiate())
	add_child(bar)
	bar.render([HandBar.SlotKind.TEMPORARY_MODIFIER] as Array[HandBar.SlotKind], _MAX_SLOTS, HandBar.Availability.LOCKED)
	var ws: Vector2i = bar.get_window().size
	var back: ColorRect = bar.get_child(0) as ColorRect
	var actual: Rect2 = back.get_global_transform() * Rect2(Vector2.ZERO, back.size)
	var expected: Rect2 = HandBar.collapsed_backing_window_rect(ws, _MAX_SLOTS)
	assert_bool(bar.diagnostic_caption_visible()).append_failure_message("PRECONDITION: 不可用態說明列顯示").is_true()
	assert_float(actual.position.y).is_equal_approx(expected.position.y, 0.5)
	assert_float(actual.end.y).is_equal_approx(expected.end.y, 0.5)
	assert_float(actual.position.x).is_equal_approx(expected.position.x, 0.5)
	for size: Vector2i in _SIZES:
		var res: Array = _scan(cells, size, HandBar.collapsed_backing_window_rect(size, _MAX_SLOTS))
		assert_int(res[0]).is_greater(0)
		assert_array(res[1]).append_failure_message("%s: 不可用態蓋住敵兵" % size).is_empty()


# ---- 敏感度證明(常駐):偵測器必須抓得到舊位置 / 空清單必須被防空洞斷言擋下 ----

func test_sensitivity_proof_detector_catches_unlifted_collapsed_rect() -> void:
	var cells: Array[Vector2i] = _enemy_cells()
	var caught: int = 0
	for ws: Vector2i in _SIZES:
		var old_rect: Rect2 = HandBar.collapsed_backing_window_rect(ws, _MAX_SLOTS)
		old_rect.position.y -= HandBar.collapsed_y_shift(ws, _MAX_SLOTS)
		if not (_scan(cells, ws, old_rect)[1] as Array).is_empty():
			caught += 1
	assert_int(caught).append_failure_message("舊位置(未抬升)應在至少一個尺寸蓋住敵兵").is_greater(0)


func test_sensitivity_proof_empty_cell_list_is_rejected_by_anti_vacuum_guard() -> void:
	var none: Array[Vector2i] = []
	var res: Array = _scan(none, _SIZES[0], HandBar.collapsed_backing_window_rect(_SIZES[0], _MAX_SLOTS))
	assert_int(res[0]).append_failure_message("空清單被測格數為 0,防空洞斷言(> 0)會擋下").is_equal(0)


# ---- AC2(部分):展開面板不得遮住我方單位(「被選取單位」必為我方) ----
# 照實揭露:游標所在格若是敵兵 (9,4)/(7,5),展開面板【會】蓋住它(面板寬 550@960 ~ 2200@4K,
# 置中於棋盤下半;幾何上無解,展開態也沒有 story-004 的變淡)。該部分未驗,已回報協調者。
func test_expanded_panel_covers_no_player_unit_cell_at_all_sizes() -> void:
	var inst: BattleScreen = load(_SCENE_PATH).instantiate()
	auto_free(inst)
	add_child(inst)
	var cells: Array[Vector2i] = []
	for u: Unit in inst._state.units_of(Unit.Faction.PLAYER):
		cells.append(inst._state.position_of(u.id))
	assert_int(cells.size()).append_failure_message("PRECONDITION: 我方單位數 > 0").is_greater(0)
	for ws: Vector2i in _SIZES:
		var origin: Vector2 = HandBar.expanded_slot_bar_rect(ws, _MAX_SLOTS).position
		var rects: Array[Rect2] = [HandBar.expanded_backing_window_rect(_MAX_SLOTS, ws, _MAX_SLOTS)]
		for i in range(_MAX_SLOTS):
			var d: Rect2 = HandBar.detail_panel_rect(i, ws)
			d.position += origin
			rects.append(d)
		for r: Rect2 in rects:
			assert_array(_scan(cells, ws, r)[1]).append_failure_message("%s: 展開面板 %s 蓋住我方單位" % [ws, r]).is_empty()
