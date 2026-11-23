## CampaignCardResolver -- 把戰役層已確認牌組的 id 解析成戰鬥用的 [Card](campfire story-005)。
##
## 兩種來源:(1) 營火產出的執行期卡 -> [method CampaignDeck.registered_card];
## (2) 檔案型卡 -> 目錄([constant CATALOG_PATH],以 vs02_cards.txt 為數值權威;
## vs02~vs05 共用卡逐字相同由資料一致性測試釘住)。牌面【文字】不在此處理:
## 戰鬥畫面照當場關卡的 card_text 檔讀(管理者 2026-11-23 裁決)。
##
## 找不到任何 id -> push_error 並整批回 null,不靜默略過(靜默略過會讓牌庫張數
## 悄悄少於確認牌組)。呼叫端(SceneRouter)遇 null 不注入,戰鬥退回固定牌表並留下錯誤。
##
## 檔案 I/O 只在 [method cards_for_battle] 的目錄讀取;[method resolve] 為純函式。
class_name CampaignCardResolver
extends RefCounted

const CATALOG_PATH: String = "res://assets/data/cards/vs02_cards.txt"

## 戰役第幾場起使用確認牌組(第 1 場維持固定牌表,管理者 2026-11-23 第 1 題)。
const FIRST_DECK_MISSION: int = 2


## 該場是否改用確認牌組。獨立成方法讓敏感度證明的 mutant 能覆寫。
func _uses_confirmed_deck(mission: int) -> bool:
	return mission >= FIRST_DECK_MISSION


## 要解析的 id 清單 —— 只認「已確認牌組」。獨立成方法讓 mutant 能覆寫成「忽略移出」。
func _ids_for(deck: CampaignDeck) -> Array[String]:
	return deck.confirmed_deck_ids()


## 讀目錄卡(固定牌表)。獨立成方法讓 mutant 能覆寫成「回固定牌表整批」。
func _load_catalog(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("CampaignCardResolver: cannot read catalog '%s'" % path)
		return null
	return Card.cards_from_text(text)


## 戰鬥注入入口。第 [param mission] 場不使用確認牌組(第 1 場)回空陣列;
## 使用但解析失敗回 null(已 push_error);否則回依牌組順序的 Card 陣列。
func cards_for_battle(mission: int, deck: CampaignDeck, catalog_path: String = CATALOG_PATH) -> Variant:
	if deck == null or not _uses_confirmed_deck(mission):
		var none: Array[Card] = []
		return none
	var parsed: Variant = _load_catalog(catalog_path)
	if parsed == null:
		return null
	var catalog: Array[Card] = parsed
	return resolve(_ids_for(deck), deck, catalog)


## 純函式:依 [param ids] 順序解析。執行期登記優先於目錄;任何 id 找不到回 null。
func resolve(ids: Array[String], deck: CampaignDeck, catalog: Array[Card]) -> Variant:
	var by_id: Dictionary = {}
	for c: Card in catalog:
		by_id[c.id] = c
	var out: Array[Card] = []
	for id: String in ids:
		var card: Card = deck.registered_card(id) if deck != null else null
		if card == null:
			card = by_id.get(id, null) as Card
		if card == null:
			push_error("CampaignCardResolver: unresolved card id '%s'" % id)
			return null
		out.append(card)
	return out
