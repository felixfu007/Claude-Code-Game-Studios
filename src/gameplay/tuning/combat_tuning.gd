# CombatTuning —— CombatRules 九項旋鈕的不可變設定物件。
#
# 規格:production/epics/tuning-data/story-004-combat-rules-tuning.md
# 管理者 2026-11-04 裁決:「現在搬」「大聲報錯」「刪掉」(LONE_MID_DISTANCE)。
#
# 數字的唯一來源:CombatRules 的同名常數(暫留作 defaults() 來源);
# TuningKnobs.KNOWN_KEYS 預設值指向它們,本檔不寫字面數字。
#
# 驗證(失敗回 null 並 push_error,不用 assert()):
#   - guard_min <= guard_max
#   - lone_near_distance < lone_far_distance
# 其餘七項無推導得出的不變式,不自行發明限制(見交付報告)。
class_name CombatTuning
extends RefCounted


const SECTION: String = "combat"
const KEY_GUARD_MIN: String = "guard_min"
const KEY_GUARD_MAX: String = "guard_max"
const KEY_LONE_FAR_DISTANCE: String = "lone_far_distance"
const KEY_LONE_FAR_GUARD: String = "lone_far_guard"
const KEY_LONE_NEAR_DISTANCE: String = "lone_near_distance"
const KEY_LONE_NEAR_GUARD: String = "lone_near_guard"
const KEY_LONE_MID_GUARD: String = "lone_mid_guard"
const KEY_HOLD_BACK_DISTANCE: String = "hold_back_distance"
const KEY_HOLD_BACK_PENALTY: String = "hold_back_penalty"

var _guard_min: int = 0
var _guard_max: int = 0
var _lone_far_distance: int = 0
var _lone_far_guard: int = 0
var _lone_near_distance: int = 0
var _lone_near_guard: int = 0
var _lone_mid_guard: int = 0
var _hold_back_distance: int = 0
var _hold_back_penalty: int = 0


## 今日值(來自 TuningKnobs.defaults())。
static func defaults() -> CombatTuning:
	return _build(TuningKnobs.defaults())


## 由已解析的 [TuningKnobs] 建立並驗證。失敗回 null 並 push_error。
static func from_knobs(knobs: TuningKnobs) -> Variant:
	var tuning: CombatTuning = _build(knobs)
	if tuning._guard_min > tuning._guard_max:
		push_error("CombatTuning: combat.guard_min (%d) must be <= guard_max (%d)" % [tuning._guard_min, tuning._guard_max])
		return null
	if tuning._lone_near_distance >= tuning._lone_far_distance:
		push_error("CombatTuning: combat.lone_near_distance (%d) must be < lone_far_distance (%d)" % [tuning._lone_near_distance, tuning._lone_far_distance])
		return null
	return tuning


## 純解析便利入口:文字 -> TuningKnobs(要求鍵齊全)-> CombatTuning。任一步失敗回 null。
static func from_text(text: String) -> Variant:
	var parsed: Variant = TuningKnobs.from_text(text)
	if parsed == null:
		return null
	return from_knobs(parsed as TuningKnobs)


static func _build(knobs: TuningKnobs) -> CombatTuning:
	var t: CombatTuning = CombatTuning.new()
	t._guard_min = knobs.get_int(SECTION, KEY_GUARD_MIN)
	t._guard_max = knobs.get_int(SECTION, KEY_GUARD_MAX)
	t._lone_far_distance = knobs.get_int(SECTION, KEY_LONE_FAR_DISTANCE)
	t._lone_far_guard = knobs.get_int(SECTION, KEY_LONE_FAR_GUARD)
	t._lone_near_distance = knobs.get_int(SECTION, KEY_LONE_NEAR_DISTANCE)
	t._lone_near_guard = knobs.get_int(SECTION, KEY_LONE_NEAR_GUARD)
	t._lone_mid_guard = knobs.get_int(SECTION, KEY_LONE_MID_GUARD)
	t._hold_back_distance = knobs.get_int(SECTION, KEY_HOLD_BACK_DISTANCE)
	t._hold_back_penalty = knobs.get_int(SECTION, KEY_HOLD_BACK_PENALTY)
	return t


func guard_min() -> int:
	return _guard_min


func guard_max() -> int:
	return _guard_max


func lone_far_distance() -> int:
	return _lone_far_distance


func lone_far_guard() -> int:
	return _lone_far_guard


func lone_near_distance() -> int:
	return _lone_near_distance


func lone_near_guard() -> int:
	return _lone_near_guard


func lone_mid_guard() -> int:
	return _lone_mid_guard


func hold_back_distance() -> int:
	return _hold_back_distance


func hold_back_penalty() -> int:
	return _hold_back_penalty
