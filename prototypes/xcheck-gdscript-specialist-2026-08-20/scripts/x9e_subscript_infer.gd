extends RefCounted
static func run() -> Dictionary:
	var d: Dictionary[AffinityTypes.Pair, Array] = {}
	d[AffinityTypes.Pair.C1_C2] = []
	var got: Array = d[AffinityTypes.Pair.C1_C2]
	return {"subscript_assigned_literal_is_typed": str(got.is_typed())}
