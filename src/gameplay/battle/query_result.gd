## QueryResult — ADR-0001 呈現層契約型別(戰棋查詢介面原子性契約)
##
## 設計文件: docs/architecture/adr-0001-tactical-query-atomicity-contract.md
## 任務: 落地 QueryResult 契約型別並遷移 move_targets_breakdown / preview_damage_breakdown
##
## 每一筆查詢結果都帶著「建構當下的 combat_state_version」,讓呼叫端(多半是 UI 層)
## 能夠判斷手上拿著的結果是否已經過期,以及一組同一畫面要合併顯示的結果彼此是否
## 來自同一個版本。
##
## 🔴 兩項刻意的設計決定,不要在未來的重構中「順手優化掉」:
## 1. 沒有無參數建構子 —— 這是刻意的。若允許無參數建構,呼叫端可能造出
##    version 與 _version_source 對不上的結果物件(例如先建物件、晚點才塞 source),
##    那樣 is_stale() 的判定就會失去意義。建構子強制要求呼叫端在建構的那一刻
##    就提供 source,version 必定是「建構當下」的真實快照。
## 2. assert_same_version() 只檢查「彼此版本相同」,不檢查 is_stale()。
##    ADR 的呈現層義務其實是兩條獨立義務:(a) 一組要合併顯示的結果彼此必須
##    同版本;(b) 整組結果相對於「現在」可能已經過期。一組結果可以彼此完全
##    一致(都來自版本 5),但現在已經是版本 7 了 —— 這種情況 assert_same_version()
##    會回傳 true,呼叫端仍必須另外呼叫 is_stale() 才能抓到。把這兩件事合併成
##    一個函式,會讓呼叫端誤以為過了 assert_same_version() 這一關,兩件事都保證了。
class_name QueryResult
extends RefCounted

## 建構當下的 _version_source.combat_state_version 快照。
var version: int

## 用來現在查詢「是否已過期」的來源 —— 不會被序列化或複製,僅供 is_stale() 使用。
var _version_source: BattleState

func _init(source: BattleState) -> void:
	_version_source = source
	version = source.combat_state_version

## 回傳 true 代表 _version_source 的版本號已經往前推進,這筆結果已經過期。
func is_stale() -> bool:
	return version != _version_source.combat_state_version

## 檢查一組要合併顯示的結果是否彼此來自同一個 combat_state_version。
## 不檢查是否過期(is_stale 是獨立的義務,見檔頭註解第 2 點)。
## size() < 2 視為恆成立(沒有「彼此」可比較)。
static func assert_same_version(results: Array[QueryResult]) -> bool:
	if results.size() < 2:
		return true
	var expected: int = results[0].version
	for r: QueryResult in results:
		if r.version != expected:
			push_error("QueryResult.assert_same_version: mixed versions in one merged frame (%d vs %d)" % [expected, r.version])
			return false
	return true
