class_name SaveFormat
extends RefCounted
# ============================================================================
# 存檔格式:純靜態工具集(設計骨架,拋棄式)
# ============================================================================
# 實作依據 = 委派任務的「設計規格」節,不是 ADR-0003 現行檔案
# (該檔 18 處呼叫形狀為 Godot 3 簽章,4.7.1 不編譯)。
#
# 已實測確立、本檔直接依賴的引擎事實:
#   * 只有 var_to_bytes(v) / bytes_to_var(b) 兩個 1 引數形狀(無 allow_objects)
#   * 合法編碼最短 4 bytes,永不為 0 -> size 0 是可靠失敗訊號
#   * 全零位元組是合法 NIL 編碼 -> 成功判定一律用 `is Dictionary`,絕不用 != null
#   * var_to_bytes() 寫入側「不」拒絕 Object(靜默編成 EncodedObjectAsID),
#     Signal/RID/Callable 更是完全不經過解碼側閘門 -> 型別閘門必須自己寫,兩側都要
#   * TYPE_MAX == 39(0..38)
# ============================================================================

# ---------------------------------------------------------------- 常數 / enum

const MAX_PAYLOAD_DEPTH: int = 64

enum PayloadRejection { NONE, FORBIDDEN_TYPE, DEPTH_EXCEEDED }
enum DecodeRejection { NONE, DATA_CORRUPTED }

# 白名單:逐一列名 0..22 與 27..38(35 項)。判準一律是「ALLOWED_TYPES.has()」,
# 絕不寫成「拒絕集合的 or 鏈」-- 後者是黑名單,新型別會預設通過。
const ALLOWED_TYPES: Dictionary = {
	TYPE_NIL: true, TYPE_BOOL: true, TYPE_INT: true, TYPE_FLOAT: true,
	TYPE_STRING: true,
	TYPE_VECTOR2: true, TYPE_VECTOR2I: true, TYPE_RECT2: true, TYPE_RECT2I: true,
	TYPE_VECTOR3: true, TYPE_VECTOR3I: true, TYPE_TRANSFORM2D: true,
	TYPE_VECTOR4: true, TYPE_VECTOR4I: true, TYPE_PLANE: true, TYPE_QUATERNION: true,
	TYPE_AABB: true, TYPE_BASIS: true, TYPE_TRANSFORM3D: true, TYPE_PROJECTION: true,
	TYPE_COLOR: true, TYPE_STRING_NAME: true, TYPE_NODE_PATH: true,
	TYPE_DICTIONARY: true, TYPE_ARRAY: true,
	TYPE_PACKED_BYTE_ARRAY: true, TYPE_PACKED_INT32_ARRAY: true,
	TYPE_PACKED_INT64_ARRAY: true, TYPE_PACKED_FLOAT32_ARRAY: true,
	TYPE_PACKED_FLOAT64_ARRAY: true, TYPE_PACKED_STRING_ARRAY: true,
	TYPE_PACKED_VECTOR2_ARRAY: true, TYPE_PACKED_VECTOR3_ARRAY: true,
	TYPE_PACKED_COLOR_ARRAY: true, TYPE_PACKED_VECTOR4_ARRAY: true,
}

# 4 項:三者(RID/CALLABLE/SIGNAL)完全不經過解碼側閘門,OBJECT 在寫入側靜默通過。
const REJECTED_TYPES: Dictionary = {
	TYPE_RID: true, TYPE_OBJECT: true, TYPE_CALLABLE: true, TYPE_SIGNAL: true,
}

# 鍵位置額外收緊。容器當鍵一律直接拒絕,不遞迴進去。
const ALLOWED_KEY_TYPES: Dictionary = {
	TYPE_STRING: true, TYPE_STRING_NAME: true, TYPE_INT: true,
}

const HASH_LEN: int = 32

# ---------------------------------------------------------------- 結果物件

class SerializeResult extends RefCounted:
	var buffer: PackedByteArray = PackedByteArray()
	var rejection: PayloadRejection = PayloadRejection.NONE
	var offending_path: String = ""
	func ok() -> bool:
		return rejection == PayloadRejection.NONE

