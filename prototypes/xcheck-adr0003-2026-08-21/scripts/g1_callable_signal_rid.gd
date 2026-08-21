# ============================================================================
# G-1 —— Callable / Signal / RID 是否真的通過型別閘門
# ============================================================================
# 待驗證的斷言(2026-08-18 第二輪 /architecture-review 發現 E1,
#   docs/architecture/architecture-review-2026-08-18-round2.md:188 逐字):
#     「Callable/Signal/RID 不是 Object 衍生類,不受 allow_objects=false 管控。
#      …若某擁有系統的 export_state() 不慎把 Callable(例如驗證器參照本身)
#      放進 payload,bytes_to_var(buffer, false) 仍會把它還原。」
#
# 該斷言自 2026-08-18 懸置三輪,來源是訓練資料推測,從未實機驗證 ——
# 與探針 F 的 N-1 剛推翻掉的那個假設同一來源。
#
# 注意:E1 原文寫的 bytes_to_var(buffer, false) 這個形狀本身已由探針 F 階段 1
# 實測為 Parse Error(4.7.1 無此 arity)。本檔一律用 1 引數形狀,
# 即「語意上不允許 Object 的那一個函式」。
#
# 判讀紀律(沿用探針 F):每個測試函式宣告 -> String,最後一行才 return sentinel。
# 呼叫端收到 "" 即代表該函式被中止。編碼/解碼結果一律用**未型別化**的 var 承接
# —— 若宣告成 var e: PackedByteArray 而函式回傳 nil,型別轉換自身就會中止,
# 那會把「API 回傳什麼」這個待測問題混進「測試碼的型別宣告」裡。
extends RefCounted

# ---------------------------------------------------------------------------
# 共用探測器:印出「呼叫前 / 回傳後」,故意不吞任何錯誤
# ---------------------------------------------------------------------------
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

# ===========================================================================
# G-1f 對照組 —— NodePath / StringName:正當原生 Variant 型別,預期乾淨往返
#   目的是證明「測試方法本身有效」,避免「全部失敗」其實是測試碼寫錯
# ===========================================================================
static func t_1f_control_nodepath_stringname() -> String:
	var np := NodePath("Visuals/Sprite2D:modulate:a")
	print("      -- NodePath --  typeof_in=%d  value_in=[%s]" % [typeof(np), str(np)])
	var e1 = _enc("NodePath", np, false)
	var r1 = _dec("NodePath", e1, false)
	print("      [CMP] NodePath  equal_to_source=%s  typeof_out=%d" % [str(r1 == np), typeof(r1)])

	var sn := StringName("affinity_data_pool")
	print("      -- StringName --  typeof_in=%d  value_in=[%s]" % [typeof(sn), str(sn)])
	var e2 = _enc("StringName", sn, false)
	var r2 = _dec("StringName", e2, false)
	print("      [CMP] StringName  equal_to_source=%s  typeof_out=%d" % [str(r2 == sn), typeof(r2)])

	# 包在 Dictionary 裡的形狀(這才是存檔 payload 的真實形狀)
	var d := {"np": np, "sn": sn, "plain": 7}
	var e3 = _enc("Dict{np,sn,plain}", d, false)
	var r3 = _dec("Dict{np,sn,plain}", e3, false)
	print("      [CMP] Dict  equal_to_source=%s" % str(r3 == d))
	return "S-G1f-REACHED-END"

# ===========================================================================
# G-1a —— Callable 能否被編碼(兩種 Callable + 空 Callable)
# ===========================================================================
static func t_1a_encode_bound_method() -> String:
	var target := GProbeTarget.new()
	target.tag = "G1a-TARGET"
	var cb := Callable(target, "ping")
	print("      來源 Callable:typeof=%d  is_valid=%s  get_object=%s  get_method=%s" % [
		typeof(cb), str(cb.is_valid()), str(cb.get_object()), str(cb.get_method())])
	print("      (先自證這個 Callable 現在就能用:)")
	var proof = cb.call(101)
	print("      來源 Callable 直呼結果=[%s]  target.call_count=%d" % [str(proof), target.call_count])

	print("")
	print("      >>> 裸 Callable,plain var_to_bytes():")
	var _e1 = _enc("bare Callable / plain", cb, false)
	print("")
	print("      >>> 裸 Callable,var_to_bytes_with_objects():")
	var _e2 = _enc("bare Callable / with_objects", cb, true)
	print("")
	print("      >>> Dictionary{cb: Callable, alpha: 1},plain var_to_bytes():")
	var _e3 = _enc("Dict{cb}/plain", {"cb": cb, "alpha": 1}, false)
	print("")
	print("      >>> Dictionary{cb: Callable, alpha: 1},var_to_bytes_with_objects():")
	var _e4 = _enc("Dict{cb}/with_objects", {"cb": cb, "alpha": 1}, true)
	return "S-G1a-REACHED-END"

