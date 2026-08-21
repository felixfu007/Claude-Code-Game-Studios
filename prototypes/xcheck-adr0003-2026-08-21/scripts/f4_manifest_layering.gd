# ============================================================================
# F4' —— manifest 分層的關鍵前提(ADR-0003 機制二,第 88-97 行)
# ============================================================================
# ADR 主張:外層解碼「一次」bytes_to_var 即得到「尚未解碼的」blocks 字典
# (PackedByteArray 本身是原生型別,取得它不等於解讀它的內容),manifest-only
# 路徑到此為止。整條 TR-save-012 雙路徑押在這個不遞迴的性質上。
extends RefCounted

# ---- F4'-a:外層解碼不遞迴進區塊 ----
static func t_a_no_recursion() -> String:
	var inner_payload: Dictionary = {
		"records": [{"m": 1.5, "t": 10}, {"m": -0.25, "t": 11}],
		"format_version": 2,
	}
	var inner_buf: PackedByteArray = var_to_bytes(inner_payload)
	var outer: Dictionary = {
		"ruleset_version": 3,
		"blocks": {"affinity_data_pool": inner_buf},
	}
	var outer_buf: PackedByteArray = var_to_bytes(outer)
	print("      inner_buf.size()=%d   outer_buf.size()=%d" % [inner_buf.size(), outer_buf.size()])
	print("      [S1] BEFORE outer bytes_to_var")
	var dec = bytes_to_var(outer_buf)
	print("      [S2] AFTER  outer bytes_to_var typeof=%d" % typeof(dec))
	if not (dec is Dictionary):
		print("      [S2!] 外層解碼未得到 Dictionary,後續判定不成立")
		return "S3-F4a-REACHED-END(outer-not-dict)"
	var d: Dictionary = dec
	print("      outer keys = %s   ruleset_version=%s" % [str(d.keys()), str(d["ruleset_version"])])
	var blk = d["blocks"]["affinity_data_pool"]
	print("      blocks['affinity_data_pool'] typeof=%d (29 = TYPE_PACKED_BYTE_ARRAY)" % typeof(blk))
	print("      is PackedByteArray = %s" % str(blk is PackedByteArray))
	print("      size: got=%d expected=%d   equal_size=%s" % [(blk as PackedByteArray).size(), inner_buf.size(), str((blk as PackedByteArray).size() == inner_buf.size())])
	print("      byte-for-byte '==' vs inner_buf : %s" % str(blk == inner_buf))
	print("      hex identical                   : %s" % str((blk as PackedByteArray).hex_encode() == inner_buf.hex_encode()))
	var inner_again = bytes_to_var(blk)
	print("      second-stage decode typeof=%d  equals original payload = %s" % [typeof(inner_again), str(inner_again == inner_payload)])
	return "S3-F4a-REACHED-END"

# ---- F4'-b:殺手鐧 —— 含 Object 的區塊塞進外層,外層還解得開嗎 ----
static func t_b_poison_block() -> String:
	var poison_buf: PackedByteArray = var_to_bytes_with_objects({"legit": 1, "obj": RefCounted.new()})
	var good_buf: PackedByteArray = var_to_bytes({"k": 42})
	var outer: Dictionary = {
		"ruleset_version": 3,
		"block_manifest": [{"source_id": "bad"}, {"source_id": "good"}],
		"blocks": {"bad": poison_buf, "good": good_buf},
	}
	var outer_buf: PackedByteArray = var_to_bytes(outer)
	print("      poison_buf.size()=%d  good_buf.size()=%d  outer_buf.size()=%d" % [poison_buf.size(), good_buf.size(), outer_buf.size()])
	print("      [S1] BEFORE outer bytes_to_var (外層本身只含 PackedByteArray,無 Object)")
	var dec = bytes_to_var(outer_buf)
	print("      [S2] AFTER  outer bytes_to_var typeof=%d is_null=%s" % [typeof(dec), str(dec == null)])
	if not (dec is Dictionary):
		print("      [S2!] *** 外層解碼失敗 *** -> ADR-0003 機制二 manifest-only 安全前提不成立")
		return "S3-F4b-REACHED-END(outer-failed)"
	var d: Dictionary = dec
	print("      *** 外層解碼成功 *** manifest 可讀:ruleset_version=%s block_manifest=%s" % [str(d["ruleset_version"]), str(d["block_manifest"])])
	print("      blocks['good'] typeof=%d  blocks['bad'] typeof=%d" % [typeof(d["blocks"]["good"]), typeof(d["blocks"]["bad"])])
	print("      [S3] 對好區塊二次解碼:")
	var g = bytes_to_var(d["blocks"]["good"])
	print("            typeof=%d value=%s" % [typeof(g), str(g)])
	print("      [S4] 對壞區塊二次解碼(應與 F2-a 同行為):")
	var bb = bytes_to_var(d["blocks"]["bad"])
	print("            typeof=%d is_null=%s value=[%s]" % [typeof(bb), str(bb == null), str(bb)])
	return "S5-F4b-REACHED-END"

# ---- 額外:外層若「直接」巢狀 Object(即 Alternative 3 的扁平化寫法)做對照 ----
static func t_b2_flat_contrast() -> String:
	var outer: Dictionary = {
		"ruleset_version": 3,
		"blocks": {"bad": {"legit": 1, "obj": RefCounted.new()}},
	}
	var outer_buf: PackedByteArray = var_to_bytes_with_objects(outer)
	print("      [S1] BEFORE (扁平巢狀,無 PackedByteArray 分層) size=%d" % outer_buf.size())
	var dec = bytes_to_var(outer_buf)
	print("      [S2] AFTER  typeof=%d is_null=%s value=[%s]" % [typeof(dec), str(dec == null), str(dec)])
	print("      判讀:此為 ADR-0003 Alternative 3(被拒的扁平方案)的失敗模式對照組。")
	return "S3-F4b2-REACHED-END"
