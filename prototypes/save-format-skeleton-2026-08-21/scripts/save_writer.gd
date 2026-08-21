class_name SaveWriter
extends RefCounted
# ============================================================================
# (c) 類發現:設計規格的「要實作的東西」只列了 SaveFormat / SaveBlockRegistry /
# SaveReader,沒有任何寫入側的組裝者。但組裝這件事是實質工作:
# 決定正規順序、算雙層雜湊鏈、組信封。ADR-0003 把它畫在示意圖裡而沒有給類別,
# ADR-0004 管的是「原子置換」(把 buffer 換到磁碟上),不是「怎麼組出 buffer」。
# 這個空隙必須有人填,本骨架自行補上 SaveWriter。
# ============================================================================

enum WriteStatus { OK, INPUT_INVALID, BLOCK_REJECTED, HASH_FAILED, ENVELOPE_REJECTED }

class WriteResult extends RefCounted:
	var buffer: PackedByteArray = PackedByteArray()
	var status: WriteStatus = WriteStatus.OK
	var stopped_at: String = ""
	var offending_source_id: String = ""
	# 刻意不型別化為 SaveFormat.PayloadRejection:
	# 「內部類別的欄位參照另一個 class_name 的 enum」這個形狀未查證,
	# 而編譯失敗會炸掉整個 save_writer.gd。該形狀由 x4 隔離檔單獨量。
	var rejection: int = 0
	var offending_path: String = ""
	var block_hashes: Dictionary = {}
	func ok() -> bool:
		return status == WriteStatus.OK

# blocks_in: Array[Dictionary],每項 {source_id, format_version, payload, migration_completion_marker}
# (c) 決定:輸入用 Array 而不是 Dictionary{source_id: ...}。
# 理由:組裝階段不該依賴 Dictionary 迭代順序;正規順序由 canonical_block_order 明確產生。
func build(ruleset_version: int, blocks_in: Array) -> WriteResult:
	var res := WriteResult.new()
	var manifest: Array = []
	var blocks: Dictionary = {}
	var seen: Dictionary = {}

	for item in blocks_in:
		if typeof(item) != TYPE_DICTIONARY:
			res.status = WriteStatus.INPUT_INVALID
			res.stopped_at = "W1_INPUT_SHAPE"
			return res
		var d: Dictionary = item
		for k in ["source_id", "format_version", "payload"]:
			if not d.has(k):
				res.status = WriteStatus.INPUT_INVALID
				res.stopped_at = "W1_INPUT_SHAPE(缺 %s)" % k
				return res
		var sid: String = d["source_id"]
		if seen.has(sid):
			# 重複 source_id 會讓「正規順序」這個概念本身失效(兩個條目排序相等)
			res.status = WriteStatus.INPUT_INVALID
			res.stopped_at = "W1_INPUT_SHAPE(重複 source_id %s)" % sid
			return res
		seen[sid] = true

		var payload: Dictionary = d["payload"]
		var ser: SaveFormat.SerializeResult = SaveFormat.serialize_block(payload)
		if not ser.ok():
			res.status = WriteStatus.BLOCK_REJECTED
			res.stopped_at = "W2_BLOCK_TYPE_GATE"
			res.offending_source_id = sid
			res.rejection = ser.rejection
			res.offending_path = ser.offending_path
			return res

		# 操作原子性:雜湊的輸入緩衝區與放進 blocks[] 的「是同一份」
		var buf: PackedByteArray = ser.buffer
		var bh: PackedByteArray = SaveFormat.compute_block_hash(buf)
		if bh.size() != SaveFormat.HASH_LEN:
			res.status = WriteStatus.HASH_FAILED
			res.stopped_at = "W3_BLOCK_HASH"
			res.offending_source_id = sid
			return res
		blocks[sid] = buf
		res.block_hashes[sid] = bh
		manifest.append({
			"source_id": sid,
			"format_version": int(d["format_version"]),
			"block_hash": bh,
			"migration_completion_marker": d.get("migration_completion_marker", null),
		})

	var ordered: Array = SaveFormat.canonical_block_order(manifest)
	var top: PackedByteArray = SaveFormat.compute_top_level_hash(ruleset_version, ordered)
	if top.size() != SaveFormat.HASH_LEN:
		res.status = WriteStatus.HASH_FAILED
		res.stopped_at = "W4_TOP_LEVEL_HASH"
		return res

	var envelope: Dictionary = {
		"ruleset_version": ruleset_version,
		"block_manifest": ordered,
		"top_level_hash": top,
		"blocks": blocks,
	}
	var env_ser: SaveFormat.SerializeResult = SaveFormat.serialize_manifest(envelope)
	if not env_ser.ok():
		res.status = WriteStatus.ENVELOPE_REJECTED
		res.stopped_at = "W5_ENVELOPE_TYPE_GATE"
		res.rejection = env_ser.rejection
		res.offending_path = env_ser.offending_path
		return res
	res.buffer = env_ser.buffer
	return res
