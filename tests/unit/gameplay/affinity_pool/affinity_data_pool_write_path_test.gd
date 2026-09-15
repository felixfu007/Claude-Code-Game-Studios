# AffinityDataPool(src/gameplay/affinity_pool/affinity_data_pool.gd)的寫入路徑
# 單元測試。
#
# Story:production/epics/affinity-data-pool/story-004-pool-skeleton-and-write-path.md(S-004)
# 涵蓋 AC-2(部分——c_i 欄位存在且不變,精確值待 S-005)、AC-7、AC-24、AC-27b、AC-28、
# AC-29、AC-30、AC-63,以及建構子預填的正面驗證與 ADR-0002 Validation Criteria #13
# (兩條序數驗證路徑一致性)。
#
# 🔴 本檔刻意只測 append_record() 這一個切面(含其對 _records/_t_now 的副作用),
# 不重測 S-003 已交付的 notify_death()/t_death() 本身行為(那些測試在
# affinity_data_pool_death_marks_test.gd)——本檔只在需要陣亡前置條件時呼叫
# notify_death() 作為 Arrange 步驟(EPIC.md 陷阱五:同一實作檔的不同切面各自建立
# 獨立測試檔,不合併)。
#
# 純資料結構與純函式、無節點——不建立任何 Node,不需要 tear-down,不會留下孤兒節點。
# 每個測試自成一組斷言,彼此不共用可變狀態、不依賴執行順序。
extends GdUnitTestSuite


# ---- AC-2(部分涵蓋):既有記錄不受新寫入影響,t_i 正確遞增 -------------------
# ⚠️ 本測試只驗證 pair/m/t/source 四欄位前後相同、c 欄位存在且不變(值恆為佔位
# 值 0)。c_i 的精確戰役刻度值依賴 S-005,本 story 不對其做任何非 0 的期望值斷言。

func test_append_record_preserves_existing_records_and_advances_t_i() -> void:
	# Arrange — 建立一份已有 2 筆記錄的 Delta Log(跨兩個不同配對)
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair_a: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	var pair_b: AffinityTypes.Pair = AffinityTypes.Pair.C3_C4

	var rejection1: AffinityDataPool.WriteRejection = pool.append_record(
		pair_a, 2.0, AffinityTypes.Source.SUPPORT_CONVERSATION
	)
	var rejection2: AffinityDataPool.WriteRejection = pool.append_record(
		pair_b, -3.0, AffinityTypes.Source.STORY_EVENT
	)
	assert_int(rejection1).is_equal(AffinityDataPool.WriteRejection.NONE)
	assert_int(rejection2).is_equal(AffinityDataPool.WriteRejection.NONE)

	var before: AffinityRecord = pool._records[pair_a].get_at(0)
	var snapshot_pair: AffinityTypes.Pair = before.pair
	var snapshot_m: float = before.m
	var snapshot_t: int = before.t
	var snapshot_c: int = before.c
	var snapshot_source: AffinityTypes.Source = before.source

	# Act — 新增第 3 筆合法記錄(AC-2 的 N+1)
	var rejection3: AffinityDataPool.WriteRejection = pool.append_record(
		pair_a, 5.0, AffinityTypes.Source.COMBAT_CARD
	)
	assert_int(rejection3).is_equal(AffinityDataPool.WriteRejection.NONE)

	# Assert — 第 1 筆記錄的欄位逐一比對前後完全相同
	var after: AffinityRecord = pool._records[pair_a].get_at(0)
	assert_int(after.pair).is_equal(snapshot_pair)
	assert_float(after.m).is_equal_approx(snapshot_m, 0.000000000001)
	assert_int(after.t).is_equal(snapshot_t)
	assert_int(after.c).is_equal(snapshot_c)
	assert_int(after.source).is_equal(snapshot_source)

	# Assert — 新記錄的 t_i = 寫入前全域計數器值(2) + 1 = 3
	var new_record: AffinityRecord = pool._records[pair_a].get_at(1)
	assert_int(new_record.t).is_equal(3)

	# AC-2 部分涵蓋:c 欄位存在且為本 story 的佔位值 0——不斷言任何非 0 的期望值,
	# 精確戰役刻度值待 S-005。
	assert_int(new_record.c).is_equal(0)


# ---- AC-7:同回合內連續兩次寫入,t_i 相異且遞增 -----------------------------

