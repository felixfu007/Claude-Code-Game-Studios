## battle-hud story-002 (`production/epics/battle-hud/story-002-guess-selector-ui-and-input.md`)
## —— 效果猜測標記(EGM)選擇器的畫面與輸入,真實 BattleScreen.tscn 載入。
##
## 載入方式比照 `tests/integration/ui/attack_confirm_panel_test.gd` 與
## `tests/integration/ui/shell/egm_setting_test.gd`:load() 真實場景、
## GameSettings.set_egm_enabled() 於 instantiate 之前設定(BattleScreen 只在 _ready()
## 讀一次),不組替身節點鏈。
##
## 🔴 涵蓋範圍誠實揭露:
##   - 本檔只做 headless。AC2/AC4/AC10 的「畫面上看起來對不對」(按鈕位置、字級、
##     ✓/✕/▸ 字形是否被字型支援、滑鼠移上按鈕時游標是否被拖離候選格)
##     【未涵蓋】,留給有畫面的環境人眼驗收。
##   - headless 不送 InputEvent:鍵盤/手把用「由 InputMap 取出真實事件、pressed=true、
##     直接餵給 BattleScreen._input()」;滑鼠選擇用 Button.pressed.emit()。
##     這證明的是 BattleScreen 的分派,不是引擎能否把實體按鍵轉成事件。
##   - 敏感度證明:見下方對照表。常駐變種為 `_Mutant*` / `_Tracker*` 子類別,
##     證明測試為 `test_sensitivity_proof_*`(Case A:set_script 在 add_child 之前)。
##
## ==== 敏感度證明對照表(21 條逐列;ac03 mouse_click 已補證明)====
## 測試名 | 證明方式或不可證類別 | 理由
## test_ac01_egm_off_preview_shown_immediately_no_selector | 可證:..._egm_off_hiding_preview_ + ..._egm_off_building_tracker_ | 預覽立即顯示 / tracker 為 null 兩半各有變種
## test_ac01_egm_off_guess_cycle_key_does_nothing | 可證:..._cycle_key_without_guard_ | 變種拿掉狀態守衛
## test_ac02_egm_on_unguessed_candidate_hides_preview_and_shows_selector | 部分可證:..._pending_revealed_early_ | 「隱藏預覽+顯示選擇器」有證明;「棋子自己腳下不出現選擇器」那一半【未驗證】(無對應變種)
## test_ac03_keyboard_cycle_then_confirm_completes_a_guess | 可證:..._confirm_never_locking_ | 變種確認不鎖定
## test_ac03_gamepad_cycle_then_confirm_completes_a_guess | 可證:..._cycle_skipping_negative_ | 變種循環漏掉「負」;手把確認路徑與鍵盤共用 _handle_guess_confirm,不另證
## test_ac03_mouse_button_press_completes_a_guess | 可證:..._button_ignoring_direction_ | 變種按鈕一律鎖「正」
## test_ac03_mouse_click_on_selector_is_not_also_a_board_click | 可證:..._selector_click_leaking_to_board_ | 先前空轉的成因(已實測):按鈕落在棋盤範圍外(cell=(5,-1)),_handle_mouse_button 的 is_in_bounds 檢查先擋掉,守衛從未被觸發。現已把按鈕蓋到候選格 b 並加前提斷言(格子在棋盤內且等於 b);變種 _MutantSelectorGuardRemoved 拿掉守衛 -> 單位移到 b
## test_ac03_project_binds_guess_cycle_to_x_and_joy_button_y | 不可證:A′ | 斷言對象是專案 InputMap 設定資料,無可注入類別
## test_ac04_real_values_absent_before_lock_present_right_after | 可證:..._pending_revealed_early_ | 變種把揭曉提前;「鎖定後立即出現」那一半無獨立變種【未驗證】
## test_ac08_locked_cell_stays_locked_after_leaving_and_returning | 可證:..._locked_cell_reopening_ | 變種鎖定後選擇器重開;「鎖定後無法改猜」(追蹤器內部邏輯)那一半【未驗證】
## test_ac08_mismatch_stays_mismatch_when_move_is_confirmed | 可證:..._forced_match_scoring_ | 間諜追蹤器偽造 delta 使不符合變符合
## test_ac09_matching_guess_counts_as_correct | 可證:..._forced_mismatch_scoring_ | 間諜追蹤器偽造 delta 使符合變不符合
## test_ac07a_lock_on_a_then_confirm_b_scores_nothing | 可證:..._scoring_unguessed_cells_is_caught_by_ac07a_detector | 間諜追蹤器對未猜測格也計分,步驟與本測試相同
## test_ac12_skip_confirm_moves_and_does_not_score | 可證:..._confirm_consuming_skip_ + ..._scoring_unguessed_cells_is_caught_by_ac12_detector | 移動與不計分各有變種
## test_ac12_skipped_cell_shows_preview_like_egm_off | 可證:..._skip_still_hidden_ | 變種被跳過格仍回報 PENDING
## test_ac06_cancel_and_reselect_reopens_guessing | 可證:..._cancel_not_discarding_ | 變種取消時不丟棄鎖定(「重選後選擇器重現」那一半【未驗證】)
## test_ac10_mismatch_text_differs_from_match_text_beyond_color | 不可證:A | 斷言對象是 static 純函式 format_guess_result,無繼承鏈可覆寫
## test_ac10_locked_mismatch_on_screen_carries_the_mismatch_text | 可證:..._mismatch_text_erased_ | 變種在顯示層把「不符合」換成「符合」(後處理式變種,模擬顯示層缺陷)
## test_ac11_every_guess_text_key_resolves_to_localized_text | 不可證:A′ | 斷言對象是 strings.csv 匯入資料,無可注入錯誤版本
## test_ac11_selector_button_texts_come_from_localization | 可證:..._hardcoded_button_text_ | 變種把按鈕文字寫死
## test_ac13_switch_is_read_once_from_game_settings_no_temporary_switch | 部分可證:..._live_egm_switch_read_ | 「戰鬥中改設定不影響本場」有證明;「追蹤器仍存在」那一半【未驗證】
## 合計:18 條有常駐證明(其中 ac02/ac04/ac08 鎖定/ac06/ac13 為部分可證,見各列【未驗證】);3 條無:ac03 project_binds(A′)、ac10 text differs(A)、ac11 keys(A′)。
## ==== /對照表 ====
##   - 讀 `res://src/ui/battle/battle_screen.gd` 不在本檔做;AC11 守衛只驗鍵存在於
##     已匯入的在地化資源(Loc.localize),不掃原始碼。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


