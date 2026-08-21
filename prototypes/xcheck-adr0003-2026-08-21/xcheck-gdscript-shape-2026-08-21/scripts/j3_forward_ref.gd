extends RefCounted
# J3(隔離)—— 靜態函式的回傳型別是「宣告在它之後」的內部類別(前向參照)
static func make() -> LateResult:
	return LateResult.new()
class LateResult extends RefCounted:
	var v: int = 42
func probe() -> String:
	var x: LateResult = make()
	print("      J3: 前向參照 OK,v=%d" % x.v)
	return "J3-REACHED-END"
