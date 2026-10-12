## MoveTargetsResult — QueryResult 子類別,包裝 BattleController.move_targets() 的酬載。
##
## 設計文件: docs/architecture/adr-0001-tactical-query-atomicity-contract.md
## 任務: 落地 QueryResult 契約型別,遷移「會被合併顯示」的查詢子集之一
## (docs/architecture/query-result-scope-boundary-2026-10-12.md)。
##
## 🔴 2026-10-12 裁決:move_targets() / attack_targets() / threat_targets() 三支的酬載
## 形狀完全相同(一組 Vector2i 格座標),但刻意各自宣告一個具名子類別
## (本檔、[AttackTargetsResult]、[ThreatTargetsResult]),不共用同一個泛用型別 ——
## 理由是讓三者在型別系統裡保持可區分:若共用同一個子類別,呼叫端把
## move_targets() 的結果誤傳進期望 attack_targets() 結果的位置,編譯期無法發現
## (兩者型別相同,欄位名也相同);各自具名後,這類寫錯會在 parse 期被抓到,
## 不必等到執行期才看出欄位語意錯置。三支共用的理由(酬載形狀相同、重複度高)
## 確實成立,但 technical-director 2026-10-12 的裁決以「型別錯誤發現時機前移」
## 為優先。
class_name MoveTargetsResult
extends QueryResult

var cells: Array[Vector2i]

func _init(source: BattleState, cells_payload: Array[Vector2i]) -> void:
	super(source)
	cells = cells_payload
