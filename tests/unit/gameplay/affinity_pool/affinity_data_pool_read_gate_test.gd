# AffinityDataPool(src/gameplay/affinity_pool/affinity_data_pool.gd)的讀取結果
# 型別與 t_query 型別閘門單元測試。
#
# Story:production/epics/affinity-data-pool/story-006-read-result-types-and-t-query-gate.md(S-006)
# 涵蓋 AC-36(三個真實讀取函數對未來時間點查詢的拒絕),以及 ADR-0002 機制五/
# 機制五之二(t_query 型別閘門三分支、pair 序數驗證入口 3–5、拒絕時哨兵值表)。
#
# 🔴 本檔刻意只測「入口 + t_query 閘門 + pair 序數驗證 + 拒絕分流」這一個切面
# (工作單 Implementation Notes #8)——加權計算邏輯本身、n(p)=0 的完整合法回傳值、
# 陣亡配對的條件式預設查詢時點實際算出的值,全部屬 S-007,本檔不對其做任何
# 非佔位值的期望值斷言(EPIC.md 陷阱五:同一實作檔的不同切面各自建立獨立測試檔,
# 不合併)。
#
# 純資料結構與純函式、無節點——不建立任何 Node,不需要 tear-down,不會留下孤兒節點。
# 每個測試自成一組斷言,彼此不共用可變狀態、不依賴執行順序。
extends GdUnitTestSuite


# ---- AC-36:三個真實讀取函數拒絕未來時間點查詢 ------------------------------

func test_combat_strength_read_rejects_future_t_query() -> void:
	# Arrange — t_now=N,以 t_query=N+1 呼叫
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._t_now = 5
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2
	)

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair, 6)

	# Assert — 拒絕,不回傳任何讀值
	assert_int(result.rejection).is_equal(AffinityDataPool.ReadRejection.FUTURE_TIME_QUERY)


func test_narrative_depth_read_rejects_future_t_query() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._t_now = 5
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_2, AffinityTypes.Character.CHARACTER_3
	)

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(pair, 6)

	# Assert
	assert_int(result.rejection).is_equal(AffinityDataPool.ReadRejection.FUTURE_TIME_QUERY)


func test_shape_feature_read_rejects_future_t_query() -> void:
	# Arrange — shape_feature_read 亦受同一閘門約束(GDD 明文「閘門在 006;010
	# 落地後須擴及 shape_feature_read」——它本就是本 story 三個真實讀取函數之一,
	# 無需等待 S-010)
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._t_now = 5
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_3, AffinityTypes.Character.CHARACTER_4
	)

	# Act
	var result: AffinityDataPool.ShapeFeatureResult = pool.shape_feature_read(pair, 6)

	# Assert
	assert_int(result.rejection).is_equal(AffinityDataPool.ReadRejection.FUTURE_TIME_QUERY)


# ---- t_query 型別閘門:match typeof() 三分支 ---------------------------------

func test_t_query_string_type_returns_invalid_t_query_type_without_aborting() -> void:
	# Arrange — 三個讀取函數共用同一顆閘門(_validate_read_query),於一個測試
	# 內依序呼叫全部三個,證明 String 型別的 t_query 被乾淨拒絕、不中止呼叫
	# 函式——若中止,後續呼叫與斷言根本不會執行到(GdUnit4 會回報未完成而非
	# 「三者皆拒絕」)。
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_3
	)

	# Act
	var combat_result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(
		pair, "garbage"
	)
	var narrative_result: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(
		pair, "garbage"
	)
	var shape_result: AffinityDataPool.ShapeFeatureResult = pool.shape_feature_read(
		pair, "garbage"
	)

	# Assert — 三者皆被拒絕,且能執行到這裡本身就證明沒有中止
	assert_int(combat_result.rejection).is_equal(
		AffinityDataPool.ReadRejection.INVALID_T_QUERY_TYPE
	)
	assert_int(narrative_result.rejection).is_equal(
		AffinityDataPool.ReadRejection.INVALID_T_QUERY_TYPE
	)
	assert_int(shape_result.rejection).is_equal(
		AffinityDataPool.ReadRejection.INVALID_T_QUERY_TYPE
	)


