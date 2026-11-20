extends RefCounted
## story-024:「開局種子關係」的期望值一律從種子檔本身推導,不在測試裡寫死「兩條」。
##
## 為什麼存在:關係不再固定(任何兩人可成好感/冷淡/敵意),種子檔只是開局初始關係;
## 舊測試把「種子檔恰有 2 條」寫成字面 2,檔案日後多一條(例如補上麥子健的線)就會
## 紅得莫名其妙,或更糟——被人「順手改成 3」。這裡改成:期望 = 用正式解析器
## [method AffinityLink.links_from_text] 讀同一份檔,實際 links() 必須與之逐條相符。
##
## 檔案存取:唯讀讀取 assets/data/affinity/ 真實資料檔(測試規範登記的例外一)。
## 不證明窮盡性:只證明「實際 links 與種子檔一致」,不證明種子檔本身內容正確(那是
## affinity_link_test 的 canon 守門測試負責)。

const SEED_PATH: String = "res://assets/data/affinity/vs01_affinity_links.txt"


static func expected_links() -> Array[AffinityLink]:
	var parsed: Variant = AffinityLink.links_from_text(FileAccess.get_file_as_string(SEED_PATH))
	if parsed == null:
		push_error("AffinitySeedExpectation: seed file failed to parse")
		return []
	var typed: Array[AffinityLink] = parsed
	return typed


static func pair_key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


## 回傳空字串 = 逐條相符(條數、每條配對、每條極性);否則回傳第一個差異的描述。
static func mismatch(actual: Array[AffinityLink], expected: Array[AffinityLink]) -> String:
	if actual.size() != expected.size():
		return "條數不符:實得 %d,期望 %d" % [actual.size(), expected.size()]
	var polarity_by_key: Dictionary = {}
	for link: AffinityLink in actual:
		polarity_by_key[pair_key(link.unit_a, link.unit_b)] = link.polarity
	for want: AffinityLink in expected:
		var key: Vector2i = pair_key(want.unit_a, want.unit_b)
		if not polarity_by_key.has(key):
			return "缺少配對 %s" % [key]
		if polarity_by_key[key] != want.polarity:
			return "配對 %s 極性不符:實得 %d,期望 %d" % [key, polarity_by_key[key], want.polarity]
	return ""
