# F1a — bytes_to_var() 以「1 個引數」呼叫,是否編譯。
# 若本檔編譯成功而 f1b(2 引數)失敗 → 4.7.1 的 bytes_to_var 沒有 allow_objects 參數,
# 而 ADR-0003 全文所寫的 `bytes_to_var(buffer, false)` 是 Godot 3 的簽章。
extends RefCounted

static func probe() -> String:
	var b: PackedByteArray = var_to_bytes(123)
	var r = bytes_to_var(b)
	print("      f1a: bytes_to_var(b) -> typeof=%d value=%s" % [typeof(r), str(r)])
	return "F1a-REACHED-END"
