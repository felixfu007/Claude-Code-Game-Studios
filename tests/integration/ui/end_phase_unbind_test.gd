# Story U-016（`production/epics/card-play-interface/story-u016-unbind-end-phase-and-hint-bar.md`）
# —— 🔴 battle_end_phase 解綁 + 操作提示橫條更新,連同管理者裁決八擴大的範圍
# （把 BattleMenu 接進 BattleScreen 並讓 battle_menu 鍵真的打得開它）。
#
# 型別:Integration,證據等級 BLOCKING(依 story 自己的 Test Evidence 節)。
#
# 🔴 AC-U12/AC-M1 是本 epic 30 條 AC 裡唯一一條「防止交付到一半就上線」的條件,
# 而 AC-M1 逐字要求「該路徑實際使敵方回合開始」——不是「選單有那個選項」,是回合真的
# 換手。本檔的 test_end_turn_via_menu_*_path_actually_starts_enemy_phase 兩條就是為此而寫,
# 用 BattleScreen.diagnostic_step_enemy_phase_call_count()(既有 story-018 診斷計數器,
# 直接數 BattleController.step_enemy_phase() 真的被呼叫過幾次)作為主要斷言——不是
# 「confirm 後那一刻 phase() 讀到 ENEMY_ACTING」這種對時序敏感的斷言:若敵方只有
# 一名單位、一步就把整個敵方階段跑完,phase() 在 .pressed.emit() 同步返回的那一刻可能
# 已經跑回 PLAYER_INPUT 了(_end_faction_phase_pressed() 是協程,迴圈第一次判斷就可能
# 在還沒遇到任何 await 之前就整段跑完並 return)——計數器不受這個時序影響,只要
# 呼叫過一次以上就是無可爭辯的「敵方階段真的被驅動過」證據。
#
# 🔴 Button.pressed 在本引擎 --headless 下無法由任何模擬輸入觸發（本專案已測，見
# tests/integration/ui/menu/battle_menu_end_turn_wiring_test.gd 檔頭「headless engine
# limitation」段:InputEventKey 經 push_input()、Input.action_press()/release()、模擬滑鼠
# 點擊,三種手法全部測過,pressed_count 恆為 0)。本檔的「按確認鍵結束回合」因此拆成
# 兩段誠實揭露的證據:①真實方向鍵導覽（headless 可行，已測）把焦點真的移到
# EndPhaseRow;②對「導覽真的到達的那顆按鈕」(不是寫死的節點參照)直接觸發
# .pressed.emit(),證明「真實導覽的落點」與「真的會結束回合的那顆按鈕」是同一顆。
# 這不是「假裝手把/鍵盤真的按下確認」,是與本專案既有測試相同的、已知邊界內的證明。
extends GdUnitTestSuite


const _BATTLE_SCREEN_SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