# ---- 常駐變種(Case A:set_script 在 add_child 之前;EGM 開關是全域 GameSettings,
# ---- 不是節點屬性,set_script 不會清掉它;各證明內以斷言確認 EGM 確實開著)------

## 模擬「拿掉滑鼠點擊的選擇器守衛」:點在按鈕上一律不算蓋在選擇器上 -> 點擊漏給棋盤。
class _MutantSelectorGuardRemoved extends BattleScreen:
	func _guess_mouse_over_selector(_window_pos: Vector2) -> bool:
		return false


## 模擬「揭曉提前到鎖定前」:PENDING 一律當成 OFF -> 預覽在猜測前就顯示。
class _MutantPendingAsOff extends BattleScreen:
	func _guess_cell_state(selected: int) -> GuessCellState:
		var s: GuessCellState = super(selected)
		return GuessCellState.OFF if s == GuessCellState.PENDING else s


## 模擬「跳過後仍隱藏預覽」:被跳過的格子仍回報 PENDING。
class _MutantSkippedStillPending extends BattleScreen:
	func _guess_cell_state(selected: int) -> GuessCellState:
		var s: GuessCellState = super(selected)
		if s == GuessCellState.OFF and _guess_tracker != null and selected != -1 \
				and _cursor_active and _guess_skipped.has(_cursor_cell):
			return GuessCellState.PENDING
		return s


## 模擬「鎖定後選擇器重新變回可互動」。
class _MutantLockedBecomesPending extends BattleScreen:
	func _guess_cell_state(selected: int) -> GuessCellState:
		var s: GuessCellState = super(selected)
		return GuessCellState.PENDING if s == GuessCellState.LOCKED else s


## 模擬「EGM 關閉時仍建追蹤器與選擇器」。
class _MutantEgmOffStillBuildsTracker extends BattleScreen:
	func _ready() -> void:
		super()
		if _guess_tracker == null:
			_guess_tracker = EffectGuessTracker.new()
			_build_guess_selector()


## 模擬「EGM 關閉時預覽仍被隱藏」:tracker 為 null 也回報 PENDING。
class _MutantEgmOffStillHidesPreview extends BattleScreen:
	func _guess_cell_state(selected: int) -> GuessCellState:
		var s: GuessCellState = super(selected)
		if _guess_tracker == null and selected != -1 and _cursor_active \
				and _is_move_preview_cell(selected):
			return GuessCellState.PENDING
		return s


## 模擬「循環漏掉『負』」:正 -> 無 -> 正。
class _MutantCycleSkipsNegative extends BattleScreen:
	func _handle_guess_cycle() -> void:
		if _guess_cell_state(_controller.selected_unit()) != GuessCellState.PENDING:
			return
		_guess_choice = EffectGuessTracker.EffectDirection.NEUTRAL \
			if _guess_choice == EffectGuessTracker.EffectDirection.POSITIVE \
			else EffectGuessTracker.EffectDirection.POSITIVE
		_refresh_view()


## 模擬「循環鍵拿掉 EGM 守衛」:不管狀態一律改選項。
class _MutantCycleIgnoresGuard extends BattleScreen:
	func _handle_guess_cycle() -> void:
		_guess_choice = EffectGuessTracker.EffectDirection.POSITIVE


## 模擬「確認鍵不鎖定」。
class _MutantConfirmNeverLocks extends BattleScreen:
	func _handle_guess_confirm() -> bool:
		return false


## 模擬「確認鍵在跳過情境被選擇器吞掉(不再往下走移動)」。
class _MutantConfirmConsumesSkip extends BattleScreen:
	func _handle_guess_confirm() -> bool:
		var was_pending: bool = _guess_cell_state(_controller.selected_unit()) == GuessCellState.PENDING
		var consumed: bool = super()
		return consumed or was_pending


## 模擬「按鈕一律鎖定『正』,不管按哪顆」。
class _MutantButtonIgnoresDirection extends BattleScreen:
	func _on_guess_button_pressed(_direction: int) -> void:
		super(EffectGuessTracker.EffectDirection.POSITIVE)



## 模擬「取消選取時不丟棄猜測」(抑制旗標永遠為真)。
class _MutantCancelNeverDiscards extends BattleScreen:
	func _ready() -> void:
		super()
		_guess_suppress_cancel = true


