extends RefCounted
# H-5: 自我參照(循環)Dictionary。
# 草案的機制一之二是「遞迴走訪」,但草案全文沒有任何深度上限或循環偵測。
# 先量引擎自己怎麼處理,再談我們的閘門會怎樣。
func probe() -> String:
	var d := {}
	d["a"] = 1
	d["self"] = d
	print("      H5a: 建構自我參照 Dict OK, size=%d" % d.size())
	var b: PackedByteArray = var_to_bytes(d)
	print("      H5a: var_to_bytes -> size=%d" % b.size())
	var r = bytes_to_var(b)
	print("      H5a: bytes_to_var -> typeof=%d" % typeof(r))
	if r is Dictionary:
		var rd: Dictionary = r
		print("      H5a: 還原 keys=%s" % str(rd.keys()))
		if rd.has("self"):
			print("      H5a: rd['self'] typeof=%d ; rd['self'] 與 rd 是否同一個: %s" % [
				typeof(rd["self"]), str(rd["self"] == rd)])
	return "H5-REACHED-END"
