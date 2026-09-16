# AffinityDataPool(src/gameplay/affinity_pool/affinity_data_pool.gd)公式一
# (戰鬥強度讀取)/公式二(敘事深度讀取)加權計算單元測試。
#
# Story:production/epics/affinity-data-pool/story-007-weighted-reads.md(S-007)
# 涵蓋 AC-3、AC-5、AC-6、AC-9、AC-11、AC-12、AC-13、AC-15、AC-16、AC-17、AC-18、
# AC-25、AC-31、AC-32、AC-33、AC-34、AC-35(范围限定,見下)、AC-55、AC-62
# (范围限定,見下)、AC-75。
#
# 🔴 λ_combat/λ_narrative/α 的取得(2026-09-16 technical-director 裁決,
# `AffinityCalibration`,見 affinity_data_pool.gd 對 [member _calibration] 的
# 文件註解與 affinity_calibration.gd 檔頭)——本檔一律以
# [method AffinityCalibration.create] 建構一份校準,經 [method AffinityDataPool._init]
# 建構期注入,不使用池上任何可寫欄位(池本身沒有這種欄位)。賦值的數值是測試
# 情境需要的任意合法值,不代表任何已定案的遊戲校準數字(校準數字本身留待
# playtest,Story Out of Scope 明文排除)。[method _make_calibration] 為本檔的
# 白箱輔助,固定填入本檔不使用的 Q/n_min_segment/M 三個旋鈕任意合法值
# (S-010/S-011 範圍)。
#
# 🔴 AC-35 陷阱的處置(工作單明文提醒):S-006 交付的佔位骨架對「所有」合法輸入
# 皆無條件回傳 n_pair=0,若沿用該骨架驗證 AC-35,測不出任何真實邏輯。本檔對
# combat_strength_read/narrative_depth_read 兩個分支建構了真正帶記錄的情境
# (最早記錄 t_i=20,查詢 t_query=10),使 n_pair=0 是「真實過濾後算出的 0」,
# 不是「佔位值恰好也是 0」。shape_feature_read 分支本 story 未觸碰公式三計算
# 本身(S-010/S-011 範圍),此處驗證的是 S-006 既有骨架不受本 story 影響,見
# 該測試內的範圍註解。
#
# 🔴 AC-62 範圍限定(轉錄自工作單):本檔只驗證 combat_strength_read/
# narrative_depth_read 兩者的凍結行為;shape_feature_read 對應分支(七項特徵
# 是否反映死後追憶)屬 S-010/S-011,本檔不驗證。
#
# 白箱輔助:`_inject_raw_record()` 直接建構 AffinityRecord 並附加進
# `pool._records[pair]`,繞過 append_record() 的自動遞增 t_i 機制——用於需要
# 精確控制歷史 t_i 值的情境(GDD 逐字範例 AC-12/13、AC-9 的兩筆任意 t_i、
# AC-34/35 的歷史 t_query 邊界)。若改用連續呼叫 append_record() 逼近同樣的
# t_i 分布,需要插入大量無關填充寫入,測試意圖會被稀釋。此輔助函式不遞增
# pool._t_now,呼叫端須自行視需要另外設定(白箱慣例,同 read_gate_test.gd/
# death_marks_test.gd 既有先例)。
#
# 純資料結構與純函式、無節點——不建立任何 Node,不需要 tear-down,不會留下孤兒
# 節點。每個測試自成一組斷言,彼此不共用可變狀態、不依賴執行順序。
extends GdUnitTestSuite


## 白箱測試輔助——建構一份 [AffinityCalibration],指定本檔測試實際會用到的
## λ_combat/λ_narrative/α 三個旋鈕;Q/n_min_segment/M 固定填入任意合法值
## (本檔任何測試皆不使用它們,屬 S-010/S-011 範圍,shape_feature_read 本 story
## 未觸碰)。呼叫端須自行確認回傳物件 rejection == NONE(本檔挑選的數值皆落在
## 合法範圍內,不測試 AffinityCalibration.create() 自身的拒絕路徑——那不是
## 本檔的驗收範圍)。
func _make_calibration(
	lambda_combat: float, lambda_narrative: float, alpha: float
) -> AffinityCalibration:
	return AffinityCalibration.create(lambda_combat, lambda_narrative, alpha, 4, 8, 5)