class DeserializeResult extends RefCounted:
	var payload: Dictionary = {}
	var rejection: DecodeRejection = DecodeRejection.NONE
	# detail 不是拒絕碼,只是診斷字串 -- 規格明訂「失敗一律 DATA_CORRUPTED,不新增拒絕碼」
	var detail: String = ""
	var offending_path: String = ""
	func ok() -> bool:
		return rejection == DecodeRejection.NONE

class TypeGateResult extends RefCounted:
	var rejection: PayloadRejection = PayloadRejection.NONE
	var path: String = ""

# ---------------------------------------------------------------- 解碼計次器
# 驗證 D 要求「用計數器證明 manifest-only 真的沒解碼區塊」。
# 本檔是全骨架唯一呼叫 bytes_to_var() 的地方,計次才有意義。

static var _decode_calls: int = 0

static func decode_calls() -> int:
	return _decode_calls

static func reset_decode_calls() -> void:
	_decode_calls = 0

static func _decode(buffer: PackedByteArray) -> Variant:
	_decode_calls += 1
	return bytes_to_var(buffer)

# ---------------------------------------------------------------- 載入期完整性斷言

# 規格逐字要求的那一條:允許集合.size() + 拒絕集合.size() == TYPE_MAX
static func verify_type_table_spec_rule(allowed: Dictionary, rejected: Dictionary) -> bool:
	return allowed.size() + rejected.size() == TYPE_MAX

# 較強的一條:逐 id 覆蓋 + 無交集 + 無越界。回傳 "" 代表通過。
static func verify_type_table_strict(allowed: Dictionary, rejected: Dictionary) -> String:
	for t in range(TYPE_MAX):
		var a: bool = allowed.has(t)
		var r: bool = rejected.has(t)
		if a and r:
			return "typeof=%d 同時在允許與拒絕集合中(交集)" % t
		if not a and not r:
			return "typeof=%d 兩個集合都沒列到(新型別會落在無人管的縫裡)" % t
	for k in allowed:
		if typeof(k) != TYPE_INT or int(k) < 0 or int(k) >= TYPE_MAX:
			return "允許集合含越界鍵 %s" % str(k)
	for k in rejected:
		if typeof(k) != TYPE_INT or int(k) < 0 or int(k) >= TYPE_MAX:
			return "拒絕集合含越界鍵 %s" % str(k)
	return ""

static func self_check() -> bool:
	var spec_ok: bool = verify_type_table_spec_rule(ALLOWED_TYPES, REJECTED_TYPES)
	var strict: String = verify_type_table_strict(ALLOWED_TYPES, REJECTED_TYPES)
	if not spec_ok:
		push_error("SaveFormat.self_check FAILED (spec rule): %d + %d != TYPE_MAX(%d)"
			% [ALLOWED_TYPES.size(), REJECTED_TYPES.size(), TYPE_MAX])
	if strict != "":
		push_error("SaveFormat.self_check FAILED (strict): %s" % strict)
	return spec_ok and strict == ""

# ---------------------------------------------------------------- 型別閘門

# 規格逐字的公開簽章。遷移鏈路徑重用這一個。
# 注意:此簽章「無法」帶出 offending_path -- 見 README (c) 類發現。
static func validate_payload_types(payload: Variant, depth: int = 0) -> PayloadRejection:
	return _walk(payload, depth, "payload").rejection

static func validate_payload_types_detailed(payload: Variant, depth: int = 0,
		path: String = "payload") -> TypeGateResult:
	return _walk(payload, depth, path)

static func _key_repr(k: Variant) -> String:
	# 只在鍵已通過 ALLOWED_KEY_TYPES 之後呼叫 -> 只會是 String/StringName/int
	if typeof(k) == TYPE_INT:
		return str(k)
	return "\"%s\"" % str(k)

