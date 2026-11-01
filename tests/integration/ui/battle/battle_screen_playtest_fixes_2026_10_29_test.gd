extends GdUnitTestSuite

# 2026-10-29 協調者試玩找到、管理者裁決「現在修」的三項:
#   1. Esc/右鍵收手牌後,棋盤游標表面沒登記回去 → 方向鍵整場移不動游標
#   2. 回合開頭的強制棄牌畫面蓋住棋盤,一次左鍵就棄牌(裁決:不加確認,改用其他防誤觸)
#   3. Esc/B 或再按一次選單鍵關不掉選單(battle-menu.md「離開」表要求可以)
# 每條「該發生」都配一條「前提不成立時不該發生」的對照。


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


func _real_pressed_event(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


func _mouse_press(position: Vector2) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	return event


func _slot_center(instance: BattleScreen, index: int) -> Vector2:
	var panel: Panel = instance._hand_bar._slot_nodes[index]
	return panel.get_global_transform() * (panel.size / 2.0)


## 6 張已知卡 → 開局 5 張 + 回合抽 1 張 = 觸發強制棄牌(同 forced_discard_test.gd 的作法)。
func _install_forced_discard_state(instance: BattleScreen) -> CardDeck:
	var cards: Array[Card] = []
	for i: int in range(6):
		cards.append(Card.new_temporary_stat_modifier("test_fix_1029_card_%d" % i, 1, 0, 1))
	var deck: CardDeck = CardDeck.new(cards)
	instance._state.attach_card_deck(deck)
	deck.deal_opening_hand()
	deck.draw_for_turn()
	assert_bool(deck.has_pending_discard()).append_failure_message(
		"PRECONDITION: 應已進入強制棄牌"
	).is_true()
	instance._refresh_view()
	# 手牌展開是動畫,測試直接跳到展開完成(同 playtest_feedback_2026_10_28_test 的作法),卡格才有實際尺寸。
	instance._hand_bar._set_expand_progress(1.0)
	return deck


## 把本次強制棄牌的開始時間撥到很久以前,等同「防誤觸等待時間已過」—— 不依賴真實時間流逝。
func _pretend_grace_elapsed(instance: BattleScreen) -> void:
	instance._track_forced_discard_arming()
	instance._discard_armed_since_msec = Time.get_ticks_msec() - BattleScreen.DISCARD_CLICK_GRACE_MSEC - 1


# ---- 1. Esc 收手牌要把棋盤游標表面登記回去 -------------------------------------

func test_esc_closing_the_hand_reregisters_the_board_cursor_surface() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._input(_real_pressed_event(&"battle_open_hand"))
	assert_bool(instance._card_selecting_from_hand).append_failure_message(
		"PRECONDITION: 手牌應已開啟"
	).is_true()

	# Act
	instance._input(_real_pressed_event(&"battle_cancel"))

	# Assert — 登出成功(回傳 REGISTERED)代表它此刻確實登記著
	assert_bool(instance._card_selecting_from_hand).is_false()
	assert_int(CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE)).append_failure_message(
		"Esc 收手牌後 BOARD_TILE 應已登記回來,否則方向鍵移不動游標"
	).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)


func test_board_cursor_surface_is_not_registered_while_the_hand_is_open() -> void:
	# Arrange — 對照組:手牌開著時本來就該是登出狀態(上一條的斷言不是恆真)
	var instance: BattleScreen = _fresh_instance()

	# Act
	instance._input(_real_pressed_event(&"battle_open_hand"))

	# Assert
	assert_int(CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE)).is_not_equal(
		CursorSurfaceRegistry.RegisterResult.REGISTERED
	)


# ---- 2. 強制棄牌防誤觸 --------------------------------------------------------

func test_discard_click_without_hovering_a_card_first_does_not_discard() -> void:
	# Arrange — 畫面出現後滑鼠沒移到卡上(例:原本正要點棋盤),即使等待時間已過
	var instance: BattleScreen = _fresh_instance()
	var deck: CardDeck = _install_forced_discard_state(instance)
	_pretend_grace_elapsed(instance)

	# Act
	instance._input(_mouse_press(_slot_center(instance, 0)))

	# Assert
	assert_bool(instance._controller.has_pending_discard()).append_failure_message(
		"沒先指到卡片就點下去,不應棄牌"
	).is_true()
	assert_int(deck.hand_size()).is_equal(6)


