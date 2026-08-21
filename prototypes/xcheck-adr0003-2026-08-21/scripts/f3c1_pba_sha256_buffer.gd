# F3c-1 —— PackedByteArray 是否有 sha256_buffer()。不存在則為 parse error。
extends RefCounted
static func probe() -> String:
	var pba := "abc".to_utf8_buffer()
	var h := pba.sha256_buffer()
	print("      PackedByteArray('abc').sha256_buffer() = %s" % h.hex_encode())
	return "F3c1-REACHED-END"
