# Story U-013（production/epics/card-play-interface/story-u013-target-selection-and-highlight.md）
# 連帶義務的測試：battle_screen.gd 的 S0<->S1 輸入接線（`battle_open_hand`）、
# 「hand_bar.gd 游標索引 -> CardDeck.hand()[index] -> BattleController.select_card()」
# 這段（上一批 active.md 點名的連帶義務），以及 AC-14（「打牌介面開啟中不得發起
# 攻擊」）的既有 move/attack 路徑閘門。
#
# 🔴 本檔不涵蓋 S2/S2p/S2q（目標選取本身）——見
# tests/integration/ui/card_target_selection_test.gd 檔頭同一則說明：卡在
# CursorStateHost 整合的架構問題，交給 godot-specialist 裁決。
#
# 沿用 tests/integration/ui/battle/battle_screen_card_deck_wiring_test.gd 與
# tests/unit/ui/battle_screen_scene_test.gd 的既有慣例：真正 load()/instantiate()
# BattleScreen.tscn 並 add_child()（觸發 _ready() 讀真實 vs01_* 資料檔），而不是
# 只呼叫純函式——這裡要驗證的正是 _ready() 之後、_input() 分派之間的整合行為。
#
# 🔴 _handle_directional()/_handle_hand_navigation() 讀的是 Input 單例的
# is_action_pressed()（輪詢），不是傳入的 InputEvent 本身（見 battle_screen.gd
# 該二函式 doc comment）——本檔驅動方向鍵一律先 Input.action_press()，呼叫後
# 一律 Input.action_release() 清乾淨，避免污染 Input 單例這個全域狀態、影響
# 同一輪測試裡的其他檔案。battle_open_hand/battle_confirm/battle_cancel 則是
# _input() 自己用 event.is_action_pressed() 檢查（不讀 Input 單例），所以用真實
# InputEventKey（InputMap.action_get_events() 取出後 duplicate() 並手動補上
# pressed = true——沿用 tests/integration/cursor/frame_buffer_ordering_test.gd
# 的「真實事件」慣例,但那份測試的消費端只看 event_is_action() 的結構性比對,
# 不看 pressed,故不需要這一步；本檔的消費端是 event.is_action_pressed(),需要）。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


