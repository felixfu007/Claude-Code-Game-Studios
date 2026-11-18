# AffinityRelation.state_of(pool, pair, neutral_band) 的單元測試
# (production/epics/skill-card-system/story-012-relation-state-of-pair.md)。
#
# 檔案存取:無(全部用記憶體內的 AffinityDataPool / 內嵌字串)。
#
# 敏感度證明(test_sensitivity_proof_*):state_of 是 static 純函式,無法繼承覆寫
# (test-standards 的 A 類),所以改為「檢查器敏感度」—— 每個 AC 的斷言被收成一個
# 接受 Callable(pool, pair, band) -> int 的檢查器,真品通過、每個植入缺陷的 mutant
# 副本必被同一個檢查器判為不通過。證明的是「這些斷言抓得到這種缺陷」。
#
# 🔴 mutant ②(忽略 n==0)不可證:池在 n==0 時 value 恆為 0.0,而 k>=0 時
# |0.0|<=k 本來就判 NONE,故「忽略 n==0」與正確實作輸出逐位相同,任何斷言都區分不了。
# n==0 的行為仍有直接斷言(AC1),只是沒有對應的 mutant 證明。
extends GdUnitTestSuite

const _PAIR_COUNT: int = 10
const _NONE: int = AffinityRelation.RelationState.NONE
const _POS: int = AffinityRelation.RelationState.POS
const _NEG: int = AffinityRelation.RelationState.NEG

const _OTHERS: String = "deck,opening_hand_size,5\ndeck,hand_size_limit,5\ndeck,cards_drawn_per_turn,1\n" \
	+ "card_modifier,atk_delta_min,-4\ncard_modifier,atk_delta_max,6\ncard_modifier,def_delta_min,-3\ncard_modifier,def_delta_max,4\n" \
	+ "combat,guard_min,-2\ncombat,guard_max,3\ncombat,lone_far_distance,3\ncombat,lone_far_guard,0\ncombat,lone_near_distance,1\n" \
	+ "combat,lone_near_guard,-1\ncombat,lone_mid_guard,2\ncombat,hold_back_distance,2\ncombat,hold_back_penalty,1\ncard,hp_cost_none,3\ncard,pair_cost_cap,3\n"
const _AFF_NO_BAND: String = "affinity,delta_positive_adjacent,3\naffinity,delta_positive_far,-1\naffinity,delta_negative_adjacent,-1\naffinity,delta_negative_far,2\naffinity,delta_neutral,0\naffinity,phi_min,-4\naffinity,phi_max,12\naffinity,phi_loss_positive,2\naffinity,phi_loss_negative,1\n"


# ---- 夾具 -------------------------------------------------------------------

func _pool_with(entries: Dictionary) -> AffinityDataPool:
	var pool: AffinityDataPool = AffinityDataPool.new()
	for pair: AffinityTypes.Pair in entries:
		for m: float in entries[pair]:
			_write(pool, pair, m)
	return pool


func _write(pool: AffinityDataPool, pair: AffinityTypes.Pair, m: float) -> void:
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(
		pair, m, AffinityTypes.Source.STORY_EVENT
	)
	if rejection != AffinityDataPool.WriteRejection.NONE:
		fail("fixture append_record rejected: %d" % rejection)


func _pair(i: int) -> AffinityTypes.Pair:
	return i as AffinityTypes.Pair


## 5 名玩家單位(roster id 1~5,對應 CHARACTER_1~5),各佔一格。
func _provider_for(pool: AffinityDataPool) -> AffinityPhiProvider:
	var roster: Array[String] = []
	for i in range(1, 6):
		roster.append("%d,P%d,PLAYER,20,10,0,0,1,1,%d,0" % [i, i, i])
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	return AffinityPhiProvider.new(state, pool)


func _legacy_state(provider: AffinityPhiProvider, pair: AffinityTypes.Pair) -> int:
	var members: Array = AffinityTypes.members_of(pair)
	var id_a: int = int(members[0]) + 1
	var id_b: int = int(members[1]) + 1
	for link: AffinityLink in provider.links():
		if link.unit_a == id_a and link.unit_b == id_b:
			if link.polarity == AffinityLink.Polarity.POSITIVE:
				return _POS
			return _NEG
	return _NONE


