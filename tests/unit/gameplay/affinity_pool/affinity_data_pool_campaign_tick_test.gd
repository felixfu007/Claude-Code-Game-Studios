# AffinityDataPool(src/gameplay/affinity_pool/affinity_data_pool.gd)的戰役刻度
# 切面單元測試。
#
# Story:production/epics/affinity-data-pool/story-005-campaign-tick.md(S-005)
# 涵蓋 AC-39(戰役最初一章的 c_now≥1 保證,白箱)、AC-41(c_now 的歷史重建不受
# 「有無配對被寫入」污染,白箱)。
#
# 🔴 本檔刻意只測 `_campaign_tick_marks` / `advance_campaign_tick()` / `_c_now()`
# 這一個切面,以及它們對 `append_record()` 的 `record.c` 欄位的銜接——不重測
# S-004 已交付的 append_record() 六步驗證本身(那些測試在
# affinity_data_pool_write_path_test.gd)。S-003~S-007 各自對同一個實作檔
# `affinity_data_pool.gd` 的不同切面建立獨立測試檔,不合併(EPIC.md 陷阱五)。
#
# ⚠️ AC-39/AC-41 原文要求透過 shape_feature_read 的 spread_ratio 觀測 c_now——
# 該讀取函數依賴 S-006/S-007(切片外),本檔只能先以池的內部狀態(白箱)驗證
# `_campaign_tick_marks` 本身的行為與 `_c_now(t_query)` 的計算是否正確。黑箱複驗
# 待 S-010 落地後由該處補上,producer 已登記此項(見 story 文件 AC 段的⚠️ 註記)。
#
# 直接讀寫 `_campaign_tick_marks` / `_t_now` 屬白箱測試——與
# affinity_data_pool_death_marks_test.gd 對 S-005 白箱驗證的既有先例(該檔案
# 開頭註解逐字提及 AC-39/41)同一形狀。
#
# 純資料結構與純函式、無節點——不建立任何 Node,不需要 tear-down,不會留下
# 孤兒節點。每個測試自成一組斷言,彼此不共用可變狀態、不依賴執行順序。
extends GdUnitTestSuite


# ---- advance_campaign_tick():附加當下 t_now 現值到標記列表 -------------------

func test_advance_campaign_tick_appends_current_t_now_to_marks_list() -> void:
	# Arrange — 白箱設定非零的 t_now(對應 append_record() 已寫入過若干筆記錄的
	# 情境),與 affinity_data_pool_death_marks_test.gd 對 notify_death() 的既有
	# 先例同一形狀
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._t_now = 5

	# Act
	var rejection: AffinityDataPool.AdvanceRejection = pool.advance_campaign_tick()

	# Assert — 附加了唯一一筆標記,值為呼叫當下的 t_now 現值
	assert_int(rejection).is_equal(AffinityDataPool.AdvanceRejection.NONE)
	assert_int(pool._campaign_tick_marks.size()).is_equal(1)
	assert_int(pool._campaign_tick_marks[0]).is_equal(5)


func test_advance_campaign_tick_does_not_increment_t_now() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._t_now = 3

	# Act
	var rejection: AffinityDataPool.AdvanceRejection = pool.advance_campaign_tick()

	# Assert — 呼叫前後 t_now 完全相同(與 notify_death() 的既有慣例一致:記錄
	# 呼叫當下的現值,不推進計數器本身)
	assert_int(rejection).is_equal(AffinityDataPool.AdvanceRejection.NONE)
	assert_int(pool._t_now).is_equal(3)


# ---- _c_now(t_query):Formulas 3c 精確定義(AC-41) --------------------------

