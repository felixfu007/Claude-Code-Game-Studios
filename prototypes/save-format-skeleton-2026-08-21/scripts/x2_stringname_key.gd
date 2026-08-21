extends RefCounted
# X-2(隔離):型別閘門的鍵位置允許 STRING / STRING_NAME / INT。
# 若某系統匯出 StringName 鍵,而讀取端以 String 查詢,查得到嗎?
# 這決定「鍵位置允許兩種字串型別」是否是一個安全的規則。
func probe() -> String:
	var d: Dictionary = {}
	d[&"alpha"] = 1
	d["beta"] = 2
	var keys := d.keys()
	print("      built dict keys typeof: %d , %d  (STRING=%d STRING_NAME=%d)"
		% [typeof(keys[0]), typeof(keys[1]), TYPE_STRING, TYPE_STRING_NAME])
	print("      pre-roundtrip: has(\"alpha\")=%s has(&\"alpha\")=%s has(\"beta\")=%s has(&\"beta\")=%s"
		% [str(d.has("alpha")), str(d.has(&"alpha")), str(d.has("beta")), str(d.has(&"beta"))])
	var back = bytes_to_var(var_to_bytes(d))
	var bd: Dictionary = back
	var bkeys := bd.keys()
	print("      post-roundtrip keys typeof: %d , %d" % [typeof(bkeys[0]), typeof(bkeys[1])])
	print("      post-roundtrip: has(\"alpha\")=%s has(&\"alpha\")=%s has(\"beta\")=%s has(&\"beta\")=%s"
		% [str(bd.has("alpha")), str(bd.has(&"alpha")), str(bd.has("beta")), str(bd.has(&"beta"))])
	print("      equal to source dict = %s" % str(bd == d))
	return "X2-REACHED-END"
