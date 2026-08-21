extends RefCounted
# H-6:照草案機制一之二實作的遞迴型別閘門,在 GDScript 下的實際成本 + 擋不擋得下毒藥。
# 探針 F 的 F5 量的是 var_to_bytes/bytes_to_var(引擎 C++)的成本;
# 閘門是本專案自己的 GDScript 迴圈,兩者不可互相推論 —— 這正是本測項存在的理由。
# 本檔的 _gate() 帶深度上限(64),故對循環引用不會爆;無上限版本見 h7。

func _gate(v: Variant, depth: int) -> bool:
	if depth > 64:
		return false
	var t := typeof(v)
	if t == TYPE_OBJECT or t == TYPE_CALLABLE or t == TYPE_SIGNAL or t == TYPE_RID:
		return false
	if t == TYPE_DICTIONARY:
		var dv: Dictionary = v
		for k in dv:
			if not _gate(k, depth + 1):
				return false
			if not _gate(dv[k], depth + 1):
				return false
		return true
	if t == TYPE_ARRAY:
		for e in (v as Array):
			if not _gate(e, depth + 1):
				return false
		return true
	return true

func _make(n: int) -> Dictionary:
	var recs := []
	recs.resize(n)
	for i in range(n):
		recs[i] = {"pair": "A_B", "source_i": "DIALOGUE", "m": 1.25, "t": i}
	return {"records": recs, "campaign_tick_marks": [], "death_marks": {}}

func probe() -> String:
	for n in [500, 100000, 500000]:
		var p := _make(n)
		var t0 := Time.get_ticks_usec()
		var ok := _gate(p, 0)
		var t1 := Time.get_ticks_usec()
		var buf: PackedByteArray = var_to_bytes(p)
		var t2 := Time.get_ticks_usec()
		var back = bytes_to_var(buf)
		var t3 := Time.get_ticks_usec()
		var ok2 := _gate(back, 0)
		var t4 := Time.get_ticks_usec()
		print("      H6: n=%7d encoded=%9d B | WRITE-gate=%8.1f ms | var_to_bytes=%7.1f ms | bytes_to_var=%7.1f ms | READ-gate=%8.1f ms | ok=%s/%s" % [
			n, buf.size(), (t1-t0)/1000.0, (t2-t1)/1000.0, (t3-t2)/1000.0, (t4-t3)/1000.0, str(ok), str(ok2)])
	print("      H6-poison: 值為 Object      -> gate=%s" % str(_gate({"records": [{"m": 1.0, "bad": RefCounted.new()}]}, 0)))
	var pk := {}
	pk[RefCounted.new()] = 1
	print("      H6-poison: 鍵為 Object      -> gate=%s" % str(_gate(pk, 0)))
	var owner := RefCounted.new()
	print("      H6-poison: Signal          -> gate=%s" % str(_gate({"s": owner.script_changed}, 0)))
	print("      H6-poison: Callable        -> gate=%s" % str(_gate({"c": owner.get_class}, 0)))
	print("      H6-allow?: Color(type 20)  -> gate=%s   <-- 草案「數學型別」一詞是否涵蓋 Color?" % str(_gate({"c": Color.RED}, 0)))
	print("      H6-allow?: Transform3D(18) -> gate=%s" % str(_gate({"x": Transform3D.IDENTITY}, 0)))
	print("      H6-allow?: Projection(19)  -> gate=%s" % str(_gate({"x": Projection()}, 0)))
	return "H6-REACHED-END"