func _fresh_instance() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_BATTLE_SCREEN_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _real_pressed_event(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


func _real_gamepad_pressed_event(action: StringName) -> InputEventJoypadButton:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var duplicated: InputEventJoypadButton = (event as InputEventJoypadButton).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


## `ui_down` 是 Godot 原生內建動作(選單列的原生 focus 導覽用,U-007~U-010 既有設計,
## 不是本 story 新綁),鍵盤/手把兩側各取一個真實綁定的事件。
func _real_ui_down_key_event() -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(&"ui_down"):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


func _real_ui_down_gamepad_event() -> InputEventJoypadButton:
	for event: InputEvent in InputMap.action_get_events(&"ui_down"):
		if event is InputEventJoypadButton:
			var duplicated: InputEventJoypadButton = (event as InputEventJoypadButton).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


func _end_phase_row(instance: BattleScreen) -> Button:
	return instance._battle_menu.get_node("Panel/ContentMargin/Rows/EndPhaseRow")


func _return_row(instance: BattleScreen) -> Button:
	return instance._battle_menu.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")


# ─── 解綁本身(project.godot)────────────────────────────────────────────────


func test_battle_end_phase_action_has_no_bindings_after_unbind() -> void:
	# Arrange / Act — 直接讀真實 InputMap(headless 下靜態設定讀取不受影響,見本檔
	# 姊妹檔 battle_new_actions_registration_test.gd 檔頭已驗證的結論)。不驗證
	# battle_end_phase 這個 action 是否仍存在——那是 BM-1 的範圍(工作單 Implementation
	# Note 1 明文),本測試只驗證綁定數量。
	var events: Array[InputEvent] = InputMap.action_get_events(&"battle_end_phase")

	# Assert
	assert_int(events.size()).append_failure_message(
		"battle_end_phase 解綁後應該零綁定(project.godot 的 events 陣列應為空),實得 %d 個"
		% events.size()
	).is_equal(0)


# ─── 取消鍵只做取消,不再結束回合(行為層級)──────────────────────────────────


func test_pressing_escape_only_triggers_cancel_not_end_turn() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var round_before: int = instance._order.round_number()

	# Act — 真實鍵盤 Esc 事件(battle_cancel 綁定),經 BattleScreen._input() 真實分派
	instance._input(_real_pressed_event(&"battle_cancel"))

	# Assert — 回合沒有換手:phase 仍是 PLAYER_INPUT,回合數沒有前進,敵方階段
	# 從未被驅動過
	assert_int(instance._controller.phase()).append_failure_message(
		"按 Esc 不應該結束回合——phase 應該仍是 PLAYER_INPUT"
	).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(instance._order.round_number()).is_equal(round_before)
	assert_int(instance.diagnostic_step_enemy_phase_call_count()).append_failure_message(
		"按 Esc 不應該驅動敵方階段任何一步"
	).is_equal(0)


func test_pressing_gamepad_b_only_triggers_cancel_not_end_turn() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var round_before: int = instance._order.round_number()

	# Act — 真實手把 B 事件(battle_cancel 綁定)
	instance._input(_real_gamepad_pressed_event(&"battle_cancel"))

	# Assert
	assert_int(instance._controller.phase()).append_failure_message(
		"按手把 B 不應該結束回合——phase 應該仍是 PLAYER_INPUT"
	).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(instance._order.round_number()).is_equal(round_before)
	assert_int(instance.diagnostic_step_enemy_phase_call_count()).is_equal(0)


# ─── 回歸測試:選單不得預設可見(接線時發現的真實缺陷)───────────────────────


## 🔴 這條測試釘住的是接線過程中實際撞到的一個真缺陷,不是憑空假設:
## BattleMenu.tscn 的根節點從未設定 visible=false,一個剛 instantiate() 的
## BattleMenu 預設 Control.visible==true(is_open() 直接讀這個屬性)——與
## tests/integration/ui/menu/battle_menu_gating_test.gd 早先撞到、並自陳
## 「it was red until this line was added」的同一個坑。若 battle_screen.gd 沒有在
## _ready() 明確把它設回 false,每一場戰鬥從第一格畫面開始選單就會蓋在棋盤上,
## 而且——因為 _handle_battle_menu_pressed() 有「已開啟就不重複呼叫 open()」的
## guard——玩家連 battle_menu 鍵都按不出反應,S4 的強制棄牌選單拒絕邏輯也永遠不會
## 被觸發(因為 open() 從未被真的呼叫過)。本測試是在修正這個缺陷之後才補上的,
## 已用「暫時拿掉 _battle_menu.visible = false 那行 -> 重跑 -> 轉紅 -> 還原 -> 重跑
## -> 轉綠」驗證過,原始輸出見任務報告。
func test_battle_menu_starts_closed_in_a_fresh_battle() -> void:
	# Arrange / Act
	var instance: BattleScreen = _fresh_instance()

	# Assert
	assert_bool(instance._battle_menu.is_open()).append_failure_message(
		"一場新戰鬥剛開始時,選單不應該是開啟狀態——BattleMenu 節點預設 visible=true," +
		"battle_screen.gd 的 _ready() 必須明確把它關掉"
	).is_false()


# ─── AC-U12/AC-M1:選單路徑真的能結束回合,鍵盤與手把各一 ──────────────────────


func test_end_turn_via_menu_keyboard_path_actually_starts_enemy_phase() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	assert_int(instance.diagnostic_step_enemy_phase_call_count()).append_failure_message(
		"PRECONDITION: 敵方階段計數器應該從 0 開始"
	).is_equal(0)

	# Act (i) — 真實鍵盤 M 事件觸發 battle_menu,經 BattleScreen._input() 分派
	instance._input(_real_pressed_event(&"battle_menu"))
	assert_bool(instance._battle_menu.is_open()).append_failure_message(
		"PRECONDITION: battle_menu 鍵應該真的打開選單"
	).is_true()
	assert_bool(_return_row(instance).has_focus()).append_failure_message(
		"PRECONDITION: 選單預設焦點應該在 ReturnToBattleRow(U-010 既有行為)"
	).is_true()

	# Act (ii) — 真實鍵盤方向鍵導覽到 EndPhaseRow(原生 Control focus,headless 可行)
	instance._battle_menu.get_viewport().push_input(_real_ui_down_key_event())
	await get_tree().process_frame

	assert_bool(_end_phase_row(instance).has_focus()).append_failure_message(
		"真實 ui_down 導覽應該把焦點移到 EndPhaseRow"
	).is_true()
	assert_bool(_end_phase_row(instance).disabled).append_failure_message(
		"PRECONDITION: EndPhaseRow 應該是可選狀態(沒有打牌中、沒有待棄牌)"
	).is_false()

	# Act (iii) — Button.pressed 在 headless 下無法由模擬輸入觸發(見本檔檔頭);
	# 對「導覽真的到達的那顆按鈕」直接觸發訊號
	_end_phase_row(instance).pressed.emit()

	# Assert — 敵方階段真的被驅動過(見本檔檔頭為什麼用這個計數器而非 phase() 本身)
	assert_int(instance.diagnostic_step_enemy_phase_call_count()).append_failure_message(
		"選單結束回合(鍵盤路徑)之後,BattleController.step_enemy_phase() 應該至少被" +
		"真實呼叫過一次——這是回合真的換手的證據,不是選單上有這個選項而已"
	).is_greater(0)


func test_end_turn_via_menu_gamepad_path_actually_starts_enemy_phase() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	assert_int(instance.diagnostic_step_enemy_phase_call_count()).is_equal(0)

	# Act (i) — 真實手把 Start 事件觸發 battle_menu
	instance._input(_real_gamepad_pressed_event(&"battle_menu"))
	assert_bool(instance._battle_menu.is_open()).append_failure_message(
		"PRECONDITION: 手把 battle_menu 鍵應該真的打開選單"
	).is_true()
	assert_bool(_return_row(instance).has_focus()).is_true()

	# Act (ii) — 真實手把方向鍵導覽
	instance._battle_menu.get_viewport().push_input(_real_ui_down_gamepad_event())
	await get_tree().process_frame

	assert_bool(_end_phase_row(instance).has_focus()).append_failure_message(
		"真實手把 ui_down 導覽應該把焦點移到 EndPhaseRow"
	).is_true()
	assert_bool(_end_phase_row(instance).disabled).is_false()

	# Act (iii) — 見鍵盤路徑測試同一段說明
	_end_phase_row(instance).pressed.emit()

	# Assert
	assert_int(instance.diagnostic_step_enemy_phase_call_count()).append_failure_message(
		"選單結束回合(手把路徑)之後,BattleController.step_enemy_phase() 應該至少被" +
		"真實呼叫過一次"
	).is_greater(0)


# ─── AC-M16 連帶:battle_menu 鍵的拒絕路徑真的接得到(強制棄牌情境)────────────


func test_battle_menu_during_forced_discard_reaches_rejection_path() -> void:
	# Arrange —— 換上決定性(非隨機)的 6 張牌 CardDeck,驅動到 has_pending_discard()
	# ==true(手法同 tests/integration/ui/forced_discard_test.gd 的
	# _install_forced_discard_state(),此處不 import 該檔的私有輔助函式——本專案既有
	# 慣例是測試檔之間不共用私有 helper,各自持有一份)
	var instance: BattleScreen = _fresh_instance()
	var cards: Array[Card] = []
	for i: int in range(6):
		cards.append(Card.new_temporary_stat_modifier("test_menu_discard_card_%d" % i, 1, 0, 1))
	var deck: CardDeck = CardDeck.new(cards)
	instance._state.attach_card_deck(deck)
	deck.deal_opening_hand()
	deck.draw_for_turn()
	assert_bool(instance._controller.has_pending_discard()).append_failure_message(
		"PRECONDITION: 手牌 6 張應該觸發強制棄牌"
	).is_true()

	# Act — 真實 battle_menu 事件,此刻應該被 _input() 頂端分派放行到
	# _battle_menu.open(),由 open() 自己的 forced_discard_in_progress_check 拒絕
	instance._input(_real_pressed_event(&"battle_menu"))

	# Assert
	assert_bool(instance._battle_menu.is_open()).append_failure_message(
		"強制棄牌進行中,選單不應該真的開啟"
	).is_false()
	assert_int(instance.diagnostic_last_menu_rejection_result()).append_failure_message(
		"拒絕原因應該是 REJECTED_FORCED_DISCARD"
	).is_equal(BattleMenu.OpenResult.REJECTED_FORCED_DISCARD)
	assert_str(instance.diagnostic_last_menu_rejection_message()).append_failure_message(
		"拒絕訊息應該與 BattleMenu 既有常數一致(AC-M16:須明說原因)"
	).is_equal(BattleMenu.REJECTION_MESSAGE_FORCED_DISCARD)


# ─── 操作提示橫條:實際渲染寬度必須放得下(陷阱十,不得只靠目測) ──────────────


func test_controls_hint_bar_fits_within_available_width_with_all_new_actions() -> void:
	# Arrange — 1920x1080(N=4)為代表解析度,與本專案既有 HudLayout 量測慣例一致
	# (story-002-adaptive-font-scale.md 的既有 spike 同樣以此解析度為基準之一)
	var window_size: Vector2i = Vector2i(1920, 1080)
	var fpx: int = HudLayout.font_size(window_size)
	var bg_rect: Rect2 = HudLayout.controls_hint_bg_rect(window_size)
	# ControlsHintLabel 的可用寬度 = 背景寬度 - 左右各 4px margin
	# (BattleScreen.tscn 既有 offset_left=4.0/offset_right=-4.0,不重新假設別的值)
	var available_width: float = bg_rect.size.x - 8.0

	var lines: PackedStringArray = BattleScreen.TEXT_CONTROLS_HINT.split("\n")
	assert_int(lines.size()).append_failure_message(
		"提示橫條文字應該是兩行(本 story 的判斷:改兩行而非分頁系統或縮小字級," +
		"理由見 TEXT_CONTROLS_HINT 自己的 doc comment)"
	).is_equal(2)

	# Act / Assert — 對每一行用真實引擎字型(ControlsHintLabel 沒有 font 覆寫,
	# 使用引擎預設 ThemeDB.fallback_font,同 hud_layout_scaler.gd 實際套用的
	# font_size)量測實際渲染寬度,不靠人工目測
	var font: Font = ThemeDB.fallback_font
	for i: int in range(lines.size()):
		var line: String = lines[i]
		var width: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
		assert_float(width).append_failure_message(
			(
				"第 %d 行「%s」在 1920x1080(fpx=%d)下實際渲染寬度 %.1fpx," +
				"超過可用寬度 %.1fpx"
			) % [i + 1, line, fpx, width, available_width]
		).is_less_equal(available_width)
