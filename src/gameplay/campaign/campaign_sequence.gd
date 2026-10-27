## 戰役關卡序列表(story-003 AC1/AC2)單列資料的解析器。
##
## 純資料持有者,解析與讀檔刻意分離 —— 本類別完全不碰 [FileAccess],比照
## [method Unit.roster_from_text] / [method AffinityLink.links_from_text] /
## [method SupportConversationRecord.records_from_text] 既有慣例,這正是本類別
## 的單元測試不必碰檔案系統的理由。
##
## 規格權威:design/quick-specs/mvp-five-levels-skeleton.md 第一部分(5 場骨架)
## Story:production/epics/game-shell/story-003-campaign-flow-and-transition-slots.md
class_name CampaignSequence
extends RefCounted

## 每列固定的逗號分隔欄位數:
## mission_index,terrain_path,roster_path,affinity_path,cards_path,card_text_path
const FIELD_COUNT: int = 6

var mission_index: int
var terrain_path: String
var roster_path: String
var affinity_path: String
var cards_path: String
var card_text_path: String


## 解析單一資料列,或在欄位數不對時回傳 [code]null[/code](畸形輸入必須有明確的
## 拒絕行為,不得靜默吞掉 —— 比照 [method SupportConversationRecord.from_csv_line]
## 的既有慣例)。欄位順序固定:
## mission_index,terrain_path,roster_path,affinity_path,cards_path,card_text_path。
##
## 🔴 刻意不檢查路徑指向的檔案是否存在 —— 本類別只負責解析文字,檔案存在與否是
## 讀取端(未來接線時 [code]BattleScreen[/code] 既有的 MISSING/UNREADABLE 分類)
## 的責任,兩者分開是「解析與讀檔分離」這條既有慣例的直接推論。
static func from_csv_line(line: String) -> CampaignSequence:
	var fields: PackedStringArray = line.split(",")
	if fields.size() != FIELD_COUNT:
		push_error(
			"CampaignSequence.from_csv_line: expected %d fields, got %d in line: %s"
			% [FIELD_COUNT, fields.size(), line]
		)
		return null

	var record: CampaignSequence = CampaignSequence.new()
	record.mission_index = int(fields[0])
	record.terrain_path = fields[1]
	record.roster_path = fields[2]
	record.affinity_path = fields[3]
	record.cards_path = fields[4]
	record.card_text_path = fields[5]
	return record


## 解析整張戰役序列表文字,一列一筆。空行與 [code]#[/code] 開頭的註解行會被跳過。
##
## 🔴 任一列解析失敗 -> 回傳 [code]null[/code](不是半套陣列),比照
## [method SupportConversationRecord.records_from_text] 的「響亮地停」慣例 ——
## 空陣列是合法狀態(資料表目前沒有任何一列),不能跟「某一列資料壞掉」混為
## 一談。回傳型別是 [Variant] 而非 [code]Array[CampaignSequence][/code],純粹為了
## 讓 [code]null[/code] 可以被表達。
static func sequence_from_text(text: String) -> Variant:
	var records: Array[CampaignSequence] = []
	var line_number: int = 0
	for raw_line: String in text.split("\n"):
		line_number += 1
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var record: CampaignSequence = from_csv_line(line)
		if record == null:
			push_error(
				"CampaignSequence.sequence_from_text: aborting -- invalid data at line %d: %s"
				% [line_number, line]
			)
			return null
		records.append(record)
	return records
