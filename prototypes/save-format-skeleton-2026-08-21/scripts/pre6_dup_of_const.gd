extends RefCounted
# PRE-6(隔離):const Dictionary 的 .duplicate() 是否回傳可變副本。
# 這是 PRE-5 手工複製迴圈的替代方案,arity/行為未查證,故獨居一檔。
const ALLOWED: Dictionary = { TYPE_NIL: true, TYPE_COLOR: true }

func probe() -> String:
	var d: Dictionary = ALLOWED.duplicate()
	print("      duplicate() size=%d is_read_only=%s" % [d.size(), str(d.is_read_only())])
	d.erase(TYPE_COLOR)
	print("      after erase: size=%d" % d.size())
	return "PRE6-REACHED-END"
