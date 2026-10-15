## Story 010（production/epics/tactical-combat/story-010-direction-key-debounce-convergence.md）
## BLOCKING test evidence.
##
## 查證結論(詳見 prototypes/story-010-echo-vs-joypad-probe-2026-10-15/README.md 全文與
## 兩支探針的逐字輸出):ADR-0005 的 `InputEventKey.echo` 過濾
## （[method CursorTypes.classify_action]，`cursor_types.gd:165`）**結構上不可能**涵蓋
## 手把類比搖桿的長按重複觸發 —— [InputEventJoypadMotion] / [InputEventJoypadButton]
## **根本沒有 `echo` 這個屬性**（engine-verified，§1 下方三條測試把這個結構事實釘成
## 迴歸鎖,不只是文件描述）。因此本 story 的結論是**不收斂**：
## `battle_screen.gd` 自維護的 Dictionary 去抖（[method BattleScreen._direction_just_pressed]
## / `_direction_was_pressed` / `_hand_direction_was_pressed`）維持原樣，不得被
## echo 過濾取代或刪除。
##
## 本檔即是「驗證既有 Dictionary 去抖邏輯仍正確運作」這條要求的 BLOCKING 證據
## （本 story QA Test Cases 節，「echo 不涵蓋手把」分支的規格），涵蓋：
##   §1 — 結構性發現：InputEventJoypadMotion/InputEventJoypadButton 沒有 echo 屬性
##   §2 — 長按只觸發一次（QA ①）、放開後再按下會重新觸發（QA ②）—— 透過
##        [method BattleScreen._handle_hand_navigation] 的真實可觀察副作用
##        （[method HandBar.diagnostic_cursor_index]）驗證，這是兩個呼叫端裡
##        唯一還有實際消費者的一個（[method BattleScreen._handle_directional] 的
##        debounce 結果自 Story 009 起恆為 `pass`，見該方法自己的 doc comment）。
##   §3 — 兩個呼叫端（棋盤游標 / 手牌列游標）的 tracker 彼此獨立、不互相污染（QA ③）
##        —— 這是 `_direction_was_pressed` 欄位自己 doc comment 明文的設計意圖
##        （"sharing one tracker between them would let a held direction on one
##        bleed into the other's edge detection"），本測試把它釘成迴歸鎖。
##
## 驅動手法沿用 tests/integration/ui/battle/battle_screen_card_play_wiring_test.gd
## 既有慣例，不自創：真正 load()/instantiate() BattleScreen.tscn 並 add_child()
## （觸發 _ready() 讀真實 vs01_* 資料檔），方向鍵一律先 Input.action_press()
## （_handle_directional()/_handle_hand_navigation() 讀的是 Input 單例的
## is_action_pressed() 輪詢，不是傳入事件本身），呼叫後一律 Input.action_release()
## 清乾淨；battle_open_hand 用真實 InputEventKey（InputMap.action_get_events() 取出
## 後 duplicate() 並補 pressed = true，因為消費端是 event.is_action_pressed()）。
##
## ⚠️ 放開鍵也必須把對應的 pressed=false 事件送進 _input() 一次，見
## [method _real_released_event] 的 doc comment —— 這不是裝飾，是第一次寫本檔時
## 漏掉、被引擎實測打回來才補上的：單純呼叫 Input.action_release() 不送事件，
## tracker 永遠停在 true，第二次按下偵測不到新的邊緣觸發。
##
## 敏感度證明（.claude/rules/test-standards.md 2026-09-16 裁決）：§3
## [method test_board_and_hand_direction_trackers_do_not_cross_contaminate]
## 已用**手動注入**驗證過會抓到它要防的錯誤 —— 暫時把 battle_screen.gd 的
## `_init()` 改成 `_hand_direction_was_pressed = _direction_was_pressed`
## （兩個 tracker 共用同一個 Dictionary），單獨重跑本檔，§3 準確地紅掉：
## `Expecting: 1 / but was: 0`，訊息為本測試自己寫的
## 「S0 的棋盤方向鍵按下不應影響 S1 手牌列游標自己的邊緣觸發判斷」，其餘 5 條
## 不受影響（6 test cases | 1 failures）；確認後已改回、`git diff` 核對零殘留。
## 🔴 誠實揭露：這是手動注入（改壞 -> 跑 -> 改回），不是本專案規定格式的常駐
## `test_sensitivity_proof_*` + 間諜子類別 —— 未補上常駐版本的理由是
## [method BattleScreen._direction_just_pressed] 是具體類別上的私有輔助方法，
## 沒有介面/虛擬方法可供子類別攔截 `tracker: Dictionary` 參數本身，要做成間諜
## 子類別需要重新衍生整個 BattleScreen 並覆寫 `_handle_hand_navigation()`，
## 代價與本 story 的範圍（查證收斂可行性，而非新建測試基礎設施）不成比例，
## 故本條目依規則「不可證的理由必須逐條寫下」誠實登記為手動注入而非常駐證明，
## 而非蓋過不提。§1、§2 四條未附帶手動注入證明 —— §1 是對 Godot 引擎類別本身
## 屬性清單的斷言（屬 test-standards.md A′類：無類別可注入錯誤版本的真實資料/
## 引擎事實），§2 兩條已由 §3 的注入過程間接證明「debounce 真的在運作」（若
## debounce 機制整個失效，§2 兩條會先紅，§3 測的是更細緻的「兩份獨立」而非
## 「debounce 本身存在」）。
extends GdUnitTestSuite

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


