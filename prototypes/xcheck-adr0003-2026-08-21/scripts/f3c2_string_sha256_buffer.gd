# F3c-2 —— String.sha256_buffer()。
extends RefCounted
static func probe() -> String:
	var h := "abc".sha256_buffer()
	print("      String('abc').sha256_buffer() = %s (size=%d)" % [h.hex_encode(), h.size()])
	return "F3c2-REACHED-END"
