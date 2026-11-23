## CampfireCardGenerator -- 營火產卡:合作卡(關心)/競爭卡(質問),強度為產卡當下的快照。
##
## 實作依據:production/epics/campfire/story-003-campfire-card-generation.md;
## docs/reviews/campfire-rules-gd-2026-11-20.md 題 2、3。
##
## 規則:
## - E = base + min(max_bonus, floor(max(0, v_signed - k) / pool_step)),
##   v_signed = +v(關心)/ -v(質問);k = [method AffinityTuning.neutral_band](由呼叫端傳入)。
## - 合作卡:delta_def = +E、delta_atk = 0;競爭卡:delta_atk = +E、delta_def = 模板固定值。
##   E 同時記入 effect_value(快照/顯示);戰鬥只讀 delta_*。
## - 付款人沿用 PAIR:named_unit_id = 第一人、partner_unit_id = 第二人(不寫新付款邏輯)。
## - 讀池只在 generate() 當下一次;之後池變動不影響已產出的卡(Card 為值,不持有池)。
## - 任何不合法輸入 push_error 並回 null(不用 assert)。
##
## 受保護的覆寫點(_k、_signed_v、_deltas)存在的唯一理由是讓敏感度證明注入 mutant。
class_name CampfireCardGenerator
extends RefCounted

var _template: CampfireCardTemplate
var _k_value: float


func _init(template: CampfireCardTemplate, k: float) -> void:
	_template = template
	_k_value = k


## 產一張營火卡。[param first]/[param second] 為所選兩人(順序即付款人/夥伴順序),
## [param action] 決定合作/競爭。池只在此刻讀取。失敗回 null。
func generate(
	card_id: String,
	first: AffinityTypes.Character,
	second: AffinityTypes.Character,
	action: CampfireWritePort.Action,
	pool: AffinityDataPool
) -> Card:
	if _template == null or pool == null:
		push_error("CampfireCardGenerator.generate: template or pool is null")
		return null
	if not AffinityTypes.is_valid_character(first) or not AffinityTypes.is_valid_character(second) or first == second:
		push_error("CampfireCardGenerator.generate: need two distinct valid characters")
		return null
	if action != CampfireWritePort.Action.CARE and action != CampfireWritePort.Action.QUESTION:
		push_error("CampfireCardGenerator.generate: invalid action %d" % action)
		return null
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(first, second)
	var read: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
	if read.rejection != AffinityDataPool.ReadRejection.NONE:
		push_error("CampfireCardGenerator.generate: pool read rejected (code %d)" % read.rejection)
		return null
	var v: float = read.value if read.n_pair > 0 else 0.0
	var e: int = _strength(_signed_v(action, v))
	var deltas: Vector2i = _deltas(action, e)
	var off: int = AffinityPoolWritePort.ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET
	return Card.new_camp_pair_card(
		card_id, deltas.x, deltas.y, _template.duration_rounds,
		int(first) + off, int(second) + off,
		_template.cost_amount, _template.target_range, e
	)


## 強度 E(純公式,[param signed_v] 已含關心/質問符號)。
func _strength(signed_v: float) -> int:
	var steps: int = floori(maxf(0.0, signed_v - _k()) / float(_template.pool_step))
	return _template.base_value + mini(_template.max_bonus, steps)


# ---- 覆寫點(僅供敏感度證明)-------------------------------------------------

func _k() -> float:
	return _k_value


func _signed_v(action: CampfireWritePort.Action, v: float) -> float:
	return v if action == CampfireWritePort.Action.CARE else -v


## x = delta_atk, y = delta_def。
func _deltas(action: CampfireWritePort.Action, e: int) -> Vector2i:
	if action == CampfireWritePort.Action.CARE:
		return Vector2i(0, e)
	return Vector2i(e, _template.competitive_delta_def)
