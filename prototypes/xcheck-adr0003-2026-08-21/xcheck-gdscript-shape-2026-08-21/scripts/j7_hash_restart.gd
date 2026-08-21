extends RefCounted
# J7 —— 補 J6 誠實留下的洞:J6-D1 的第二次 start() 發生在「還沒餵資料」時,
#   所以它不能回答「已累積資料後再 start() 會不會重置」。這才是「跨區塊重用同一個
#   HashingContext 而忘了 finish()」的真實形狀。
func probe() -> String:
	var abc: PackedByteArray = "abc".to_utf8_buffer()
	print("      J7: ERR_ALREADY_IN_USE=%d  ERR_UNCONFIGURED=%d  FAILED=%d" % [ERR_ALREADY_IN_USE, ERR_UNCONFIGURED, FAILED])
	var c := HashingContext.new()
	print("      J7a: start err=%d" % c.start(HashingContext.HASH_SHA256))
	print("      J7a: update(abc) err=%d" % c.update(abc))
	print("      J7a: 已餵資料後再 start() err=%d" % c.start(HashingContext.HASH_SHA256))
	print("      J7a: update(abc) 第二次 err=%d" % c.update(abc))
	var d: PackedByteArray = c.finish()
	print("      J7a: finish hex=%s" % d.hex_encode())
	print("        對照 SHA256(abc)    = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
	print("        對照 SHA256(abcabc) = %s" % ("abcabc".sha256_text()))
	print("      J7b: 空 buffer 是否真的可能 —— var_to_bytes({}) size=%d,var_to_bytes(null) size=%d" % [var_to_bytes({}).size(), var_to_bytes(null).size()])
	return "J7-REACHED-END"
