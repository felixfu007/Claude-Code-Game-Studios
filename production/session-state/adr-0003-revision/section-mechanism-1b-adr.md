# 機制一之二:序列化型別閘門(SaveTypeGate)

> 精簡版,供併入 ADR-0003。完整推導與逐證據引用見同目錄
> `section-mechanism-1b.md`(不刪減,留作紀錄)。引擎行為的量測敘述一律不重述於此,
> 只指到 `docs/engine-reference/godot/modules/core-serialization.md` 的節次。

## 為什麼需要獨立閘門

機制一「型別白名單問題結構性地不存在」只在**讀取側對 `Object`**成立。完整的二維
威脅模型(**證據**:`core-serialization.md` §2–4):

| 型別 | 寫入側 `var_to_bytes` | 讀取側 `bytes_to_var` |
|---|---|---|
| `Object`(24) | ❌ 靜默編成 `EncodedObjectAsID`,原欄位資料遺失,零錯誤 | ✅ 整包原子性失敗,`ERR_UNAUTHORIZED` |
| `RID`(23)/`Callable`(25)/`Signal`(26) | ❌ 不拒絕 | ❌ **也不拒絕** |

引擎在寫入側完全沒有安全網,讀取側只對 `Object` 一種型別有安全網。`SaveTypeGate`
是寫入/讀取兩側共用的獨立防線。**必須拒絕的型別恰為 4 個**:`RID`/`Object`/
`Callable`/`Signal`。`NodePath`(22)不拒絕(合法常用),但**消費端不得**直接把
存檔裡的 `NodePath` 餵給 `get_node()`——這是介面義務,型別閘門不強制此事,語意
驗證(機制六)才是負責處。

## `SaveTypeGate` 契約

```gdscript
# ─── save_type_gate.gd ──────────────────────────────────────────
class_name SaveTypeGate extends RefCounted

# 比較式為 depth > MAX_PAYLOAD_DEPTH,語意見下方「深度上限」。
const MAX_PAYLOAD_DEPTH: int = 64

# 35 項:0–22 + 27–38。白名單制,判準恆為 .has(t),絕不寫黑名單 or 鏈。
const ALLOWED_TYPES: Dictionary = {
	TYPE_NIL: true, TYPE_BOOL: true, TYPE_INT: true, TYPE_FLOAT: true, TYPE_STRING: true,
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

const REJECTED_TYPES: Dictionary = {
	TYPE_RID: true, TYPE_OBJECT: true, TYPE_CALLABLE: true, TYPE_SIGNAL: true,
}

# 容器一律直接拒絕當鍵、不遞迴進去看內容。
const ALLOWED_KEY_TYPES: Dictionary = {
	TYPE_STRING: true, TYPE_STRING_NAME: true, TYPE_INT: true,
}

enum GateRejection { NONE, FORBIDDEN_TYPE, DEPTH_EXCEEDED }

# 回傳結果物件而非 bool,安全前提見下方程式碼後的說明。
class GateResult extends RefCounted:
	var rejection: GateRejection = GateRejection.NONE
	var path: String = ""
	func ok() -> bool:
		return rejection == GateRejection.NONE

static func scan(payload: Variant) -> GateResult:
	return _walk(payload, 0, "payload")

# 讀取側 deserialize_manifest() 必須呼叫這個入口,掃整個信封,見下方「巢狀
# PackedByteArray 的界線」。
static func scan_envelope(envelope: Variant) -> GateResult:
	return _walk(envelope, 0, "envelope")

# 薄殼:只做深度檢查,除了 MAX_PAYLOAD_DEPTH 這個數字外沒有其他理由被觸碰。
static func _walk(value: Variant, depth: int, path: String) -> GateResult:
	if depth > MAX_PAYLOAD_DEPTH:
		var result := GateResult.new()
		result.rejection = GateRejection.DEPTH_EXCEEDED
		result.path = "%s <depth %d > MAX %d>" % [path, depth, MAX_PAYLOAD_DEPTH]
		return result
	return _walk_body(value, depth, path)

# 型別判斷 + 遞迴。**任何遞迴呼叫一律呼叫 _walk(),絕不可呼叫 _walk_body()**——
# 呼叫錯的後果是深度檢查對該分支完全失效,由下方「深度回歸測試」把關這條規則。
static func _walk_body(value: Variant, depth: int, path: String) -> GateResult:
	var result := GateResult.new()
	var t: int = typeof(value)
	if not ALLOWED_TYPES.has(t):
		result.rejection = GateRejection.FORBIDDEN_TYPE
		result.path = "%s <typeof=%d>" % [path, t]
		return result
	if t == TYPE_DICTIONARY:
		var d: Dictionary = value
		for key in d:
			if not ALLOWED_KEY_TYPES.has(typeof(key)):
				result.rejection = GateRejection.FORBIDDEN_TYPE
				result.path = "%s.<KEY typeof=%d>" % [path, typeof(key)]
				return result
			var sub: GateResult = _walk(d[key], depth + 1, "%s[%s]" % [path, str(key)])  # _walk,非 _walk_body
			if not sub.ok():
				return sub
	elif t == TYPE_ARRAY:
		var a: Array = value
		for i in a.size():
			var sub: GateResult = _walk(a[i], depth + 1, "%s[%d]" % [path, i])  # _walk,非 _walk_body
			if not sub.ok():
				return sub
	return result  # PACKED_BYTE_ARRAY 等葉節點型別在此結束,不遞迴進去看內容

# 完整性斷言:單純比數量對「漏一個允許型別+多一個拒絕型別」的成對抵銷完全瞎
# (實測見骨架驗證 E)。唯一可靠的是逐一檢查每個索引恰好落在其中一個集合。
static func verify_type_table_sum(allowed: Dictionary, rejected: Dictionary) -> bool:
	return allowed.size() + rejected.size() == TYPE_MAX  # 僅供對照,不得單獨作為判準

static func verify_type_table_partition(allowed: Dictionary, rejected: Dictionary) -> String:
	for t in range(TYPE_MAX):
		var is_allowed: bool = allowed.has(t)
		var is_rejected: bool = rejected.has(t)
		if is_allowed and is_rejected:
			return "typeof=%d 同時在兩集合中(交集)" % t
		if not is_allowed and not is_rejected:
			return "typeof=%d 兩集合都沒列到" % t
	return ""

static func self_check() -> bool:
	var ok: bool = verify_type_table_sum(ALLOWED_TYPES, REJECTED_TYPES)
	var err: String = verify_type_table_partition(ALLOWED_TYPES, REJECTED_TYPES)
	if not ok or err != "":
		push_error("SaveTypeGate.self_check FAILED: sum_ok=%s partition_err=%s" % [ok, err])
	return ok and err == ""
```

