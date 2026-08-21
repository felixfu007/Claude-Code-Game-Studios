# F1f — 嘗試以引擎內省取得全域工具函式清單。全域工具函式不是 Object 方法,
# ClassDB 未必登記;本檔只負責「測出可不可以」,測不到就明說未查證,不外推。
extends RefCounted

static func probe() -> String:
	print("      f1f: ClassDB.class_exists('@GlobalScope') = %s" % str(ClassDB.class_exists("@GlobalScope")))
	print("      f1f: ClassDB.class_exists('@GDScript')    = %s" % str(ClassDB.class_exists("@GDScript")))
	var ml: Array = ClassDB.class_get_method_list("@GlobalScope", true)
	print("      f1f: class_get_method_list('@GlobalScope').size() = %d" % ml.size())
	for m in ml:
		var n: String = str(m.get("name", ""))
		if n.contains("bytes_to_var") or n.contains("var_to_bytes"):
			print("      f1f:   HIT %s -> %s" % [n, str(m)])
	return "F1f-REACHED-END"
