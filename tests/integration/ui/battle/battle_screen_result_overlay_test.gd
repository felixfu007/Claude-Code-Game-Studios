## battle_screen_result_overlay_test.gd
##
## story-025(production/epics/tactical-combat/story-025-result-overlay.md)
## 勝利/戰敗改為畫面中央大字 + 滿版半透明遮罩。
##
## 甲類檔案 I/O 揭露(.claude/rules/test-standards.md):載入真實 BattleScreen.tscn,
## 經 terrain_path_override / roster_path_override 唯讀餵入 assets/data/ 下已進版控的
## 夾具(test_fixture_terrain_duel.txt、test_fixture_roster_duel.txt)。不寫入任何檔案。
##
## 🔴 截圖 AC 不在此:像素只能開窗量,管理者在公司,本批延後由管理者在家目視。
## 本檔只做 headless 結構斷言(遮罩節點存在/可見/覆蓋整個視窗、文字置中、字級大於 HUD 字級)。
## 揭露:不證明窮盡性,也不證明畫面「看起來對」。
##
## AC 對照:
##   test_overlay_hidden_before_battle_ends       -> 前提(戰鬥未結束時沒有遮罩)
##   test_victory_shows_mask_covering_whole_window -> AC2
##   test_victory_text_is_centered_and_larger_than_hud_font -> AC1
##   test_status_label_hidden_after_battle_ended   -> AC3(擇一:隱藏)
##   test_sensitivity_proof_*                      -> 敏感度證明(AC2)
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN_DUEL_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_DUEL_PATH: String = "res://assets/data/units/test_fixture_roster_duel.txt"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


## 間諜:戰鬥結束時不顯示遮罩(證明 AC2 斷言會抓到「忘了開遮罩」)。
class _MutantNoMask extends BattleScreen:
	func _on_battle_ended(outcome: BattleState.Outcome) -> void:
		super(outcome)
		_result_mask.visible = false


func _load(script: Script) -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	if script != null:
		# set_script() 必須在 override 賦值之前(見 battle_screen_defeat_reason_test.gd)
		instance.set_script(script)
	instance.terrain_path_override = _TERRAIN_DUEL_PATH
	instance.roster_path_override = _ROSTER_DUEL_PATH
	auto_free(instance)
	add_child(instance)
	return instance


func _win(instance: BattleScreen) -> void:
	instance._controller.click_tile(Vector2i(0, 0))
	instance._controller.click_tile(Vector2i(1, 0))
	assert_int(instance._controller.outcome()).override_failure_message(
		"前提失敗(測試空轉):未打到勝利"
	).is_equal(BattleState.Outcome.VICTORY)


func test_overlay_hidden_before_battle_ends() -> void:
	var instance: BattleScreen = _load(null)
	assert_object(instance.get_node_or_null("UILayer/ResultMask")).is_not_null()
	assert_bool(instance._result_mask.visible).is_false()
	assert_bool(instance._result_label.visible).is_false()


func test_victory_shows_mask_covering_whole_window() -> void:
	var instance: BattleScreen = _load(null)
	_win(instance)
	await get_tree().process_frame
	var window_size: Vector2 = Vector2(instance.get_window().size)
	var mask: ColorRect = instance._result_mask
	assert_bool(mask.visible).is_true()
	assert_vector(mask.get_global_rect().position).is_equal(Vector2.ZERO)
	assert_vector(mask.get_global_rect().size).is_equal(window_size)
	assert_float(mask.color.a).is_greater(0.0)
	assert_float(mask.color.a).is_less(1.0)
	# 管理者 2026-10-29 裁決「擋住(推薦)」:結果顯示期間遮罩擋住滑鼠點到底下的 HUD 按鈕。
	assert_int(mask.mouse_filter).append_failure_message("結果遮罩須擋住點擊(MOUSE_FILTER_STOP)").is_equal(Control.MOUSE_FILTER_STOP)


func test_victory_text_is_centered_and_larger_than_hud_font() -> void:
	var instance: BattleScreen = _load(null)
	_win(instance)
	await get_tree().process_frame
	var window_size: Vector2i = instance.get_window().size
	var label: Label = instance._result_label
	assert_bool(label.visible).is_true()
	assert_vector(label.get_global_rect().get_center()).is_equal_approx(Vector2(window_size) / 2.0, Vector2(1.0, 1.0))
	var hud_px: int = HudLayout.font_size(window_size)
	var result_px: int = label.get_theme_font_size(&"font_size")
	assert_int(result_px).is_equal(HudLayout.result_font_size(window_size))
	assert_int(result_px).is_greater(hud_px)
	assert_int(result_px % HudLayout.GLYPH_PX).is_equal(0)


func test_status_label_hidden_after_battle_ended() -> void:
	var instance: BattleScreen = _load(null)
	assert_bool(instance._status_label.visible).is_true()
	_win(instance)
	assert_bool(instance._status_label.visible).is_false()


func test_sensitivity_proof_missing_mask_is_caught() -> void:
	var instance: BattleScreen = _load(_MutantNoMask)
	_win(instance)
	assert_bool(instance._result_mask.visible).is_false()
