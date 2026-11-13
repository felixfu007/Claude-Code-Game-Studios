## battle_screen_objective_and_menu_test.gd
##
## story-046:開場目標(AC1)、結果畫面「規則/下一步」兩行(AC3)、敏感度證明(AC5)。
## 🔴 AC2(選單「目標」「圖例」項)本檔【未涵蓋】:需改 battle_menu.gd / BattleMenu.tscn,
## 超出工單 Affected Files,已停下回報,見交付回報。
##
## 甲類檔案 I/O 揭露(.claude/rules/test-standards.md):載入真實 BattleScreen.tscn,
## 經 terrain/roster_path_override 唯讀餵入 assets/data/ 下已進版控的夾具
## (test_fixture_terrain_duel.txt、test_fixture_roster_duel.txt)。不寫入任何檔案。
## 揭露:不證明窮盡性;只驗文字內容與可見性,不驗像素(AC6 另案)。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN_DUEL_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_DUEL_PATH: String = "res://assets/data/units/test_fixture_roster_duel.txt"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()
	TutorialProgress.end()


func after_test() -> void:
	_host_snap.restore()
	CampaignProgress.reset_for_test()
	TutorialProgress.end()


## 突變體①:目標文字被清空。
class _MutantEmptyObjective extends BattleScreen:
	func objective_text() -> String:
		return ""


## 突變體③:結果細節漏掉「規則」行,只剩「下一步」。
class _MutantNoRuleLine extends BattleScreen:
	func result_detail_text(outcome: BattleState.Outcome) -> String:
		var full: String = super.result_detail_text(outcome)
		return full.substr(full.find("\n") + 1)


func _load(script: Script) -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	if script != null:
		# set_script() 必須先於 override 賦值(set_script 會清回宣告預設值)
		instance.set_script(script)
	instance.terrain_path_override = _TERRAIN_DUEL_PATH
	instance.roster_path_override = _ROSTER_DUEL_PATH
	auto_free(instance)
	add_child(instance)
	return instance


func _confirm_event() -> InputEventAction:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"battle_confirm"
	ev.pressed = true
	return ev


# ---- AC1 -------------------------------------------------------------------

func test_objective_visible_at_start_with_localized_text() -> void:
	var instance: BattleScreen = _load(null)
	assert_bool(instance.is_objective_visible()).is_true()
	var label: Label = instance.get_node("UILayer/ObjectivePanel/ObjectiveLabel") as Label
	assert_str(label.text).is_equal(Loc.localize(&"battle.objective.line"))
	assert_str(label.text).is_not_empty()


func test_objective_dismissed_by_confirm_key_and_does_not_block_input() -> void:
	var instance: BattleScreen = _load(null)
	assert_bool(instance.is_objective_visible()).is_true()
	instance._input(_confirm_event())
	assert_bool(instance.is_objective_visible()).is_false()
	assert_bool(instance.get_node("UILayer/ObjectivePanel").mouse_filter == Control.MOUSE_FILTER_IGNORE).is_true()


func test_tutorial_objective_has_extra_learn_line() -> void:
	TutorialProgress.begin()
	var instance: BattleScreen = _load(null)
	var expected: String = Loc.localize(&"battle.objective.line") + "\n" + Loc.localize(&"battle.objective.tut01_learn")
	assert_str(instance.get_node("UILayer/ObjectivePanel/ObjectiveLabel").text).is_equal(expected)


# ---- AC3 -------------------------------------------------------------------

func _detail(instance: BattleScreen) -> String:
	return (instance.get_node("UILayer/ResultDetailLabel") as Label).text


func test_victory_and_defeat_each_have_rule_and_next_lines_and_differ() -> void:
	var win: BattleScreen = _load(null)
	win._on_battle_ended(BattleState.Outcome.VICTORY)
	var lose: BattleScreen = _load(null)
	lose._on_battle_ended(BattleState.Outcome.DEFEAT)
	var win_lines: PackedStringArray = _detail(win).split("\n")
	var lose_lines: PackedStringArray = _detail(lose).split("\n")
	assert_int(win_lines.size()).is_equal(2)
	assert_int(lose_lines.size()).is_equal(2)
	assert_str(win_lines[0]).is_equal(Loc.localize(&"battle.result.rule_victory"))
	assert_str(lose_lines[0]).is_equal(Loc.localize(&"battle.result.rule_defeat"))
	assert_str(win_lines[1]).is_equal(Loc.localize(&"battle.result.next_title"))
	assert_str(_detail(win)).is_not_equal(_detail(lose))
	assert_bool((win.get_node("UILayer/ResultDetailLabel") as Label).visible).is_true()


func test_campaign_defeat_next_line_does_not_promise_restart_same_mission() -> void:
	var instance: BattleScreen = _load(null)
	instance.campaign_ledger_override = CampaignProgress.start_mission_affinity_ledger()
	instance._on_battle_ended(BattleState.Outcome.DEFEAT)
	var next_line: String = _detail(instance).split("\n")[1]
	assert_str(next_line).is_equal(Loc.localize(&"battle.result.next_defeat_campaign"))
	# 2026-11-13 實測:標題「開始戰鬥」進教學第 1 場,故文字不得承諾「可再次開始戰鬥」。
	assert_bool(next_line.contains("再次")).is_false()


func test_campaign_victory_not_last_mission_next_is_next_mission() -> void:
	var instance: BattleScreen = _load(null)
	instance.campaign_ledger_override = CampaignProgress.start_mission_affinity_ledger()
	instance._on_battle_ended(BattleState.Outcome.VICTORY)
	assert_str(_detail(instance).split("\n")[1]).is_equal(Loc.localize(&"battle.result.next_mission"))


func test_tutorial_defeat_next_is_replay_same_mission() -> void:
	TutorialProgress.begin()
	var instance: BattleScreen = _load(null)
	instance._on_battle_ended(BattleState.Outcome.DEFEAT)
	assert_str(_detail(instance).split("\n")[1]).is_equal(Loc.localize(&"battle.result.next_defeat_tutorial"))


# ---- AC5 敏感度證明(一次一個 mutant;對應的真測試以同樣情境斷言) -------------------

func test_sensitivity_empty_objective_is_caught() -> void:
	var instance: BattleScreen = _load(_MutantEmptyObjective)
	var label: Label = instance.get_node("UILayer/ObjectivePanel/ObjectiveLabel") as Label
	assert_str(label.text).is_not_equal(Loc.localize(&"battle.objective.line"))


func test_sensitivity_missing_rule_line_is_caught() -> void:
	var instance: BattleScreen = _load(_MutantNoRuleLine)
	instance._on_battle_ended(BattleState.Outcome.DEFEAT)
	assert_int(_detail(instance).split("\n").size()).is_not_equal(2)
