# AffinityRules(src/gameplay/affinity/affinity_rules.gd)的單元測試。
#
# 對照組是原型 prototypes/affinity-position-concept-v5/prototype.html 的
# affinityDelta():
#   正關係 距離1 → +3、距離2 → 0、距離3 以上 → -1
#   負關係 距離1 → -1、距離2 → 0、距離3 以上 → +2
#
# 原型另有 activeDeltasAt() 的「同一單位同時只有最近一條正關係生效,其餘
# 抑制」簡化。design/gdd/affinity-position-chain.md 的 R4(2026-08-31 本次
# 裁決)已推翻這條規則:現在每條線一律生效、逐條加總,不存在任何抑制
# ——AC-R4a/AC-R4b 是這項推翻的直接驗證。R7 另外新增 Φ 的硬性夾限
# (PHI_MIN=-4、PHI_MAX=+12,見 AC-R7/AC-R7b/AC-MIX/AC-F3),線數不設上限後
# 這道夾限會在合法佈局下真的作用,不是只在資料寫錯時才觸發的保險絲。
#
# 純函式、無狀態、無節點 —— 不建立任何 Node,也不需要 tear-down,
# 不會留下孤兒節點。每個測試自備 positions 與 links,不共用狀態,
# 因此不依賴執行順序。命名慣例沿用既有先例
# tests/unit/gameplay/combat/combat_rules_test.gd 的 test_[scenario]_[expected]。
extends GdUnitTestSuite

# 配對表以資料列字串提供,經正式解析路徑建立,不手動塞欄位。
# ⚠️ 以下常數是為了驗證「規則」而合成的假配對,不是本作的真實人際關係。
# 遊戲的真實配對(甲乙正、丙丁負、戊無線)來自
# design/narrative/characters.md 第三節,只在 affinity_link_test.gd 裡斷言。
const LINK_1_2_POSITIVE: String = "1,2,POSITIVE,1"
const LINK_3_4_POSITIVE: String = "3,4,POSITIVE,1"
const LINK_2_5_NEGATIVE: String = "2,5,NEGATIVE,1"
const LINK_1_3_POSITIVE: String = "1,3,POSITIVE,1"

const ORIGIN: Vector2i = Vector2i(0, 0)

# AC-R2:涵蓋距離 0、1、2、3、以及 vs01 棋盤(13×6)的角對角最大距離 17,
# 共 24 組座標對。每一組只斷言「兩份獨立實作對同一組座標算出同一個距離」,
# 不合併成同一個函式——R2 明文允許兩份實作並存,合併會讓 Gameplay 橫向
# 耦合到戰鬥模組(見 AffinityRules.manhattan_distance 的文件註解)。
const _R2_FROM_CELLS: Array[Vector2i] = [
	# 距離 0
	Vector2i(0, 0), Vector2i(5, 5), Vector2i(-3, 2), Vector2i(12, 5),
	# 距離 1
	Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(6, 3),
	# 距離 2
	Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(4, 4),
	# 距離 3
	Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(2, 3),
	# 中距離(4~10),補齊樣本廣度
	Vector2i(0, 0), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 0),
	# 棋盤最大距離:vs01 為 13×6,角對角 = (13-1)+(6-1) = 17
	Vector2i(0, 0), Vector2i(12, 0), Vector2i(0, 5),
]
const _R2_TO_CELLS: Array[Vector2i] = [
	# 距離 0
	Vector2i(0, 0), Vector2i(5, 5), Vector2i(-3, 2), Vector2i(12, 5),
	# 距離 1
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(7, 3),
	# 距離 2
	Vector2i(2, 0), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(4, 2),
	# 距離 3
	Vector2i(3, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(4, 4),
	# 中距離(4~10)
	Vector2i(4, 0), Vector2i(0, 6), Vector2i(6, 4), Vector2i(5, 5),
	# 棋盤最大距離 17
	Vector2i(12, 5), Vector2i(0, 5), Vector2i(12, 0),
]


# ---- 測試資料工廠 --------------------------------------------------------

func _links(lines: Array[String]) -> Array[AffinityLink]:
	return AffinityLink.links_from_text("\n".join(lines))


# 讓「單位 1 與夥伴相距 distance 格」的一組座標。
func _pair_positions(partner_id: int, distance: int) -> Dictionary[int, Vector2i]:
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[partner_id] = ORIGIN + Vector2i(distance, 0)
	return positions


# ---- delta():正關係三種距離 -------------------------------------------

func test_delta_positive_distance_one_returns_plus_three() -> void:
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 1, 1)).is_equal(3)