# ---- 檢查器(真品與 mutant 共用)---------------------------------------------

## AC1:四條判定與兩個邊界。fn: Callable(pool, pair, band) -> int。
func _ac1_holds(fn: Callable) -> bool:
	var p: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	var ok: bool = true
	# n==0 -> NONE(k=0 與 k=0.5 都是)
	ok = ok and fn.call(_pool_with({}), p, 0.0) == _NONE
	ok = ok and fn.call(_pool_with({}), p, 0.5) == _NONE
	# k=0:正 -> POS,負 -> NEG
	ok = ok and fn.call(_pool_with({p: [1.0]}), p, 0.0) == _POS
	ok = ok and fn.call(_pool_with({p: [-1.0]}), p, 0.0) == _NEG
	# n>0 的小淨值(衰減使 [1,-1] 不會相消;值由池當場讀出,不寫死):
	# band 恰等於 |v| -> NONE(邊界),略小於 |v| -> 依符號判定
	var mixed: AffinityDataPool = _pool_with({p: [1.0, -1.0]})
	var mv: float = _value_of(mixed, p)
	ok = ok and mv != 0.0
	var outside: int = _POS if mv > 0.0 else _NEG
	ok = ok and fn.call(mixed, p, absf(mv)) == _NONE
	ok = ok and fn.call(mixed, p, absf(mv) * 0.5) == outside
	# k=0.5:冷淡區內、邊界(v==k、v==-k 皆 NONE)、區外
	ok = ok and fn.call(_pool_with({p: [0.25]}), p, 0.5) == _NONE
	ok = ok and fn.call(_pool_with({p: [0.5]}), p, 0.5) == _NONE
	ok = ok and fn.call(_pool_with({p: [-0.5]}), p, 0.5) == _NONE
	ok = ok and fn.call(_pool_with({p: [0.75]}), p, 0.5) == _POS
	ok = ok and fn.call(_pool_with({p: [-0.75]}), p, 0.5) == _NEG
	return ok


## AC2:10 組各以同一函式判定,同樣的池內容得到同樣的狀態(與名字無關)。
func _ac2_holds(fn: Callable) -> bool:
	for i in range(_PAIR_COUNT):
		var p: AffinityTypes.Pair = _pair(i)
		if fn.call(_pool_with({p: [1.0]}), p, 0.0) != _POS:
			return false
		if fn.call(_pool_with({p: [-1.0]}), p, 0.0) != _NEG:
			return false
		if fn.call(_pool_with({}), p, 0.0) != _NONE:
			return false
	return true


## AC3 的 k 敏感部分:呼叫端傳入的 band 必須被使用(k=0 時 0.3 即 POS)。
func _ac3_k_is_honoured(fn: Callable) -> bool:
	var p: AffinityTypes.Pair = AffinityTypes.Pair.C2_C5
	return fn.call(_pool_with({p: [0.3]}), p, 0.0) == _POS \
		and fn.call(_pool_with({p: [0.3]}), p, 0.4) == _NONE


## AC4:同一池連續兩次寫入、各查一次,結果即時反映。
func _ac4_holds(fn: Callable) -> bool:
	var p: AffinityTypes.Pair = AffinityTypes.Pair.C3_C4
	var pool: AffinityDataPool = _pool_with({})
	var s0: int = fn.call(pool, p, 0.0)
	_write(pool, p, 1.0)
	var s1: int = fn.call(pool, p, 0.0)
	_write(pool, p, -3.0)
	var s2: int = fn.call(pool, p, 0.0)
	return s0 == _NONE and s1 == _POS and s2 == _NEG


func _all_hold(fn: Callable) -> bool:
	return _ac1_holds(fn) and _ac2_holds(fn) and _ac3_k_is_honoured(fn) and _ac4_holds(fn)


# ---- mutant 實作 --------------------------------------------------------------

func _real(pool: AffinityDataPool, pair: AffinityTypes.Pair, band: float) -> int:
	return AffinityRelation.state_of(pool, pair, band)


func _value_of(pool: AffinityDataPool, pair: AffinityTypes.Pair) -> float:
	return pool.combat_strength_read(pair).value


