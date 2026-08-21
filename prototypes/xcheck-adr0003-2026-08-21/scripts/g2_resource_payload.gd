# ============================================================================
# G-2 —— var_to_bytes()(不帶 _with_objects)對 Resource 子類別
# ============================================================================
# 待驗證的宣稱(docs/registry/architecture.yaml,forbidden pattern
#   resource_based_save_payload 的 why: 欄,第 1558-1559 行逐字):
#     「A future system … that hands a raw Resource to the save system's write path
#      would fail to serialize at all, or — worse, if some other path bypasses
#      this check — reintroduce the exact type-instantiation attack surface …」
#
# 探針 F 的 F2-f 已測出 plain var_to_bytes() 對 RefCounted.new() **不失敗**,
# 而是靜默編成 EncodedObjectAsID(N-1)。但 F2-f 測的是 RefCounted,不是 Resource;
# F2-g 雖有測 F2CustomRes,走的卻是 var_to_bytes_with_objects() 的讀取側路徑,
# 沒有回答「plain 寫入側對 Resource 會怎樣」。因此 registry:1558 仍未驗證。
#
# 本檔的關鍵差異:欄位帶**可辨識的值**,使「只剩一個 ID」與「資料真的被帶過去」
# 在 log 上一眼可分 —— 這是 F2-g 用預設值時測不出來的區別。
#
# 判讀紀律同 G-1:未型別化承接、三段 sentinel、風險測項排最後。
extends RefCounted

static func _enc(label: String, v: Variant, with_objects: bool) -> Variant:
	var fname: String = "var_to_bytes_with_objects" if with_objects else "var_to_bytes"
	print("      [ENC-1] %s : calling %s() ..." % [label, fname])
	var e = var_to_bytes_with_objects(v) if with_objects else var_to_bytes(v)
	print("      [ENC-2] %s : RETURNED typeof=%d" % [label, typeof(e)])
	if e is PackedByteArray:
		var hx: String = e.hex_encode() if e.size() <= 512 else "<%d bytes, too long>" % e.size()
		print("      [ENC-3] %s : size=%d hex=%s" % [label, e.size(), hx])
	else:
		print("      [ENC-3] %s : *** NOT a PackedByteArray *** value=[%s]" % [label, str(e)])
	return e

static func _dec(label: String, e: Variant, with_objects: bool) -> Variant:
	var fname: String = "bytes_to_var_with_objects" if with_objects else "bytes_to_var"
	if not (e is PackedByteArray):
		print("      [DEC-0] %s : SKIPPED — 編碼側沒有給出 PackedByteArray" % label)
		return null
	print("      [DEC-1] %s : calling %s() ..." % [label, fname])
	var r = bytes_to_var_with_objects(e) if with_objects else bytes_to_var(e)
	print("      [DEC-2] %s : RETURNED typeof=%d is_null=%s value=[%s]" % [label, typeof(r), str(r == null), str(r)])
	return r

static func _make_res() -> GCustomRes:
	var r := GCustomRes.new()
	r.payload_int = 424242
	r.payload_str = "G2-DISTINCTIVE-STRING"
	r.payload_dict = {"nested": [1, 2, 3], "flag": true}
	return r

# 用 Object.get() 而非 . 存取 —— get() 對不存在的屬性回傳 null 且**不中止**,
# 這樣「屬性不存在」與「函式被中止」在 log 上不會混淆。
static func _describe_object(tag: String, v: Variant) -> void:
	print("      [OBJ] %s : typeof=%d  is Object=%s  is Resource=%s  value=[%s]" % [
		tag, typeof(v), str(v is Object), str(v is Resource), str(v)])
	if not (v is Object):
		return
	var o: Object = v
	print("      [OBJ] %s : get_class()=%s  is EncodedObjectAsID=%s" % [
		tag, o.get_class(), str(o is EncodedObjectAsID)])
	print("      [OBJ] %s : get(payload_int)=[%s]  get(payload_str)=[%s]  get(payload_dict)=[%s]" % [
		tag, str(o.get("payload_int")), str(o.get("payload_str")), str(o.get("payload_dict"))])
	print("      [OBJ] %s : get(object_id)=[%s]" % [tag, str(o.get("object_id"))])

# ===========================================================================
# G-2a / G-2b —— 自訂 class_name Resource 子類別,plain 寫入側
# ===========================================================================
static func t_2ab_custom_resource_plain() -> String:
	var res := _make_res()
	print("      來源 Resource:get_class=%s  instance_id=%d" % [res.get_class(), res.get_instance_id()])
	print("      來源欄位:payload_int=%d  payload_str=%s  payload_dict=%s" % [
		res.payload_int, res.payload_str, str(res.payload_dict)])

	print("")
	print("      >>> G-2a:Dictionary{res: GCustomRes, alpha: 1},plain var_to_bytes()")
	var e = _enc("Dict{res}/plain", {"res": res, "alpha": 1}, false)
	print("")
	print("      >>> G-2b:plain bytes_to_var()")
	var r = _dec("Dict{res}/plain", e, false)
	if r is Dictionary:
		var dd: Dictionary = r
		print("      [RPT] keys=%s  size=%d" % [str(dd.keys()), dd.size()])
		if dd.has("res"):
			_describe_object("dd[res]", dd["res"])
		else:
			print("      [RPT] *** res 這個鍵不存在了 ***")
	else:
		print("      [RPT] 解碼結果不是 Dictionary -> 整包失敗")
	return "S-G2ab-REACHED-END"

static func t_2a2_bare_toplevel_resource_plain() -> String:
	var res := _make_res()
	print("      >>> 頂層直接就是 Resource,plain var_to_bytes()")
	var e = _enc("bare GCustomRes/plain", res, false)
	var r = _dec("bare GCustomRes/plain", e, false)
	_describe_object("bare 還原物", r)
	return "S-G2a2-REACHED-END"

