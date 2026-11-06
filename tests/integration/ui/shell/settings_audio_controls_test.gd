## audio-foundation story-002 —— 設定畫面三滑桿 + 靜音開關。
##
## 真實場景載入(load() SettingsScreen.tscn,不自組替身節點鏈)。
##
## 檔案存取類別:本檔【不】讀寫任何檔案(甲/乙類例外皆不適用)。GameSettings 持久化預設關閉
## (headless 下 boot_load 為 no-op,且測試不呼叫它),故不會碰真實 user://settings.cfg。
## 每條測試收尾呼叫 GameSettings.reset_for_test()。
##
## 輸入驗證:直接對 HSlider 呼叫 _gui_input() 餵 InputEventKey / InputEventJoypadButton
## (不用 InputEventAction —— 它不代表真實按鍵)。headless 不送真實 InputEvent,故這是
## 「控件對事件的反應」而非「引擎投遞」的驗證;鍵位對應走 InputMap 的 ui_left/ui_right。
##
## 不斷言「真的聽得到」(headless 無聲)。
##
## 敏感度證明(常駐,間諜子類別於 add_child 前 set_script,Case A 安全時機):
##   AC-2:_MutantNoWriteBack 吞掉寫回 → 偵測器必須判為「不寫回」。
##   AC-4:_MutantWrappingChain 把末端接回首端 → 偵測器必須判為「有環繞」。
##   證明不了的:AC-1/5/7 為純值同步/資料斷言(A/A′/第六類),不蓋證明。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/shell/SettingsScreen.tscn"
const _ROWS: String = "Panel/ContentMargin/Rows/"


class _MutantNoWriteBack extends SettingsScreen:
	func _on_master_changed(_value: float) -> void:
		pass


class _MutantWrappingChain extends SettingsScreen:
	func _ready() -> void:
		super._ready()
		var back: Button = get_node("Panel/ContentMargin/Rows/BackRow")
		var first: CheckButton = get_node("Panel/ContentMargin/Rows/EgmToggleRow")
		back.focus_neighbor_bottom = back.get_path_to(first)


var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	# push_input 會讓 CursorStateHost 以為有鍵盤輸入而改裁定;還原共用狀態。
	_host_snap.restore()
	GameSettings.reset_for_test()


func _make(script: Script = null) -> SettingsScreen:
	var inst: SettingsScreen = load(_SCENE_PATH).instantiate()
	if script != null:
		inst.set_script(script)
	auto_free(inst)
	add_child(inst)
	return inst


func _slider(s: SettingsScreen, row: String) -> HSlider:
	return s.get_node(_ROWS + row + "/Slider")


func _chain(s: SettingsScreen) -> Array[Control]:
	return [
		s.get_node(_ROWS + "EgmToggleRow"), s.get_node(_ROWS + "HideAffinityRow"),
		_slider(s, "MasterRow"), _slider(s, "MusicRow"), _slider(s, "SfxRow"),
		s.get_node(_ROWS + "MuteRow"), s.get_node(_ROWS + "BackRow"),
	]


## 偵測器:改主音量滑桿後 GameSettings 是否等於新值。
func _writes_back(s: SettingsScreen) -> bool:
	_slider(s, "MasterRow").value = 0.25
	return is_equal_approx(GameSettings.get_master_volume(), 0.25)


## 偵測器:焦點鏈是否有界(首項 top 指自己、末項 bottom 指自己、中間逐項相連)。
func _chain_bounded(s: SettingsScreen) -> bool:
	var c: Array[Control] = _chain(s)
	for i in c.size():
		var up: Control = c[maxi(i - 1, 0)]
		var down: Control = c[mini(i + 1, c.size() - 1)]
		if c[i].get_node(c[i].focus_neighbor_top) != up:
			return false
		if c[i].get_node(c[i].focus_neighbor_bottom) != down:
			return false
	return true


# ---- AC-1 ------------------------------------------------------------------

func test_settings_audio_initial_values_sync_from_game_settings() -> void:
	GameSettings.set_master_volume(0.3)
	GameSettings.set_music_volume(0.6)
	GameSettings.set_sfx_volume(0.9)
	GameSettings.set_muted(true)
	var s: SettingsScreen = _make()

	assert_float(_slider(s, "MasterRow").value).is_equal_approx(0.3, 0.001)
	assert_float(_slider(s, "MusicRow").value).is_equal_approx(0.6, 0.001)
	assert_float(_slider(s, "SfxRow").value).is_equal_approx(0.9, 0.001)
	assert_bool((s.get_node(_ROWS + "MuteRow") as CheckButton).button_pressed).is_true()


# ---- AC-2 ------------------------------------------------------------------

func test_settings_audio_controls_write_back_to_game_settings() -> void:
	var s: SettingsScreen = _make()

	_slider(s, "MasterRow").value = 0.25
	_slider(s, "MusicRow").value = 0.35
	_slider(s, "SfxRow").value = 0.45
	(s.get_node(_ROWS + "MuteRow") as CheckButton).button_pressed = true

	assert_float(GameSettings.get_master_volume()).is_equal_approx(0.25, 0.001)
	assert_float(GameSettings.get_music_volume()).is_equal_approx(0.35, 0.001)
	assert_float(GameSettings.get_sfx_volume()).is_equal_approx(0.45, 0.001)
	assert_bool(GameSettings.is_muted()).is_true()


