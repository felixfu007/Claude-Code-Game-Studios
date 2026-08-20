# A1-(d) 候選替代 D:內層 Array[AffinityRecord] 包進 AffinityRecordList(RefCounted)。
# 外層值型別是「類別」而非「容器」,理論上不觸發巢狀限制,且兩層型別都保住。
# 代價:多一層 .items 存取,以及一個額外的 class_name。
extends RefCounted

static func build() -> Dictionary:
	var d: Dictionary[AffinityTypes.Pair, AffinityRecordList] = {}
	var rec := AffinityRecord.new()
	rec.pair = AffinityTypes.Pair.C1_C2
	rec.m = 1.5
	rec.t = 1
	rec.c = 0
	rec.source = AffinityTypes.Source.COMBAT_CARD

	var list := AffinityRecordList.new()
	list.items.append(rec)
	d[AffinityTypes.Pair.C1_C2] = list
	return d
