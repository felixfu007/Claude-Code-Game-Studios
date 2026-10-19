# SupportConversationPoolWritePort
# (src/gameplay/narrative/support_conversation_pool_write_port.gd)的整合測試。
#
# 裁決②(2026-10-19 管理者裁決,逐字選項「新增一個專用轉接器(推薦)」)—— 本檔
# 驗證兩件事:①成功路徑把 pair/m/source 原封不動轉送進真實 AffinityDataPool;
# ②池子拒絕時不被靜默吞掉(push_error 曝光 + last_rejection 診斷欄位反映真實拒絕碼)。
#
# 型別:Integration —— 跨 src/gameplay/narrative 與 src/gameplay/affinity_pool 兩個
# 系統的真實接線,比照既有先例
# tests/integration/gameplay/cards/affinity_pool_write_port_test.gd。
#
# AffinityDataPool/AffinityTypes/AffinityRecord/SupportConversationPoolWritePort 皆為
# RefCounted,不建立任何 Node,不會留下孤兒節點,不需要 tear-down。
extends GdUnitTestSuite


# 間諜池 —— 永遠回傳池側 INVALID_PAIR,用於證明本轉接器的拒絕曝光邏輯是對
# 「任何非 NONE 的拒絕碼」一般化判斷,不是只對 ZERO_AMPLITUDE 特例處理。
# 手法比照 tests/integration/gameplay/cards/affinity_pool_write_port_test.gd 的
# _AlwaysInvalidPairPool。
class _AlwaysInvalidPairPool extends AffinityDataPool:
	func append_record(
		_pair: AffinityTypes.Pair, _m: float, _source: AffinityTypes.Source
	) -> WriteRejection:
		return WriteRejection.INVALID_PAIR


# ---- 成功路徑:原封不動轉送 --------------------------------------------------

func test_append_record_forwards_pair_m_source_to_real_pool_on_success() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()
	var port: SupportConversationPoolWritePort = SupportConversationPoolWritePort.new(pool)
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2
	)

	# Act
	port.append_record(pair, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)

	# Assert —— 記錄真的落進池子,source 是 SUPPORT_CONVERSATION 本身(不是被
	# 轉接器悄悄改成別的值,與 src/gameplay/cards/affinity_pool_write_port.gd
	# 那種「source 恆映射成單一常數、不讀參數」的設計不同——本檔的 source 是
	# 原封不動轉送的參數)。
	assert_int(pool._records[pair].size()).is_equal(1)
	var record: AffinityRecord = pool._records[pair].get_at(0)
	assert_int(record.pair).is_equal(pair)
	assert_float(record.m).is_equal_approx(1.0, 0.000000000001)
	assert_int(record.source).is_equal(AffinityTypes.Source.SUPPORT_CONVERSATION)
	assert_int(port.last_rejection).is_equal(AffinityDataPool.WriteRejection.NONE)


func test_append_record_forwards_negative_magnitude_unchanged() -> void:
	# Arrange —— 負向 valence 的寫入量值(SupportConversationRules.MAGNITUDE_ABS 的
	# 帶負號版本),確認本檔不對 m 做任何轉換或取絕對值。
	var pool: AffinityDataPool = AffinityDataPool.new()
	var port: SupportConversationPoolWritePort = SupportConversationPoolWritePort.new(pool)
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_3, AffinityTypes.Character.CHARACTER_4
	)

	# Act
	port.append_record(pair, -1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)

	# Assert
	var record: AffinityRecord = pool._records[pair].get_at(0)
	assert_float(record.m).is_equal_approx(-1.0, 0.000000000001)


# ---- 拒絕路徑:不可靜默吞掉 --------------------------------------------------

func test_append_record_zero_amplitude_rejection_is_exposed_not_swallowed() -> void:
	# AffinityDataPool.append_record() 對 m == 0.0 回傳 WriteRejection.ZERO_AMPLITUDE
	# ——這是真實情境下 NEUTRAL 若被誤接到本埠時會發生的拒絕(裁決③已改為根本
	# 不呼叫,但本檔驗證「萬一真的被呼叫」時轉接器自己的防線)。
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()
	var port: SupportConversationPoolWritePort = SupportConversationPoolWritePort.new(pool)
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_5
	)
	var call_append: Callable = func() -> void:
		port.append_record(pair, 0.0, AffinityTypes.Source.SUPPORT_CONVERSATION)

	# Act & Assert —— 拒絕必須曝光(push_error),不可靜默吞掉
	await assert_error(call_append).is_push_error(any_string())

	# Assert —— 診斷欄位記下真實拒絕碼,且池子沒有真的寫入任何記錄
	assert_int(port.last_rejection).append_failure_message(
		"last_rejection 應反映池子真實回傳的 ZERO_AMPLITUDE,而不是維持預設的 NONE"
	).is_equal(AffinityDataPool.WriteRejection.ZERO_AMPLITUDE)
	assert_int(pool._records[pair].size()).append_failure_message(
		"被拒絕的寫入不應該在池子裡留下任何記錄"
	).is_equal(0)


func test_sensitivity_proof_generalizes_to_any_non_none_rejection() -> void:
	# 敏感度證明:本轉接器的拒絕曝光邏輯是 `!= WriteRejection.NONE` 的一般化判斷,
	# 不是只對 ZERO_AMPLITUDE 寫死特例 —— 間諜池永遠回傳 INVALID_PAIR(與上面
	# ZERO_AMPLITUDE 不同的拒絕碼),證明任何非 NONE 的拒絕碼都會被曝光。
	# Arrange
	var spy_pool: _AlwaysInvalidPairPool = _AlwaysInvalidPairPool.new()
	var port: SupportConversationPoolWritePort = SupportConversationPoolWritePort.new(spy_pool)
	var call_append: Callable = func() -> void:
		port.append_record(AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)

	# Act & Assert
	await assert_error(call_append).is_push_error(any_string())
	assert_int(port.last_rejection).append_failure_message(
		"敏感度證明失敗:換了一種拒絕碼(INVALID_PAIR),last_rejection 卻沒有跟著反映"
		+ " —— 代表曝光邏輯可能寫死只認 ZERO_AMPLITUDE,而不是一般化判斷。"
	).is_equal(AffinityDataPool.WriteRejection.INVALID_PAIR)


func test_last_rejection_defaults_to_none_before_any_call() -> void:
	# Arrange & Act
	var pool: AffinityDataPool = AffinityDataPool.new()
	var port: SupportConversationPoolWritePort = SupportConversationPoolWritePort.new(pool)

	# Assert
	assert_int(port.last_rejection).is_equal(AffinityDataPool.WriteRejection.NONE)