**回傳物件而非 bool 的安全前提**:深度檢查是 `_walk()` 執行的第一件事,先於任何
型別判斷、更先於任何遞迴。遞迴因此鎖在 65 層內,遠低於 GDScript 堆疊上限(推論值
約 1024 層,`core-serialization.md` §6)。**這是結構性排除,不是「風險被推遠」**
——`_walk()` 在第 65 次呼叫就直接返回,不會嘗試第 66 次;三條可能繞過此檢查的路徑
(Dictionary 的鍵不遞迴、容器當值是唯一遞迴路徑且 depth 恰好 +1、公開入口 depth
皆硬寫 0)經覆核逐一排除(security-engineer,2026-08-24)。若此前提被打破(深度
檢查移到遞迴之後),堆疊溢位會在 `null` 上取屬性,呼叫端無聲中止——這是給未來
維護者的顯性要求。為降低此前提被意外破壞的機率,`_walk()` 拆成薄殼(只做深度
檢查)+ `_walk_body()`(型別判斷與遞迴),薄殼極短、除了那個數字外沒有理由被
編輯到;殘餘風險是遞迴呼叫寫錯成 `_walk_body()`,由下方「深度回歸測試」把關。

**深度上限的精確語意**:比較式 `depth > MAX_PAYLOAD_DEPTH`,`depth` 從頂層 0 起算,
故「值所在深度」能通過的上限是 64、65 起被擋。測試工具 `_nested(d)` 的參數 `d`
與值深度相差 1,故以 `d` 計是 63 通過、64 起被擋——**兩種說法都對,差別只在量的
單位**,規格一律用比較式本身描述,不用裸數字。循環引用(`{self: 自己}`)落在
`DEPTH_EXCEEDED`,而非引擎自身的 `var_to_bytes()` 循環保護(該保護回傳 `size()==0`
且不崩潰,但因閘門先跑而不可達)。**證據**:骨架驗證 C,`prototypes/save-format-skeleton-2026-08-21/README.md` 第 158-163 行;`core-serialization.md` §6。

**巢狀 `PackedByteArray` 的界線(決策,非量測)**:已序列化的 `PackedByteArray` 值
一律視為葉節點,不打開來看內容——manifest-only 路徑的正確性依賴這個邊界。**代價**:
若某區塊從未被 `read_full` 實際解碼,藏在裡面的危險型別要到該區塊真正被
`deserialize_block()` 解碼時才會被查到。

## 寫入側接入點

