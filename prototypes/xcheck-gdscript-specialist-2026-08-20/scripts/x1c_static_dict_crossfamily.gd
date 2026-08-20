extends RefCounted
static func run() -> int:
	var a: Dictionary[AffinityTypes.Character, int] = {}
	var b: Dictionary[AffinityTypes.Pair, int] = a
	return b.size()