func test_discard_click_within_grace_period_does_not_discard() -> void:
	# Arrange — 指到卡片了,但畫面才剛出現(開始時間 = 現在)
	var instance: BattleScreen = _fresh_instance()
	var deck: CardDeck = _install_forced_discard_state(instance)
	instance._track_forced_discard_arming()
	instance._discard_armed_since_msec = Time.get_ticks_msec() + 60_000
	instance._input(_mouse_motion(_slot_center(instance, 0)))

	# Act
	instance._input(_mouse_press(_slot_center(instance, 0)))

	# Assert
	assert_bool(instance._controller.has_pending_discard()).append_failure_message(
		"畫面剛出現的等待時間內點擊,不應棄牌"
	).is_true()
	assert_int(deck.hand_size()).is_equal(6)


func test_discard_click_after_hover_and_grace_discards_the_clicked_card() -> void:
	# Arrange — 對照組:兩個條件都滿足就要能棄(防誤觸不能把正常棄牌也擋掉)
	var instance: BattleScreen = _fresh_instance()
	var deck: CardDeck = _install_forced_discard_state(instance)
	_pretend_grace_elapsed(instance)
	var clicked: Card = deck.hand()[2]
	instance._input(_mouse_motion(_slot_center(instance, 2)))
	assert_bool(instance.diagnostic_forced_discard_click_allowed()).append_failure_message(
		"PRECONDITION: 指到卡片且等待已過,應允許點擊棄牌"
	).is_true()

	# Act
	instance._input(_mouse_press(_slot_center(instance, 2)))

	# Assert
	assert_bool(instance._controller.has_pending_discard()).is_false()
	assert_bool(deck.used().has(clicked)).append_failure_message(
		"被棄的應是點到的那張"
	).is_true()


func test_keyboard_discard_is_not_affected_by_mouse_guard() -> void:
	# Arrange — 鍵盤/手把不受防誤觸影響:畫面剛出現、滑鼠沒動也能直接確認
	var instance: BattleScreen = _fresh_instance()
	_install_forced_discard_state(instance)

	# Act
	instance._input(_real_pressed_event(&"battle_confirm"))

	# Assert
	assert_bool(instance._controller.has_pending_discard()).is_false()


# ---- 3. Esc / 再按選單鍵關選單 --------------------------------------------------

func test_esc_closes_the_open_menu() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._battle_menu.open()
	await await_idle_frame()

	# Act
	instance._battle_menu._unhandled_input(_real_pressed_event(&"battle_cancel"))

	# Assert
	assert_bool(instance._battle_menu.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(instance._controller.phase()).append_failure_message(
		"Esc 關選單只是「返回戰鬥」,不可結束回合"
	).is_equal(BattleController.Phase.PLAYER_INPUT)


func test_pressing_menu_key_again_closes_the_menu() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._battle_menu.open()
	await await_idle_frame()

	# Act
	instance._battle_menu._unhandled_input(_real_pressed_event(&"battle_menu"))

	# Assert
	assert_bool(instance._battle_menu.is_open()).is_false()


func test_the_keypress_that_opens_the_menu_does_not_also_close_it() -> void:
	# Arrange — 對照組:開選單那一下按鍵在同一幀會繼續流到選單,不能把它當成「再按一次」
	var instance: BattleScreen = _fresh_instance()
	var press: InputEventKey = _real_pressed_event(&"battle_menu")

	# Act — 同一幀:戰鬥畫面開選單,同一個事件接著流到選單的 _unhandled_input
	instance._input(press)
	instance._battle_menu._unhandled_input(press)

	# Assert
	assert_bool(instance._battle_menu.is_open()).append_failure_message(
		"開選單那一下不應同時把選單關掉"
	).is_true()


func test_esc_with_leave_confirm_open_closes_only_the_confirm() -> void:
	# Arrange — 離開確認框開著時,Esc 只關確認框,選單留著
	var instance: BattleScreen = _fresh_instance()
	instance._battle_menu.open()
	instance._battle_menu.open_leave_confirm()
	await await_idle_frame()

	# Act
	instance._battle_menu._unhandled_input(_real_pressed_event(&"battle_cancel"))

	# Assert
	assert_bool(instance._battle_menu._leave_confirm.visible).is_false()
	assert_bool(instance._battle_menu.is_open()).is_true()