```gdscript
class SerializeResult extends RefCounted:
	var buffer: PackedByteArray = PackedByteArray()
	var rejection: SaveTypeGate.GateRejection = SaveTypeGate.GateRejection.NONE
	var offending_path: String = ""
	func ok() -> bool:
		return rejection == SaveTypeGate.GateRejection.NONE

static func serialize_block(payload: Dictionary) -> SerializeResult:
	return _serialize_gated(payload, "payload")

static func serialize_manifest(envelope: Dictionary) -> SerializeResult:
	return _serialize_gated(envelope, "envelope")

static func _serialize_gated(d: Dictionary, root: String) -> SerializeResult:
	var res := SerializeResult.new()
	var gate: SaveTypeGate.GateResult = SaveTypeGate._walk(d, 0, root)
	if not gate.ok():
		res.rejection = gate.rejection
		res.offending_path = gate.path
		return res
	var buf: PackedByteArray = var_to_bytes(d)
	if buf.size() == 0:  # 合法編碼永不為 0;備援防線,見上方深度上限段落
		res.rejection = SaveTypeGate.GateRejection.DEPTH_EXCEEDED
		res.offending_path = "%s <var_to_bytes returned size 0>" % root
		return res
	res.buffer = buf
	return res
```

**失敗行為**:fail-closed,拒絕整次寫入。寫入側失敗**不可**併入 `SaveFormat.ReadRejection`
(語意不同,見獨立 `SerializeResult`/`WriteResult`)。拒絕發生在組裝原子寫入序列
**之前**,故傷害上限是「這次沒存到」,磁碟上既有存檔不受影響。

## 讀取側接入點

```gdscript
static func deserialize_block(buffer: PackedByteArray) -> DeserializeResult:
	return _deserialize_gated(buffer, "payload")

static func deserialize_manifest(buffer: PackedByteArray) -> DeserializeResult:
	return _deserialize_gated(buffer, "envelope")

static func _deserialize_gated(buffer: PackedByteArray, root: String) -> DeserializeResult:
	var res := DeserializeResult.new()
	if buffer.size() == 0:
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "empty buffer"
		return res
	var decoded: Variant = bytes_to_var(buffer)
	if not (decoded is Dictionary):  # 絕不用 != null,見下方判定規則
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "decoded typeof=%d, not a Dictionary" % typeof(decoded)
		return res
	var gate: SaveTypeGate.GateResult = SaveTypeGate.scan_envelope(decoded) \
		if root == "envelope" else SaveTypeGate.scan(decoded)
	if not gate.ok():
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "type gate rejected on READ side (rejection=%d)" % gate.rejection
		res.offending_path = gate.path
		return res
	res.payload = decoded
	return res
```

`deserialize_manifest()` 的順序(不得調換):

```
bytes_to_var(buffer) → is Dictionary? → SaveTypeGate.scan_envelope(整個信封) → SaveEnvelope.check_shape(envelope)
```

型別閘門先跑、且掃**整個信封**——這是「未知欄位可以夾帶一般資料、但夾帶不了危險
型別」的機制來源。失敗一律回 `DATA_CORRUPTED`,不新增拒絕代碼。**證據**(讀取側
獨立掃描的必要性):`core-serialization.md` §3–4;骨架驗證 C 逐字確認
`EncodedObjectAsID`/`Signal`/`RID`/`Callable` 四種毒位元組 `bytes_to_var()` 全部
靜默成功,只有閘門會擋(`README.md` 第 165-181 行)。

## `SaveEnvelope.check_shape()`

