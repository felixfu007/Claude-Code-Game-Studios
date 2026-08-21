# F2-e —— 非 Object 的壞位元組。ADR-0003 機制三第 4 步先驗雜湊,但仍需知道
# 這條路徑的失敗模式(回傳 null / 回傳垃圾 / 中止)。
# 決定性:所有「隨機」位元組一律用固定樣式產生,不使用任何 RNG。
extends RefCounted

static func _report(label: String, b: PackedByteArray) -> void:
	print("      [S1] BEFORE bytes_to_var  <%s>  size=%d hex=%s" % [label, b.size(), b.hex_encode()])
	var r = bytes_to_var(b)
	print("      [S2] AFTER  <%s>  typeof=%d is_null=%s value=[%s]" % [label, typeof(r), str(r == null), str(r)])

static func t_empty() -> String:
	_report("empty PackedByteArray", PackedByteArray())
	return "S3-F2e-empty-REACHED-END"

static func t_truncated_half() -> String:
	var full: PackedByteArray = var_to_bytes({"alpha": 1, "beta": "two", "gamma": 3.5})
	_report("truncated to half", full.slice(0, full.size() / 2))
	return "S3-F2e-trunc-half-REACHED-END"

static func t_truncated_header_only() -> String:
	var full: PackedByteArray = var_to_bytes({"alpha": 1, "beta": "two"})
	_report("truncated to first 4 bytes (type header only)", full.slice(0, 4))
	return "S3-F2e-trunc-hdr-REACHED-END"

static func t_garbage_fixed_pattern() -> String:
	# 固定樣式,非 RNG:0xDE 0xAD 0xBE 0xEF 重複 16 次 = 64 bytes
	var b := PackedByteArray()
	for i in range(16):
		b.append_array(PackedByteArray([0xDE, 0xAD, 0xBE, 0xEF]))
	_report("64 bytes of fixed 0xDEADBEEF pattern", b)
	return "S3-F2e-garbage-REACHED-END"

static func t_valid_header_bogus_length() -> String:
	# type=28 (PackedByteArray) 之後宣告一個超大長度,但後面沒有資料
	var b := PackedByteArray([29, 0, 0, 0,  0xFF, 0xFF, 0xFF, 0x7F])
	_report("valid-ish type header + bogus huge length, no payload", b)
	return "S3-F2e-bogus-len-REACHED-END"

static func t_all_zero() -> String:
	var b := PackedByteArray()
	b.resize(16)
	_report("16 zero bytes (type 0 = NIL?)", b)
	return "S3-F2e-zeros-REACHED-END"
