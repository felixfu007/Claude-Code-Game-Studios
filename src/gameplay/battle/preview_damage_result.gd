## PreviewDamageResult — QueryResult 子類別,包裝 BattleState.preview_damage() 的酬載。
##
## 設計文件: docs/architecture/adr-0001-tactical-query-atomicity-contract.md
## 任務: 落地 QueryResult 契約型別,遷移「會被合併顯示」的查詢子集之一
## (docs/architecture/query-result-scope-boundary-2026-10-12.md 第三節 #5)。
##
## 與 [DamageBreakdownResult] 的差別:後者包裝 [method
## BattleState.preview_damage_breakdown] 的完整 6 欄 Dictionary;本類別包裝
## [method BattleState.preview_damage] 既有的單一 int 傷害值 —— 兩個公開方法
## 刻意保留各自既有的回傳形狀(一個是結構化明細、一個是單一數字),這次遷移
## 只替每個方法換上各自的版本號包裝容器,不把兩者合併成同一個型別。
class_name PreviewDamageResult
extends QueryResult

var damage: int

func _init(source: BattleState, damage_payload: int) -> void:
	super(source)
	damage = damage_payload
