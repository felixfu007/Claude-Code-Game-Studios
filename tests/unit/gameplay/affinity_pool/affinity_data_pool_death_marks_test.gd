# AffinityDataPool(src/gameplay/affinity_pool/affinity_data_pool.gd)的陣亡標記
# 表切面單元測試。
#
# Story:production/epics/affinity-data-pool/story-003-death-marks.md(S-003)
# 涵蓋 AC-73(陣亡通知介面基本功能,含 t_now=0 邊界)、AC-74(陣亡通知冪等性
# 拒絕),以及 ADR-0002 R7-P1「陷阱二」(非法序數不得靜默寫入)與已登記禁令
# `death_marks_prefill_or_unguarded_read` 的正面驗證。
#
# 🔴 本檔刻意只測 `_death_marks` / `notify_death()` / `t_death()` 這一個切面。
# S-004~S-007 會針對同一個實作檔 `affinity_data_pool.gd` 的其他切面(寫入路徑、
# 戰役刻度、讀取函數)各自建立獨立測試檔,不與本檔合併(EPIC.md 陷阱五)。
#
# 直接讀寫 `_death_marks` / `_t_now` 屬白箱測試——本 story 尚無 `append_record()`
# (S-004)可以把 t_now 推進到非零值,直接賦值內部欄位是目前唯一手段,與
# ADR-0002 對 S-005 白箱驗證的既有先例(AC-39/41)同一形狀。
#
# 純資料結構與純函式、無節點——不建立任何 Node,不需要 tear-down,不會留下
# 孤兒節點。每個測試自成一組斷言,彼此不共用可變狀態、不依賴執行順序。
extends GdUnitTestSuite


# ---- AC-73:陣亡通知介面基本功能 -------------------------------------------

func test_notify_death_records_current_t_now_without_incrementing_it() -> void:
	# Arrange — 白箱設定非零的 t_now(對應 append_record() 已寫入過若干筆記錄
	# 的情境;本 story 尚無 append_record() 可真的推進它)
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._t_now = 5

	# Act
	var result: AffinityDataPool.DeathNotifyResult = pool.notify_death(
		AffinityTypes.Character.CHARACTER_1
	)

	# Assert — 新增 (X, 呼叫當下的現值),且呼叫前後 t_now 不變
	assert_int(result).is_equal(AffinityDataPool.DeathNotifyResult.NONE)
	assert_int(pool._death_marks[AffinityTypes.Character.CHARACTER_1]).is_equal(5)
	assert_int(pool._t_now).is_equal(5)


func test_notify_death_at_t_now_zero_is_legal() -> void:
	# Arrange — 戰役最初,t_now 尚未被任何寫入推進過(建構子預設值 0)
	var pool: AffinityDataPool = AffinityDataPool.new()

	# Act
	var result: AffinityDataPool.DeathNotifyResult = pool.notify_death(
		AffinityTypes.Character.CHARACTER_2
	)

	# Assert — (Y, 0) 是合法標記值,不觸發任何驗證錯誤 —— t_now=0 時陣亡是
	# 合法情境,不是資料損毀信號
	assert_int(result).is_equal(AffinityDataPool.DeathNotifyResult.NONE)
	assert_int(pool._death_marks[AffinityTypes.Character.CHARACTER_2]).is_equal(0)


# ---- AC-74:陣亡通知冪等性拒絕 ----------------------------------------------

func test_notify_death_twice_for_same_character_is_rejected() -> void:
	# Arrange — 陣亡標記表已含角色 X 的標記
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool.notify_death(AffinityTypes.Character.CHARACTER_3)

	# Act — 再次以角色 X 呼叫
	var second_result: AffinityDataPool.DeathNotifyResult = pool.notify_death(
		AffinityTypes.Character.CHARACTER_3
	)

	# Assert — 呼叫被拒
	assert_int(second_result).is_equal(
		AffinityDataPool.DeathNotifyResult.DUPLICATE_DEATH_NOTIFICATION
	)


func test_notify_death_rejected_call_does_not_overwrite_existing_mark() -> void:
	# Arrange — 角色 X 先在 t_now=3 陣亡並記錄
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool._t_now = 3
	pool.notify_death(AffinityTypes.Character.CHARACTER_4)

	# Act — t_now 推進到 9 後再次通知同一角色陣亡(應被拒絕)
	pool._t_now = 9
	var second_result: AffinityDataPool.DeathNotifyResult = pool.notify_death(
		AffinityTypes.Character.CHARACTER_4
	)

	# Assert — 拒絕發生,且既有標記值(3)不被覆寫成 9
	assert_int(second_result).is_equal(
		AffinityDataPool.DeathNotifyResult.DUPLICATE_DEATH_NOTIFICATION
	)
	assert_int(pool._death_marks[AffinityTypes.Character.CHARACTER_4]).is_equal(3)


# ---- 陷阱二:非法序數不得靜默寫入非法鍵 -------------------------------------

func test_notify_death_with_invalid_character_ordinal_is_rejected() -> void:
	# Arrange — 探針 B 已實測:越界 int 原封不動抵達函式本體,零錯誤零檢查
	var pool: AffinityDataPool = AffinityDataPool.new()

	# Act
	var result: AffinityDataPool.DeathNotifyResult = pool.notify_death(-1)

	# Assert — 呼叫被拒,且非法序數 -1 沒有被靜默寫入 _death_marks 的鍵集合
	assert_int(result).is_equal(AffinityDataPool.DeathNotifyResult.INVALID_CHARACTER)
	assert_bool(pool._death_marks.has(-1)).is_false()
	assert_int(pool._death_marks.size()).is_equal(0)


# ---- 禁令 death_marks_prefill_or_unguarded_read:正面驗證 --------------------

func test_death_marks_not_prefilled_all_five_characters_are_alive_initially() -> void:
	# Arrange — 剛建構完成、尚未有任何 notify_death() 呼叫
	var pool: AffinityDataPool = AffinityDataPool.new()

	# Act / Assert — 5 名角色全部不在陣亡標記表的鍵集合中(鍵存在本身就是
	# 「已陣亡」;預填會讓全部角色一開局就變成已陣亡,摧毀語意)
	for character: AffinityTypes.Character in AffinityTypes.Character.values():
		assert_bool(pool._death_marks.has(character)).is_false()

	assert_int(pool._death_marks.size()).is_equal(0)


# ---- t_death():兩名成員各查一次,取較早值 -----------------------------------

func test_t_death_returns_null_when_neither_member_has_died() -> void:
	# Arrange — 兩名成員皆未陣亡
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2
	)

	# Act
	var result: Variant = pool.t_death(pair)

	# Assert
	assert_object(result).is_null()


func test_t_death_returns_earlier_value_when_both_members_have_died() -> void:
	# Arrange — 兩名成員在不同時間點各自陣亡
	var pool: AffinityDataPool = AffinityDataPool.new()
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_3, AffinityTypes.Character.CHARACTER_5
	)

	pool._t_now = 4
	pool.notify_death(AffinityTypes.Character.CHARACTER_5)   # 標記於 t_now=4(較早)
	pool._t_now = 10
	pool.notify_death(AffinityTypes.Character.CHARACTER_3)   # 標記於 t_now=10(較晚)

	# Act
	var result: Variant = pool.t_death(pair)

	# Assert — 回傳較早的標記值(4),且回傳型別確實是 int(不是哨兵/null)
	assert_bool(typeof(result) == TYPE_INT).is_true()
	assert_int(result).is_equal(4)
