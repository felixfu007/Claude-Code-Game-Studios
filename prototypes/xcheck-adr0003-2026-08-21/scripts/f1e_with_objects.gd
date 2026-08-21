# F1e — `_with_objects` 變體是否存在。若存在,即為「Godot 4 把 allow_objects 旗標
# 拆成兩個獨立函式」的結構性證據(而非 Godot 3 的布林參數)。
extends RefCounted

static func probe_encode() -> String:
	var b: PackedByteArray = var_to_bytes_with_objects(RefCounted.new())
	print("      f1e: var_to_bytes_with_objects(RefCounted.new()) -> size=%d" % b.size())
	print("      f1e: hex(前 32 byte) = %s" % b.slice(0, 32).hex_encode())
	return "F1e-encode-REACHED-END"

static func probe_decode() -> String:
	var b: PackedByteArray = var_to_bytes_with_objects(RefCounted.new())
	var r = bytes_to_var_with_objects(b)
	print("      f1e: bytes_to_var_with_objects(b) -> typeof=%d is_Object=%s" % [typeof(r), str(r is Object)])
	return "F1e-decode-REACHED-END"
