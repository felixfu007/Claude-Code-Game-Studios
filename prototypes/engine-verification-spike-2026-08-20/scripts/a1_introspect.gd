# A1 附加內省 —— 刻意獨立成一檔。
# is_typed_key() / get_typed_key_builtin() 等方法是否存在於 4.7.1,本專案未查證。
# 若不存在,靜態型別的 Dictionary 上直接呼叫會是**編譯期**錯誤 —— 那會把整個 runner 一起弄爆。
# 隔離成一檔之後,「這一檔編譯失敗」本身就是一筆乾淨的結果,不影響其他任何檢查。
extends RefCounted

static func run(d: Dictionary) -> Dictionary:
	var out := {}
	out["is_typed_key"] = d.is_typed_key()
	out["is_typed_value"] = d.is_typed_value()
	out["get_typed_key_builtin"] = d.get_typed_key_builtin()
	out["get_typed_value_builtin"] = d.get_typed_value_builtin()
	return out
