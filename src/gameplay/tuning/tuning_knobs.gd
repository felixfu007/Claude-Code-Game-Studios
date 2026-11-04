# TuningKnobs —— 調整旋鈕的共用不可變設定物件(資料檔 -> 純解析 -> 注入 BattleState)。
#
# 規格:production/epics/tuning-data/story-001-tuning-skeleton.md
# 規劃:docs/reviews/tuning-knobs-data-driven-plan-2026-11-04.md 第 3 節(方案 B)
# 管理者 2026-11-04 裁決:「現在搬」「大聲報錯」。
#
# 設計約束:
#   - 純解析,不碰 FileAccess(讀檔留在組裝點 battle_screen.gd),比照
#     [method Unit.roster_from_text] / [method AffinityLink.links_from_text]。
#   - 失敗回 null 並 push_error;絕不使用 assert()(失敗的 assert 會讓回傳
#     宣告型別的序數 0,見 .claude/docs/coding-standards.md)。
#   - 檔案格式 `section,key,value`,`#` 註解,空行略過。
#   - 驗證:欄位數必為 3、值必為整數、重複鍵失敗、未知 section/key 失敗
#     (防打錯字靜默失效)。
#   - story-002 起 [constant KNOWN_KEYS] 含 deck 三鍵;story-003 增 card_modifier 四鍵;story-004 增 combat 九鍵;後續各 story 各自增補一個系統的鍵。
#   - 🔴 一律嚴格:known_keys 每個鍵都必須出現,缺任一個即失敗(大聲報錯裁決:資料檔刪行不得靜默退回程式內舊值)。
class_name TuningKnobs
extends RefCounted


## 已知鍵清單:`"section.key"` -> 預設值(int)。預設值即 [method defaults] 的內容,
## 也是「零行為變更」的錨點:每個 story 搬常數時必須讓這裡的值等於舊常數。
## story-002:deck 三鍵(預設值指向 CardDeck 常數,數字只有一個來源)。
const KNOWN_KEYS: Dictionary = {
	"deck.opening_hand_size": CardDeck.OPENING_HAND_SIZE,
	"deck.hand_size_limit": CardDeck.HAND_SIZE_LIMIT,
	"deck.cards_drawn_per_turn": CardDeck.CARDS_DRAWN_PER_TURN,
	# story-003:card_modifier 四鍵(預設值指向 CardModifierRules 常數)。
	"card_modifier.atk_delta_min": CardModifierRules.ATK_DELTA_MIN,
	"card_modifier.atk_delta_max": CardModifierRules.ATK_DELTA_MAX,
	"card_modifier.def_delta_min": CardModifierRules.DEF_DELTA_MIN,
	"card_modifier.def_delta_max": CardModifierRules.DEF_DELTA_MAX,
	# story-004:combat 九鍵(預設值指向 CombatRules 常數)。
	"combat.guard_min": CombatRules.GUARD_MIN,
	"combat.guard_max": CombatRules.GUARD_MAX,
	"combat.lone_far_distance": CombatRules.LONE_FAR_DISTANCE,
	"combat.lone_far_guard": CombatRules.LONE_FAR_GUARD,
	"combat.lone_near_distance": CombatRules.LONE_NEAR_DISTANCE,
	"combat.lone_near_guard": CombatRules.LONE_NEAR_GUARD,
	"combat.lone_mid_guard": CombatRules.LONE_MID_GUARD,
	"combat.hold_back_distance": CombatRules.HOLD_BACK_DISTANCE,
	"combat.hold_back_penalty": CombatRules.HOLD_BACK_PENALTY,
	# story-005:affinity 七鍵(預設值指向 AffinityRules 常數;距離門檻不搬)。phi_min/phi_max 為戰鬥力上下限(承重值)。
	"affinity.delta_positive_adjacent": AffinityRules.DELTA_POSITIVE_ADJACENT,
	"affinity.delta_positive_far": AffinityRules.DELTA_POSITIVE_FAR,
	"affinity.delta_negative_adjacent": AffinityRules.DELTA_NEGATIVE_ADJACENT,
	"affinity.delta_negative_far": AffinityRules.DELTA_NEGATIVE_FAR,
	"affinity.delta_neutral": AffinityRules.DELTA_NEUTRAL,
	"affinity.phi_min": AffinityRules.PHI_MIN,
	"affinity.phi_max": AffinityRules.PHI_MAX,
}

