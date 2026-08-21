extends RefCounted
# H-5:引擎自己(var_to_bytes / bytes_to_var)對循環引用容器的行為。
# 隔離在本檔:若引擎在此無限遞迴,只損失本測項。
func probe() -> String:
	# H-5a 自我參照 Dictionary
	var d := {}
	d["a"] = 1
	d["self"] = d
	print("      H5a: 建構自我參照 Dict 成功(GDScript 允許),size=%d" % d.size())
	var b: PackedByteArray = var_to_bytes(d)
	print("      H5a: var_to_bytes -> size=%d" % b.size())
	var r = bytes_to_var(b)
	print("      H5a: bytes_to_var -> typeof=%d" % typeof(r))
	if r is Dictionary:
		var rd: Dictionary = r
		print("      H5a: 還原 keys=%s" % str(rd.keys()))
		if rd.has("self"):
			print("      H5a: rd['self'] typeof=%d  rd['self']==rd ? %s" % [typeof(rd["self"]), str(rd["self"] == rd)])
			if rd["self"] is Dictionary:
				print("      H5a: rd['self'] keys=%s (若仍含 'self' 則循環在位元組流中被保留)" % str((rd["self"] as Dictionary).keys()))
	# H-5b 互相參照的兩個 Array
	var a1: Array = [1]
	var a2: Array = [2]
	a1.append(a2)
	a2.append(a1)
	print("      H5b: 建構互相參照的兩個 Array 成功")
	var b2: PackedByteArray = var_to_bytes(a1)
	print("      H5b: var_to_bytes -> size=%d" % b2.size())
	var r2 = bytes_to_var(b2)
	print("      H5b: bytes_to_var -> typeof=%d value=%s" % [typeof(r2), str(r2)])
	return "H5-REACHED-END"
