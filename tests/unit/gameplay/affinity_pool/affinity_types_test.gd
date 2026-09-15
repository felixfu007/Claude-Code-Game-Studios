# AffinityTypes(src/gameplay/affinity_pool/affinity_types.gd)的單元測試。
#
# Story:production/epics/affinity-data-pool/story-001-affinity-types.md(S-001)
# 涵蓋 AC-27a(Pair 恰有 10 種合法值)、AC-56(Pair 穩定名稱存取器)、
# AC-57(Source 穩定名稱存取器,與 AC-56 對稱)。
#
# 純靜態函式、無實例狀態、無節點 —— 不建立任何 Node,不需要 tear-down,
# 不會留下孤兒節點。每個測試自成一組斷言,不共用可變狀態,不依賴執行順序。
extends GdUnitTestSuite


# ---- AC-27a:Pair enum 恰有 10 個合法值 -----------------------------------

func test_pair_enum_has_exactly_ten_values() -> void:
	# Arrange / Act — 靜態檢視 enum 定義本身,C(5,2) = 10
	var values: Array = AffinityTypes.Pair.values()

	# Assert
	assert_int(values.size()).is_equal(10)


# ---- AC-56:Pair 的名稱存取器回傳穩定、與序數無關的字串 ----------------------

func test_pair_find_key_returns_stable_name_independent_of_ordinal() -> void:
	# Arrange — 名稱與 enum 原始碼定義處逐一對應,不是從序數推導出來的
	# （find_key() 是本專案已登記的持久化名稱存取器慣例,見
	# src/ui/cursor/cursor_state.gd 的既有用法)。
	var expected_names_by_value: Dictionary = {
		AffinityTypes.Pair.C1_C2: "C1_C2",
		AffinityTypes.Pair.C1_C3: "C1_C3",
		AffinityTypes.Pair.C1_C4: "C1_C4",
		AffinityTypes.Pair.C1_C5: "C1_C5",
		AffinityTypes.Pair.C2_C3: "C2_C3",
		AffinityTypes.Pair.C2_C4: "C2_C4",
		AffinityTypes.Pair.C2_C5: "C2_C5",
		AffinityTypes.Pair.C3_C4: "C3_C4",
		AffinityTypes.Pair.C3_C5: "C3_C5",
		AffinityTypes.Pair.C4_C5: "C4_C5",
	}

	# Act / Assert — 逐值查詢,名稱須與字面定義一致
	for pair_value: AffinityTypes.Pair in expected_names_by_value:
		var expected_name: String = expected_names_by_value[pair_value]
		assert_str(AffinityTypes.Pair.find_key(pair_value)).is_equal(expected_name)

	# Assert — 10 個名稱互不相同(名稱存取器不會把兩個不同的合法值疊到同一個
	# 字串上,這是「穩定且獨立」的另一半)
	var all_names: Array = []
	for pair_value: AffinityTypes.Pair in expected_names_by_value:
		all_names.append(AffinityTypes.Pair.find_key(pair_value))
	var unique_names: Dictionary = {}
	for name: String in all_names:
		unique_names[name] = true
	assert_int(unique_names.size()).is_equal(10)


# ---- AC-57:Source 的名稱存取器回傳穩定、與序數無關的字串(與 AC-56 對稱)----

func test_source_find_key_returns_stable_name_independent_of_ordinal() -> void:
	# Arrange
	var expected_names_by_value: Dictionary = {
		AffinityTypes.Source.COMBAT_CARD: "COMBAT_CARD",
		AffinityTypes.Source.SUPPORT_CONVERSATION: "SUPPORT_CONVERSATION",
		AffinityTypes.Source.STORY_EVENT: "STORY_EVENT",
	}

	# Act / Assert
	for source_value: AffinityTypes.Source in expected_names_by_value:
		var expected_name: String = expected_names_by_value[source_value]
		assert_str(AffinityTypes.Source.find_key(source_value)).is_equal(expected_name)

	# Assert — 3 個名稱互不相同
	var all_names: Array = []
	for source_value: AffinityTypes.Source in expected_names_by_value:
		all_names.append(AffinityTypes.Source.find_key(source_value))
	var unique_names: Dictionary = {}
	for name: String in all_names:
		unique_names[name] = true
	assert_int(unique_names.size()).is_equal(3)


# ---- 機制四之四:三個公開序數驗證器 ----------------------------------------