## 模擬「不符合的結果文字被改得跟符合一樣」(顯示層後處理)。
class _MutantMismatchTextLooksLikeMatch extends BattleScreen:
	func _refresh_view() -> void:
		super()
		_info_label.text = _info_label.text.replace(
			Loc.localize(TEXT_GUESS_MISMATCH), Loc.localize(TEXT_GUESS_MATCH))


## 模擬「按鈕文字寫死、不走在地化」。
class _MutantButtonTextHardcoded extends BattleScreen:
	func _update_guess_selector_ui(pending: bool) -> void:
		super(pending)
		for btn: Button in _guess_buttons.values():
			btn.text = "hardcoded"


## 模擬「EGM 開關改成即時讀設定,而非開戰時讀一次」。
class _MutantEgmSwitchLiveRead extends BattleScreen:
	func is_egm_enabled_for_this_battle() -> bool:
		return GameSettings.is_egm_enabled()


## 把追蹤器換成可注入計分缺陷的間諜(於 _ready 之後替換)。
class _MutantInstallTracker extends BattleScreen:
	var spy_script: GDScript = null
	func _ready() -> void:
		super()
		if _guess_tracker != null and spy_script != null:
			_guess_tracker = spy_script.new()


## 間諜:計分時偽造 delta,使任何已鎖定猜測都「符合」。
class _TrackerForcesMatch extends EffectGuessTracker:
	func confirm_move(cell: Vector2i, delta: int) -> void:
		var g: int = get_locked_guess(cell) if has_locked_guess(cell) else NO_GUESS
		var fake: int = 0
		if g == EffectDirection.POSITIVE:
			fake = 1
		elif g == EffectDirection.NEGATIVE:
			fake = -1
		super(cell, fake)


## 間諜:計分時偽造 delta,使任何已鎖定猜測都「不符合」。
class _TrackerForcesMismatch extends EffectGuessTracker:
	func confirm_move(cell: Vector2i, delta: int) -> void:
		var g: int = get_locked_guess(cell) if has_locked_guess(cell) else NO_GUESS
		super(cell, -1 if g == EffectDirection.POSITIVE else 1)


## 間諜:未猜測的格子在確認移動時也被計分(自動補一個猜測)。
class _TrackerScoresUnguessed extends EffectGuessTracker:
	func confirm_move(cell: Vector2i, delta: int) -> void:
		if not has_locked_guess(cell):
			record_guess(cell, EffectDirection.NEUTRAL)
		super(cell, delta)


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	GameSettings.reset_for_test()


func after_test() -> void:
	GameSettings.reset_for_test()
	_host_snap.restore()
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


# ---- helpers ----------------------------------------------------------------

func _instance(egm_on: bool) -> BattleScreen:
	GameSettings.set_egm_enabled(egm_on)
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _event(action: StringName, gamepad: bool = false) -> InputEvent:
	for event: InputEvent in InputMap.action_get_events(action):
		if gamepad and event is InputEventJoypadButton:
			var jb: InputEventJoypadButton = (event as InputEventJoypadButton).duplicate()
			jb.pressed = true
			return jb
		if not gamepad and event is InputEventKey:
			var k: InputEventKey = (event as InputEventKey).duplicate()
			k.pressed = true
			return k
	return null


## 選一名我方單位並回傳其前兩個候選格(各自帶 delta)。用真實查詢,不重新實作規則。
## 會留下該單位為「已選取」狀態。
func _select_unit_with_two_candidates(instance: BattleScreen) -> Dictionary:
	for unit: Unit in instance._state.units_of(Unit.Faction.PLAYER):
		if not instance._controller.select_unit(unit.id):
			continue
		var cells: Array[Vector2i] = instance._controller.move_targets().cells
		var usable: Array[Vector2i] = []
		for cell: Vector2i in cells:
			if cell != instance._state.position_of(unit.id):
				usable.append(cell)
		if usable.size() >= 2:
			return {
				"unit": unit, "a": usable[0], "b": usable[1],
				"delta_a": instance._guess_delta_for_cell(unit.id, usable[0]),
			}
		instance._controller.deselect()
	return {}


func _park(instance: BattleScreen, cell: Vector2i) -> void:
	instance._cursor_cell = cell
	instance._cursor_active = true
	instance._refresh_view()


func _wrong_guess_for(delta: int) -> int:
	var actual: int = EffectGuessTracker.classify_delta(delta)
	return EffectGuessTracker.EffectDirection.NEGATIVE \
		if actual != EffectGuessTracker.EffectDirection.NEGATIVE \
		else EffectGuessTracker.EffectDirection.POSITIVE


func _preview_text(instance: BattleScreen, unit_id: int, cell: Vector2i) -> String:
	var positions: Dictionary[int, Vector2i] = instance._phi.positions()
	var links: Array[AffinityLink] = instance._phi.links()
	var hypo: Dictionary[int, Vector2i] = instance._phi.positions_with(unit_id, cell)
	return BattleScreen.format_affinity_preview(
		AffinityRules.bonus_for(unit_id, positions, links),
		AffinityRules.bonus_for_at(unit_id, cell, hypo, links)
	)


# ---- AC1 迴歸安全 ------------------------------------------------------------