static func _walk(v: Variant, depth: int, path: String) -> TypeGateResult:
	var r := TypeGateResult.new()
	# 深度上限先於一切 -- 它同時是巢狀上限與「循環引用」的唯一防線。
	# 絕不靠堆疊溢位當防線。
	if depth > MAX_PAYLOAD_DEPTH:
		r.rejection = PayloadRejection.DEPTH_EXCEEDED
		r.path = "%s <depth %d > MAX %d>" % [path, depth, MAX_PAYLOAD_DEPTH]
		return r
	var t: int = typeof(v)
	if not ALLOWED_TYPES.has(t):
		r.rejection = PayloadRejection.FORBIDDEN_TYPE
		r.path = "%s <typeof=%d>" % [path, t]
		return r
	if t == TYPE_DICTIONARY:
		var d: Dictionary = v
		for k in d:
			var kt: int = typeof(k)
			if not ALLOWED_KEY_TYPES.has(kt):
				r.rejection = PayloadRejection.FORBIDDEN_TYPE
				r.path = "%s.<KEY typeof=%d>" % [path, kt]
				return r
			var sub: TypeGateResult = _walk(d[k], depth + 1, "%s[%s]" % [path, _key_repr(k)])
			if sub.rejection != PayloadRejection.NONE:
				return sub
	elif t == TYPE_ARRAY:
		var a: Array = v
		for i in a.size():
			var sub: TypeGateResult = _walk(a[i], depth + 1, "%s[%d]" % [path, i])
			if sub.rejection != PayloadRejection.NONE:
				return sub
	return r

# ---------------------------------------------------------------- 區塊序列化

static func serialize_block(payload: Dictionary) -> SerializeResult:
	return _serialize_gated(payload, "payload")

static func serialize_manifest(envelope: Dictionary) -> SerializeResult:
	# 外層信封也走同一組閘門(信封裡的 manifest 中繼資料也可能被上游餵毒)。
	# 具名函式的必要性見 README:ADR 示意圖有這個 var_to_bytes() 呼叫,
	# 但介面清單裡沒有對應函式。
	return _serialize_gated(envelope, "envelope")

static func _serialize_gated(d: Dictionary, root: String) -> SerializeResult:
	var res := SerializeResult.new()
	var gate: TypeGateResult = _walk(d, 0, root)
	if gate.rejection != PayloadRejection.NONE:
		res.rejection = gate.rejection
		res.offending_path = gate.path
		return res
	var buf: PackedByteArray = var_to_bytes(d)
	if buf.size() == 0:
		# 合法編碼永不為 0。已知唯一成因是循環引用(引擎印 Potential infinite recursion)。
		# 但閘門先跑,循環引用會先被 DEPTH_EXCEEDED 攔下 -> 這條路徑理論上不可達,
		# 骨架刻意保留並實測其可達性(見 README 的 C-循環)。
		res.rejection = PayloadRejection.DEPTH_EXCEEDED
		res.offending_path = "%s <var_to_bytes returned size 0>" % root
		return res
	res.buffer = buf
	return res

static func deserialize_block(buffer: PackedByteArray) -> DeserializeResult:
	return _deserialize_gated(buffer, "payload")

static func deserialize_manifest(buffer: PackedByteArray) -> DeserializeResult:
	return _deserialize_gated(buffer, "envelope")

static func _deserialize_gated(buffer: PackedByteArray, root: String) -> DeserializeResult:
	var res := DeserializeResult.new()
	if buffer.size() == 0:
		res.rejection = DecodeRejection.DATA_CORRUPTED
		res.detail = "empty buffer"
		return res
	var decoded: Variant = _decode(buffer)
	# 成功判定一律 `is Dictionary`。絕不用 != null:全零位元組是合法 NIL 編碼。
	if not (decoded is Dictionary):
		res.rejection = DecodeRejection.DATA_CORRUPTED
		res.detail = "decoded typeof=%d, not a Dictionary" % typeof(decoded)
		return res
	# 對稱閘門:舊版有瑕疵的建置可能已把 EncodedObjectAsID / Signal / RID 寫進檔案,
	# 而這三者在解碼側完全不觸發引擎的拒絕。
	var gate: TypeGateResult = _walk(decoded, 0, root)
	if gate.rejection != PayloadRejection.NONE:
		res.rejection = DecodeRejection.DATA_CORRUPTED
		res.detail = "type gate rejected on READ side (rejection=%d)" % gate.rejection
		res.offending_path = gate.path
		return res
	res.payload = decoded
	return res

