extends GdUnitTestSuite
## story-053:滑鼠「結束角色行動」按鈕。載入真實 BattleScreen.tscn(預設真實資料,未合成)。
## 檔案存取:無。禁用態 = 字灰 + 底色拿掉(空心)+ 外框 1px + disabled(管理者 2026-11-16 裁決,不加叉叉)。
## 未涵蓋:待棄牌(has_pending_discard)原因句 —— 本檔無法低成本造出該狀態,見交付回報。

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _END_TEXT: String = "結束角色行動"

var _host_snap: CursorHostSnapshot = null


class _MutantSeparateEndLogic extends BattleScreen:
	func _perform_end_unit_turn() -> void:
		# 另寫一份(錯的)結束邏輯:只取消選取,不結束單位。
		_controller.deselect()


class _MutantAlwaysAvailable extends BattleScreen:
	func _end_action_available() -> bool:
		return true


class _MutantSolidDisabledStyle extends BattleScreen:
	func _build_hud_action_buttons() -> void:
		super()
		var solid: StyleBoxFlat = _make_hud_button_style(&"normal")
		_end_action_button.add_theme_stylebox_override(&"disabled", solid)


class _MutantGrayFontMissing extends BattleScreen:
	func _build_hud_action_buttons() -> void:
		super()
		_end_action_button.add_theme_color_override(&"font_disabled_color", _end_action_button.get_theme_color(&"font_color"))


class _MutantKeepsBarOnEnd extends BattleScreen:
	func _on_battle_ended(outcome: BattleState.Outcome) -> void:
		super(outcome)
		_controls_hint_bg.visible = true


class _MutantHidesBarAtStart extends BattleScreen:
	func _ready() -> void:
		super()
		_controls_hint_bg.visible = false


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
	return instance


func _select_first(instance: BattleScreen) -> int:
	var ids: Array[int] = instance._controller.selectable_units()
	assert_int(ids.size()).append_failure_message("PRECONDITION: 有可選單位").is_greater(0)
	assert_bool(instance._controller.select_unit(ids[0])).append_failure_message("PRECONDITION: 選取成功").is_true()
	instance._refresh_end_action_button()
	return ids[0]


func _action_event(action: StringName) -> InputEventAction:
	var e: InputEventAction = InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _back_event() -> InputEventJoypadButton:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_BACK
	e.pressed = true
	return e


func _end_via(instance: BattleScreen, path: String) -> void:
	match path:
		"mouse":
			instance._end_action_button.pressed.emit()
		"key_q":
			instance._input(_action_event(&"battle_end_unit_turn"))
		"pad_back":
			instance._input(_back_event())


# ---- AC1 / AC3:三路徑逐項相同 ------------------------------------------------------

func _assert_path_ends_unit(path: String) -> void:
	var instance: BattleScreen = _make()
	var id: int = _select_first(instance)
	assert_bool(instance._controller.unit_action_state(id) != TurnOrder.ActionState.DONE).append_failure_message(
		"PRECONDITION: 結束前單位未 DONE").is_true()
	_end_via(instance, path)
	assert_int(instance._controller.selected_unit()).append_failure_message("%s:選取應清除" % path).is_equal(-1)
	assert_int(instance._controller.unit_action_state(id)).append_failure_message(
		"%s:單位應 DONE" % path).is_equal(TurnOrder.ActionState.DONE)
	assert_int(instance.diagnostic_end_unit_turn_rejected_count()).is_equal(0)


func test_mouse_button_ends_selected_unit() -> void:
	_assert_path_ends_unit("mouse")


func test_key_q_ends_selected_unit() -> void:
	_assert_path_ends_unit("key_q")


func test_gamepad_back_ends_selected_unit() -> void:
	_assert_path_ends_unit("pad_back")


func test_sensitivity_proof_separate_end_logic_mutant_goes_red_on_mouse_path() -> void:
	var instance: BattleScreen = _make(_MutantSeparateEndLogic)
	var id: int = _select_first(instance)
	instance._end_action_button.pressed.emit()
	assert_bool(instance._controller.unit_action_state(id) == TurnOrder.ActionState.DONE).append_failure_message(
		"mutant 另寫邏輯 → 單位不會 DONE(此斷言為假代表偵測得到)").is_false()