```gdscript
class_name SaveEnvelope extends RefCounted

const ENVELOPE_TOP_KEYS: Array[String] = [
	"ruleset_version", "block_manifest", "top_level_hash", "blocks",
]

class ShapeCheckResult extends RefCounted:
	var rejection: SaveFormat.ReadRejection = SaveFormat.ReadRejection.NONE
	var detail: String = ""
	func ok() -> bool:
		return rejection == SaveFormat.ReadRejection.NONE

static func check_shape(envelope: Dictionary) -> ShapeCheckResult:
	var res := ShapeCheckResult.new()
	for k in ENVELOPE_TOP_KEYS:
		if not envelope.has(k):
			return _fail(res, "信封缺少鍵 %s" % k)
	# 2026-08-24 管理者裁決:未知額外鍵不拒絕,故無「額外鍵一律視為損毀」的反向迴圈。
	if typeof(envelope["ruleset_version"]) != TYPE_INT:
		return _fail(res, "ruleset_version 應為 int")
	if typeof(envelope["block_manifest"]) != TYPE_ARRAY:
		return _fail(res, "block_manifest 應為 Array")
	if typeof(envelope["top_level_hash"]) != TYPE_PACKED_BYTE_ARRAY \
			or (envelope["top_level_hash"] as PackedByteArray).size() != SaveFormat.HASH_LEN:
		return _fail(res, "top_level_hash 型別或長度不符")
	if typeof(envelope["blocks"]) != TYPE_DICTIONARY:
		return _fail(res, "blocks 應為 Dictionary")
	return _check_manifest_entries(envelope["block_manifest"])

static func _fail(res: ShapeCheckResult, detail: String) -> ShapeCheckResult:
	res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
	res.detail = detail
	return res

static func _check_manifest_entries(block_manifest: Array) -> ShapeCheckResult:
	var res := ShapeCheckResult.new()
	var seen: Dictionary = {}
	for i in block_manifest.size():
		if typeof(block_manifest[i]) != TYPE_DICTIONARY:
			return _fail(res, "block_manifest[%d] 應為 Dictionary" % i)
		var entry: Dictionary = block_manifest[i]
		for field_name in SaveFormat.MANIFEST_ENTRY_FIELDS:  # 見下方共用常數
			if not entry.has(field_name):
				return _fail(res, "block_manifest[%d] 缺少鍵 %s" % [i, field_name])
		var type_error: String = _check_entry_field_types(entry, i)
		if type_error != "":
			return _fail(res, type_error)
		var sid: String = entry["source_id"]
		if seen.has(sid):
			return _fail(res, "重複的 source_id '%s'" % sid)
		seen[sid] = true
	return res

# 欄位名來自共用常數,但型別因欄位而異——這是共用常數無法消除的殘餘手動步驟
# (見下方誠實劃界)。
static func _check_entry_field_types(entry: Dictionary, index: int) -> String:
	if typeof(entry["source_id"]) != TYPE_STRING:
		return "source_id 應為 String"
	if typeof(entry["format_version"]) != TYPE_INT:
		return "format_version 應為 int"
	if typeof(entry["block_hash"]) != TYPE_PACKED_BYTE_ARRAY \
			or (entry["block_hash"] as PackedByteArray).size() != SaveFormat.HASH_LEN:
		return "block_hash 型別或長度不符"
	var mt: int = typeof(entry["migration_completion_marker"])
	if mt != TYPE_INT and mt != TYPE_NIL:
		return "migration_completion_marker 應為 int 或 null"
	return ""
```

**保留**:必要鍵存在、型別正確、雜湊長度恰為 32、`source_id` 不重複。**移除**:
額外鍵拒絕迴圈(管理者裁決)。此裁決只開放「夾帶任意資料」,沒開放「夾帶危險型別」
——`check_shape()` 在型別閘門通過**之後**才執行。**延後項**(非本節缺陷,應寫入
Consequences → Negative):信封層寬容 + `blocks` 額外條目被靜默忽略(機制三既有
設計)= 兩塊內容不受頂層雜湊涵蓋也不觸發拒絕的區域,是否擴大雜湊範圍留待實作階段。

## `MANIFEST_ENTRY_FIELDS`(單一共用常數)

```gdscript
# save_format.gd 節錄。形狀檢查與雜湊 canonicalization 都從這裡讀取欄位清單,不得
# 另寫一份(修正前一輪「兩份清單各自漂移」)。選 Array[String] 而非 Dictionary:
# 雜湊側需固定順序(Dictionary 插入順序會改變 var_to_bytes() 輸出,見
# core-serialization.md §7),
# Array 天然保序且 .has() 已足夠支援存在性查詢。
const MANIFEST_ENTRY_FIELDS: Array[String] = [
	"source_id", "format_version", "block_hash", "migration_completion_marker",
]

static func compute_top_level_hash(ruleset_version: int, block_manifest: Array) -> PackedByteArray:
	var ordered: Array = canonical_block_order(block_manifest)
	if ordered.size() != block_manifest.size():
		return PackedByteArray()
	var chunks: Array = [var_to_bytes(ruleset_version)]
	for e in ordered:
		var entry: Dictionary = e
		var tuple: Array = []
		for field_name in MANIFEST_ENTRY_FIELDS:
			tuple.append(entry.get(field_name, null))
		chunks.append(var_to_bytes(tuple))
	return _sha256_of_chunks(chunks)
```

**保證**:新增欄位只需改這一個陣列,存在性檢查與雜湊涵蓋範圍自動同步。**沒有保證**:
每個欄位的型別檢查分支(`_check_entry_field_types`)仍須手動新增——後果是「這個
欄位暫時不驗型別」(侷限、審查能一眼看出),不是「雜湊範圍與形狀檢查彼此不同步」
那種隱性不一致,兩種殘餘風險性質不同。

