# A1-(c) 候選替代 C:外層型別化、內層裸 Array。
# 代價:內層元素型別完全放棄,append 任何東西都不會被擋。
extends RefCounted

static func build() -> Dictionary:
	var d: Dictionary[AffinityTypes.Pair, Array] = {}
	var rec := AffinityRecord.new()
	rec.pair = AffinityTypes.Pair.C1_C2
	d[AffinityTypes.Pair.C1_C2] = [rec]
	return d