static func t_1a2_encode_lambda() -> String:
	var lam := func(x: int) -> String:
		print("      !!!! LAMBDA ACTUALLY EXECUTED  x=%d !!!!" % x)
		return "LAMBDA-EXECUTED-%d" % x
	print("      來源 lambda:typeof=%d  is_valid=%s  get_object=%s  get_method=%s" % [
		typeof(lam), str(lam.is_valid()), str(lam.get_object()), str(lam.get_method())])
	print("      (先自證它現在就能用:)")
	var proof = lam.call(202)
	print("      來源 lambda 直呼結果=[%s]" % str(proof))
	print("")
	print("      >>> 裸 lambda,plain var_to_bytes():")
	var _e1 = _enc("bare lambda / plain", lam, false)
	print("")
	print("      >>> Dictionary{cb: lambda},plain var_to_bytes():")
	var _e2 = _enc("Dict{lambda}/plain", {"cb": lam, "alpha": 1}, false)
	print("")
	print("      >>> Dictionary{cb: lambda},var_to_bytes_with_objects():")
	var _e3 = _enc("Dict{lambda}/with_objects", {"cb": lam, "alpha": 1}, true)
	return "S-G1a2-REACHED-END"

static func t_1a3_encode_empty_callable() -> String:
	var cb := Callable()
	print("      空 Callable:typeof=%d  is_valid=%s  is_null=%s" % [typeof(cb), str(cb.is_valid()), str(cb.is_null())])
	var _e1 = _enc("empty Callable / plain", cb, false)
	var _e2 = _enc("Dict{empty Callable} / plain", {"cb": cb}, false)
	return "S-G1a3-REACHED-END"

# ===========================================================================
# G-1b —— 解碼:回傳什麼?typeof?是否 ERR_UNAUTHORIZED?是否中止?
#   (本節**不**呼叫還原物 —— call() 的風險留給 G-1c,排在後面)
# ===========================================================================
static func t_1b_decode_bound_method() -> String:
	var target := GProbeTarget.new()
	target.tag = "G1b-TARGET"
	var cb := Callable(target, "ping")
	var d := {"cb": cb, "alpha": 1, "beta": "two"}

	print("      >>> 路徑一:plain var_to_bytes() -> plain bytes_to_var()")
	var e1 = _enc("Dict{cb}", d, false)
	var r1 = _dec("Dict{cb}", e1, false)
	_report_decoded_dict("路徑一", r1)

	print("")
	print("      >>> 路徑二:var_to_bytes_with_objects() -> plain bytes_to_var()  (F2 的形狀)")
	var e2 = _enc("Dict{cb}", d, true)
	var r2 = _dec("Dict{cb}", e2, false)
	_report_decoded_dict("路徑二", r2)

	print("")
	print("      >>> 路徑三:var_to_bytes_with_objects() -> bytes_to_var_with_objects()  (對照上限)")
	var e3 = _enc("Dict{cb}", d, true)
	var r3 = _dec("Dict{cb}", e3, true)
	_report_decoded_dict("路徑三", r3)
	return "S-G1b-REACHED-END"

static func t_1b2_decode_lambda() -> String:
	var lam := func(x: int) -> String:
		print("      !!!! LAMBDA ACTUALLY EXECUTED  x=%d !!!!" % x)
		return "LAMBDA-EXECUTED-%d" % x
	var d := {"cb": lam, "alpha": 1}
	print("      >>> plain -> plain")
	var r1 = _dec("Dict{lambda}", _enc("Dict{lambda}", d, false), false)
	_report_decoded_dict("lambda/plain", r1)
	print("")
	print("      >>> with_objects -> plain")
	var r2 = _dec("Dict{lambda}", _enc("Dict{lambda}", d, true), false)
	_report_decoded_dict("lambda/with_objects->plain", r2)
	return "S-G1b2-REACHED-END"

