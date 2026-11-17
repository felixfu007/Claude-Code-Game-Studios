extends GdUnitTestSuite
## Story 013:好感度位置系統(AffinityPhiProvider)改讀關係狀態 AffinityRelation.state_of。
## 規格:production/epics/skill-card-system/story-013-position-chain-reads-relation-state.md
## 檔案存取:AC5 載入真實 BattleScreen.tscn(預設真實資料檔,唯讀,甲類例外);其餘無。
##
## AC1(k=0 回歸)主體是既有 affinity_phi_provider_test.gd 等檔斷言未改且全綠;
## 本檔另有 test_k0_*_matches_legacy_sign_rule 釘住 k=0 逐位等同「正→POSITIVE、負→NEGATIVE、n==0→無線」。
##
## 敏感度證明:AffinityPhiProvider 可繼承,mutant 子類別覆寫 _link_for_pair(進樹前不涉及 set_script)。
## ① 仍以名字決定人設線 → AC2 紅  ② 忽略冷淡區 → AC3 紅  ③ 快取 S → AC4 紅  ④ POS/NEG 對調 → AC2 紅。

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _OTHERS: String = "deck,opening_hand_size,5\ndeck,hand_size_limit,5\ndeck,cards_drawn_per_turn,1\n" \
	+ "card_modifier,atk_delta_min,-4\ncard_modifier,atk_delta_max,6\ncard_modifier,def_delta_min,-3\ncard_modifier,def_delta_max,4\n" \
	+ "combat,guard_min,-2\ncombat,guard_max,3\ncombat,lone_far_distance,3\ncombat,lone_far_guard,0\ncombat,lone_near_distance,1\n" \
	+ "combat,lone_near_guard,-1\ncombat,lone_mid_guard,2\ncombat,hold_back_distance,2\ncombat,hold_back_penalty,1\n" \
	+ "card,hp_cost_none,3\ncard,pair_cost_cap,3\n"
const _AFF_NO_BAND: String = "affinity,delta_positive_adjacent,3\naffinity,delta_positive_far,-1\naffinity,delta_negative_adjacent,-1\naffinity,delta_negative_far,2\naffinity,delta_neutral,0\naffinity,phi_min,-4\naffinity,phi_max,12\n"

var _host_snap: CursorHostSnapshot = null


# ---- mutant 子類別(只改「有無線/極性」這一步)-----------------------------------

## 共用:把 state 轉成 link(與正式實作同形,mutant 只在 state 的取得上做手腳)。
class _Util:
	static func link_from(a: int, b: int, st: AffinityRelation.RelationState) -> Variant:
		if st == AffinityRelation.RelationState.NONE:
			return null
		var link: AffinityLink = AffinityLink.new()
		link.unit_a = a
		link.unit_b = b
		link.amp = AffinityLink.AMP_EXPECTED
		if st == AffinityRelation.RelationState.POS:
			link.polarity = AffinityLink.Polarity.POSITIVE
		else:
			link.polarity = AffinityLink.Polarity.NEGATIVE
		return link


## ① 仍以名字判定:只有「人設線」(C1_C2、C3_C4)才有線。
class _MutantNameBased extends AffinityPhiProvider:
	func _link_for_pair(a: int, b: int, pair: AffinityTypes.Pair) -> Variant:
		if pair != AffinityTypes.Pair.C1_C2 and pair != AffinityTypes.Pair.C3_C4:
			return null
		return super(a, b, pair)


## ② 忽略冷淡區:band 恆當 0。
class _MutantIgnoreBand extends AffinityPhiProvider:
	func _link_for_pair(a: int, b: int, pair: AffinityTypes.Pair) -> Variant:
		var st: AffinityRelation.RelationState = AffinityRelation.state_of(_pool, pair, 0.0)
		return _Util.link_from(a, b, st)


## ③ 快取 S:每個 pair 第一次算出的狀態永遠沿用。
class _MutantCacheState extends AffinityPhiProvider:
	var _cache: Dictionary = {}
	func _link_for_pair(a: int, b: int, pair: AffinityTypes.Pair) -> Variant:
		if not _cache.has(pair):
			_cache[pair] = AffinityRelation.state_of(_pool, pair, _state.affinity_tuning.neutral_band())
		return _Util.link_from(a, b, _cache[pair])


## ④ POS/NEG 對調。
class _MutantSwapPolarity extends AffinityPhiProvider:
	func _link_for_pair(a: int, b: int, pair: AffinityTypes.Pair) -> Variant:
		var st: AffinityRelation.RelationState = AffinityRelation.state_of(_pool, pair, _state.affinity_tuning.neutral_band())
		if st == AffinityRelation.RelationState.POS:
			st = AffinityRelation.RelationState.NEG
		elif st == AffinityRelation.RelationState.NEG:
			st = AffinityRelation.RelationState.POS
		return _Util.link_from(a, b, st)


# ---- 夾具 -------------------------------------------------------------------

func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	get_tree().paused = false


