extends RefCounted
# 驗證 F(第二半,行程 2 —— 獨立行程)。
# 這一項關掉探針 F 未查證 #5 與探針 G 未查證 #1:
# 存檔裡夾帶的記憶體號碼(EncodedObjectAsID / Signal 的 ObjectID)在新行程裡是什麼?
# 指向 nothing?還是指向剛好占用同號碼的別的物件?——「後者是最壞情況,未測」。
#
# 風險遞增,每一項獨立函式:sentinel 收到 "" 即代表該項中止。
# 刻意「不」呼叫還原出來的 Callable(探針 G 已實測會中止呼叫函式)。

const PATH_WITH_OBJECTS: String = "user://f_with_objects.bin"
const PATH_PLAIN: String = "user://f_plain.bin"
const PATH_IDS: String = "user://f_ids.txt"

var _saved_oid: int = 0
var _churn: Array = []

func _read_ids() -> int:
	var f := FileAccess.open(PATH_IDS, FileAccess.READ)
	if f == null:
		return 0
	var line := f.get_line()
	f.close()
	return int(line)

func _slot(oid: int) -> int:
	# Godot 的 ObjectID 低 32 bits 是 slot,高位是遞增的 validator。
	# (這個拆法是推測 —— 只用來「觀察」,任何結論都以 instance_from_id 的實際回傳為準。)
	return oid & 0xFFFFFFFF

func t_f1_ids_and_pre_churn_lookup() -> String:
	_saved_oid = _read_ids()
	print("      行程 1 存下的 instance_id = %d" % _saved_oid)
	print("      低 32 bits(推測為 slot)  = %d" % _slot(_saved_oid))
	if _saved_oid == 0:
		return "F2-ABORT-NO-SIDECAR"
	print("      本行程新建一個物件的 id 作為對照 = %d" % SkelPoisonTarget.new().get_instance_id())
	print("      -- 未經任何物件配置(churn)之前,直接查詢那個號碼 --")
	var o = instance_from_id(_saved_oid)
	print("      instance_from_id(舊 id) -> typeof=%d is_null=%s" % [typeof(o), str(o == null)])
	if o != null:
		print("        !!! 拿到東西了: class=%s" % str((o as Object).get_class()))
	return "F1-REACHED-END"

func t_f2_post_churn_lookup() -> String:
	# 刻意大量配置物件並保持存活,盡量把 slot 用滿 —— 逼近「同號碼被別的物件占用」的最壞情況
	for i in 2000:
		_churn.append(SkelPoisonTarget.new())
	var ids: Array = []
	for o in _churn:
		ids.append((o as Object).get_instance_id())
	var lo: int = ids[0]
	var hi: int = ids[0]
	var collision: bool = false
	for v in ids:
		if v < lo:
			lo = v
		if v > hi:
			hi = v
		if v == _saved_oid:
			collision = true
	print("      配置了 %d 個物件並保持存活" % _churn.size())
	print("        id 範圍 %d .. %d" % [lo, hi])
	print("        slot 範圍 %d .. %d" % [_slot(lo), _slot(hi)])
	print("        舊 id 的 slot %d 落在這個範圍內嗎: %s"
		% [_slot(_saved_oid), str(_slot(_saved_oid) >= _slot(lo) and _slot(_saved_oid) <= _slot(hi))])
	print("        有任何新物件「完整」等於舊 id 嗎: %s" % str(collision))
	var o = instance_from_id(_saved_oid)
	print("      instance_from_id(舊 id) 再查一次 -> typeof=%d is_null=%s" % [typeof(o), str(o == null)])
	if o != null:
		print("        !!! 拿到東西了: class=%s instance_id=%d"
			% [str((o as Object).get_class()), (o as Object).get_instance_id()])
	return "F2-REACHED-END"

func t_f3_plain_file() -> String:
	var b := SkelFixture.read_file(PATH_PLAIN)
	print("      %s -> %d bytes" % [PATH_PLAIN, b.size()])
	var v = bytes_to_var(b)
	print("      bytes_to_var typeof=%d" % typeof(v))
	if not (v is Dictionary):
		return "F3-REACHED-END(not-dict)"
	var d: Dictionary = v
	print("      keys = %s" % str(d.keys()))
	print("      marker_str = %s" % str(d.get("marker_str")))
	for k in ["obj", "sig", "cb"]:
		var e = d.get(k)
		print("        %-4s typeof=%d  class=%s" % [k, typeof(e),
			(str((e as Object).get_class()) if e is Object else "n/a")])
	var o = d.get("obj")
	if o is Object:
		var got_id = (o as Object).get("object_id")
		print("      obj.get(\"object_id\") = %s(行程 1 存的是 %d;相同嗎 %s)"
			% [str(got_id), _saved_oid, str(typeof(got_id) == TYPE_INT and int(got_id) == _saved_oid)])
		print("      obj 的欄位還在嗎: marker=%s" % str((o as Object).get("marker")))
	# 骨架的閘門對這份位元組怎麼判
	var res = SaveFormat.deserialize_block(b)
	print("      SaveFormat.deserialize_block -> ok=%s detail=%s path=%s"
		% [str(res.ok()), res.detail, res.offending_path])
	return "F3-REACHED-END"

