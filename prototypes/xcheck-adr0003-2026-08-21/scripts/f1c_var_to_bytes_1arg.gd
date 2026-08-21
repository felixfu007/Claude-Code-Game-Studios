# F1c — var_to_bytes() 以 1 個引數呼叫(ADR-0003 採用的形狀)。
extends RefCounted

static func probe() -> String:
	var b: PackedByteArray = var_to_bytes({"k": 1})
	print("      f1c: var_to_bytes({'k':1}) -> typeof=%d size=%d" % [typeof(b), b.size()])
	return "F1c-REACHED-END"
