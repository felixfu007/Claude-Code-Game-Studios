extends RefCounted
# 驗證 C:毒藥向量 x 兩側。
#   寫入側 -> 回哪一個拒絕碼、offending_path 指到哪
#   讀取側 -> 繞過寫入側直接構造毒位元組,對稱閘門擋不擋

var _target: SkelPoisonTarget = SkelPoisonTarget.new()

func _rej_name(r: int) -> String:
	if r == SaveFormat.PayloadRejection.NONE:
		return "NONE"
	if r == SaveFormat.PayloadRejection.FORBIDDEN_TYPE:
		return "FORBIDDEN_TYPE"
	return "DEPTH_EXCEEDED"

func _write_side(label: String, payload: Dictionary) -> void:
	var res = SaveFormat.serialize_block(payload)
	print("      [寫入側] %-28s rejection=%-15s buffer=%d bytes"
		% [label, _rej_name(res.rejection), res.buffer.size()])
	print("               offending_path = %s" % _trunc(res.offending_path))

func _read_side(label: String, poison_bytes: PackedByteArray) -> void:
	var res = SaveFormat.deserialize_block(poison_bytes)
	print("      [讀取側] %-28s bytes=%-6d rejection=%s"
		% [label, poison_bytes.size(), ("NONE" if res.ok() else "DATA_CORRUPTED")])
	print("               detail = %s" % res.detail)
	print("               offending_path = %s" % _trunc(res.offending_path))
	if res.ok():
		print("               !!! 通過了 —— payload keys = %s" % str(res.payload.keys()))

func _trunc(s: String) -> String:
	if s.length() <= 160:
		return s
	return s.substr(0, 80) + " ...[省略 %d 字元]... " % (s.length() - 160) + s.substr(s.length() - 80)

func _nested(depth: int) -> Dictionary:
	var root: Dictionary = {}
	var cur: Dictionary = root
	for i in depth:
		var nxt: Dictionary = {}
		cur["n"] = nxt
		cur = nxt
	cur["leaf"] = 1
	return root

# ---------------------------------------------------------------- 寫入側

func t_c_write_side() -> String:
	_write_side("對照組(乾淨 payload)", {"alpha": 1, "beta": [1, 2.5, "x"]})
	_write_side("值是 Object", {"alpha": 1, "poison": RefCounted.new()})
	_write_side("值是 Resource", {"poison": Resource.new()})
	var kd: Dictionary = {}
	kd[RefCounted.new()] = 1
	_write_side("鍵是 Object", kd)
	var kd2: Dictionary = {}
	kd2[Vector2i(1, 2)] = 1
	_write_side("鍵是 Vector2i(非容器但非白名單鍵)", kd2)
	var kd3: Dictionary = {}
	kd3[[1, 2]] = 1
	_write_side("鍵是 Array(容器當鍵)", kd3)
	_write_side("值是 Signal", {"s": _target.pinged})
	_write_side("值是 RID", {"r": RID()})
	_write_side("值是 Callable", {"c": _target.noop})
	_write_side("Object 藏在第 3 層", {"a": {"b": [1, RefCounted.new()]}})
	return "C-WRITE-REACHED-END"

func t_c_write_side_depth() -> String:
	print("      MAX_PAYLOAD_DEPTH = %d" % SaveFormat.MAX_PAYLOAD_DEPTH)
	for d in [10, 62, 63, 64, 65, 100]:
		var res = SaveFormat.serialize_block(_nested(d))
		print("      巢狀深度 %-4d -> rejection=%-15s buffer=%d bytes"
			% [d, _rej_name(res.rejection), res.buffer.size()])
	return "C-DEPTH-REACHED-END"

func t_c_write_side_circular() -> String:
	# 規格有兩條機制都聲稱能處理循環引用:型別閘門的深度上限、以及 size>0 斷言。
	# 而規格鎖定的順序是「先閘門、再 var_to_bytes」-> 後者永遠看不到循環引用。
	var a: Dictionary = {}
	a["self"] = a
	var res = SaveFormat.serialize_block(a)
	print("      Dictionary 自我參照 -> rejection=%s" % _rej_name(res.rejection))
	print("        offending_path = %s" % _trunc(res.offending_path))
	print("        (若是 DEPTH_EXCEEDED 且 path 不含 var_to_bytes 字樣,")
	print("         代表 size>0 那條斷言在這個順序下不可達)")
	var arr: Array = []
	arr.append(arr)
	var res2 = SaveFormat.serialize_block({"cycle": arr})
	print("      Array 自我參照     -> rejection=%s" % _rej_name(res2.rejection))
	print("        offending_path = %s" % _trunc(res2.offending_path))
	# 對照:直接餵給 var_to_bytes(繞過閘門)會怎樣
	var direct: PackedByteArray = var_to_bytes(a)
	print("      對照:直接 var_to_bytes(循環 Dictionary).size() = %d" % direct.size())
	return "C-CIRCULAR-REACHED-END"

# ---------------------------------------------------------------- 讀取側

func t_c_read_side() -> String:
	# 全部繞過寫入側,直接構造毒位元組
	_read_side("對照組(乾淨)", var_to_bytes({"alpha": 1}))
	_read_side("plain 編的 Object(EncodedObjectAsID)", var_to_bytes({"poison": RefCounted.new()}))
	_read_side("plain 編的 Resource", var_to_bytes({"poison": Resource.new()}))
	_read_side("with_objects 編的 Object", var_to_bytes_with_objects({"poison": RefCounted.new()}))
	var kd: Dictionary = {}
	kd[RefCounted.new()] = 1
	_read_side("鍵是 Object(plain)", var_to_bytes(kd))
	_read_side("Signal", var_to_bytes({"s": _target.pinged}))
	_read_side("RID", var_to_bytes({"r": RID()}))
	_read_side("Callable", var_to_bytes({"c": _target.noop}))
	_read_side("深度 100", var_to_bytes(_nested(100)))
	_read_side("全零 16 bytes(合法 NIL 編碼)", PackedByteArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]))
	_read_side("空 buffer", PackedByteArray())
	_read_side("頂層是 Array 而非 Dictionary", var_to_bytes([1, 2, 3]))
	return "C-READ-REACHED-END"
