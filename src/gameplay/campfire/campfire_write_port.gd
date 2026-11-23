## CampfireWritePort -- 營火「任選兩人,關心 +m / 質問 -m」的寫入口。
##
## 實作依據:production/epics/campfire/story-002-campfire-write-port.md;
## 裁決 docs/reviews/campfire-rulings-2026-11-20.md(每輪 3 次、同輪同組不可重複)、
## docs/reviews/campfire-rulings-2026-11-23.md(來源值)、
## docs/reviews/campfire-open-tech-2026-11-23.md 題 1(探針 (A) 級)。
##
## 規則:
## - 寫進戰役累積記錄 [CampaignAffinityLedger],來源值一律 [code]SUPPORT_CONVERSATION[/code]
##   (不追加 CAMPFIRE;[code]COMBAT_CARD[/code] 會被折成約 0.275 倍,不可用)。
## - 【不】呼叫 [method PermanentAffinityWriteRules.legal_pairs](丙類卡路徑):
##   10 組任一皆可,含麥子健(CHARACTER_5)的 4 組。
## - 寫入先後:每次玩家確認一個動作【立即】寫一筆、依確認先後附加;不批次、不排序、不重排。
## - 拒絕(同一角色、非法角色、本輪次數用完、本輪已選過這一組)零寫入,
##   回傳非 NONE 的 [enum Rejection],可用 [method rejection_text] 取可讀原因。
## - 回傳 enum 的函式不用 assert()(失敗會回序數 0 = NONE = 成功,見 coding-standards)。
##
## 本類別不持有池;寫入後的 v 以 [method rebuild_pool] 委託共用的
## [CampaignAffinityPoolRebuilder] 重建(單一重播實作),關係狀態用
## [method AffinityRelation.state_of]。
##
## 「每輪開始清空」由誰在何時呼叫 [method begin_round],與 story-006/015 介接。
##
## 受保護的覆寫點([code]_is_pair_writable[/code]、[code]_signed_amount[/code]、
## [code]_round_budget_left[/code]、[code]_is_repeat_this_round[/code]、[code]_source_value[/code])
## 存在的唯一理由是讓敏感度證明能以子類別注入 mutant,不是擴充點。
class_name CampfireWritePort
extends RefCounted

enum Action { CARE, QUESTION }

## 第 0 值 = NONE = 成功。呼叫端必須檢查,不得忽略回傳值。
enum Rejection { NONE, SAME_CHARACTER, INVALID_CHARACTER, INVALID_ACTION, NO_ACTIONS_LEFT, PAIR_ALREADY_CHOSEN, NO_LEDGER }

var _ledger: CampaignAffinityLedger
var _knobs: CampfireKnobs
var _used_this_round: int = 0
var _chosen_pairs: Dictionary = {}


func _init(ledger: CampaignAffinityLedger, knobs: CampfireKnobs) -> void:
	_ledger = ledger
	_knobs = knobs


## 開始新的一輪營火:清空本輪次數與「本輪已選過的組」。
func begin_round() -> void:
	_used_this_round = 0
	_chosen_pairs.clear()


## 本輪還能確認幾次。
func actions_left() -> int:
	return maxi(_knobs.actions_per_round() - _used_this_round, 0)


## 確認一個動作:對 [param a]、[param b] 做 [param action]。成功時立即寫一筆
## [code](pair, ±m, SUPPORT_CONVERSATION)[/code] 進 ledger 並回 [constant Rejection.NONE]。
func confirm(a: AffinityTypes.Character, b: AffinityTypes.Character, action: Action) -> Rejection:
	if _ledger == null or _knobs == null:
		push_error("CampfireWritePort.confirm: ledger or knobs is null, nothing written")
		return Rejection.NO_LEDGER
	if not AffinityTypes.is_valid_character(a) or not AffinityTypes.is_valid_character(b):
		return Rejection.INVALID_CHARACTER
	if a == b:
		return Rejection.SAME_CHARACTER
	if action != Action.CARE and action != Action.QUESTION:
		return Rejection.INVALID_ACTION
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(a, b)
	if not _is_pair_writable(pair):
		return Rejection.INVALID_CHARACTER
	if _round_budget_left() <= 0:
		return Rejection.NO_ACTIONS_LEFT
	if _is_repeat_this_round(pair):
		return Rejection.PAIR_ALREADY_CHOSEN
	_ledger.append(pair, _signed_amount(action), _source_value())
	_used_this_round += 1
	_chosen_pairs[pair] = true
	return Rejection.NONE


## 以目前 ledger 重建池(委託共用純函式),供產卡讀 v。
func rebuild_pool() -> AffinityDataPool:
	return CampaignAffinityPoolRebuilder.rebuild(_ledger)


## 拒絕原因的可讀文字(開發/測試用,非玩家可見字串)。
static func rejection_text(rejection: Rejection) -> String:
	match rejection:
		Rejection.NONE:
			return "ok"
		Rejection.SAME_CHARACTER:
			return "same character chosen twice"
		Rejection.INVALID_CHARACTER:
			return "invalid character"
		Rejection.INVALID_ACTION:
			return "invalid action"
		Rejection.NO_ACTIONS_LEFT:
			return "no actions left this round"
		Rejection.PAIR_ALREADY_CHOSEN:
			return "pair already chosen this round"
		Rejection.NO_LEDGER:
			return "ledger or knobs missing"
		_:
			return "unknown rejection"


# ---- 覆寫點(僅供敏感度證明)-------------------------------------------------

func _is_pair_writable(_pair: AffinityTypes.Pair) -> bool:
	return true


func _signed_amount(action: Action) -> float:
	return _knobs.m() if action == Action.CARE else -_knobs.m()


func _round_budget_left() -> int:
	return actions_left()


func _is_repeat_this_round(pair: AffinityTypes.Pair) -> bool:
	return _chosen_pairs.has(pair)


func _source_value() -> AffinityTypes.Source:
	return AffinityTypes.Source.SUPPORT_CONVERSATION
