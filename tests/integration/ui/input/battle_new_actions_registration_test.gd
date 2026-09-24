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
#
# 🔴 2026-09-16 敏感度證明手法評估(管理者裁決:全專案改用常駐測試,範本見
# tests/integration/gameplay/affinity_pool/affinity_pool_wiring_test.gd)——本檔為何
# 長得跟範本不一樣,原因寫在這裡,不要跳過:
#
# 範本的做法是「繼承受測類別、覆寫一個方法讓它帶壞掉的副作用、證明偵測邏輯真的抓到」。
# 本檔的受測對象是 `project.godot` 載入後的 InputMap 內容——一份資料,不是一個類別,
# 沒有東西可以繼承、沒有方法可以覆寫。範本手法在字面上搬不過來。
#
# 逐一盤點本檔 9 條測試後,只有一處是「本檔自己寫的、非顯而易見正確的邏輯」——
# `_keyboard_events()` / `_joypad_events()`(現拆為薄殼 + `_filter_keyboard_events()` /
# `_filter_joypad_events()` 兩個純函式)對一組混合型別事件做型別篩選。這段邏輯壞掉
# (例如 `is InputEventKey` 誤寫成 `is InputEvent`、或漏篩掉 `InputEventMouseButton`)
# 會讓下面全部 9 條測試同時被同一個 bug 污染,而且沒有任何一條測試能從自己的角度
# 看出篩選器內部壞了——它們只看得到篩選後的輸出。這正是敏感度證明要防的情況,
# 而且可以在**完全不碰真正的 `InputMap` 單例**的前提下證明:把 `InputEventKey`/
# `InputEventJoypadButton`/`InputEventMouseButton` 純粹在記憶體中組出來,直接餵給
# 拆出來的純篩選函式即可,不需要 teardown,不會有任何全域狀態污染風險(見檔案末尾
# 兩條 test_sensitivity_proof_* )。
#
# 其餘 8 條(has_action 存在性檢查、各動作鍵盤/手把欄位比對、battle_cancel 與
# battle_end_phase 綁定相同、battle_end_phase 綁定不變)全部是「直接讀真實引擎狀態、
# 用 GdUnit4 自己的斷言原語(`assert_int().is_equal()` 等,本測試套件已使用超過 700 次)
# 逐欄位比對常數」——比對邏輯本身就是斷言,中間沒有插入任何本檔自己寫的演算法可以
# 注入缺陷。要「證明」這裡的敏感度,唯一手法是暫時竄改真正全域 `InputMap` 單例的內容
# 再驗證斷言抓得到,但這只能證明「GdUnit4 的 is_equal 能分辨不相等」——這件事已經
# 由這 700 次既有用法保證,不是本檔的邏輯可能弄壞的東西,竄改全域單例換來的只有
# teardown 沒還原乾淨、污染其餘 700 多條測試的風險,沒有換到任何新的保證。
# 🔴 因此這 8 條刻意不配對應的「注入證明」測試——這是評估後的結論,不是遺漏。
extends GdUnitTestSuite

const NEW_ACTIONS: PackedStringArray = [
	"battle_cancel",
	"battle_open_hand",
	"battle_next_target",
	"battle_prev_target",
	"battle_menu",
]


# 純函式——不查詢 InputMap,只對呼叫端給的事件陣列做型別篩選。從 `_keyboard_events()`
# 拆出來的唯一理由是讓下面的敏感度證明可以直接餵記憶體中組出來的假事件進來測試,
# 不必碰真正的 InputMap 單例(見檔案開頭「敏感度證明手法評估」節)。
func _filter_keyboard_events(events: Array[InputEvent]) -> Array[InputEventKey]:
	var result: Array[InputEventKey] = []
	for event: InputEvent in events:
		if event is InputEventKey:
			result.append(event as InputEventKey)
	return result


func _filter_joypad_events(events: Array[InputEvent]) -> Array[InputEventJoypadButton]:
	var result: Array[InputEventJoypadButton] = []
	for event: InputEvent in events:
		if event is InputEventJoypadButton:
			result.append(event as InputEventJoypadButton)
	return result


func _keyboard_events(action: StringName) -> Array[InputEventKey]:
	return _filter_keyboard_events(InputMap.action_get_events(action))


func _joypad_events(action: StringName) -> Array[InputEventJoypadButton]:
	return _filter_joypad_events(InputMap.action_get_events(action))


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

	# Assert — 依 U-004 探針結論,鍵盤 Esc / 手把 B。
	# 🔴 2026-09-24(Story U-016)更正:這裡原本寫「與 battle_end_phase 相同,刻意的
	# 過渡狀態,見下方 test_battle_cancel_shares_bindings_with_battle_end_phase_during_transition」
	# ——那是舊註解,現在是懸空引用(該測試已被 U-016 刪除,見本檔下方
	# 「2026-09-24(Story U-016)」歷史說明區塊)。**終態,不是過渡狀態**:
	# battle_end_phase 現在零綁定(project.godot),Esc/手把 B 只觸發這裡驗證的
	# battle_cancel,不再與任何其他動作共用。承接原本那條過渡態測試涵蓋範圍的是
	# tests/integration/ui/end_phase_unbind_test.gd 的
	# test_battle_end_phase_action_has_no_bindings_after_unbind(綁定層級)與
	# test_pressing_escape_only_triggers_cancel_not_end_turn(行為層級)。
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