static func _report_decoded_dict(tag: String, r: Variant) -> void:
	if not (r is Dictionary):
		print("      [RPT] %s : 解碼結果不是 Dictionary(typeof=%d) -> 整包失敗或型別改變" % [tag, typeof(r)])
		return
	var dd: Dictionary = r
	print("      [RPT] %s : Dictionary size=%d keys=%s" % [tag, dd.size(), str(dd.keys())])
	if dd.has("cb"):
		var v = dd["cb"]
		print("      [RPT] %s : dd[cb] typeof=%d  is_null=%s  value=[%s]" % [tag, typeof(v), str(v == null), str(v)])
		print("      [RPT] %s : dd[cb] is Callable = %s" % [tag, str(v is Callable)])
	else:
		print("      [RPT] %s : *** cb 這個鍵不存在了 ***" % tag)

# ===========================================================================
# G-1d —— Signal(編碼 / 解碼 / 內省。emit/connect 留給後面的風險段)
# ===========================================================================
static func t_1d_signal_encode_decode() -> String:
	var target := GProbeTarget.new()
	target.tag = "G1d-TARGET"
	var sg: Signal = target.pinged
	print("      來源 Signal:typeof=%d  is_null=%s  get_object=%s  get_name=%s" % [
		typeof(sg), str(sg.is_null()), str(sg.get_object()), str(sg.get_name())])
	print("      (先自證它現在就能用:connect + emit)")
	sg.connect(target.on_pinged)
	sg.emit(303)
	print("      來源 Signal emit 後 target.emit_count=%d" % target.emit_count)

	print("")
	print("      >>> 裸 Signal,plain var_to_bytes():")
	var _e0 = _enc("bare Signal / plain", sg, false)
	print("")
	print("      >>> Dictionary{sg: Signal},plain -> plain:")
	var r1 = _dec("Dict{sg}", _enc("Dict{sg}/plain", {"sg": sg, "alpha": 1}, false), false)
	_report_decoded_signal("plain->plain", r1)
	print("")
	print("      >>> Dictionary{sg: Signal},with_objects -> plain:")
	var r2 = _dec("Dict{sg}", _enc("Dict{sg}/with_objects", {"sg": sg, "alpha": 1}, true), false)
	_report_decoded_signal("with_objects->plain", r2)
	print("")
	print("      >>> Dictionary{sg: Signal},with_objects -> with_objects:")
	var r3 = _dec("Dict{sg}", _enc("Dict{sg}/with_objects", {"sg": sg, "alpha": 1}, true), true)
	_report_decoded_signal("with_objects->with_objects", r3)
	return "S-G1d-REACHED-END"

static func _report_decoded_signal(tag: String, r: Variant) -> void:
	if not (r is Dictionary):
		print("      [RPT] %s : 解碼結果不是 Dictionary(typeof=%d)" % [tag, typeof(r)])
		return
	var dd: Dictionary = r
	print("      [RPT] %s : keys=%s" % [tag, str(dd.keys())])
	if not dd.has("sg"):
		print("      [RPT] %s : *** sg 這個鍵不存在了 ***" % tag)
		return
	var v = dd["sg"]
	print("      [RPT] %s : dd[sg] typeof=%d  is_null=%s  is Signal=%s  value=[%s]" % [
		tag, typeof(v), str(v == null), str(v is Signal), str(v)])

