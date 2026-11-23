## CampfireKnobs -- 營火寫入的兩個旋鈕:單次寫入量 [code]m[/code] 與每輪次數。
##
## 實作依據:production/epics/campfire/story-002-campfire-write-port.md「規則摘要」。
## 資料檔:assets/data/campfire/campfire_knobs.txt(.txt,不得 .csv,見 coding-standards)。
##
## 純解析,不碰 FileAccess(讀檔留在組裝點),比照 [AffinityTuning.from_text]。
## 解析失敗(缺鍵、重複鍵、未知鍵、非數字、m 不在 (0, 1]、次數 < 1)回傳 null 並
## push_error,不回預設值 —— 預設值會讓「資料檔壞了」看起來像「一切正常」。
## m 上限 1.0 = [constant SupportConversationRules.MAGNITUDE_ABS]
## (creative-director 條件:單次 m 不得大於一次支援對話的寫入量)。
class_name CampfireKnobs
extends RefCounted

const DATA_PATH: String = "res://assets/data/campfire/campfire_knobs.txt"
const KEY_M: String = "m"
const KEY_ACTIONS: String = "camp_actions_per_round"

var _m: float
var _actions_per_round: int


## 單次關心/質問的寫入量(正數;質問時寫入端取負)。
func m() -> float:
	return _m


## 每輪營火可確認的動作次數(關心、質問合計)。
func actions_per_round() -> int:
	return _actions_per_round


## 從資料檔路徑讀取並解析;讀檔失敗或解析失敗回 null。
static func from_file(path: String = DATA_PATH) -> CampfireKnobs:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CampfireKnobs.from_file: cannot open '%s'" % path)
		return null
	return from_text(f.get_as_text())


## 解析 [param text];任何問題回 null(已 push_error)。
static func from_text(text: String) -> CampfireKnobs:
	var seen: Dictionary = {}
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(",")
		if fields.size() != 2:
			push_error("CampfireKnobs: malformed line '%s'" % line)
			return null
		var key: String = fields[0].strip_edges()
		var value: String = fields[1].strip_edges()
		if key != KEY_M and key != KEY_ACTIONS:
			push_error("CampfireKnobs: unknown key '%s'" % key)
			return null
		if seen.has(key):
			push_error("CampfireKnobs: duplicate key '%s'" % key)
			return null
		if not value.is_valid_float():
			push_error("CampfireKnobs: value of '%s' is not a number: '%s'" % [key, value])
			return null
		seen[key] = value.to_float()
	if not seen.has(KEY_M) or not seen.has(KEY_ACTIONS):
		push_error("CampfireKnobs: both '%s' and '%s' are required" % [KEY_M, KEY_ACTIONS])
		return null
	var m_value: float = seen[KEY_M]
	var actions_value: float = seen[KEY_ACTIONS]
	if m_value <= 0.0 or m_value > SupportConversationRules.MAGNITUDE_ABS:
		push_error("CampfireKnobs: m must be in (0, %s], got %s" % [SupportConversationRules.MAGNITUDE_ABS, m_value])
		return null
	if actions_value < 1.0 or actions_value != floorf(actions_value):
		push_error("CampfireKnobs: camp_actions_per_round must be an integer >= 1, got %s" % actions_value)
		return null
	var knobs: CampfireKnobs = CampfireKnobs.new()
	knobs._m = m_value
	knobs._actions_per_round = int(actions_value)
	return knobs