func test_delta_positive_distance_two_returns_zero() -> void:
	# 距離 2 是刻意的死區:靠近才有獎勵,離太遠才有懲罰,中間不動
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 2, 1)).is_equal(0)


func test_delta_positive_distance_three_returns_minus_one() -> void:
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 3, 1)).is_equal(-1)


func test_delta_positive_distance_far_beyond_three_stays_minus_one() -> void:
	# 3 以上是同一段,不隨距離加深
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 9, 1)).is_equal(-1)


# ---- delta():負關係三種距離 -------------------------------------------

func test_delta_negative_distance_one_returns_minus_one() -> void:
	assert_int(AffinityRules.delta(AffinityLink.Polarity.NEGATIVE, 1, 1)).is_equal(-1)


func test_delta_negative_distance_two_returns_zero() -> void:
	assert_int(AffinityRules.delta(AffinityLink.Polarity.NEGATIVE, 2, 1)).is_equal(0)


func test_delta_negative_distance_three_returns_plus_two() -> void:
	assert_int(AffinityRules.delta(AffinityLink.Polarity.NEGATIVE, 3, 1)).is_equal(2)


func test_delta_distance_zero_returns_zero_for_both_polarities() -> void:
	# 同格在盤面上不會發生,但規則必須有定義且不得爆炸
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 0, 1)).is_equal(0)
	assert_int(AffinityRules.delta(AffinityLink.Polarity.NEGATIVE, 0, 1)).is_equal(0)


func test_delta_amp_multiplies_the_base_value() -> void:
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 1, 2)).is_equal(6)


# ---- bonus_for():整體加成 ----------------------------------------------

func test_bonus_for_positive_pair_adjacent_grants_plus_three() -> void:
	# AC-F1
	# Arrange
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = _pair_positions(2, 1)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(3)


func test_bonus_for_positive_pair_far_apart_costs_one() -> void:
	# Arrange
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = _pair_positions(2, 4)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(-1)


func test_bonus_for_negative_pair_adjacent_costs_one() -> void:
	# Arrange — 從單位 2 的角度看 2-5 這條負關係
	var links: Array[AffinityLink] = _links([LINK_2_5_NEGATIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[2] = ORIGIN
	positions[5] = ORIGIN + Vector2i(1, 0)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(2, positions, links)).is_equal(-1)


func test_bonus_for_negative_pair_far_apart_grants_plus_two() -> void:
	# Arrange
	var links: Array[AffinityLink] = _links([LINK_2_5_NEGATIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[2] = ORIGIN
	positions[5] = ORIGIN + Vector2i(0, 3)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(2, positions, links)).is_equal(2)


func test_bonus_for_positive_and_negative_links_sum_together() -> void:
	# AC-R6 — 相鄰合作(+3)與遠離對立(+2)各自單獨存在時不相等,且各自正確
	# Arrange — 單位 2:與 1 相鄰(正 +3),與 5 相距 3(負 +2)
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE, LINK_2_5_NEGATIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[2] = ORIGIN
	positions[1] = ORIGIN + Vector2i(1, 0)
	positions[5] = ORIGIN + Vector2i(0, 3)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(2, positions, links)).is_equal(5)


func test_bonus_for_unit_with_no_links_is_zero() -> void:
	# Arrange — 單位 5 不在任何一條配對上
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE, LINK_3_4_POSITIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[2] = ORIGIN + Vector2i(1, 0)
	positions[3] = ORIGIN + Vector2i(2, 0)
	positions[4] = ORIGIN + Vector2i(3, 0)
	positions[5] = ORIGIN + Vector2i(4, 0)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(5, positions, links)).is_equal(0)


func test_bonus_for_unit_absent_from_positions_is_zero() -> void:
	# Arrange — 單位不在盤面上(陣亡或尚未上場)
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[2] = ORIGIN

	# Act / Assert
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(0)


