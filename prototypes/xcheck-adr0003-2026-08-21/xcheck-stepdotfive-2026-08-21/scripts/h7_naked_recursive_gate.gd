extends RefCounted
# H-7:照草案機制一之二「逐字」實作的遞迴走訪 —— 沒有深度上限、沒有已訪集合,
#      因為草案全文沒有提到任何一個。對循環引用 payload 會發生什麼?
# 本檔刻意排在最後、且獨立於 h6(h6 有深度上限)。
var steps := 0

func _gate_naked(v: Variant) -> bool:
	steps += 1
	var t := typeof(v)
	if t == TYPE_OBJECT or t == TYPE_CALLABLE or t == TYPE_SIGNAL or t == TYPE_RID:
		return false
	if t == TYPE_DICTIONARY:
		var dv: Dictionary = v
		for k in dv:
			if not _gate_naked(k):
				return false
			if not _gate_naked(dv[k]):
				return false
		return true
	if t == TYPE_ARRAY:
		for e in (v as Array):
			if not _gate_naked(e):
				return false
		return true
	return true

func probe() -> String:
	var d := {}
	d["a"] = 1
	d["self"] = d
	print("      H7: 即將對自我參照 Dict 呼叫無防護的遞迴閘門(草案逐字寫法)...")
	var ok := _gate_naked(d)
	print("      H7: 回傳 %s,走訪步數=%d  <-- 若這行印得出來,表示沒有無限迴圈" % [str(ok), steps])
	return "H7-REACHED-END"
