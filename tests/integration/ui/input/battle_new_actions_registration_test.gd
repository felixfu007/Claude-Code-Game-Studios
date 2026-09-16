# U-005:驗證 `project.godot` 新增的 5 個輸入動作已正確註冊進 InputMap。
#
# Story: production/epics/card-play-interface/story-u005-input-actions-registration.md
# Governing ADR: ADR-0005(Accepted)——呈現層規則「載入期必須驗證 Input Map 約束……
# 鍵不存在時回報 UNKNOWN,不得視為通過」。本檔是這條規則對本 story 新增動作的具體執行:
# 不允許只讀 `project.godot` 文字內容當作驗證,必須實際呼叫 `InputMap` API。
#
# 🔴 本檔刻意只驗證「InputMap 的靜態註冊狀態」——動作是否存在、綁定的事件型別/欄位是否
# 正確——不驗證「按下去真的觸發對應行為」。後者需要引擎送 `InputEvent`,而 `--headless`
# 下引擎不送 `InputEvent`(見 `.claude/docs/coding-standards.md`「What NOT to Automate」)。
# `InputMap.get_actions()`/`action_get_events()` 讀的是專案啟動時載入的靜態設定,不涉及
# 視窗/顯示子系統,不受 headless 影響——這一點已由
# `prototypes/u004-inputmap-probe-2026-09-16/README.md`(「headless 下 InputMap 讀得到
# 真東西嗎?」節)實機驗證,本檔沿用同一個結論,不是本檔自己的新宣稱。
extends GdUnitTestSuite

const NEW_ACTIONS: PackedStringArray = [
	"battle_cancel",
	"battle_open_hand",
	"battle_next_target",
	"battle_prev_target",
	"battle_menu",
]


func _keyboard_events(action: StringName) -> Array[InputEventKey]:
	var result: Array[InputEventKey] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			result.append(event as InputEventKey)
	return result


func _joypad_events(action: StringName) -> Array[InputEventJoypadButton]:
	var result: Array[InputEventJoypadButton] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			result.append(event as InputEventJoypadButton)
	return result


func test_five_new_actions_exist_in_input_map() -> void:
	# Arrange / Act / Assert — 逐一查詢,AC:「5 個新動作皆可透過 InputMap.has_action()
	# 查詢確認存在」
	for action_name: String in NEW_ACTIONS:
		assert_bool(InputMap.has_action(action_name)) \
			.append_failure_message("動作 %s 未註冊於 InputMap" % action_name) \
			.is_true()


func test_each_new_action_has_both_keyboard_and_pad_binding() -> void:
	# AC:「每個動作皆有鍵盤與手把兩側綁定」
	for action_name: String in NEW_ACTIONS:
		var kb_events: Array[InputEventKey] = _keyboard_events(action_name)
		var pad_events: Array[InputEventJoypadButton] = _joypad_events(action_name)
		assert_int(kb_events.size()) \
			.append_failure_message("%s 缺少鍵盤綁定" % action_name) \
			.is_greater(0)
		assert_int(pad_events.size()) \
			.append_failure_message("%s 缺少手把綁定" % action_name) \
			.is_greater(0)


func test_battle_cancel_bindings_match_esc_and_pad_b() -> void:
	# Arrange / Act
	var kb_events: Array[InputEventKey] = _keyboard_events("battle_cancel")
	var pad_events: Array[InputEventJoypadButton] = _joypad_events("battle_cancel")

	# Assert — 依 U-004 探針結論,鍵盤 Esc / 手把 B(與 battle_end_phase 相同,刻意的
	# 過渡狀態,見下方 test_battle_cancel_shares_bindings_with_battle_end_phase_during_transition)
	assert_int(kb_events.size()).is_equal(1)
	assert_int(kb_events[0].keycode).is_equal(KEY_ESCAPE)
	assert_int(pad_events.size()).is_equal(1)
	assert_int(pad_events[0].button_index).is_equal(JOY_BUTTON_B)


func test_battle_open_hand_bindings_match_c_and_pad_x() -> void:
	# Arrange / Act
	var kb_events: Array[InputEventKey] = _keyboard_events("battle_open_hand")
	var pad_events: Array[InputEventJoypadButton] = _joypad_events("battle_open_hand")

	# Assert — 依 U-004 探針結論:探針對 InputMap.get_actions() 當時回傳的全部 93 個已註冊
	# 動作逐一比對(見 prototypes/u004-inputmap-probe-2026-09-16/README.md),鍵盤 C 未出現在
	# 任何一個的綁定中。手把 X 雖被 ui_colorpicker_delete_preset 佔用,但該衝突對象與本專案
	# 介面元件類別無重疊(探針報告「陷阱九覆核」節),故沿用 X。
	assert_int(kb_events.size()).is_equal(1)
	assert_int(kb_events[0].keycode).is_equal(KEY_C)
	assert_int(pad_events.size()).is_equal(1)
	assert_int(pad_events[0].button_index).is_equal(JOY_BUTTON_X)


