# AffinityTuning —— AffinityRules 曲線與 Φ 夾限七項旋鈕的不可變設定物件。
#
# 規格:production/epics/tuning-data/story-005-affinity-rules-tuning.md
# 管理者 2026-11-04 裁決:「現在搬」「大聲報錯」「距離留在程式」
# (DISTANCE_ADJACENT / DISTANCE_FAR 不搬,仍是 AffinityRules 的 const)。
#
# 數字的唯一來源:AffinityRules 的同名常數(暫留作 defaults() 來源);
# TuningKnobs.KNOWN_KEYS 預設值指向它們,本檔不寫字面數字。
#
# 🔴 phi_min / phi_max 是承重值:調它們就是調戰鬥力的上下限。
# 夾限只在 AffinityRules.bonus_breakdown_for_at() 對加總後的總和夾一次
# (docs/registry/architecture.yaml forbidden pattern phi_clamp_treated_as_a_safety_net),
# 本物件只提供上下限數值,不做夾限。
#
# 驗證(失敗回 null 並 push_error,不用 assert()):
#   - phi_min <= phi_max
class_name AffinityTuning
extends RefCounted


const SECTION: String = "affinity"
const KEY_DELTA_POSITIVE_ADJACENT: String = "delta_positive_adjacent"
const KEY_DELTA_POSITIVE_FAR: String = "delta_positive_far"
const KEY_DELTA_NEGATIVE_ADJACENT: String = "delta_negative_adjacent"
const KEY_DELTA_NEGATIVE_FAR: String = "delta_negative_far"
const KEY_DELTA_NEUTRAL: String = "delta_neutral"
const KEY_PHI_MIN: String = "phi_min"
const KEY_PHI_MAX: String = "phi_max"

var _delta_positive_adjacent: int = 0
var _delta_positive_far: int = 0
var _delta_negative_adjacent: int = 0
var _delta_negative_far: int = 0
var _delta_neutral: int = 0
var _phi_min: int = 0
var _phi_max: int = 0


## 今日值(來自 TuningKnobs.defaults())。
static func defaults() -> AffinityTuning:
	return _build(TuningKnobs.defaults())


## 由已解析的 [TuningKnobs] 建立並驗證。失敗回 null 並 push_error。
static func from_knobs(knobs: TuningKnobs) -> Variant:
	var tuning: AffinityTuning = _build(knobs)
	if tuning._phi_min > tuning._phi_max:
		push_error("AffinityTuning: affinity.phi_min (%d) must be <= phi_max (%d)" % [tuning._phi_min, tuning._phi_max])
		return null
	return tuning


## 純解析便利入口:文字 -> TuningKnobs(要求鍵齊全)-> AffinityTuning。任一步失敗回 null。
static func from_text(text: String) -> Variant:
	var parsed: Variant = TuningKnobs.from_text(text)
	if parsed == null:
		return null
	return from_knobs(parsed as TuningKnobs)


static func _build(knobs: TuningKnobs) -> AffinityTuning:
	var t: AffinityTuning = AffinityTuning.new()
	t._delta_positive_adjacent = knobs.get_int(SECTION, KEY_DELTA_POSITIVE_ADJACENT)
	t._delta_positive_far = knobs.get_int(SECTION, KEY_DELTA_POSITIVE_FAR)
	t._delta_negative_adjacent = knobs.get_int(SECTION, KEY_DELTA_NEGATIVE_ADJACENT)
	t._delta_negative_far = knobs.get_int(SECTION, KEY_DELTA_NEGATIVE_FAR)
	t._delta_neutral = knobs.get_int(SECTION, KEY_DELTA_NEUTRAL)
	t._phi_min = knobs.get_int(SECTION, KEY_PHI_MIN)
	t._phi_max = knobs.get_int(SECTION, KEY_PHI_MAX)
	return t


func delta_positive_adjacent() -> int:
	return _delta_positive_adjacent


func delta_positive_far() -> int:
	return _delta_positive_far


func delta_negative_adjacent() -> int:
	return _delta_negative_adjacent


func delta_negative_far() -> int:
	return _delta_negative_far


func delta_neutral() -> int:
	return _delta_neutral


func phi_min() -> int:
	return _phi_min


func phi_max() -> int:
	return _phi_max