func test_ac01_egm_off_preview_shown_immediately_no_selector() -> void:
	var instance: BattleScreen = _instance(false)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	assert_bool(setup.is_empty()).append_failure_message("PRECONDITION: 找不到有 2 個候選格的我方單位").is_false()
	var unit: Unit = setup["unit"]

	_park(instance, setup["a"])

	assert_object(instance.diagnostic_guess_tracker()).append_failure_message(
		"AC1:EGM 關閉時不應建立追蹤器(所有 EGM 路徑短路)").is_null()
	assert_bool(instance.diagnostic_guess_selector_visible()).is_false()
	assert_str(instance._info_label.text).append_failure_message(
		"AC1:EGM 關閉時預覽文字須立即顯示,且與改動前相同(format_affinity_preview 的輸出)"
	).is_equal(_preview_text(instance, unit.id, setup["a"]))


func test_ac01_egm_off_guess_cycle_key_does_nothing() -> void:
	var instance: BattleScreen = _instance(false)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	_park(instance, setup["a"])
	var before: String = instance._info_label.text

	instance._input(_event(&"battle_guess_cycle"))

	assert_str(instance._info_label.text).is_equal(before)
	assert_int(instance.diagnostic_guess_choice()).is_equal(EffectGuessTracker.NO_GUESS)


# ---- AC2 選擇器出現 ----------------------------------------------------------

func test_ac02_egm_on_unguessed_candidate_hides_preview_and_shows_selector() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	var unit: Unit = setup["unit"]

	_park(instance, setup["a"])

	assert_str(instance._info_label.text).append_failure_message(
		"AC2:尚未猜測時好感度預覽文字應被隱藏").is_equal("")
	assert_bool(instance.diagnostic_guess_selector_visible()).append_failure_message(
		"AC2:選擇器應顯示").is_true()
	assert_int(instance._guess_buttons.size()).is_equal(3)
	# 棋子自己腳下:delta 恆為 0,沒有可猜的東西 -> 不出現選擇器,預覽照常。
	_park(instance, instance._state.position_of(unit.id))
	assert_bool(instance.diagnostic_guess_selector_visible()).is_false()


# ---- AC3 輸入平權 ------------------------------------------------------------

func test_ac03_keyboard_cycle_then_confirm_completes_a_guess() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	_park(instance, setup["a"])

	instance._input(_event(&"battle_guess_cycle"))
	assert_int(instance.diagnostic_guess_choice()).is_equal(EffectGuessTracker.EffectDirection.POSITIVE)
	instance._input(_event(&"battle_confirm"))

	assert_bool(instance.diagnostic_guess_tracker().has_locked_guess(setup["a"])).is_true()
	assert_int(instance.diagnostic_guess_tracker().get_locked_guess(setup["a"])).is_equal(
		EffectGuessTracker.EffectDirection.POSITIVE)


func test_ac03_gamepad_cycle_then_confirm_completes_a_guess() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	_park(instance, setup["a"])

	instance._input(_event(&"battle_guess_cycle", true))
	instance._input(_event(&"battle_guess_cycle", true))
	assert_int(instance.diagnostic_guess_choice()).is_equal(EffectGuessTracker.EffectDirection.NEGATIVE)
	instance._input(_event(&"battle_confirm", true))

	assert_int(instance.diagnostic_guess_tracker().get_locked_guess(setup["a"])).is_equal(
		EffectGuessTracker.EffectDirection.NEGATIVE)


func test_ac03_mouse_button_press_completes_a_guess() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	_park(instance, setup["a"])

	instance._guess_buttons[EffectGuessTracker.EffectDirection.NEUTRAL].pressed.emit()

	assert_int(instance.diagnostic_guess_tracker().get_locked_guess(setup["a"])).is_equal(
		EffectGuessTracker.EffectDirection.NEUTRAL)


func test_ac03_mouse_click_on_selector_is_not_also_a_board_click() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	_park(instance, setup["a"])
	var probe: Dictionary = _overlap_selector_with_cell_b(instance, setup)
	var unit_id: int = (setup["unit"] as Unit).id
	var pos_before: Vector2i = instance._state.position_of(unit_id)
	var rejected_before: int = instance._diagnostic_click_tile_rejected_count
	var action_before: StringName = instance._diagnostic_last_click_tile_action

	instance._input(probe["click"])

	assert_bool(instance._guess_mouse_over_selector(probe["click"].position)).is_true()
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"點在選擇器上不得被當成棋盤點擊(否則會取消選取)").is_equal(unit_id)
	assert_object(instance._state.position_of(unit_id)).append_failure_message(
		"點在選擇器上不得讓單位移動到下方的棋盤格").is_equal(pos_before)
	assert_int(instance._diagnostic_click_tile_rejected_count).is_equal(rejected_before)
	assert_str(String(instance._diagnostic_last_click_tile_action)).is_equal(String(action_before))


