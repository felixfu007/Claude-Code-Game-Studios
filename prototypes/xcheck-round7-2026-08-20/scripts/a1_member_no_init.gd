class_name R7AMemberNoInit extends RefCounted
# A1 — R7E-1 Q1: enum-key + custom-class-value Dictionary as a CLASS MEMBER
# with NO initializer. Mirrors ADR-0002 mechanism two's exact declaration
# `var _records: Dictionary[AffinityTypes.Pair, AffinityRecordList]` (no `= {}`).
# Question: does this even compile, and if it does, does storing+reading back
# through it preserve the inner Array[AffinityRecord] type (is_typed() == true)?

var _records: Dictionary[AffinityTypes.Pair, AffinityRecordList]

func try_store_and_check(pair: AffinityTypes.Pair) -> String:
	print("      >> R7AMemberNoInit.try_store_and_check: entering")
	var list := AffinityRecordList.new()
	var rec := AffinityRecord.new()
	rec.pair = pair
	list.items.append(rec)
	_records[pair] = list
	var read_back: Variant = _records[pair]
	print("      >> R7AMemberNoInit.try_store_and_check: store/read done, about to return")
	if read_back == null:
		return "REACHED END read_back=NULL"
	return "REACHED END is_typed=%s is_AffinityRecordList=%s global_name=%s" % [
		str(read_back.items.is_typed()),
		str(read_back is AffinityRecordList),
		str(read_back.get_script().get_global_name()),
	]
