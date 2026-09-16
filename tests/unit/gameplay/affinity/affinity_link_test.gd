# AffinityLink(src/gameplay/affinity/affinity_link.gd)的單元測試。
#
# 只測「解析」,不測「讀檔」—— 解析與讀檔是分開的兩件事,這正是這個模組
# 把 links_from_text() 和檔案存取拆開的理由。
#
# 純函式、無狀態、無節點 —— 不建立任何 Node,也不需要 tear-down,
# 不會留下孤兒節點。命名慣例沿用既有先例
# tests/unit/gameplay/units/unit_test.gd 的 test_[scenario]_[expected]。
extends GdUnitTestSuite

# 測試資料以具名常數提供,不在斷言裡塞魔術字串。
# ⚠️ 以下常數是「餵給解析器的合成資料」,不是本作的真實配對表 ——
# 例如 2,5 這一對在遊戲裡並不存在。真實配對表只在
# test_links_from_text_loads_vs01_file_returns_the_two_canon_links() 裡斷言,
# 權威來源是 design/narrative/characters.md 第三節。
const LINE_POSITIVE: String = "1,2,POSITIVE,1"
const LINE_NEGATIVE: String = "2,5,NEGATIVE,1"
const LINE_AMPLIFIED: String = "3,4,POSITIVE,2"
const VS01_LINKS_PATH: String = "res://assets/data/affinity/vs01_affinity_links.txt"


# ---- from_csv_line() ----------------------------------------------------

func test_from_csv_line_parses_every_field_correctly() -> void:
	# Act
	var link: AffinityLink = AffinityLink.from_csv_line(LINE_POSITIVE)

	# Assert
	assert_int(link.unit_a).is_equal(1)
	assert_int(link.unit_b).is_equal(2)
	assert_int(link.polarity).is_equal(AffinityLink.Polarity.POSITIVE)
	assert_int(link.amp).is_equal(1)


func test_from_csv_line_parses_negative_polarity() -> void:
	# Act
	var link: AffinityLink = AffinityLink.from_csv_line(LINE_NEGATIVE)

	# Assert
	assert_int(link.polarity).is_equal(AffinityLink.Polarity.NEGATIVE)
	assert_int(link.unit_a).is_equal(2)
	assert_int(link.unit_b).is_equal(5)


func test_from_csv_line_parses_amp_greater_than_one() -> void:
	# Act
	var link: AffinityLink = AffinityLink.from_csv_line(LINE_AMPLIFIED)

	# Assert
	assert_int(link.amp).is_equal(2)


# 2026-09-16 管理者裁決(產出於 PROJECT-STATUS.md「等你裁決」第二項):角色/配對表
# 未知列舉字串一律「響亮地停」,不得靜默落回列舉序數 0
# (.claude/docs/coding-standards.md 2026-09-15 條目所禁止的
# assert(false)+return 序數0 寫法,兩者恰好都是 0 == Polarity.POSITIVE,
# 今天測不出行為差異,但資料檔打錯字會被當成合法配對靜默使用)。
func test_from_csv_line_unknown_polarity_returns_null() -> void:
	# Arrange — polarity 欄位打錯字(例如漏打或拼錯 NEGATIVE)
	var line: String = "1,2,NEGATVIE,1"

	# Act
	var link: AffinityLink = AffinityLink.from_csv_line(line)

	# Assert
	assert_object(link).is_null()


# ---- links_from_text() --------------------------------------------------

func test_links_from_text_parses_three_links_in_file_order() -> void:
	# Arrange
	var text: String = "%s\n%s\n%s" % [LINE_POSITIVE, LINE_AMPLIFIED, LINE_NEGATIVE]

	# Act
	var links: Array[AffinityLink] = AffinityLink.links_from_text(text)

	# Assert — 順序必須與檔案一致,畫線時的疊放順序才穩定
	assert_int(links.size()).is_equal(3)
	assert_int(links[0].unit_a).is_equal(1)
	assert_int(links[1].unit_a).is_equal(3)
	assert_int(links[2].unit_a).is_equal(2)


func test_links_from_text_skips_comment_and_blank_lines() -> void:
	# Arrange
	var text: String = "# 註解行\n\n%s\n   \n# 又一行註解\n%s" % [LINE_POSITIVE, LINE_NEGATIVE]

	# Act
	var links: Array[AffinityLink] = AffinityLink.links_from_text(text)

	# Assert
	assert_int(links.size()).is_equal(2)


