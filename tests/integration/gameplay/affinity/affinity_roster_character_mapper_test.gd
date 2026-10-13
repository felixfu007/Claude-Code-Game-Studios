# AffinityRosterCharacterMapper(src/gameplay/affinity/
# affinity_roster_character_mapper.gd)的整合測試 ——
# production/epics/affinity-position-chain/
# story-004-affinity-pool-instance-and-id-mapping.md(P-2)。
#
# 涵蓋工作單 QA Test Cases 的「驗證 id 對映邊界」一項:roster id 1~5 應對映到
# 合法 Character 序數;roster id 6~10(敵方)或任何超出 1~10 的值,應被
# is_valid_character() 擋下,不得未驗證直接送進 pair_of()。
#
# 🔴 工作單另一項 QA Test Case(「驗證池擁有者存活」)不在本測試涵蓋範圍內——
# 本 story 依協調者 2026-10-13 前置反查的範圍收斂,不建立/不接線
# AffinityDataPool 的擁有權(P-1 剩餘的「讓 #5 側透過建構子注入取得池參照」
# 留給 story-005,見工作單「實作決定」小節)。本檔只測 P-2。
#
# 分類為 Integration(工作單 Type 欄明文)。理由:被測函式本身是純函式,但它
# 存在的理由是讓兩個獨立子系統(#5 讀取側與 #6/#1 既有寫入側)對同一份
# roster id 達成一致——test_mapper_agrees_with_write_port_on_the_same_pair
# 斷言的核心正是這個跨子系統一致性,不是單一函式的孤立行為,故依工作單指示
# 放在 tests/integration/gameplay/affinity/(新建,比照既有
# tests/integration/gameplay/affinity_pool/ 慣例)。
#
# 全鏈路(AffinityRosterCharacterMapper/AffinityTypes/AffinityPoolWritePort/
# AffinityDataPool)皆為 RefCounted,不建立任何 Node,不需要 tear-down,
# 不會留下孤兒節點。
#
# 🔴 敏感度證明揭露(.claude/rules/test-standards.md 2026-09-16 裁決,逐條
# 寫下「證不了」的理由,不湊數):下方全部三條測試的被測對象都是
# AffinityRosterCharacterMapper.character_for_roster_id() 這個 static 純
# 函式——GDScript 的 static 方法沒有可覆寫的繼承鏈,無法用間諜子類別注入
# 故意改壞的版本來證明「真的會抓到回歸」(該規則登記的「已知證明不了」A 類:
# 斷言對象是 static 純函式)。本檔選擇不硬湊一個假的「故意算錯的平行版本」
# 比較——那種寫法只能證明「這段測試自己的算術是對的」,證明不了「真實的
# assert 會抓到生產程式碼的回歸」,屬於該規則明文禁止的「假證明比沒有證明
# 更糟」。下方三條測試因此皆誠實標記為 A 類、不可證,不另外提供
# test_sensitivity_proof_* 函式。
extends GdUnitTestSuite


# ---- 正面案例:roster id 1~5 對映到正確的 Character 序數(對應甲乙丙丁戊)----
# 🔴 A 類,不可證(見檔頭揭露)。

func test_valid_player_roster_ids_map_to_expected_characters() -> void:
	# Arrange
	var expected_by_roster_id: Dictionary = {
		1: AffinityTypes.Character.CHARACTER_1,
		2: AffinityTypes.Character.CHARACTER_2,
		3: AffinityTypes.Character.CHARACTER_3,
		4: AffinityTypes.Character.CHARACTER_4,
		5: AffinityTypes.Character.CHARACTER_5,
	}

	# Act / Assert
	for roster_id: int in expected_by_roster_id:
		var result: Variant = AffinityRosterCharacterMapper.character_for_roster_id(roster_id)
		assert_int(result).append_failure_message(
			"roster id %d should map to Character ordinal %s" % [roster_id, expected_by_roster_id[roster_id]]
		).is_equal(expected_by_roster_id[roster_id])


# ---- 負面案例:敵方 roster id(6~10)與越界值一律回傳 null,不得被誤讀為合法 ----
# 🔴 A 類,不可證(見檔頭揭露)。

