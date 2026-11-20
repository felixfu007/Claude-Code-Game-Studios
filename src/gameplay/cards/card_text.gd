## Card-face text table: parses `id,card_name,effect_line` rows (as read from
## `assets/data/cards/vs0N_card_text.txt`) into lookups a caller can query alongside
## [Card]'s mechanical data.
##
## Deliberately separate from [Card] (2026-09-15 manager ruling, transcribed in
## `vs01_card_text.txt`'s header): [Card] has no field for display text and this class
## never writes one into a [Card] instance.
##
## 2026-11-20 story-029:文字表由 `id,flavor_text` 兩欄改為 `id,card_name,effect_line` 三欄
## (ux 判定方案 A:牌名獨立欄、條件與代價不放牌面)。🔴 [b]拒絕舊兩欄格式,不做相容[/b]:
## 全部資料檔(vs01~05、教學場)已一次遷移完畢;相容會讓「漏遷的檔案」靜默被當成
## 「牌名=整句、效果=空」或反之而不報錯。舊格式列只有 2 欄 -> 整表拒絕並 push_error。
##
## Parsing is deliberately split from file reading (this class never touches
## [FileAccess]) — mirrors [method Unit.roster_from_text] and
## [method AffinityLink.links_from_text] so every branch is unit-testable.
class_name CardText
extends RefCounted

## Number of fields a parsed line must resolve to: id, card_name, effect_line.
##
## 2026-11-11 管理者裁決(story-038):欄數檢查為 push_error + 整表拒絕,發行版也有效
## (assert 在 release 匯出會被整條移除,檢查會消失)。
const FIELD_COUNT: int = 3

## [method faces_from_text] 每筆值([PackedStringArray])內的欄位索引。
const FACE_NAME: int = 0
const FACE_EFFECT: int = 1


## Parses an entire card-text-table blob into [code]id -> [card_name, effect_line][/code].
## Blank lines and lines starting with [code]#[/code] are skipped.
##
## Splits each line on the FIRST TWO commas only ([code]split(",", true, 2)[/code]):
## [code]card_name[/code] is comma-free by contract, and any further comma stays inside
## [code]effect_line[/code] (no quote-escaping convention exists in this table format).
## 🔴 副作用(誠實登記):一列舊格式但內文含逗號(例 [code]card_99,甲說,「x」[/code])
## 會被讀成三欄(牌名「甲說」)而【不會】被拒絕 —— 欄數檢查只抓得到「不足 3 欄」。
## 防線是:資料檔已全數遷移(測試掃描),而非解析器。
##
## 任何一列不足 3 欄(含舊兩欄格式、缺逗號)-> [code]push_error()[/code](含行號)後回傳
## [b]空字典[/b],整張表不採用。接收端對缺牌面文字本來就以 [code]""[/code] 退回。
## 🔴 重複 [code]id[/code] 仍【未裁決】:目前後者覆蓋前者。
static func faces_from_text(text: String) -> Dictionary[String, PackedStringArray]:
	var result: Dictionary[String, PackedStringArray] = {}
	var line_number: int = 0
	for raw_line: String in text.split("\n"):
		line_number += 1
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(",", true, FIELD_COUNT - 1)
		if fields.size() != FIELD_COUNT:
			push_error(
				(
					"CardText.faces_from_text: aborting -- expected %d fields "
					+ "(id,card_name,effect_line; old 2-column format is rejected), got %d "
					+ "at line %d: %s"
				) % [FIELD_COUNT, fields.size(), line_number, line]
			)
			return {}
		result[fields[0]] = PackedStringArray([fields[1], fields[2]])
	return result


## id -> effect_line([code]{記號}[/code] 尚未替換,取用處須走 [method render])。
## 壞表 -> 空字典(見 [method faces_from_text])。
static func flavor_texts_from_text(text: String) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	var faces: Dictionary[String, PackedStringArray] = faces_from_text(text)
	for id: String in faces:
		result[id] = faces[id][FACE_EFFECT]
	return result


## id -> card_name(可為空字串:空牌名 UI 不顯示標題列)。壞表 -> 空字典。
static func card_names_from_text(text: String) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	var faces: Dictionary[String, PackedStringArray] = faces_from_text(text)
	for id: String in faces:
		result[id] = faces[id][FACE_NAME]
	return result


## 2026-11-19 story-028:牌面數字樣板。可用的具名記號(白名單,全為 [Card] 的 int 欄位):
## [code]{cost_amount}[/code]、[code]{effect_value}[/code]、[code]{target_range}[/code]、
## [code]{delta_atk}[/code]、[code]{delta_def}[/code]、[code]{duration_rounds}[/code]、
## [code]{affinity_magnitude}[/code]。
const _TEMPLATE_PATTERN: String = "[{]([A-Za-z_][A-Za-z0-9_]*)[}]"

## 負數顯示用的減號:U+2212(與 design/narrative/card-face-text-14-2026-11-18.md 一致),
## 非 ASCII 連字號。正數不加正號(要「+3」的牌面由樣板作者寫成 "+{delta_atk}")。
const MINUS_SIGN: String = "−"


## 把 [param text] 內的 [code]{欄位名}[/code] 以 [param card] 對應欄位的數字取代並回傳。
## 不含記號的文字原樣回傳。未知記號 -> [code]push_error[/code] 並【保留原記號字樣】
## (畫面看得出錯,不靜默變成空字串或 0);不用 assert(release 匯出會被剝除)。
## 集中於此一處:battle_screen.gd 所有牌面文字取用處皆須走本函式。
static func render(card: Card, text: String) -> String:
	if card == null or text.find("{") == -1:
		return text
	var regex: RegEx = RegEx.new()
	regex.compile(_TEMPLATE_PATTERN)
	var out: String = ""
	var cursor: int = 0
	for m: RegExMatch in regex.search_all(text):
		out += text.substr(cursor, m.get_start() - cursor)
		cursor = m.get_end()
		var token: String = m.get_string(1)
		if not _is_known_token(token):
			push_error(
				"CardText.render: unknown template token {%s} in card '%s' text; kept verbatim."
				% [token, card.id]
			)
			out += m.get_string()
			continue
		out += _format_number(int(card.get(token)))
	out += text.substr(cursor)
	return out


static func _is_known_token(token: String) -> bool:
	return token in [
		"cost_amount", "effect_value", "target_range", "delta_atk", "delta_def",
		"duration_rounds", "affinity_magnitude",
	]


static func _format_number(value: int) -> String:
	if value < 0:
		return MINUS_SIGN + str(-value)
	return str(value)
