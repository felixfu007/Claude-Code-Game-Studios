## story-060:開戰鬥選單時隱藏開場目標框(目標框不得蓋住選單「回到遊戲」列)。
##
## 真實場景載入(technical-preferences「第 5 點」):load() BattleScreen.tscn -> instantiate()
## -> (set_script 先於任何屬性)-> 設 override -> call_deferred("add_child") -> 等 2 個 process_frame。
##
## ## 檔案 I/O 使用揭露
## 甲類:BattleScreen 預設載入的真實關卡/名冊資料檔(assets/data/,已進版控;不注入夾具,
## 因 duel 夾具與預設 Board 尺寸不合,實測產生 push_error)。
## 🔴 不證明窮盡性:只驗「開選單 / 目標列 / 結束回合」三條路徑上的目標框可見性;
## 不證明版面(目標框與選單列是否不重疊)—— 那由開窗實拍(AC7)與人眼(AC8)負責。
##
## ## 敏感度證明(常駐 mutant + set_script)
## ① _MutantNeverHides:選單開啟時不收起 -> AC1 紅。
## ② _MutantHidesOnAnyChange(關閉時也隱藏):🔴 證明不了 —— 「目標」列是 close() 再 emit,
##    close() 觸發的隱藏發生在 show_objective() 之前,最終狀態與正確實作逐位元相同;
##    且關閉當下目標框本來就是隱藏的(開啟時已收起),故任何路徑都分不出兩者(等價 mutant)。
## ③ _MutantHideKeepsTimer:hide_objective 不停 Timer -> AC3 紅。
## ④ _MutantTimerAlwaysNoHide(修法 B):Timer 改 ALWAYS 而不隱藏 -> AC1 紅。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	get_tree().paused = false


## ① 選單開啟時不收起目標框。
class _MutantNeverHides extends BattleScreen:
	func _on_battle_menu_visibility_for_objective() -> void:
		pass


## ③ hide_objective 只藏面板、不停 Timer。
class _MutantHideKeepsTimer extends BattleScreen:
	func hide_objective() -> void:
		if _objective_panel != null:
			_objective_panel.visible = false


## ④ 修法 B:Timer 不受暫停影響、不主動隱藏。
class _MutantTimerAlwaysNoHide extends BattleScreen:
	func _on_battle_menu_visibility_for_objective() -> void:
		var timer: Timer = get_node_or_null("ObjectiveTimer") as Timer
		if timer != null:
			timer.process_mode = Node.PROCESS_MODE_ALWAYS


func _make_screen(script: GDScript = null) -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	if script != null:
		instance.set_script(script)  # 🔴 先於任何屬性賦值(test-standards 陷阱一)
	auto_free(instance)
	get_tree().root.call_deferred("add_child", instance)
	await get_tree().process_frame
	await get_tree().process_frame
	return instance


func _timer_of(screen: BattleScreen) -> Timer:
	return screen.get_node_or_null("ObjectiveTimer") as Timer


func test_objective_menu_open_hides_panel_while_paused() -> void:
	var screen: BattleScreen = await _make_screen()
	assert_bool(screen.is_objective_visible()).append_failure_message("PRECONDITION: 開場目標框應可見").is_true()

	screen._handle_battle_menu_pressed()

	assert_bool(get_tree().paused).append_failure_message("斷言須發生在暫停狀態").is_true()
	assert_bool(screen._battle_menu.visible).is_true()
	assert_bool(screen.is_objective_visible()).is_false()


func test_objective_row_press_reshows_panel_and_survives() -> void:
	var screen: BattleScreen = await _make_screen()
	screen._handle_battle_menu_pressed()

	screen._battle_menu._objective_row.pressed.emit()

	assert_bool(screen._battle_menu.visible).is_false()
	assert_bool(screen.is_objective_visible()).is_true()
	await get_tree().create_timer(BattleScreen.OBJECTIVE_AUTO_HIDE_SECONDS / 20.0).timeout
	assert_bool(screen.is_objective_visible()).append_failure_message("重看後不得被關閉回呼立刻關掉").is_true()


func test_objective_timer_stopped_on_menu_open_and_restarted_on_review() -> void:
	var screen: BattleScreen = await _make_screen()
	screen._handle_battle_menu_pressed()
	assert_bool(_timer_of(screen).is_stopped()).is_true()

	screen._battle_menu._objective_row.pressed.emit()

	var timer: Timer = _timer_of(screen)
	assert_bool(timer.is_stopped()).is_false()
	assert_float(timer.time_left).is_between(
		BattleScreen.OBJECTIVE_AUTO_HIDE_SECONDS - 1.0, BattleScreen.OBJECTIVE_AUTO_HIDE_SECONDS
	)


func test_objective_hidden_during_enemy_phase() -> void:
	var screen: BattleScreen = await _make_screen()
	screen._handle_battle_menu_pressed()

	screen._battle_menu._end_phase_row.pressed.emit()

	assert_bool(screen.is_objective_visible()).append_failure_message("敵方回合不應有目標框").is_false()
	await get_tree().process_frame
	assert_bool(screen.is_objective_visible()).is_false()


func test_objective_not_reappearing_after_menu_closed_without_objective_row() -> void:
	var screen: BattleScreen = await _make_screen()
	screen._handle_battle_menu_pressed()

	screen._battle_menu.close()
	await get_tree().process_frame

	assert_bool(screen.is_objective_visible()).is_false()


func test_sensitivity_proof_never_hides_fails_ac1() -> void:
	var screen: BattleScreen = await _make_screen(_MutantNeverHides)
	screen._handle_battle_menu_pressed()
	# 偵測器:正確實作下此為 false;mutant 下仍為 true,AC1 斷言會紅。
	assert_bool(screen.is_objective_visible()).is_true()


func test_sensitivity_proof_hide_keeps_timer_fails_ac3() -> void:
	var screen: BattleScreen = await _make_screen(_MutantHideKeepsTimer)
	screen._handle_battle_menu_pressed()
	assert_bool(screen.is_objective_visible()).is_false()
	assert_bool(_timer_of(screen).is_stopped()).is_false()


func test_sensitivity_proof_method_b_fails_ac1() -> void:
	var screen: BattleScreen = await _make_screen(_MutantTimerAlwaysNoHide)
	screen._handle_battle_menu_pressed()
	assert_bool(screen.is_objective_visible()).is_true()
	assert_int(_timer_of(screen).process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