## 把 POSITIVE 按鈕蓋到候選格 b 的中心,回傳 {click, cell_b}。前提斷言在此:
## 點擊位置換算出的格子必須在棋盤內且等於 b,否則點擊會在 _handle_mouse_button 的
## is_in_bounds 檢查被擋掉,守衛從未被觸發 —— 測試空轉。座標換算一律走
## BoardCoords.grid_to_window / window_to_grid + WorldLayout 的真實變換,不自算格寬。
func _overlap_selector_with_cell_b(instance: BattleScreen, setup: Dictionary) -> Dictionary:
	var win: Vector2i = instance.get_window().size
	var center: Vector2 = BoardCoords.grid_to_window(
		setup["b"], WorldLayout.canvas_to_window_transform(win), Vector2.ZERO)
	var btn: Button = instance._guess_buttons[EffectGuessTracker.EffectDirection.POSITIVE]
	btn.global_position = center - btn.size * 0.5
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = btn.get_global_rect().get_center()
	var cell: Vector2i = instance._window_pos_to_cell(click.position)
	assert_bool(BoardCoords.is_in_bounds(cell)).append_failure_message(
		"前提失敗(測試空轉):點擊位置 %s 換算出的格子 %s 在棋盤外,守衛不會被觸發" % [click.position, cell]).is_true()
	assert_object(cell).append_failure_message(
		"前提失敗(測試空轉):點擊格 %s 應等於候選格 b %s" % [cell, setup["b"]]).is_equal(setup["b"])
	return {"click": click, "cell_b": setup["b"]}


func test_ac03_project_binds_guess_cycle_to_x_and_joy_button_y() -> void:
	assert_bool(InputMap.has_action(&"battle_guess_cycle")).is_true()
	var key_ok: bool = false
	var pad_ok: bool = false
	for event: InputEvent in InputMap.action_get_events(&"battle_guess_cycle"):
		if event is InputEventKey and (event as InputEventKey).keycode == KEY_X:
			key_ok = true
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y:
			pad_ok = true
	assert_bool(key_ok).is_true()
	assert_bool(pad_ok).is_true()


# ---- AC4 揭曉與鎖定同時發生 / AC8 不可灌水 -------------------------------------

func test_ac04_real_values_absent_before_lock_present_right_after() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	var unit: Unit = setup["unit"]
	var preview: String = _preview_text(instance, unit.id, setup["a"])
	_park(instance, setup["a"])
	# 循環到某選項但尚未確認:仍不得出現真實值。
	instance._input(_event(&"battle_guess_cycle"))
	assert_str(instance._info_label.text).append_failure_message(
		"AC4:標記完成之前真實數值不得出現").is_equal("")

	instance._input(_event(&"battle_confirm"))

	assert_str(instance._info_label.text).append_failure_message(
		"AC4:鎖定的同一瞬間預覽文字顯示真實值").contains(preview)
	assert_bool(instance.diagnostic_guess_selector_visible()).append_failure_message(
		"AC4:鎖定後選擇器轉為唯讀(不再顯示可互動按鈕)").is_false()


func test_ac08_locked_cell_stays_locked_after_leaving_and_returning() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	var wrong: int = _wrong_guess_for(setup["delta_a"])
	_park(instance, setup["a"])
	instance._guess_choice = wrong
	instance._input(_event(&"battle_confirm"))

	_park(instance, setup["b"])   # 移出
	_park(instance, setup["a"])   # 移回

	assert_bool(instance.diagnostic_guess_selector_visible()).append_failure_message(
		"AC6/AC8:移出移回不得重新出現可互動選擇器").is_false()
	assert_str(instance._info_label.text).is_not_equal("")
	instance._input(_event(&"battle_guess_cycle"))
	assert_int(instance.diagnostic_guess_tracker().get_locked_guess(setup["a"])).append_failure_message(
		"AC8:鎖定後無法改猜").is_equal(wrong)
	instance.diagnostic_guess_tracker().record_guess(
		setup["a"], EffectGuessTracker.classify_delta(setup["delta_a"]))
	assert_int(instance.diagnostic_guess_tracker().get_locked_guess(setup["a"])).is_equal(wrong)


func test_ac08_mismatch_stays_mismatch_when_move_is_confirmed() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	var wrong: int = _wrong_guess_for(setup["delta_a"])
	_park(instance, setup["a"])
	instance._guess_choice = wrong
	instance._input(_event(&"battle_confirm"))   # 鎖定
	var tracker: EffectGuessTracker = instance.diagnostic_guess_tracker()

	instance._input(_event(&"battle_confirm"))   # 第二次確認 = 移動

	assert_vector(instance._state.position_of((setup["unit"] as Unit).id)).is_equal(setup["a"])
	assert_int(tracker.get_scored_total()).is_equal(1)
	assert_int(tracker.get_scored_correct()).append_failure_message(
		"AC8:看到答案後也不能變成符合").is_equal(0)


func test_ac09_matching_guess_counts_as_correct() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	_park(instance, setup["a"])
	instance._guess_choice = EffectGuessTracker.classify_delta(setup["delta_a"])
	instance._input(_event(&"battle_confirm"))
	instance._input(_event(&"battle_confirm"))

	var tracker: EffectGuessTracker = instance.diagnostic_guess_tracker()
	assert_int(tracker.get_scored_total()).is_equal(1)
	assert_int(tracker.get_scored_correct()).is_equal(1)


# ---- AC7(a) 鎖定後確認別格不計分 ----------------------------------------------

func test_ac07a_lock_on_a_then_confirm_b_scores_nothing() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	_park(instance, setup["a"])
	instance._guess_choice = EffectGuessTracker.EffectDirection.POSITIVE
	instance._input(_event(&"battle_confirm"))   # 在 A 鎖定
	_park(instance, setup["b"])

	instance._input(_event(&"battle_confirm"))   # B 尚未猜測、直接確認 = 跳過並移動

	assert_int(instance.diagnostic_guess_tracker().get_scored_total()).is_equal(0)


# ---- AC12 跳過 ---------------------------------------------------------------

