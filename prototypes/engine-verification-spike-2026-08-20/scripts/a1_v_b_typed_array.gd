# A1-(b) 單獨的 Array[自訂類別] —— 確認型別化陣列本身可用(不是巢狀問題以外的問題)。
extends RefCounted

static func build() -> Array:
	var rec := AffinityRecord.new()
	rec.pair = AffinityTypes.Pair.C1_C2
	rec.m = 1.5
	rec.t = 1
	rec.c = 0
	rec.source = AffinityTypes.Source.COMBAT_CARD
	var arr: Array[AffinityRecord] = []
	arr.append(rec)
	return arr
