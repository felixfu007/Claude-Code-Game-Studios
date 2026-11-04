# production/epics/tuning-data/story-002-card-deck-tuning.md AC2 / AC3 / AC4
# 真實 BattleScreen.tscn 注入 tuning_path_override:證明 CardDeck 與手牌列用的是【注入的】設定,
# 且資料檔刪鍵 / 違反不變式時載入明確失敗。
# 檔案存取:甲類例外 —— 唯讀 assets/data/tuning/ 版控夾具與真實檔。⚠️ 不證明窮盡性。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _REAL: String = "res://assets/data/tuning/tuning_knobs.txt"
const _HAND3: String = "res://assets/data/tuning/test_fixture_tuning_deck_hand3.txt"
const _MISSING_KEY: String = "res://assets/data/tuning/test_fixture_tuning_deck_missing_key.txt"
const _OPEN_GT_LIMIT: String = "res://assets/data/tuning/test_fixture_tuning_deck_opening_gt_limit.txt"

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


func test_real_file_equals_defaults_and_deck_uses_five() -> void:
	var s: BattleScreen = _load_with_tuning(_REAL)
	assert_bool(s._load_failed).is_false()
	var deck: CardDeck = s._state.card_deck()
	assert_int(deck.hand_size_limit()).is_equal(CardDeck.HAND_SIZE_LIMIT)
	assert_int(deck.hand_size()).is_equal(CardDeck.OPENING_HAND_SIZE)
	assert_int(s._hand_bar.diagnostic_max_slots()).is_equal(5)
	remove_child(s)


# ── 敏感度證明(常駐):走真實流程,可觀測行為跟著注入的檔案改變 ──────────────
func test_sensitivity_proof_injected_hand_limit_changes_hand_bar_and_opening_hand() -> void:
	var s: BattleScreen = _load_with_tuning(_HAND3)
	assert_bool(s._load_failed).is_false()
	var deck: CardDeck = s._state.card_deck()
	assert_int(deck.hand_size_limit()).is_equal(3)
	assert_int(deck.hand_size()).is_equal(3)
	assert_int(s._hand_bar.diagnostic_max_slots()).append_failure_message("手牌列槽數應為注入的 3").is_equal(3)
	assert_bool(s._hand_button.text.ends_with("3")).append_failure_message("手牌按鈕應顯示 n/3:" + s._hand_button.text).is_true()
	remove_child(s)


func test_load_fails_loudly_on_deleted_key_and_on_invariant_violation() -> void:
	for path: String in [_MISSING_KEY, _OPEN_GT_LIMIT]:
		var s: BattleScreen = _load_with_tuning(path)
		assert_bool(s._load_failed).append_failure_message("應載入失敗:" + path).is_true()
		assert_bool(s._state == null).is_true()
		remove_child(s)