func test_ac12_skip_confirm_moves_and_does_not_score() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	_park(instance, setup["a"])

	instance._input(_event(&"battle_confirm"))   # 選擇器仍為初始狀態

	assert_vector(instance._state.position_of((setup["unit"] as Unit).id)).append_failure_message(
		"跳過:確認照常執行移動").is_equal(setup["a"])
	assert_int(instance.diagnostic_guess_tracker().get_scored_total()).is_equal(0)


func test_ac12_skipped_cell_shows_preview_like_egm_off() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	var unit: Unit = setup["unit"]
	_park(instance, setup["a"])
	assert_str(instance._info_label.text).is_equal("")

	instance._guess_skipped[setup["a"]] = true   # 等同跳過標記(移動沒發生時的殘留)
	instance._refresh_view()

	assert_str(instance._info_label.text).append_failure_message(
		"AC12:跳過後預覽比照 EGM 關閉時立即顯示,不得繼續隱藏"
	).is_equal(_preview_text(instance, unit.id, setup["a"]))
	assert_bool(instance.diagnostic_guess_selector_visible()).is_false()


func test_ac06_cancel_and_reselect_reopens_guessing() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	var unit: Unit = setup["unit"]
	_park(instance, setup["a"])
	instance._guess_choice = EffectGuessTracker.EffectDirection.POSITIVE
	instance._input(_event(&"battle_confirm"))
	assert_bool(instance.diagnostic_guess_tracker().has_locked_guess(setup["a"])).is_true()

	instance._controller.deselect()
	assert_bool(instance.diagnostic_guess_tracker().has_locked_guess(setup["a"])).append_failure_message(
		"取消選取應丟棄鎖定的猜測").is_false()
	assert_bool(instance._controller.select_unit(unit.id)).is_true()
	_park(instance, setup["a"])

	assert_bool(instance.diagnostic_guess_selector_visible()).append_failure_message(
		"重新選取同一棋子 = 全新選取過程,選擇器重新出現").is_true()


# ---- AC10 非純色區分 ---------------------------------------------------------

func test_ac10_mismatch_text_differs_from_match_text_beyond_color() -> void:
	var match_text: String = BattleScreen.format_guess_result("P", EffectGuessTracker.EffectDirection.POSITIVE, 3)
	var mismatch_text: String = BattleScreen.format_guess_result("P", EffectGuessTracker.EffectDirection.NEGATIVE, 3)

	assert_str(match_text).is_not_equal(mismatch_text)
	assert_str(match_text).contains(Loc.localize(BattleScreen.TEXT_GUESS_MATCH))
	assert_str(mismatch_text).contains(Loc.localize(BattleScreen.TEXT_GUESS_MISMATCH))
	assert_str(mismatch_text).append_failure_message(
		"不符合須帶文字(「不符合」)而非只靠顏色").contains("不符合")
	assert_str(match_text).not_contains("不符合")


func test_ac10_locked_mismatch_on_screen_carries_the_mismatch_text() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	_park(instance, setup["a"])
	instance._guess_choice = _wrong_guess_for(setup["delta_a"])
	instance._input(_event(&"battle_confirm"))

	assert_str(instance._info_label.text).contains(Loc.localize(BattleScreen.TEXT_GUESS_MISMATCH))


# ---- AC11 在地化 -------------------------------------------------------------

func test_ac11_every_guess_text_key_resolves_to_localized_text() -> void:
	var keys: Array[StringName] = [
		BattleScreen.TEXT_GUESS_OPTION_POSITIVE, BattleScreen.TEXT_GUESS_OPTION_NEGATIVE,
		BattleScreen.TEXT_GUESS_OPTION_NEUTRAL, BattleScreen.TEXT_GUESS_OPTION_MARKED_FORMAT,
		BattleScreen.TEXT_GUESS_DIRECTION_POSITIVE, BattleScreen.TEXT_GUESS_DIRECTION_NEGATIVE,
		BattleScreen.TEXT_GUESS_DIRECTION_NEUTRAL, BattleScreen.TEXT_GUESS_MATCH,
		BattleScreen.TEXT_GUESS_MISMATCH, BattleScreen.TEXT_GUESS_RESULT_FORMAT,
	]
	for key: StringName in keys:
		var text: String = Loc.localize(key)
		assert_str(text).append_failure_message("鍵 %s 沒有在地化文字" % key).is_not_empty()
		assert_str(text).append_failure_message(
			"鍵 %s 回傳的是鍵名本身(strings.csv 缺此列或未重新匯入)" % key).is_not_equal(String(key))


func test_ac11_selector_button_texts_come_from_localization() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	_park(instance, setup["a"])

	var pos_btn: Button = instance._guess_buttons[EffectGuessTracker.EffectDirection.POSITIVE]
	assert_str(pos_btn.text).is_equal(Loc.localize(BattleScreen.TEXT_GUESS_OPTION_POSITIVE))


# ---- AC13(由既有實作滿足)與「無暫代開關」-----------------------------------

func test_ac13_switch_is_read_once_from_game_settings_no_temporary_switch() -> void:
	var instance: BattleScreen = _instance(true)
	assert_bool(instance.is_egm_enabled_for_this_battle()).is_true()
	assert_object(instance.diagnostic_guess_tracker()).is_not_null()
	GameSettings.set_egm_enabled(false)   # 戰鬥中改設定:不影響進行中這場
	assert_object(instance.diagnostic_guess_tracker()).is_not_null()
	assert_bool(instance.is_egm_enabled_for_this_battle()).is_true()


