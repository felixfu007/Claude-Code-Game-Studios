# F4'-c —— 浮點位元保真。ADR-0003 第 70 行以「JSON 雙精度無法保證位元級往返」
# 作為拒絕 JSON 的理由之一,GDD AC-24 的「位元完全相同或誤差 <1e-12」依賴此。
# 位元比較採 PackedFloat64Array([v]).to_byte_array().hex_encode() —— 這是獨立於
# var_to_bytes 編碼器的 IEEE754 原始位元讀出,不是用同一個編碼器自我證明。
# NAN 一律用 is_nan() 判,不用 ==。
extends RefCounted

static func _bits(v: float) -> String:
	var a := PackedFloat64Array([v])
	return a.to_byte_array().hex_encode()

static func t_roundtrip() -> String:
	var names: Array[String] = [
		"0.1", "1e-300", "PI", "-0.0", "+0.0", "INF", "-INF", "NAN",
		"1.0/3.0", "max double 1.7976931348623157e308", "min subnormal 5e-324",
		"9007199254740993.0 (2^53+1)", "1.5 (exactly representable)",
	]
	var vals: Array[float] = [
		0.1, 1e-300, PI, -0.0, 0.0, INF, -INF, NAN,
		1.0 / 3.0, 1.7976931348623157e308, 5e-324,
		9007199254740993.0, 1.5,
	]
	var all_bit_identical := true
	for i in range(names.size()):
		var v: float = vals[i]
		var enc: PackedByteArray = var_to_bytes({"v": v})
		var dec = bytes_to_var(enc)
		if not (dec is Dictionary):
			print("      [%-44s] *** 解碼未得 Dictionary,typeof=%d ***" % [names[i], typeof(dec)])
			all_bit_identical = false
			continue
		var rt: float = (dec as Dictionary)["v"]
		var b_in := _bits(v)
		var b_out := _bits(rt)
		var same := (b_in == b_out)
		if not same:
			all_bit_identical = false
		var nan_note := ""
		if is_nan(v):
			nan_note = "  is_nan(in)=%s is_nan(out)=%s" % [str(is_nan(v)), str(is_nan(rt))]
		print("      [%-44s] enc_size=%2d  bits_in=%s  bits_out=%s  BIT_IDENTICAL=%s%s" % [names[i], enc.size(), b_in, b_out, str(same), nan_note])
	print("      ---- 全部項目位元完全相同 = %s ----" % str(all_bit_identical))
	return "F4c-REACHED-END"

static func t_int_float_distinction() -> String:
	# ADR-0003 第 260 行以「JSON 的 int vs float 型別可能模糊」作為拒絕理由之一。
	var d: Dictionary = {"as_int": 3, "as_float": 3.0}
	var dec = bytes_to_var(var_to_bytes(d))
	var dd: Dictionary = dec
	print("      as_int   typeof=%d (2=TYPE_INT)   value=%s" % [typeof(dd["as_int"]), str(dd["as_int"])])
	print("      as_float typeof=%d (3=TYPE_FLOAT) value=%s" % [typeof(dd["as_float"]), str(dd["as_float"])])
	print("      int/float 區分是否保住 = %s" % str(typeof(dd["as_int"]) == TYPE_INT and typeof(dd["as_float"]) == TYPE_FLOAT))
	return "F4c-int-float-REACHED-END"
