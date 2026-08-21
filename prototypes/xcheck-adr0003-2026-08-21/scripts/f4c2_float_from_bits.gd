# ============================================================================
# F4'-c 補測 —— 以「位元樣式」直接構造 double,繞開來源字面量常數池
# ============================================================================
# 為何需要本檔:f4c_float_fidelity.gd 第一版用「浮點字面量」當測試向量,結果
# `+0.0` 與 `5e-324` 兩列印出的 bits_in 都是 0000000000000080(即 -0.0 的位元),
# 與 `-0.0` 那一列完全相同。也就是說那兩個向量在「進入序列化之前」就已經不是
# 我想測的值了 —— 推測是 GDScript 常數池以 Variant 相等性去重,而 IEEE754 下
# -0.0 == 0.0 為 true(且 5e-324 若被剖析器下溢為 0.0 也會落進同一個常數槽)。
#
# 那是「探針自己的缺陷」,不是序列化的缺陷:往返本身在 13 個向量上 bits_in 恆等於
# bits_out。但既然那兩個向量沒測到我宣稱在測的東西,就必須補一個不依賴字面量的
# 版本,而不是把第一版的 true 當成已涵蓋。
#
# 本檔一律用 PackedByteArray.decode_double() 從明確的小端位元組樣式構造 double,
# 構造路徑不經過任何浮點字面量,故不受常數池去重影響。
# 單獨一檔:decode_double() 若不存在會是 parse error,不可拖累 f4c。
extends RefCounted

static func _from_le_hex(h: String) -> float:
	var b := PackedByteArray()
	b.resize(8)
	for i in range(8):
		b[i] = h.substr(i * 2, 2).hex_to_int()
	return b.decode_double(0)

static func _bits(v: float) -> String:
	return PackedFloat64Array([v]).to_byte_array().hex_encode()

static func t_from_bits_roundtrip() -> String:
	var names: Array[String] = [
		"+0.0            (0x0000000000000000)",
		"-0.0            (0x8000000000000000)",
		"min subnormal   (0x0000000000000001)",
		"max subnormal   (0x000FFFFFFFFFFFFF)",
		"min normal      (0x0010000000000000)",
		"0.1             (0x3FB999999999999A)",
		"+INF            (0x7FF0000000000000)",
		"-INF            (0xFFF0000000000000)",
		"quiet NaN       (0x7FF8000000000000)",
		"NaN w/ payload  (0x7FF8000000000001)",
		"signaling NaN   (0x7FF0000000000001)",
		"max double      (0x7FEFFFFFFFFFFFFF)",
	]
	var le_hex: Array[String] = [
		"0000000000000000",
		"0000000000000080",
		"0100000000000000",
		"ffffffffffff0f00",
		"0000000000001000",
		"9a9999999999b93f",
		"000000000000f07f",
		"000000000000f0ff",
		"000000000000f87f",
		"010000000000f87f",
		"010000000000f07f",
		"ffffffffffffef7f",
	]
	var all_ok := true
	var all_constructed_ok := true
	for i in range(names.size()):
		var want: String = le_hex[i]
		var v: float = _from_le_hex(want)
		var got_in: String = _bits(v)
		var constructed_ok: bool = (got_in == want)
		if not constructed_ok:
			all_constructed_ok = false
		var enc: PackedByteArray = var_to_bytes({"v": v})
		var dec = bytes_to_var(enc)
		if not (dec is Dictionary):
			print("      [%s] *** 解碼未得 Dictionary typeof=%d ***" % [names[i], typeof(dec)])
			all_ok = false
			continue
		var rt: float = (dec as Dictionary)["v"]
		var got_out: String = _bits(rt)
		var same: bool = (got_out == got_in)
		if not same:
			all_ok = false
		print("      [%s] want=%s constructed=%s CONSTRUCT_OK=%s | enc=%2d out=%s ROUNDTRIP_BIT_IDENTICAL=%s" % [names[i], want, got_in, str(constructed_ok), enc.size(), got_out, str(same)])
	print("      ---- 構造出來的值確實等於指定位元 = %s ----" % str(all_constructed_ok))
	print("      ---- 全部向量往返位元完全相同     = %s ----" % str(all_ok))
	return "F4c2-frombits-REACHED-END"

static func t_literal_constant_pool_anomaly() -> String:
	# 直接把第一版那個異常本身量出來,不靠推論。
	var lit_neg_zero := -0.0
	var lit_pos_zero := 0.0
	var lit_subnormal := 5e-324
	var rt_pos_zero: float = float(0)
	var rt_pos_zero2: float = 1.0 - 1.0
	var from_bits_pos_zero: float = _from_le_hex("0000000000000000")
	print("      字面量 -0.0            bits = %s" % _bits(lit_neg_zero))
	print("      字面量  0.0            bits = %s   <-- 若與上一行相同,即為常數池去重" % _bits(lit_pos_zero))
	print("      字面量  5e-324         bits = %s   <-- 同上" % _bits(lit_subnormal))
	print("      執行期 float(0)        bits = %s" % _bits(rt_pos_zero))
	print("      執行期 1.0 - 1.0       bits = %s" % _bits(rt_pos_zero2))
	print("      由位元構造 +0.0        bits = %s" % _bits(from_bits_pos_zero))
	print("      判讀:此為 GDScript 來源字面量層的現象,與 var_to_bytes/bytes_to_var 無關;")
	print("            記錄於此是因為它使 f4c 第一版的兩個測試向量失效。")
	return "F4c2-anomaly-REACHED-END"
