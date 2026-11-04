# production/epics/tuning-data/story-004-combat-rules-tuning.md AC2 / AC3 / AC4
# 真實 BattleScreen.tscn 注入 tuning_path_override:證明結算(BattleState breakdown)與
# 畫面減傷顯示(BattleScreen.displayed_guard,吃同一個 combat_tuning)讀的是【同一份】注入設定。
# 檔案存取:甲類例外 —— 唯讀 assets/data/tuning/ 版控夾具與真實檔。⚠️ 不證明窮盡性。
# ⚠️ 顯示路徑以 BattleScreen.displayed_guard(static)直接呼叫,未驅動 _displayed_guard_at 本身。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _REAL: String = "res://assets/data/tuning/tuning_knobs.txt"
const _GUARD1: String = "res://assets/data/tuning/test_fixture_tuning_combat_guard.txt"
const _HOLDBACK3: String = "res://assets/data/tuning/test_fixture_tuning_combat_holdback.txt"
const _TERRAIN: PackedStringArray = ["........", "........", "........"]

var _host_snap: CursorHostSnapshot = null


class _StubPhi extends RefCounted:
	var value: int = 12

	func phi_of(_unit_id: int) -> int:
		return value


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


func test_real_file_equals_defaults() -> void:
	var s: BattleScreen = _load_with_tuning(_REAL)
	assert_bool(s._load_failed).is_false()
	var t: CombatTuning = s._state.combat_tuning
	var d: CombatTuning = CombatTuning.defaults()
	assert_int(t.guard_min()).is_equal(d.guard_min())
	assert_int(t.guard_max()).is_equal(d.guard_max())
	assert_int(t.hold_back_penalty()).is_equal(d.hold_back_penalty())
	remove_child(s)


func test_sensitivity_proof_guard_max_in_settlement_and_display() -> void:
	var s: BattleScreen = _load_with_tuning(_GUARD1)
	assert_bool(s._load_failed).is_false()
	var state: BattleState = s._state
	var stub: _StubPhi = _StubPhi.new()
	state.attach_defense_phi_provider(Callable(stub, "phi_of"))
	var player: Unit = state.units_of(Unit.Faction.PLAYER)[0]
	var enemy: Unit = state.units_of(Unit.Faction.ENEMY)[0]
	# 結算/預覽路徑:Φ=12 -> guard_phi 6 -> 夾到注入的 guard_max=1(預設會是 3)。
	var bd: Dictionary = state.preview_damage_breakdown(enemy.id, player.id, 0).breakdown
	assert_int(int(bd["guard_phi"])).is_equal(6)
	assert_int(int(bd["guard"])).is_equal(1)
	# 顯示路徑吃同一份設定 -> 答案一致。
	assert_int(BattleScreen.displayed_guard(12, 0, false, state.combat_tuning)).is_equal(int(bd["guard"]))
	remove_child(s)


func test_sensitivity_proof_hold_back_penalty_in_settlement() -> void:
	var s: BattleScreen = _load_with_tuning(_HOLDBACK3)
	assert_bool(s._load_failed).is_false()
	assert_int(s._state.combat_tuning.hold_back_penalty()).is_equal(3)
	# 以 BattleScreen 載入後持有的 knobs 建 d=2 的騎牆者:結算 breakdown 的留一手 = 3(預設會是 1)。
	var roster: String = "\n".join([
		"1,甲,PLAYER,30,16,8,6,1,1,0,0",
		"5,戊,PLAYER,30,16,8,6,1,1,2,0,1",
		"6,E1,ENEMY,300,14,6,6,1,1,7,2",
	])
	var state: BattleState = BattleState.create(_TERRAIN, roster, s._state.tuning)
	var bd: Dictionary = state.preview_damage_breakdown(5, 6, 0).breakdown
	assert_int(int(bd["hold_back"])).is_equal(3)
	assert_int(int(bd["damage"])).is_equal(10 - 3)
	remove_child(s)


func test_load_fails_loudly_on_bad_tuning_file() -> void:
	# combat 缺鍵/不變式違反由單元測試覆蓋;這裡證 BattleScreen 對壞檔明確失敗。
	var s: BattleScreen = _load_with_tuning("res://assets/data/tuning/test_fixture_tuning_deck_missing_key.txt")
	assert_bool(s._load_failed).is_true()
	assert_bool(s._state == null).is_true()
	remove_child(s)
