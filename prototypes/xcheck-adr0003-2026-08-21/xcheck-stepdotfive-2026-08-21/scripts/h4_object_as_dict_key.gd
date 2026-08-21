extends RefCounted
# H-4: Object / Signal / Callable 能不能當 Dictionary 的「鍵」,
#      以及 var_to_bytes() 對這種 Dictionary 的行為。
# 目的:核實草案「遞迴走訪 Dictionary 的鍵與值」這條規則的鍵側是否真的可達
#      (若鍵側結構上不可能出現這些型別,那半條規則就是死碼 —— 與 R7E-6 同形狀)。
func probe() -> String:
	var rc := RefCounted.new()
	var d1 := {}
	d1[rc] = 1
	d1["ok"] = 2
	print("      H4a: Dict 以 RefCounted 為鍵,size=%d  keys typeof=%s" % [
		d1.size(), str(d1.keys().map(func(k): return typeof(k)))])
	var b1: PackedByteArray = var_to_bytes(d1)
	print("      H4a: var_to_bytes(該 Dict) -> size=%d (零錯誤代表靜默成功)" % b1.size())
	var r1 = bytes_to_var(b1)
	print("      H4a: bytes_to_var -> typeof=%d value=%s" % [typeof(r1), str(r1)])
	if r1 is Dictionary:
		print("      H4a: 還原後 keys typeof=%s" % str((r1 as Dictionary).keys().map(func(k): return typeof(k))))

	var sig_owner := RefCounted.new()
	var d2 := {}
	d2["v"] = 1
	var b2: PackedByteArray = var_to_bytes(d2)
	print("      H4b: 對照 —— 乾淨 Dict size=%d" % b2.size())

	# Array 內含 Object
	var arr := [1, RefCounted.new(), "x"]
	var b3: PackedByteArray = var_to_bytes(arr)
	var r3 = bytes_to_var(b3)
	print("      H4c: Array 含 Object -> encode size=%d ; decode typeof=%d value=%s" % [
		b3.size(), typeof(r3), str(r3)])

	# 型別化 Array 往返後還是不是型別化的
	var ta: Array[int] = [1, 2, 3]
	var b4: PackedByteArray = var_to_bytes(ta)
	var r4 = bytes_to_var(b4)
	print("      H4d: Array[int] -> decode typeof=%d  is Array=%s  get_typed_builtin(src)=%d" % [
		typeof(r4), str(r4 is Array), ta.get_typed_builtin()])
	if r4 is Array:
		print("      H4d: 還原物 get_typed_builtin()=%d (0 = 非型別化)" % (r4 as Array).get_typed_builtin())
	return "H4-REACHED-END"
