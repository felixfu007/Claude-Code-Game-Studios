extends RefCounted
# X-3(隔離):頂層雜湊的輸入是 manifest 的「tuple 清單」。
# 若實作者改用 manifest 的 Dictionary 條目直接餵 var_to_bytes,
# 位元組會不會隨鍵的插入順序而變?(= 雜湊是否依賴容器迭代順序)
func probe() -> String:
	var a: Dictionary = {}
	a["source_id"] = "affinity_data_pool"
	a["format_version"] = 3
	var b: Dictionary = {}
	b["format_version"] = 3
	b["source_id"] = "affinity_data_pool"
	print("      a == b (Variant equality) : %s" % str(a == b))
	var ba := var_to_bytes(a)
	var bb := var_to_bytes(b)
	print("      var_to_bytes(a).size=%d  hex=%s" % [ba.size(), ba.hex_encode()])
	print("      var_to_bytes(b).size=%d  hex=%s" % [bb.size(), bb.hex_encode()])
	print("      BYTES IDENTICAL = %s   <-- if false, hashing a Dictionary is order-dependent"
		% str(ba == bb))
	# 對照:明確順序的 Array tuple
	var ta: Array = ["affinity_data_pool", 3]
	var tb: Array = ["affinity_data_pool", 3]
	print("      array-tuple bytes identical = %s" % str(var_to_bytes(ta) == var_to_bytes(tb)))
	return "X3-REACHED-END"