func test_two_writes_in_same_turn_get_distinct_increasing_t_i() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2

	# Act — 同一回合內連續觸發兩次好感度對話卡牌效果
	pool.append_record(pair, 1.0, AffinityTypes.Source.COMBAT_CARD)
	pool.append_record(pair, 1.0, AffinityTypes.Source.COMBAT_CARD)

	# Assert — 兩筆記錄取得不同且遞增的 t_i,呼叫順序即記錄順序
	var first: AffinityRecord = pool._records[pair].get_at(0)
	var second: AffinityRecord = pool._records[pair].get_at(1)
	assert_int(first.t).is_equal(1)
	assert_int(second.t).is_equal(2)
	assert_int(second.t).is_greater(first.t)


# ---- AC-24:幅度為 0 的寫入被拒絕 -------------------------------------------

func test_append_record_rejects_zero_amplitude() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	var t_before: int = pool._t_now
	var n_before: int = pool._records[pair].size()

	# Act
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(
		pair, 0.0, AffinityTypes.Source.COMBAT_CARD
	)

	# Assert — 全域計數器不遞增、Delta Log 不新增記錄、n(p) 不變
	assert_int(rejection).is_equal(AffinityDataPool.WriteRejection.ZERO_AMPLITUDE)
	assert_int(pool._t_now).is_equal(t_before)
	assert_int(pool._records[pair].size()).is_equal(n_before)


# ---- AC-27b/AC-30:非法配對序數的寫入被拒絕 ---------------------------------

func test_append_record_rejects_out_of_range_pair_ordinal() -> void:
	# Arrange — 探針 B 已實測:越界 int(-1/999)原封不動抵達函式本體,零錯誤零檢查,
	# 與 affinity_data_pool_death_marks_test.gd 對 notify_death(-1) 的既有測試同一形狀。
	var pool: AffinityDataPool = AffinityDataPool.new()
	var t_before: int = pool._t_now

	# Act
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(
		999, 1.0, AffinityTypes.Source.COMBAT_CARD
	)

	# Assert — 不遞增任何計數器,且沒有任何一個合法配對意外收到這筆記錄
	# (證明沒有任何程式碼路徑能讓非法配對進入 Delta Log)
	assert_int(rejection).is_equal(AffinityDataPool.WriteRejection.INVALID_PAIR)
	assert_int(pool._t_now).is_equal(t_before)
	for pair: AffinityTypes.Pair in AffinityTypes.Pair.values():
		assert_int(pool._records[pair].size()).is_equal(0)


# ---- AC-28:非法來源標籤的寫入被拒絕 ----------------------------------------

func test_append_record_rejects_invalid_source_label() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	var t_before: int = pool._t_now
	var n_before: int = pool._records[pair].size()

	# Act — 探針 B 同型:越界 int 原封不動抵達函式本體
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(pair, 1.0, 999)

	# Assert
	assert_int(rejection).is_equal(AffinityDataPool.WriteRejection.INVALID_SOURCE)
	assert_int(pool._t_now).is_equal(t_before)
	assert_int(pool._records[pair].size()).is_equal(n_before)


# ---- AC-29:NaN 幅度的寫入被拒絕(只在池的直接單元測試可構造) -----------------

func test_append_record_rejects_nan_amplitude() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	var t_before: int = pool._t_now
	var n_before: int = pool._records[pair].size()

	# Act — 不允許 NaN 以任何形式(例如靜默轉換為 0)進入 Delta Log
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(
		pair, NAN, AffinityTypes.Source.COMBAT_CARD
	)

	# Assert
	assert_int(rejection).is_equal(AffinityDataPool.WriteRejection.NON_FINITE_AMPLITUDE)
	assert_int(pool._t_now).is_equal(t_before)
	assert_int(pool._records[pair].size()).is_equal(n_before)


# ---- AC-63:陣亡配對的寫入限制(判定條件為「至少一人」) -----------------------

func test_append_record_rejects_combat_card_for_dead_pair_member_a() -> void:
	# Arrange — 配對中 A 陣亡、B 存活
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2
	)
	pool.notify_death(AffinityTypes.Character.CHARACTER_1)
	var t_before: int = pool._t_now
	var n_before: int = pool._records[pair].size()

	# Act — 以戰鬥好感度對話卡牌來源寫入
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(
		pair, 1.0, AffinityTypes.Source.COMBAT_CARD
	)

	# Assert — 拒絕,計數器與筆數不變
	assert_int(rejection).is_equal(AffinityDataPool.WriteRejection.DEAD_PAIR_COMBAT_CARD_FORBIDDEN)
	assert_int(pool._t_now).is_equal(t_before)
	assert_int(pool._records[pair].size()).is_equal(n_before)


