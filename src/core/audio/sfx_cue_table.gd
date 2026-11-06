## 音效 cue 表解析(audio-foundation story-003,AC-5 / AC-6)。
##
## 純函式:吃 CSV 文字、回傳結果 Dictionary,不讀檔(讀檔留在組裝點,比照 tuning_knobs.gd)、
## 不 push_error / push_warning(壞列以回傳值回報,不洗版)。
class_name SfxCueTable
extends RefCounted

const CSV_PATH: String = "res://assets/data/audio/sfx_cues.txt"

const CUE_UI_CLICK: StringName = &"ui_click"
const CUE_UNIT_SELECT: StringName = &"unit_select"
const CUE_CANCEL: StringName = &"cancel"
const CUE_UNIT_MOVE: StringName = &"unit_move"
const CUE_ATTACK_HIT: StringName = &"attack_hit"
const CUE_UNIT_DOWN: StringName = &"unit_down"
const CUE_VICTORY: StringName = &"victory"
const CUE_DEFEAT: StringName = &"defeat"
const CUE_AFFINITY_UP: StringName = &"affinity_up"

## M1~M9 對應的九個 cue(M5/M6 各一)。
const REQUIRED_CUE_IDS: Array[StringName] = [
	CUE_UI_CLICK, CUE_UNIT_SELECT, CUE_CANCEL, CUE_UNIT_MOVE, CUE_ATTACK_HIT,
	CUE_UNIT_DOWN, CUE_VICTORY, CUE_DEFEAT, CUE_AFFINITY_UP,
]

const COLUMN_COUNT: int = 4


## 解析 CSV 文字。回傳 {"cues": {StringName: {"path": String, "min_interval_ms": int, "bus": StringName}},
## "errors": Array[String]}。壞列(欄數不對、空欄位、非數值/負數間隔、bus 不在 AudioBuses 子 bus、
## 重複 cue_id)被略過並記入 errors。
static func parse(text: String) -> Dictionary:
	var cues: Dictionary = {}
	var errors: Array[String] = []
	var line_no: int = 0
	for raw_line: String in text.split("\n"):
		line_no += 1
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var cols: PackedStringArray = line.split(",")
		if cols.size() > 0 and cols[0].strip_edges() == "cue_id":
			continue # 標題列
		if cols.size() != COLUMN_COUNT:
			errors.append("line %d: expected %d columns, got %d" % [line_no, COLUMN_COUNT, cols.size()])
			continue
		var cue_id: String = cols[0].strip_edges()
		var path: String = cols[1].strip_edges()
		var interval_text: String = cols[2].strip_edges()
		var bus: String = cols[3].strip_edges()
		if cue_id.is_empty() or path.is_empty() or bus.is_empty():
			errors.append("line %d: empty field" % line_no)
			continue
		if not interval_text.is_valid_int() or interval_text.to_int() < 0:
			errors.append("line %d: min_interval_ms not a non-negative integer" % line_no)
			continue
		if not is_valid_bus(StringName(bus)):
			errors.append("line %d: unknown bus '%s'" % [line_no, bus])
			continue
		if cues.has(StringName(cue_id)):
			errors.append("line %d: duplicate cue_id '%s'" % [line_no, cue_id])
			continue
		cues[StringName(cue_id)] = {
			"path": path,
			"min_interval_ms": interval_text.to_int(),
			"bus": StringName(bus),
		}
	return {"cues": cues, "errors": errors}


## AC-6:bus 名稱必須是 story-001 定義的子 bus 常數之一。
static func is_valid_bus(bus: StringName) -> bool:
	return AudioBuses.CHILD_BUSES.has(bus)


## 回傳 [param cues] 中缺少的必要 cue_id。
static func missing_required(cues: Dictionary) -> Array[StringName]:
	var missing: Array[StringName] = []
	for cue_id: StringName in REQUIRED_CUE_IDS:
		if not cues.has(cue_id):
			missing.append(cue_id)
	return missing