# ===========================================================================
# G-1e —— RID
#   RID 來源:PhysicsServer2D.body_create()。headless 下物理伺服器仍在跑,
#   不依賴 RenderingServer(headless 為 dummy driver)。
# ===========================================================================
static func t_1e_rid_encode_decode() -> String:
	var body: RID = PhysicsServer2D.body_create()
	print("      來源 RID:typeof=%d  is_valid=%s  get_id=%d" % [typeof(body), str(body.is_valid()), body.get_id()])
	var empty := RID()
	print("      空 RID  :typeof=%d  is_valid=%s  get_id=%d" % [typeof(empty), str(empty.is_valid()), empty.get_id()])

	print("")
	print("      >>> 裸 RID,plain var_to_bytes():")
	var _e0 = _enc("bare RID / plain", body, false)
	print("")
	print("      >>> Dictionary{rid: RID},plain -> plain:")
	var r1 = _dec("Dict{rid}", _enc("Dict{rid}/plain", {"rid": body, "alpha": 1}, false), false)
	_report_decoded_rid("plain->plain", r1, body)
	print("")
	print("      >>> Dictionary{rid: RID},with_objects -> plain:")
	var r2 = _dec("Dict{rid}", _enc("Dict{rid}/with_objects", {"rid": body, "alpha": 1}, true), false)
	_report_decoded_rid("with_objects->plain", r2, body)
	print("")
	print("      >>> Dictionary{rid: 空 RID},plain -> plain:")
	var r3 = _dec("Dict{empty rid}", _enc("Dict{empty rid}/plain", {"rid": empty}, false), false)
	_report_decoded_rid("empty/plain->plain", r3, empty)

	# 刻意不釋放這個 RID:PhysicsServer2D.body_free() 在 4.7.1 不存在
	# (本探針第一次執行即因此整檔 Parse Error,見 log 的 RUN-A 段),
	# 而正確名稱若猜錯會再一次讓整個 G-1 一項都跑不出來。行程即將結束,
	# 洩漏一個物理 body 對量測無影響 —— 用「不呼叫」換掉一個不必要的編譯風險。
	print("      (刻意不釋放此 RID — 見程式碼註解:避免再引入一個不確定的 API 名稱)")
	return "S-G1e-REACHED-END"

static func _report_decoded_rid(tag: String, r: Variant, source: RID) -> void:
	if not (r is Dictionary):
		print("      [RPT] %s : 解碼結果不是 Dictionary(typeof=%d)" % [tag, typeof(r)])
		return
	var dd: Dictionary = r
	print("      [RPT] %s : keys=%s" % [tag, str(dd.keys())])
	if not dd.has("rid"):
		print("      [RPT] %s : *** rid 這個鍵不存在了 ***" % tag)
		return
	var v = dd["rid"]
	print("      [RPT] %s : dd[rid] typeof=%d  is_null=%s  is RID=%s  value=[%s]" % [
		tag, typeof(v), str(v == null), str(v is RID), str(v)])
	if v is RID:
		var rr: RID = v
		print("      [RPT] %s : 還原 RID is_valid=%s get_id=%d  /  來源 get_id=%d  /  相同=%s" % [
			tag, str(rr.is_valid()), rr.get_id(), source.get_id(), str(rr == source)])

# ===========================================================================
# ===== 以下為風險段:實際呼叫 / emit 還原物。排在所有量測之後。 =====
# ===========================================================================

# G-1c —— 安全關鍵:還原出來的 Callable 還能被呼叫嗎?
static func t_1c_invoke_restored_bound() -> String:
	var target := GProbeTarget.new()
	target.tag = "G1c-TARGET"
	var cb := Callable(target, "ping")
	var e = _enc("Dict{cb} for invoke", {"cb": cb}, false)
	var r = _dec("Dict{cb} for invoke", e, false)
	if not (r is Dictionary):
		print("      解碼結果不是 Dictionary -> 沒有可呼叫的東西,G-1c 到此為止")
		return "S-G1c-NOTHING-TO-INVOKE"
	var dd: Dictionary = r
	if not dd.has("cb"):
		print("      cb 鍵不存在 -> 沒有可呼叫的東西,G-1c 到此為止")
		return "S-G1c-NOTHING-TO-INVOKE"
	var v = dd["cb"]
	print("      還原物:typeof=%d  is Callable=%s  value=[%s]" % [typeof(v), str(v is Callable), str(v)])
	if not (v is Callable):
		print("      還原物不是 Callable -> 無 call() 可測")
		return "S-G1c-NOT-A-CALLABLE"
	var rc: Callable = v
	# 只用長期穩定的四個內省方法。get_argument_count()/is_standard()/is_custom()/
	# get_object_id() 這幾個 arity 或存在性我沒有把握,已隔離到 g1x_extra_introspection.gd
	# —— 它們若不存在只會讓那一個小檔 Parse Error,不會再次拖垮整個 G-1。
	print("      [INTRO] is_valid=%s  is_null=%s" % [str(rc.is_valid()), str(rc.is_null())])
	print("      [INTRO] get_object=%s  get_method=%s" % [str(rc.get_object()), str(rc.get_method())])
	print("      [INTRO] 呼叫前 target.call_count=%d" % target.call_count)
	print("      [RISK-1] 即將 rc.call(999) —— 若下一行沒印出來就是中止了")
	var out = rc.call(999)
	print("      [RISK-2] rc.call(999) 回傳 typeof=%d value=[%s]" % [typeof(out), str(out)])
	print("      [RISK-3] 呼叫後 target.call_count=%d  last_arg=%d  <== 這一欄是「真的執行了」的唯一鐵證" % [
		target.call_count, target.last_arg])
	return "S-G1c-REACHED-END"

