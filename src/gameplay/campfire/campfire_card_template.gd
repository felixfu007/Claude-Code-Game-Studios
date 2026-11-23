## CampfireCardTemplate -- 營火產卡的模板旋鈕(強度公式與卡面固定欄位)。
##
## 實作依據:production/epics/campfire/story-003-campfire-card-generation.md 模板表。
## 資料檔:assets/data/campfire/campfire_card_template.txt(.txt,不得 .csv)。
## 數字皆占位、不得直接上線,交 systems-designer 校準。
##
## 純解析,不碰 FileAccess 以外的東西;解析失敗(缺鍵/重複/未知鍵/非整數/值域不合)
## 回傳 null 並 push_error,不回預設值。
class_name CampfireCardTemplate
extends RefCounted

const DATA_PATH: String = "res://assets/data/campfire/campfire_card_template.txt"
const KEYS: Array[String] = [
	"base_value", "max_bonus", "pool_step", "duration_rounds",
	"cost_amount", "target_range", "competitive_delta_def",
]

var base_value: int
var max_bonus: int
var pool_step: int
var duration_rounds: int
var cost_amount: int
var target_range: int
## 競爭卡固定 DEF 變化(負數)。
var competitive_delta_def: int


static func from_file(path: String = DATA_PATH) -> CampfireCardTemplate:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CampfireCardTemplate.from_file: cannot open '%s'" % path)
		return null
	return from_text(f.get_as_text())


static func from_text(text: String) -> CampfireCardTemplate:
	var seen: Dictionary = {}
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(",")
		if fields.size() != 2:
			push_error("CampfireCardTemplate: malformed line '%s'" % line)
			return null
		var key: String = fields[0].strip_edges()
		var value: String = fields[1].strip_edges()
		if not KEYS.has(key):
			push_error("CampfireCardTemplate: unknown key '%s'" % key)
			return null
		if seen.has(key):
			push_error("CampfireCardTemplate: duplicate key '%s'" % key)
			return null
		if not value.is_valid_int():
			push_error("CampfireCardTemplate: value of '%s' is not an integer: '%s'" % [key, value])
			return null
		seen[key] = value.to_int()
	for key: String in KEYS:
		if not seen.has(key):
			push_error("CampfireCardTemplate: missing key '%s'" % key)
			return null
	var t: CampfireCardTemplate = CampfireCardTemplate.new()
	t.base_value = seen["base_value"]
	t.max_bonus = seen["max_bonus"]
	t.pool_step = seen["pool_step"]
	t.duration_rounds = seen["duration_rounds"]
	t.cost_amount = seen["cost_amount"]
	t.target_range = seen["target_range"]
	t.competitive_delta_def = seen["competitive_delta_def"]
	if t.base_value < 0 or t.max_bonus < 0 or t.pool_step < 1 or t.duration_rounds < 1 \
			or t.cost_amount < 0 or t.competitive_delta_def > 0:
		push_error("CampfireCardTemplate: a value is out of range (base/max_bonus>=0, pool_step>=1, duration>=1, cost>=0, competitive_delta_def<=0)")
		return null
	return t
