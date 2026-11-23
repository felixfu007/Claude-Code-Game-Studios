## CampaignDeck -- 戰役層的牌組與收藏區(campfire story-004)。
##
## 只存在記憶體:不寫任何檔案、不新增存檔欄位;「一輪」的邊界是新遊戲
## ([method CampaignProgress.reset_campaign] 呼叫 [method clear])。
## 本類別【完全不碰 FileAccess】:資料檔由 [CampaignDeckDefaultsLoader] 讀取後交
## [method from_text] 解析。
##
## 模型:牌組(deck)= 本場洗進牌庫的牌;收藏區(collection)= 擁有但不在牌組的牌。
## 編輯是暫存的:[method move_to_deck] / [method move_to_collection] 只動「編輯中」
## 的牌組,[method confirm] 通過張數檢查才成為「已確認牌組」;戰鬥端與 AC5
## (戰敗直接重打保留牌組)只認 [method confirmed_deck_ids]。
## 卡以 id 字串表示;檔案型卡的 id -> Card 解析由 [CampaignCardResolver] 負責,
## 營火產出的執行期卡由 [method add_new_card] 同時登記在本物件的登記區
## ([method registered_card]),與牌組/收藏區同一份快照([method snapshot])。
##
## 🔴 收藏區初始內容與 8/14 上下限皆為占位,見 default_deck.txt 檔頭。
class_name CampaignDeck
extends RefCounted

enum ConfirmResult { OK, TOO_FEW, TOO_MANY }

const KEY_MIN: String = "deck_min"
const KEY_MAX: String = "deck_max"
const KEY_DECK: String = "deck"
const KEY_COLLECTION: String = "collection"

var _min: int = 8
var _max: int = 14
var _default_deck: Array[String] = []
var _default_collection: Array[String] = []

var _deck: Array[String] = []
var _collection: Array[String] = []
var _confirmed_deck: Array[String] = []
var _confirmed_collection: Array[String] = []
var _new_marks: Dictionary = {}
## 營火產出(執行期)卡的登記區:id -> Card。只增不減(孤兒條目無害:id 不在牌組就不會被戰鬥讀到)。
## 檔案型卡不登記在此,由 [CampaignCardResolver] 從牌表解析。
var _registry: Dictionary = {}


func deck_min() -> int:
	return _min


func deck_max() -> int:
	return _max


## 編輯中的牌組(尚未確認的改動也看得到)。
func working_deck_ids() -> Array[String]:
	return _deck.duplicate()


## 編輯中的收藏區。
func collection_ids() -> Array[String]:
	return _collection.duplicate()


## 最近一次確認的牌組 —— 戰鬥端讀這個。
func confirmed_deck_ids() -> Array[String]:
	return _confirmed_deck.duplicate()


## 該 id 是否為「新」(營火自動入組後、下次 [method confirm] 成功前)。
func is_new(card_id: String) -> bool:
	return _new_marks.has(card_id)


## 回到資料檔預設(新遊戲)。含清除「新」標記與未確認的編輯。
func clear() -> void:
	_deck = _default_deck.duplicate()
	_collection = _default_collection.duplicate()
	_confirmed_deck = _default_deck.duplicate()
	_confirmed_collection = _default_collection.duplicate()
	_new_marks.clear()
	_registry.clear()


## 放棄未確認的編輯,回到已確認狀態。
func cancel_edit() -> void:
	_deck = _confirmed_deck.duplicate()
	_collection = _confirmed_collection.duplicate()


## 任何牌皆可移出,移出的牌回收藏區(營火卡也不消耗)。id 不在編輯中牌組回 false。
func move_to_collection(card_id: String) -> bool:
	if not _deck.has(card_id):
		return false
	_remove_from_deck(card_id)
	return true


## 把收藏區的牌移入編輯中牌組。允許暫時超過上限,由 [method confirm] 拒絕。
func move_to_deck(card_id: String) -> bool:
	if not _collection.has(card_id):
		return false
	_collection.erase(card_id)
	_deck.append(card_id)
	return true


## 以編輯中牌組的張數確認。OK 才寫入已確認牌組並清「新」標記;否則什麼都不改。
func confirm() -> ConfirmResult:
	var result: ConfirmResult = _check_size(_deck.size())
	if result != ConfirmResult.OK:
		return result
	_confirmed_deck = _deck.duplicate()
	_confirmed_collection = _collection.duplicate()
	_new_marks.clear()
	return ConfirmResult.OK


## 新營火卡入帳:先丟棄未確認編輯;已確認牌組未滿上限 → 自動入組並標「新」,
## 已滿 → 留收藏區。id 已擁有(牌組或收藏區)回 false、不動任何狀態(含登記區,不覆蓋)。
## [param card] 非 null 時入帳成功後登記為該 id 的執行期卡(重回營火再產同 id 時,
## 因 id 未擁有而再度入帳,登記區覆蓋為新產生的 Card)。
func add_new_card(card_id: String, card: Card = null) -> bool:
	if _confirmed_deck.has(card_id) or _confirmed_collection.has(card_id):
		return false
	if card != null:
		_registry[card_id] = card
	cancel_edit()
	if _confirmed_deck.size() < _max:
		_confirmed_deck.append(card_id)
		_new_marks[card_id] = true
	else:
		_confirmed_collection.append(card_id)
	cancel_edit()
	return true


