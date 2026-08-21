# F4'-c 補測之二 —— 判別性測試:上一檔 f4c2 觀察到「同一檔案內所有值為零的 float
# 編譯期常數(含 0.0 / 5e-324 / float(0) / 1.0-1.0)都印出 -0.0 的位元」。
# 那個檔案裡 -0.0 是**第一個**出現的零值 float 字面量。
#
# 本檔是同一形狀但**順序相反**:+0.0 先出現、-0.0 後出現。
#   * 若兩者都印出 +0.0 的位元 -> 支持「同檔內先出現者勝」的常數去重假說
#   * 若各自印出正確位元       -> 推翻該假說,f4c2 的成因另有其他
# 單獨一檔,因為「哪個字面量先出現」正是本測項唯一的自變數,不能與 f4c2 同檔。
extends RefCounted

static func _bits(v: float) -> String:
	return PackedFloat64Array([v]).to_byte_array().hex_encode()

static func probe() -> String:
	var first_pos_zero := 0.0      # 本檔中第一個零值 float 字面量
	var then_neg_zero := -0.0
	print("      本檔順序:先 0.0、後 -0.0(與 f4c2 相反)")
	print("        字面量  0.0  (先) bits = %s   期望 0000000000000000" % _bits(first_pos_zero))
	print("        字面量 -0.0  (後) bits = %s   期望 0000000000000080" % _bits(then_neg_zero))
	print("      判讀:若第二行印出 0000000000000000,即『同檔內先出現的零值 float 常數勝』;")
	print("            若兩行各自正確,則 f4c2 的成因不是順序相關的常數去重。")
	return "F4c3-REACHED-END"

static func probe_signbit_visible() -> String:
	# 用一個不依賴位元讀取的獨立管道再確認一次:1.0/x 對 ±0 會給出 ±INF。
	var z := 0.0
	print("        1.0 / (本檔字面量 0.0) = %s   (+inf 表示 +0.0,-inf 表示 -0.0)" % str(1.0 / z))
	var from_bits := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]).decode_double(0)
	print("        1.0 / (由位元構造的 +0.0) = %s" % str(1.0 / from_bits))
	return "F4c3-signbit-REACHED-END"