## 5 名玩家單位;單位 2、5 相鄰((0,0),(1,0)),其餘遠離。
func _state_for_pair_2_5() -> BattleState:
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,10,5",
		"2,P2,PLAYER,20,10,0,0,1,1,0,0",
		"3,P3,PLAYER,20,10,0,0,1,1,6,5",
		"4,P4,PLAYER,20,10,0,0,1,1,12,0",
		"5,P5,PLAYER,20,10,0,0,1,1,1,0",
	]
	return BattleState.create(PackedStringArray(), "\n".join(roster))


func _tuning_with_band(centi: int) -> AffinityTuning:
	return AffinityTuning.from_text(
		_OTHERS + _AFF_NO_BAND + "affinity,neutral_band_centi,%d\n" % centi) as AffinityTuning


func _write(pool: AffinityDataPool, pair: AffinityTypes.Pair, m: float) -> void:
	var r: AffinityDataPool.WriteRejection = pool.append_record(pair, m, AffinityTypes.Source.STORY_EVENT)
	if r != AffinityDataPool.WriteRejection.NONE:
		fail("fixture append_record rejected: %d" % r)


func _value_of(pool: AffinityDataPool, pair: AffinityTypes.Pair) -> float:
	return pool.combat_strength_read(pair).value


# ---- AC1:k=0 與舊規則逐位一致 -----------------------------------------------

func test_k0_links_match_legacy_sign_rule() -> void:
	var pool: AffinityDataPool = AffinityDataPool.new()
	_write(pool, AffinityTypes.Pair.C1_C2, 1.0)   # 正
	_write(pool, AffinityTypes.Pair.C2_C5, -1.0)  # 負
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(_state_for_pair_2_5(), pool)
	var polarity_by_pair: Dictionary = {}
	for link: AffinityLink in provider.links():
		polarity_by_pair["%d-%d" % [link.unit_a, link.unit_b]] = link.polarity
	assert_int(polarity_by_pair.size()).is_equal(2)  # 其餘 8 對 n==0 無線
	assert_int(polarity_by_pair["1-2"]).is_equal(AffinityLink.Polarity.POSITIVE)
	assert_int(polarity_by_pair["2-5"]).is_equal(AffinityLink.Polarity.NEGATIVE)


# ---- AC2:非人設配對有線(POS 與 NEG)------------------------------------------

## 以 provider 檢查:非人設對 C2_C5(單位 2、5 相鄰)寫正後 Φ(2) 增加 delta_positive_adjacent;寫負則 delta_negative_adjacent。
func _ac2_holds(provider: AffinityPhiProvider, pool: AffinityDataPool, state: BattleState) -> bool:
	var t: AffinityTuning = state.affinity_tuning
	var ok: bool = provider.phi_of(2) == 0
	_write(pool, AffinityTypes.Pair.C2_C5, 1.0)
	ok = ok and provider.phi_of(2) == t.delta_positive_adjacent()
	ok = ok and provider.phi_of(5) == t.delta_positive_adjacent()
	return ok


func _ac2_neg_holds(provider: AffinityPhiProvider, pool: AffinityDataPool, state: BattleState) -> bool:
	_write(pool, AffinityTypes.Pair.C2_C5, -1.0)
	return provider.phi_of(2) == state.affinity_tuning.delta_negative_adjacent()


func test_ac2_non_canon_pair_positive_contributes_adjacent_delta() -> void:
	var state: BattleState = _state_for_pair_2_5()
	var pool: AffinityDataPool = AffinityDataPool.new()
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, pool)
	assert_bool(_ac2_holds(provider, pool, state)).is_true()


func test_ac2_non_canon_pair_negative_contributes_negative_adjacent_delta() -> void:
	var state: BattleState = _state_for_pair_2_5()
	var pool: AffinityDataPool = AffinityDataPool.new()
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, pool)
	assert_bool(_ac2_neg_holds(provider, pool, state)).is_true()


# ---- AC3:冷淡區 -------------------------------------------------------------

func _ac3_holds(provider: AffinityPhiProvider, pool: AffinityDataPool, state: BattleState) -> bool:
	_write(pool, AffinityTypes.Pair.C2_C5, 1.0)
	var v: float = _value_of(pool, AffinityTypes.Pair.C2_C5)
	var centi: int = int(roundf(absf(v) * 100.0))
	# band 恰等於 |v| -> 無線;略小 -> 有線
	state.affinity_tuning = _tuning_with_band(centi)
	var ok: bool = provider.links().is_empty() and provider.phi_of(2) == 0
	state.affinity_tuning = _tuning_with_band(centi - 1)
	ok = ok and provider.links().size() == 1
	return ok


func test_ac3_neutral_band_hides_line_when_abs_value_within_k() -> void:
	var state: BattleState = _state_for_pair_2_5()
	var pool: AffinityDataPool = AffinityDataPool.new()
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, pool)
	assert_bool(_ac3_holds(provider, pool, state)).is_true()


