# CardCostTuning —— 卡牌代價結算的兩個旋鈕(card.hp_cost_none、card.pair_cost_cap)。
#
# 規格:production/epics/skill-card-system/story-015-card-cost-settlement.md AC9。
# 資料來源:assets/data/tuning/tuning_knobs.txt 的 `card` 區(經 [TuningKnobs],與其他旋鈕同一套機制)。
#
# 偏離工單 AC9 原文(與 story-012 相同處理,協調者 2026-11-17 指示):工單寫「缺鍵 -> 預設值 +
# push_warning」,但專案規則(tuning-data epic,2026-11-04)是「旋鈕檔缺行一律載入失敗」,
# 故缺鍵/非整數由 [TuningKnobs.from_text] 整檔拒絕(回 null + push_error)。
# 本類別只多做一件事:值域驗證 2~5,超出整份拒絕(回 null + push_error)。不用 assert()。
class_name CardCostTuning
extends RefCounted

const SECTION: String = "card"
const KEY_HP_COST_NONE: String = "hp_cost_none"
const KEY_PAIR_COST_CAP: String = "pair_cost_cap"

const HP_COST_NONE_DEFAULT: int = 3
const PAIR_COST_CAP_DEFAULT: int = 3
const RANGE_MIN: int = 2
const RANGE_MAX: int = 5

var _hp_cost_none: int = HP_COST_NONE_DEFAULT
var _pair_cost_cap: int = PAIR_COST_CAP_DEFAULT


## 今日值(來自 TuningKnobs.defaults())。
static func defaults() -> CardCostTuning:
	return _build(TuningKnobs.defaults())


## 由已解析的 [TuningKnobs] 建立並驗證值域;失敗回 null 並 push_error。
static func from_knobs(knobs: TuningKnobs) -> Variant:
	var tuning: CardCostTuning = _build(knobs)
	if tuning._hp_cost_none < RANGE_MIN or tuning._hp_cost_none > RANGE_MAX:
		push_error(
			"CardCostTuning: card.hp_cost_none (%d) is outside %d~%d"
			% [tuning._hp_cost_none, RANGE_MIN, RANGE_MAX]
		)
		return null
	if tuning._pair_cost_cap < RANGE_MIN or tuning._pair_cost_cap > RANGE_MAX:
		push_error(
			"CardCostTuning: card.pair_cost_cap (%d) is outside %d~%d"
			% [tuning._pair_cost_cap, RANGE_MIN, RANGE_MAX]
		)
		return null
	return tuning


## 純解析便利入口:文字 -> TuningKnobs(要求鍵齊全)-> CardCostTuning。任一步失敗回 null。
static func from_text(text: String) -> Variant:
	var parsed: Variant = TuningKnobs.from_text(text)
	if parsed == null:
		return null
	return from_knobs(parsed as TuningKnobs)


static func _build(knobs: TuningKnobs) -> CardCostTuning:
	var t: CardCostTuning = CardCostTuning.new()
	t._hp_cost_none = knobs.get_int(SECTION, KEY_HP_COST_NONE)
	t._pair_cost_cap = knobs.get_int(SECTION, KEY_PAIR_COST_CAP)
	return t


## S=NONE 時每位付款人付的血。
func hp_cost_none() -> int:
	return _hp_cost_none


## 同一配對一場內累計折損上限。
func pair_cost_cap() -> int:
	return _pair_cost_cap