func test_links_from_text_empty_text_returns_empty_array() -> void:
	# Act
	var links: Array[AffinityLink] = AffinityLink.links_from_text("")

	# Assert — 空表不是錯誤,是「沒有任何配對」,呼叫端據此判斷載入失敗
	assert_int(links.size()).is_equal(0)


func test_links_from_text_only_comments_returns_empty_array() -> void:
	# Arrange
	var text: String = "# 只有註解\n# 沒有任何資料列\n"

	# Act
	var links: Array[AffinityLink] = AffinityLink.links_from_text(text)

	# Assert
	assert_int(links.size()).is_equal(0)


# 迴歸測試(2026-09-16 第一次裁決)— 見 test_from_csv_line_unknown_polarity_returns_null()
# 的裁決背景。這裡鎖住 links_from_text() 這一層的行為:一列打錯字,不是只丟掉
# 那一列,是整張表當作解析失敗。
#
# 2026-09-16 第二次裁決更正本測試的斷言:第一次裁決落地時,失敗與「合法的零
# 配對」(戊沒有任何關係線,見下面 test_links_from_text_vs01_file_gives_unit_five_no_links)
# 曾經都回傳空陣列 [] —— 兩者對呼叫端(battle_screen.gd)而言無法區分,而空陣列
# 本身是合法狀態、不能一律擋下。因此改為回傳 null:null 代表「解析失敗」,
# [] 代表「確實沒有任何配對」,兩者現在型別上就分得開,呼叫端據此決定是否
# 走向 _fail_load()。刻意在打錯字那一列前後各放一個合法列,證明合法列不會
# 讓結果誤變成「部分成功」。
func test_links_from_text_unknown_polarity_returns_null_not_empty_array() -> void:
	# Arrange
	var text: String = "%s\n1,3,BADVALUE,1\n%s" % [LINE_POSITIVE, LINE_NEGATIVE]

	# Act
	var links: Variant = AffinityLink.links_from_text(text)

	# Assert — null(解析失敗),不是空陣列(合法的零配對)。這兩者曾經無法區分,
	# 這支測試鎖住修好之後的樣子。
	assert_object(links).is_null()


func test_links_from_text_loads_vs01_file_returns_the_two_canon_links() -> void:
	# Arrange
	assert_bool(FileAccess.file_exists(VS01_LINKS_PATH)).is_true()
	var text: String = FileAccess.get_file_as_string(VS01_LINKS_PATH)

	# Act
	var links: Array[AffinityLink] = AffinityLink.links_from_text(text)

	# Assert — 來源是 design/narrative/characters.md 第三節「關係」
	# (Canon level: Established):甲乙合作(正)、丙丁對立(負)。
	assert_int(links.size()).is_equal(2)
	assert_int(links[0].unit_a).is_equal(1)
	assert_int(links[0].unit_b).is_equal(2)
	assert_int(links[0].polarity).is_equal(AffinityLink.Polarity.POSITIVE)
	assert_int(links[1].unit_a).is_equal(3)
	assert_int(links[1].unit_b).is_equal(4)
	assert_int(links[1].polarity).is_equal(AffinityLink.Polarity.NEGATIVE)


func test_links_from_text_vs01_file_gives_unit_five_no_links() -> void:
	# Arrange — 戊(麥子健)沒有配對是刻意的設定,不是漏寫。這個測試存在的
	# 唯一目的,是讓未來「順手補上」的人立刻撞牆並回去讀 characters.md。
	var text: String = FileAccess.get_file_as_string(VS01_LINKS_PATH)
	var links: Array[AffinityLink] = AffinityLink.links_from_text(text)

	# Act / Assert
	for link: AffinityLink in links:
		assert_bool(link.involves(5)).is_false()


# ---- involves() / partner_of() ------------------------------------------

func test_involves_true_for_both_endpoints_false_for_outsider() -> void:
	# Arrange
	var link: AffinityLink = AffinityLink.from_csv_line(LINE_POSITIVE)

	# Assert
	assert_bool(link.involves(1)).is_true()
	assert_bool(link.involves(2)).is_true()
	assert_bool(link.involves(3)).is_false()


func test_partner_of_returns_the_other_endpoint() -> void:
	# Arrange
	var link: AffinityLink = AffinityLink.from_csv_line(LINE_POSITIVE)

	# Assert
	assert_int(link.partner_of(1)).is_equal(2)
	assert_int(link.partner_of(2)).is_equal(1)
