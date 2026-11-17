extends GdUnitTestSuite
## story-049:換手標題色 + 敵方/我方回合橫幅(AC1~AC5)。載入真實 BattleScreen.tscn,預設真實資料(未合成)。
## 檔案存取:無。
## 敏感度證明:常駐 mutant 子類別(set_script 先於任何屬性賦值,見 coding-standards 陷阱一)。
##   每個 AC 的檢查寫成 _acN_failure(instance) -> String("" = 成立),真實畫面斷言 == "",
##   mutant 斷言 != ""(= 偵測器真的抓到植入缺陷)。
## 未涵蓋(誠實登記):①像素層(AC6,協調者補拍)②透明度連續值只由 banner_alpha 純函式測,不在畫面上量
##   ③敵方橫幅「不延後第一個敵方步驟」只斷言第一步在呼叫同一幀已執行(橫幅程式碼本身無 await)。

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3440, 1440),
]

var _host_snap: CursorHostSnapshot = null


# ① 不還原標題色:恆為敵方色。
class _MutantTitleNeverRestores extends BattleScreen:
	func _title_color_for_phase(_phase: BattleController.Phase) -> Color:
		return BattleScreen.TITLE_COLOR_ENEMY


# ② 敵方橫幅不出現。
class _MutantNoEnemyBanner extends BattleScreen:
	func _banner_kind_for_transition(prev: BattleController.Phase, new_phase: BattleController.Phase) -> BattleScreen.PhaseBanner:
		if new_phase == BattleController.Phase.ENEMY_ACTING:
			return BattleScreen.PhaseBanner.NONE
		return super(prev, new_phase)


# ③ 不更新提示列。
class _MutantHintNotUpdated extends BattleScreen:
	func _refresh_controls_hint(_force: bool = false) -> void:
		pass


# ④ 我方橫幅不出現。
class _MutantNoPlayerBanner extends BattleScreen:
	func _banner_kind_for_transition(prev: BattleController.Phase, new_phase: BattleController.Phase) -> BattleScreen.PhaseBanner:
		if new_phase == BattleController.Phase.PLAYER_INPUT:
			return BattleScreen.PhaseBanner.NONE
		return super(prev, new_phase)


# ⑤ 我方橫幅不因輸入消失。
class _MutantBannerIgnoresInput extends BattleScreen:
	func _banner_dismiss_on_input(_event: InputEvent) -> bool:
		return false


# ⑥ 橫幅矩形改放視窗中央(蓋在棋盤上)。
class _MutantBannerOnBoard extends BattleScreen:
	func _phase_banner_rect_for(window_size: Vector2i) -> Rect2:
		return Rect2(Vector2(window_size) / 2.0 - Vector2(10.0, 10.0), Vector2(20.0, 20.0))


# ⑦ 我方橫幅吞掉該輸入:關閉橫幅後不呼叫 super。
class _MutantSwallowsInput extends BattleScreen:
	func _input(event: InputEvent) -> void:
		if _phase_banner_kind == BattleScreen.PhaseBanner.PLAYER and _banner_dismiss_on_input(event):
			_hide_phase_banner()
			return
		super(event)


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	get_tree().paused = false


func _make(script: Script = null) -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	if script != null:
		instance.set_script(script)
	auto_free(instance)
	add_child(instance)
	instance._note_hint_device(_key(KEY_A))
	instance._refresh_controls_hint()
	return instance