## 放開鍵的事件 —— 在真實遊戲中，放開按鍵本身會產生一個 pressed=false 的
## InputEventKey 並送進 _input()，這正是讓 _direction_just_pressed() 的 tracker
## 在下一次按下前先看到一次 false 的機制（見本檔下方 debug 記錄：單純呼叫
## Input.action_release() 而不搭配送一個事件進 _input()，tracker 永遠不會被寫回
## false，第二次按下就不會被偵測為新的邊緣觸發）。不是為了「更像真實輸入」而加的
## 裝飾，是因為第一次寫測試時漏了這一步，實測直接讓
## test_release_then_press_again_retriggers_hand_cursor_move 紅掉，才發現生產
## 程式碼的去抖本來就依賴「放開事件也會被送進 _input() 一次」這個前提。
func _real_released_event(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = false
			return duplicated
	return null


func _has_property(obj: Object, prop_name: String) -> bool:
	for p: Dictionary in obj.get_property_list():
		if p["name"] == prop_name:
			return true
	return false


## 與 battle_screen_card_play_wiring_test.gd 的 after_test() 相同義務：本檔
## _fresh_instance() 也會 add_child() 一個真實 BattleScreen，其 _ready() 會在
## 真實、共用的 CursorStateHost Autoload 上註冊 BOARD_TILE。不清掉的話，後續
## 測試檔案若也操作 BOARD_TILE 這個 surface type，會撞到
## "Trying to return a previously freed instance." —— 該檔 after_test() 的
## doc comment 有完整重現記錄，此處採同一套清理，不重新發明。
func after_test() -> void:
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


# ─── §1: 結構性發現 —— echo 是鍵盤專屬概念,手把事件類別連屬性都沒有 ──────────


func test_input_event_key_has_echo_property() -> void:
	# Arrange / Act — 先驗證反射技巧本身有效（對照組）：InputEventKey 確實宣告了
	# echo 屬性。
	var event := InputEventKey.new()

	# Assert
	assert_bool(_has_property(event, "echo")).append_failure_message(
		"InputEventKey 預期宣告 echo 屬性 —— 若此處失敗，代表下面兩條測試的反射" +
		"技巧本身可能有問題，不能信任其 false 結果"
	).is_true()


func test_input_event_joypad_motion_has_no_echo_property() -> void:
	# Arrange / Act — engine-verified
	# （prototypes/story-010-echo-vs-joypad-probe-2026-10-15/run_output_echo_property.txt）：
	# InputEventJoypadMotion 完全沒有宣告 echo 屬性。這正是
	# CursorTypes.classify_action() 的
	# `event is InputEventKey and (event as InputEventKey).echo` 過濾
	# （cursor_types.gd:165）結構上無法比照擴充到過濾重複手把搖桿事件的原因 ——
	# 沒有這個欄位可以檢查。
	var event := InputEventJoypadMotion.new()

	# Assert
	assert_bool(_has_property(event, "echo")).append_failure_message(
		"InputEventJoypadMotion 不應有 echo 屬性 —— 若此處失敗，echo 過濾涵蓋手把" +
		"的結論需要重新查證，本 story 的『不收斂』結論也需要重新評估"
	).is_false()
	assert_object(event.get("echo")).append_failure_message(
		"get('echo') 預期回傳 null（不存在的屬性）"
	).is_null()


func test_input_event_joypad_button_has_no_echo_property() -> void:
	# Arrange / Act — 與 InputEventJoypadMotion 同樣的結構性缺失。
	var event := InputEventJoypadButton.new()

	# Assert
	assert_bool(_has_property(event, "echo")).append_failure_message(
		"InputEventJoypadButton 不應有 echo 屬性"
	).is_false()
	assert_object(event.get("echo")).append_failure_message(
		"get('echo') 預期回傳 null（不存在的屬性）"
	).is_null()


# ─── §2: _handle_hand_navigation() 的 Dictionary 去抖（QA ①②）────────────────


func test_held_direction_moves_hand_cursor_only_once() -> void:
	# Arrange — 開手牌進入 S1，記錄起始游標索引
	var instance: BattleScreen = _fresh_instance()
	instance._input(_real_pressed_event(&"battle_open_hand"))
	var index_before: int = instance._hand_bar.diagnostic_cursor_index()

	# Act — 模擬「長按不放」：只呼叫一次 Input.action_press()（代表玩家按住的
	# 那一瞬間狀態不變），但把 _input() 呼叫多次（模擬長按期間多次事件/多幀
	# 都讀到 pressed=true 這個相同的全域狀態，不在中間 release）
	Input.action_press(&"ui_right")
	for _i in range(5):
		instance._input(_real_pressed_event(&"ui_right"))
	Input.action_release(&"ui_right")

	# Assert — 不論 _input() 被呼叫幾次，長按期間只應該移動一次
	assert_int(instance._hand_bar.diagnostic_cursor_index()).append_failure_message(
		"長按方向鍵期間呼叫 _input() 5 次，預期 hand_bar 游標只移動一次（%d -> %d），" % [
			index_before, index_before + 1
		] + "實得 %d —— 若此處失敗，Dictionary 去抖可能被破壞，長按會讓游標連續移動"
		% instance._hand_bar.diagnostic_cursor_index()
	).is_equal(index_before + 1)


func test_release_then_press_again_retriggers_hand_cursor_move() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._input(_real_pressed_event(&"battle_open_hand"))
	var index_before: int = instance._hand_bar.diagnostic_cursor_index()

	# Act — 第一次按下 -> 放開。放開時也要把「放開事件」送進 _input()
	# 一次，對應真實遊戲中放開按鍵會產生自己的 pressed=false 事件 ——
	# 否則 tracker 永遠停在 true，下一次按下不會被偵測成新的邊緣觸發
	# （見 _real_released_event() 的 doc comment，記錄了這個寫法為什麼必要）。
	Input.action_press(&"ui_right")
	instance._input(_real_pressed_event(&"ui_right"))
	Input.action_release(&"ui_right")
	instance._input(_real_released_event(&"ui_right"))
	var index_after_first_press: int = instance._hand_bar.diagnostic_cursor_index()

	# Act — 放開後再次按下 -> 放開，應該各自獨立重新觸發一次
	Input.action_press(&"ui_right")
	instance._input(_real_pressed_event(&"ui_right"))
	Input.action_release(&"ui_right")
	instance._input(_real_released_event(&"ui_right"))

	# Assert — 兩次按下動作各自觸發一次移動，總共移動兩格
	assert_int(index_after_first_press).append_failure_message(
		"第一次按下應移動一格"
	).is_equal(index_before + 1)
	assert_int(instance._hand_bar.diagnostic_cursor_index()).append_failure_message(
		"放開後再次按下應該重新觸發，預期總共移動兩格（%d -> %d）" % [
			index_before, index_before + 2
		]
	).is_equal(index_before + 2)


# ─── §3: 兩個呼叫端的 tracker 彼此獨立，不互相污染（QA ③）─────────────────────


func test_board_and_hand_direction_trackers_do_not_cross_contaminate() -> void:
	# Arrange — S0（手牌未開），按一次 ui_right 並放開。此時會走
	# _handle_directional() 這條路（_card_selecting_from_hand 為 false），
	# 其 debounce 結果雖然自 Story 009 起不再移動棋盤游標（恆為 pass），但仍會
	# 呼叫 _direction_just_pressed(&"ui_right", _direction_was_pressed)，把
	# _direction_was_pressed[&"ui_right"] 寫成 true 這個副作用。
	var instance: BattleScreen = _fresh_instance()
	assert_bool(instance._controller.is_card_play_in_progress()).append_failure_message(
		"前提：S0 時不應有進行中的打牌 session"
	).is_false()

	Input.action_press(&"ui_right")
	instance._input(_real_pressed_event(&"ui_right"))
	Input.action_release(&"ui_right")

	assert_bool(instance._direction_was_pressed.get(&"ui_right", false)).append_failure_message(
		"前提：S0 的 ui_right 按下應已寫入 _direction_was_pressed[ui_right] = true" +
		"（棋盤游標自己的 tracker，與下面 S1 要用的 _hand_direction_was_pressed 是" +
		"兩個不同的 Dictionary）"
	).is_true()

	# Act — 開手牌進入 S1，第一次按下 ui_right。若兩個 tracker 共用同一份狀態，
	# 這裡 _hand_direction_was_pressed[&"ui_right"] 會被誤判成「已經是 true」
	# （沿用上面 S0 那次按下留下的狀態），導致這次邊緣觸發被錯誤地吃掉、
	# hand_bar 游標不會移動。
	instance._input(_real_pressed_event(&"battle_open_hand"))
	var index_before: int = instance._hand_bar.diagnostic_cursor_index()

	Input.action_press(&"ui_right")
	instance._input(_real_pressed_event(&"ui_right"))
	Input.action_release(&"ui_right")

	# Assert — S1 的這次按下必須被視為全新的邊緣觸發，正確移動 hand_bar 游標。
	# 若此處失敗（游標沒有移動），代表兩個 Dictionary 被意外合併或共用，
	# 棋盤游標的按鍵歷史洩漏進了手牌列游標的去抖判斷。
	assert_int(instance._hand_bar.diagnostic_cursor_index()).append_failure_message(
		"S0 的棋盤方向鍵按下不應影響 S1 手牌列游標自己的邊緣觸發判斷 —— 預期從 %d" % index_before +
		" 移動到 %d，若 tracker 被污染則會卡在 %d 不動" % [index_before + 1, index_before]
	).is_equal(index_before + 1)
