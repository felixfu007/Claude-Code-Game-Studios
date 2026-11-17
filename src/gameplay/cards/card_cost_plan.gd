# CardCostPlan —— 一張卡「這次要付什麼代價」的結果物件(story-015)。
#
# 面板(020)顯示的資料與實際扣款共用同一個物件:CardPlaySession 的預覽與 confirm()
# 都經由同一個建構函式產生它,不得各算一次(AC6)。
#
# reason 第 0 值 NONE = 可打(專案慣例);所有失敗路徑一律明確給非 NONE 的原因,
# 不用 assert() 守衛 enum 回傳。
class_name CardCostPlan
extends RefCounted

## 代價種類。NONE = 無代價(預設)。
enum Kind { NONE, HP, WEAR }

## 不可打原因。NONE = 可打。
enum Reason {
	NONE,
	UNRESOLVED_CATEGORY, ## 卡類別尚無法結算(017~019 前的新類別)。
	UNSUPPORTED_COST_TYPE, ## AFFINITY:列舉保留、卡表不使用,此處一律拒絕。
	PAYER_MISSING, ## 付款人無法確定(named 與施放者皆未定)。
	PARTNER_ABSENT, ## 付款人或夥伴不在場(不存在或已倒下)。
	OUT_OF_RANGE, ## 兩人距離超過 target_range。
	CANNOT_AFFORD_HP, ## 付血須 hp > cost,付不起。
	WEAR_CAP_REACHED, ## 該配對本場折損已達上限。
	RELATION_UNRESOLVED, ## 無法解析配對關係態(缺池或單位編號非法)。
	NO_LEGAL_TARGET, ## 甲類:目前沒有合法承受者(story-009 的點名者不在場)。
}

var kind: Kind = Kind.NONE
var reason: Reason = Reason.NONE
## 付款人 roster id(HP 與 WEAR 的 NONE 分支皆為付血對象;WEAR 時為折損涉及的兩人)。
var payer_ids: Array[int] = []
## 每位付款人付的點數(HP:血;WEAR:折損)。
var amount: int = 0
## WEAR 或 PAIR 卡所屬配對([enum AffinityTypes.Pair] 序數);無配對為 -1。
var pair: int = -1
## PAIR 卡解析出的關係態([enum AffinityRelation.RelationState] 序數)。
var relation: int = AffinityRelation.RelationState.NONE


func is_payable() -> bool:
	return reason == Reason.NONE


static func rejected(p_reason: Reason) -> CardCostPlan:
	var plan: CardCostPlan = CardCostPlan.new()
	plan.reason = p_reason
	return plan


## 付款人集合(純函式,答案檔題 1):named_unit_id 一律是付款人(< 1 時由施放者
## [param caster_id] 擔任);PAIR 且非補血類 -> named 與 partner 兩人皆付;
## PAIR 且補血類(HEAL)-> 只有 named 付;HP -> 只有 named 付;其他 -> 無。
static func payers_of(card: Card, caster_id: int) -> Array[int]:
	var result: Array[int] = []
	var payer: int = card.named_unit_id if card.named_unit_id >= 1 else caster_id
	match card.cost_type:
		Card.CostType.HP:
			if payer >= 1:
				result.append(payer)
		Card.CostType.PAIR:
			if payer >= 1:
				result.append(payer)
				if card.category != Card.Category.HEAL and card.partner_unit_id >= 1:
					result.append(card.partner_unit_id)
		_:
			pass
	return result


## roster id 一對 -> [enum AffinityTypes.Pair];任一 id 非法或相同回 null(不呼叫 pair_of()
## 於未驗證輸入,ADR-0002 機制四之四)。
static func pair_of_units(unit_a: int, unit_b: int) -> Variant:
	var offset: int = AffinityPoolWritePort.ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET
	var char_a: AffinityTypes.Character = (unit_a - offset) as AffinityTypes.Character
	var char_b: AffinityTypes.Character = (unit_b - offset) as AffinityTypes.Character
	if not AffinityTypes.is_valid_character(char_a) or not AffinityTypes.is_valid_character(char_b):
		return null
	if char_a == char_b:
		return null
	return AffinityTypes.pair_of(char_a, char_b)
