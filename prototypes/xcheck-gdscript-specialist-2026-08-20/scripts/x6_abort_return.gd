extends RefCounted
static func aborts_midway() -> Dictionary:
	var d: Dictionary[AffinityTypes.Pair, int] = {}
	var k: Variant = "bad"
	d[k] = 1
	return {"reached_return": true, "size": d.size()}
