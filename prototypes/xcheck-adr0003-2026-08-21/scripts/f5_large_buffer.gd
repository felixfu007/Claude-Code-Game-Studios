# F5 —— 大緩衝區的往返耗時與 SHA-256 耗時。
# ADR-0003 VR#5 / Risks 表第 3 列。目標不是逼近 2GB 上限(會 OOM),
# 只是確認本專案估計規模(單槽數十 KB;Delta Log 累積後可能數 MB)不存在效能懸崖。
extends RefCounted

static func _sha256(buf: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(buf)
	return ctx.finish()

static func t_raw_buffer(mb: int) -> String:
	var n: int = mb * 1024 * 1024
	var raw := PackedByteArray()
	raw.resize(n)
	# 打一些非零值進去(固定樣式,非 RNG),避免全零被任何特化路徑優待
	for i in range(0, n, 65536):
		raw[i] = (i / 65536) % 251
	var payload: Dictionary = {"blob": raw, "note": "f5"}

	var t0 := Time.get_ticks_msec()
	var enc: PackedByteArray = var_to_bytes(payload)
	var t1 := Time.get_ticks_msec()
	var dec = bytes_to_var(enc)
	var t2 := Time.get_ticks_msec()
	var h := _sha256(enc)
	var t3 := Time.get_ticks_msec()

	var ok: bool = (dec is Dictionary) and ((dec as Dictionary)["blob"] == raw)
	print("      [%d MB raw PackedByteArray in a Dictionary]" % mb)
	print("        var_to_bytes  : %6d ms   (encoded size = %d bytes)" % [t1 - t0, enc.size()])
	print("        bytes_to_var  : %6d ms   round-trip byte-identical = %s" % [t2 - t1, str(ok)])
	print("        SHA-256       : %6d ms   digest = %s" % [t3 - t2, h.hex_encode()])
	return "F5-raw-%dMB-REACHED-END" % mb

static func t_many_records(n: int) -> String:
	var tb0 := Time.get_ticks_msec()
	var records: Array = []
	records.resize(n)
	for i in range(n):
		records[i] = {"t": i, "m": float(i) * 0.001, "s": "C1_C2"}
	var payload: Dictionary = {"delta_log": records, "format_version": 1}
	var tb1 := Time.get_ticks_msec()

	var t0 := Time.get_ticks_msec()
	var enc: PackedByteArray = var_to_bytes(payload)
	var t1 := Time.get_ticks_msec()
	var dec = bytes_to_var(enc)
	var t2 := Time.get_ticks_msec()
	var h := _sha256(enc)
	var t3 := Time.get_ticks_msec()

	var ok: bool = (dec is Dictionary) and ((dec as Dictionary)["delta_log"] as Array).size() == n
	var spot: bool = ok and ((dec as Dictionary)["delta_log"] as Array)[n - 1]["s"] == "C1_C2"
	print("      [%d records, each a 3-key Dictionary]" % n)
	print("        (build in GDScript) : %6d ms" % [tb1 - tb0])
	print("        var_to_bytes        : %6d ms   (encoded size = %d bytes = %.2f MB)" % [t1 - t0, enc.size(), float(enc.size()) / 1048576.0])
	print("        bytes_to_var        : %6d ms   size preserved=%s  last record spot-check=%s" % [t2 - t1, str(ok), str(spot)])
	print("        SHA-256             : %6d ms   digest = %s" % [t3 - t2, h.hex_encode()])
	return "F5-records-%d-REACHED-END" % n

static func t_realistic_slot() -> String:
	# GDD 自陳的實際規模:單槽數十 KB。作為對照基準。
	var records: Array = []
	for i in range(500):
		records.append({"t": i, "m": float(i) * 0.01, "s": "C1_C2", "src": "DIALOGUE"})
	var payload: Dictionary = {"delta_log": records, "format_version": 1}
	var t0 := Time.get_ticks_msec()
	var enc: PackedByteArray = var_to_bytes(payload)
	var t1 := Time.get_ticks_msec()
	var dec = bytes_to_var(enc)
	var t2 := Time.get_ticks_msec()
	var h := _sha256(enc)
	var t3 := Time.get_ticks_msec()
	print("      [realistic single slot: 500 records]")
	print("        encoded size = %d bytes (%.1f KB)" % [enc.size(), float(enc.size()) / 1024.0])
	print("        var_to_bytes %d ms / bytes_to_var %d ms / SHA-256 %d ms   ok=%s" % [t1 - t0, t2 - t1, t3 - t2, str(dec is Dictionary)])
	print("        digest = %s" % h.hex_encode())
	return "F5-realistic-REACHED-END"
