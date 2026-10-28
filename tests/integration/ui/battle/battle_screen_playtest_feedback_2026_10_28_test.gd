extends GdUnitTestSuite

# 2026-10-28 管理者第一次實際試玩後的五點回饋,其中 2~5 點的行為測試
# (第 1 點是名冊數值,見 assets/data/units/vs0*_roster.txt;battle_state_test.gd 已同步)。
#   2. 我方沒有可行動角色時自動結束回合
#   3. 從選單選「結束回合」時順便關閉選單
#   4. 全程只用滑鼠:右鍵取消、左鍵點卡片出牌、底部「手牌」「選單」按鈕
#   5. 手牌收合時不再蓋在棋盤上(張數改顯示在「手牌」按鈕)
# 每條「該發生」的測試都配一條「前提不成立時不該發生」的對照,避免條件拿掉照樣綠。


var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	# Restore shared CursorStateHost Autoload state; see tests/helpers/cursor_host_snapshot.gd
	_host_snap.restore()
	get_tree().paused = false


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


func _fresh_instance() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _mouse_press(button_index: MouseButton, position: Vector2) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.position = position
	return event


func _slot_center(instance: BattleScreen, index: int) -> Vector2:
	var panel: Panel = instance._hand_bar._slot_nodes[index]
	return panel.get_global_transform() * (panel.size / 2.0)


# ---- 第 2 點:自動結束回合 -------------------------------------------------------

func test_auto_end_turn_starts_enemy_phase_when_every_player_unit_is_done() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	for id: int in instance._controller.selectable_units():
		instance._controller.end_unit_turn(id)
	assert_bool(instance._controller.selectable_units().is_empty()).append_failure_message(
		"PRECONDITION: 我方每個單位都應已結束行動"
	).is_true()

	# Act
	instance._process(0.0)

	# Assert
	assert_int(instance.diagnostic_step_enemy_phase_call_count()).append_failure_message(
		"我方全員行動完畢後,下一畫格應自動驅動敵方階段"
	).is_greater(0)


