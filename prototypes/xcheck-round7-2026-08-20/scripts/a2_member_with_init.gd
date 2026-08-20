class_name R7AMemberWithInit extends RefCounted
# A2 — R7E-1 Q2: same shape as A1 but WITH an explicit `= {}` initializer.
# ADR-0002's Verification Required #6/#5 established that the no-init vs
# with-init distinction matters for NESTED typed containers (Dictionary of
# Array) -- this is a DIFFERENT type combination (enum key + custom-class
# value, no nesting at the GDScript syntax level), so it is not safe to
# assume the same answer without a separate probe.

var _records: Dictionary[AffinityTypes.Pair, AffinityRecordList] = {}

func try_store_and_check(pair: AffinityTypes.Pair) -> String:
	print("      >> R7AMemberWithInit.try_store_and_check: entering")
	var list := AffinityRecordList.new()
	var rec := AffinityRecord.new()
	rec.pair = pair
	list.items.append(rec)
	_records[pair] = list
	var read_back: Variant = _records[pair]
	print("      >> R7AMemberWithInit.try_store_and_check: store/read done, about to return")
	if read_back == null:
		return "REACHED END read_back=NULL"
	return "REACHED END is_typed=%s is_AffinityRecordList=%s global_name=%s" % [
		str(read_back.items.is_typed()),
		str(read_back is AffinityRecordList),
		str(read_back.get_script().get_global_name()),
	]
