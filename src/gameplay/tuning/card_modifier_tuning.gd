# CardModifierTuning —— CardModifierRules 四項夾限的不可變設定物件。
#
# 規格:production/epics/tuning-data/story-003-card-modifier-tuning.md
# 管理者 2026-11-04 裁決:「現在搬」「大聲報錯」。
#
# 數字的唯一來源:CardModifierRules.ATK_DELTA_MIN / ATK_DELTA_MAX / DEF_DELTA_MIN / DEF_DELTA_MAX
# (常數暫留作 defaults() 來源);TuningKnobs.KNOWN_KEYS 的預設值指向它們,本檔不寫字面數字。
#
# 驗證(失敗回 null 並 push_error,不用 assert()):
#   - atk_delta_min <= atk_delta_max
#   - def_delta_min <= def_delta_max
class_name CardModifierTuning
extends RefCounted


const SECTION: String = "card_modifier"
const KEY_ATK_MIN: String = "atk_delta_min"
const KEY_ATK_MAX: String = "atk_delta_max"
const KEY_DEF_MIN: String = "def_delta_min"
const KEY_DEF_MAX: String = "def_delta_max"

var _atk_delta_min: int = 0
var _atk_delta_max: int = 0
var _def_delta_min: int = 0
var _def_delta_max: int = 0


## 今日值(來自 TuningKnobs.defaults())。
static func defaults() -> CardModifierTuning:
	var knobs: TuningKnobs = TuningKnobs.defaults()
	var tuning: CardModifierTuning = CardModifierTuning.new()
	tuning._atk_delta_min = knobs.get_int(SECTION, KEY_ATK_MIN)
	tuning._atk_delta_max = knobs.get_int(SECTION, KEY_ATK_MAX)
	tuning._def_delta_min = knobs.get_int(SECTION, KEY_DEF_MIN)
	tuning._def_delta_max = knobs.get_int(SECTION, KEY_DEF_MAX)
	return tuning


## 由已解析的 [TuningKnobs] 建立並驗證。失敗回 null 並 push_error。
static func from_knobs(knobs: TuningKnobs) -> Variant:
	var atk_min: int = knobs.get_int(SECTION, KEY_ATK_MIN)
	var atk_max: int = knobs.get_int(SECTION, KEY_ATK_MAX)
	var def_min: int = knobs.get_int(SECTION, KEY_DEF_MIN)
	var def_max: int = knobs.get_int(SECTION, KEY_DEF_MAX)
	if atk_min > atk_max:
		push_error("CardModifierTuning: card_modifier.atk_delta_min (%d) must be <= atk_delta_max (%d)" % [atk_min, atk_max])
		return null
	if def_min > def_max:
		push_error("CardModifierTuning: card_modifier.def_delta_min (%d) must be <= def_delta_max (%d)" % [def_min, def_max])
		return null
	var tuning: CardModifierTuning = CardModifierTuning.new()
	tuning._atk_delta_min = atk_min
	tuning._atk_delta_max = atk_max
	tuning._def_delta_min = def_min
	tuning._def_delta_max = def_max
	return tuning


## 純解析便利入口:文字 -> TuningKnobs(要求鍵齊全)-> CardModifierTuning。任一步失敗回 null。
static func from_text(text: String) -> Variant:
	var parsed: Variant = TuningKnobs.from_text(text)
	if parsed == null:
		return null
	return from_knobs(parsed as TuningKnobs)


func atk_delta_min() -> int:
	return _atk_delta_min


func atk_delta_max() -> int:
	return _atk_delta_max


func def_delta_min() -> int:
	return _def_delta_min


func def_delta_max() -> int:
	return _def_delta_max
