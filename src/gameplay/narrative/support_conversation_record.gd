## 支援對話資料表(系統 #8)單筆記錄,與其觸發狀態機。
##
## 純資料持有者,不含任何好感度數學,也不碰任何檔案存取 —— 解析與讀檔刻意分離
## (mirrors [method AffinityLink.links_from_text] / [method Unit.roster_from_text]
## 既有慣例),這正是本類別的單元測試不必碰檔案系統的理由。
##
## 規格權威:design/quick-specs/support-conversation-system.md 第 2/3/5 節
## 內容來源:design/quick-specs/mvp-five-levels-skeleton.md 第三部分(Q1~Q3 已結案)
## Story:production/epics/support-conversation/story-001-data-table-and-trigger-rules.md
class_name SupportConversationRecord
extends RefCounted

## 三段對話各自的 valence(規格第 2 節)。
##
## 🔴 NEUTRAL 在 MVP 三段對話裡沒有任何一段使用(見
## assets/data/narrative/support_conversations.txt)。它觸發完成時該寫入好感度池
## 多少量值,規格從未定案 —— 見 [method SupportConversationRules.magnitude_for_valence]
## 的文件註解,此處不重複。
enum Valence { POSITIVE, NEGATIVE, NEUTRAL }

## 觸發狀態機(規格第 3 節「完成時機規則」、第 5 節「未支援時的處置規則」;
## 本 story AC-3/AC-7)。
##
## 🔴 刻意只有這三個值 —— AC-7 要求「沒有『可延後』這個狀態」要體現在型別上,
## 不是靠註解宣告:這個列舉裡找不到任何 DEFERRED/PENDING/CONFIRMED 之類的中繼狀態,
## 這就是「不存在」的具體寫法。合法轉移只有
## NOT_TRIGGERED -> COMPLETED 與 NOT_TRIGGERED -> SKIPPED,兩者皆為終態 ——
## 見 [constant _TRANSITIONS] 與 [method try_transition]。
enum TriggerState { NOT_TRIGGERED, COMPLETED, SKIPPED }

## 每列固定的逗號分隔欄位數:
## conversation_id,trigger_after_mission,pair_a,pair_b,valence
const FIELD_COUNT: int = 5

## [enum TriggerState] 的顯式轉移表(`.claude/rules/gameplay-code.md`:
## 「狀態機必須有明確的轉移表」)。鍵為起始狀態,值為該狀態下全部合法的目的狀態。
## COMPLETED / SKIPPED 兩者皆為終態 —— 清單皆為空陣列,任何嘗試從終態再轉移的呼叫
## 都會被 [method try_transition] 拒絕,包含嘗試轉回 NOT_TRIGGERED。
const _TRANSITIONS: Dictionary = {
	TriggerState.NOT_TRIGGERED: [TriggerState.COMPLETED, TriggerState.SKIPPED],
	TriggerState.COMPLETED: [],
	TriggerState.SKIPPED: [],
}

var conversation_id: String
var trigger_after_mission: int

## 參與此段對話的兩個角色,採用與 [member AffinityLink.unit_a] /
## [member AffinityLink.unit_b] 相同的慣例:
## assets/data/units/vs01_roster.txt 的名冊 id(1=甲 2=乙 3=丙 4=丁 5=戊),
## 不是 [enum AffinityTypes.Character] 的序數。轉成 [enum AffinityTypes.Character]
## 的時機與責任屬 [method SupportConversationRules.trigger],本類別自己不做這個轉換,
## 只在解析時用 [AffinityRosterCharacterMapper] 驗證兩者是否為合法的角色名冊 id
## (見 [method from_csv_line])。
var pair_a: int
var pair_b: int

var valence: Valence

## 本段對話目前的觸發狀態,初始必為 [constant TriggerState.NOT_TRIGGERED]
## (規格第 2 節:資料表本身不記錄進度,狀態是執行期疊加上去的,不是資料表的欄位)。
var state: TriggerState = TriggerState.NOT_TRIGGERED


## 嘗試把 [member state] 轉移到 [param to]。合法則套用並回傳 [code]true[/code];
## 不合法(不在 [constant _TRANSITIONS] 的允許清單內,包含原地不動)則
## [method push_error] 並回傳 [code]false[/code],[member state] 維持不變 ——
## 明確拒絕,不靜默吞掉非法轉移(本 story AC-3)。
func try_transition(to: TriggerState) -> bool:
	var allowed: Array = _TRANSITIONS.get(state, [])
	if not allowed.has(to):
		push_error(
			"SupportConversationRecord.try_transition: illegal transition %d -> %d for '%s'"
			% [state, to, conversation_id]
		)
		return false
	state = to
	return true


## 解析資料表的 valence 欄位字串,回傳對應的 [enum Valence],未知字串回傳
## [code]null[/code]。
##
## 🔴 用 [code]match[/code] 而非把字串直接當列舉名稱查詢 —— 後者對未知名稱會中止
## 呼叫函式(已登記禁用模式 raw_enum_name_subscript_from_untrusted_string,見
## [method AffinityLink._polarity_from_string] 的文件註解)。回傳 [code]null[/code]
## 而不是 [code]assert(false, ...)[/code]:依 `.claude/docs/coding-standards.md`
## 2026-09-15 條目,若此函式直接回傳裸 [enum Valence] 並用 assert 守衛未知分支,
## 失敗時會中止並靜默回傳序數 0([constant Valence.POSITIVE]),讓資料檔打錯字被
## 當成合法的正向對話。
static func _valence_from_string(value: String) -> Variant:
	match value:
		"positive":
			return Valence.POSITIVE
		"negative":
			return Valence.NEGATIVE
		"neutral":
			return Valence.NEUTRAL
		_:
			return null