func test_bonus_for_ignores_link_whose_partner_is_absent() -> void:
	# Arrange — 夥伴陣亡後那條線整條不算,原型同樣跳過死亡夥伴
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN

	# Act / Assert
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(0)


# ---- R4:所有關係線全部生效,逐條加總,不存在抑制 --------------------------

func test_bonus_for_two_positive_links_at_different_distances_sums_both() -> void:
	# AC-R4a(本系統改動的金絲雀測試)—— R4 推翻了原型「只取最近一條正關係」
	# 的簡化。若這裡回傳 +3,代表實作仍在跑舊邏輯,測試必須失敗。
	# Arrange — 單位 1 同時與 2(距離 1)和 3(距離 5)有兩條正關係
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE, LINK_1_3_POSITIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[2] = ORIGIN + Vector2i(1, 0)
	positions[3] = ORIGIN + Vector2i(5, 0)

	# Act / Assert — 3 + (-1) = 2
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(2)


func test_bonus_for_two_positive_links_plus_one_negative_adjacent_sums_to_one() -> void:
	# AC-R4b
	# Arrange — 承上,再加一條負向距離 1 的線
	var links: Array[AffinityLink] = _links(
		[LINK_1_2_POSITIVE, LINK_1_3_POSITIVE, "1,4,NEGATIVE,1"]
	)
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[2] = ORIGIN + Vector2i(1, 0)
	positions[3] = ORIGIN + Vector2i(5, 0)
	positions[4] = ORIGIN + Vector2i(0, 1)

	# Act / Assert — 3 + (-1) + (-1) = 1
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(1)


func test_bonus_for_two_negative_links_at_different_distances_sums_both() -> void:
	# R4 對負向關係同樣成立——這條線原本測的是「正向抑制規則不誤傷負向」,
	# 該抑制規則已被 R4 整條刪除,故改名為單純的負向加總回歸測試,不再用
	# 「抑制」這個已經不存在的概念描述它。
	# Arrange
	var lines_text: Array[String] = ["1,2,NEGATIVE,1", "1,3,NEGATIVE,1"]
	var links: Array[AffinityLink] = _links(lines_text)
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[2] = ORIGIN + Vector2i(1, 0)
	positions[3] = ORIGIN + Vector2i(3, 0)

	# Act / Assert — -1 + 2 = 1
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(1)


# ---- R7/Formula 三:Φ 的硬性夾限,線數不設上限後會在合法佈局下真的作用 ----

func test_bonus_for_six_positive_adjacent_links_clamps_to_plus_twelve() -> void:
	# AC-R7(改寫:6 條線現為合法佈局,不是資料錯誤)—— 理論和 +18,
	# 證明夾限在合法佈局下確實作用。
	# Arrange
	var lines: Array[String] = []
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	for partner_id: int in range(2, 8):  # 2..7 → 6 個夥伴
		lines.append("1,%d,POSITIVE,1" % partner_id)
		positions[partner_id] = ORIGIN + Vector2i(1, 0)
	var links: Array[AffinityLink] = _links(lines)

	# Act / Assert — 6×(+3) = +18,夾限壓回恰為 +12
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(12)


func test_bonus_for_single_link_with_amp_ten_still_clamps_to_plus_twelve() -> void:
	# AC-R7b — 夾限獨立於線數:單一連線但 amp=10(理論和 +30 = 3×10)。
	# amp 由未受驗證的 CSV 欄位解析而來,此路徑現在就活著
	# (見 affinity_link_test.gd 的 amp 診斷測試)。
	# Arrange
	var links: Array[AffinityLink] = _links(["1,2,POSITIVE,10"])
	var positions: Dictionary[int, Vector2i] = _pair_positions(2, 1)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(12)