func test_c_now_at_query_is_count_of_marks_at_or_before_query() -> void:
	# Arrange — AC-41 原文案例:戰役刻度標記列表已有 5 筆標記,對應第 1~5 次
	# 「前進戰役刻度」呼叫,分別發生於全域計數器 t=1、t=3、t=3、t=3、t=8(其中
	# t=3 那三次代表連續三章開始時皆無任何好感度事件寫入)。白箱直接設定標記
	# 列表——本測試只驗證 _c_now() 本身的計算,不透過 advance_campaign_tick()
	# 逐次呼叫建立(那需要在呼叫間手動搬動 _t_now,對本測試而言是無關的雜訊)。
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._campaign_tick_marks = [1, 3, 3, 3, 8]

	# Act — 以 t_query=5(晚於第 4 次標記、早於第 5 次標記)查詢
	var result: int = pool._c_now(5)

	# Assert — 精確等於 4(t≤5 的標記筆數),而非依賴 Delta Log 記錄本身反推出
	# 的任何較低值
	assert_int(result).is_equal(4)


func test_c_now_unaffected_by_periods_with_no_affinity_writes() -> void:
	# Arrange — 同 AC-41 案例,額外驗證 Delta Log 全空(全部 10 個合法配對皆
	# 0 筆記錄),證明本次查詢期間沒有任何一筆好感度事件被寫入過
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._campaign_tick_marks = [1, 3, 3, 3, 8]

	for pair: AffinityTypes.Pair in AffinityTypes.Pair.values():
		assert_int(pool._records[pair].size()).is_equal(0)

	# Act
	var result: int = pool._c_now(5)

	# Assert — AC-41 的核心宣稱:即使整場戰役目前一筆好感度記錄都沒寫過,
	# c_now(5) 仍精確回傳 4——c_now 的歷史重建不受「該期間有無配對被寫入」
	# 影響,密度污染(Delta Log 疏密改變 c_now 觀測值)不再發生,這正是本
	# story 存在的理由
	assert_int(result).is_equal(4)


func test_c_now_includes_mark_exactly_equal_to_query() -> void:
	# Arrange — 獨立覆核抓到的邊界盲區:原 AC-41 案例(marks=[1,3,3,3,8],
	# t_query=5)沒有任何一筆標記值恰好等於查詢值,故無法區分 `mark <= t_query`
	# 與 `mark < t_query` 兩種實作(注入驗證兩者在該資料下答案相同、皆為 4)。
	# 本測試改用 marks=[1, 3, 5, 8]、t_query=5——標記值 5 恰好等於查詢值,
	# 唯一能讓「≤ 是否含等於」這條邊界產生可觀測差異的資料。
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._campaign_tick_marks = [1, 3, 5, 8]

	# Act
	var result: int = pool._c_now(5)

	# Assert — 精確等於 3(1、3、5 三筆滿足 mark<=5;8 不滿足)。若實作誤寫成
	# `mark < t_query`,標記值 5 會被排除,結果變成 2,本測試會抓到這個差異。
	assert_int(result).is_equal(3)


# ---- append_record() 銜接:戰役最初一章的 c_i≥1 保證(AC-39) -----------------

func test_first_chapter_start_tick_makes_c_i_at_least_one_for_subsequent_writes() -> void:
	# Arrange — 這是戰役最初一章,章節/戰役結構系統依既定呼叫時機於該章開始時
	# 呼叫「前進戰役刻度」介面
	var pool: AffinityDataPool = AffinityDataPool.new()
	var advance_rejection: AffinityDataPool.AdvanceRejection = pool.advance_campaign_tick()
	assert_int(advance_rejection).is_equal(AffinityDataPool.AdvanceRejection.NONE)

	# Act — 該章開始後、結束前的某個時間點觸發好感度事件並寫入記錄
	var pair: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
	var write_rejection: AffinityDataPool.WriteRejection = pool.append_record(
		pair, 2.0, AffinityTypes.Source.STORY_EVENT
	)
	assert_int(write_rejection).is_equal(AffinityDataPool.WriteRejection.NONE)

	# Assert — 該筆記錄的 c_i ≥ 1,驗證 Formulas 3c 的 c_now≥1 保證在戰役最初
	# 一章確實成立。⚠️ 本測試只白箱驗證池內部狀態(record.c 欄位本身)——
	# 透過 shape_feature_read 的 spread_ratio 觀測 c_now 的黑箱複驗待 S-010。
	var record: AffinityRecord = pool._records[pair].get_at(0)
	assert_int(record.c).is_greater_equal(1)
