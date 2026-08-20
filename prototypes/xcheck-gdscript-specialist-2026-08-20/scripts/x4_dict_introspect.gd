extends RefCounted
static func run() -> Dictionary:
	var d: Dictionary[AffinityTypes.Pair, int] = {}
	d[AffinityTypes.Pair.C1_C2] = 1
	var out := {}
	out["is_typed_key"] = str(d.is_typed_key())
	out["is_typed_value"] = str(d.is_typed_value())
	out["get_typed_key_builtin"] = str(d.get_typed_key_builtin())
	out["get_typed_value_builtin"] = str(d.get_typed_value_builtin())
	return out