func test_is_valid_pair_rejects_out_of_range_ordinal() -> void:
	# Arrange / Act / Assert — 探針 D 已實測:越界輸入乾淨回傳 false、不中止
	assert_bool(AffinityTypes.is_valid_pair(-1)).is_false()
	assert_bool(AffinityTypes.is_valid_pair(999)).is_false()

	# Assert — 合法值必須通過(正面案例,避免函式恆回 false 也能騙過上面兩行)
	assert_bool(AffinityTypes.is_valid_pair(AffinityTypes.Pair.C1_C2)).is_true()
	assert_bool(AffinityTypes.is_valid_pair(AffinityTypes.Pair.C4_C5)).is_true()


func test_is_valid_character_rejects_out_of_range_ordinal() -> void:
	# Arrange / Act / Assert
	assert_bool(AffinityTypes.is_valid_character(-1)).is_false()
	assert_bool(AffinityTypes.is_valid_character(999)).is_false()

	# Assert — 正面案例
	assert_bool(AffinityTypes.is_valid_character(AffinityTypes.Character.CHARACTER_1)).is_true()
	assert_bool(AffinityTypes.is_valid_character(AffinityTypes.Character.CHARACTER_5)).is_true()


func test_is_valid_source_rejects_out_of_range_ordinal() -> void:
	# Arrange / Act / Assert
	assert_bool(AffinityTypes.is_valid_source(-1)).is_false()
	assert_bool(AffinityTypes.is_valid_source(999)).is_false()

	# Assert — 正面案例
	assert_bool(AffinityTypes.is_valid_source(AffinityTypes.Source.COMBAT_CARD)).is_true()
	assert_bool(AffinityTypes.is_valid_source(AffinityTypes.Source.STORY_EVENT)).is_true()


# ---- 機制二:pair_of() 正規化建構函式 --------------------------------------

func test_pair_of_normalizes_argument_order() -> void:
	# Arrange / Act — 同一組人,兩種呼叫順序
	var forward: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2
	)
	var reversed: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_2, AffinityTypes.Character.CHARACTER_1
	)

	# Assert — 兩種順序回傳相同的 Pair,且是正確的那一個
	assert_int(forward).is_equal(AffinityTypes.Pair.C1_C2)
	assert_int(reversed).is_equal(AffinityTypes.Pair.C1_C2)
	assert_int(forward).is_equal(reversed)


func test_pair_of_covers_all_ten_combinations_without_collision() -> void:
	# Arrange — 5 名角色兩兩組合,窮舉全部 10 組,附上各自預期的 Pair
	var expected_by_combination: Array = [
		[AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2, AffinityTypes.Pair.C1_C2],
		[AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_3, AffinityTypes.Pair.C1_C3],
		[AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_4, AffinityTypes.Pair.C1_C4],
		[AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_5, AffinityTypes.Pair.C1_C5],
		[AffinityTypes.Character.CHARACTER_2, AffinityTypes.Character.CHARACTER_3, AffinityTypes.Pair.C2_C3],
		[AffinityTypes.Character.CHARACTER_2, AffinityTypes.Character.CHARACTER_4, AffinityTypes.Pair.C2_C4],
		[AffinityTypes.Character.CHARACTER_2, AffinityTypes.Character.CHARACTER_5, AffinityTypes.Pair.C2_C5],
		[AffinityTypes.Character.CHARACTER_3, AffinityTypes.Character.CHARACTER_4, AffinityTypes.Pair.C3_C4],
		[AffinityTypes.Character.CHARACTER_3, AffinityTypes.Character.CHARACTER_5, AffinityTypes.Pair.C3_C5],
		[AffinityTypes.Character.CHARACTER_4, AffinityTypes.Character.CHARACTER_5, AffinityTypes.Pair.C4_C5],
	]

	# Act / Assert — 逐組驗證,含反向呼叫
	for combination: Array in expected_by_combination:
		var a: AffinityTypes.Character = combination[0]
		var b: AffinityTypes.Character = combination[1]
		var expected_pair: AffinityTypes.Pair = combination[2]
		assert_int(AffinityTypes.pair_of(a, b)).is_equal(expected_pair)
		assert_int(AffinityTypes.pair_of(b, a)).is_equal(expected_pair)

	# Assert — 10 組輸入對應 10 個互不相同的 Pair(沒有兩組合被誤判成同一個)
	var produced_pairs: Dictionary = {}
	for combination: Array in expected_by_combination:
		var pair_result: AffinityTypes.Pair = AffinityTypes.pair_of(combination[0], combination[1])
		produced_pairs[pair_result] = true
	assert_int(produced_pairs.size()).is_equal(10)
