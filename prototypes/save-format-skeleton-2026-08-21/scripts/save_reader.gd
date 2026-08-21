class_name SaveReader
extends RefCounted
# ============================================================================
# 讀取路徑,依規格鎖定順序:
#   (1) 外層解碼   (1b) 信封欄位形狀   (2) 頂層雜湊   (3) 版本比對
#   (4) 逐區塊雜湊(對尚未解碼的位元組)   (5) 區塊解碼+型別閘門   (6) 語意驗證器
#
# 步驟 1b 不在設計規格裡 —— 它是實作時發現非做不可的一關,見 README (c) 類發現:
# 步驟 2 必須先「讀出」ruleset_version 與 block_manifest 才能重算頂層雜湊,
# 也就是說在雜湊驗證通過之前,就已經必須信任這些欄位的形狀。
# 而缺鍵 subscript 讀取已實測會中止呼叫函式 -> 沒有 1b 的話,一份把
# block_manifest 寫成 int 的損毀檔案不會回 DATA_CORRUPTED,而是讓讀取函式從中間斷掉。
# ============================================================================

enum ReadStatus { OK, DATA_CORRUPTED, VERSION_TOO_NEW, SEMANTIC_INVALID }

const S1_ENVELOPE_DECODE: String = "S1_ENVELOPE_DECODE(外層解碼+型別閘門)"
const S1B_MANIFEST_SHAPE: String = "S1B_MANIFEST_SHAPE(信封欄位形狀)"
const S2_TOP_LEVEL_HASH: String = "S2_TOP_LEVEL_HASH(頂層雜湊)"
const S3_VERSION_COMPARE: String = "S3_VERSION_COMPARE(規則集版本)"
const S4_BLOCK_HASH: String = "S4_BLOCK_HASH(逐區塊雜湊/未解碼位元組)"
const S5_BLOCK_DECODE: String = "S5_BLOCK_DECODE_TYPE_GATE(區塊解碼+型別閘門)"
const S6_VALIDATOR: String = "S6_VALIDATOR(語意驗證器)"

const ENVELOPE_KEYS: Array = ["ruleset_version", "block_manifest", "top_level_hash", "blocks"]
const MANIFEST_ENTRY_KEYS: Array = ["source_id", "format_version", "block_hash",
	"migration_completion_marker"]

class ReadResult extends RefCounted:
	var status: ReadStatus = ReadStatus.OK
	var stopped_at: String = ""
	var detail: String = ""
	var ruleset_version: int = -1
	var manifest: Array = []
	var payloads: Dictionary = {}
	var blocks_decoded: int = 0
	func ok() -> bool:
		return status == ReadStatus.OK

var _registry: SaveBlockRegistry

func _init(registry: SaveBlockRegistry) -> void:
	_registry = registry

func read_manifest_only(buffer: PackedByteArray, game_ruleset_version: int) -> ReadResult:
	return _read(buffer, game_ruleset_version, true)

func read_full(buffer: PackedByteArray, game_ruleset_version: int) -> ReadResult:
	return _read(buffer, game_ruleset_version, false)

func _fail(res: ReadResult, status: ReadStatus, stage: String, detail: String) -> ReadResult:
	res.status = status
	res.stopped_at = stage
	res.detail = detail
	return res

