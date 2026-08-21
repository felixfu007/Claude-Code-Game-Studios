extends RefCounted
# H-2: 4.7.1 完整 Variant 型別列舉。
# 目的:核實 ADR-0003 修訂草案的白名單/黑名單兩張表是否漏了任何型別。
# 使用全域 type_string() —— arity 未經本專案查證,故隔離在本檔。
func probe() -> String:
	var i := 0
	while i < 64:
		var s: String = type_string(i)
		if s == "":
			print("      H2: type %d -> (empty string) — 視為列舉尾端,停止" % i)
			break
		print("      H2: type %2d -> %s" % [i, s])
		i += 1
	print("      H2: 掃描停在 i=%d" % i)
	return "H2-REACHED-END"
