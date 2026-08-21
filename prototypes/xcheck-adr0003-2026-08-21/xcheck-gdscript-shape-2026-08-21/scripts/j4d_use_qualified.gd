extends RefCounted
# J4d —— 讀取 J4b(限定寫法)是否真的可用
func probe() -> String:
	var r := JReadResultQualified.new()
	print("      J4d: 限定寫法可用 —— rejection=%d  typeof=%d" % [r.rejection, typeof(r.rejection)])
	print("      J4d: JOwner.ReadRejection.keys()=%s" % str(JOwner.ReadRejection.keys()))
	return "J4d-REACHED-END"
