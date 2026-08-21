extends RefCounted
# J1b —— 呼叫端:跨檔案以 OuterClass.InnerClass 標註型別、讀 enum 欄位。
# run2:原本第 14 行的 r2.rejection = 1.7 是 run1 整檔 parse error 的成因,已拆到 j1e。
func probe() -> String:
	print("      J1b-S1 呼叫前 sentinel")
	var r: JSaveFormat.SerializeResult = JSaveFormat.serialize_block({"a": 1})
	print("      J1b: typeof(r)=%d  get_class()=%s  is RefCounted=%s" % [typeof(r), r.get_class(), str(r is RefCounted)])
	print("      J1b: rejection=%d  == PayloadRejection.NONE -> %s" % [r.rejection, str(r.rejection == JSaveFormat.PayloadRejection.NONE)])
	print("      J1b: buffer.size()=%d  offending_path=[%s]" % [r.buffer.size(), r.offending_path])
	var r2: JSaveFormat.SerializeResult = JSaveFormat.serialize_block({"poison": 1})
	print("      J1b: 拒絕路徑 rejection=%d  path=[%s]  buffer.size()=%d" % [r2.rejection, r2.offending_path, r2.buffer.size()])
	print("      J1b-S2 呼叫後 sentinel")
	return "J1b-REACHED-END"
