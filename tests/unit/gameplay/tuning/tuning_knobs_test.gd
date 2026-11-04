# production/epics/tuning-data/story-001-tuning-skeleton.md AC2 / AC5
# TuningKnobs.from_text 純解析單元測試。
#
# 檔案存取:僅一條甲類例外 —— 唯讀 assets/data/tuning/tuning_knobs.txt(已進版控),
# 證明「真實資料檔可解析」。⚠️ 不證明窮盡性(只證明這個檔此刻能解析,不證明日後增補的鍵合法)。
# 其餘測試全用 in-test 字串,零 I/O。
#
# 敏感度證明:見 test_sensitivity_proof_*。AC2「push_error 有訊息」用 assert_error() 證明
# 訊息真的發出,訊息文字逐字比對,不只看回傳 null。
extends GdUnitTestSuite


const _REAL_PATH: String = "res://assets/data/tuning/tuning_knobs.txt"
# 測試用已知鍵清單(production 清單在 story-001 為空)。
const _TEST_KNOWN: Dictionary = {"combat.alpha": 5, "combat.beta": 7}


func test_tuning_knobs_valid_text_returns_object_with_values() -> void:
	var parsed: Variant = TuningKnobs.from_text("# c\n\ncombat,alpha,3\n combat , beta , -4 \n", _TEST_KNOWN)
	assert_bool(parsed != null).is_true()
	var knobs: TuningKnobs = parsed as TuningKnobs
	assert_int(knobs.get_int("combat", "alpha")).is_equal(3)
	assert_int(knobs.get_int("combat", "beta")).is_equal(-4)
	assert_bool(knobs.is_default).is_false()


func test_tuning_knobs_empty_text_missing_keys_returns_null_and_pushes_error() -> void:
	var result: Array = [TuningKnobs.defaults()]
	await assert_error(func() -> void: result[0] = TuningKnobs.from_text("")) \
		.is_push_error("TuningKnobs.from_text: missing required key 'deck.opening_hand_size'")
	assert_bool(result[0] == null).is_true()


func test_tuning_knobs_partial_file_names_the_missing_key() -> void:
	var result: Array = [TuningKnobs.defaults()]
	await assert_error(func() -> void: result[0] = TuningKnobs.from_text("combat,alpha,3\n", _TEST_KNOWN)) \
		.is_push_error("TuningKnobs.from_text: missing required key 'combat.beta'")
	assert_bool(result[0] == null).is_true()


func test_tuning_knobs_missing_key_falls_back_to_known_default_only_via_defaults() -> void:
	var defaults: TuningKnobs = TuningKnobs.defaults()
	assert_bool(defaults.is_default).is_true()


func test_tuning_knobs_unknown_key_returns_null_and_pushes_error() -> void:
	var result: Array = [null]
	await assert_error(func() -> void: result[0] = TuningKnobs.from_text("combat,gamma,1\n", _TEST_KNOWN)) \
		.is_push_error("TuningKnobs.from_text: line 1: unknown key 'combat.gamma'")
	assert_bool(result[0] == null).is_true()


func test_tuning_knobs_duplicate_key_returns_null_and_pushes_error() -> void:
	var result: Array = [null]
	await assert_error(func() -> void: result[0] = TuningKnobs.from_text("combat,alpha,1\ncombat,alpha,2\n", _TEST_KNOWN)) \
		.is_push_error("TuningKnobs.from_text: line 2: duplicate key 'combat.alpha'")
	assert_bool(result[0] == null).is_true()


func test_tuning_knobs_non_integer_returns_null_and_pushes_error() -> void:
	var result: Array = [null]
	await assert_error(func() -> void: result[0] = TuningKnobs.from_text("combat,alpha,1.5\n", _TEST_KNOWN)) \
		.is_push_error("TuningKnobs.from_text: line 1: value '1.5' is not an integer")
	assert_bool(result[0] == null).is_true()


func test_tuning_knobs_wrong_field_count_returns_null_and_pushes_error() -> void:
	var result: Array = [null]
	await assert_error(func() -> void: result[0] = TuningKnobs.from_text("combat,alpha\n", _TEST_KNOWN)) \
		.is_push_error("TuningKnobs.from_text: line 1: expected 3 fields (section,key,value), got 2")
	assert_bool(result[0] == null).is_true()


func test_tuning_knobs_real_data_file_parses() -> void:
	# 甲類例外:唯讀版控資料檔。
	var text: String = FileAccess.get_file_as_string(_REAL_PATH)
	assert_int(text.length()).append_failure_message("real file read as empty (length 0)").is_greater(0)
	assert_bool(TuningKnobs.from_text(text) != null).is_true()


# ── 敏感度證明 ─────────────────────────────────────────────────────────────
## 若 from_text 不驗證未知鍵(把同一份文字餵給「不含該鍵」與「含該鍵」的清單),
## 結果必須不同 —— 證明驗證分支真的看清單。
func test_sensitivity_proof_known_key_list_controls_acceptance() -> void:
	var text: String = "combat,alpha,3\ncombat,beta,4\n"
	assert_bool(TuningKnobs.from_text(text, _TEST_KNOWN) != null).is_true()
	var result: Array = [true]
	await assert_error(func() -> void: result[0] = TuningKnobs.from_text(text, {}) == null) \
		.is_push_error("TuningKnobs.from_text: line 1: unknown key 'combat.alpha'")
	assert_bool(result[0]).is_true()
