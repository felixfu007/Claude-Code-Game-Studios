extends RefCounted
static func run() -> Dictionary:
	var a: Array[AffinityRecord] = []
	var out := {}
	out["is_typed"] = str(a.is_typed())
	out["get_typed_builtin"] = str(a.get_typed_builtin())
	out["get_typed_class_name"] = str(a.get_typed_class_name())
	out["typed_script_is_null"] = str(a.get_typed_script() == null)
	return out
