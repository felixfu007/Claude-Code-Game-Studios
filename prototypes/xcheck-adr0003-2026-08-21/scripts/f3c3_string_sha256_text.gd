# F3c-3 —— String.sha256_text()。
extends RefCounted
static func probe() -> String:
	var h := "abc".sha256_text()
	print("      String('abc').sha256_text() = %s" % h)
	return "F3c3-REACHED-END"
