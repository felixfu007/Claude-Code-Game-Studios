extends RefCounted
# J1d(隔離)—— enum 型別欄位被賦值「越界的 int 字面量」
func probe() -> String:
	var r := JSaveFormat.SerializeResult.new()
	r.rejection = 7
	print("      J1d: r.rejection = 7(int 字面量,越界)-> %d  typeof=%d" % [r.rejection, typeof(r.rejection)])
	print("      J1d: == NONE? %s   == FORBIDDEN_TYPE? %s" % [str(r.rejection == JSaveFormat.PayloadRejection.NONE), str(r.rejection == JSaveFormat.PayloadRejection.FORBIDDEN_TYPE)])
	return "J1d-REACHED-END"