func test_q_with_no_selection_rejects_safely_and_button_is_disabled() -> void:
	var instance: BattleScreen = _make()
	assert_int(instance._controller.selected_unit()).is_equal(-1)
	instance._input(_action_event(&"battle_end_unit_turn"))
	assert_int(instance.diagnostic_end_unit_turn_rejected_count()).is_equal(1)
	instance._refresh_end_action_button()
	assert_bool(instance._end_action_button.disabled).is_true()


func test_button_is_focus_none() -> void:
	var instance: BattleScreen = _make()
	assert_int(instance._end_action_button.focus_mode).is_equal(Control.FOCUS_NONE)


# ---- AC2:可用狀態表 -----------------------------------------------------------------

func _assert_presentation(instance: BattleScreen, expect_disabled: bool) -> void:
	var b: Button = instance._end_action_button
	assert_bool(b.disabled).is_equal(expect_disabled)
	assert_str(b.text).append_failure_message("文字永遠是同一句,不加前綴").is_equal(_END_TEXT)
	var style: StyleBoxFlat = b.get_theme_stylebox(&"disabled") as StyleBoxFlat
	var normal: StyleBoxFlat = b.get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_float(style.bg_color.a).append_failure_message("禁用底色應拿掉(空心)").is_equal(0.0)
	assert_int(style.border_width_left).is_equal(BattleScreen.HUD_BUTTON_DISABLED_BORDER_WIDTH)
	assert_bool(b.get_theme_color(&"font_disabled_color") != b.get_theme_color(&"font_color")).is_true()
	assert_int(normal.border_width_left).is_equal(BattleScreen.HUD_BUTTON_BORDER_WIDTH)
	assert_float(normal.bg_color.a).is_greater(0.0)


func test_state_no_selection_is_disabled_with_reason() -> void:
	var instance: BattleScreen = _make()
	instance._refresh_end_action_button()
	_assert_presentation(instance, true)
	assert_str(instance._end_action_button.tooltip_text).is_equal(Loc.localize(&"battle.hud.end_action_reason.no_selection"))
	assert_bool(instance._end_action_button.visible).is_true()


func test_state_selected_is_enabled_and_presentation_differs_from_disabled() -> void:
	var instance: BattleScreen = _make()
	_select_first(instance)
	_assert_presentation(instance, false)
	assert_str(instance._end_action_button.tooltip_text).is_equal("")
	var d: StyleBoxFlat = instance._end_action_button.get_theme_stylebox(&"disabled") as StyleBoxFlat
	var n: StyleBoxFlat = instance._end_action_button.get_theme_stylebox(&"normal") as StyleBoxFlat
	assert_int(n.border_width_left).is_not_equal(d.border_width_left)
	assert_bool(n.bg_color.a > 0.0 and d.bg_color.a == 0.0).is_true()


func test_state_enemy_phase_is_disabled_with_not_your_turn() -> void:
	var instance: BattleScreen = _make()
	_select_first(instance)
	instance._controller.end_faction_phase()
	instance._refresh_end_action_button()
	assert_int(instance._controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)
	_assert_presentation(instance, true)
	assert_str(instance._end_action_button.tooltip_text).is_equal(Loc.localize(&"battle.menu.reason_not_player_turn"))


func test_state_hand_open_follows_is_card_play_in_progress() -> void:
	var instance: BattleScreen = _make()
	_select_first(instance)
	instance._controller.open_hand()
	instance._refresh_end_action_button()
	var in_progress: bool = instance._controller.is_card_play_in_progress()
	print("MEASURED open_hand() -> is_card_play_in_progress = ", in_progress)
	assert_bool(instance._end_action_button.disabled).append_failure_message(
		"手牌展開未選牌:disabled 應等於 is_card_play_in_progress(實測值 %s)" % in_progress).is_equal(in_progress)
	if in_progress:
		assert_str(instance._end_action_button.tooltip_text).is_equal(Loc.localize(&"battle.menu.reason_card_play_in_progress"))


