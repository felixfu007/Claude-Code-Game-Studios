# A1-c:靜態可見的錯誤值型別(String 當值,宣告要求 int)。
# 改寫理由同 a1_typed_dict_bad_key_static.gd。
extends RefCounted

static func run() -> void:
	var d: Dictionary[AffinityTypes.Pair, int] = {}
	d[AffinityTypes.Pair.C1_C2] = "not_an_int"