func _read(buffer: PackedByteArray, game_ruleset_version: int, manifest_only: bool) -> ReadResult:
	var res := ReadResult.new()

	# --- (1) 外層解碼 -------------------------------------------------------
	var outer = SaveFormat.deserialize_manifest(buffer)
	if not outer.ok():
		return _fail(res, ReadStatus.DATA_CORRUPTED, S1_ENVELOPE_DECODE,
			"%s %s" % [outer.detail, outer.offending_path])
	var env: Dictionary = outer.payload

	# --- (1b) 信封欄位形狀 --------------------------------------------------
	var shape: String = _validate_envelope_shape(env)
	if shape != "":
		return _fail(res, ReadStatus.DATA_CORRUPTED, S1B_MANIFEST_SHAPE, shape)
	res.ruleset_version = env["ruleset_version"]
	res.manifest = env["block_manifest"]

	# --- (2) 頂層雜湊 -------------------------------------------------------
	var recomputed: PackedByteArray = SaveFormat.compute_top_level_hash(
		res.ruleset_version, res.manifest)
	if not SaveFormat.hash_matches(recomputed, env["top_level_hash"]):
		return _fail(res, ReadStatus.DATA_CORRUPTED, S2_TOP_LEVEL_HASH,
			"recomputed=%s stored=%s" % [recomputed.hex_encode().substr(0, 16),
				(env["top_level_hash"] as PackedByteArray).hex_encode().substr(0, 16)])

	# --- (3) 版本比對 -------------------------------------------------------
	if res.ruleset_version > game_ruleset_version:
		return _fail(res, ReadStatus.VERSION_TOO_NEW, S3_VERSION_COMPARE,
			"檔案 ruleset_version=%d > 遊戲 %d" % [res.ruleset_version, game_ruleset_version])

	if manifest_only:
		return res  # manifest-only 路徑到此為止,不碰 blocks

	# --- (4)(5)(6) 逐區塊 ---------------------------------------------------
	# (c) 決定:逐區塊「交錯」處理(A 的雜湊->解碼->驗證 全跑完才輪到 B),
	# 不是「先驗全部雜湊再解全部區塊」。規格沒講。副作用:B 損毀時 A 已經被
	# 解碼並驗證過了 —— 讀取不是跨區塊 all-or-nothing。呼叫端要自己決定要不要套用。
	var blocks: Dictionary = env["blocks"]
	for e in SaveFormat.canonical_block_order(res.manifest):
		var entry: Dictionary = e
		var sid: String = entry["source_id"]
		# blocks 的鍵集合「不」被任何雜湊涵蓋,也刻意不在 1b 交叉檢查
		# (那會讓「manifest 少一條」提前在 1b 被攔,而規格要求它由頂層雜湊攔)。
		if not blocks.has(sid):
			return _fail(res, ReadStatus.DATA_CORRUPTED, S4_BLOCK_HASH,
				"blocks 缺少 source_id '%s'(頂層雜湊涵蓋不到這件事)" % sid)
		if typeof(blocks[sid]) != TYPE_PACKED_BYTE_ARRAY:
			return _fail(res, ReadStatus.DATA_CORRUPTED, S4_BLOCK_HASH,
				"blocks['%s'] typeof=%d,不是 PackedByteArray" % [sid, typeof(blocks[sid])])
		var raw: PackedByteArray = blocks[sid]

		# (4) 對尚未解碼的位元組算雜湊
		var bh: PackedByteArray = SaveFormat.compute_block_hash(raw)
		if not SaveFormat.hash_matches(bh, entry["block_hash"]):
			return _fail(res, ReadStatus.DATA_CORRUPTED, S4_BLOCK_HASH,
				"'%s' 區塊雜湊不符 recomputed=%s stored=%s" % [sid,
					bh.hex_encode().substr(0, 16),
					(entry["block_hash"] as PackedByteArray).hex_encode().substr(0, 16)])

		# (5) 解碼 + 型別閘門
		var db = SaveFormat.deserialize_block(raw)
		if not db.ok():
			return _fail(res, ReadStatus.DATA_CORRUPTED, S5_BLOCK_DECODE,
				"'%s' %s %s" % [sid, db.detail, db.offending_path])
		res.blocks_decoded += 1

		# (6) 語意驗證器(fail-closed)
		var v: Variant = _registry.get_validator(sid)
		if typeof(v) != TYPE_CALLABLE:
			return _fail(res, ReadStatus.DATA_CORRUPTED, S6_VALIDATOR,
				"'%s' 沒有登記驗證器(fail-closed)" % sid)
		var cb: Callable = v
		if not cb.is_valid():
			# 登記時有效不代表現在有效 —— 目標物件可能已被釋放。
			# 已實測:呼叫失效 Callable 會中止呼叫函式,不是回傳錯誤。
			return _fail(res, ReadStatus.DATA_CORRUPTED, S6_VALIDATOR,
				"'%s' 的驗證器 Callable 已失效" % sid)
		var ir: Variant = cb.call(db.payload)
		if not (ir is SaveImportResult):
			return _fail(res, ReadStatus.DATA_CORRUPTED, S6_VALIDATOR,
				"'%s' 的驗證器回傳 typeof=%d,不是 SaveImportResult" % [sid, typeof(ir)])
		var import_result: SaveImportResult = ir
		if not import_result.ok:
			return _fail(res, ReadStatus.SEMANTIC_INVALID, S6_VALIDATOR,
				"'%s' 語意驗證失敗: %s" % [sid, import_result.first_error()])
		res.payloads[sid] = db.payload
	return res

