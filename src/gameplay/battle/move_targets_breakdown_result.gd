## MoveTargetsBreakdownResult — QueryResult 子類別,包裝 BattleController.move_targets_breakdown() 的酬載。
##
## 設計文件: docs/architecture/adr-0001-tactical-query-atomicity-contract.md
## 任務: 落地 QueryResult 契約型別並遷移 move_targets_breakdown / preview_damage_breakdown
##
## breakdown 故意宣告為無型別參數的 Dictionary —— 其值是異質的(int、Array 等混合),
## 型別化字典（Dictionary[String, int]）無法表達。
class_name MoveTargetsBreakdownResult
extends QueryResult

var breakdown: Dictionary

func _init(source: BattleState, breakdown_payload: Dictionary) -> void:
	super(source)
	breakdown = breakdown_payload