func _inject_raw_record(
	pool: AffinityDataPool,
	pair: AffinityTypes.Pair,
	m: float,
	t: int,
	source: AffinityTypes.Source = AffinityTypes.Source.SUPPORT_CONVERSATION
) -> void:
	var record := AffinityRecord.new()
	record.pair = pair
	record.m = m
	record.t = t
	record.c = 0
	record.source = source
	pool._records[pair].append(record)


## 白箱輔助:對 [param exclude_pair] 以外的其他配對輪流寫入 [param count] 筆
## 記錄,用於推進全域計數器而不影響被排除的配對。
func _advance_other_pairs(
	pool: AffinityDataPool, exclude_pair: AffinityTypes.Pair, count: int
) -> void:
	var other_pairs: Array = []
	for p: AffinityTypes.Pair in AffinityTypes.Pair.values():
		if p != exclude_pair:
			other_pairs.append(p)
	for i in range(count):
		var target_pair: AffinityTypes.Pair = other_pairs[i % other_pairs.size()]
		pool.append_record(target_pair, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)


# ---- AC-3:純讀取不推進全域計數器 -------------------------------------------

func test_combat_strength_read_does_not_advance_t_now() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	pool.append_record(pair, 3.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	var t_now_before: int = pool._t_now

	# Act — 連續呼叫 3 次純讀取
	var result1: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
	var result2: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
	var result3: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)

	# Assert — 全域計數器全程不變,三次呼叫的 t_query/n_pair 完全相同
	assert_int(pool._t_now).is_equal(t_now_before)
	for result: AffinityDataPool.AffinityReadResult in [result1, result2, result3]:
		assert_int(result.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
		assert_int(result.t_query).is_equal(t_now_before)
		assert_int(result.n_pair).is_equal(1)


# ---- AC-5:age 因其他配對的活動而增長 ----------------------------------------

func test_age_grows_from_other_pairs_activity() -> void:
	# Arrange — 配對 B(C1_C2)於 t=1 寫入,其後配對 A(C3_C4,與 B 無共用角色)
	# 接續 4 筆寫入,將全域計數器推進至 t=5,期間 B 未再被寫入
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	var pair_b: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	var pair_a: AffinityTypes.Pair = AffinityTypes.Pair.C3_C4
	pool.append_record(pair_b, 5.0, AffinityTypes.Source.SUPPORT_CONVERSATION)  # t=1
	for i in range(4):
		pool.append_record(pair_a, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)  # t=2..5

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair_b)

	# Assert — age = 5-1 = 4(而非 0),讀值 = 5 × 0.9^4
	assert_int(pool._t_now).is_equal(5)
	assert_int(result.t_query).is_equal(5)
	var expected: float = 5.0 * pow(0.9, 4)
	assert_float(result.value).is_equal_approx(expected, 0.000000001)


# ---- AC-6:n(p) 與 t_now 是兩個獨立追蹤的量 ----------------------------------

func test_n_pair_independent_of_t_now() -> void:
	# Arrange — 同 AC-5 情境
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	var pair_b: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	var pair_a: AffinityTypes.Pair = AffinityTypes.Pair.C3_C4
	pool.append_record(pair_b, 5.0, AffinityTypes.Source.SUPPORT_CONVERSATION)  # t=1
	for i in range(4):
		pool.append_record(pair_a, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)  # t=2..5

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair_b)

	# Assert — n(p)=1,即使 t_now 已推進到 5
	assert_int(pool._t_now).is_equal(5)
	assert_int(result.n_pair).is_equal(1)


# ---- AC-9:λ=1 精確抵銷,下游須以 n(p) 判斷有無資料 ---------------------------

