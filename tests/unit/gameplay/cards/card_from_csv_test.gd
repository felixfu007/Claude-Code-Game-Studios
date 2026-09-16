# Card.from_csv_line() / Card.cards_from_text() 的單元測試 —— Story U-001
# （production/epics/card-play-interface/story-u001-card-table-parser.md）:
# 把 assets/data/cards/vs01_cards.txt 的固定 8 欄格式轉成 Card 實例。
#
# 純資料/純函式測試——Card 是 RefCounted,不建立任何 Node,不需要 tear-down,
# 不會留下孤兒節點。命名慣例沿用既有先例 tests/unit/gameplay/cards/
# card_deck_test.gd 的 test_[scenario]_[expected]。每個測試自建自拆，
# 不共用可變狀態。
#
# 🔴 本檔含兩支讀真實資料檔的測試
# （test_cards_from_text_parses_vs01_cards_txt_into_eight_cards、
# test_cards_from_text_vs01_file_has_no_bare_header_line_left_over）——這是
# .claude/rules/test-standards.md 2026-09-16 裁決的「甲類」明文例外
# （唯讀 assets/data/ 底下已進版控的資料檔),不是違規:
#   1. 為什麼不能用注入/假資料取代:這兩條測試驗證的正是「真實資料檔
#      沒有打錯字、欄位數與 category 字面值皆合法、也沒有裸表頭殘留」——
#      寫死一份假 CSV 字串測不到「資料檔本身壞了」這種錯(本專案前例:
#      資料檔沒打包、遊戲靜默畫空棋盤、151 條測試全綠)。其餘測試才是純
#      字串輸入,各自自建自拆,不碰檔案系統。
#   2. 唯讀 assets/data/cards/vs01_cards.txt,不寫入任何檔案、不讀
#      user:// 或暫存目錄。
#
# 2026-09-16 管理者裁決 B(「停下來,指出第幾行」,card-play-interface
# Story U-001)—— Card.cards_from_text() 任一列解析失敗即整批回傳 null,
# 不是跳過該列。🔴 這條裁決只涵蓋卡表這一張資料檔,管理者同批明確裁決
# 「維持一張一張裁」,不推廣為通用規則——不要拿本檔的測試形狀去論證其他
# 資料檔「應該」一致。
#
# 讀真實資料檔的兩支測試改用 Variant 承接 + fail() 響亮標紅（而非直接寫
# `var cards: Array[Card] = Card.cards_from_text(...)`），比照
# tests/unit/gameplay/cards/card_permanent_write_test.gd 的 _vs01_links()：
# null 代表「真實資料檔解析失敗」，這是資料檔本身的缺陷，不是測試或受測
# 程式碼的 bug，應該響亮失敗而不是被靜默轉型成空陣列。
extends GdUnitTestSuite

const VS01_CARDS_PATH: String = "res://assets/data/cards/vs01_cards.txt"


## 讀取並解析真實 vs01_cards.txt。null 時 fail() 響亮標紅並回傳空陣列，讓
## 呼叫端的斷言不必再處理 null（同一失敗訊息已經記錄過了）。
func _cards_from_vs01_file() -> Array[Card]:
	var text: String = FileAccess.get_file_as_string(VS01_CARDS_PATH)
	var parsed: Variant = Card.cards_from_text(text)
	if parsed == null:
		fail(
			(
				"_cards_from_vs01_file(): Card.cards_from_text() returned null while parsing "
				+ "%s — the real, version-controlled card data file failed to parse. This is a "
				+ "data-file defect, not a bug in the test or in the code under test."
			) % VS01_CARDS_PATH
		)
		return []
	return parsed


# ---- from_csv_line()：甲類（暫時性戰鬥數值）欄位逐一對應 ----------------------

func test_from_csv_line_parses_temporary_stat_modifier_fields() -> void:
	# Arrange — 甲類:id,category,delta_atk,delta_def,duration_rounds,
	# affinity_character_a,affinity_character_b,affinity_magnitude
	var line: String = "c1,TEMPORARY_STAT_MODIFIER,3,-2,2,-1,-1,0"

	# Act
	var card: Card = Card.from_csv_line(line)

	# Assert — 四個甲類欄位與輸入逐一對應（工作單 AC 第一條）
	assert_object(card).is_not_null()
	assert_str(card.id).is_equal("c1")
	assert_int(card.category).is_equal(Card.Category.TEMPORARY_STAT_MODIFIER)
	assert_int(card.delta_atk).is_equal(3)
	assert_int(card.delta_def).is_equal(-2)
	assert_int(card.duration_rounds).is_equal(2)


# ---- from_csv_line()：丙類（永久好感度寫入）欄位逐一對應 ----------------------

func test_from_csv_line_parses_permanent_affinity_write_fields() -> void:
	# Arrange — 丙類:甲類專用三欄一律 0，丙類專用三欄才是實際數值
	var line: String = "c2,PERMANENT_AFFINITY_WRITE,0,0,0,1,2,-3"

	# Act
	var card: Card = Card.from_csv_line(line)

	# Assert — 四個丙類欄位與輸入逐一對應（工作單 AC 第二條）
	assert_object(card).is_not_null()
	assert_str(card.id).is_equal("c2")
	assert_int(card.category).is_equal(Card.Category.PERMANENT_AFFINITY_WRITE)
	assert_int(card.affinity_character_a).is_equal(1)
	assert_int(card.affinity_character_b).is_equal(2)
	assert_int(card.affinity_magnitude).is_equal(-3)


