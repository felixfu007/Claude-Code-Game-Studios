extends RefCounted
# H-1: FileAccess.get_var / store_var 的真實簽章。
# 目的:核實 ADR-0003 修訂草案「save-system.md:706 的
#       FileAccess.get_var(allow_objects=false) 是正確的」這個判斷。
# FileAccess 是 ClassDB 登記類別(對比 @GlobalScope 全域函式不是),故內省可用。
func probe() -> String:
	for mname in ["get_var", "store_var", "get_buffer", "store_buffer"]:
		if not ClassDB.class_has_method("FileAccess", mname):
			print("      H1: FileAccess.%s -> class_has_method = FALSE" % mname)
			continue
		var ml: Array = ClassDB.class_get_method_list("FileAccess", false)
		for m in ml:
			if m.get("name") != mname:
				continue
			var argdesc := []
			for a in m.get("args", []):
				argdesc.append("%s:type%d" % [a.get("name"), a.get("type")])
			var dflt = m.get("default_args", [])
			print("      H1: FileAccess.%s(%s)  default_args=%s  return=type%d" % [
				mname, ", ".join(argdesc), str(dflt),
				(m.get("return", {}) as Dictionary).get("type", -1)])
	return "H1-REACHED-END"