func _key(code: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func _to_enemy(instance: BattleScreen) -> void:
	instance._controller.end_faction_phase()


## 逐步跑完敵方回合直到離開 ENEMY_ACTING(同步,不經畫面協程)。
func _to_player(instance: BattleScreen) -> void:
	var guard: int = 0
	while instance._controller.phase() == BattleController.Phase.ENEMY_ACTING and guard < 200:
		instance._controller.step_enemy_phase()
		guard += 1


func _title_color(instance: BattleScreen) -> Color:
	return instance._status_label.get_theme_color(&"font_color")


func _board_cells_overlap(rect: Rect2, window_size: Vector2i) -> bool:
	for col: int in range(BoardCoords.BOARD_COLS):
		for row: int in range(BoardCoords.BOARD_ROWS):
			if rect.intersects(HudLayout.cell_window_rect(Vector2i(col, row), window_size), false):
				return true
	return false


## InfoLabel 文字矩形(右對齊於其框右緣)是否與 [param banner] 相交;空字串視為不相交。
func _info_text_overlaps(instance: BattleScreen, banner: Rect2) -> bool:
	var text: String = instance._info_label.text
	if text == "":
		return false
	var fpx: int = instance._info_label.get_theme_font_size(&"font_size")
	var w: float = instance._info_label.get_theme_font(&"font").get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
	var box: Rect2 = instance._info_label.get_global_rect()
	return Rect2(Vector2(box.end.x - w, box.position.y), Vector2(w, box.size.y)).intersects(banner, false)


# ---------------------------------------------------------------- 檢查函式("" = 成立)

func _ac1_failure(instance: BattleScreen) -> String:
	if _title_color(instance) != BattleScreen.TITLE_COLOR_PLAYER:
		return "開場標題色不是白色常數"
	_to_enemy(instance)
	if _title_color(instance) != BattleScreen.TITLE_COLOR_ENEMY:
		return "ENEMY_ACTING 標題色不是 #FF5252"
	_to_player(instance)
	if _title_color(instance) != BattleScreen.TITLE_COLOR_PLAYER:
		return "回到 PLAYER_INPUT 標題色沒有還原"
	return ""


func _ac2_failure(instance: BattleScreen) -> String:
	if instance.phase_banner_should_show():
		return "開場不該有橫幅"
	_to_enemy(instance)
	if not instance.phase_banner_should_show() or instance.phase_banner_kind() != BattleScreen.PhaseBanner.ENEMY:
		return "進入 ENEMY_ACTING 後敵方橫幅旗標不為真(防空洞)"
	if instance._phase_banner_label.text != Loc.localize(BattleScreen.TEXT_FACTION_ENEMY):
		return "敵方橫幅文字不是 battle.hud.faction_enemy"
	var node: Control = instance.phase_banner_node()
	if node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return "橫幅 mouse_filter 不是 IGNORE"
	var rect: Rect2 = node.get_rect()
	var ws: Vector2i = instance.get_window().size
	if _board_cells_overlap(rect, ws):
		return "橫幅節點矩形 %s 與棋盤相交(視窗 %s)" % [rect, ws]
	if instance._info_label.text != "" and _info_text_overlaps(instance, rect):
		return "橫幅可見時 InfoLabel 非空且文字矩形與橫幅相交"
	instance._tick_phase_banner(BattleScreen.phase_banner_total_seconds() + 0.01)
	if instance.phase_banner_should_show():
		return "時間到後橫幅沒有消失"
	return ""


func _ac2b_failure(instance: BattleScreen) -> String:
	if instance.phase_banner_should_show():
		return "開場第一個玩家回合不該出我方橫幅"
	_to_enemy(instance)
	_to_player(instance)
	if instance._controller.phase() != BattleController.Phase.PLAYER_INPUT:
		return "PRECONDITION: 敵方回合後應回到 PLAYER_INPUT"
	if not instance.phase_banner_should_show() or instance.phase_banner_kind() != BattleScreen.PhaseBanner.PLAYER:
		return "敵方→我方換手後我方橫幅旗標不為真(防空洞)"
	if instance._phase_banner_label.text != Loc.localize(BattleScreen.TEXT_FACTION_PLAYER):
		return "我方橫幅文字不是 battle.hud.faction_player"
	var rect: Rect2 = instance.phase_banner_node().get_rect()
	var ws: Vector2i = instance.get_window().size
	if _board_cells_overlap(rect, ws):
		return "我方橫幅矩形 %s 與棋盤相交(視窗 %s)" % [rect, ws]
	if _info_text_overlaps(instance, rect):
		return "我方橫幅可見時 InfoLabel 文字矩形與橫幅相交"
	if instance.phase_banner_node().get_index() >= instance._info_label.get_index():
		return "橫幅 z 序不在 InfoLabel 之下"
	# 滑鼠移動不關閉。
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(5, 5)
	instance._input(motion)
	if not instance.phase_banner_should_show():
		return "滑鼠移動不應關閉我方橫幅"
	# 第一個按下輸入關閉。
	instance._input(_key(KEY_A))
	if instance.phase_banner_should_show():
		return "第一個玩家輸入沒有關閉我方橫幅"
	return ""


func _ac3_failure(instance: BattleScreen) -> String:
	var no_selection_text: String = instance._controls_hint_label.text
	_to_enemy(instance)
	instance._refresh_view()
	instance._refresh_controls_hint()
	if _title_color(instance) != BattleScreen.TITLE_COLOR_ENEMY:
		return "同一次 _refresh_view 後標題色不是敵方色"
	if not instance.phase_banner_should_show():
		return "同一次 _refresh_view 後橫幅旗標不為真"
	if not instance._controls_hint_label.text.contains("敵方行動中"):
		return "提示列不是 story-045 的 ENEMY_PHASE 內容"
	_to_player(instance)
	instance._refresh_view()
	instance._refresh_controls_hint()
	if _title_color(instance) != BattleScreen.TITLE_COLOR_PLAYER:
		return "換手後標題色未還原"
	if instance.phase_banner_kind() != BattleScreen.PhaseBanner.PLAYER:
		return "換手後我方橫幅旗標不為真"
	# 換手抽牌後真實資料可能直接進入「待棄牌」(FORCED_DISCARD)而非 NO_SELECTION —— 以真實狀態映射為準:
	# 提示列必須等於 _current_hint_state() 的內容、且不再是敵方回合文字。
	print("MEASURE hint_state after handover = ", instance._current_hint_state(),
		" (NO_SELECTION=", ControlsHintContent.HintState.NO_SELECTION, ")")
	if instance._controls_hint_label.text.contains("敵方行動中") or no_selection_text == "":
		return "換手後提示列仍是敵方回合內容"
	if instance._current_hint_state() == ControlsHintContent.HintState.NO_SELECTION \
			and instance._controls_hint_label.text != no_selection_text:
		return "換手後提示列不是 NO_SELECTION 內容"
	return ""


func _ac4_failure(instance: BattleScreen) -> String:
	# 敵方橫幅期間:確認鍵不關閉橫幅,也不選取任何單位(輸入本就凍結)。
	_to_enemy(instance)
	instance._input(_key(KEY_ENTER))
	if instance.phase_banner_kind() != BattleScreen.PhaseBanner.ENEMY:
		return "敵方橫幅不該被輸入關閉"
	if instance._controller.selected_unit() != -1:
		return "敵方回合輸入不該選取單位"
	_to_player(instance)
	# 實測:換手抽牌後真實資料會進入「待棄牌」,該狀態下確認鍵不選單位。先依規則由玩家棄到合格(測試代為指名第一張)。
	var guard: int = 0
	while instance._controller.has_pending_discard() and guard < 20:
		instance._controller.resolve_forced_discard(instance._state.card_deck().hand()[0])
		guard += 1
	if instance._controller.has_pending_discard():
		return "PRECONDITION: 無法清掉待棄牌"
	var players: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	if players.is_empty():
		return "PRECONDITION: 沒有我方單位"
	instance._cursor_cell = instance._state.position_of(players[0].id)
	if instance._controller.selected_unit() != -1:
		return "PRECONDITION: 換手後不應已有選取"
	instance._input(_key(KEY_ENTER))
	if instance.phase_banner_should_show():
		return "確認鍵沒有關閉我方橫幅"
	if instance._controller.selected_unit() == -1:
		return "確認鍵的原效果(選取單位)沒有發生 —— 輸入被橫幅吞掉"
	return ""


# ---------------------------------------------------------------- 真實畫面

func test_title_color_enemy_red_and_restored_to_white() -> void:
	assert_str(_ac1_failure(_make())).is_empty()


func test_title_color_constants_match_spec() -> void:
	assert_str(BattleScreen.TITLE_COLOR_ENEMY.to_html(false).to_upper()).is_equal("FF5252")
	assert_str(BattleScreen.TITLE_COLOR_PLAYER.to_html(false).to_upper()).is_equal("FFFFFF")
	assert_bool(BattleScreen.TITLE_COLOR_ENEMY != BattleScreen.TITLE_COLOR_PLAYER).is_true()


func test_enemy_banner_shows_expires_and_stays_off_board() -> void:
	assert_str(_ac2_failure(_make())).is_empty()


func test_enemy_banner_hidden_on_leaving_enemy_phase_and_on_finished() -> void:
	var a: BattleScreen = _make()
	_to_enemy(a)
	assert_bool(a.phase_banner_should_show()).is_true()
	_to_player(a)
	assert_int(a.phase_banner_kind()).is_not_equal(BattleScreen.PhaseBanner.ENEMY)
	var b: BattleScreen = _make()
	_to_enemy(b)
	b._controller._set_phase(BattleController.Phase.FINISHED)
	assert_bool(b.phase_banner_should_show()).is_false()


func test_enemy_banner_does_not_delay_first_enemy_step() -> void:
	var instance: BattleScreen = _make()
	instance._end_faction_phase_pressed()
	# 協程在第一個 await 暫停;此時第一個敵方步驟必須已執行(橫幅沒有任何 await 擋在前面)。
	assert_int(instance._diagnostic_step_enemy_phase_call_count).is_greater_equal(1)


func test_banner_rect_pure_function_never_touches_board_at_all_sizes() -> void:
	for ws: Vector2i in _WINDOW_SIZES:
		var rect: Rect2 = HudLayout.phase_banner_rect(ws)
		assert_bool(_board_cells_overlap(rect, ws)).append_failure_message(
			"phase_banner_rect %s 與棋盤相交,視窗 %s" % [rect, ws]).is_false()
		var fpx: float = float(HudLayout.font_size(ws))
		assert_float(rect.size.x).is_equal(fpx * HudLayout.PHASE_BANNER_WIDTH_MULTIPLIER)
		assert_float(rect.size.y).is_equal(fpx * HudLayout.LABEL_HEIGHT_MULTIPLIER)
		assert_float(rect.get_center().x).is_equal_approx(float(ws.x) / 2.0, 0.5)


func test_player_banner_only_on_enemy_to_player_and_dismissed_by_first_press() -> void:
	assert_str(_ac2b_failure(_make())).is_empty()


func test_player_banner_measurements_selected_unit_minus_one_at_handover() -> void:
	var instance: BattleScreen = _make()
	_to_enemy(instance)
	_to_player(instance)
	print("MEASURE selected_unit() at handover = ", instance._controller.selected_unit(),
		"  info_label.text='", instance._info_label.text, "'")
	assert_int(instance._controller.selected_unit()).is_equal(-1)


func test_player_banner_hard_closed_on_leaving_player_input() -> void:
	var instance: BattleScreen = _make()
	_to_enemy(instance)
	_to_player(instance)
	assert_int(instance.phase_banner_kind()).is_equal(BattleScreen.PhaseBanner.PLAYER)
	# 第二次 end_faction_phase() 可能被待棄牌擋下(真實規則),改用 FINISHED 驗證「離開 PLAYER_INPUT 即硬關」。
	instance._controller._set_phase(BattleController.Phase.FINISHED)
	assert_bool(instance.phase_banner_should_show()).is_false()


func test_title_banner_hint_consistent_after_refresh_view() -> void:
	assert_str(_ac3_failure(_make())).is_empty()


func test_banners_do_not_block_input() -> void:
	assert_str(_ac4_failure(_make())).is_empty()


func test_banner_alpha_curve() -> void:
	assert_float(BattleScreen.banner_alpha(0.0)).is_equal(0.0)
	assert_float(BattleScreen.banner_alpha(BattleScreen.PHASE_BANNER_FADE_IN_SECONDS / 2.0)).is_equal_approx(0.5, 0.001)
	assert_float(BattleScreen.banner_alpha(0.5)).is_equal(1.0)
	var fade_mid: float = BattleScreen.PHASE_BANNER_FADE_IN_SECONDS + BattleScreen.PHASE_BANNER_HOLD_SECONDS \
		+ BattleScreen.PHASE_BANNER_FADE_OUT_SECONDS / 2.0
	assert_float(BattleScreen.banner_alpha(fade_mid)).is_equal_approx(0.5, 0.001)
	assert_float(BattleScreen.banner_alpha(BattleScreen.phase_banner_total_seconds())).is_equal(0.0)
	assert_float(BattleScreen.banner_alpha(-1.0)).is_equal(0.0)


# ---------------------------------------------------------------- 敏感度證明(常駐,皆應通過)

func test_sensitivity_proof_title_never_restored_is_caught() -> void:
	assert_str(_ac1_failure(_make(_MutantTitleNeverRestores))).is_not_empty()


func test_sensitivity_proof_no_enemy_banner_is_caught() -> void:
	assert_str(_ac2_failure(_make(_MutantNoEnemyBanner))).is_not_empty()


func test_sensitivity_proof_hint_not_updated_is_caught() -> void:
	assert_str(_ac3_failure(_make(_MutantHintNotUpdated))).is_not_empty()


func test_sensitivity_proof_no_player_banner_is_caught() -> void:
	assert_str(_ac2b_failure(_make(_MutantNoPlayerBanner))).is_not_empty()


func test_sensitivity_proof_banner_ignores_input_is_caught() -> void:
	assert_str(_ac2b_failure(_make(_MutantBannerIgnoresInput))).is_not_empty()


func test_sensitivity_proof_banner_on_board_is_caught_for_both_banners() -> void:
	assert_str(_ac2_failure(_make(_MutantBannerOnBoard))).is_not_empty()
	assert_str(_ac2b_failure(_make(_MutantBannerOnBoard))).is_not_empty()


func test_sensitivity_proof_banner_swallows_input_is_caught() -> void:
	assert_str(_ac4_failure(_make(_MutantSwallowsInput))).is_not_empty()