func test_lambda_one_exact_cancellation_with_n_pair_two() -> void:
	# Arrange — 兩筆記錄:(m=+5,t=10)、(m=-5,t=20),λ_combat=1.0(合法邊界)
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(1.0, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	_inject_raw_record(pool, pair, 5.0, 10)
	_inject_raw_record(pool, pair, -5.0, 20)
	pool._t_now = 20

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)

	# Assert — 讀值精確等於 0,n(p)=2
	assert_float(result.value).is_equal_approx(0.0, 0.000000001)
	assert_int(result.n_pair).is_equal(2)


# ---- AC-11:combat_strength_read 對來源不敏感 --------------------------------

func test_combat_strength_read_insensitive_to_source() -> void:
	# Arrange — 兩份 pair/m_i/t_i 完全相同的記錄集合,唯一差異是 source
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2

	var pool_cc: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	_inject_raw_record(pool_cc, pair, 2.0, 5, AffinityTypes.Source.COMBAT_CARD)
	_inject_raw_record(pool_cc, pair, -3.0, 8, AffinityTypes.Source.COMBAT_CARD)
	pool_cc._t_now = 10

	var pool_sc: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	_inject_raw_record(pool_sc, pair, 2.0, 5, AffinityTypes.Source.SUPPORT_CONVERSATION)
	_inject_raw_record(pool_sc, pair, -3.0, 8, AffinityTypes.Source.SUPPORT_CONVERSATION)
	pool_sc._t_now = 10

	# Act
	var result_cc: AffinityDataPool.AffinityReadResult = pool_cc.combat_strength_read(pair)
	var result_sc: AffinityDataPool.AffinityReadResult = pool_sc.combat_strength_read(pair)

	# Assert — 兩者回傳數值相同(誤差 <1e-9)
	assert_float(result_cc.value).is_equal_approx(result_sc.value, 0.000000001)


# ---- AC-12:GDD 逐字工作範例(敘事深度讀取) ----------------------------------

func test_narrative_depth_read_matches_worked_example() -> void:
	# Arrange — GDD Formulas 範例:三筆記錄,查詢於 t_now=42,λ_narrative=0.9,α=0.3
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	_inject_raw_record(pool, pair, 2.0, 10, AffinityTypes.Source.COMBAT_CARD)
	_inject_raw_record(pool, pair, -1.0, 25, AffinityTypes.Source.SUPPORT_CONVERSATION)
	_inject_raw_record(pool, pair, 1.0, 40, AffinityTypes.Source.STORY_EVENT)
	pool._t_now = 42

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(pair)

	# Assert — GDD 範例值 ≈0.664(誤差 ±0.01)
	assert_float(result.value).is_equal_approx(0.664, 0.01)


# ---- AC-13:同一份記錄,combat_strength_read 不因來源打折 --------------------

func test_combat_strength_read_matches_worked_example_same_records() -> void:
	# Arrange — 沿用 AC-12 同一份記錄集合
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	_inject_raw_record(pool, pair, 2.0, 10, AffinityTypes.Source.COMBAT_CARD)
	_inject_raw_record(pool, pair, -1.0, 25, AffinityTypes.Source.SUPPORT_CONVERSATION)
	_inject_raw_record(pool, pair, 1.0, 40, AffinityTypes.Source.STORY_EVENT)
	pool._t_now = 42

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)

	# Assert — GDD 範例值 ≈0.712(誤差 ±0.01),對照 AC-12 的 0.664
	assert_float(result.value).is_equal_approx(0.712, 0.01)


# ---- AC-15:0^0:=1 慣例(戰鬥端) ---------------------------------------------

func test_zero_zero_convention_combat() -> void:
	# Arrange — 單筆記錄,age=0(t_i == t_now),λ_combat=0
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.0, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	_inject_raw_record(pool, pair, 2.0, 7)
	pool._t_now = 7

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)

	# Assert — 回傳值精確等於 2,不因 0^0 被引擎預設當作 0 而回傳 0
	assert_float(result.value).is_equal_approx(2.0, 0.000000001)
	assert_int(result.n_pair).is_equal(1)


# ---- AC-16:λ=1 無界線性成長(戰鬥端) ----------------------------------------