func test_state_attack_confirm_panel_open_is_disabled_with_card_reason() -> void:
	var instance: BattleScreen = _make()
	_select_first(instance)
	instance._attack_confirm_panel.visible = true
	instance._refresh_end_action_button()
	_assert_presentation(instance, true)
	assert_str(instance._end_action_button.tooltip_text).is_equal(Loc.localize(&"battle.menu.reason_card_play_in_progress"))


func test_state_finished_is_disabled_without_reason() -> void:
	# 用既有決鬥夾具(輸出同 battle_screen_battle_outcome_test):選 (0,0) 再點 (1,0) 打到勝利。
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.terrain_path_override = "res://assets/data/levels/test_fixture_terrain_duel.txt"
	instance.roster_path_override = "res://assets/data/units/test_fixture_roster_duel.txt"
	auto_free(instance)
	add_child(instance)
	assert_that(instance._controller.click_tile(Vector2i(0, 0))["action"]).is_equal(&"selected")
	assert_that(instance._controller.click_tile(Vector2i(1, 0))["action"]).is_equal(&"attacked")
	instance._refresh_end_action_button()
	assert_int(instance._controller.phase()).append_failure_message("PRECONDITION: 已 FINISHED").is_equal(BattleController.Phase.FINISHED)
	_assert_presentation(instance, true)
	assert_str(instance._end_action_button.tooltip_text).is_equal("")


func test_sensitivity_proof_always_available_mutant_fails_disabled_state() -> void:
	var instance: BattleScreen = _make(_MutantAlwaysAvailable)
	instance._refresh_end_action_button()
	assert_bool(instance._end_action_button.disabled).append_failure_message(
		"mutant:無選取卻可按(此斷言為假代表偵測得到)").is_false()


func test_sensitivity_proof_solid_disabled_style_mutant_is_detected() -> void:
	var instance: BattleScreen = _make(_MutantSolidDisabledStyle)
	var style: StyleBoxFlat = instance._end_action_button.get_theme_stylebox(&"disabled") as StyleBoxFlat
	assert_bool(style.bg_color.a == 0.0 and style.border_width_left == BattleScreen.HUD_BUTTON_DISABLED_BORDER_WIDTH).is_false()


func test_sensitivity_proof_font_not_gray_mutant_is_detected() -> void:
	var instance: BattleScreen = _make(_MutantGrayFontMissing)
	var b: Button = instance._end_action_button
	assert_bool(b.get_theme_color(&"font_disabled_color") != b.get_theme_color(&"font_color")).is_false()


# ---- AC5:結束畫面底條 ---------------------------------------------------------------

func test_hint_bar_hidden_on_end_and_visible_on_next_battle() -> void:
	var first: BattleScreen = _make()
	assert_bool(first._controls_hint_bg.visible).append_failure_message("PRECONDITION: 戰鬥中底條可見").is_true()
	first._on_battle_ended(BattleState.Outcome.VICTORY)
	assert_bool(first._controls_hint_bg.visible).is_false()
	var next: BattleScreen = _make()
	assert_bool(next._controls_hint_bg.visible).append_failure_message("下一場開始後底條應恢復可見").is_true()


func test_sensitivity_proof_bar_kept_on_end_mutant() -> void:
	var m: BattleScreen = _make(_MutantKeepsBarOnEnd)
	m._on_battle_ended(BattleState.Outcome.VICTORY)
	assert_bool(m._controls_hint_bg.visible).append_failure_message("mutant 漏隱藏(為真代表偵測得到)").is_true()


func test_sensitivity_proof_bar_not_restored_mutant() -> void:
	var m: BattleScreen = _make(_MutantHidesBarAtStart)
	assert_bool(m._controls_hint_bg.visible).append_failure_message("mutant 新場仍隱藏(為假代表偵測得到)").is_false()