func test_bonus_for_four_positive_adjacent_plus_one_negative_far_clamps_to_plus_twelve() -> void:
	# AC-MIX — 混合極性溢位:4 條正向相鄰(+12)加 1 條負向距≥3(+2),
	# 理論和 +14,是合法佈局而非資料錯誤:棋盤只有四個正交相鄰格
	# (上/下/左/右,|dx|+|dy|==1 恰有四組整數解,不含對角),四個正向
	# 夥伴各佔一格,彼此不同格、也不與 ORIGIN 同格,因此這是真實可達的
	# 佈局,不是靠「疊在同一格」這種棋盤禁止的手法湊出來的。若實作把
	# clamp() 當裝飾省略,這是唯一會抓到的測試(4 條正向本身就已飽和
	# +12,不需要負向線也能觸發夾限——加入負向線是為了證明「混合極性」
	# 不會被漏算)。
	# Arrange
	var lines: Array[String] = []
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	var adjacent_offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	for i: int in range(4):  # 2,3,4,5 → 4 條正向相鄰,各佔一個相鄰格
		var partner_id: int = i + 2
		lines.append("1,%d,POSITIVE,1" % partner_id)
		positions[partner_id] = ORIGIN + adjacent_offsets[i]
	lines.append("1,6,NEGATIVE,1")
	positions[6] = ORIGIN + Vector2i(3, 0)  # 距離 3 → 負向遠離 +2
	var links: Array[AffinityLink] = _links(lines)

	# Act / Assert — 4×(+3) + (+2) = +14,夾限壓回恰為 +12
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(12)


func test_bonus_for_five_positive_links_fourth_adjacent_fifth_in_dead_zone_is_plus_twelve() -> void:
	# AC-F2 — 具體佈局抽查:4 條距離 1、第 5 條落在距離 2 死區(淨貢獻 0)。
	# 這只是一個抽查案例,不代表「第 5 條只能落在死區」——那個宣稱已被
	# AC-MIX 推翻(公式二:距離 ≥3 的格子不稀缺)。
	# Arrange
	var lines: Array[String] = []
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	for partner_id: int in range(2, 6):  # 2,3,4,5 → 4 條距離 1
		lines.append("1,%d,POSITIVE,1" % partner_id)
		positions[partner_id] = ORIGIN + Vector2i(1, 0)
	lines.append("1,6,POSITIVE,1")
	positions[6] = ORIGIN + Vector2i(2, 0)  # 距離 2 死區
	var links: Array[AffinityLink] = _links(lines)

	# Act / Assert — 4×(+3) + 0 = +12(此案例本身未觸發夾限,恰好等於上限)
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(12)


func test_bonus_for_five_negative_adjacent_links_clamps_to_minus_four() -> void:
	# AC-F3 — 下界夾限,與 AC-R7 對稱。理論和 -5,壓回恰為 -4。
	# Arrange
	var lines: Array[String] = []
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	for partner_id: int in range(2, 7):  # 2..6 → 5 條負向相鄰
		lines.append("1,%d,NEGATIVE,1" % partner_id)
		positions[partner_id] = ORIGIN + Vector2i(1, 0)
	var links: Array[AffinityLink] = _links(lines)

	# Act / Assert — 5×(-1) = -5,夾限壓回恰為 -4
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(-4)


# ---- R8:每條線對兩端同時生效,雙方看到的狀態必然一致 -----------------------

func test_line_status_is_identical_from_either_endpoint() -> void:
	# AC-R8(改寫:點名存取器)—— 刻意讓 A、B 各自還有別的關係線,證明本測試
	# 測的是「同一條線」的對稱性,不是兩個單位總和加成恰好相等的巧合。
	# ⚠️ 不得改用 bonus_for(A) 對比 bonus_for(B) 做這個測試——只要 A、B
	# 各自還有別的關係線,兩者的總和本來就該不相等,那樣測根本沒測到 R8。
	# Arrange — A(1)—B(2) 一條正向線;A 另有一條線到 3,B 另有一條線到 5
	var links: Array[AffinityLink] = _links(
		[LINK_1_2_POSITIVE, LINK_1_3_POSITIVE, LINK_2_5_NEGATIVE]
	)
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[2] = ORIGIN + Vector2i(1, 0)
	positions[3] = ORIGIN + Vector2i(5, 0)
	positions[5] = ORIGIN + Vector2i(0, 3)

	# Act
	var lines_from_a: Array[AffinityLineStatus] = AffinityRules.lines_for(1, positions, links)
	var lines_from_b: Array[AffinityLineStatus] = AffinityRules.lines_for(2, positions, links)

	var entry_a_to_b: AffinityLineStatus = null
	for status: AffinityLineStatus in lines_from_a:
		if status.partner_id == 2:
			entry_a_to_b = status
	var entry_b_to_a: AffinityLineStatus = null
	for status: AffinityLineStatus in lines_from_b:
		if status.partner_id == 1:
			entry_b_to_a = status

	# Assert
	assert_object(entry_a_to_b).is_not_null()
	assert_object(entry_b_to_a).is_not_null()
	assert_int(entry_a_to_b.delta).is_equal(entry_b_to_a.delta)
	assert_int(entry_a_to_b.polarity).is_equal(entry_b_to_a.polarity)


