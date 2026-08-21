extends RefCounted
# X-1(隔離):假資料來源的規格寫 `campaign_tick_marks: Array[int]`。
# 型別化容器經 var_to_bytes/bytes_to_var 往返後還是型別化的嗎?
# 若不是,import_state() 就不能把還原值直接指派給 Array[int] 欄位。
# 這會直接影響 ADR-0002 的容器型別決策,故在寫骨架之前先量。

func probe_is_typed() -> String:
	var src: Array[int] = [3, 5, 8]
	print("      src.is_typed()=%s get_typed_builtin()=%d" % [str(src.is_typed()), src.get_typed_builtin()])
	var b := var_to_bytes(src)
	var back = bytes_to_var(b)
	print("      back typeof=%d (TYPE_ARRAY=%d) size=%d" % [typeof(back), TYPE_ARRAY, (back as Array).size()])
	print("      back.is_typed()=%s get_typed_builtin()=%d"
		% [str((back as Array).is_typed()), (back as Array).get_typed_builtin()])
	print("      back == src : %s" % str(back == src))
	return "X1-ISTYPED-REACHED-END"

# 這一步可能中止 —— 單獨一個函式,呼叫端收到 "" 即為中止的證據。
func probe_assign_untyped_into_typed() -> String:
	var src: Array[int] = [3, 5, 8]
	var back = bytes_to_var(var_to_bytes(src))
	print("      about to assign the round-tripped value into an Array[int] variable...")
	var dst: Array[int] = back
	print("      assignment SURVIVED. dst.size()=%d is_typed=%s" % [dst.size(), str(dst.is_typed())])
	return "X1-ASSIGN-REACHED-END"

func probe_assign_via_helper() -> String:
	var src: Array[int] = [3, 5, 8]
	var back = bytes_to_var(var_to_bytes(src))
	var dst: Array[int] = []
	dst.assign(back)
	print("      Array.assign() path: dst.size()=%d is_typed=%s content=%s"
		% [dst.size(), str(dst.is_typed()), str(dst)])
	return "X1-ASSIGNHELPER-REACHED-END"
