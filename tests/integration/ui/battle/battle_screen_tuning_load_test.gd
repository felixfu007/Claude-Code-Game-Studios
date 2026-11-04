# production/epics/tuning-data/story-001-tuning-skeleton.md AC3 / AC4
# 真實 BattleScreen.tscn:instantiate -> 設 tuning_path_override -> add_child(測試框架的
# add_child 於測試內同步呼叫,與既有 campaign_all_missions_load_test 同一手法)。
#
# 檔案存取:甲類例外 —— 唯讀 assets/data/tuning/ 版控夾具與真實檔。
# ⚠️ 不證明窮盡性:只證明本 story 的四種壞檔與兩種好檔的行為。
#
# 敏感度證明:test_sensitivity_proof_* —— 換掉注入的夾具路徑,BattleState.tuning 跟著換。
# 這是後續各 story 把某個旋鈕「真的接到行為」的敏感度證明的接線基礎。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _VALID: String = "res://assets/data/tuning/test_fixture_tuning_valid.txt"
const _REAL: String = "res://assets/data/tuning/tuning_knobs.txt"
const _UNKNOWN: String = "res://assets/data/tuning/test_fixture_tuning_unknown_key.txt"
const _DUPLICATE: String = "res://assets/data/tuning/test_fixture_tuning_duplicate_key.txt"
const _NON_INT: String = "res://assets/data/tuning/test_fixture_tuning_non_integer.txt"
const _MISSING: String = "res://assets/data/tuning/test_fixture_tuning_does_not_exist.txt"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()


func after_test() -> void:
	_host_snap.restore()
	CampaignProgress.reset_for_test()


func _load_with_tuning(path: String) -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.tuning_path_override = path
	add_child(instance)
	return instance


func test_tuning_load_valid_fixture_succeeds_and_state_holds_parsed_result() -> void:
	var instance: BattleScreen = _load_with_tuning(_VALID)
	assert_bool(instance._load_failed).is_false()
	var tuning: TuningKnobs = instance._state.tuning
	assert_bool(tuning.is_default).is_false()
	assert_str(tuning.diagnostic_source_text).contains("FIXTURE-VALID-MARKER")
	remove_child(instance)


func test_tuning_load_bad_fixtures_fail_loudly_not_silently_default() -> void:
	for path: String in [_UNKNOWN, _DUPLICATE, _NON_INT, _MISSING]:
		var instance: BattleScreen = _load_with_tuning(path)
		assert_bool(instance._load_failed).append_failure_message("應載入失敗:" + path).is_true()
		assert_bool(instance._state == null).append_failure_message("失敗時不得建立 _state:" + path).is_true()
		assert_str(instance.diagnostic_resolved_data_paths().get("tuning", "")).is_equal(path)
		remove_child(instance)


func test_tuning_load_default_path_loads_real_file() -> void:
	var instance: BattleScreen = _load_with_tuning("")
	assert_bool(instance._load_failed).is_false()
	assert_bool(instance._state.tuning.is_default).is_false()
	assert_str(instance.diagnostic_resolved_data_paths().get("tuning", "")).is_equal(_REAL)
	remove_child(instance)


# ── 敏感度證明(常駐) ─────────────────────────────────────────────────────
func test_sensitivity_proof_injected_fixture_path_changes_state_tuning() -> void:
	var a: BattleScreen = _load_with_tuning(_VALID)
	var b: BattleScreen = _load_with_tuning(_REAL)
	var text_a: String = a._state.tuning.diagnostic_source_text
	var text_b: String = b._state.tuning.diagnostic_source_text
	assert_int(text_a.length()).append_failure_message("A 的來源文字為空(length 0)").is_greater(0)
	assert_int(text_b.length()).append_failure_message("B 的來源文字為空(length 0)").is_greater(0)
	assert_bool(text_a != text_b).append_failure_message("換路徑後 tuning 必須跟著換").is_true()
	assert_bool(a._state.tuning != b._state.tuning).is_true()
	remove_child(a)
	remove_child(b)
