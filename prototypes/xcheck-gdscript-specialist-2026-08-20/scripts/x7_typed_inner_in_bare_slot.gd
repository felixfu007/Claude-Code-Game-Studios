extends RefCounted
static func run() -> Dictionary:
	var d: Dictionary[AffinityTypes.Pair, Array] = {}
	var inner: Array[AffinityRecord] = []
	inner.append(AffinityRecord.new())
	d[AffinityTypes.Pair.C1_C2] = inner
	var got: Array = d[AffinityTypes.Pair.C1_C2]
	return {
		"stored_is_typed": str(got.is_typed()),
		"stored_typed_class": str(got.get_typed_class_name()),
		"literal_untyped_is_typed": str(([AffinityRecord.new()] as Array).is_typed()),
	}
