class_name X9DWrapperMember extends RefCounted
var _records: Dictionary[AffinityTypes.Pair, AffinityRecordList]

static func probe() -> String:
	var inst := X9DWrapperMember.new()
	var d: Dictionary = inst._records
	d[AffinityTypes.Pair.C1_C2] = AffinityRecordList.new()
	return "uninitialized member typeof=%s size_after_write=%d is_typed_key=%s typed_value_builtin=%d" % [
		type_string(typeof(inst._records)), inst._records.size(),
		str(inst._records.is_typed_key()), inst._records.get_typed_value_builtin()]
