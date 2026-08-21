extends RefCounted
# 追加測項(Run 1 的 G 量出來之後才發現非做不可):
# 型別閘門單獨要 20 ms,是 var_to_bytes 的 15 倍以上,且占 read_full 三成。
# 這是「規格要求的形狀」造成的,還是「我的實作」造成的?
# 本檔用一個精簡版閘門(只回 int、不配置任何結果物件、失敗才算路徑)當對照,
# 把成本歸因分清楚 —— 這決定 (c) 類建議該怎麼下。

const RECORDS: int = 500

# 精簡版:與 SaveFormat._walk 同語意,但
#   (1) 回傳 int 而不是每個節點都 new 一個 TypeGateResult
#   (2) 不組 offending_path 字串
func _fast(v: Variant, depth: int) -> int:
	if depth > SaveFormat.MAX_PAYLOAD_DEPTH:
		return SaveFormat.PayloadRejection.DEPTH_EXCEEDED
	var t: int = typeof(v)
	if not SaveFormat.ALLOWED_TYPES.has(t):
		return SaveFormat.PayloadRejection.FORBIDDEN_TYPE
	if t == TYPE_DICTIONARY:
		var d: Dictionary = v
		for k in d:
			if not SaveFormat.ALLOWED_KEY_TYPES.has(typeof(k)):
				return SaveFormat.PayloadRejection.FORBIDDEN_TYPE
			var s: int = _fast(d[k], depth + 1)
			if s != SaveFormat.PayloadRejection.NONE:
				return s
	elif t == TYPE_ARRAY:
		var a: Array = v
		for i in a.size():
			var s2: int = _fast(a[i], depth + 1)
			if s2 != SaveFormat.PayloadRejection.NONE:
				return s2
	return SaveFormat.PayloadRejection.NONE

func _ms(u: int) -> String:
	return "%.3f ms" % (float(u) / 1000.0)

func t_i_gate_attribution() -> String:
	var payload: Dictionary = FakeAffinitySource.new().export_state(RECORDS)
	# 節點數估算
	var nodes: int = 1 + 3 + RECORDS * 6 + 12 + 2
	print("      payload 約 %d 個節點(500 筆 x 6 + 頂層)" % nodes)
	for pass_no in 3:
		var t0: int = Time.get_ticks_usec()
		var r1 = SaveFormat.validate_payload_types(payload)
		var t_spec: int = Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		var r2: int = _fast(payload, 0)
		var t_fast: int = Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		var b: PackedByteArray = var_to_bytes(payload)
		var t_enc: int = Time.get_ticks_usec() - t0
		print("      pass %d: 規格版閘門 %-10s 精簡版閘門 %-10s var_to_bytes %-10s (rej %d/%d, %d bytes)"
			% [pass_no + 1, _ms(t_spec), _ms(t_fast), _ms(t_enc), r1, r2, b.size()])
	return "I-REACHED-END"

func t_i_warm_file_io() -> String:
	# Run 1 量到檔案寫入 42 ms / 讀取 29 ms,對 70 KB 而言高得可疑
	# (首次建檔 + Windows AppData)。重量三次,分清「冷」與「熱」。
	var fx := SkelFixture.new()
	var wr := fx.build(RECORDS)
	print("      信封 %d bytes" % wr.buffer.size())
	for i in 3:
		var path := "user://slot_warm_%d.sav" % i
		var t0: int = Time.get_ticks_usec()
		SkelFixture.write_file(path, wr.buffer)
		var t_w: int = Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		var back := SkelFixture.read_file(path)
		var t_r: int = Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		var res = fx.reader().read_full(back, SkelFixture.GAME_RULESET_VERSION)
		var t_f: int = Time.get_ticks_usec() - t0
		print("      iter %d: write %-10s read %-10s read_full %-10s status=%d"
			% [i + 1, _ms(t_w), _ms(t_r), _ms(t_f), res.status])
	return "I-IO-REACHED-END"
