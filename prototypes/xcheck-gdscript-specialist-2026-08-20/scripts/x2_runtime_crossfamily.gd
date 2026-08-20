extends RefCounted

static func try_wrong_family_key() -> String:
	var d: Dictionary[AffinityTypes.Pair, int] = {}
	var sneaky: Variant = AffinityTypes.Character.CHARACTER_3
	d[sneaky] = 99
	return "NOT ABORTED size=%d keys=%s" % [d.size(), str(d.keys())]
