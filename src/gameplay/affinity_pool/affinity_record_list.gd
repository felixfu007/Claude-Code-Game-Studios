# AffinityRecordList —— 繞過 GDScript 不支援巢狀型別容器限制的包裝層。
#
# 治理 ADR:docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md
#   - 機制二(2026-08-20 BLOCKING 修訂):ADR-0002 初版把 per-pair 儲存寫成
#     `Dictionary[Pair, Array[AffinityRecord]]`,在 Godot 4.7.1 實機測出無法編譯
#     (`Parse Error: Nested typed collections are not supported`,class member/
#     函式參數/回傳型別三種語法形狀皆同)。本類別是該替代方案的落地——
#     `AffinityDataPool` 改存 `Dictionary[Pair, AffinityRecordList]`(單層)。
#   - Validation Criteria 第 11 項(本 story 的驗收依據,GDD AC 歸屬為 0)
# Story:production/epics/affinity-data-pool/story-002-affinity-record.md(S-002)
#
# 🔴 誠實聲明,不可省略(ADR-0002 原文):GDScript 沒有真正的私有成員,`_items`
# 的底線前綴是命名慣例、不是語言層強制。本類別不宣稱這是結構保證——相對公開
# `items` 的收益是:唯一被許可的寫入路徑收斂為 append(record: AffinityRecord)
# 這個型別化簽章,任何對 `_items` 的整體賦值都是明顯的慣例違反。
#
# 已登記禁令:wholesale_reassignment_of_affinity_record_list_items ——
# 本類別不提供任何回傳 `_items` 本身的方法。
class_name AffinityRecordList
extends RefCounted

# 內層元素型別由本宣告式初始化 + append() 的型別化參數簽章共同保證,不經任何
# subscript 賦值路徑寫入 —— 已實測「未型別化字面量經 subscript 賦值存入型別化
# Array 的值槽後讀回,is_typed() 為 false」(ADR-0002 VR#5),故本類別的唯一
# 寫入入口是 append(),不提供任何以索引賦值取代 append() 的路徑。
var _items: Array[AffinityRecord] = []


## 附加一筆記錄。這是本類別唯一被許可的寫入路徑。
func append(record: AffinityRecord) -> void:
	_items.append(record)


## 回傳目前記錄筆數。
func size() -> int:
	return _items.size()


## 依索引取得一筆記錄。
##
## 越界(含負索引、含等於 [method size] 的索引)一律乾淨回傳 [code]null[/code]、
## 不中止呼叫函式。[b]不得[/b]沿用引擎對型別化 [Array] 的 `[]` subscript 越界時
## 中止呼叫函式的原生行為,也不得沿用「非空陣列 `-1` 取最後一筆、空陣列則中止」
## 這種行為隨陣列當下狀態而變的語意——這種語意不能暴露給呼叫端
## (ADR-0002 機制二第 3 點,VR#11)。
##
## 呼叫端義務(已登記進 docs/architecture/control-manifest.md):所有呼叫端
## 必須檢查回傳值是否為 [code]null[/code],不得假設索引一定落在合法範圍。
func get_at(index: int) -> AffinityRecord:
	if index < 0 or index >= _items.size():
		return null
	return _items[index]