# ---- AC4:即時讀 -------------------------------------------------------------

func _ac4_holds(provider: AffinityPhiProvider, pool: AffinityDataPool, state: BattleState) -> bool:
	_write(pool, AffinityTypes.Pair.C2_C5, 1.0)
	var before: int = provider.phi_of(2)
	_write(pool, AffinityTypes.Pair.C2_C5, -5.0)   # 翻轉為 NEG
	_write(pool, AffinityTypes.Pair.C2_C5, -5.0)
	var after: int = provider.phi_of(2)
	return before == state.affinity_tuning.delta_positive_adjacent() \
		and after == state.affinity_tuning.delta_negative_adjacent()


func test_ac4_pool_write_flipping_state_is_reflected_on_next_phi() -> void:
	var state: BattleState = _state_for_pair_2_5()
	var pool: AffinityDataPool = AffinityDataPool.new()
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, pool)
	assert_bool(_ac4_holds(provider, pool, state)).is_true()


# ---- AC5:真實場景檔 + 池寫入 → 戰鬥讀到的 Φ ----------------------------------

## 載入真實 BattleScreen.tscn(預設真實資料 vs01)。在 live 池中找一對「n==0 且相鄰」的配對
## (不寫死哪一對,避免與開局好感度記錄耦合),寫入正向記錄,斷言戰鬥自己的 _phi 讀到 +delta。
func test_ac5_real_battle_screen_phi_reflects_pool_write_for_pair_without_prior_records() -> void:
	var screen: BattleScreen = load(_SCENE_PATH).instantiate()
	auto_free(screen)
	add_child(screen)
	var pool: AffinityDataPool = screen._affinity_pool
	var phi: AffinityPhiProvider = screen._phi
	var positions: Dictionary[int, Vector2i] = phi.positions()
	var chosen: int = -1
	for p: int in range(10):
		var pair: AffinityTypes.Pair = p as AffinityTypes.Pair
		var m: Array = AffinityTypes.members_of(pair)
		var ia: int = int(m[0]) + 1
		var ib: int = int(m[1]) + 1
		if pool.combat_strength_read(pair).n_pair != 0:
			continue
		if not positions.has(ia) or not positions.has(ib):
			continue
		var d: Vector2i = positions[ia] - positions[ib]
		if absi(d.x) + absi(d.y) == 1:
			chosen = p
			break
	assert_int(chosen).append_failure_message("PRECONDITION: 找到 n==0 且相鄰的配對").is_not_equal(-1)
	var pair_c: AffinityTypes.Pair = chosen as AffinityTypes.Pair
	var members: Array = AffinityTypes.members_of(pair_c)
	var id_a: int = int(members[0]) + 1
	var before: int = phi.phi_of(id_a)
	_write(pool, pair_c, 1.0)
	var after: int = phi.phi_of(id_a)
	var delta_pos: int = screen._state.affinity_tuning.delta_positive_adjacent()
	assert_int(after - before).is_equal(delta_pos)


# ---- AC6:敏感度證明(常駐;每個 mutant 被同一檢查器判為不通過)------------------

func _run_check(provider: AffinityPhiProvider, state: BattleState, pool: AffinityDataPool, which: String) -> bool:
	match which:
		"ac2": return _ac2_holds(provider, pool, state)
		"ac2neg": return _ac2_neg_holds(provider, pool, state)
		"ac3": return _ac3_holds(provider, pool, state)
		"ac4": return _ac4_holds(provider, pool, state)
	return false


func _mutant_fails(mutant_script: Script, which: String) -> bool:
	var state: BattleState = _state_for_pair_2_5()
	var pool: AffinityDataPool = AffinityDataPool.new()
	var provider: AffinityPhiProvider = mutant_script.new(state, pool)
	return not _run_check(provider, state, pool, which)


func _real_passes(which: String) -> bool:
	var state: BattleState = _state_for_pair_2_5()
	var pool: AffinityDataPool = AffinityDataPool.new()
	return _run_check(AffinityPhiProvider.new(state, pool), state, pool, which)


func test_sensitivity_proof_real_implementation_passes_all_checks() -> void:
	for which: String in ["ac2", "ac2neg", "ac3", "ac4"]:
		assert_bool(_real_passes(which)).append_failure_message(which).is_true()


func test_sensitivity_proof_name_based_mutant_fails_ac2() -> void:
	assert_bool(_mutant_fails(_MutantNameBased, "ac2")).is_true()


func test_sensitivity_proof_ignore_neutral_band_mutant_fails_ac3() -> void:
	assert_bool(_mutant_fails(_MutantIgnoreBand, "ac3")).is_true()


func test_sensitivity_proof_cached_state_mutant_fails_ac4() -> void:
	assert_bool(_mutant_fails(_MutantCacheState, "ac4")).is_true()


func test_sensitivity_proof_swapped_polarity_mutant_fails_ac2() -> void:
	assert_bool(_mutant_fails(_MutantSwapPolarity, "ac2")).is_true()