func _real_pressed_event(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


func _fresh_instance() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


# ─── battle_open_hand —— S0 -> S1 ───────────────────────────────────────────


func test_battle_open_hand_opens_hand_session_and_expands_hand_bar() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	assert_bool(instance._controller.is_card_play_in_progress()).append_failure_message(
		"新場景一開始就應該是 CLOSED（S0），不是打牌狀態"
	).is_false()

	# Act
	instance._input(_real_pressed_event(&"battle_open_hand"))

	# Assert
	assert_bool(instance._controller.is_card_play_in_progress()).append_failure_message(
		"按下 battle_open_hand 後應進入 S1（CardPlaySession.is_open() == true）"
	).is_true()
	assert_bool(instance._card_selecting_from_hand).is_true()
	assert_bool(instance._hand_bar.diagnostic_is_expanded()).append_failure_message(
		"Z1 應原地展開為 Z2"
	).is_true()


func test_battle_open_hand_pressed_again_while_selecting_card_closes_back_to_s0() -> void:
	# Arrange — 先開手牌
	var instance: BattleScreen = _fresh_instance()
	instance._input(_real_pressed_event(&"battle_open_hand"))
	assert_bool(instance._controller.is_card_play_in_progress()).is_true()

	# Act — Interaction Map「選擇不打」：再按一次開手牌鍵應收起（不需要另一把鍵）
	instance._input(_real_pressed_event(&"battle_open_hand"))

	# Assert
	assert_bool(instance._controller.is_card_play_in_progress()).append_failure_message(
		"S1 再按一次開手牌鍵應退回 S0（CLOSED），不是停留在 S1"
	).is_false()
	assert_bool(instance._card_selecting_from_hand).is_false()
	assert_bool(instance._hand_bar.diagnostic_is_expanded()).is_false()


func test_battle_cancel_while_selecting_card_also_closes_back_to_s0() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._input(_real_pressed_event(&"battle_open_hand"))

	# Act
	instance._input(_real_pressed_event(&"battle_cancel"))

	# Assert
	assert_bool(instance._controller.is_card_play_in_progress()).is_false()
	assert_bool(instance._card_selecting_from_hand).is_false()


# ─── 連帶義務：hand_bar 游標索引 -> CardDeck.hand()[index] -> select_card() ────


func test_hand_navigation_moves_cursor_index_only_while_selecting_card() -> void:
	# Arrange — 尚未開手牌時，方向鍵不應動到 hand_bar 的游標
	var instance: BattleScreen = _fresh_instance()
	var index_before_open: int = instance._hand_bar.diagnostic_cursor_index()

	Input.action_press(&"ui_right")
	instance._input(_real_pressed_event(&"ui_right"))
	Input.action_release(&"ui_right")
	assert_int(instance._hand_bar.diagnostic_cursor_index()).append_failure_message(
		"S0（未開手牌）時方向鍵不應移動 hand_bar 的游標"
	).is_equal(index_before_open)

	# Act — 開手牌後（S1），方向鍵應移動 hand_bar 的游標
	instance._input(_real_pressed_event(&"battle_open_hand"))
	Input.action_press(&"ui_right")
	instance._input(_real_pressed_event(&"ui_right"))
	Input.action_release(&"ui_right")

	# Assert
	assert_int(instance._hand_bar.diagnostic_cursor_index()).append_failure_message(
		"S1（選牌中）時 ui_right 應把 hand_bar 的游標往右移一張"
	).is_equal(index_before_open + 1)


func test_confirm_selected_card_reads_index_maps_to_card_and_calls_select_card() -> void:
	# Arrange — 真實開局手牌（vs01_cards.txt 8 張、CardDeck.OPENING_HAND_SIZE=5，
	# 足夠索引 1 存在）
	var instance: BattleScreen = _fresh_instance()
	instance._input(_real_pressed_event(&"battle_open_hand"))

	var hand_before: Array[Card] = instance._state.card_deck().hand()
	assert_int(hand_before.size()).append_failure_message(
		"預期開局手牌至少 2 張才能移動游標到索引 1，實得 %d 張——vs01_cards.txt/"
		+ "CardDeck.OPENING_HAND_SIZE 的資料是否變動了？"
	).is_greater_equal(2)

	Input.action_press(&"ui_right")
	instance._input(_real_pressed_event(&"ui_right"))
	Input.action_release(&"ui_right")
	var cursor_index: int = instance._hand_bar.diagnostic_cursor_index()
	assert_int(cursor_index).is_equal(1)
	var expected_card: Card = hand_before[cursor_index]

	# Act — 這是連帶義務的核心一步：battle_confirm 必須把「hand_bar 游標停在的
	# 索引」轉成「CardDeck.hand() 同一個索引的那張 Card」,再呼叫
	# BattleController.select_card(),而不是隨便選一張或索引對錯位
	instance._input(_real_pressed_event(&"battle_confirm"))

	# Assert — session 已離開 SELECTING_CARD（S1），並且選中的正是索引 1 那張卡
	# （身分比對，is_same()，不是只比對 category/id 這種可能巧合相等的欄位）
	assert_bool(instance._card_selecting_from_hand).append_failure_message(
		"select_card() 成功後應離開 S1（hand_bar 收合）"
	).is_false()
	assert_bool(instance._hand_bar.diagnostic_is_expanded()).is_false()
	assert_int(instance._controller._card_play_session.step()).append_failure_message(
		"select_card() 成功後 CardPlaySession 應進入 SELECTING_TARGET（S2/S2p）"
	).is_equal(CardPlaySession.Step.SELECTING_TARGET)
	assert_object(instance._controller._card_play_session._selected_card).append_failure_message(
		"CardPlaySession 記住的選定卡必須是 hand_bar 游標停在的那一張（索引 %d）,"
		% cursor_index + "不是別張——這正是本連帶義務要接對的那一段轉換"
	).is_same(expected_card)


func test_confirm_selected_card_is_a_no_op_when_hand_is_empty() -> void:
	# Arrange — 誠實登記的邊界情況（S7 空手牌）：診斷游標索引在空手牌時會被夾到 0，
	# 而 hand.size() 也是 0，_confirm_selected_card() 的邊界檢查必須擋下這個組合，
	# 不能當成「索引 0 存在」而越界讀取
	var instance: BattleScreen = _fresh_instance()
	# 把手牌清空，模擬 S7（打光或卡池不足）——不直接操縱私有欄位以外的公開介面：
	# 逐張 play_card() 到用完為止（CardDeck 公開介面允許的操作）
	var deck: CardDeck = instance._state.card_deck()
	for card: Card in deck.hand():
		deck.play_card(card)
	assert_int(deck.hand_size()).is_equal(0)

	instance._input(_real_pressed_event(&"battle_open_hand"))

	# Act — 空手牌時按確認，不應崩潰、也不應呼叫 select_card()
	instance._input(_real_pressed_event(&"battle_confirm"))

	# Assert — 仍停在 S1（沒有東西可選，session 沒有被改變）
	assert_bool(instance._card_selecting_from_hand).append_failure_message(
		"空手牌時按確認不應該讓 session 離開 S1（沒有卡可選）"
	).is_true()


# ─── AC-14 —— 打牌介面開啟中不得發起攻擊/移動（既有 move/attack 路徑閘門）──────


func test_click_on_own_unit_selects_it_when_no_card_play_is_open() -> void:
	# Arrange — 控制組：證明點擊機制與座標換算本身是對的（否則下一條測試的
	# 「沒有被選中」有可能只是座標算錯,不是閘門生效）
	var instance: BattleScreen = _fresh_instance()
	var player_unit: Unit = instance._state.units_of(Unit.Faction.PLAYER)[0]
	var cell: Vector2i = instance._state.position_of(player_unit.id)
	var click_event: InputEventMouseButton = _click_event_at_cell(instance, cell)

	# Act
	instance._handle_mouse_button(click_event)

	# Assert
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"未開手牌時點擊自己的單位應該選中它（控制組——證明座標換算與點擊機制本身正確）"
	).is_equal(player_unit.id)


