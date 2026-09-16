# 卡表(vs01_cards.txt)與牌面文字表(vs01_card_text.txt)的編號集合一致性——
# production/epics/card-play-interface/story-u017-card-table-id-consistency.md
# (U-017)。
#
# 🔴 本檔搬遷紀錄:這條測試最初寫在 tests/integration/ui/battle/
# battle_screen_card_deck_wiring_test.gd(U-003 的卡牌線半部),但 U-003 工作單
# 本身的 Out of Scope 節明文排除它(「本 story 亦不主動承接...留待實作時判斷是否
# 順手補上,或另開工作單」)。2026-09-16 管理者裁決:保留這條測試、搬離 U-003
# 的驗收檔案、另開 U-017 承接它的歸屬。搬遷時邏輯與斷言完全未改動,只搬動位置、
# 更換路徑常數的來源(見下方路徑常數段落)。
#
# vs01_cards.txt 檔頭逐字:「本檔每一列新增/刪除都必須同步那張表的對應列」。
# 全庫先前沒有任何測試同時載入兩張表比對過這個不變式——本檔是第一個。
#
# 🔴 路徑常數選擇(搬遷時的判斷,記錄給後人不必猜):本檔沒有沿用
# BattleScreen.CARDS_PATH / BattleScreen.CARD_TEXT_PATH,改為自己宣告
# _CARDS_PATH / _CARD_TEXT_PATH 兩個常數,直接指向同樣的檔案路徑。理由:
# ① 本檔測的是 Card/CardText 兩個資料解析類別之間的一致性,概念上與
# BattleScreen(UI 類別)無關——繼續借用會對一個不相干的 UI 類別產生本質上
# 不必要的相依。② 這與本目錄既有先例一致:affinity_pool_write_port_test.gd
# 同樣自己宣告 _AFFINITY_LINKS_PATH,而不是借 BattleScreen.AFFINITY_PATH——
# 本目錄(tests/integration/gameplay/cards/)裡沒有任何一個既有測試檔向
# BattleScreen 借過路徑常數,本檔沿用這個目錄自己的慣例。
# ⚠️ 代價已知且接受:兩處常數字面值相同的字串,若日後檔案路徑搬家,兩邊要各自
# 更新一次——但換來的是這個目錄的測試不必知道 BattleScreen 的存在。
#
# 全鏈路(Card/CardText)皆為 static 純函式解析,不建立任何 Node,不需要
# tear-down。
extends GdUnitTestSuite


const _CARDS_PATH: String = "res://assets/data/cards/vs01_cards.txt"
const _CARD_TEXT_PATH: String = "res://assets/data/cards/vs01_card_text.txt"


# ---- 兩表(vs01_cards.txt / vs01_card_text.txt)id 集合一致性 -----------------
func test_cards_table_and_card_text_table_have_identical_id_sets() -> void:
	# Arrange
	var cards_text: String = FileAccess.get_file_as_string(_CARDS_PATH)
	var card_text_text: String = FileAccess.get_file_as_string(_CARD_TEXT_PATH)
	var parsed_cards: Variant = Card.cards_from_text(cards_text)
	assert_object(parsed_cards).is_not_null()
	var cards: Array[Card] = parsed_cards
	var flavor: Dictionary[String, String] = CardText.flavor_texts_from_text(card_text_text)

	# Act
	var card_ids: Dictionary = {}
	for card: Card in cards:
		card_ids[card.id] = true
	var flavor_ids: Dictionary = {}
	for id: String in flavor.keys():
		flavor_ids[id] = true

	# Assert — 每一張機制卡都有恰一列對應的顯示文字,反之亦然
	for id: String in card_ids.keys():
		assert_bool(flavor_ids.has(id)).is_true()
	for id: String in flavor_ids.keys():
		assert_bool(card_ids.has(id)).is_true()
	assert_int(card_ids.size()).is_equal(flavor_ids.size())