# ---- delta_def == 0 是合法的「這張牌不動這個軸」，不是 unset sentinel --------

func test_delta_def_zero_is_preserved_not_treated_as_unset() -> void:
	# Arrange — 純 ATK 卡：delta_def 欄位字面值就是 0
	var line: String = "c3,TEMPORARY_STAT_MODIFIER,2,0,1,-1,-1,0"

	# Act
	var card: Card = Card.from_csv_line(line)

	# Assert — 0 被原樣保留，不觸發任何跳過或改值（不得混同丙類 magnitude 的
	# unset sentinel 語意，工作單 Implementation Note 4）
	assert_object(card).is_not_null()
	assert_int(card.delta_def).is_equal(0)


# ---- from_csv_line()：未知 category 字串回傳 null，不 assert() -----------------

func test_from_csv_line_unknown_category_returns_null() -> void:
	# Arrange — 大小寫不符也視為未知（工作單 Out of Scope 明文：不做別名/大小寫容錯）
	var line: String = "c4,Temporary_stat_modifier,1,1,1,-1,-1,0"

	# Act
	var card: Card = Card.from_csv_line(line)

	# Assert
	assert_object(card).is_null()


# ---- cards_from_text()：空行與 # 註解列被跳過 ---------------------------------

func test_blank_and_comment_lines_are_skipped() -> void:
	# Arrange
	var text: String = (
		"# leading comment\n"
		+ "\n"
		+ "c1,TEMPORARY_STAT_MODIFIER,1,1,1,-1,-1,0\n"
		+ "   \n"
		+ "# another comment\n"
		+ "c2,PERMANENT_AFFINITY_WRITE,0,0,0,1,2,1\n"
	)

	# Act
	var cards: Array[Card] = Card.cards_from_text(text)

	# Assert — 只有兩張真正的卡，空行/註解不產生 Card 也不報錯
	assert_int(cards.size()).is_equal(2)
	assert_str(cards[0].id).is_equal("c1")
	assert_str(cards[1].id).is_equal("c2")


# ---- cards_from_text()：一列打錯字 → 整批回傳 null(2026-09-16 裁決 B) --------
#
# 刻意在打錯字那一列前後各放一個合法列,證明合法列不會讓結果誤變成
# 「部分成功」——比照 affinity_link_test.gd 的
# test_links_from_text_unknown_polarity_returns_null_not_empty_array()。

func test_unknown_category_string_logs_error_and_aborts_whole_batch() -> void:
	# Arrange
	var text: String = (
		"c1,TEMPORARY_STAT_MODIFIER,1,1,1,-1,-1,0\n"
		+ "c_bad,NOT_A_REAL_CATEGORY,0,0,0,-1,-1,0\n"
		+ "c2,PERMANENT_AFFINITY_WRITE,0,0,0,1,2,1\n"
	)

	# Act
	var cards: Variant = Card.cards_from_text(text)

	# Assert — null(解析失敗),不是「少一張」的部分陣列
	assert_object(cards).is_null()


# ---- 迴歸測試:裸表頭列(無 # 前綴)必須被當成壞資料整批擋下,不得靜默漏算 ----
#
# 這是 2026-09-16 第二次覆核抓到的真實缺陷的迴歸測試:vs01_cards.txt 曾經在
# 第 66 行有一份沒有 `#` 前綴的裸表頭(與同檔第 2 行、以及 vs01_roster.txt /
# vs01_affinity_links.txt 兩張姊妹表的既有慣例都不一致)。裸表頭的
# category 欄位字面值是 "category",不是任何合法 Category 名稱,所以它會走
# 到 from_csv_line() 的未知 category 分支——本測試鎖住這個分支在批次層真的
# 會整批擋下,而不是被某個「看起來像註解」的特判悄悄吃掉。

func test_cards_from_text_bare_header_line_without_hash_prefix_aborts_whole_batch() -> void:
	# Arrange — 複刻真實缺陷的形狀:一份沒有 # 前綴的裸表頭混在合法資料列之間
	var text: String = (
		"card_01,TEMPORARY_STAT_MODIFIER,3,0,1,-1,-1,0\n"
		+ "id,category,delta_atk,delta_def,duration_rounds,"
		+ "affinity_character_a,affinity_character_b,affinity_magnitude\n"
		+ "card_02,TEMPORARY_STAT_MODIFIER,1,0,2,-1,-1,0\n"
	)

	# Act
	var cards: Variant = Card.cards_from_text(text)

	# Assert — 整批 null,不是「少算一張表頭當卡」或「悄悄跳過表頭仍回傳兩張卡」
	assert_object(cards).is_null()


# ---- cards_from_text()：真實 vs01_cards.txt 解析出恰好 8 張卡(甲類例外) ----

func test_cards_from_text_parses_vs01_cards_txt_into_eight_cards() -> void:
	# Arrange
	assert_bool(FileAccess.file_exists(VS01_CARDS_PATH)).is_true()

	# Act
	var cards: Array[Card] = _cards_from_vs01_file()

	# Assert — 對照現有資料檔:恰好 8 張，6 張甲類、2 張丙類
	assert_int(cards.size()).is_equal(8)
	var temporary_count: int = 0
	var permanent_count: int = 0
	for card: Card in cards:
		if card.category == Card.Category.TEMPORARY_STAT_MODIFIER:
			temporary_count += 1
		elif card.category == Card.Category.PERMANENT_AFFINITY_WRITE:
			permanent_count += 1
	assert_int(temporary_count).is_equal(6)
	assert_int(permanent_count).is_equal(2)