func _validate_envelope_shape(env: Dictionary) -> String:
	for k in ENVELOPE_KEYS:
		if not env.has(k):
			return "信封缺少鍵 %s" % k
	if typeof(env["ruleset_version"]) != TYPE_INT:
		return "ruleset_version typeof=%d,應為 int" % typeof(env["ruleset_version"])
	if typeof(env["block_manifest"]) != TYPE_ARRAY:
		return "block_manifest typeof=%d,應為 Array" % typeof(env["block_manifest"])
	if typeof(env["top_level_hash"]) != TYPE_PACKED_BYTE_ARRAY:
		return "top_level_hash typeof=%d,應為 PackedByteArray" % typeof(env["top_level_hash"])
	if (env["top_level_hash"] as PackedByteArray).size() != SaveFormat.HASH_LEN:
		return "top_level_hash 長度 %d,應為 %d" % [
			(env["top_level_hash"] as PackedByteArray).size(), SaveFormat.HASH_LEN]
	if typeof(env["blocks"]) != TYPE_DICTIONARY:
		return "blocks typeof=%d,應為 Dictionary" % typeof(env["blocks"])
	var seen: Dictionary = {}
	var manifest: Array = env["block_manifest"]
	for i in manifest.size():
		if typeof(manifest[i]) != TYPE_DICTIONARY:
			return "block_manifest[%d] typeof=%d,應為 Dictionary" % [i, typeof(manifest[i])]
		var d: Dictionary = manifest[i]
		for k in MANIFEST_ENTRY_KEYS:
			if not d.has(k):
				return "block_manifest[%d] 缺少鍵 %s" % [i, k]
		if typeof(d["source_id"]) != TYPE_STRING:
			return "block_manifest[%d].source_id typeof=%d" % [i, typeof(d["source_id"])]
		if typeof(d["format_version"]) != TYPE_INT:
			return "block_manifest[%d].format_version typeof=%d" % [i, typeof(d["format_version"])]
		if typeof(d["block_hash"]) != TYPE_PACKED_BYTE_ARRAY:
			return "block_manifest[%d].block_hash typeof=%d" % [i, typeof(d["block_hash"])]
		if (d["block_hash"] as PackedByteArray).size() != SaveFormat.HASH_LEN:
			return "block_manifest[%d].block_hash 長度 %d" % [i,
				(d["block_hash"] as PackedByteArray).size()]
		var mt: int = typeof(d["migration_completion_marker"])
		if mt != TYPE_INT and mt != TYPE_NIL:
			return "block_manifest[%d].migration_completion_marker typeof=%d,應為 int 或 null" % [i, mt]
		var sid: String = d["source_id"]
		if seen.has(sid):
			# 重複 source_id 會讓「依 source_id 字典序」這個正規順序失去唯一性,
			# 頂層雜湊也就不再是輸入的函數。設計規格對此完全沒講。
			return "block_manifest 有重複的 source_id '%s'" % sid
		seen[sid] = true
	return ""