# ---- R9:陣亡/離場單位的線立即整條失效,無快取 ------------------------------

func test_partner_phi_drops_by_three_immediately_when_unit_removed_from_positions() -> void:
	# AC-R9(改寫:移除 tick 概念)—— 在同一個測試函式內、中間不呼叫任何
	# 重置或清快取方法,查詢 partner 的 Φ 必須立即反映移除後的新狀態。
	# 不使用 await 畫格——本系統沒有更新迴圈(R10),那樣寫只會替 headless
	# CI 引入不必要的不穩定。
	# Arrange — Y(1)與 partner(2)有一條正向距離 1 線
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = _pair_positions(2, 1)

	# Act
	var before: int = AffinityRules.bonus_for(2, positions, links)
	positions.erase(1)  # Y 離場,無需重置或清快取
	var after: int = AffinityRules.bonus_for(2, positions, links)

	# Assert — 立即減少 3
	assert_int(before).is_equal(3)
	assert_int(after).is_equal(0)
	assert_int(before - after).is_equal(3)


# ---- R10:純查詢,不改動輸入,重複呼叫結果相同 ------------------------------

func test_bonus_for_at_same_inputs_twice_yields_equal_outputs_and_leaves_inputs_untouched() -> void:
	# AC-R10a(改寫:今日可測)—— 相同輸入連查兩次,輸出相等且傳入的
	# positions/links 於呼叫前後內容不變。
	# Arrange
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE, LINK_2_5_NEGATIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[2] = ORIGIN + Vector2i(1, 0)
	positions[5] = ORIGIN + Vector2i(0, 3)
	var positions_snapshot: Dictionary[int, Vector2i] = positions.duplicate(true)
	var links_snapshot: Array = []
	for link: AffinityLink in links:
		links_snapshot.append([link.unit_a, link.unit_b, link.polarity, link.amp])

	# Act
	var first: int = AffinityRules.bonus_for_at(1, positions[1], positions, links)
	var second: int = AffinityRules.bonus_for_at(1, positions[1], positions, links)

	# Assert — 輸出相等
	assert_int(first).is_equal(second)
	# Assert — 輸入未被改動
	assert_bool(positions == positions_snapshot).is_true()
	for i: int in range(links.size()):
		var link: AffinityLink = links[i]
		var snapshot: Array = links_snapshot[i]
		assert_int(link.unit_a).is_equal(snapshot[0])
		assert_int(link.unit_b).is_equal(snapshot[1])
		assert_int(link.polarity).is_equal(snapshot[2])
		assert_int(link.amp).is_equal(snapshot[3])


# ---- 給畫線用的介面 ------------------------------------------------------