func test_t_query_float_type_returns_invalid_t_query_type() -> void:
	# Arrange — TYPE_FLOAT 一律拒絕,不接受 3.0(工作單 Implementation Notes #4:
	# 浮點截斷靜默通過值域檢查的陷阱,與機制八對 t/c 嚴格 TYPE_INT 同一立場)
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._t_now = 5
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_4
	)

	# Act
	var combat_result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(
		pair, 3.0
	)
	var narrative_result: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(
		pair, 3.0
	)
	var shape_result: AffinityDataPool.ShapeFeatureResult = pool.shape_feature_read(
		pair, 3.0
	)

	# Assert
	assert_int(combat_result.rejection).is_equal(
		AffinityDataPool.ReadRejection.INVALID_T_QUERY_TYPE
	)
	assert_int(narrative_result.rejection).is_equal(
		AffinityDataPool.ReadRejection.INVALID_T_QUERY_TYPE
	)
	assert_int(shape_result.rejection).is_equal(
		AffinityDataPool.ReadRejection.INVALID_T_QUERY_TYPE
	)


func test_t_query_null_falls_through_to_default_query_point_branch() -> void:
	# Arrange — 防止 match 三分支未來被重排(ADR-0002 實作提醒:若 `_` 分支被
	# 移到 TYPE_NIL 之前,null 會被提前吃掉,且引擎不擋編譯、不印警告)。省略
	# t_query(即 null)應落入「條件式預設查詢時點」分支,而非 INVALID_T_QUERY_TYPE。
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_2, AffinityTypes.Character.CHARACTER_4
	)

	# Act — 三個函數皆省略 t_query 參數
	var combat_result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
	var narrative_result: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(pair)
	var shape_result: AffinityDataPool.ShapeFeatureResult = pool.shape_feature_read(pair)

	# Assert — 皆通過(NONE),不是 INVALID_T_QUERY_TYPE
	assert_int(combat_result.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
	assert_int(narrative_result.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
	assert_int(shape_result.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)


# ---- pair 序數驗證(機制四之四入口 3–5) --------------------------------------

func test_combat_strength_read_rejects_invalid_pair_ordinal() -> void:
	# Arrange — 探針 A 實測:未攔下的話,_records[非法序數] 缺鍵讀取會直接
	# 中止呼叫函式(比 append_record() 的靜默寫錯更嚴重——這是每回合的熱路徑)
	var pool: AffinityDataPool = AffinityDataPool.new()

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(-1, 0)

	# Assert
	assert_int(result.rejection).is_equal(AffinityDataPool.ReadRejection.INVALID_PAIR)


func test_narrative_depth_read_rejects_invalid_pair_ordinal() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(999, 0)

	# Assert
	assert_int(result.rejection).is_equal(AffinityDataPool.ReadRejection.INVALID_PAIR)


func test_shape_feature_read_rejects_invalid_pair_ordinal() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()

	# Act
	var result: AffinityDataPool.ShapeFeatureResult = pool.shape_feature_read(-1, 0)

	# Assert
	assert_int(result.rejection).is_equal(AffinityDataPool.ReadRejection.INVALID_PAIR)


# ---- 機制五之二:拒絕時哨兵值表 ----------------------------------------------

func test_rejected_read_result_carries_nan_sentinel_for_value() -> void:
	# Arrange — 以非法 pair 序數觸發拒絕(哨兵值表與拒絕碼種類無關,任何拒絕
	# 分支皆套用同一張表——本測試選 INVALID_PAIR 作代表)
	var pool: AffinityDataPool = AffinityDataPool.new()

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(-1, 0)

	# Assert — 逐欄位核對機制五之二的哨兵值表(工作單 Implementation Notes #5)
	assert_int(result.rejection).is_equal(AffinityDataPool.ReadRejection.INVALID_PAIR)
	assert_bool(is_nan(result.value)).is_true()
	assert_int(result.t_query).is_equal(-1)
	assert_int(result.n_pair).is_equal(-1)
	assert_int(result.diagnostic_visited_count).is_equal(-1)


func test_rejected_shape_feature_result_carries_full_sentinel_table() -> void:
	# Arrange — 以非法 pair 序數觸發拒絕
	var pool: AffinityDataPool = AffinityDataPool.new()

	# Act
	var result: AffinityDataPool.ShapeFeatureResult = pool.shape_feature_read(-1, 0)

	# Assert — 11 欄逐一斷言(工作單 Implementation Notes #5 完整表)
	assert_int(result.rejection).is_equal(AffinityDataPool.ReadRejection.INVALID_PAIR)
	assert_int(result.reversal_count).is_equal(-1)
	assert_dict(result.source_distribution).is_empty()
	assert_object(result.time_distribution).is_null()
	assert_dict(result.source_polarity).is_empty()
	assert_bool(is_nan(result.total_churn)).is_true()
	assert_object(result.segment_profile).is_null()
	assert_object(result.low_confidence).is_null()
	assert_dict(result.source_absence).is_empty()
	assert_int(result.n_pair).is_equal(-1)
	assert_int(result.t_query).is_equal(-1)
	assert_int(result.c_now).is_equal(-1)
	assert_int(result.diagnostic_visited_count).is_equal(-1)


# ---- t_query 早於最早記錄 ≠ 拒絕(合法的 n(p)=0 情境) ------------------------

func test_t_query_earlier_than_earliest_record_is_not_a_rejection() -> void:
	# Arrange — t_now 已推進(白箱設定),t_query=0 早於 t_now,但不是未來查詢——
	# 視同該配對在 t_query 當下 n(p, t_query)=0,是合法情境
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._t_now = 5
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_4, AffinityTypes.Character.CHARACTER_5
	)

	# Act
	var combat_result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair, 0)
	var narrative_result: AffinityDataPool.AffinityReadResult = pool.narrative_depth_read(
		pair, 0
	)
	var shape_result: AffinityDataPool.ShapeFeatureResult = pool.shape_feature_read(pair, 0)

	# Assert — 合法情境(視同 n(p, t_query)=0),不是拒絕
	assert_int(combat_result.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
	assert_int(narrative_result.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
	assert_int(shape_result.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)


# ---- 實作選擇(非規格明文釘死):型別通過後,pair 驗證先於未來時點檢查 --------
# 🔴 本測試把「配對驗證在未來時點檢查之前」這個目前的實作順序當場釘死。
# 這不是 GDD/ADR 逐字指定的順序(規格只明文「t_query 型別閘門必須最先」,
# 沒有對「pair 驗證 vs. 未來時點檢查」的相對順序給出可測試的明文斷言或 AC)——
# 若日後有意調整順序,必須連同這條測試一起改,而不是讓它悄悄變成假的保證。
func test_combined_invalid_pair_and_future_t_query_returns_invalid_pair_first() -> void:
	# Arrange — 同時違反兩條規則:pair 非法、且 t_query 為未來時間點
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._t_now = 5

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(-1, 999)

	# Assert — 目前實作:pair 驗證先執行,回傳 INVALID_PAIR 而非 FUTURE_TIME_QUERY
	assert_int(result.rejection).is_equal(AffinityDataPool.ReadRejection.INVALID_PAIR)


# ---- AC-36 邊界:t_query == _t_now(恰為現值,非「大於」)是合法呼叫 -----------
# 🔴 AC-36 原文明確是「t_query=N+1」(嚴格大於)才拒絕——沒有覆蓋 t_query 恰等於
# 現值 N 這個邊界的測試,無法區分實作寫的是 `>` 還是 `>=`(兩者對 N+1 輸入的
# 行為相同,只在 N 這個邊界分岔)。
func test_t_query_equal_to_t_now_is_legal() -> void:
	# Arrange — t_now=5,以 t_query=5(恰為現值,非未來)呼叫
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._t_now = 5
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_5
	)

	# Act
	var result: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair, 5)

	# Assert — 合法,不是 FUTURE_TIME_QUERY
	assert_int(result.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