static func t_1c2_invoke_restored_lambda() -> String:
	var lam := func(x: int) -> String:
		print("      !!!! LAMBDA ACTUALLY EXECUTED  x=%d !!!!" % x)
		return "LAMBDA-EXECUTED-%d" % x
	var r = _dec("Dict{lambda} for invoke", _enc("Dict{lambda} for invoke", {"cb": lam}, false), false)
	if not (r is Dictionary) or not (r as Dictionary).has("cb"):
		print("      無可呼叫的還原物,G-1c2 到此為止")
		return "S-G1c2-NOTHING-TO-INVOKE"
	var v = (r as Dictionary)["cb"]
	print("      還原物:typeof=%d  is Callable=%s  value=[%s]" % [typeof(v), str(v is Callable), str(v)])
	if not (v is Callable):
		return "S-G1c2-NOT-A-CALLABLE"
	var rc: Callable = v
	print("      [INTRO] is_valid=%s  is_null=%s  is_standard=%s  is_custom=%s" % [
		str(rc.is_valid()), str(rc.is_null()), str(rc.is_standard()), str(rc.is_custom())])
	print("      [RISK-1] 即將 rc.call(888)")
	var out = rc.call(888)
	print("      [RISK-2] 回傳 typeof=%d value=[%s]" % [typeof(out), str(out)])
	return "S-G1c2-REACHED-END"

# G-1d2 —— 還原出來的 Signal 還能 connect / emit 嗎?
static func t_1d2_emit_restored_signal() -> String:
	var target := GProbeTarget.new()
	target.tag = "G1d2-TARGET"
	var sg: Signal = target.pinged
	var r = _dec("Dict{sg} for emit", _enc("Dict{sg} for emit", {"sg": sg}, false), false)
	if not (r is Dictionary) or not (r as Dictionary).has("sg"):
		print("      無可用的還原 Signal,G-1d2 到此為止")
		return "S-G1d2-NOTHING-TO-EMIT"
	var v = (r as Dictionary)["sg"]
	print("      還原物:typeof=%d  is Signal=%s  value=[%s]" % [typeof(v), str(v is Signal), str(v)])
	if not (v is Signal):
		return "S-G1d2-NOT-A-SIGNAL"
	var rs: Signal = v
	print("      [INTRO] is_null=%s  get_object=%s  get_object_id=%d  get_name=%s" % [
		str(rs.is_null()), str(rs.get_object()), rs.get_object_id(), str(rs.get_name())])
	print("      [RISK-1] 即將 rs.connect(target.on_pinged)")
	var cerr = rs.connect(target.on_pinged)
	print("      [RISK-2] connect 回傳 typeof=%d value=[%s]  is_connected=%s" % [
		typeof(cerr), str(cerr), str(rs.is_connected(target.on_pinged))])
	print("      [RISK-3] 即將 rs.emit(777);emit 前 target.emit_count=%d" % target.emit_count)
	rs.emit(777)
	print("      [RISK-4] emit 後 target.emit_count=%d  <== 這一欄是「真的送達」的鐵證" % target.emit_count)
	return "S-G1d2-REACHED-END"
