## 讀取 default_deck 資料檔(唯讀)並交 [method CampaignDeck.from_text] 解析。
## 讀檔與解析分開,讓 [CampaignDeck] 本體完全不碰 FileAccess。
## 失敗時 push_error 並回傳空的 [CampaignDeck](上下限 8/14、牌組為空),
## 不回 null —— 靜態持有者在腳本載入時呼叫本函式,null 會讓 reset 時崩潰。
class_name CampaignDeckDefaultsLoader
extends RefCounted

const DATA_PATH: String = "res://assets/data/campfire/default_deck.txt"


static func load_defaults(path: String = DATA_PATH) -> CampaignDeck:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CampaignDeckDefaultsLoader: cannot open '%s'" % path)
		return CampaignDeck.new()
	var deck: CampaignDeck = CampaignDeck.from_text(f.get_as_text())
	if deck == null:
		return CampaignDeck.new()
	return deck
