# F1d — var_to_bytes() 以 2 個引數呼叫。用來對稱地確認寫入側有沒有第二參數。
extends RefCounted

static func probe() -> String:
	var b: PackedByteArray = var_to_bytes({"k": 1}, false)
	print("      f1d: var_to_bytes({'k':1}, false) -> size=%d" % b.size())
	return "F1d-REACHED-END"