func test_battle_next_target_bindings_match_tab_and_pad_rb() -> void:
	# Arrange / Act
	var kb_events: Array[InputEventKey] = _keyboard_events("battle_next_target")
	var pad_events: Array[InputEventJoypadButton] = _joypad_events("battle_next_target")

	# Assert — 依 U-004 探針結論(逐項結論表 next_target 列):鍵盤 Tab 側被 3 個內建動作佔用
	# (皆單側,不影響手把);手把 RB 在探針對全部 93 個已註冊動作的逐一比對中,未出現在任何
	# 一個的綁定中(同一份 README 的域,見上一支測試的引用)
	assert_int(kb_events.size()).is_equal(1)
	assert_int(kb_events[0].keycode).is_equal(KEY_TAB)
	assert_bool(kb_events[0].shift_pressed).is_false()
	assert_int(pad_events.size()).is_equal(1)
	assert_int(pad_events[0].button_index).is_equal(JOY_BUTTON_RIGHT_SHOULDER)


func test_battle_prev_target_bindings_match_shift_tab_and_pad_lb() -> void:
	# Arrange / Act
	var kb_events: Array[InputEventKey] = _keyboard_events("battle_prev_target")
	var pad_events: Array[InputEventJoypadButton] = _joypad_events("battle_prev_target")

	# Assert — 依 U-004 探針結論(逐項結論表 prev_target 列):鍵盤 Shift+Tab 側被 3 個內建動作
	# 佔用(皆單側,不影響手把);手把 LB 在探針對全部 93 個已註冊動作的逐一比對中,未出現在
	# 任何一個的綁定中。
	# shift_pressed 斷言是本檔區分 next_target 與 prev_target 的關鍵——兩者鍵盤 keycode
	# 相同(皆為 Tab),差別只在 shift 修飾鍵。
	assert_int(kb_events.size()).is_equal(1)
	assert_int(kb_events[0].keycode).is_equal(KEY_TAB)
	assert_bool(kb_events[0].shift_pressed).is_true()
	assert_int(pad_events.size()).is_equal(1)
	assert_int(pad_events[0].button_index).is_equal(JOY_BUTTON_LEFT_SHOULDER)


func test_battle_menu_bindings_match_m_and_pad_start() -> void:
	# Arrange / Act
	var kb_events: Array[InputEventKey] = _keyboard_events("battle_menu")
	var pad_events: Array[InputEventJoypadButton] = _joypad_events("battle_menu")

	# Assert — 依 U-004 探針結論(逐項結論表 battle_menu 列):鍵盤 M、手把 Start 兩者,在探針
	# 對 InputMap.get_actions() 當時全部 93 個已註冊動作的逐一比對中,均未出現在任何一個的
	# 綁定中(同一份探針 README,非本檔另行量測)。
	assert_int(kb_events.size()).is_equal(1)
	assert_int(kb_events[0].keycode).is_equal(KEY_M)
	assert_int(pad_events.size()).is_equal(1)
	assert_int(pad_events[0].button_index).is_equal(JOY_BUTTON_START)


func test_battle_cancel_shares_bindings_with_battle_end_phase_during_transition() -> void:
	# 中間狀態(U-005 到 U-016 之間)刻意接受 Esc/B 同時觸發兩個動作——這支測試鎖定的是
	# 「兩者綁定相同」這件事本身,不是缺陷。管理者裁決見
	# production/epics/card-play-interface/EPIC.md 第八節第 2 項、本 story 文件第 2 點。
	# Arrange / Act
	var cancel_kb: Array[InputEventKey] = _keyboard_events("battle_cancel")
	var end_phase_kb: Array[InputEventKey] = _keyboard_events("battle_end_phase")
	var cancel_pad: Array[InputEventJoypadButton] = _joypad_events("battle_cancel")
	var end_phase_pad: Array[InputEventJoypadButton] = _joypad_events("battle_end_phase")

	# Assert
	assert_int(cancel_kb.size()).is_equal(end_phase_kb.size())
	assert_int(cancel_kb[0].keycode).is_equal(end_phase_kb[0].keycode)
	assert_int(cancel_pad.size()).is_equal(end_phase_pad.size())
	assert_int(cancel_pad[0].button_index).is_equal(end_phase_pad[0].button_index)


func test_battle_end_phase_bindings_unchanged() -> void:
	# 鎖定既有 battle_end_phase 的綁定不被本 story 動到——鍵盤僅 Esc、手把僅 B
	# (button_index=1),各恰好一個事件。這支測試就是 AC「battle_end_phase 現有的
	# Esc/手把 B 綁定完全不變」的自動化版本。
	# Arrange / Act
	var kb_events: Array[InputEventKey] = _keyboard_events("battle_end_phase")
	var pad_events: Array[InputEventJoypadButton] = _joypad_events("battle_end_phase")

	# Assert
	assert_int(kb_events.size()).is_equal(1)
	assert_int(kb_events[0].keycode).is_equal(KEY_ESCAPE)
	assert_int(pad_events.size()).is_equal(1)
	assert_int(pad_events[0].button_index).is_equal(JOY_BUTTON_B)