func t_f4_with_objects_file() -> String:
	var b := SkelFixture.read_file(PATH_WITH_OBJECTS)
	print("      %s -> %d bytes" % [PATH_WITH_OBJECTS, b.size()])
	print("      -- 先用 1 引數的 bytes_to_var(骨架真正會走的那一條)--")
	var v1 = bytes_to_var(b)
	print("      bytes_to_var typeof=%d is_null=%s" % [typeof(v1), str(v1 == null)])
	print("      -- 再用 bytes_to_var_with_objects(僅為量測跨行程行為)--")
	var v2 = bytes_to_var_with_objects(b)
	print("      bytes_to_var_with_objects typeof=%d" % typeof(v2))
	if not (v2 is Dictionary):
		return "F4-REACHED-END(not-dict)"
	var d: Dictionary = v2
	print("      keys = %s" % str(d.keys()))
	var o = d.get("obj")
	print("      obj typeof=%d is_Object=%s" % [typeof(o), str(o is Object)])
	if o is Object:
		print("        class=%s  instance_id=%d(行程 1 的是 %d)"
			% [str((o as Object).get_class()), (o as Object).get_instance_id(), _saved_oid])
		print("        is SkelPoisonTarget = %s" % str(o is SkelPoisonTarget))
		print("        marker = %s(行程 1 是 987654321)" % str((o as Object).get("marker")))
	var cb = d.get("cb")
	print("      cb typeof=%d is_valid=%s(刻意不呼叫它)"
		% [typeof(cb), (str((cb as Callable).is_valid()) if cb is Callable else "n/a")])
	return "F4-REACHED-END"

func t_f5_signal_inspect() -> String:
	# 風險段:Signal 在行程 1 夾帶了一個 ObjectID 進位元組流。
	var b := SkelFixture.read_file(PATH_WITH_OBJECTS)
	var d = bytes_to_var_with_objects(b)
	if not (d is Dictionary):
		return "F5-REACHED-END(no-dict)"
	var sig = (d as Dictionary).get("sig")
	print("      sig typeof=%d is_Signal=%s" % [typeof(sig), str(sig is Signal)])
	if not (sig is Signal):
		return "F5-REACHED-END(not-signal)"
	var s: Signal = sig
	print("      get_name() = %s" % str(s.get_name()))
	print("      about to call get_object_id()...")
	print("      get_object_id() = %d(行程 1 的來源是 %d;相同嗎 %s)"
		% [s.get_object_id(), _saved_oid, str(s.get_object_id() == _saved_oid)])
	print("      about to call is_null()...")
	print("      is_null() = %s" % str(s.is_null()))
	print("      about to call get_object()...")
	var obj = s.get_object()
	print("      get_object() = %s" % str(obj))
	if obj != null:
		print("        !!! 新行程裡竟然拿到了一個物件: class=%s instance_id=%d"
			% [str((obj as Object).get_class()), (obj as Object).get_instance_id()])
	return "F5-REACHED-END"

func t_f6_signal_connect_emit() -> String:
	# 最高風險,排在最後:還原出來的 Signal 在新行程裡還能 connect / emit 嗎?
	var b := SkelFixture.read_file(PATH_WITH_OBJECTS)
	var d = bytes_to_var_with_objects(b)
	if not (d is Dictionary):
		return "F6-REACHED-END(no-dict)"
	var sig = (d as Dictionary).get("sig")
	if not (sig is Signal):
		return "F6-REACHED-END(not-signal)"
	var s: Signal = sig
	var witness := SkelPoisonTarget.new()
	print("      about to connect()...")
	var err: int = s.connect(witness._on_pinged)
	print("      connect() -> %d (%s)" % [err, error_string(err)])
	print("      is_connected = %s" % str(s.is_connected(witness._on_pinged)))
	print("      about to emit()...")
	s.emit(777)
	print("      emit() 之後 witness.ping_count = %d(0 = 事件沒送達)" % witness.ping_count)
	return "F6-REACHED-END"