func test_lines_for_reports_endpoints_distance_and_state() -> void:
	# Arrange
	var links: Array[AffinityLink] = _links([LINK_2_5_NEGATIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[2] = ORIGIN
	positions[5] = ORIGIN + Vector2i(1, 0)

	# Act
	var lines: Array[AffinityLineStatus] = AffinityRules.lines_for(2, positions, links)

	# Assert
	assert_int(lines.size()).is_equal(1)
	assert_int(lines[0].unit_id).is_equal(2)
	assert_int(lines[0].partner_id).is_equal(5)
	assert_int(lines[0].distance).is_equal(1)
	assert_int(lines[0].delta).is_equal(-1)
	assert_int(lines[0].state).is_equal(AffinityLineStatus.State.NEGATIVE)


func test_lines_for_distance_two_reports_neutral_state() -> void:
	# Arrange
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = _pair_positions(2, 2)

	# Act
	var lines: Array[AffinityLineStatus] = AffinityRules.lines_for(1, positions, links)

	# Assert — 有連線但目前不影響數值,畫中性色
	assert_int(lines[0].state).is_equal(AffinityLineStatus.State.NEUTRAL)
	assert_int(lines[0].delta).is_equal(0)


func test_board_lines_returns_one_entry_per_link_with_both_units_present() -> void:
	# Arrange — 三條配對,但單位 5 不在盤面上,故 2-5 那條不畫
	var links: Array[AffinityLink] = _links(
		[LINK_1_2_POSITIVE, LINK_3_4_POSITIVE, LINK_2_5_NEGATIVE]
	)
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[2] = ORIGIN + Vector2i(1, 0)
	positions[3] = ORIGIN + Vector2i(0, 4)
	positions[4] = ORIGIN + Vector2i(1, 4)

	# Act
	var lines: Array[AffinityLineStatus] = AffinityRules.board_lines(positions, links)

	# Assert
	assert_int(lines.size()).is_equal(2)
	assert_int(lines[0].unit_id).is_equal(1)
	assert_int(lines[0].partner_id).is_equal(2)
	assert_int(lines[0].state).is_equal(AffinityLineStatus.State.POSITIVE)
	assert_int(lines[1].unit_id).is_equal(3)
	assert_int(lines[1].partner_id).is_equal(4)


func test_bonus_for_at_previews_a_move_without_touching_positions() -> void:
	# Arrange — 單位 1 目前離夥伴 4 格(-1),預覽走到相鄰格(+3)
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = _pair_positions(2, 4)
	var preview_cell: Vector2i = positions[2] + Vector2i(1, 0)

	# Act
	var current: int = AffinityRules.bonus_for(1, positions, links)
	var preview: int = AffinityRules.bonus_for_at(1, preview_cell, positions, links)

	# Assert — 預覽不得改動輸入
	assert_int(current).is_equal(-1)
	assert_int(preview).is_equal(3)
	assert_int(positions[1].x).is_equal(ORIGIN.x)
	assert_int(positions[1].y).is_equal(ORIGIN.y)


# ---- R2:與 CombatRules 的距離判定一致(兩份獨立實作,測到一致) -------------

func test_manhattan_distance_agrees_with_combat_rules_across_boundary_distances() -> void:
	# AC-R2(改寫)—— 至少 20 組涵蓋邊界距離(0、1、2、3、棋盤最大值)的座標
	# 對,逐組比對 AffinityRules.manhattan_distance 與 CombatRules 射程判定
	# 所隱含的距離。這是「兩份實作測到一致」,不是「同一個函式」——後者是
	# 黑箱測試在結構上無法驗證的事(CombatRules._manhattan_distance 是私有
	# 函式,見 R2)。
	assert_int(_R2_FROM_CELLS.size()).is_equal(_R2_TO_CELLS.size())
	assert_int(_R2_FROM_CELLS.size()).is_equal(24)

	for i: int in _R2_FROM_CELLS.size():
		var from_cell: Vector2i = _R2_FROM_CELLS[i]
		var to_cell: Vector2i = _R2_TO_CELLS[i]
		var distance: int = AffinityRules.manhattan_distance(from_cell, to_cell)

		if distance == 0:
			# is_in_range 對距離 0 恆回傳 false,不論範圍——用一個涵蓋幾乎
			# 任何距離的寬範圍[0,999],唯一會讓它回傳 false 的情況就是
			# CombatRules 內部算出的距離也剛好是 0。
			assert_bool(CombatRules.is_in_range(from_cell, to_cell, 0, 999)).is_false()
		else:
			assert_bool(
				CombatRules.is_in_range(from_cell, to_cell, distance, distance)
			).is_true()
			assert_bool(
				CombatRules.is_in_range(from_cell, to_cell, 0, distance - 1)
			).is_false()
			assert_bool(
				CombatRules.is_in_range(from_cell, to_cell, distance + 1, 999)
			).is_false()