## 解析單一資料列成 [SupportConversationRecord],或在下列任一情況回傳
## [code]null[/code](本 story AC-2,「畸形輸入必須有明確的拒絕行為,不得靜默吞掉」):
## 欄位數不對、valence 欄位無法辨識、pair_a/pair_b 不是合法的角色名冊 id、或
## pair_a 與 pair_b 相同(自己跟自己不構成一段對話)。欄位順序固定:
## conversation_id,trigger_after_mission,pair_a,pair_b,valence。
##
## 🔴 [b]2026-10-19 刻意偏離 [method Unit.from_csv_line] / [method
## AffinityLink.from_csv_line] 的既有慣例[/b]:那兩者的欄位數檢查用
## [code]assert()[/code] 中止(本函式回傳物件參照,assert 失敗的預設值是
## [code]null[/code],不是任何看似合法的列舉序數,所以原本不落入
## `.claude/docs/coding-standards.md` 2026-09-15 條目禁止的「assert 守衛 enum
## 回傳」陷阱——那個陷阱只發生在函式本身回傳型別是 enum 的情況)。[b]但實測
## GdUnit4 會把 [code]assert()[/code] 失敗本身算成測試錯誤、判整條測試
## FAILED,不論函式事後是否照常回傳 [code]null[/code][/b]——這與
## [code]Board.passable()[/code] 對「未登記地形字元」改用 push_error() 而非
## assert() 是同一類考量(見該方法文件註解引用同一條 coding-standards.md
## 2026-09-15 條目),且已由既有測試
## [code]board_passable_test.gd[/code] 的
## [code]test_unregistered_terrain_character_returns_explicit_sentinels_not_silent_fallback[/code]
## 證實:該測試直接呼叫觸發 push_error() 的路徑,未包
## [code]assert_error()[/code],測試照樣通過。本函式因此選擇用
## push_error() + 明確 return null 取代 assert()——行為對呼叫端完全不變
## (一樣印出錯誤、一樣回傳 null),換來的是這條路徑從「不可測」變成「有
## 自動化測試防線」(見
## [code]tests/unit/gameplay/narrative/support_conversation_record_test.gd[/code]
## 的 [code]test_from_csv_line_wrong_field_count_returns_null[/code])。
## [b]只偏離本檔自己,不回頭修改 [Unit]/[AffinityLink] ——兩者不在本 story
## 範圍內。[/b] valence 未知字串、pair_a/pair_b 非法角色 id 兩者同樣用
## push_error() + 明確 return null,三者現在用的是同一套拒絕慣例。
static func from_csv_line(line: String) -> SupportConversationRecord:
	var fields: PackedStringArray = line.split(",")
	if fields.size() != FIELD_COUNT:
		push_error(
			"SupportConversationRecord.from_csv_line: expected %d fields, got %d in line: %s"
			% [FIELD_COUNT, fields.size(), line]
		)
		return null

	var record: SupportConversationRecord = SupportConversationRecord.new()
	record.conversation_id = fields[0]
	record.trigger_after_mission = int(fields[1])

	var parsed_pair_a: int = int(fields[2])
	var parsed_pair_b: int = int(fields[3])

	if AffinityRosterCharacterMapper.character_for_roster_id(parsed_pair_a) == null:
		push_error(
			"SupportConversationRecord.from_csv_line: unknown pair_a '%s' in line: %s"
			% [fields[2], line]
		)
		return null
	if AffinityRosterCharacterMapper.character_for_roster_id(parsed_pair_b) == null:
		push_error(
			"SupportConversationRecord.from_csv_line: unknown pair_b '%s' in line: %s"
			% [fields[3], line]
		)
		return null
	if parsed_pair_a == parsed_pair_b:
		push_error(
			"SupportConversationRecord.from_csv_line: pair_a and pair_b are the same character "
			+ "in line: %s" % line
		)
		return null
	record.pair_a = parsed_pair_a
	record.pair_b = parsed_pair_b

	var valence: Variant = _valence_from_string(fields[4])
	if valence == null:
		push_error(
			"SupportConversationRecord.from_csv_line: unknown valence '%s' in line: %s"
			% [fields[4], line]
		)
		return null
	record.valence = valence
	return record


## 解析整張支援對話資料表文字,一列一筆。空行與 [code]#[/code] 開頭的註解行會被跳過。
##
## 🔴 任何一列解析失敗 -> 回傳 [code]null[/code](不是空陣列),並記錄 1-based 行號
## —— 與 [method AffinityLink.links_from_text] 相同的「響亮地停」慣例(2026-09-16
## 管理者裁決):空陣列是合法狀態(代表「這張表目前沒有任何一列」),不能跟「某一列
## 資料壞掉」混為一談,呼叫端必須能區分兩者。回傳型別是 [Variant] 而非
## [code]Array[SupportConversationRecord][/code],純粹為了讓 [code]null[/code]
## 可以被表達。
static func records_from_text(text: String) -> Variant:
	var records: Array[SupportConversationRecord] = []
	var line_number: int = 0
	for raw_line: String in text.split("\n"):
		line_number += 1
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var record: SupportConversationRecord = from_csv_line(line)
		if record == null:
			push_error(
				"SupportConversationRecord.records_from_text: aborting -- invalid data at line %d: %s"
				% [line_number, line]
			)
			return null
		records.append(record)
	return records