func test_lambda_one_unbounded_linear_growth_combat() -> void:
	# Arrange — λ_combat=1(合法邊界值)
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(1.0, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2

	# Act — 連續寫入 100 筆記錄(每筆 m=+2)後立即查詢
	for i in range(100):
		pool.append_record(pair, 2.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	var result_100: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)

	# Assert — 精確等於 200,不拋出例外、不產生 NaN/Infinity
	assert_float(result_100.value).is_equal_approx(200.0, 0.000000001)
	assert_bool(is_nan(result_100.value)).is_false()
	assert_bool(is_inf(result_100.value)).is_false()

	# Act — 再寫入 100 筆(共 200 筆)後重新查詢
	for i in range(100):
		pool.append_record(pair, 2.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	var result_200: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)

	# Assert — 精確等於 400
	assert_float(result_200.value).is_equal_approx(400.0, 0.000000001)


# ---- AC-17:λ<1 收斂至穩態(戰鬥端) ------------------------------------------

func test_lambda_less_than_one_converges_to_steady_state_combat() -> void:
	# Arrange — λ_combat=0.9
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2

	# Act — 連續寫入 100 筆記錄(每筆 m=+2)後立即查詢
	for i in range(100):
		pool.append_record(pair, 2.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	var result_100: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)

	# Assert — 落在封閉解 r/(1-λ)=2/(1-0.9)=20 的 ±0.01 範圍內
	assert_float(result_100.value).is_equal_approx(20.0, 0.01)

	# Act — 再寫入 100 筆(共 200 筆)後重新查詢
	for i in range(100):
		pool.append_record(pair, 2.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	var result_200: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)

	# Assert — 與前次查詢結果差異 < 0.001(收斂至穩態,不隨筆數無限增長)
	assert_float(absf(result_200.value - result_100.value)).is_less(0.001)


# ---- AC-18:純戰鬥地板值(k=1) -----------------------------------------------

func test_pure_combat_floor_k_equals_one() -> void:
	# Arrange — 「純戰鬥玩家」模擬配對,僅接收 combat_card 來源,r_card=2,
	# 寫入間隔固定為每 1 個全域刻度一筆(k=1),λ_narrative=0.9,α=0.3
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2

	# Act — 累積至少 100 筆記錄,最新一筆寫入後立即查詢
	for i in range(100):
		pool.append_record(pair, 2.0, AffinityTypes.Source.COMBAT_CARD)
	var result: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(pair)

	# Assert — 落在封閉解 pure_combat_floor = α·r_card/(1-λ_narrative) = 0.3×2/0.1 = 6
	# 的 ±0.01 範圍內
	assert_float(result.value).is_equal_approx(6.0, 0.01)


# ---- AC-25:陣亡配對凍結於 t_death(p),shape_feature_read 不受影響 -----------

func test_dead_pair_freezes_combat_and_narrative_but_not_shape() -> void:
	# Arrange — 配對 p(C1_C2),陣亡前兩筆記錄(非零凍結基準),之後 CHARACTER_1
	# 陣亡,陣亡後其他配對(C3_C4)接續寫入 10 筆,使全域計數器明顯推進至遠大於
	# t_death(p),λ<1(排除合法邊界值 1,依 GDD 建議校準範圍 [0.90,0.98])
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.95, 0.95, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	var other_pair: AffinityTypes.Pair = AffinityTypes.Pair.C3_C4

	pool.append_record(pair, 5.0, AffinityTypes.Source.SUPPORT_CONVERSATION)  # t=1
	pool.append_record(pair, 3.0, AffinityTypes.Source.COMBAT_CARD)  # t=2
	pool.notify_death(AffinityTypes.Character.CHARACTER_1)  # t_death(p) = 2

	for i in range(10):
		pool.append_record(other_pair, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	# _t_now 現為 12,遠大於 t_death(p)=2

	# Act — 省略 t_query,應凍結於 t_death(p)=2
	var combat_frozen: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
	var combat_at_death: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair, 2)
	var combat_at_now: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair, 12)

	var narrative_frozen: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(pair)
	var narrative_at_death: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(
		pair, 2
	)
	var narrative_at_now: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(
		pair, 12
	)

	# Assert — 省略 t_query 的讀值與明確帶入 t_death(p) 完全相同,且明確不等於
	# 以目前推進後的 t_now 為 t_query 呼叫的結果(差距遠大於 ±0.01 容許誤差)
	assert_int(combat_frozen.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
	assert_int(narrative_frozen.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)

	assert_float(combat_frozen.value).is_equal_approx(combat_at_death.value, 0.000000001)
	assert_float(absf(combat_frozen.value - combat_at_now.value)).is_greater(0.01)

	assert_float(narrative_frozen.value).is_equal_approx(narrative_at_death.value, 0.000000001)
	assert_float(absf(narrative_frozen.value - narrative_at_now.value)).is_greater(0.01)

	# Assert — shape_feature_read(省略 t_query)不受本 story 新增的凍結邏輯影響
	# ⚠️ 本 story 未觸碰 shape_feature_read 的公式三計算本身(S-010/S-011 範圍),
	# 這裡只驗證 S-006 既有骨架的既有分流(省略 t_query 恆預設 _t_now)未被本次
	# 修改波及——不是本 story 新交付的行為。
	var shape_omitted: AffinityDataPool.ShapeFeatureResult = pool.shape_feature_read(pair)
	var shape_explicit_now: AffinityDataPool.ShapeFeatureResult = pool.shape_feature_read(
		pair, 12
	)
	assert_int(shape_omitted.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
	assert_int(shape_omitted.t_query).is_equal(shape_explicit_now.t_query)
	assert_int(shape_omitted.n_pair).is_equal(shape_explicit_now.n_pair)


# ---- AC-31:λ=0 的全域計數器行為(多配對交錯) --------------------------------

func test_lambda_zero_global_interleaving() -> void:
	# Arrange — 配對 B 於 t=1 寫入,其後配對 A~J(9 個其他配對)接續寫入,
	# 將全域計數器推進至 t=10,期間 B 未再被寫入
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.0, 0.0, 0.3))
	var pair_b: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	pool.append_record(pair_b, 5.0, AffinityTypes.Source.SUPPORT_CONVERSATION)  # t=1
	_advance_other_pairs(pool, pair_b, 9)  # t=2..10

	# Act
	var combat_result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(
		pair_b, 10
	)
	var narrative_result: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(
		pair_b, 10
	)

	# Assert — 讀值皆為 0(而非 5),因為配對 B 不是全域最後一次寫入
	assert_int(pool._t_now).is_equal(10)
	assert_float(combat_result.value).is_equal_approx(0.0, 0.000000001)
	assert_float(narrative_result.value).is_equal_approx(0.0, 0.000000001)


