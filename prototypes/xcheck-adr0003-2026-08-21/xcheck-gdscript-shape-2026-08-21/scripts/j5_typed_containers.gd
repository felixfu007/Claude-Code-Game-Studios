extends RefCounted
# J5 —— C1/B3:is Dictionary 對型別化 Dictionary、typed 容器往返、非 Dictionary 的合法解碼值
# run2:原第 10 行 `ta is Dictionary`(ta 靜態型別為 Array[int])是 run1 整檔 parse error 的成因,
#       已改為經無型別 Variant 中介 —— 這正是 deserialize_block() 回傳值的實際形狀。
func probe() -> String:
	var td: Dictionary[String, int] = {"a": 1, "b": 2}
	print("      J5a: Dictionary[String,int] -> typeof=%d  is Dictionary=%s" % [typeof(td), str(td is Dictionary)])
	var b: PackedByteArray = var_to_bytes(td)
	var back = bytes_to_var(b)
	print("      J5a: 往返後 typeof=%d  is Dictionary=%s  size=%d" % [typeof(back), str(back is Dictionary), (back as Dictionary).size()])
	var ta: Array[int] = [1, 2, 3]
	var ta_v = ta
	print("      J5b: Array[int] 經 Variant -> typeof=%d  is Array=%s  is Dictionary=%s" % [typeof(ta_v), str(ta_v is Array), str(ta_v is Dictionary)])
	print("      J5c: 合法但非 Dictionary 的解碼值 —— is Dictionary 各自為:")
	for v in [42, 3.14, "str", [1,2], PackedByteArray([1,2]), true, null]:
		var bb: PackedByteArray = var_to_bytes(v)
		var rr = bytes_to_var(bb)
		print("        輸入 typeof=%2d -> 解碼 typeof=%2d  is Dictionary=%s  == null -> %s" % [typeof(v), typeof(rr), str(rr is Dictionary), str(rr == null)])
	print("      J5d: 空 Dictionary 是否通過 is Dictionary:%s" % str(bytes_to_var(var_to_bytes({})) is Dictionary))
	var typed_back = bytes_to_var(var_to_bytes(td))
	print("      J5e: 型別化 Dictionary 往返後 get_typed_key_builtin=%d get_typed_value_builtin=%d (0=非型別化)" % [(typed_back as Dictionary).get_typed_key_builtin(), (typed_back as Dictionary).get_typed_value_builtin()])
	return "J5-REACHED-END"
