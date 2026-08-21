extends RefCounted
# PRE-5:規格要求「以『允許集合 has()』為判準」,且要求載入期完整性斷言
# `允許集合.size() + 拒絕集合.size() == TYPE_MAX`。
# 若 const Dictionary 以全域 enum 常數當鍵不成立,白名單就得改寫成別的形狀。
# 另測:驗證 E 要「故意從允許集合拿掉一個型別」—— const Dictionary 在 4.x 是唯讀,
# 必須確認能否做出可變副本。
const ALLOWED: Dictionary = {
	TYPE_NIL: true, TYPE_BOOL: true, TYPE_INT: true, TYPE_FLOAT: true,
	TYPE_STRING: true, TYPE_COLOR: true, TYPE_DICTIONARY: true, TYPE_ARRAY: true,
}
const REJECTED: Dictionary = {
	TYPE_RID: true, TYPE_OBJECT: true, TYPE_CALLABLE: true, TYPE_SIGNAL: true,
}

func probe() -> String:
	print("      ALLOWED.size()=%d REJECTED.size()=%d" % [ALLOWED.size(), REJECTED.size()])
	print("      ALLOWED.has(TYPE_COLOR)=%s ALLOWED.has(TYPE_OBJECT)=%s"
		% [str(ALLOWED.has(TYPE_COLOR)), str(ALLOWED.has(TYPE_OBJECT))])
	print("      ALLOWED.is_read_only()=%s" % str(ALLOWED.is_read_only()))
	var copy: Dictionary = {}
	for k in ALLOWED:
		copy[k] = true
	print("      hand-built copy size=%d is_read_only=%s" % [copy.size(), str(copy.is_read_only())])
	copy.erase(TYPE_COLOR)
	print("      after erase(TYPE_COLOR): size=%d has(TYPE_COLOR)=%s"
		% [copy.size(), str(copy.has(TYPE_COLOR))])
	return "PRE5-REACHED-END"
