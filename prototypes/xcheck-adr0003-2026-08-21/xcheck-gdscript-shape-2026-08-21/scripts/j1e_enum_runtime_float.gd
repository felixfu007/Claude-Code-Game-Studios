extends RefCounted
# J1e(隔離)—— enum 型別欄位被賦值「執行期才知道型別的 float」
#   run1 已測到:float **字面量**直接賦值是 Parse Error。
#   本檔問的是不同的問題:值來自無型別 Variant(即 ADR-0002 R7E-4 的形狀)時會怎樣。
var _untyped = 1.7
func probe() -> String:
	var r := JSaveFormat.SerializeResult.new()
	print("      J1e-S1 賦值前 sentinel(_untyped typeof=%d 值=%s)" % [typeof(_untyped), str(_untyped)])
	r.rejection = _untyped
	print("      J1e: 賦值後 r.rejection=%s  typeof=%d" % [str(r.rejection), typeof(r.rejection)])
	print("      J1e-S2 賦值後 sentinel")
	return "J1e-REACHED-END"
