extends RefCounted
# J2(隔離)—— 內部類別「不寫 extends」的形式:class X:
class PlainResult:
	var buffer: PackedByteArray
	var rejection: int
func probe() -> String:
	var p := PlainResult.new()
	print("      J2: class X: (無 extends) -> get_class()=%s  is RefCounted=%s  is Object=%s" % [p.get_class(), str(p is RefCounted), str(p is Object)])
	return "J2-REACHED-END"