func test_click_on_own_unit_is_gated_while_card_play_session_is_open() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var player_unit: Unit = instance._state.units_of(Unit.Faction.PLAYER)[0]
	var cell: Vector2i = instance._state.position_of(player_unit.id)
	var click_event: InputEventMouseButton = _click_event_at_cell(instance, cell)
	instance._input(_real_pressed_event(&"battle_open_hand"))
	assert_bool(instance._controller.is_card_play_in_progress()).is_true()

	# Act — 與上一條完全相同的點擊，唯一差異是打牌介面已開啟
	instance._handle_mouse_button(click_event)

	# Assert — AC-14：不得發起（這裡是移動/選取）——若閘門寫反或被拿掉，
	# 這條會變成 is_equal(player_unit.id) 而不是 is_equal(-1)，當場變紅
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"打牌介面開啟中,同一個點擊不得選中/操作棋盤上的單位（AC-14）"
	).is_equal(-1)


func test_directional_input_does_not_move_board_cursor_while_card_play_session_is_open() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var cursor_before: Vector2i = instance._cursor_cell
	instance._input(_real_pressed_event(&"battle_open_hand"))

	# Act — ui_down 既不是 hand 導覽用的鍵（只接 left/right），也不應該落到舊的
	# 棋盤方向鍵路徑（該路徑現在整段被閘在 is_card_play_in_progress() 之外）
	Input.action_press(&"ui_down")
	instance._input(_real_pressed_event(&"ui_down"))
	Input.action_release(&"ui_down")

	# Assert
	assert_vector(instance._cursor_cell).append_failure_message(
		"打牌介面開啟中,方向鍵不應移動既有的棋盤 move/attack 游標"
	).is_equal(cursor_before)


func _click_event_at_cell(instance: BattleScreen, cell: Vector2i) -> InputEventMouseButton:
	var window_size: Vector2i = instance.get_window().size
	var canvas_to_window: Transform2D = WorldLayout.canvas_to_window_transform(window_size)
	var raw_pos: Vector2 = BoardCoords.grid_to_window(cell, canvas_to_window, Vector2.ZERO)
	var click_event: InputEventMouseButton = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = raw_pos
	return click_event


# 敏感度證明的原始輸出(手動改壞 -> 跑 -> 還原 -> 再跑)留在本 story 的任務報告裡,
# 不寫死在這裡——寫死一份「已執行過」的清單卻沒有可查證的痕跡,正是本專案已經
# 記過一次的失效形狀。見任務報告的「敏感度證明」節。
#
# 🔴 本段刻意不把「掃描注入標記的那串字面字元」原樣寫進這份原始碼——本專案另有
# 一個治理習慣:跑一次全庫搜尋,確認暫時性的手動改壞沒有殘留忘記還原。若那個標記
# 字串本身出現在任何原始碼裡（哪怕只是像現在這樣，出現在描述它的註解裡），那次
# 搜尋就永遠不會回報「零殘留」,真正的殘留會被這個常態雜訊淹沒、看不出來——
# 這正是 2026-09-22 協調者在本 story 抓到的一個實例(本檔曾經這樣寫,已修正)。
# 依 .claude/rules/test-standards.md 的官方敏感度證明門檻(間諜子類別 + 常駐
# test_sensitivity_proof_* 測試,`grep '^func test_sensitivity'` 可查證),本檔
# 的斷言多數屬於該檔「已知證明不了的五類」之外的第六類（直接讀取真實全域狀態、
# 中間沒有自有判斷邏輯的欄位比對）——這裡不硬做間諜子類別去湊一份形式證明。
