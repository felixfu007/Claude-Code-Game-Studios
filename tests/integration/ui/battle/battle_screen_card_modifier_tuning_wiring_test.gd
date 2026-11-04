# production/epics/tuning-data/story-003-card-modifier-tuning.md AC2 / AC3 / AC4
# 真實 BattleScreen.tscn 注入 tuning_path_override:證明戰鬥結算(BattleState -> Unit.effective_*)
# 與卡牌確認預覽(battle_screen.gd 預覽呼叫處)讀的是【同一份】注入設定。
# 檔案存取:甲類例外 —— 唯讀 assets/data/tuning/ 版控夾具與真實檔。⚠️ 不證明窮盡性。
# ⚠️ 未驅動 _open_card_confirm_panel() 本身;預覽處讀 _state.card_modifier_tuning 以讀碼與本檔
# 「同源物件」斷言為憑,不是由面板文字斷言。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _REAL: String = "res://assets/data/tuning/tuning_knobs.txt"
const _NARROW: String = "res://assets/data/tuning/test_fixture_tuning_card_modifier_narrow.txt"

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


func _boost(unit: Unit, atk_delta: int, def_delta: int) -> void:
	unit.add_modifier(CardModifier.new("t", atk_delta, def_delta, 1))


func test_real_file_equals_defaults() -> void:
	var s: BattleScreen = _load_with_tuning(_REAL)
	assert_bool(s._load_failed).is_false()
	var t: CardModifierTuning = s._state.card_modifier_tuning
	assert_int(t.atk_delta_max()).is_equal(CardModifierRules.ATK_DELTA_MAX)
	assert_int(t.def_delta_min()).is_equal(CardModifierRules.DEF_DELTA_MIN)
	remove_child(s)


func test_sensitivity_proof_settlement_and_preview_share_injected_clamp() -> void:
	var s: BattleScreen = _load_with_tuning(_NARROW)
	assert_bool(s._load_failed).is_false()
	var state: BattleState = s._state
	var player: Unit = state.units_of(Unit.Faction.PLAYER)[0]
	var enemy: Unit = state.units_of(Unit.Faction.ENEMY)[0]
	_boost(player, 99, 0)
	_boost(enemy, 0, 99)
	# 結算路徑:effective 值被注入的夾限(atk +2 / def +1)限制,而非今日的 +6 / +4。
	var atk_settle: int = player.effective_atk(state.card_modifier_tuning)
	var def_settle: int = enemy.effective_def(state.card_modifier_tuning)
	assert_int(atk_settle).is_equal(player.atk + 2)
	assert_int(def_settle).is_equal(enemy.def + 1)
	# 預覽路徑(與 battle_screen.gd 預覽呼叫處同一呼叫形狀、同一物件)答案一致。
	assert_int(CardModifierRules.effective_atk(player.atk, player.active_modifiers(), state.card_modifier_tuning)).is_equal(atk_settle)
	assert_int(CardModifierRules.effective_def(enemy.def, enemy.active_modifiers(), state.card_modifier_tuning)).is_equal(def_settle)
	# 真實結算入口讀的也是這份:breakdown 的 atk/def 欄位等於夾限後的值。
	var result: DamageBreakdownResult = state.preview_damage_breakdown(player.id, enemy.id, 0)
	assert_int(int(result.breakdown["atk"])).is_equal(atk_settle)
	assert_int(int(result.breakdown["def"])).is_equal(def_settle)
	remove_child(s)


func test_load_fails_loudly_on_inverted_bounds() -> void:
	# 反向夾限由 CardModifierTuning 單元測試覆蓋;這裡只證 BattleScreen 對缺鍵檔失敗(沿用 deck 夾具)。
	var s: BattleScreen = _load_with_tuning("res://assets/data/tuning/test_fixture_tuning_deck_missing_key.txt")
	assert_bool(s._load_failed).is_true()
	assert_bool(s._state == null).is_true()
	remove_child(s)