func test_append_record_rejects_combat_card_for_dead_pair_member_b() -> void:
	# Arrange — 配對中 B 陣亡、A 存活(2026-08-10 第十輪對抗性覆核補上:「至少一人」
	# 判定不得偏袒配對中的任一位置,故 A 死/B 死須各一條測試)
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_3, AffinityTypes.Character.CHARACTER_4
	)
	pool.notify_death(AffinityTypes.Character.CHARACTER_4)
	var t_before: int = pool._t_now
	var n_before: int = pool._records[pair].size()

	# Act
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(
		pair, 1.0, AffinityTypes.Source.COMBAT_CARD
	)

	# Assert
	assert_int(rejection).is_equal(AffinityDataPool.WriteRejection.DEAD_PAIR_COMBAT_CARD_FORBIDDEN)
	assert_int(pool._t_now).is_equal(t_before)
	assert_int(pool._records[pair].size()).is_equal(n_before)


func test_append_record_accepts_support_conversation_for_dead_pair() -> void:
	# Arrange — 陣亡配對,死後追憶
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2
	)
	pool.notify_death(AffinityTypes.Character.CHARACTER_1)

	# Act
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(
		pair, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION
	)

	# Assert — 正常成功、正常遞增全域計數器
	assert_int(rejection).is_equal(AffinityDataPool.WriteRejection.NONE)
	assert_int(pool._records[pair].size()).is_equal(1)
	assert_int(pool._t_now).is_equal(1)


func test_append_record_accepts_story_event_for_dead_pair() -> void:
	# Arrange — 陣亡配對,死後追憶(劇情事件來源)
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2
	)
	pool.notify_death(AffinityTypes.Character.CHARACTER_2)

	# Act
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(
		pair, 1.0, AffinityTypes.Source.STORY_EVENT
	)

	# Assert
	assert_int(rejection).is_equal(AffinityDataPool.WriteRejection.NONE)
	assert_int(pool._records[pair].size()).is_equal(1)
	assert_int(pool._t_now).is_equal(1)


# ---- 建構子預填的正面驗證(支撐 S-006/S-007 的 n(p)=0 讀取不中止) -------------

func test_all_ten_pairs_readable_immediately_after_construction() -> void:
	# Arrange — 剛建構完成,尚未有任何 append_record() 呼叫
	var pool: AffinityDataPool = AffinityDataPool.new()

	# Act / Assert — 探針 A:型別化 Dictionary 對未預填的鍵做 subscript 讀取會中止
	# 呼叫函式;這裡直接讀取驗證全部 10 個合法配對皆不中止,且回傳合法的空
	# AffinityRecordList(n(p)=0 是 GDD 明文的合法狀態,不是邊緣情境)
	for pair: AffinityTypes.Pair in AffinityTypes.Pair.values():
		assert_int(pool._records[pair].size()).is_equal(0)


# ---- Validation Criteria #13:兩條序數驗證路徑一致性 ------------------------

func test_two_ordinal_validation_paths_agree_on_same_inputs() -> void:
	# ADR-0002 機制四之四:AffinityTypes.is_valid_*()(公開靜態,S-001,低頻)與
	# AffinityDataPool._validate_*_ordinal()(內部讀 _init() 快取,本 story,熱路徑)
	# 是刻意保留的兩份獨立實作路徑(見 affinity_data_pool.gd 對應文件註解),兩者對
	# 同一輸入必須回傳完全一致的結果。
	#
	# 本測試只能證明「兩條路徑今天一致」,不能證明「結構上不可能分岔」——兩份獨立
	# 實作意味著未來任一份被單獨修改,編譯器不會擋下語意分歧,這是刻意接受這個形狀
	# 所付的代價,不是本測試消除掉的風險。
	var pool: AffinityDataPool = AffinityDataPool.new()

	var pair_inputs: Array = [AffinityTypes.Pair.C1_C2, -1, 999]
	for input in pair_inputs:
		assert_bool(pool._validate_pair_ordinal(input)).is_equal(
			AffinityTypes.is_valid_pair(input)
		)

	var character_inputs: Array = [AffinityTypes.Character.CHARACTER_1, -1, 999]
	for input in character_inputs:
		assert_bool(pool._validate_character_ordinal(input)).is_equal(
			AffinityTypes.is_valid_character(input)
		)

	var source_inputs: Array = [AffinityTypes.Source.COMBAT_CARD, -1, 999]
	for input in source_inputs:
		assert_bool(pool._validate_source_ordinal(input)).is_equal(
			AffinityTypes.is_valid_source(input)
		)