func _mut_strict_less(pool: AffinityDataPool, pair: AffinityTypes.Pair, band: float) -> int:
	var v: float = _value_of(pool, pair)
	if v > band:
		return _POS
	if v < -band:
		return _NEG
	if v == band and band > 0.0:
		return _POS  # 冷淡區用 < 而非 <=:v==k 落到區外
	return _NONE


func _mut_swapped_sign(pool: AffinityDataPool, pair: AffinityTypes.Pair, band: float) -> int:
	var s: int = AffinityRelation.state_of(pool, pair, band)
	if s == _POS:
		return _NEG
	if s == _NEG:
		return _POS
	return s


func _mut_name_branch(pool: AffinityDataPool, pair: AffinityTypes.Pair, band: float) -> int:
	if pair == AffinityTypes.Pair.C1_C2:
		return _POS
	return AffinityRelation.state_of(pool, pair, band)


func _mut_hardcoded_band(pool: AffinityDataPool, pair: AffinityTypes.Pair, _band: float) -> int:
	return AffinityRelation.state_of(pool, pair, 0.5)


func _make_caching_mutant() -> Callable:
	var cache: Dictionary = {}
	return func(pool: AffinityDataPool, pair: AffinityTypes.Pair, band: float) -> int:
		if not cache.has(pair):
			cache[pair] = AffinityRelation.state_of(pool, pair, band)
		return cache[pair]


# ---- AC1 / AC2 / AC3 / AC4 / AC6 ------------------------------------------------

func test_relation_ac1_four_rules_and_boundaries() -> void:
	assert_bool(_ac1_holds(_real)).is_true()


func test_relation_ac2_ten_pairs_same_function_regardless_of_names() -> void:
	assert_bool(_ac2_holds(_real)).is_true()
	# 麥子健(CHARACTER_5)配對與非人設配對各有專條斷言
	var with_maizi: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_5)
	var non_canon: AffinityTypes.Pair = AffinityTypes.Pair.C2_C4
	var pool: AffinityDataPool = _pool_with({with_maizi: [2.0], non_canon: [-2.0]})
	assert_int(AffinityRelation.state_of(pool, with_maizi, 0.0)).is_equal(_POS)
	assert_int(AffinityRelation.state_of(pool, non_canon, 0.0)).is_equal(_NEG)


func test_relation_ac3_k_zero_matches_legacy_links_for_every_pair_and_pool_state() -> void:
	var pools: Array[AffinityDataPool] = [
		_pool_with({}),
		_pool_with({AffinityTypes.Pair.C1_C2: [1.0], AffinityTypes.Pair.C3_C4: [-1.0]}),
		_pool_with({AffinityTypes.Pair.C1_C2: [1.0, -1.0]}),
		_pool_with({AffinityTypes.Pair.C1_C5: [0.3], AffinityTypes.Pair.C2_C3: [-0.3, 2.0, -1.0]}),
		_pool_with({AffinityTypes.Pair.C4_C5: [-1.0, -1.0, 5.0], AffinityTypes.Pair.C1_C3: [1.0, 1.0, -9.0]}),
	]
	var compared: int = 0
	for pool: AffinityDataPool in pools:
		var provider: AffinityPhiProvider = _provider_for(pool)
		for p in range(_PAIR_COUNT):
			var expected: int = _legacy_state(provider, _pair(p))
			var actual: int = AffinityRelation.state_of(pool, _pair(p), 0.0)
			assert_int(actual).is_equal(expected)
			compared += 1
	assert_int(compared).is_equal(5 * _PAIR_COUNT)
	assert_bool(_ac3_k_is_honoured(_real)).is_true()


func test_relation_ac4_reads_live_without_caching() -> void:
	assert_bool(_ac4_holds(_real)).is_true()


func test_relation_ac6_read_only_pool_unchanged() -> void:
	var p: AffinityTypes.Pair = AffinityTypes.Pair.C1_C3
	var pool: AffinityDataPool = _pool_with({p: [1.0, 2.0], AffinityTypes.Pair.C2_C3: [-1.0]})
	var before: Array = []
	for i in range(_PAIR_COUNT):
		var r: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(_pair(i))
		var n: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(_pair(i))
		before.append([r.n_pair, r.value, n.value, r.t_query])
	for i in range(_PAIR_COUNT):
		AffinityRelation.state_of(pool, _pair(i), 0.0)
		AffinityRelation.state_of(pool, _pair(i), 0.5)
	for i in range(_PAIR_COUNT):
		var r: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(_pair(i))
		var n: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(_pair(i))
		assert_array([r.n_pair, r.value, n.value, r.t_query]).is_equal(before[i])