# 🔴 2026-09-24(Story U-016)——本節原有兩條測試,已移除,歷史記在此不讓它無聲消失:
#
# 1. `test_battle_cancel_shares_bindings_with_battle_end_phase_during_transition`——
#    鎖定 2026-09-15 管理者裁決 F 核准的過渡態(U-005 到 U-016 之間,Esc/手把 B
#    同時觸發 battle_cancel 與 battle_end_phase 兩個動作,見 EPIC.md 第八節第 2 項)。
#    U-016 是「由 U-016 一次解決」那句話裡的 U-016——本 story 把 battle_end_phase
#    的兩個綁定清空,過渡態結構上不再可能發生(battle_end_phase 現在零綁定,
#    無綁定可與 battle_cancel「共用」)。它原本鎖定的東西不是壞掉,是被本 story
#    依裁決刻意移除。
# 2. `test_battle_end_phase_bindings_unchanged`——鎖定「battle_end_phase 的 Esc/手把 B
#    綁定維持不動」,這正是 U-005 到 U-015 期間應該成立、U-016 應該終結的狀態。
#
# 終態(battle_end_phase 綁定歸零、Esc/B 只觸發 battle_cancel)改由
# tests/integration/ui/end_phase_unbind_test.gd 的
# test_battle_end_phase_action_has_no_bindings_after_unbind(綁定層級,逐一比對
# 上面兩條原本比對的兩個陣列,斷言長度為 0,不是只換個名字)與
# test_pressing_escape_only_triggers_cancel_not_end_turn(行為層級,真實
# InputEventKey 經 BattleScreen._input() 分派,比綁定比對更直接地證明「Esc 現在
# 只做取消」)兩條測試承接,涵蓋範圍不只是名字對得上,兩者合起來同時覆蓋了
# 「boundary 層級」與「行為層級」,比被移除的那兩條原本各自的覆蓋範圍更完整。


# ---- 敏感度證明 ---------------------------------------------------------------
#
# 刻意放在檔案最後兩條:GdUnit4 一條測試失敗會中止「同一個檔案」後面所有測試
# (.claude/docs/coding-standards.md 已登記的既有陷阱)。這兩條測試的對象是本檔
# 自己的篩選邏輯,不是上面 9 條測試賴以成立的前提——放在最後,即使這兩條其中
# 一條意外壞掉,上面 9 條對 project.godot 真實內容的驗證結果不會被連坐。
#
# 🔴 兩條都刻意不碰真正的 InputMap 單例——事件物件全部在記憶體中直接 new 出來,
# 不經過 InputMap.action_add_event()/action_erase_event()。因此不需要 teardown,
# 也沒有污染其餘 700 多條測試全域狀態的風險。

func test_sensitivity_proof_filter_keyboard_events_catches_a_type_confusion_bug() -> void:
	# Arrange — 混合鍵盤、手把、滑鼠三種事件型別,鍵盤事件故意放兩個且不相鄰,
	# 用來同時驗證「排除非鍵盤型別」與「不只抓到第一個/漏掉後面的」兩件事。
	var kb_a: InputEventKey = InputEventKey.new()
	kb_a.keycode = KEY_A
	var kb_b: InputEventKey = InputEventKey.new()
	kb_b.keycode = KEY_B
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	var mixed: Array[InputEvent] = [kb_a, pad, mouse, kb_b]

	# Act
	var result: Array[InputEventKey] = _filter_keyboard_events(mixed)

	# Assert — 若篩選邏輯壞成「什麼型別都收」(例如 `is InputEventKey` 誤寫成
	# `is InputEvent`),這裡會拿到 4 筆而非 2 筆,斷言會紅;若壞成「漏篩掉不相鄰的
	# 第二個」,會拿到 1 筆而非 2 筆。兩種壞法都會被下面兩行抓到。
	assert_int(result.size()) \
		.append_failure_message(
			(
				"_filter_keyboard_events() 對混合型別陣列的篩選結果筆數不對——" +
				"預期只留下 2 個 InputEventKey,實際拿到 %d 筆。這代表型別篩選壞了," +
				"依本檔頭部說明,下面全部 9 條 project.godot 內容測試都可能被同一個 bug" +
				"污染而不自知。"
			) % result.size()
		) \
		.is_equal(2)
	assert_int(result[0].keycode).is_equal(KEY_A)
	assert_int(result[1].keycode).is_equal(KEY_B)


func test_sensitivity_proof_filter_joypad_events_catches_a_type_confusion_bug() -> void:
	# Arrange — 與上一條對稱,證明的是 `_filter_joypad_events()`,鍵盤/滑鼠事件皆為
	# 干擾項,手把事件故意放兩個且不相鄰。
	var pad_a: InputEventJoypadButton = InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	var pad_b: InputEventJoypadButton = InputEventJoypadButton.new()
	pad_b.button_index = JOY_BUTTON_B
	var kb: InputEventKey = InputEventKey.new()
	kb.keycode = KEY_ESCAPE
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	var mixed: Array[InputEvent] = [pad_a, kb, mouse, pad_b]

	# Act
	var result: Array[InputEventJoypadButton] = _filter_joypad_events(mixed)

	# Assert
	assert_int(result.size()) \
		.append_failure_message(
			(
				"_filter_joypad_events() 對混合型別陣列的篩選結果筆數不對——" +
				"預期只留下 2 個 InputEventJoypadButton,實際拿到 %d 筆。"
			) % result.size()
		) \
		.is_equal(2)
	assert_int(result[0].button_index).is_equal(JOY_BUTTON_A)
	assert_int(result[1].button_index).is_equal(JOY_BUTTON_B)