# ---- 敏感度證明(常駐變種;每條皆為「會通過」的測試,斷言偵測器抓到植入缺陷)-------

func _instance_mutant(mutant_script: GDScript, egm_on: bool) -> BattleScreen:
	GameSettings.set_egm_enabled(egm_on)
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.set_script(mutant_script)   # 必須在 add_child 之前、也在設任何屬性之前
	add_child(instance)
	return instance


func _ready_setup(instance: BattleScreen) -> Dictionary:
	var setup: Dictionary = _select_unit_with_two_candidates(instance)
	assert_bool(setup.is_empty()).append_failure_message("PRECONDITION: 找不到候選格").is_false()
	return setup


func test_sensitivity_proof_pending_revealed_early_is_caught_by_ac02_ac04_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantPendingAsOff, true)
	assert_bool(instance.is_egm_enabled_for_this_battle()).append_failure_message("PRECONDITION: EGM 須為開").is_true()
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	# AC2/AC4 偵測器斷言「鎖定前 info_label == ''、選擇器顯示」;變種下兩者都被打破。
	assert_str(instance._info_label.text).is_equal(_preview_text(instance, (setup["unit"] as Unit).id, setup["a"]))
	assert_bool(instance.diagnostic_guess_selector_visible()).is_false()


func test_sensitivity_proof_skip_still_hidden_is_caught_by_ac12_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantSkippedStillPending, true)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	instance._guess_skipped[setup["a"]] = true
	instance._refresh_view()
	# AC12 偵測器斷言「跳過後預覽顯示、選擇器消失」;變種下預覽仍空、選擇器仍在。
	assert_str(instance._info_label.text).is_equal("")
	assert_bool(instance.diagnostic_guess_selector_visible()).is_true()


func test_sensitivity_proof_locked_cell_reopening_is_caught_by_ac08_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantLockedBecomesPending, true)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	instance._guess_choice = EffectGuessTracker.EffectDirection.POSITIVE
	instance._input(_event(&"battle_confirm"))   # 鎖定
	_park(instance, setup["b"])
	_park(instance, setup["a"])
	# AC8 偵測器斷言「移出移回選擇器不可再出現」;變種下它出現了。
	assert_bool(instance.diagnostic_guess_selector_visible()).is_true()


func test_sensitivity_proof_egm_off_building_tracker_is_caught_by_ac01_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantEgmOffStillBuildsTracker, false)
	# AC1 偵測器斷言「EGM 關閉時追蹤器為 null」;變種下不為 null。
	assert_object(instance.diagnostic_guess_tracker()).is_not_null()


func test_sensitivity_proof_egm_off_hiding_preview_is_caught_by_ac01_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantEgmOffStillHidesPreview, false)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	# AC1 偵測器斷言「EGM 關閉時預覽立即顯示」;變種下預覽為空。
	assert_str(instance._info_label.text).is_equal("")
	assert_str(_preview_text(instance, (setup["unit"] as Unit).id, setup["a"])).is_not_equal("")


func test_sensitivity_proof_cycle_skipping_negative_is_caught_by_ac03_gamepad_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantCycleSkipsNegative, true)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	instance._input(_event(&"battle_guess_cycle", true))
	instance._input(_event(&"battle_guess_cycle", true))
	# 偵測器斷言兩下之後是 NEGATIVE;變種下是 NEUTRAL。
	assert_int(instance.diagnostic_guess_choice()).is_equal(EffectGuessTracker.EffectDirection.NEUTRAL)


func test_sensitivity_proof_cycle_key_without_guard_is_caught_by_ac01_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantCycleIgnoresGuard, false)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	instance._input(_event(&"battle_guess_cycle"))
	# AC1 偵測器斷言 EGM 關閉時選項維持 NO_GUESS;變種下被改動。
	assert_int(instance.diagnostic_guess_choice()).is_equal(EffectGuessTracker.EffectDirection.POSITIVE)


func test_sensitivity_proof_confirm_never_locking_is_caught_by_ac03_keyboard_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantConfirmNeverLocks, true)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	instance._input(_event(&"battle_guess_cycle"))
	instance._input(_event(&"battle_confirm"))
	# 偵測器斷言鎖定成功;變種下沒有鎖定(確認直接當成移動)。
	assert_bool(instance.diagnostic_guess_tracker().has_locked_guess(setup["a"])).is_false()


func test_sensitivity_proof_confirm_consuming_skip_is_caught_by_ac12_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantConfirmConsumesSkip, true)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	instance._input(_event(&"battle_confirm"))
	# 偵測器斷言跳過時單位移到 a;變種下沒有移動。
	assert_vector(instance._state.position_of((setup["unit"] as Unit).id)).is_not_equal(setup["a"])


func test_sensitivity_proof_button_ignoring_direction_is_caught_by_ac03_mouse_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantButtonIgnoresDirection, true)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	instance._guess_buttons[EffectGuessTracker.EffectDirection.NEUTRAL].pressed.emit()
	# 偵測器斷言鎖定的是 NEUTRAL;變種下鎖成 POSITIVE。
	assert_int(instance.diagnostic_guess_tracker().get_locked_guess(setup["a"])).is_equal(
		EffectGuessTracker.EffectDirection.POSITIVE)