# ---------------------------------------------------------------- 雜湊

static func _sha256_of_chunks(chunks: Array) -> PackedByteArray:
	# 每一次雜湊各自 HashingContext.new() -- 已實測:已餵資料後再 start()
	# 回傳 ERR_ALREADY_IN_USE(22) 且「不重置」,續餵會得到「前一段+本段」的雜湊,
	# 而長度仍然是正確的 32 bytes(= 長度斷言抓不到這種污染)。
	var ctx := HashingContext.new()
	var err: int = ctx.start(HashingContext.HASH_SHA256)
	if err != OK:
		push_error("HashingContext.start failed: %s" % error_string(err))
		return PackedByteArray()
	for c in chunks:
		var chunk: PackedByteArray = c
		if chunk.size() == 0:
			continue  # 零長度分段:跳過,不是錯誤(update(空陣列) 已實測回 FAILED(1))
		var e2: int = ctx.update(chunk)
		if e2 != OK:
			push_error("HashingContext.update failed: %s" % error_string(e2))
			return PackedByteArray()
	var digest: PackedByteArray = ctx.finish()
	if digest.size() != HASH_LEN:
		push_error("HashingContext.finish gave %d bytes, expected %d" % [digest.size(), HASH_LEN])
		return PackedByteArray()
	return digest

static func compute_block_hash(buffer: PackedByteArray) -> PackedByteArray:
	return _sha256_of_chunks([buffer])

static func compute_top_level_hash(ruleset_version: int, block_manifest: Array) -> PackedByteArray:
	var ordered: Array = canonical_block_order(block_manifest)
	if ordered.size() != block_manifest.size():
		# canonical_block_order 已 push_error;此處不得繼續,否則會算出一個
		# 「長度正確但輸入不完整」的雜湊。
		return PackedByteArray()
	var chunks: Array = [var_to_bytes(ruleset_version)]
	for e in ordered:
		var entry: Dictionary = e
		# 明確順序的 Array tuple,不是把 Dictionary 直接餵進去 --
		# 已實測 var_to_bytes(Dictionary) 的位元組隨鍵插入順序改變(見 X-3)。
		var tuple: Array = [
			entry.get("source_id", null),
			entry.get("format_version", null),
			entry.get("block_hash", null),
			entry.get("migration_completion_marker", null),
		]
		chunks.append(var_to_bytes(tuple))
	return _sha256_of_chunks(chunks)

static func hash_matches(a: PackedByteArray, b: PackedByteArray) -> bool:
	# 絕不直接寫 a == b:雜湊失敗時 _sha256_of_chunks 回傳空陣列,
	# 兩邊都失敗時 empty == empty 為 true -> 會變成「雜湊通過」。
	if a.size() != HASH_LEN or b.size() != HASH_LEN:
		return false
	return a == b

# ---------------------------------------------------------------- 正規順序

static func canonical_block_order(block_manifest: Array) -> Array:
	# 依 source_id 字典序。不依賴容器迭代順序,也不改動呼叫端傳進來的陣列。
	# 手工插入排序:刻意不用 sort_custom + lambda(靜態情境下的 lambda 行為未查證,
	# 而編譯失敗會炸掉整個 save_format.gd)。插入排序在此天然穩定。
	var out: Array = []
	for e in block_manifest:
		if typeof(e) != TYPE_DICTIONARY:
			push_error("canonical_block_order: manifest 條目不是 Dictionary(typeof=%d)" % typeof(e))
			return []
		var d: Dictionary = e
		if not d.has("source_id") or typeof(d["source_id"]) != TYPE_STRING:
			push_error("canonical_block_order: manifest 條目缺少 String 的 source_id")
			return []
		var sid: String = d["source_id"]
		var pos: int = out.size()
		for i in out.size():
			var other: Dictionary = out[i]
			if sid < String(other["source_id"]):
				pos = i
				break
		out.insert(pos, d)
	return out
