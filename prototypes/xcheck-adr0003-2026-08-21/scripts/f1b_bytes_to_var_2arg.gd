# F1b — bytes_to_var() 以「2 個引數」呼叫(ADR-0003 全文採用的形狀)。
# 這正是 ADR-0003 機制一/二/三與 Key Interfaces 逐字寫下的 `bytes_to_var(buffer, false)`。
extends RefCounted

static func probe() -> String:
	var b: PackedByteArray = var_to_bytes(123)
	var r = bytes_to_var(b, false)
	print("      f1b: bytes_to_var(b, false) -> typeof=%d value=%s" % [typeof(r), str(r)])
	return "F1b-REACHED-END"
