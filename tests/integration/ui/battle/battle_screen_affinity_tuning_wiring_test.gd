# production/epics/tuning-data/story-005-affinity-rules-tuning.md AC2 / AC4
# 真實 BattleScreen.tscn 注入 tuning_path_override:證明 BattleState、AffinityPhiProvider(結算 Φ)
# 讀的是【同一份】注入的 AffinityTuning。
# 檔案存取:甲類例外 —— 唯讀 assets/data/tuning/ 版控夾具與真實檔。⚠️ 不證明窮盡性。
# 未涵蓋:BattleScreen 壞檔失敗(phi_min>phi_max)僅由單元測試證 AffinityTuning.from_text 回 null。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _REAL: String = "res://assets/data/tuning/tuning_knobs.txt"
const _NARROW: String = "res://assets/data/tuning/test_fixture_tuning_affinity_phi_narrow.txt"

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


func test_real_file_affinity_equals_defaults() -> void:
	var s: BattleScreen = _load_with_tuning(_REAL)
	assert_bool(s._load_failed).is_false()
	var t: AffinityTuning = s._state.affinity_tuning
	var d: AffinityTuning = AffinityTuning.defaults()
	assert_int(t.phi_min()).is_equal(d.phi_min())
	assert_int(t.phi_max()).is_equal(d.phi_max())
	assert_int(t.delta_positive_adjacent()).is_equal(d.delta_positive_adjacent())
	remove_child(s)


func test_sensitivity_proof_phi_max_reaches_state_and_phi_provider() -> void:
	var s: BattleScreen = _load_with_tuning(_NARROW)
	assert_bool(s._load_failed).is_false()
	assert_int(s._state.affinity_tuning.phi_max()).is_equal(6)
	# 結算 Φ 的提供者讀同一份:任何單位的 Φ 都不得超過新上限,且與同設定直接呼叫一致。
	var positions: Dictionary[int, Vector2i] = s._phi.positions()
	var links: Array[AffinityLink] = s._phi.links()
	for unit: Unit in s._state.units_of(Unit.Faction.PLAYER):
		var via_provider: int = s._phi.phi_of(unit.id)
		assert_int(via_provider).is_less_equal(6)
		assert_int(via_provider).is_equal(
			AffinityRules.bonus_for(unit.id, positions, links, s._state.affinity_tuning))
	remove_child(s)
