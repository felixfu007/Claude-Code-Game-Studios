## campaign_affinity_pool_rebuilder_test.gd
##
## 實作依據:production/epics/campfire/story-001-ledger-to-pool-rebuild-shared.md
## AC1(三組配對、正負混合、多筆;含麥子健=CHARACTER_5 的配對、含非人設配對)、
## AC2(空累積記錄 -> 10 組全 n_pair==0、state_of 全 NONE)。
##
## 檔案存取:無(純記憶體)。
##
## 期望值的來源:n_pair 為手寫的筆數;value 與「直接對一個新池逐筆 append_record」
## 的結果比對 —— 受測的只有「重播迴圈」,池本身的加權公式不在本檔範圍
## (affinity_data_pool_*_test.gd 負責)。
##
## 敏感度證明:被測的是 static 純函式,無繼承鏈可覆寫(test-standards.md 的 A 類
## 「證明不了」)。常駐的 test_sensitivity_proof_* 只能證明「AC1 的比對偵測得出
## 少一筆」,證不了函式本體;函式本體的 mutant(漏掉最後一筆)已於交付時手動
## 注入執行並貼出紅燈原始輸出(見交付回報),不在版本庫留痕。
extends GdUnitTestSuite

const _NEUTRAL_BAND: float = 0.0


func _make_ledger() -> CampaignAffinityLedger:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	# C1_C2:人設配對,3 筆,正負混合
	ledger.append(AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.STORY_EVENT)
	ledger.append(AffinityTypes.Pair.C1_C2, 2.0, AffinityTypes.Source.COMBAT_CARD)
	ledger.append(AffinityTypes.Pair.C1_C2, -0.5, AffinityTypes.Source.SUPPORT_CONVERSATION)
	# C3_C4:人設配對,2 筆,偏負
	ledger.append(AffinityTypes.Pair.C3_C4, -1.0, AffinityTypes.Source.STORY_EVENT)
	ledger.append(AffinityTypes.Pair.C3_C4, -2.0, AffinityTypes.Source.COMBAT_CARD)
	# C2_C5:含麥子健(CHARACTER_5)、非人設配對,1 筆,正 —— 刻意放在最後一筆
	ledger.append(AffinityTypes.Pair.C2_C5, 1.5, AffinityTypes.Source.COMBAT_CARD)
	return ledger


func _reference_pool(entries: Array) -> AffinityDataPool:
	var pool: AffinityDataPool = AffinityDataPool.new()
	for entry: CampaignAffinityLedger.Entry in entries:
		pool.append_record(entry.pair, entry.m, entry.source)
	return pool


func test_rebuild_three_pairs_mixed_signs_matches_per_record_accumulation() -> void:
	# Arrange
	var ledger: CampaignAffinityLedger = _make_ledger()
	var reference: AffinityDataPool = _reference_pool(ledger.records())

	# Act
	var pool: AffinityDataPool = CampaignAffinityPoolRebuilder.rebuild(ledger)

	# Assert
	var expected_n: Dictionary = {
		AffinityTypes.Pair.C1_C2: 3,
		AffinityTypes.Pair.C3_C4: 2,
		AffinityTypes.Pair.C2_C5: 1,
	}
	for pair: AffinityTypes.Pair in expected_n:
		var got: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
		var want: AffinityDataPool.AffinityReadResult = reference.combat_strength_read(pair)
		assert_int(got.n_pair).is_equal(expected_n[pair])
		assert_float(got.value).is_equal(want.value)
	assert_int(
		AffinityRelation.state_of(pool, AffinityTypes.Pair.C1_C2, _NEUTRAL_BAND)
	).is_equal(AffinityRelation.RelationState.POS)
	assert_int(
		AffinityRelation.state_of(pool, AffinityTypes.Pair.C3_C4, _NEUTRAL_BAND)
	).is_equal(AffinityRelation.RelationState.NEG)
	assert_int(
		AffinityRelation.state_of(pool, AffinityTypes.Pair.C2_C5, _NEUTRAL_BAND)
	).is_equal(AffinityRelation.RelationState.POS)


func test_rebuild_untouched_pairs_stay_empty() -> void:
	# Arrange / Act
	var pool: AffinityDataPool = CampaignAffinityPoolRebuilder.rebuild(_make_ledger())

	# Assert
	assert_int(pool.combat_strength_read(AffinityTypes.Pair.C1_C3).n_pair).is_equal(0)
	assert_int(pool.combat_strength_read(AffinityTypes.Pair.C4_C5).n_pair).is_equal(0)


func test_rebuild_empty_ledger_all_ten_pairs_none() -> void:
	# Arrange
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()

	# Act
	var pool: AffinityDataPool = CampaignAffinityPoolRebuilder.rebuild(ledger)

	# Assert
	var pairs: Array = AffinityTypes.Pair.values()
	assert_int(pairs.size()).is_equal(10)
	for pair: AffinityTypes.Pair in pairs:
		assert_int(pool.combat_strength_read(pair).n_pair).is_equal(0)
		assert_int(AffinityRelation.state_of(pool, pair, _NEUTRAL_BAND)).is_equal(
			AffinityRelation.RelationState.NONE
		)


func test_rebuild_returns_fresh_pool_each_call() -> void:
	# Arrange
	var ledger: CampaignAffinityLedger = _make_ledger()

	# Act
	var a: AffinityDataPool = CampaignAffinityPoolRebuilder.rebuild(ledger)
	var b: AffinityDataPool = CampaignAffinityPoolRebuilder.rebuild(ledger)

	# Assert
	assert_bool(a == b).is_false()
	assert_int(b.combat_strength_read(AffinityTypes.Pair.C1_C2).n_pair).is_equal(3)


## 只證明「AC1 的比對偵測得出少一筆」,不證明函式本體(見檔頭)。
func test_sensitivity_proof_ac1_comparison_detects_a_dropped_last_record() -> void:
	# Arrange
	var ledger: CampaignAffinityLedger = _make_ledger()
	var entries: Array = ledger.records()
	entries.pop_back()
	var truncated: AffinityDataPool = _reference_pool(entries)

	# Act
	var full: AffinityDataPool = CampaignAffinityPoolRebuilder.rebuild(ledger)

	# Assert
	var c2c5: AffinityTypes.Pair = AffinityTypes.Pair.C2_C5
	assert_int(truncated.combat_strength_read(c2c5).n_pair).is_equal(0)
	assert_int(full.combat_strength_read(c2c5).n_pair).is_equal(1)