# ---- AC5 旋鈕載入 -------------------------------------------------------------------
# 註:既有 TuningKnobs 一律嚴格 —— 缺鍵即整份載入失敗(回 null + push_error),
# 不是工單 AC5 原文的「缺鍵 -> k=0 + push_warning」。依既有規則照辦,回報已揭露。

func test_relation_ac5_band_comes_from_data_file() -> void:
	var t: AffinityTuning = AffinityTuning.from_text(
		_OTHERS + _AFF_NO_BAND + "affinity,neutral_band_centi,50\n") as AffinityTuning
	assert_float(t.neutral_band()).is_equal(0.5)
	assert_int(t.neutral_band_centi()).is_equal(50)
	var zero: AffinityTuning = AffinityTuning.from_text(
		_OTHERS + _AFF_NO_BAND + "affinity,neutral_band_centi,0\n") as AffinityTuning
	assert_float(zero.neutral_band()).is_equal(0.0)
	assert_float(AffinityTuning.defaults().neutral_band()).is_equal(0.0)


func test_relation_ac5_missing_key_fails_load_loudly() -> void:
	var result: Array = [AffinityTuning.defaults()]
	await assert_error(func() -> void: result[0] = AffinityTuning.from_text(_OTHERS + _AFF_NO_BAND)) \
		.is_push_error("TuningKnobs.from_text: missing required key 'affinity.neutral_band_centi'")
	assert_bool(result[0] == null).is_true()


func test_relation_ac5_non_integer_rejected() -> void:
	var result: Array = [AffinityTuning.defaults()]
	await assert_error(func() -> void: result[0] = AffinityTuning.from_text(
			_OTHERS + _AFF_NO_BAND + "affinity,neutral_band_centi,2.5\n")) \
		.is_push_error("TuningKnobs.from_text: line 28: value '2.5' is not an integer")
	assert_bool(result[0] == null).is_true()


func test_relation_ac5_negative_band_rejected() -> void:
	var result: Array = [AffinityTuning.defaults()]
	await assert_error(func() -> void: result[0] = AffinityTuning.from_text(
			_OTHERS + _AFF_NO_BAND + "affinity,neutral_band_centi,-5\n")) \
		.is_push_error("AffinityTuning: affinity.neutral_band_centi (-5) must be >= 0")
	assert_bool(result[0] == null).is_true()


func test_relation_ac5_shipped_data_file_band_is_zero() -> void:
	# 甲類例外:唯讀 assets/data/tuning/tuning_knobs.txt(已進版控),量測前 k 必為 0。
	var text: String = FileAccess.get_file_as_string("res://assets/data/tuning/tuning_knobs.txt")
	var t: AffinityTuning = AffinityTuning.from_text(text) as AffinityTuning
	assert_bool(t != null).is_true()
	assert_int(t.neutral_band_centi()).is_equal(0)


# ---- AC7 敏感度證明(常駐)-------------------------------------------------------------

func test_sensitivity_proof_real_implementation_passes_all_checkers() -> void:
	assert_bool(_all_hold(_real)).is_true()


func test_sensitivity_proof_strict_less_than_boundary_is_caught_by_ac1() -> void:
	assert_bool(_ac1_holds(_mut_strict_less)).is_false()


func test_sensitivity_proof_swapped_sign_is_caught_by_ac1() -> void:
	assert_bool(_ac1_holds(_mut_swapped_sign)).is_false()


func test_sensitivity_proof_name_branch_is_caught_by_ac2() -> void:
	assert_bool(_ac2_holds(_mut_name_branch)).is_false()


func test_sensitivity_proof_cached_first_result_is_caught_by_ac4() -> void:
	assert_bool(_ac4_holds(_make_caching_mutant())).is_false()


func test_sensitivity_proof_hardcoded_band_is_caught_by_ac3() -> void:
	assert_bool(_ac3_k_is_honoured(_mut_hardcoded_band)).is_false()