## 登記區裡該 id 的執行期卡;沒有回 null(檔案型卡一律回 null)。
func registered_card(card_id: String) -> Card:
	return _registry.get(card_id, null) as Card


## 登記區的淺拷貝(id -> Card)。Card 在戰鬥中不被改動,可共用參照。
func registry_copy() -> Dictionary:
	return _registry.duplicate()


## 已確認狀態的快照(story-015 退回營火前用)。只存「已確認」那組 + 「新」標記 + 登記區;
## 編輯中副本不存,[method restore] 後與已確認狀態相同。
func snapshot() -> Dictionary:
	return {
		"confirmed_deck": _confirmed_deck.duplicate(),
		"confirmed_collection": _confirmed_collection.duplicate(),
		"new_marks": _new_marks.duplicate(),
		"registry": _registry.duplicate(),
	}


## 還原 [method snapshot];同時重設編輯中副本。形狀不符回 false、不動任何狀態。
func restore(snap: Dictionary) -> bool:
	var d: Variant = snap.get("confirmed_deck", null)
	var c: Variant = snap.get("confirmed_collection", null)
	var m: Variant = snap.get("new_marks", null)
	var r: Variant = snap.get("registry", null)
	if not (d is Array) or not (c is Array) or not (m is Dictionary) or not (r is Dictionary):
		push_error("CampaignDeck.restore: malformed snapshot")
		return false
	_confirmed_deck.assign(d)
	_confirmed_collection.assign(c)
	_new_marks = (m as Dictionary).duplicate()
	_registry = (r as Dictionary).duplicate()
	cancel_edit()
	return true


## [enum ConfirmResult] 的人可讀原因(OK 回空字串)。
func rejection_reason(result: ConfirmResult) -> String:
	match result:
		ConfirmResult.TOO_FEW:
			return "牌組至少需要 %d 張" % _min
		ConfirmResult.TOO_MANY:
			return "牌組最多只能有 %d 張" % _max
	return ""


## 解析 default_deck 資料文字;任何問題回 null(已 push_error),不回預設值。
static func from_text(text: String) -> CampaignDeck:
	var d: CampaignDeck = CampaignDeck.new()
	if not d.apply_text(text):
		return null
	return d


## 把 [param text] 解析進本實例(測試用 mutant 子類別也走這條);失敗回 false。
func apply_text(text: String) -> bool:
	var d: CampaignDeck = self
	var seen: Dictionary = {}
	var ids: Dictionary = {}
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(",")
		if fields.size() != 2:
			push_error("CampaignDeck: malformed line '%s'" % line)
			return false
		var key: String = fields[0].strip_edges()
		var value: String = fields[1].strip_edges()
		match key:
			KEY_MIN, KEY_MAX:
				if seen.has(key) or not value.is_valid_int():
					push_error("CampaignDeck: bad or duplicate '%s'" % key)
					return false
				seen[key] = value.to_int()
			KEY_DECK, KEY_COLLECTION:
				if value.is_empty() or ids.has(value):
					push_error("CampaignDeck: empty or duplicate card id '%s'" % value)
					return false
				ids[value] = true
				if key == KEY_DECK:
					d._default_deck.append(value)
				else:
					d._default_collection.append(value)
			_:
				push_error("CampaignDeck: unknown key '%s'" % key)
				return false
	if not seen.has(KEY_MIN) or not seen.has(KEY_MAX):
		push_error("CampaignDeck: both '%s' and '%s' are required" % [KEY_MIN, KEY_MAX])
		return false
	d._min = seen[KEY_MIN]
	d._max = seen[KEY_MAX]
	if d._min < 1 or d._max < d._min:
		push_error("CampaignDeck: need 1 <= deck_min <= deck_max, got %d/%d" % [d._min, d._max])
		return false
	if d._default_deck.size() < d._min or d._default_deck.size() > d._max:
		push_error("CampaignDeck: default deck size %d outside %d..%d" % [d._default_deck.size(), d._min, d._max])
		return false
	d.clear()
	return true


## 張數檢查 —— 獨立成方法讓敏感度證明的 mutant 能覆寫。
func _check_size(count: int) -> ConfirmResult:
	if count < _min:
		return ConfirmResult.TOO_FEW
	if count > _max:
		return ConfirmResult.TOO_MANY
	return ConfirmResult.OK


## 移出 = 回收藏區。獨立成方法讓 mutant 能覆寫成「刪除」。
func _remove_from_deck(card_id: String) -> void:
	_deck.erase(card_id)
	_collection.append(card_id)