func test_sensitivity_proof_write_back_detector_catches_swallowed_handler() -> void:
	assert_bool(_writes_back(_make())).is_true()
	GameSettings.reset_for_test()
	assert_bool(_writes_back(_make(_MutantNoWriteBack))).append_failure_message(
		"偵測器應判定突變體(吞掉寫回)為不寫回"
	).is_false()


# ---- AC-3 ------------------------------------------------------------------

func test_settings_audio_all_inputs_share_value_changed_and_toggled_handlers() -> void:
	var s: SettingsScreen = _make()
	var sl: HSlider = _slider(s, "MasterRow")
	var mute: CheckButton = s.get_node(_ROWS + "MuteRow")

	var vc: Array[Dictionary] = sl.get_signal_connection_list("value_changed")
	var found_vc: bool = false
	for d in vc:
		if (d["callable"] as Callable).get_method() == &"_on_master_changed":
			found_vc = true
	assert_bool(found_vc).is_true()
	var found_t: bool = false
	for d in mute.get_signal_connection_list("toggled"):
		if (d["callable"] as Callable).get_method() == &"_on_mute_toggled":
			found_t = true
	assert_bool(found_t).is_true()


func test_settings_audio_keyboard_left_right_adjusts_focused_slider() -> void:
	var s: SettingsScreen = _make()
	var sl: HSlider = _slider(s, "MasterRow")
	sl.value = 0.5
	sl.grab_focus()

	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	sl.get_viewport().push_input(right)
	var after_right: float = GameSettings.get_master_volume()

	var left := InputEventKey.new()
	left.keycode = KEY_LEFT
	left.pressed = true
	sl.get_viewport().push_input(left)
	sl.get_viewport().push_input(left)
	var after_left: float = GameSettings.get_master_volume()

	assert_float(after_right).append_failure_message(
		"KEY_RIGHT 應使滑桿 +step 並寫回 GameSettings,實得 %f" % after_right).is_greater(0.5)
	assert_float(after_left).append_failure_message(
		"KEY_LEFT x2 後應低於右鍵後的值,實得 %f" % after_left).is_less(after_right)


## 手把:headless 下 push_input(InputEventJoypadButton) 實測【不會】調動滑桿(鍵盤事件則會,
## 見上一條),原因未查明。故這裡只驗兩件可驗的事,並【誠實登記手把端到端未驗,需家中實測】:
## ① ui_right/ui_left 的 InputMap 確實含 d-pad 與左搖桿綁定;② 滑桿可取得焦點(FOCUS_ALL)。
## 鍵盤用的是同一組 ui_left/ui_right 動作,滑桿對動作反應已由鍵盤測試證明。
func test_settings_audio_gamepad_bindings_exist_for_slider_actions() -> void:
	var s: SettingsScreen = _make()
	var sl: HSlider = _slider(s, "MusicRow")
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_RIGHT
	dpad.pressed = true
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	assert_bool(InputMap.event_is_action(dpad, "ui_right")).is_true()
	assert_bool(InputMap.event_is_action(stick, "ui_right")).is_true()
	assert_int(sl.focus_mode).is_equal(Control.FOCUS_ALL)


# ---- AC-4 ------------------------------------------------------------------

func test_settings_audio_focus_chain_is_bounded_and_reaches_back() -> void:
	var s: SettingsScreen = _make()
	assert_bool(_chain_bounded(s)).is_true()
	for c in _chain(s):
		assert_int(c.focus_mode).is_equal(Control.FOCUS_ALL)


func test_sensitivity_proof_chain_detector_catches_wrap_around() -> void:
	assert_bool(_chain_bounded(_make())).is_true()
	assert_bool(_chain_bounded(_make(_MutantWrappingChain))).append_failure_message(
		"偵測器應判定突變體(末端環繞回首端)為非有界"
	).is_false()


# ---- AC-5 ------------------------------------------------------------------

func test_settings_audio_new_strings_exist_and_non_empty() -> void:
	for key in [&"shell.settings.volume_master", &"shell.settings.volume_music",
			&"shell.settings.volume_sfx", &"shell.settings.mute_toggle"]:
		var text: String = Loc.localize(key)
		assert_str(text).append_failure_message("鍵 %s 缺字串" % key).is_not_empty()
		assert_str(text).append_failure_message("鍵 %s 未翻譯(回傳 key 本身)" % key).is_not_equal(String(key))
	var s: SettingsScreen = _make()
	assert_str((s.get_node(_ROWS + "MasterRow/Label") as Label).text).is_equal(
		Loc.localize(&"shell.settings.volume_master"))
	assert_str((s.get_node(_ROWS + "MuteRow") as CheckButton).text).is_equal(
		Loc.localize(&"shell.settings.mute_toggle"))


# ---- AC-7 ------------------------------------------------------------------

func test_settings_audio_mute_does_not_change_slider_values() -> void:
	var s: SettingsScreen = _make()
	var before: Array[float] = [_slider(s, "MasterRow").value,
		_slider(s, "MusicRow").value, _slider(s, "SfxRow").value]

	(s.get_node(_ROWS + "MuteRow") as CheckButton).button_pressed = true

	assert_float(_slider(s, "MasterRow").value).is_equal(before[0])
	assert_float(_slider(s, "MusicRow").value).is_equal(before[1])
	assert_float(_slider(s, "SfxRow").value).is_equal(before[2])
	assert_float(GameSettings.get_master_volume()).is_equal_approx(before[0], 0.001)