func test_enemy_and_out_of_range_roster_ids_return_null() -> void:
	# Arrange — 6~10 為敵方(assets/data/units/vs01_roster.txt),另補兩個明顯
	# 越界值(0、負值)
	var invalid_roster_ids: Array[int] = [0, -1, 6, 7, 8, 9, 10, 11, 999]

	# Act / Assert
	for roster_id: int in invalid_roster_ids:
		var result: Variant = AffinityRosterCharacterMapper.character_for_roster_id(roster_id)
		assert_object(result).append_failure_message(
			(
				"roster id %d is outside the player range (1~5) and must return null, not a "
				+ "silently-wrong Character ordinal."
			) % roster_id
		).is_null()


# ---- 跨子系統一致性:讀取側(本類別)與寫入側(AffinityPoolWritePort)對同一組
# roster id 必須算出完全相同的 Pair——這是「抽成共用常數」這個實作決定真正要
# 保證的事:不是「今天剛好答案一致」,而是結構上不可能不一致,因為兩側呼叫的
# 是同一個 AffinityPoolWritePort.ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET。
# 🔴 A 類,不可證(見檔頭揭露——兩側共用同一個 const,沒有可供故障注入的分支:
# 唯一能讓兩側不一致的方式是重新引入第二份偏移量常數,那是源碼層級的回歸,
# 不是本測試能透過子類別注入證明「抓得到」的那種行為性故障)。

func test_mapper_agrees_with_write_port_on_the_same_pair() -> void:
	# Arrange — 甲乙(roster id 1、2)寫入池,讀取側獨立轉換同一組 roster id
	var pool: AffinityDataPool = AffinityDataPool.new()
	var port: AffinityPoolWritePort = AffinityPoolWritePort.new(pool)
	var rejection: AffinityWritePort.Rejection = port.append_record(
		1, 2, 3, AffinityWritePort.SOURCE_COMBAT_CARD
	)
	assert_int(rejection).append_failure_message(
		"Arrange step itself failed to write — the agreement assertion below would be "
		+ "meaningless if the write never landed."
	).is_equal(AffinityWritePort.Rejection.NONE)

	# Act — 讀取側獨立做同一組轉換
	var char_a: Variant = AffinityRosterCharacterMapper.character_for_roster_id(1)
	var char_b: Variant = AffinityRosterCharacterMapper.character_for_roster_id(2)
	# 驗證兩個轉換本身成功(回傳合法 Character 序數,不是 null)——故意不用
	# assert_object():GdUnitObjectAssertImpl._init()
	# (addons/gdUnit4/src/asserts/GdUnitObjectAssertImpl.gd)對非 null 的
	# BOOL/INT/FLOAT/STRING 值會主動回報「unexpected type」錯誤,因為它假設
	# 被斷言對象是真正的 Object 參照。char_a/char_b 是 enum(底層為 int)
	# 而非 Object,即使轉換成功也會被 assert_object() 誤判為錯誤——這不是
	# AffinityRosterCharacterMapper 的 bug,是本測試一開始選錯了斷言方法。
	# 改用 assert_int() 直接核對預期值,同時也比單純的「非 null」更嚴格。
	assert_int(char_a).append_failure_message(
		"character_for_roster_id(1) should map to CHARACTER_1 — arrange/act setup is broken."
	).is_equal(AffinityTypes.Character.CHARACTER_1)
	assert_int(char_b).append_failure_message(
		"character_for_roster_id(2) should map to CHARACTER_2 — arrange/act setup is broken."
	).is_equal(AffinityTypes.Character.CHARACTER_2)
	var mapper_pair: AffinityTypes.Pair = AffinityTypes.pair_of(char_a, char_b)

	# Assert — 讀取側算出的 Pair,與寫入側實際落地在池裡的 Pair 鍵,是同一個
	assert_int(pool._records[mapper_pair].size()).append_failure_message(
		(
			"AffinityRosterCharacterMapper and AffinityPoolWritePort disagreed on which Pair "
			+ "roster ids (1, 2) belong to — the shared-constant guarantee this story relies on "
			+ "would be broken."
		)
	).is_equal(1)
