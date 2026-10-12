## ThreatTargetsResult — QueryResult 子類別,包裝 BattleController.threat_targets() 的酬載。
##
## 設計文件: docs/architecture/adr-0001-tactical-query-atomicity-contract.md
## 任務: 落地 QueryResult 契約型別,遷移「會被合併顯示」的查詢子集之一
## (docs/architecture/query-result-scope-boundary-2026-10-12.md)。
##
## 為何不與 [MoveTargetsResult] / [AttackTargetsResult] 共用同一個泛用型別:
## 理由見 [MoveTargetsResult] 檔頭,此處不複述。
class_name ThreatTargetsResult
extends QueryResult

var cells: Array[Vector2i]

func _init(source: BattleState, cells_payload: Array[Vector2i]) -> void:
	super(source)
	cells = cells_payload