func test_auto_end_turn_does_not_fire_while_one_player_unit_can_still_act() -> void:
	# Arrange — 對照組:留一個單位沒結束
	var instance: BattleScreen = _fresh_instance()
	var ids: Array[int] = instance._controller.selectable_units()
	for id: int in ids.slice(0, ids.size() - 1):
		instance._controller.end_unit_turn(id)

	# Act
	instance._process(0.0)

	# Assert
	assert_int(instance._controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(instance.diagnostic_step_enemy_phase_call_count()).is_equal(0)


func test_auto_end_turn_waits_while_the_hand_is_open() -> void:
	# Arrange — 全員行動完畢,但玩家正在選牌:不該把他的出牌機會吃掉
	var instance: BattleScreen = _fresh_instance()
	for id: int in instance._controller.selectable_units():
		instance._controller.end_unit_turn(id)
	instance._handle_open_hand_pressed()
	assert_bool(instance._controller.is_card_play_in_progress()).append_failure_message(
		"PRECONDITION: 手牌應已開啟"
	).is_true()

	# Act
	instance._process(0.0)

	# Assert
	assert_int(instance._controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)


# ---- 第 3 點:選單結束回合順便關選單 -----------------------------------------------

func test_end_turn_row_in_menu_closes_the_menu() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._battle_menu.open()
	assert_bool(instance._battle_menu.is_open()).is_true()
	var end_row: Button = instance._battle_menu.get_node("Panel/ContentMargin/Rows/EndPhaseRow")

	# Act
	end_row.pressed.emit()

	# Assert
	assert_bool(instance._battle_menu.is_open()).append_failure_message(
		"選「結束回合」後選單應已關閉"
	).is_false()
	assert_bool(get_tree().paused).append_failure_message(
		"選單關閉後遊戲樹不應仍在暫停,否則敵方回合畫面不會動"
	).is_false()
	assert_int(instance.diagnostic_step_enemy_phase_call_count()).is_greater(0)


func test_right_click_closes_the_open_menu() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._battle_menu.open()

	# Act
	instance._battle_menu._input(_mouse_press(MOUSE_BUTTON_RIGHT, Vector2.ZERO))

	# Assert
	assert_bool(instance._battle_menu.is_open()).is_false()
	assert_int(instance._controller.phase()).append_failure_message(
		"右鍵關選單只是「返回戰鬥」,不可結束回合"
	).is_equal(BattleController.Phase.PLAYER_INPUT)


# ---- 第 4 點:只用滑鼠 -----------------------------------------------------------

func test_hand_button_opens_the_hand() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	assert_bool(instance._controller.is_card_play_in_progress()).is_false()

	# Act
	instance._hand_button.pressed.emit()

	# Assert
	assert_bool(instance._controller.is_card_play_in_progress()).is_true()
	assert_bool(instance._hand_bar.visible).is_true()


func test_menu_button_opens_the_menu() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()

	# Act
	instance._menu_button.pressed.emit()

	# Assert
	assert_bool(instance._battle_menu.is_open()).is_true()


func test_right_click_cancels_the_open_hand() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._handle_open_hand_pressed()
	assert_bool(instance._controller.is_card_play_in_progress()).is_true()

	# Act
	instance._input(_mouse_press(MOUSE_BUTTON_RIGHT, Vector2.ZERO))

	# Assert
	assert_bool(instance._controller.is_card_play_in_progress()).append_failure_message(
		"開著手牌時按右鍵,應等同 Esc 收回手牌"
	).is_false()


func test_left_click_on_a_card_selects_that_card() -> void:
	# Arrange — 點第 2 張(index 1),確認選到的不是游標預設的第 1 張
	var instance: BattleScreen = _fresh_instance()
	instance._handle_open_hand_pressed()
	var hand: Array[Card] = instance._state.card_deck().hand()
	assert_int(hand.size()).append_failure_message("PRECONDITION: 至少要有兩張手牌").is_greater_equal(2)
	var click_at: Vector2 = _slot_center(instance, 1)

	# Act
	instance._input(_mouse_press(MOUSE_BUTTON_LEFT, click_at))

	# Assert
	assert_object(instance._controller.selected_card()).append_failure_message(
		"左鍵點在第 2 張卡上,應選中第 2 張"
	).is_same(hand[1])


func test_left_click_outside_every_card_selects_nothing() -> void:
	# Arrange — 對照組
	var instance: BattleScreen = _fresh_instance()
	instance._handle_open_hand_pressed()

	# Act — 視窗左上角,不在任何卡格上
	instance._input(_mouse_press(MOUSE_BUTTON_LEFT, Vector2(1.0, 1.0)))

	# Assert
	assert_object(instance._controller.selected_card()).is_null()
	assert_bool(instance._card_selecting_from_hand).is_true()


# ---- 第 5 點:手牌不擋地圖(第二輪:縮小,不是隱藏) ----------------------------------

func test_collapsed_hand_stays_visible_but_shrunk_and_count_shows_on_hand_button() -> void:
	# Arrange / Act
	var instance: BattleScreen = _fresh_instance()
	var hand_size: int = instance._state.card_deck().hand().size()

	# Assert — 管理者第二輪:「手牌不見了,縮小就好,不是要你隱藏」
	assert_bool(instance._hand_bar.visible).is_true()
	assert_float(instance._hand_bar.scale.x).is_equal_approx(HandBar.COLLAPSED_SCALE, 0.001)
	assert_str(instance._hand_button.text).is_equal(
		Loc.localize(BattleScreen.TEXT_HAND_BUTTON) % [hand_size, CardDeck.HAND_SIZE_LIMIT]
	)


func test_expanded_hand_returns_to_full_size() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._handle_open_hand_pressed()

	# Act — 直接把展開進度推到底,不等 tween(結果與時間無關)
	instance._hand_bar._set_expand_progress(1.0)

	# Assert
	assert_float(instance._hand_bar.scale.x).is_equal_approx(1.0, 0.001)


# ---- 第二輪第 3 點:原地移動 -------------------------------------------------------

func test_clicking_the_selected_unit_again_spends_its_move_without_moving() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var id: int = instance._controller.selectable_units()[0]
	var pos: Vector2i = instance._state.position_of(id)
	instance._controller.click_tile(pos)
	assert_int(instance._controller.selected_unit()).is_equal(id)

	# Act
	var result: Dictionary = instance._controller.click_tile(pos)

	# Assert
	assert_str(String(result["action"])).is_equal("moved")
	assert_that(instance._state.position_of(id)).is_equal(pos)
	assert_int(instance._controller.unit_action_state(id)).is_equal(TurnOrder.ActionState.ATTACK_ONLY)


func test_clicking_an_unselected_own_unit_only_selects_it() -> void:
	# Arrange — 對照組:第一次點只是選取,不可吃掉移動
	var instance: BattleScreen = _fresh_instance()
	var id: int = instance._controller.selectable_units()[0]

	# Act
	instance._controller.click_tile(instance._state.position_of(id))

	# Assert
	assert_int(instance._controller.unit_action_state(id)).is_equal(TurnOrder.ActionState.NONE_USED)


# ---- 第二輪第 4 點:移動完、沒有敵人可打 = 自動結束 ------------------------------------

func test_auto_end_turn_when_every_unit_moved_and_none_has_a_target_in_range() -> void:
	# Arrange — 開場時敵我距離 ≥ 7 格,全員原地移動後沒人搆得到敵人
	var instance: BattleScreen = _fresh_instance()
	for id: int in instance._controller.selectable_units():
		var pos: Vector2i = instance._state.position_of(id)
		instance._controller.click_tile(pos)
		instance._controller.click_tile(pos)
	assert_bool(instance._controller.selectable_units().is_empty()).append_failure_message(
		"PRECONDITION: 單位只用了移動、攻擊旗標還在 —— 舊條件(全員旗標用完)不會觸發"
	).is_false()

	# Act
	instance._process(0.0)

	# Assert
	assert_int(instance.diagnostic_step_enemy_phase_call_count()).is_greater(0)


# ---- 第三輪(同日)----------------------------------------------------------------

func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	return event


func test_right_click_deselects_the_selected_unit() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var id: int = instance._controller.selectable_units()[0]
	instance._controller.click_tile(instance._state.position_of(id))
	assert_int(instance._controller.selected_unit()).is_equal(id)

	# Act
	instance._input(_mouse_press(MOUSE_BUTTON_RIGHT, Vector2.ZERO))

	# Assert
	assert_int(instance._controller.selected_unit()).is_equal(-1)
	assert_int(instance._controller.unit_action_state(id)).append_failure_message(
		"取消選取不可吃掉任何旗標"
	).is_equal(TurnOrder.ActionState.NONE_USED)


func test_hovering_a_card_moves_the_hand_cursor_to_it() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._handle_open_hand_pressed()
	instance._hand_bar._set_expand_progress(1.0)
	assert_int(instance._hand_bar.diagnostic_cursor_index()).is_equal(0)

	# Act
	instance._input(_mouse_motion(_slot_center(instance, 2)))

	# Assert
	assert_int(instance._hand_bar.diagnostic_cursor_index()).is_equal(2)


func test_hovering_with_the_hand_closed_does_not_move_the_hand_cursor() -> void:
	# Arrange — 對照組:手牌沒開
	var instance: BattleScreen = _fresh_instance()

	# Act
	instance._input(_mouse_motion(_slot_center(instance, 2)))

	# Assert
	assert_int(instance._hand_bar.diagnostic_cursor_index()).is_equal(0)


func test_open_hand_detail_panel_shows_the_card_text() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var hand: Array[Card] = instance._state.card_deck().hand()
	instance._handle_open_hand_pressed()

	# Act
	instance._hand_bar._set_expand_progress(1.0)

	# Assert — 卡面文字來自卡面文字表,不是空白
	assert_bool(instance._hand_bar.diagnostic_detail_panel_visible()).is_true()
	assert_str(instance._hand_bar.diagnostic_detail_panel_text()).is_equal(
		instance._card_flavor_texts.get(hand[0].id, "")
	)
	assert_str(instance._hand_bar.diagnostic_detail_panel_text()).is_not_empty()


func test_threat_cells_get_a_red_fill_under_the_stripes() -> void:
	# Arrange
	var board_view: BoardView = auto_free(load("res://src/ui/battle/BoardView.tscn").instantiate())
	add_child(board_view)
	var cells: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 2)]

	# Act
	board_view.set_threat_highlights(cells)

	# Assert
	var fills: int = 0
	for child: Node in board_view.get_node("ThreatHighlightLayer").get_children():
		if child is ColorRect and (child as ColorRect).color == BoardView.THREAT_FILL_COLOR:
			fills += 1
	assert_int(fills).is_equal(cells.size())


func test_relation_toggle_button_is_smaller_than_before() -> void:
	# Arrange — 「之前」= 與一致率計數器同寬同高
	var window_size: Vector2i = Vector2i(1440, 810)
	var counter: Rect2 = HudLayout.consistency_counter_rect(window_size)

	# Act
	var toggle: Rect2 = HudLayout.relation_minimap_toggle_rect(window_size)

	# Assert
	assert_float(toggle.size.x).is_less(counter.size.x)
	assert_float(toggle.size.y).is_less(counter.size.y)