func test_sensitivity_proof_selector_click_leaking_to_board_is_caught_by_ac03_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantSelectorGuardRemoved, true)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	var probe: Dictionary = _overlap_selector_with_cell_b(instance, setup)
	var action_before: StringName = instance._diagnostic_last_click_tile_action

	instance._input(probe["click"])

	# AC3 偵測器斷言單位未移動且 last action 不變;守衛被拿掉後點擊漏給棋盤,
	# 單位移到下方的 b,last action 變為 moved。
	assert_vector(instance._state.position_of((setup["unit"] as Unit).id)).is_equal(setup["b"])
	assert_str(String(instance._diagnostic_last_click_tile_action)).is_not_equal(String(action_before))


func test_sensitivity_proof_cancel_not_discarding_is_caught_by_ac06_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantCancelNeverDiscards, true)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	instance._guess_choice = EffectGuessTracker.EffectDirection.POSITIVE
	instance._input(_event(&"battle_confirm"))
	instance._controller.deselect()
	# AC6 偵測器斷言取消後鎖定被丟棄;變種下仍鎖著。
	assert_bool(instance.diagnostic_guess_tracker().has_locked_guess(setup["a"])).is_true()


func test_sensitivity_proof_mismatch_text_erased_is_caught_by_ac10_on_screen_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantMismatchTextLooksLikeMatch, true)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	instance._guess_choice = _wrong_guess_for(setup["delta_a"])
	instance._input(_event(&"battle_confirm"))
	# 偵測器斷言畫面含「不符合」;變種下沒有。
	assert_str(instance._info_label.text).not_contains(Loc.localize(BattleScreen.TEXT_GUESS_MISMATCH))


func test_sensitivity_proof_hardcoded_button_text_is_caught_by_ac11_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantButtonTextHardcoded, true)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	var pos_btn: Button = instance._guess_buttons[EffectGuessTracker.EffectDirection.POSITIVE]
	# 偵測器斷言按鈕文字等於在地化文字;變種下不等。
	assert_str(pos_btn.text).is_not_equal(Loc.localize(BattleScreen.TEXT_GUESS_OPTION_POSITIVE))


func test_sensitivity_proof_live_egm_switch_read_is_caught_by_ac13_detector() -> void:
	var instance: BattleScreen = _instance_mutant(_MutantEgmSwitchLiveRead, true)
	assert_bool(instance.is_egm_enabled_for_this_battle()).append_failure_message("PRECONDITION: EGM 須為開").is_true()
	GameSettings.set_egm_enabled(false)
	# AC13 偵測器斷言戰鬥中改設定不影響本場;變種下跟著變。
	assert_bool(instance.is_egm_enabled_for_this_battle()).is_false()


func _instance_with_spy_tracker(spy: GDScript) -> BattleScreen:
	GameSettings.set_egm_enabled(true)
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.set_script(_MutantInstallTracker)
	instance.spy_script = spy   # set_script 之後才設(順序規則見上)
	add_child(instance)
	return instance


func test_sensitivity_proof_forced_match_scoring_is_caught_by_ac08_mismatch_detector() -> void:
	var instance: BattleScreen = _instance_with_spy_tracker(_TrackerForcesMatch)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	instance._guess_choice = _wrong_guess_for(setup["delta_a"])
	instance._input(_event(&"battle_confirm"))
	instance._input(_event(&"battle_confirm"))
	# 偵測器斷言「不符合維持不符合」(correct == 0);變種下 correct == 1。
	assert_int(instance.diagnostic_guess_tracker().get_scored_total()).is_equal(1)
	assert_int(instance.diagnostic_guess_tracker().get_scored_correct()).is_equal(1)


func test_sensitivity_proof_forced_mismatch_scoring_is_caught_by_ac09_detector() -> void:
	var instance: BattleScreen = _instance_with_spy_tracker(_TrackerForcesMismatch)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	instance._guess_choice = EffectGuessTracker.classify_delta(setup["delta_a"])
	instance._input(_event(&"battle_confirm"))
	instance._input(_event(&"battle_confirm"))
	# 偵測器斷言符合的猜測計為正確(correct == 1);變種下 correct == 0。
	assert_int(instance.diagnostic_guess_tracker().get_scored_total()).is_equal(1)
	assert_int(instance.diagnostic_guess_tracker().get_scored_correct()).is_equal(0)


func test_sensitivity_proof_scoring_unguessed_cells_is_caught_by_ac12_detector() -> void:
	var instance: BattleScreen = _instance_with_spy_tracker(_TrackerScoresUnguessed)
	var setup: Dictionary = _ready_setup(instance)
	# ac12:跳過直接確認 -> 偵測器斷言 total == 0;變種下 1。
	_park(instance, setup["a"])
	instance._input(_event(&"battle_confirm"))
	assert_int(instance.diagnostic_guess_tracker().get_scored_total()).is_equal(1)


func test_sensitivity_proof_scoring_unguessed_cells_is_caught_by_ac07a_detector() -> void:
	var instance: BattleScreen = _instance_with_spy_tracker(_TrackerScoresUnguessed)
	var setup: Dictionary = _ready_setup(instance)
	_park(instance, setup["a"])
	instance._guess_choice = EffectGuessTracker.EffectDirection.POSITIVE
	instance._input(_event(&"battle_confirm"))   # 在 A 鎖定
	_park(instance, setup["b"])
	instance._input(_event(&"battle_confirm"))   # B 未猜測、跳過並移動
	# 偵測器斷言 total == 0;變種下 B 被計分。
	assert_int(instance.diagnostic_guess_tracker().get_scored_total()).is_equal(1)
