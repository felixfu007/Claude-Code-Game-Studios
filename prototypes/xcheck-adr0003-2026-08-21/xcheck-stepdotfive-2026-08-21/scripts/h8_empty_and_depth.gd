extends RefCounted
# H-8:兩個定案用的數字。
# (1) var_to_bytes() 對「合法但空」的容器回傳幾個 byte?
#     —— 草案第 121-122 行主張「空 PackedByteArray 與『合法但空』不可分」,
#        這是它改變 serialize_block() 公開回傳型別的唯一理由。若空容器編出非零長度,
#        那個理由不成立(結論可能仍對,但理由必須換)。
# (2) 引擎的「Potential infinite recursion」門檻是深度多少?
#     —— 這決定閘門的深度上限該設多少才不會誤拒合法的深層 payload。
func probe() -> String:
	print("      H8a: var_to_bytes({})            -> size=%d" % var_to_bytes({}).size())
	print("      H8a: var_to_bytes([])            -> size=%d" % var_to_bytes([]).size())
	print("      H8a: var_to_bytes(null)          -> size=%d" % var_to_bytes(null).size())
	print("      H8a: var_to_bytes(PackedByteArray()) -> size=%d" % var_to_bytes(PackedByteArray()).size())
	print("      H8a: var_to_bytes({'v':1})       -> size=%d" % var_to_bytes({"v": 1}).size())
	print("      H8a: 解碼空 Dictionary 是否還原為 Dictionary: typeof=%d" % typeof(bytes_to_var(var_to_bytes({}))))
	# (2) 合法的深層(非循環)巢狀鏈,找出引擎 bail 的深度
	for depth in [16, 32, 64, 96, 128, 256]:
		var inner: Variant = {"leaf": 1}
		for i in range(depth):
			inner = {"n": inner}
		var b: PackedByteArray = var_to_bytes(inner)
		var back = bytes_to_var(b)
		print("      H8b: 合法巢狀深度 %4d -> encode size=%6d  decode typeof=%d %s" % [
			depth, b.size(), typeof(back),
			("<-- encode 回傳 0,引擎在此深度已 bail" if b.size() == 0 else "")])
	return "H8-REACHED-END"