## `size() == 0` / `is Dictionary` 判定規則

**證據**:`core-serialization.md` §3(全零 16 bytes 是合法 NIL 編碼,`bytes_to_var()`
回傳 `null` 且零錯誤;合法編碼最短 4 bytes,永不為 0)。契約規則:

1. 解碼前先查 `buffer.size() == 0`——可靠、無歧義的失敗訊號。
2. 解碼後一律用 `decoded is Dictionary` 判定成功,**絕不**用 `!= null`(全零位元組
   合法解出 `null`,`!= null` 判定會漏放這種損毀)。
3. 寫入側 `var_to_bytes()` 後查 `size() == 0`,歸為 `DEPTH_EXCEEDED`(唯一已知成因
   是循環引用繞過閘門直接抵達 `var_to_bytes`,理論上不可達,列為備援)。

## 深度回歸測試(自動化偵測「深度檢查被移到遞迴之後」)

```gdscript
# ─── tests/unit/save_system/save_type_gate_depth_regression_test.gd ─────────
extends GdUnitTestSuite

const REGRESSION_DEPTH: int = 3000  # 理由見下方

func test_save_type_gate_extreme_depth_rejects_without_stack_overflow() -> void:
	# Arrange:迭代組裝,不遞迴——否則測試自己先溢位。
	var deep: Dictionary = _build_nested_iteratively(REGRESSION_DEPTH)
	# Act
	var result: SaveTypeGate.GateResult = SaveTypeGate.scan(deep)
	# Assert
	assert_int(result.rejection).is_equal(SaveTypeGate.GateRejection.DEPTH_EXCEEDED)
	# 第二項斷言(引擎沒有真的堆疊溢位)無法用 GdUnit4 的斷言 API 表達——
	# GDScript 的 SCRIPT ERROR/Stack overflow 不透過例外或回傳值傳遞。CI runner
	# 必須額外檢查本測試行程的 stderr 不含 "Stack overflow"/"Stack underflow"
	# 字串,這一層屬於 CI 設定而非本測試檔本身,已提醒協調者登記。

func _build_nested_iteratively(depth: int) -> Dictionary:
	var root: Dictionary = {}
	var cur: Dictionary = root
	for i in depth:
		var nxt: Dictionary = {}
		cur["n"] = nxt
		cur = nxt
	cur["leaf"] = 1
	return root
```

**這條測試能抓到的範圍,精確界定**:它抓的是「深度檢查被移到遞迴之後」。若被移到
「型別判斷之後、但仍在遞迴之前」,本測試會通過——而那個位置仍然是安全的(沒有
遞迴就不會溢位)。涵蓋範圍恰好等於危險的那一種挪動,不是部分涵蓋,不要因為誤以為
它涵蓋不足而另外加測試。

**層數選擇(3000)**:落在建議區間 2,000–5,000 的中段,相對推論的 ~1024 層堆疊
上限有約 3 倍餘裕——若 `_walk_body()` 的遞迴分支誤呼叫 `_walk_body()` 而非
`_walk()`(繞過深度檢查),真正的 GDScript 遞迴會在遠低於 3000 層處(約 1024 層)
先行溢位,可靠觸發真正的堆疊錯誤;層數本身遠低於一般 CI 環境的其他資源限制,
迭代組裝的記憶體/時間成本可忽略。

## 未查證 / 待覆核

- **release build 下本節全部行為是否一致**——全部測量僅限 debug/headless,不宣稱
  release 下維持一致(與 ADR-0002/-0004 共用同一缺口)。
- **`MANIFEST_ENTRY_FIELDS` 與型別檢查分支的一致性**是否需要 CI 層級強制比對,
  留待 `/create-architecture` 決定。

## 交付摘要

- `save_type_gate.gd` — `SaveTypeGate`:常數、`GateRejection`、`GateResult`、
  `scan()`/`scan_envelope()`/`_walk()`(薄殼)/`_walk_body()`(型別判斷+遞迴)/
  `verify_type_table_sum()`/`verify_type_table_partition()`/`self_check()`。
- `save_format.gd` — 新增 `MANIFEST_ENTRY_FIELDS`;`serialize_block/manifest()`、
  `deserialize_block/manifest()` 委派 `SaveTypeGate`,兩側共用同一份實作。
- `save_envelope.gd` — 新增 `SaveEnvelope.check_shape()`,依裁決不含額外鍵拒絕。
- `tests/unit/save_system/save_type_gate_depth_regression_test.gd` — 深度回歸
  測試,涵蓋範圍精確界定為「深度檢查被移到遞迴之後」這一種挪動。
