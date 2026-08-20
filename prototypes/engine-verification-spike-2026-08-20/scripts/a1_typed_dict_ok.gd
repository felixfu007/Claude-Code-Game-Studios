# A1 對照組:ADR-0002 機制四的真實宣告,正確用法。
# 這一檔若編譯失敗,代表 ADR-0002 的核心資料結構在 4.7.1 根本寫不出來 —— 那是 BLOCKING。
#
# 刻意只做「宣告 + 正確插入 + 回傳容器」。所有內省(get_typed_*)一律交給 runner 用
# has_method() 守衛後再呼叫 —— 那些方法本身是否存在於 4.7.1 也未經本專案查證,
# 不可以讓一個未查證的內省 API 把這個對照組一起拖下水。
extends RefCounted

static func build() -> Dictionary:
	var d: Dictionary[AffinityTypes.Pair, Array[AffinityRecord]] = {}
	var rec := AffinityRecord.new()
	rec.pair = AffinityTypes.Pair.C1_C2
	rec.m = 1.5
	rec.t = 1
	rec.c = 0
	rec.source = AffinityTypes.Source.COMBAT_CARD

	var arr: Array[AffinityRecord] = []
	arr.append(rec)
	d[AffinityTypes.Pair.C1_C2] = arr
	return d