# ---- AC-32:λ_narrative=1 無界線性成長 ---------------------------------------

func test_lambda_narrative_one_unbounded_linear_growth() -> void:
	# Arrange — λ_narrative=1(合法邊界值),100 筆記錄皆 support_conversation
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 1.0, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2

	# Act
	for i in range(100):
		pool.append_record(pair, 2.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	var result: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(pair)

	# Assert — 精確等於 200,不拋出例外、不產生 NaN/Infinity
	assert_float(result.value).is_equal_approx(200.0, 0.000000001)
	assert_bool(is_nan(result.value)).is_false()
	assert_bool(is_inf(result.value)).is_false()


# ---- AC-33:0^0:=1 慣例(敘事端) ---------------------------------------------

func test_zero_zero_convention_narrative() -> void:
	# Arrange — 單筆記錄,age=0,source=support_conversation,λ_narrative=0
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.0, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	_inject_raw_record(pool, pair, 2.0, 9, AffinityTypes.Source.SUPPORT_CONVERSATION)
	pool._t_now = 9

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(pair)

	# Assert — 回傳值精確等於 2(w(source_1)·m_1·λ^0 = 1.0×2×1 = 2)
	assert_float(result.value).is_equal_approx(2.0, 0.000000001)


# ---- AC-34:歷史 t_query 不洩漏未來記錄 --------------------------------------

func test_historical_t_query_does_not_leak_future_records() -> void:
	# Arrange — 配對 p 有記錄 (m=+3,t=5)、(m=+2,t=15)
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	_inject_raw_record(pool, pair, 3.0, 5)
	_inject_raw_record(pool, pair, 2.0, 15)
	pool._t_now = 20

	# Act — t_query=10(早於第二筆,晚於第一筆)
	var result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair, 10)

	# Assert — 只計入第一筆記錄(age=10-5=5),完全不受第二筆影響
	var expected: float = 3.0 * pow(0.9, 5)
	assert_float(result.value).is_equal_approx(expected, 0.000000001)
	assert_int(result.n_pair).is_equal(1)


