class_name SupportConversationBufferedWritePort
extends SupportConversationWritePort
## 支援對話寫入介面的「暫存」轉接器(campfire story-013)。
##
## 管理者 2026-11-23 裁決:對話造成的好感度變化改在「對話播完」才寫入累積記錄。
## 勝利當下仍要跑 [method SupportConversationRules.trigger](挑段與存活判斷都在那裡),
## 但寫入量不能當場進累積記錄 —— 本轉接器把 trigger 要寫的 (pair, m, source) 先收起來,
## 由呼叫端帶到對話畫面,播完時再用 [SupportConversationLedgerWritePort] 真正寫入。
##
## 純資料、零節點;本檔只「接收」寫入,不呼叫任何下游寫入埠。

## 一筆待寫入的記錄。
class Entry extends RefCounted:
	var pair: AffinityTypes.Pair
	var m: float
	var source: AffinityTypes.Source

	func _init(p: AffinityTypes.Pair, amount: float, src: AffinityTypes.Source) -> void:
		pair = p
		m = amount
		source = src


var _entries: Array[Entry] = []


func append_record(pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source) -> void:
	_entries.append(Entry.new(pair, m, source))


## 取走目前收到的全部記錄並清空(依收到順序)。
func drain() -> Array[Entry]:
	var out: Array[Entry] = _entries
	_entries = []
	return out