## 解析出的 `"section.key"` -> int。僅含實際在檔案中出現的鍵(defaults() 則含全部已知鍵)。
var _values: Dictionary = {}

## 是否由 [method defaults] 產生(未注入設定時的佔位)。診斷用,業務邏輯不得依賴。
var is_default: bool = false

## 解析來源文字的原樣保留(診斷用)。敏感度證明藉此分辨「注入的是哪一份檔案」
## —— 本張清單為空,無法靠鍵值分辨。業務邏輯不得依賴。
var diagnostic_source_text: String = ""


## 未注入時使用:值等於 [constant KNOWN_KEYS] 的預設值。
static func defaults() -> TuningKnobs:
	var knobs: TuningKnobs = TuningKnobs.new()
	knobs.is_default = true
	for composite: String in KNOWN_KEYS:
		knobs._values[composite] = int(KNOWN_KEYS[composite])
	return knobs


## 純解析。成功回 [TuningKnobs],任何格式/驗證錯誤回 null 並 push_error 說明。
## [param known_keys] 預設為 [constant KNOWN_KEYS];僅供單元測試注入清單以驗證
## 「未知鍵/重複鍵」等分支(production 呼叫端不傳)。
static func from_text(text: String, known_keys: Dictionary = KNOWN_KEYS) -> Variant:
	var knobs: TuningKnobs = TuningKnobs.new()
	knobs.diagnostic_source_text = text
	var line_no: int = 0
	for raw_line: String in text.split("\n"):
		line_no += 1
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(",")
		if fields.size() != 3:
			push_error("TuningKnobs.from_text: line %d: expected 3 fields (section,key,value), got %d" % [line_no, fields.size()])
			return null
		var section: String = fields[0].strip_edges()
		var key: String = fields[1].strip_edges()
		var value_text: String = fields[2].strip_edges()
		if section.is_empty() or key.is_empty():
			push_error("TuningKnobs.from_text: line %d: empty section or key" % line_no)
			return null
		if not value_text.is_valid_int():
			push_error("TuningKnobs.from_text: line %d: value '%s' is not an integer" % [line_no, value_text])
			return null
		var composite: String = "%s.%s" % [section, key]
		if knobs._values.has(composite):
			push_error("TuningKnobs.from_text: line %d: duplicate key '%s'" % [line_no, composite])
			return null
		if not known_keys.has(composite):
			push_error("TuningKnobs.from_text: line %d: unknown key '%s'" % [line_no, composite])
			return null
		knobs._values[composite] = value_text.to_int()
	for known: String in known_keys:
		if not knobs._values.has(known):
			push_error("TuningKnobs.from_text: missing required key '%s'" % known)
			return null
	return knobs


## 讀取一個旋鈕。檔案沒列出該鍵時回 [constant KNOWN_KEYS] 的預設值;
## 鍵本身未知時 push_error 並回 0(呼叫端打錯字不得靜默)。
func get_int(section: String, key: String) -> int:
	var composite: String = "%s.%s" % [section, key]
	if _values.has(composite):
		return int(_values[composite])
	if KNOWN_KEYS.has(composite):
		return int(KNOWN_KEYS[composite])
	push_error("TuningKnobs.get_int: unknown key '%s'" % composite)
	return 0


## 診斷:目前持有的鍵數(測試用)。
func diagnostic_value_count() -> int:
	return _values.size()
