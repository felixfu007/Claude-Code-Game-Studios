## 支援對話台詞順序表(assets/data/narrative/support_conversation_lines.txt)的解析器。
##
## 純 RefCounted/靜態函式,不碰檔案、不碰 Loc —— 讀檔與在地化由呼叫端負責
## (mirrors [method SupportConversationRecord.records_from_text] 的解析/讀檔分離慣例)。
## 本類別只回答「給 conversation_id → 依序的 (speaker_roster_id, text_key)」。
##
## 設計來源:production/epics/support-conversation-ui/story-002-dialogue-lines-data.md
## 劇本:design/narrative/support-conversations-script.md(Provisional)
class_name SupportConversationScript
extends RefCounted

## 每列固定欄位數:conversation_id,seq,speaker_roster_id,text_key
const FIELD_COUNT: int = 4

## 名冊 id 合法範圍(1=甲 … 5=戊,見 vs01_roster.txt)。
const SPEAKER_MIN: int = 1
const SPEAKER_MAX: int = 5

## 單列結果的鍵名。
const KEY_SPEAKER: String = "speaker_roster_id"
const KEY_TEXT_KEY: String = "text_key"


## 解析整張台詞表。成功回傳 [code]Dictionary[/code]:conversation_id(String)->
## [code]Array[/code] of [code]{speaker_roster_id: int, text_key: String}[/code](依 seq 順序)。
## 任一列有問題 -> [code]push_error[/code] 並回傳 [code]null[/code](不是空字典:
## 空表是合法狀態,與「某列壞掉」要能區分)。
##
## 拒絕條件:欄位數不是 4;seq 非整數或不是「該段上一列 + 1」(每段從 1 起、不得跳號/
## 重複/倒退);speaker 非整數或不在 1~5;conversation_id 不在 [param known_conversation_ids];
## text_key 為空;同一段的列不連續(中間插入別段)。
##
## 🔴 用 push_error + 明確 return null,不用 assert()(理由同 SupportConversationRecord.from_csv_line)。
static func script_from_text(text: String, known_conversation_ids: Array[String]) -> Variant:
	var result: Dictionary = {}
	var last_seq: Dictionary = {}
	var current_id: String = ""
	var line_number: int = 0
	for raw_line: String in text.split("\n"):
		line_number += 1
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(",")
		if fields.size() != FIELD_COUNT:
			return _reject("expected %d fields, got %d" % [FIELD_COUNT, fields.size()], line_number, line)
		var conversation_id: String = fields[0]
		if not known_conversation_ids.has(conversation_id):
			return _reject("unknown conversation_id '%s'" % conversation_id, line_number, line)
		if conversation_id != current_id and result.has(conversation_id):
			return _reject("rows of '%s' are not contiguous" % conversation_id, line_number, line)
		if not fields[1].is_valid_int() or not fields[2].is_valid_int():
			return _reject("seq or speaker_roster_id is not an integer", line_number, line)
		var seq: int = fields[1].to_int()
		var speaker: int = fields[2].to_int()
		if speaker < SPEAKER_MIN or speaker > SPEAKER_MAX:
			return _reject("speaker_roster_id %d outside %d..%d" % [speaker, SPEAKER_MIN, SPEAKER_MAX], line_number, line)
		var expected_seq: int = int(last_seq.get(conversation_id, 0)) + 1
		if seq != expected_seq:
			return _reject("seq %d, expected %d (must start at 1, no gaps)" % [seq, expected_seq], line_number, line)
		var text_key: String = fields[3]
		if text_key.is_empty():
			return _reject("empty text_key", line_number, line)
		if not result.has(conversation_id):
			result[conversation_id] = []
		(result[conversation_id] as Array).append({KEY_SPEAKER: speaker, KEY_TEXT_KEY: text_key})
		last_seq[conversation_id] = seq
		current_id = conversation_id
	return result


## 取某段對話的依序台詞;[param script] 為 [method script_from_text] 的成功結果。
## 找不到該 id -> push_error 並回傳空陣列。
static func lines_for(script: Dictionary, conversation_id: String) -> Array:
	if not script.has(conversation_id):
		push_error("SupportConversationScript.lines_for: unknown conversation_id '%s'" % conversation_id)
		return []
	return script[conversation_id]


static func _reject(reason: String, line_number: int, line: String) -> Variant:
	push_error(
		"SupportConversationScript.script_from_text: aborting -- %s at line %d: %s"
		% [reason, line_number, line]
	)
	return null
