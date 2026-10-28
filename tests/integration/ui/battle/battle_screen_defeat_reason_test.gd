## battle_screen_defeat_reason_test.gd
##
## story-022(production/epics/tactical-combat/story-022-defeat-reason-text.md)
## 戰敗時結果文字附上倒下的我方角色名。
##
## 甲類檔案 I/O 揭露(.claude/rules/test-standards.md):載入真實 BattleScreen.tscn,
## 經 terrain_path_override / roster_path_override 唯讀餵入 assets/data/ 下已進版控的
## 夾具(test_fixture_terrain_duel.txt、test_fixture_roster_doomed.txt),AC2 另用預設
## vs01 真實資料(5 名我方)。不寫入任何檔案。
##
## 揭露:不證明窮盡性。AC2 的「同回合多人倒下」以 Unit.take_damage() 直接令兩名
## 我方單位 HP 歸零後呼叫 _on_battle_ended(DEFEAT) 驅動,並非走敵方 AI 真的一回合殺兩人
## (沒有現成夾具;自組會是另一份未驗證的場景)。AC1 走真實敵方回合。
##
## AC 對照:
##   test_defeat_text_names_fallen_character          -> AC1 + AC4
##   test_defeat_text_lists_every_fallen_character     -> AC2
##   test_victory_text_unchanged                        -> AC3(勝利);戰役完成文字由既有測試守住
##   test_sensitivity_proof_*                           -> 敏感度證明
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN_DUEL_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_DOOMED_PATH: String = "res://assets/data/units/test_fixture_roster_doomed.txt"
const _ROSTER_DUEL_PATH: String = "res://assets/data/units/test_fixture_roster_duel.txt"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


## 間諜:忽略倒下者,永遠只顯示純「戰敗」(證明 AC1/AC2 的文字斷言會抓到退步)。
class _MutantIgnoresFallen extends BattleScreen:
	func _defeat_result_text() -> String:
		return Loc.localize(TEXT_RESULT_DEFEAT)


## 間諜:只列第一位倒下者(證明 AC2 會抓到「只列一個」)。
class _MutantListsOnlyFirst extends BattleScreen:
	func _defeat_result_text() -> String:
		for id: int in _player_roster_ids:
			var unit: Unit = _state.unit_by_id(id)
			if unit != null and not unit.is_alive():
				return Loc.localize(TEXT_RESULT_DEFEAT_REASON_FORMAT) % Loc.localize(StringName("character.name.%d" % id))
		return Loc.localize(TEXT_RESULT_DEFEAT)


func _load(script: Script, terrain: String, roster: String) -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	if script != null:
		# set_script() 必須在 override 賦值之前(見 battle_screen_battle_outcome_test.gd 查證記錄)
		instance.set_script(script)
	if terrain != "":
		instance.terrain_path_override = terrain
	if roster != "":
		instance.roster_path_override = roster
	auto_free(instance)
	add_child(instance)
	return instance


func _expected_two() -> String:
	return Loc.localize(BattleScreen.TEXT_RESULT_DEFEAT_REASON_FORMAT) % (
		Loc.localize(&"character.name.1") + Loc.localize(BattleScreen.TEXT_RESULT_DEFEAT_REASON_SEPARATOR) + Loc.localize(&"character.name.3")
	)


func _kill_one_and_three(instance: BattleScreen) -> void:
	var u1: Unit = instance._state.unit_by_id(1)
	var u3: Unit = instance._state.unit_by_id(3)
	assert_bool(u1 != null and u3 != null and u1.is_alive() and u3.is_alive()).override_failure_message(
		"前提失敗(測試空轉):vs01 名冊的 1、3 號我方單位不存在或已倒下"
	).is_true()
	instance._state.commit_authoritative_change(func() -> void:
		u1.take_damage(9999)
		u3.take_damage(9999)
	)
	assert_bool(u1.is_alive() or u3.is_alive()).override_failure_message(
		"前提失敗(測試空轉):兩名單位未真的倒下"
	).is_false()


func test_defeat_text_names_fallen_character() -> void:
	var instance: BattleScreen = _load(null, _TERRAIN_DUEL_PATH, _ROSTER_DOOMED_PATH)
	await instance._end_faction_phase_pressed()
	assert_int(instance._controller.outcome()).override_failure_message("前提失敗(測試空轉):未打到戰敗").is_equal(BattleState.Outcome.DEFEAT)
	var expected: String = Loc.localize(BattleScreen.TEXT_RESULT_DEFEAT_REASON_FORMAT) % Loc.localize(&"character.name.1")
	assert_str(instance._result_label.text).is_equal(expected)
	assert_str(instance._result_label.text).contains(Loc.localize(&"character.name.1"))


func test_defeat_text_lists_every_fallen_character() -> void:
	var instance: BattleScreen = _load(null, "", "")
	_kill_one_and_three(instance)
	instance._on_battle_ended(BattleState.Outcome.DEFEAT)
	assert_str(instance._result_label.text).is_equal(_expected_two())


func test_victory_text_unchanged() -> void:
	var instance: BattleScreen = _load(null, _TERRAIN_DUEL_PATH, _ROSTER_DUEL_PATH)
	instance._controller.click_tile(Vector2i(0, 0))
	instance._controller.click_tile(Vector2i(1, 0))
	assert_int(instance._controller.outcome()).override_failure_message("前提失敗(測試空轉):未打到勝利").is_equal(BattleState.Outcome.VICTORY)
	assert_str(instance._result_label.text).is_equal(Loc.localize(BattleScreen.TEXT_RESULT_VICTORY))


func test_sensitivity_proof_ignoring_fallen_is_caught() -> void:
	var instance: BattleScreen = _load(_MutantIgnoresFallen, "", "")
	_kill_one_and_three(instance)
	instance._on_battle_ended(BattleState.Outcome.DEFEAT)
	# 間諜只顯示純「戰敗」,與期望的多人文字不同 —— 證明 AC2 斷言會抓到
	assert_str(instance._result_label.text).is_equal(Loc.localize(BattleScreen.TEXT_RESULT_DEFEAT))
	assert_str(instance._result_label.text).is_not_equal(_expected_two())


func test_sensitivity_proof_listing_only_first_is_caught() -> void:
	var instance: BattleScreen = _load(_MutantListsOnlyFirst, "", "")
	_kill_one_and_three(instance)
	instance._on_battle_ended(BattleState.Outcome.DEFEAT)
	assert_str(instance._result_label.text).is_not_equal(_expected_two())
	assert_bool(instance._result_label.text.contains(Loc.localize(&"character.name.3"))).is_false()
