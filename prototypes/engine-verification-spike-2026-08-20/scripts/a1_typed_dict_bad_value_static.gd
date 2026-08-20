# A1-c:靜態可見的錯誤「值」型別(int 當值,宣告要求 Array[AffinityRecord])。
extends RefCounted

static func run() -> void:
	var d: Dictionary[AffinityTypes.Pair, Array[AffinityRecord]] = {}
	d[AffinityTypes.Pair.C1_C2] = 12345
