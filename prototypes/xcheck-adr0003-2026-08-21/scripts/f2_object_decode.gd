# ============================================================================
# F2 —— ADR-0003 型別安全論證的地基(VR 第 2 項,ADR 自陳最高優先)
# ============================================================================
# ADR-0003 第 62 行核心洞見:「bytes_to_var(bytes, false) 是引擎層級直接拒絕解碼出
# 任何 Object 衍生實例 …… 型別白名單問題不是『被解決』,而是結構性地不存在」。
# ADR-0003 第 20 行 VR#2 要問的精確問題:實際行為是否確為「整個容器解碼呼叫
# 原子性失敗、回傳 null,並伴隨 console/log 錯誤訊息」。
#
# 判讀紀律:每個測試函式宣告 -> String,函式最後一行才 return sentinel。
# 呼叫端收到 "" 即代表該函式被中止 —— 這是唯一可靠的「有沒有中止」依據,
# 不是任何印出來的標籤。三個 sentinel 位置:
#   [S1] 呼叫 bytes_to_var 之前
#   [S2] 呼叫 bytes_to_var 之後(印得出來 = 沒中止,且拿得到回傳值)
#   [S3] 函式 return 值本身(呼叫端可見 = 函式完整跑完)
extends RefCounted

# ---- F2-a:頂層就是一個 Object ----
static func t_a_toplevel_object() -> String:
	var enc: PackedByteArray = var_to_bytes_with_objects(RefCounted.new())
	print("      [S1] BEFORE bytes_to_var  (encoded size=%d)" % enc.size())
	var r = bytes_to_var(enc)
	print("      [S2] AFTER  bytes_to_var  typeof=%d  is_null=%s  value=[%s]" % [typeof(r), str(r == null), str(r)])
	return "S3-F2a-REACHED-END"

# ---- F2-b:原子性 —— 3 個合法鍵 + 1 個 Object 值 ----
static func t_b_atomicity() -> String:
	var d: Dictionary = {"alpha": 1, "beta": "two", "gamma": 3.5, "poison": RefCounted.new()}
	var enc: PackedByteArray = var_to_bytes_with_objects(d)
	print("      [S1] BEFORE bytes_to_var  (4 keys: alpha/beta/gamma/poison, encoded size=%d)" % enc.size())
	var r = bytes_to_var(enc)
	print("      [S2] AFTER  bytes_to_var  typeof=%d  is_null=%s" % [typeof(r), str(r == null)])
	if r is Dictionary:
		var dd: Dictionary = r
		print("      [S2b] *** PARTIAL DECODE *** size=%d keys=%s" % [dd.size(), str(dd.keys())])
		print("      [S2b] full value = %s" % str(dd))
	else:
		print("      [S2b] not a Dictionary -> 整包失敗(ADR 主張的原子性失敗)")
	return "S3-F2b-REACHED-END"

# ---- F2-c:深層巢狀 Dictionary -> Array -> Object(第三層) ----
static func t_c_deep_nested() -> String:
	var d: Dictionary = {"lvl1_ok": 11, "lvl1_arr": ["s", 22, RefCounted.new()]}
	var enc: PackedByteArray = var_to_bytes_with_objects(d)
	print("      [S1] BEFORE bytes_to_var  (Dict -> Array -> Object, encoded size=%d)" % enc.size())
	var r = bytes_to_var(enc)
	print("      [S2] AFTER  bytes_to_var  typeof=%d  is_null=%s  value=[%s]" % [typeof(r), str(r == null), str(r)])
	return "S3-F2c-REACHED-END"

# ---- F2-f:寫入側 —— var_to_bytes()(不帶 _with_objects)碰到 Object ----
static func t_f_write_side_plain() -> String:
	var d: Dictionary = {"alpha": 1, "poison": RefCounted.new()}
	print("      [S1] BEFORE var_to_bytes (NO _with_objects) on Dictionary containing an Object")
	var enc: PackedByteArray = var_to_bytes(d)
	print("      [S2] AFTER  var_to_bytes  size=%d  hex=%s" % [enc.size(), enc.hex_encode()])
	var r = bytes_to_var(enc)
	print("      [S3] round-trip bytes_to_var  typeof=%d  value=[%s]" % [typeof(r), str(r)])
	if r is Dictionary:
		var dd: Dictionary = r
		print("      [S3b] keys=%s" % str(dd.keys()))
		if dd.has("poison"):
			print("      [S3b] dd['poison'] typeof=%d value=[%s]  <-- 這是什麼型別?" % [typeof(dd["poison"]), str(dd["poison"])])
	return "S4-F2f-REACHED-END"

# ---- F2-f2:對照 —— 頂層直接就是 Object,用 plain var_to_bytes ----
static func t_f2_write_side_toplevel() -> String:
	var o := RefCounted.new()
	print("      [S1] BEFORE var_to_bytes(RefCounted.new()) — plain, 頂層即 Object")
	var enc: PackedByteArray = var_to_bytes(o)
	print("      [S2] AFTER  var_to_bytes  size=%d  hex=%s" % [enc.size(), enc.hex_encode()])
	var r = bytes_to_var(enc)
	print("      [S3] bytes_to_var  typeof=%d  value=[%s]" % [typeof(r), str(r)])
	return "S4-F2f2-REACHED-END"

# ---- F2-g:三種 Object 種類 ----
static func t_g_builtin_refcounted() -> String:
	var enc: PackedByteArray = var_to_bytes_with_objects({"o": RefCounted.new()})
	print("      [S1] BEFORE (builtin RefCounted, size=%d)" % enc.size())
	var r = bytes_to_var(enc)
	print("      [S2] AFTER  typeof=%d is_null=%s value=[%s]" % [typeof(r), str(r == null), str(r)])
	return "S3-F2g-builtin-REACHED-END"

static func t_g_custom_refcounted() -> String:
	var enc: PackedByteArray = var_to_bytes_with_objects({"o": F2CustomRef.new()})
	print("      [S1] BEFORE (custom class_name F2CustomRef, size=%d)" % enc.size())
	var r = bytes_to_var(enc)
	print("      [S2] AFTER  typeof=%d is_null=%s value=[%s]" % [typeof(r), str(r == null), str(r)])
	return "S3-F2g-customref-REACHED-END"

static func t_g_custom_resource() -> String:
	var enc: PackedByteArray = var_to_bytes_with_objects({"o": F2CustomRes.new()})
	print("      [S1] BEFORE (custom class_name F2CustomRes extends Resource, size=%d)" % enc.size())
	var r = bytes_to_var(enc)
	print("      [S2] AFTER  typeof=%d is_null=%s value=[%s]" % [typeof(r), str(r == null), str(r)])
	return "S3-F2g-customres-REACHED-END"

# ---- 對照組:完全乾淨的 payload,確認正常路徑真的會回傳 Dictionary ----
static func t_control_clean() -> String:
	var d: Dictionary = {"alpha": 1, "beta": "two", "gamma": 3.5}
	var r = bytes_to_var(var_to_bytes(d))
	print("      [CONTROL] clean payload -> typeof=%d  equal_to_source=%s  value=%s" % [typeof(r), str(r == d), str(r)])
	return "CONTROL-REACHED-END"