# ---- AC-35:t_query 早於最早記錄 → n(p)=0(真實計算,非佔位值) ----------------
# 🔴 見檔頭「AC-35 陷阱的處置」——combat/narrative 兩支用真實記錄驗證,
# shape_feature_read 分支範圍限定同工作單。

func test_t_query_before_earliest_record_returns_n_pair_zero_sentinel() -> void:
	# Arrange — 配對 p 最早一筆記錄的 t_i=20
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	_inject_raw_record(pool, pair, 4.0, 20)
	pool._t_now = 20

	# Act — t_query=10,早於該配對任何記錄
	var combat_result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair, 10)
	var narrative_result: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(
		pair, 10
	)
	var shape_result: AffinityDataPool.ShapeFeatureResult = pool.shape_feature_read(pair, 10)

	# Assert — combat/narrative:真實加權邏輯過濾後算出的 n(p)=0 與中性值 0.0,
	# 行為與「從未有任何記錄」完全一致——這不是佔位值,是實際遍歷後排除了那筆
	# t=20 的記錄才得到的結果(該配對的 _records 確實有 1 筆記錄,診斷計數會
	# 反映走訪過它,但 n_pair 正確排除)
	assert_int(combat_result.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
	assert_int(combat_result.n_pair).is_equal(0)
	assert_float(combat_result.value).is_equal_approx(0.0, 0.000000001)
	assert_int(combat_result.diagnostic_visited_count).is_equal(1)

	assert_int(narrative_result.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
	assert_int(narrative_result.n_pair).is_equal(0)
	assert_float(narrative_result.value).is_equal_approx(0.0, 0.000000001)

	# shape_feature_read:本 story 未觸碰公式三計算本身(S-010/S-011 範圍),此處
	# 驗證的是 S-006 既有骨架的 n_pair=0 哨兵值不受本 story 影響——不是本 story
	# 新交付的行為(範圍見 Story S-007 Out of Scope)。
	assert_int(shape_result.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
	assert_int(shape_result.n_pair).is_equal(0)


# ---- AC-55:O(n_pair) 診斷計數不受其他配對筆數影響 ---------------------------

func test_diagnostic_visited_count_equals_n_pair_regardless_of_other_pairs_size() -> void:
	# Arrange — 配對 p 有 4 筆記錄
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	pool.append_record(pair, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	pool.append_record(pair, 2.0, AffinityTypes.Source.COMBAT_CARD)
	pool.append_record(pair, -1.5, AffinityTypes.Source.STORY_EVENT)
	pool.append_record(pair, 3.0, AffinityTypes.Source.SUPPORT_CONVERSATION)

	# Act — 其餘配對合計先推進 10 筆(N_other 小)
	_advance_other_pairs(pool, pair, 10)
	var combat_small: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
	var narrative_small: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(pair)

	# Act — 其餘配對再累積至約 1000 筆(與前一次相比改變超過一個數量級)
	_advance_other_pairs(pool, pair, 1000)
	var combat_large: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
	var narrative_large: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(pair)

	# Assert — 診斷值精確等於 n_p=4,且不隨其他配對筆數變動而改變
	assert_int(combat_small.diagnostic_visited_count).is_equal(4)
	assert_int(combat_small.n_pair).is_equal(4)
	assert_int(combat_large.diagnostic_visited_count).is_equal(4)
	assert_int(combat_large.n_pair).is_equal(4)

	assert_int(narrative_small.diagnostic_visited_count).is_equal(4)
	assert_int(narrative_large.diagnostic_visited_count).is_equal(4)
	# 讀值本身不斷言相等——省略 t_query 時預設值跟著 _t_now 前進,age 因此改變,
	# 這是預期行為(呼應 AC-5),本 AC 只斷言診斷計數不受影響。


# ---- AC-62(範圍限定):陣亡後追憶寫入不改變凍結讀值 ---------------------------

func test_posthumous_writes_do_not_change_frozen_combat_and_narrative_reads() -> void:
	# Arrange — 配對 (A,B),A 陣亡前 1 筆記錄,陣亡後陸續追加追憶記錄(M=1,再 M=2)
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.9, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	pool.append_record(pair, 4.0, AffinityTypes.Source.SUPPORT_CONVERSATION)  # t=1
	pool.notify_death(AffinityTypes.Character.CHARACTER_1)  # t_death(p) = 1

	var combat_death_only: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
	var narrative_death_only: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(
		pair
	)

	# Act — M=1:追加一筆死後追憶記錄(來源非 combat_card,合法)
	pool.append_record(pair, 2.0, AffinityTypes.Source.SUPPORT_CONVERSATION)  # t=2
	var combat_m1: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
	var narrative_m1: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(pair)

	# Act — M=2:再追加一筆
	pool.append_record(pair, -3.0, AffinityTypes.Source.STORY_EVENT)  # t=3
	var combat_m2: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
	var narrative_m2: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(pair)

	# Assert — 省略 t_query 的讀值與明確帶入 t_death=1 完全相同,且不隨 M 增加而變化
	var combat_at_death: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair, 1)
	var narrative_at_death: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(
		pair, 1
	)

	for combat_result: AffinityDataPool.AffinityReadResult in [
		combat_death_only, combat_m1, combat_m2
	]:
		assert_float(combat_result.value).is_equal_approx(combat_at_death.value, 0.000000001)

	for narrative_result: AffinityDataPool.AffinityReadResult in [
		narrative_death_only, narrative_m1, narrative_m2
	]:
		assert_float(narrative_result.value).is_equal_approx(
			narrative_at_death.value, 0.000000001
		)


# ---- AC-75:t_death(p) 確實來自陣亡標記表,不是抽象量 -------------------------

func test_t_death_actually_used_as_frozen_query_point() -> void:
	# Arrange — 配對 (A,B),先以正常寫入介面寫入 2 筆記錄,再呼叫陣亡通知介面,
	# 之後對其他配對接續寫入,使全域計數器明顯推進至遠大於陣亡標記表中 A 的標記值
	var pool: AffinityDataPool = AffinityDataPool.new(_make_calibration(0.95, 0.9, 0.3))
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	var other_pair: AffinityTypes.Pair = AffinityTypes.Pair.C3_C4

	pool.append_record(pair, 4.0, AffinityTypes.Source.SUPPORT_CONVERSATION)  # t=1
	pool.append_record(pair, 2.0, AffinityTypes.Source.SUPPORT_CONVERSATION)  # t=2
	pool.notify_death(AffinityTypes.Character.CHARACTER_1)  # 陣亡標記表:A -> 2

	for i in range(10):
		pool.append_record(other_pair, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	# _t_now 現為 12,遠大於陣亡標記表中 A 的標記值(2)

	# Act — 省略 t_query
	var result_omitted: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
	# 明確帶入陣亡標記表中 A 的標記值(經 t_death() 讀出)
	var death_mark: Variant = pool.t_death(pair)
	var result_at_death_mark: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(
		pair, death_mark
	)
	var result_at_current_t_now: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(
		pair, pool._t_now
	)

	# Assert — 省略 t_query 的讀值與明確帶入陣亡標記表標記值完全相同
	assert_float(result_omitted.value).is_equal_approx(result_at_death_mark.value, 0.000000001)
	# 且明確不等於以目前推進後的 t_now 為 t_query 呼叫的結果
	assert_float(absf(result_omitted.value - result_at_current_t_now.value)).is_greater(0.01)