# ===========================================================================
# G-2c —— 內建 Resource.new() 與自訂子類別行為是否一致
# ===========================================================================
static func t_2c_builtin_resource_plain() -> String:
	var res := Resource.new()
	res.resource_name = "G2-BUILTIN-RES"
	print("      來源:get_class=%s  instance_id=%d  resource_name=%s" % [
		res.get_class(), res.get_instance_id(), res.resource_name])
	var e = _enc("Dict{builtin Resource}/plain", {"res": res, "alpha": 1}, false)
	var r = _dec("Dict{builtin Resource}/plain", e, false)
	if r is Dictionary and (r as Dictionary).has("res"):
		_describe_object("builtin dd[res]", (r as Dictionary)["res"])
		var inner = (r as Dictionary)["res"]
		if inner is Object:
			print("      [OBJ] builtin dd[res] : get(resource_name)=[%s]" % str((inner as Object).get("resource_name")))
	print("      >>> 與 F2 對照:同一個內建 Resource 走 with_objects 寫入 + plain 讀取")
	var e2 = _enc("Dict{builtin Resource}/with_objects", {"res": res, "alpha": 1}, true)
	var r2 = _dec("Dict{builtin Resource}/with_objects->plain", e2, false)
	print("      [RPT] with_objects->plain 結果 typeof=%d is_null=%s" % [typeof(r2), str(r2 == null)])
	return "S-G2c-REACHED-END"

# ===========================================================================
# G-2c2 —— 上限對照組:with_objects 兩側。用來界定「真的把資料帶過去」長什麼樣。
#   這一項不是 ADR 會走的路徑,它的作用是讓 G-2b 的「只剩 ID」有對照基準。
# ===========================================================================
static func t_2c2_with_objects_both_sides() -> String:
	var res := _make_res()
	print("      來源 instance_id=%d" % res.get_instance_id())
	var e = _enc("Dict{res}/with_objects", {"res": res, "alpha": 1}, true)
	var r = _dec("Dict{res}/with_objects->with_objects", e, true)
	if r is Dictionary and (r as Dictionary).has("res"):
		var v = (r as Dictionary)["res"]
		_describe_object("with_objects 還原物", v)
		if v is Object:
			print("      [OBJ] 還原物 instance_id=%d  與來源同一個實例=%s" % [
				(v as Object).get_instance_id(), str((v as Object).get_instance_id() == res.get_instance_id())])
	return "S-G2c2-REACHED-END"

# ===========================================================================
# ===== 風險段:instance_from_id()。整支探針的最後一項。 =====
#   問題:plain 路徑還原出來的 EncodedObjectAsID 所帶的 ID,能不能拿去復活?
#   本測項刻意讓來源物件在同一行程內**仍然活著** —— 那是「懸空 ID 是否可復活」
#   這個實務風險的最壞情況(跨行程 ID 顯然無意義,已在探針 F 列為未查證)。
# ===========================================================================
static func t_2d_instance_from_id() -> String:
	var res := _make_res()
	var src_id: int = res.get_instance_id()
	print("      來源仍活著,instance_id=%d" % src_id)
	var r = _dec("Dict{res}/plain for 2d", _enc("Dict{res}/plain for 2d", {"res": res}, false), false)
	var got_id: int = -1
	if r is Dictionary and (r as Dictionary).has("res"):
		var v = (r as Dictionary)["res"]
		_describe_object("2d 還原物", v)
		if v is Object:
			var raw = (v as Object).get("object_id")
			print("      [2d] get(object_id)=[%s] typeof=%d" % [str(raw), typeof(raw)])
			if typeof(raw) == TYPE_INT:
				got_id = raw
	print("      [2d] 取到的 id=%d  /  來源 id=%d  /  相同=%s" % [got_id, src_id, str(got_id == src_id)])

	if got_id == -1:
		print("      [2d] 取不到 object_id -> instance_from_id 無從測起(明確記為未達成,非未做)")
		return "S-G2d-NO-ID"

	print("      [RISK-1] 即將 instance_from_id(%d) —— 若下一行沒印出來就是中止/崩潰了" % got_id)
	var revived = instance_from_id(got_id)
	print("      [RISK-2] instance_from_id 回傳 typeof=%d is_null=%s value=[%s]" % [
		typeof(revived), str(revived == null), str(revived)])
	if revived is Object:
		var ro: Object = revived
		print("      [RISK-3] get_class=%s  instance_id=%d  與來源同一實例=%s" % [
			ro.get_class(), ro.get_instance_id(), str(ro.get_instance_id() == src_id)])
		print("      [RISK-4] 復活物欄位:payload_int=[%s]  payload_str=[%s]  payload_dict=[%s]" % [
			str(ro.get("payload_int")), str(ro.get("payload_str")), str(ro.get("payload_dict"))])
		print("      [RISK-4] <== 若這一行印出 424242 / G2-DISTINCTIVE-STRING,代表 ID 可被復活成完整物件")
	return "S-G2d-REACHED-END"

# 真正的最後一項:一個幾乎確定不存在的 ID。放在 t_2d 之後,因為它比 t_2d 更可能崩。
static func t_2d2_instance_from_bogus_id() -> String:
	var bogus: int = 123456789
	print("      [RISK-1] 即將 instance_from_id(%d)(刻意選一個幾乎確定不存在的 id)" % bogus)
	var revived = instance_from_id(bogus)
	print("      [RISK-2] 回傳 typeof=%d is_null=%s value=[%s]" % [
		typeof(revived), str(revived == null), str(revived)])
	return "S-G2d2-REACHED-END"
