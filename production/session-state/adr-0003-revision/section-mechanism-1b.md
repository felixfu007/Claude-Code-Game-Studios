# 機制一之二:序列化型別閘門(SaveTypeGate)

> 本檔為 ADR-0003 修訂草案的**內文草稿**,交付位置為
> `production/session-state/adr-0003-revision/section-mechanism-1b.md`。
> 尚未併入 `draft.md` 或正式 ADR 檔案——併入順序依前一輪裁決,必須先有內文才能讓
> 檔頭表格引用它,本檔就是那份內文。
>
> **證據等級標記約定**(比照 `docs/engine-reference/godot/modules/core-serialization.md`):
> - `**證據**:` 開頭的段落 = 可追溯到具體探針/log 的量測結果
> - `**決策**:` 開頭的段落 = 本節做出的設計選擇,不是引擎行為
> - `**推論**:` 開頭的段落 = 從已量測事實邏輯推導,但推導本身未直接測試

## 為什麼這一節必須存在

機制一(二進位 Variant 序列化)的核心論證是「型別白名單問題結構性地不存在」——這句話
**在讀取側對 `Object`(typeof 24)這一個型別成立,除此之外不成立**。這不是收窄後的
措辭問題,是**兩個獨立、方向相反的引擎行為**共同構成的一個洞,兩者都必須有對應的
程式碼防線,理由分別如下。

**證據**(二維威脅模型,`modules/core-serialization.md` 第 2/3/4 節):

| 型別 | 寫入側(`var_to_bytes`) | 讀取側(`bytes_to_var`) |
|---|---|---|
| `Object`(24,含所有 `Resource`/`RefCounted`/`Node`) | ❌ **不拒絕**——靜默編成 `EncodedObjectAsID`(4 bytes 型別碼 + 8 bytes ObjectID),原欄位資料靜默遺失,零錯誤訊息 | ✅ 整包解碼原子性失敗,回傳 `null`,伴隨 `ERR_UNAUTHORIZED` |
| `RID`(23) / `Callable`(25) / `Signal`(26) | ❌ 不拒絕,正常編碼 | ❌ **也不拒絕**——三者完全不受 `allow_objects` 那道閘門管控,零 `ERR_UNAUTHORIZED`、零丟鍵、零整包失敗 |

換句話說:引擎在**寫入側完全沒有安全網**(對 `Object` 靜默腐化資料,對另外三者完全放行);
在**讀取側**只對 `Object` 一種型別有安全網,`RID`/`Callable`/`Signal` 兩側都無防護。
`docs/engine-reference/godot/modules/core-serialization.md` 第 4 節進一步指出三者「通過閘門
之後的命運完全不同」——`Signal` 同行程是全功能物件、`RID` 跨行程指向真實存在、屬於別人的
伺服器資源(`prototypes/save-format-skeleton-2026-08-21/README.md` F-3,兩次獨立行程執行
`RID.get_id()` 逐字相同,非機率碰撞)、`Callable` 是空殼但呼叫它會中止呼叫端函式。

**這一節要擋掉的具體災難**:
1. 存檔裡混入一個 `Object`/`Resource`(例如上游程式碼不小心把一個節點參照塞進要存檔的
   `Dictionary`)寫入時不會有任何錯誤訊息,玩家會拿到一份看似正常、實際上關鍵欄位全部
   為 `null` 的存檔——問題會在讀檔後的遊戲邏輯裡以難以追溯的方式爆炸,而不是在存檔當下。
2. 存檔裡混入 `RID`/`Callable`/`Signal`(不論是上游程式碼誤用,或是舊版有瑕疵建置寫出的
   檔案)讀取時引擎會**成功**解碼出來——不會被 Core Rules #9 的型別白名單機制攔下,因為
   `bytes_to_var()` 本身在這三個型別上沒有任何拒絕行為。若消費端不假思索地使用這個解碼
   結果(例如把還原出來的 `RID` 拿去對伺服器發送指令),等於讓存檔內容直接操作一個可能
   屬於別人的活體引擎資源。

`SaveTypeGate` 是本 ADR 對這兩個方向各自補上的獨立防線,寫入側與讀取側共用同一份實作
(見下方「寫入/讀取接入點」),避免兩套邏輯各自漂移。

## 威脅模型精確化(不擴大,但必須改寫得更精確)

Core Rules #8 的既有威脅模型聲明——本系統防護**意外損毀**與**未經工具協助的手動編輯**,
不是反作弊或防止知情攻擊者竄改的保證——本節不改變這個範圍。但範圍內需要區分兩種後果:

- **資料是垃圾**(欄位全 `null`、解碼失敗)——`Object` 走這條路,已有雜湊鏈與型別閘門
  兩層防護,後果止於「這個區塊/這次存檔讀不回來」。
- **控制代碼跨界指向活體資源**——`RID` 走這條路,後果不是「資料壞了」,而是「拿到一個
  指向真實引擎物件的把柄」。`SaveTypeGate` 把這個型別列入拒絕清單,是本 ADR 對這個較嚴重
  後果類別的唯一防線;`Core Rules #8` 的威脅模型聲明並不因此改變,只是需要明確承認
  「意外損毀」與「控制代碼外洩」是兩種不同的後果形狀,前者由雜湊鏈防護,後者由型別閘門
  防護,兩者都必須存在才涵蓋機制一之二要處理的完整範圍。

`NodePath`(22)**不**列入拒絕——它是合法且常用的持久化型別(例如記錄場景內某節點的
相對路徑供之後定位)。**決策**:消費端讀出 `NodePath` 後,不得直接把它餵給
`get_node()`/`get_node_or_null()` 定位一個當下可能不存在、或路徑語意已隨版本演進而改變
的節點——這是消費端的介面義務,不是 `SaveTypeGate` 能在型別層級強制的事;`SaveTypeGate`
只保證「這是一個 `NodePath` 值,不是別的東西」,語意驗證(該路徑指向的節點目前是否存在、
是否是預期的節點型別)屬於機制六 `validate_semantics()` 的責任範圍。

## `SaveTypeGate` 契約

```gdscript
# ─── save_type_gate.gd ──────────────────────────────────────────
# 純靜態工具集,不持有狀態。寫入側與讀取側呼叫同一份實作(見下方接入點)。
class_name SaveTypeGate extends RefCounted

# ---------------------------------------------------------------- 常數

# 深度上限。語意見下方「深度上限的精確語意」一節——這是一個「值所在深度」的比較式,
# 不是「巢狀了幾層容器」的計數,兩者相差 1。
const MAX_PAYLOAD_DEPTH: int = 64

# 白名單制:判準一律是 ALLOWED_TYPES.has(t),絕不寫成「拒絕集合的 or 鏈」——
# 後者是黑名單,任何新加入引擎的型別會預設通過,而不是預設被擋。
# 35 項:0–22(Nil 到 NodePath)+ 27–38(Dictionary 到 PackedVector4Array)。
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

# 4 項,前一輪 security-engineer 與 GDScript 專家互不知情、獨立收斂的結果,見機制一之二
# 開頭的二維威脅模型表。這 4 個是「必須拒絕」的完整清單,不多不少。
const REJECTED_TYPES: Dictionary = {
	TYPE_RID: true, TYPE_OBJECT: true, TYPE_CALLABLE: true, TYPE_SIGNAL: true,
}

# Dictionary 的鍵額外收緊為這三種——鍵位置不能是容器(容器當鍵一律直接拒絕,不遞迴
# 進去看容器內容),也不能是上面允許清單裡其餘的原生型別(例如 Vector2i 當鍵合法但
# 在此收緊為不允許,降低鍵空間的意外面)。
const ALLOWED_KEY_TYPES: Dictionary = {
	TYPE_STRING: true, TYPE_STRING_NAME: true, TYPE_INT: true,
}

# ---------------------------------------------------------------- 拒絕代碼與結果物件

enum GateRejection { NONE, FORBIDDEN_TYPE, DEPTH_EXCEEDED }

# 遞迴掃描的回傳型別選擇說明見下方「為什麼回傳物件而不是 bool」——
# 這裡刻意回傳帶欄位的結果物件以攜帶 offending_path 供診斷,
# 其安全性前提是「深度檢查一律先於任何遞迴呼叫執行」,見同節。
class GateResult extends RefCounted:
	var rejection: GateRejection = GateRejection.NONE
	var path: String = ""
	func ok() -> bool:
		return rejection == GateRejection.NONE

# ---------------------------------------------------------------- 公開掃描入口

# 掃描一個區塊 payload(頂層通常是 Dictionary,但函式本身不假設頂層型別——
# 呼叫端若需要「頂層必須是 Dictionary」這條額外規則,由呼叫端自行檢查,理由見
# 下方「讀取側接入點」——型別閘門與「這是不是一份合法信封」是兩個不同的問題)。
static func scan(payload: Variant) -> GateResult:
	return _walk(payload, 0, "payload")

# 掃描整個信封(包含尚未拆分的 blocks 字典)。讀取側 deserialize_manifest() 必須呼叫
# 這個入口而不是 scan(),因為信封裡的 blocks 字典的值是 PackedByteArray(見下方
# 「巢狀 PackedByteArray 的界線」,這些值本身是允許型別,不會被誤擋)。
static func scan_envelope(envelope: Variant) -> GateResult:
	return _walk(envelope, 0, "envelope")

static func _key_repr(k: Variant) -> String:
	# 只在鍵已通過 ALLOWED_KEY_TYPES 之後才會被呼叫,故只會是 String/StringName/int。
	if typeof(k) == TYPE_INT:
		return str(k)
	return "\"%s\"" % str(k)

# 薄殼(2026-08-24 second-round 修訂,security-engineer 提案,已採納):只做深度
# 檢查,除了 MAX_PAYLOAD_DEPTH 這個數字外沒有其他理由被觸碰——見下方「為什麼回傳
# 物件」專節的「拆薄殼」討論。
static func _walk(value: Variant, depth: int, path: String) -> GateResult:
	if depth > MAX_PAYLOAD_DEPTH:
		var result := GateResult.new()
		result.rejection = GateRejection.DEPTH_EXCEEDED
		result.path = "%s <depth %d > MAX %d>" % [path, depth, MAX_PAYLOAD_DEPTH]
		return result
	return _walk_body(value, depth, path)

# 型別判斷 + 遞迴。**任何遞迴呼叫一律呼叫 _walk(),絕不可呼叫 _walk_body()**——
# 呼叫錯的後果是深度檢查對該分支完全失效,由「深度回歸測試」專節的自動化測試把關。
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
			var key_type: int = typeof(key)
			if not ALLOWED_KEY_TYPES.has(key_type):
				result.rejection = GateRejection.FORBIDDEN_TYPE
				result.path = "%s.<KEY typeof=%d>" % [path, key_type]
				return result
			var sub: GateResult = _walk(d[key], depth + 1, "%s[%s]" % [path, _key_repr(key)])  # _walk,非 _walk_body
			if not sub.ok():
				return sub
	elif t == TYPE_ARRAY:
		var a: Array = value
		for i in a.size():
			var sub: GateResult = _walk(a[i], depth + 1, "%s[%d]" % [path, i])  # _walk,非 _walk_body
			if not sub.ok():
				return sub
	# TYPE_PACKED_BYTE_ARRAY 落在這裡結束——它是允許型別,且不是 TYPE_DICTIONARY/
	# TYPE_ARRAY,故不會進入上面任何一個分支,函式對它視為葉節點直接放行。
	return result

# ---------------------------------------------------------------- 載入期完整性斷言

# 規格逐字要求的那一條:僅比較數量。**決策依據**:骨架驗證 E 實測這條斷言對
# 「拿掉 TYPE_COLOR、同時把 TYPE_OBJECT 誤加進允許集合」這個最壞情境完全瞎
# (35+4=39,斷言回 true,而 TYPE_OBJECT 已經在白名單上)——見下方專節。
# 保留此函式僅供對照/文件用途,**不得**單獨作為 CI 或啟動期檢查的判準。
static func verify_type_table_sum(allowed: Dictionary, rejected: Dictionary) -> bool:
	return allowed.size() + rejected.size() == TYPE_MAX

# 較強的一條:逐一檢查 0..TYPE_MAX-1 每個索引恰好落在其中一個集合(無交集、無遺漏、
# 無越界鍵)。回傳空字串代表通過,否則回傳指出問題的字串。這是啟動期/CI 應該實際
# 呼叫的那一個。
static func verify_type_table_partition(allowed: Dictionary, rejected: Dictionary) -> String:
	for t in range(TYPE_MAX):
		var is_allowed: bool = allowed.has(t)
		var is_rejected: bool = rejected.has(t)
		if is_allowed and is_rejected:
			return "typeof=%d 同時在允許與拒絕集合中(交集)" % t
		if not is_allowed and not is_rejected:
			return "typeof=%d 兩個集合都沒列到(新型別會落在無人管的縫裡)" % t
	for k in allowed:
		if typeof(k) != TYPE_INT or int(k) < 0 or int(k) >= TYPE_MAX:
			return "允許集合含越界鍵 %s" % str(k)
	for k in rejected:
		if typeof(k) != TYPE_INT or int(k) < 0 or int(k) >= TYPE_MAX:
			return "拒絕集合含越界鍵 %s" % str(k)
	return ""

# 啟動期自我檢查:兩條斷言都跑,任一失敗即 push_error。應在遊戲啟動流程或 CI 早期
# 呼叫一次,確保任何未來修改 ALLOWED_TYPES/REJECTED_TYPES 的人不會意外破壞分割完整性。
static func self_check() -> bool:
	var sum_ok: bool = verify_type_table_sum(ALLOWED_TYPES, REJECTED_TYPES)
	var partition_error: String = verify_type_table_partition(ALLOWED_TYPES, REJECTED_TYPES)
	if not sum_ok:
		push_error("SaveTypeGate.self_check FAILED(數量): %d + %d != TYPE_MAX(%d)"
			% [ALLOWED_TYPES.size(), REJECTED_TYPES.size(), TYPE_MAX])
	if partition_error != "":
		push_error("SaveTypeGate.self_check FAILED(分割): %s" % partition_error)
	return sum_ok and partition_error == ""
```

**證據**(常數與判讀依據):`TYPE_MAX = 39`、Variant 型別枚舉全表、35+4=39 剛好完整——
`modules/core-serialization.md` 第 9 節;白名單/拒絕清單/鍵收緊三張表的具體內容——
`prototypes/save-format-skeleton-2026-08-21/scripts/save_format.gd`(階段 0 pre1 已驗證
39 個 `TYPE_*` 識別字全部 `COMPILED OK`,`README.md` 第 88 行)。

**證據**(完整性斷言的必要性):骨架驗證 E,`README.md` 第 194-202 行——「拿掉
`TYPE_COLOR`、同時把 `TYPE_OBJECT` 誤加進允許集合」這個情境下,單純比較數量的斷言
回傳 `true`(通過),而逐一分割檢查的版本正確抓到「typeof=20(Color)兩個集合都沒
列到」。**這裡刻意不概括為「白名單問題結構性地不存在」這類全稱語句**——這正是本
專案已登記過一次的失敗形狀(措辭全稱、定義域只有一項),完整性斷言本身只覆蓋「兩個
`const Dictionary` 是否構成一個無縫、無交集的分割」這一件事,不覆蓋「白名單裡列的
39 個型別的判斷值『允許/拒絕』本身選對了沒有」——後者是機制一之二開頭那張二維表
的責任,兩者是不同層級的正確性。

## 為什麼回傳物件而不是 bool——以及這個選擇為何在本設計裡是安全的

`security-engineer` 在前一輪明文警告:遞迴掃描的回傳型別選擇會影響安全性。若判定
極性寫成「找到合法值回 `true`」這種寫法,GDScript 呼叫堆疊溢位時每一層展開拿到的
零值是 `false`(布林零值),恰好落在「安全」的極性上——**但這是巧合,不是設計出來
的保證**。若回傳型別換成一個帶欄位的結果物件(例如本節的 `GateResult`),堆疊溢位
展開時拿到的零值是 `null`,呼叫端接著讀取 `result.rejection`/`result.path` 就會在
`null` 實例上取屬性,從「意外安全」變成「呼叫端無聲中止」。

**證據**(堆疊溢位的零值展開行為):`modules/core-serialization.md` 第 6 節——無防護
遞迴閘門對循環引用會導致 `SCRIPT ERROR: Stack overflow`,接著約 1024 行
`Stack underflow! (Engine Bug)`;GDScript 遞迴上限約 1024 個堆疊框是**由 1024 行
`Stack underflow` 推得,非直接量測**(該檔明文標記為推論)。

**本設計為何仍選擇回傳 `GateResult` 物件**:`_walk()` 的**第一行**就是深度檢查
(`if depth > MAX_PAYLOAD_DEPTH: return ...`),先於任何型別判斷,更先於任何遞迴呼叫。
這代表遞迴深度在架構上被鎖死在 65 層以內(`depth` 從 0 起算,`depth > 64` 在第 65 次
呼叫時觸發並直接返回,不再往下遞迴)——這個上限與推得的 ~1024 層 GDScript 堆疊上限
之間有超過 15 倍的餘裕。**決策**:security-engineer 警告的失敗模式,其前提是「遞迴
沒有深度上限,或深度上限設得比堆疊上限還高」,兩者本節都不成立,所以選擇回傳物件
而非 bool——物件形式帶得出 `offending_path` 供診斷,而堆疊溢位這個具體風險已經被
深度檢查的執行順序(檢查先於遞迴)結構性排除,不是靠零值巧合僥倖過關。**這個安全性
論證的前提是「深度檢查必須是遞迴函式的第一件事」——任何未來重構若把深度檢查移到
型別判斷或遞迴呼叫之後,這個論證就不再成立**,這是本設計對日後維護者的一項隱性
要求,值得在程式碼註解與 code review checklist 中明文提醒。

骨架階段 1 驗證 C(循環引用)已實測這個順序確實生效:`{self: 自己}` 這種自我參照
`Dictionary` 餵進 `SaveTypeGate.scan()` 時,結果是 `DEPTH_EXCEEDED`,而不是堆疊溢位
崩潰——見下方「深度上限與循環引用」專節。

### 2026-08-24 第二輪覆核:`security-engineer` 確認結構性排除,並抓到一個測試盲點

`security-engineer` 逐一查核三條可能繞過深度檢查的路徑——Dictionary 的鍵不遞迴、
容器當值是唯一遞迴路徑且 `depth` 恰好 `+1`、所有公開入口 `depth` 皆硬寫 `0`——
三者皆不成立。判定:**這不是「風險被推遠」,是結構性排除**,`_walk()` 在第 65 次
呼叫就直接返回,不會嘗試第 66 次。`GateResult` 回傳物件的設計維持,不改回 bool。

但他同時指出一個本節先前沒看到、且比原本爭點更重要的盲點:**現有測試(骨架測了
深度 10/62/63/64/65/100)驗證的是「深度上限這個數字對不對」,不是「深度檢查的
執行順序對不對」**。若未來有人把深度檢查移到遞迴呼叫**之後**,深度 100 的輸入
仍然 100 遠小於 1024,不會撞到真正的堆疊上限,函式看起來仍然正常運作——**順序被
破壞會是靜默的**,沒有任何既有測試會亮紅燈。

**已落實的兩項緩解**:
1. `_walk()` 拆成薄殼(只做深度檢查)+ `_walk_body()`(型別判斷與遞迴),見上方
   程式碼——薄殼極短,除了那個數字外沒有理由被編輯到。**殘餘風險**:遞迴呼叫
   寫錯成 `_walk_body()` 而非 `_walk()`,這個拆分本身不能消除這個風險,只能降低
   「順手把檢查往下挪」的編輯機率。
2. **深度回歸測試**(新增,見下方專節):構造遠超 100(3,000 層)的巢狀結構,
   斷言結果為 `DEPTH_EXCEEDED` 且行程未真的堆疊溢位——這條測試的涵蓋範圍精確
   等於「深度檢查被移到遞迴之後」這一種挪動(含上述殘餘風險:遞迴呼叫錯呼叫
   `_walk_body()`,效果等同於檢查被繞過,同樣會被此測試的堆疊溢位偵測抓到),
   不涵蓋「移到型別判斷之後、仍在遞迴之前」這種挪動——但後者本來就是安全的
   (沒有遞迴就不會溢位),所以涵蓋範圍與風險範圍是重合的,不是打折的涵蓋。

## 深度回歸測試

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
	# 第二項斷言(引擎沒有真的堆疊溢位)無法用 GdUnit4 的斷言 API 表達——GDScript 的
	# SCRIPT ERROR/Stack overflow 不透過例外或回傳值傳遞。CI runner 必須額外檢查
	# 本測試行程的 stderr 不含 "Stack overflow"/"Stack underflow" 字串,這一層屬於
	# CI 設定而非本測試檔本身。

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

**基底類別**:`extends GdUnitTestSuite`,沿用 `tests/unit/harness/harness_selfcheck_test.gd`
已驗證可編譯的既有慣例(`tests/README.md`)。**檔名/函式名慣例**:
`[system]_[feature]_test.gd` / `test_[system]_[scenario]_[expected_result]`,依
`.claude/rules/test-standards.md`。

**層數選擇(3000)**:落在協調者建議區間 2,000–5,000 的中段,相對推論的 ~1024 層
堆疊上限有約 3 倍餘裕——若 `_walk_body()` 的遞迴分支誤呼叫 `_walk_body()` 而非
`_walk()`(繞過深度檢查),真正的 GDScript 遞迴會在遠低於 3000 層處(約 1024 層)
先行溢位,可靠觸發真正的堆疊錯誤;層數本身遠低於一般 CI 環境的其他資源限制,
迭代組裝的記憶體/時間成本可忽略。

## 深度上限的精確語意(不要用「63 通過、64 被擋」這種單一數字描述)

前一輪的紀錄把這件事登記成「差一錯誤」,重新核對後兩種說法**各自成立,只是量的
定義不同**,必須把它寫成不會被誤讀的形式。

`_walk()` 的比較式是 `depth > MAX_PAYLOAD_DEPTH`,其中 `MAX_PAYLOAD_DEPTH = 64`,
`depth` 是**呼叫進入時的當前深度**,頂層呼叫(`scan(payload)`)以 `depth = 0` 開始。
每多一層 `Dictionary`/`Array` 巢狀,子呼叫的 `depth` 加 1。也就是說:

- **葉節點值本身所在的深度** = 巢狀容器層數。一個「巢狀 N 層容器、最內層放一個值」
  的結構,該值是在第 N 次遞迴呼叫時被檢查,此時 `depth = N`。
- 比較式 `depth > 64` 在 `depth = 64` 時**不觸發**(64 不大於 64,放行),在
  `depth = 65` 時**觸發**(65 大於 64,拒絕)。
- 因此:**以「值所在深度」為量的單位,能通過的最大深度是 64,65 開始被擋。**

骨架測試工具 `_nested(d)` 的參數 `d` 代表的是「呼叫端要求構造幾層巢狀容器」,而
`_nested(d)` 的實作是先建立 `d` 層 `Dictionary` 巢狀、最內層再放一個葉節點值——
即參數 `d` 與「值所在深度」相差 1(因為頂層 payload 本身要先花一次巢狀才進到第一層
子 Dictionary,值又比最後一層巢狀容器深一層)。**因此**:

- **以「`_nested(d)` 的參數 `d`」為量的單位,能通過的最大 `d` 是 63,`d = 64` 開始
  被擋。**

兩種說法(「64 通過、65 被擋」vs「63 通過、64 被擋」)**都對**,差別只在於「64」
指的是值深度還是 `_nested()` 的參數——這正是前一輪產生數字分歧的根源,不是任何一方
量錯了。**規格與程式碼註解一律應以比較式本身(`depth > MAX_PAYLOAD_DEPTH`,`depth`
從頂層 0 起算)描述,不要用裸數字描述「第幾層被擋」**,避免同一個上限被不同的人
用不同的量單位各自複述、產生看似矛盾實則一致的紀錄。

**證據**:骨架驗證 C,`README.md` 第 158-159 行(逐字):「深度:`MAX_PAYLOAD_DEPTH=64`。
巢狀 10/62/63 → NONE;64/65/100 → DEPTH_EXCEEDED。(本骨架的 `_nested(d)` 讓最深的
**值**位於深度 `d+1`,故實際可過的最大值深度就是 64,與 `depth > MAX` 一致。)」;
`t_c_poison.gd` 第 66-72 行(`t_c_write_side_depth()`,逐一測 `[10, 62, 63, 64, 65, 100]`)。

## 深度上限與循環引用

GDScript 允許構造自我參照的 `Dictionary`/`Array`(它們是參照型別,`d["self"] = d`
合法)。規格鎖定的順序是「先跑型別閘門、再呼叫 `var_to_bytes()`」——這意味著循環
引用**只會被深度上限攔下**,不會抵達 `var_to_bytes()` 自身的循環引用保護,兩條理論上
存在的防線實際上只有一條可達。

**證據**:骨架驗證 C-循環(`README.md` 第 161-163 行、(b)-4):`{self: 自己}` 餵進
`SaveTypeGate` 的結果是 `DEPTH_EXCEEDED`,`offending_path` 是 65 層 `["self"]` 疊出來
的字串(即遞迴確實跑了 65 次才觸發拒絕,與上一節「值深度 65 被擋」的語意完全一致);
`Array` 自我參照同樣是 `DEPTH_EXCEEDED`。**對照組**:若繞過閘門直接呼叫
`var_to_bytes(循環 Dictionary)`,回傳的 `PackedByteArray.size() == 0`(不是崩潰、
不是掛起),但過程中會印出 1 次 `Potential infinite recursion detected. Bailing.`
加上每層巢狀各一次的 `Condition "err" is true`——`modules/core-serialization.md`
第 6 節記載這是引擎自己的保護機制,`prototypes/save-format-skeleton-2026-08-21/README.md`
第 76-80 行記載這個對照組單一呼叫產生了 1,025 行的錯誤 log(408 KB log 檔案裡的
絕大部分)。

這個對照組的意義:**它證明了「回傳 `size()==0` 判斷循環引用」這個備援防線是真實
存在的引擎行為,不是理論假設**——但因為型別閘門先攔截,這條防線在本設計的正常
執行路徑上永遠不會被觸發。**決策**:仍然在 `SaveTypeGate.scan()` 的呼叫端(即
`serialize_block`/`serialize_manifest`)保留「`var_to_bytes()` 回傳 `size()==0`
視為失敗」這條檢查,不因為它理論上不可達就省略——理由是深度上限與型別閘門的正確性
依賴的是本節程式碼本身沒有 bug;若未來某次重構意外讓某個路徑繞過了 `SaveTypeGate`
直接呼叫 `var_to_bytes()`,這條備援檢查是唯一還能攔住循環引用的東西。

## 巢狀 `PackedByteArray` 的界線(決策,非量測)

`blocks` 字典裡每個區塊的值是一份**已經序列化過**的 `PackedByteArray`(機制二的分層
設計)。`SaveTypeGate.scan_envelope()` 掃描整個信封時,會走到這些值——`TYPE_PACKED_BYTE_ARRAY`
本身在 `ALLOWED_TYPES` 上,`_walk()` 對它不做任何特殊處理,視為葉節點直接放行,
**不會**呼叫 `bytes_to_var()` 打開它來看裡面裝的是什麼。

**這是一個決策,不是量測結果**——上一輪 `security-engineer` 曾提出這個問題(若某
區塊 payload 裡巢狀了一個已經序列化過的 `PackedByteArray`,閘門該不該打開內層緩衝區
一起掃),協調者當時誤判為「往返保真問題」並已被指出誤判;真正的問題是**閘門掃描
範圍的定義**,前一輪已裁決為「不打開,視為葉節點」,本節沿用此裁決並在此明文記錄
理由:

1. **manifest-only 路徑的正確性依賴這個邊界**——機制二整個分層設計的前提就是外層
   `bytes_to_var()` 解碼後,`blocks` 字典的值仍是「尚未解碼的 `PackedByteArray`」,
   驗證 D 用呼叫計數器證明的正是這件事(`read_manifest_only` 的 `decode_calls=1`)。
   若 `SaveTypeGate` 自己打開這些緩衝區去掃,等於在 manifest-only 路徑上偷偷做了
   完整解碼,直接違反 Core Rules #5 對這個介面的要求。
2. **「打開來掃」預設了一個遞迴終止條件不存在的問題**——若某系統的區塊 payload 本身
   又巢狀了另一個已序列化的區塊(理論上可能,雖然目前已知的擁有系統都不這樣做),
   「打開來掃」需要遞迴到不知道多少層的 `bytes_to_var()` 呼叫,而深度上限是對
   `Dictionary`/`Array` 巢狀層數設計的,不是對「序列化緩衝區的巢狀次數」設計的,
   兩者不是同一個量,把它們混在一起會讓深度上限的語意變得複雜且難以推理。
3. **每個區塊各自的雜湊驗證(機制三步驟 4)已經是這個緩衝區的完整性防線**——若某個
   `PackedByteArray` 值本身裡面藏了不該有的型別,那個緩衝區在它自己被
   `deserialize_block()` 解碼時,會被**同一份** `SaveTypeGate` 實作再掃一次(見下方
   讀取側接入點),不會漏掉,只是防線落在「該區塊真正被解碼的那一刻」,不是「外層
   信封掃描的那一刻」。

**這個決策的代價**(誠實揭露,不是免費的):如果某個區塊從未被 `read_full` 實際
解碼(例如某次讀取只需要另外兩個區塊),藏在它裡面的危險型別**在那次讀取中永遠不會
被 `SaveTypeGate` 檢查到**——因為 `deserialize_block()` 根本沒被呼叫。這與機制二
「manifest-only 不解碼任何區塊」的設計目標是一致的(不解碼就是不解碼,包含不做
型別檢查),但若呼叫端誤以為「信封層的 `scan_envelope()` 已經檢查過所有內容」,
會錯誤地以為未被讀取的區塊也是安全的。**建議**:這一點應該在 `SaveReader`/
`SaveTypeGate` 的介面文件與注入該資訊的 code review checklist 中明文提醒。

## 寫入側接入點

```gdscript
# ─── save_format.gd(節錄,型別閘門介入的部分)────────────────
class_name SaveFormat extends RefCounted

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
	if buf.size() == 0:
		# 合法編碼永不為 0(見下方 size()==0 判定規則)。已知唯一成因是循環引用,
		# 但閘門已先跑,這條路徑理論上不可達——保留當備援防線,見上方專節。
		res.rejection = SaveTypeGate.GateRejection.DEPTH_EXCEEDED
		res.offending_path = "%s <var_to_bytes returned size 0>" % root
		return res
	res.buffer = buf
	return res
```

**失敗行為**:寫入側閘門拒絕**整次寫入**(fail-closed)——`SerializeResult.ok() == false`
時,呼叫端(`SaveWriter.build()`)必須整個中止組裝,不寫出任何位元組。**決策**(前一輪
`security-engineer` 裁決,本節採納):寫入失敗**不可**併入 `SaveFormat.ReadRejection`——
兩者語意不同,`ReadRejection` 描述的是「一份已存在的位元組流不合法」,而寫入側閘門描述
的是「這次企圖產生的位元組流一開始就不該被產生」,混用會讓呼叫端無法區分「我這次沒存
成功」與「我讀到一份壞檔案」這兩種完全不同的處置路徑(前者通常只需要重試或提示玩家,
後者可能需要進入損毀復原流程)。本節沿用骨架已驗證的形狀:寫入側用獨立的
`SerializeResult`/`WriteResult`(見 `SaveWriter.WriteStatus`,`prototypes/save-format-skeleton-2026-08-21/scripts/save_writer.gd`),讀取側用 `SaveFormat.ReadRejection`。

**既有存檔不受影響**:本 ADR 的原子寫入模型(ADR-0004)要求「先寫暫存檔、確認成功、
再重新命名」的序列——寫入側閘門的拒絕發生在**進入這個序列之前**(閘門檢查的是記憶體
中的 `Dictionary`/組裝完的信封,不是已經寫到磁碟的位元組)。因此寫入側閘門拒絕的傷害
上限是「這次沒存到」:磁碟上任何既有的、之前成功寫入的存檔檔案完全不受這次失敗寫入
嘗試影響,不存在「半份新檔案覆蓋掉舊檔案」的風險。

## 讀取側接入點

```gdscript
# ─── save_format.gd(節錄,型別閘門介入的部分)────────────────
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
	# 成功判定一律 `is Dictionary`,絕不用 `!= null`——見下方 size()==0/null 判定規則。
	if not (decoded is Dictionary):
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "decoded typeof=%d, not a Dictionary" % typeof(decoded)
		return res
	# 對稱閘門:掃描「整個」已解碼結構,舊版有瑕疵的建置可能已把 EncodedObjectAsID /
	# Signal / RID 寫進檔案,而這三者在解碼側完全不觸發引擎自己的拒絕行為。
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

`deserialize_manifest()` 的完整順序(對應前一輪已裁決、不得推翻的前提 11):

```
bytes_to_var(buffer)
    ↓
is Dictionary?  ──否──▶ DATA_CORRUPTED
    ↓ 是
SaveTypeGate.scan_envelope(整個信封)  ──未通過──▶ DATA_CORRUPTED
    ↓ 通過
SaveEnvelope.check_shape(envelope)    ──未通過──▶ DATA_CORRUPTED
```

**這個順序的理由**:型別閘門先跑,而且掃的是**整個信封**(不是只掃某個已知欄位)——
這正是「未知欄位可以夾帶一般資料、但夾帶不了危險型別」的機制來源(見下方
`SaveEnvelope.check_shape()` 專節)。若順序反過來(先做形狀檢查、再做型別閘門),
一個「形狀完全正確、但某個必要欄位的值是 `RID`」的信封會先通過形狀檢查,型別閘門
反而變成事後補救而非第一道防線。

**失敗行為**:讀取側閘門拒絕視為 `SaveFormat.ReadRejection.DATA_CORRUPTED`——沿用
ADR 既有的拒絕代碼列舉,不新增代碼,理由與該列舉原本涵蓋的「頂層/逐區塊雜湊不符、
型別白名單解碼失敗、驗證器未登記」語意一致:對呼叫端而言,「這份資料在型別層級就不
可信」與「這份資料雜湊對不上」都是同一類「不能用」的結果,不需要在拒絕代碼層級
區分。

**證據**(讀取側必須獨立掃描的必要性):骨架驗證 C 讀取側,`README.md` 第 165-181 行——
plain 編的 `Object`(`EncodedObjectAsID`)、`Signal`、`RID`、`Callable` 四種毒位元組,
`bytes_to_var()` 全部**靜默成功解碼**,只有閘門自己會擋;逐字結論:「讀取側必須再跑
一次同一組型別閘門」這條規格要求,實測是必要的而非贅餘。

## `SaveEnvelope.check_shape()`

```gdscript
# ─── save_envelope.gd ────────────────────────────────────────────
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
			res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
			res.detail = "信封缺少鍵 %s" % k
			return res
	# 依 2026-08-24 管理者裁決:未知額外鍵不拒絕(維持寬容,換取未來加欄位不必升版本
	# 號)。本函式因此刻意不含任何「for key in envelope: if not 必要鍵.has(key)」這種
	# 反向迴圈——那種迴圈就是「額外鍵一律視為損毀」,已被明文推翻。
	if typeof(envelope["ruleset_version"]) != TYPE_INT:
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "ruleset_version typeof=%d,應為 int" % typeof(envelope["ruleset_version"])
		return res
	if typeof(envelope["block_manifest"]) != TYPE_ARRAY:
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "block_manifest typeof=%d,應為 Array" % typeof(envelope["block_manifest"])
		return res
	if typeof(envelope["top_level_hash"]) != TYPE_PACKED_BYTE_ARRAY \
			or (envelope["top_level_hash"] as PackedByteArray).size() != SaveFormat.HASH_LEN:
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "top_level_hash 型別或長度不符(應為 %d bytes 的 PackedByteArray)" \
			% SaveFormat.HASH_LEN
		return res
	if typeof(envelope["blocks"]) != TYPE_DICTIONARY:
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "blocks typeof=%d,應為 Dictionary" % typeof(envelope["blocks"])
		return res
	return _check_manifest_entries(envelope["block_manifest"])

static func _check_manifest_entries(block_manifest: Array) -> ShapeCheckResult:
	var res := ShapeCheckResult.new()
	var seen_source_ids: Dictionary = {}
	for i in block_manifest.size():
		if typeof(block_manifest[i]) != TYPE_DICTIONARY:
			res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
			res.detail = "block_manifest[%d] typeof=%d,應為 Dictionary" \
				% [i, typeof(block_manifest[i])]
			return res
		var entry: Dictionary = block_manifest[i]
		# 必要鍵存在性:一律來自共用常數 MANIFEST_ENTRY_FIELDS,見下方專節。
		for field_name in SaveFormat.MANIFEST_ENTRY_FIELDS:
			if not entry.has(field_name):
				res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
				res.detail = "block_manifest[%d] 缺少鍵 %s" % [i, field_name]
				return res
		# 逐欄位型別檢查:field 名稱來自同一份共用常數,但每個欄位的合法型別不同,
		# 這一段 match 是共用常數目前無法消除的殘餘手動步驟——見下方專節誠實說明。
		var type_error: String = _check_entry_field_types(entry, i)
		if type_error != "":
			res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
			res.detail = type_error
			return res
		var source_id: String = entry["source_id"]
		if seen_source_ids.has(source_id):
			res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
			res.detail = "block_manifest 有重複的 source_id '%s'" % source_id
			return res
		seen_source_ids[source_id] = true
	return res

static func _check_entry_field_types(entry: Dictionary, index: int) -> String:
	if typeof(entry["source_id"]) != TYPE_STRING:
		return "block_manifest[%d].source_id typeof=%d,應為 String" \
			% [index, typeof(entry["source_id"])]
	if typeof(entry["format_version"]) != TYPE_INT:
		return "block_manifest[%d].format_version typeof=%d,應為 int" \
			% [index, typeof(entry["format_version"])]
	if typeof(entry["block_hash"]) != TYPE_PACKED_BYTE_ARRAY \
			or (entry["block_hash"] as PackedByteArray).size() != SaveFormat.HASH_LEN:
		return "block_manifest[%d].block_hash 型別或長度不符(應為 %d bytes)" \
			% [index, SaveFormat.HASH_LEN]
	var marker_type: int = typeof(entry["migration_completion_marker"])
	if marker_type != TYPE_INT and marker_type != TYPE_NIL:
		return "block_manifest[%d].migration_completion_marker typeof=%d,應為 int 或 null" \
			% [index, marker_type]
	return ""
```

**依裁決保留的檢查**:必要鍵存在(頂層 4 個、每個 manifest 條目 4 個)、型別正確、
`block_hash`/`top_level_hash` 長度恰為 `HASH_LEN`(32)、`source_id` 不重複。

**依裁決移除的檢查**:「額外鍵一律視為損毀」的反向拒絕迴圈——2026-08-24 管理者裁決
信封層出現未知額外鍵時**忽略,不拒絕**,理由是換取未來加欄位不必升版本號、新舊版
存檔仍可互通。**這個裁決只開放了「夾帶任意資料」的面,沒有開放「夾帶危險型別」的
面**:因為 `check_shape()` 只在 `SaveTypeGate.scan_envelope()` 已經通過**之後**才
執行(見上方讀取側接入點的順序圖),未知欄位的內容早已被型別閘門掃過一輪——一個
未知欄位可以裝一個字串或數字,但不能裝一個 `RID`/`Object`/`Callable`/`Signal`,
兩種閘門各自負責不同的問題,順序保證了寬容不會擴大到危險型別。

**已知但刻意不在本節解決的組合後果**(前一輪已登記為延後項,此處重申):信封層
寬容(本節)加上 `blocks` 字典裡多出的條目被靜默忽略(機制三讀取路徑的既有設計,
`README.md` (c)-4)= 存檔裡有兩塊內容不受頂層雜湊涵蓋、也不觸發拒絕的區域。這不是
本節的缺陷(兩個決策各自有理由,見上方與機制三),但合起來看確實是一個需要在
Consequences → Negative 明文承認的組合後果,是否要擴大頂層雜湊涵蓋範圍留待實作
階段決定。

## `MANIFEST_ENTRY_FIELDS`:單一共用常數(問題 A)

前一輪產生了兩份各自維護的 manifest 欄位清單——`SaveEnvelope`(或前一輪版本裡的
`SaveReader`)用於形狀檢查的必要鍵清單,以及雜湊 canonicalization 那一側(`compute_top_level_hash`)組 tuple 時各自寫死的欄位順序。這是被明文警告過的漂移風險:新增一個
manifest 欄位時,若忘記同步更新其中一份清單,會產生「形狀檢查通過了,但頂層雜湊
沒把新欄位算進去(或反過來)」這種難以在程式碼審查中發現的不一致。

```gdscript
# ─── save_format.gd(節錄)──────────────────────────────────────
class_name SaveFormat extends RefCounted

# 單一共用常數。形狀檢查(SaveEnvelope.check_shape)與雜湊 canonicalization
# (compute_top_level_hash)都必須從這裡讀取欄位清單,不得另外硬寫一份。
#
# 選用 Array[String] 而非 Dictionary 的理由:雜湊那一側需要「固定順序」——已實測
# 兩個 == 相等、鍵值相同但插入順序不同的 Dictionary,var_to_bytes() 編碼結果逐位元組
# 不同(見下方「深度上限」前一節之外的證據段落)——而 Array 天然保有宣告順序;
# 同時 Array 本身就支援 .has() 做集合查詢(元素數量固定在個位數,O(n) 掃描沒有效能
# 疑慮),不需要額外維護一份 Dictionary 版本來滿足「查詢」這個用途。單一常數
# 因此能同時滿足「固定順序」(雜湊 tuple 組裝的迭代順序)與「集合查詢」
# (check_shape 的存在性檢查)兩種需求,不需要兩份平行資料結構。
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
		# 迭代同一份共用常數組出 tuple——欄位順序與 check_shape() 的存在性檢查
		# 使用的是同一份清單,不會出現「這裡多算一個欄位、那裡少檢查一個欄位」的漂移。
		for field_name in MANIFEST_ENTRY_FIELDS:
			tuple.append(entry.get(field_name, null))
		chunks.append(var_to_bytes(tuple))
	return _sha256_of_chunks(chunks)
```

**這個設計保證了什麼、沒保證什麼**(誠實劃界,不誇大單一常數的效力):

- **保證**:新增一個 manifest 欄位時,只要把欄位名稱加進 `MANIFEST_ENTRY_FIELDS`
  這一個陣列,`check_shape()` 的「必要鍵存在」檢查與 `compute_top_level_hash()` 的
  tuple 組裝**會自動同步涵蓋新欄位**——因為兩者都是對同一份陣列做迭代,不是各自
  複製一份清單再各自維護。這正是前一輪要求的「新增欄位時只需改一處」性質,達成的
  方式是把「欄位名稱清單」本身變成程式碼裡唯一的一份資料,而不是靠人工紀律保證
  兩份清單同步。
- **沒有保證**:新欄位的**型別合法性檢查**(例如新欄位該是 `int` 還是 `String`)
  不會自動生成——`_check_entry_field_types()` 仍然是一段針對每個欄位名稱各自寫死
  判斷邏輯的 `match`/`if` 序列,新增欄位時仍需要在這裡手動加一個分支。**這與被
  警告的「兩份清單各自漂移」不是同一種風險**:漏加型別檢查分支的後果是「這個新
  欄位暫時不驗型別」(一個侷限、可追蹤的缺口,程式碼審查能一眼看出這個欄位沒有
  對應分支),而不是「雜湊涵蓋範圍與形狀檢查範圍彼此不同步」(一個難以從單一檔案
  看出的隱性不一致)。**決策**:接受這個殘餘的手動步驟,不強行把型別檢查也塞進
  同一個資料結構(例如改成 `Dictionary[String, int]` 存欄位名稱到期望 typeof 的
  對照)——因為 `migration_completion_marker` 的合法型別是「`int` 或 `null`」這種
  雙型別,`source_id` 還需要額外的「不可重複」語意,單一 typeof 值無法完整表達
  這些規則,勉強塞入同一個資料結構反而會讓資料結構本身變得難懂。

## `size() == 0` 是可靠的失敗訊號,`== null` 不是——寫入本契約

`SaveTypeGate`/`SaveFormat` 的所有判定一律遵循這條規則,而不是把它當成單一函式裡的
特例:

| 判定方式 | 全零 16 bytes(合法 NIL 編碼) | 空 `PackedByteArray` | 截斷/偽造壞位元組 |
|---|---|---|---|
| `bytes_to_var()` 回傳值 | `null`,**無任何錯誤訊息** | `null`(`Condition "len < 4"` 系列) | `null`(各自的 `Condition ... ERR_INVALID_DATA/ERR_FILE_EOF`) |
| `== null` 能否區分「損毀」與「合法值」 | **不能** | 能 | 能 |
| `is Dictionary`(本契約規定的頂層型別)能否區分 | **能** | 能 | 能 |

**契約規則**:
1. 任何解碼路徑(`deserialize_block`/`deserialize_manifest`)在呼叫 `bytes_to_var()`
   之前,先檢查 `buffer.size() == 0`——這是一個可靠、無歧義的失敗訊號,因為
   `var_to_bytes()` 合法輸出的最短長度是 4 bytes(`null` 本身)、`{}`/`[]`/空
   `PackedByteArray` 皆 8 bytes,**合法編碼永遠不會是 0 bytes**。
2. 解碼後,一律用 `decoded is Dictionary` 判定成功,**絕不**用 `decoded != null`——
   全零 16 bytes 是合法的 NIL 編碼,`bytes_to_var()` 對它回傳 `null` 且零錯誤訊息,
   `!= null` 判定會把「一份全零的損毀檔案」誤判為「合法解碼成功」(因為 `null` 確實
   `!= null` 這個判斷本身沒有意義,正確心智模型是:`null` 本身就是一個可能的合法
   解碼結果,不能單靠「不是 null」來判斷成功,必須判斷「是不是我要的型別」)。
3. 寫入側 `var_to_bytes()` 之後檢查 `buffer.size() == 0`,視為 `DEPTH_EXCEEDED`(見
   上方「深度上限與循環引用」——已知唯一成因是循環引用繞過閘門直接抵達
   `var_to_bytes()`,理論上不可達,但保留作為備援)。

**證據**:`modules/core-serialization.md` 第 3 節「`size()==0` 是可靠的失敗訊號,
`== null` 不是」專節(探針 F2-e、探針 H-8);骨架驗證 C 讀取側逐字確認「全零 16
bytes(合法 NIL 編碼)」與「空 buffer」兩種輸入都被正確攔下(`README.md` 第 175-176 行)。

## 型別完整性斷言:39 個 Variant 型別逐一歸屬,不是數量相等

見上方「載入期完整性斷言」程式碼區塊的 `verify_type_table_partition()`。這裡重申
設計理由,避免日後有人「優化」掉逐一檢查、改回單純的數量比較:`ALLOWED_TYPES.size()
+ REJECTED_TYPES.size() == TYPE_MAX` 這條斷言,對「同時漏掉一個允許型別、又多加一個
拒絕型別」這種**成對抵銷**的錯誤完全無感——數量依然對得上,但分割本身已經出錯。
`verify_type_table_partition()` 改為逐一檢查 `range(TYPE_MAX)` 的每一個索引恰好落在
`ALLOWED_TYPES`/`REJECTED_TYPES` 兩者之一(不可同時屬於兩者,不可兩者都不屬於),
這才是規則本身要求的「每個型別都有一個明確歸屬」,而不是「兩堆東西的元素數量加
起來對」。

**證據**:骨架驗證 E,`README.md` 第 194-202 行(逐字):「規格逐字要求的載入期完整性
斷言(`允許.size() + 拒絕.size() == TYPE_MAX`)是必要條件、不是充分條件,而且對
『`TYPE_OBJECT` 被誤加進白名單』這個最壞的錯誤完全瞎」。

## 未查證項與待覆核

本節沿用 `docs/engine-reference/godot/modules/core-serialization.md` 與
`modules/scripting-typing.md` 已登記的「未查證」項目,不重複列出;以下是本節特有、
需要在下一輪覆核時特別確認的項目:

1. **release build 下型別閘門的行為**——本節全部設計依據的引擎行為(`bytes_to_var()`
   對 Object 的拒絕、`size()==0` 訊號、深度檢查所依賴的 GDScript 遞迴上限)皆只在
   debug/headless 下量測。**不宣稱**這些行為在 release build 下維持一致——這是
   已登記的開放項,由 ADR-0002/ADR-0003/ADR-0004 共用同一個缺口。
2. **~~`GateResult` 物件的安全前提僅靠程式碼審查紀律維持~~**——2026-08-24 已補上
   自動化緩解(`_walk`/`_walk_body` 拆分 + 深度回歸測試,見上方兩節),此項關閉。
   **殘餘、仍未查證**:遞迴呼叫誤寫成 `_walk_body()` 這個具體筆誤本身沒有專屬的
   靜態檢查(例如 lint 規則禁止在該檔案內出現 `_walk_body(` 於遞迴分支外的呼叫),
   目前完全依賴深度回歸測試在執行期抓到,不是編譯期。
3. **`MANIFEST_ENTRY_FIELDS` 是否需要在 CI 層面強制「陣列元素與 `_check_entry_field_types()`
   的分支一一對應」**——本節只做到把欄位名稱清單去重為單一常數,型別檢查分支的
   同步仍是人工紀律,未來若欄位數量增長,是否需要一個對照表或反射機制自動比對,
   留待 `/create-architecture` 決定。

## 交付摘要

本節定義的類別/檔案(概念契約,實作時可依需要拆分或合併,但語意不得改變):

- `save_type_gate.gd` — `SaveTypeGate`:常數(`MAX_PAYLOAD_DEPTH`、`ALLOWED_TYPES`、
  `REJECTED_TYPES`、`ALLOWED_KEY_TYPES`)、`GateRejection` 列舉、`GateResult` 類別、
  `scan()`/`scan_envelope()`/`verify_type_table_sum()`/`verify_type_table_partition()`/
  `self_check()`。
- `save_format.gd` — 新增 `MANIFEST_ENTRY_FIELDS` 共用常數;`serialize_block()`/
  `serialize_manifest()`/`deserialize_block()`/`deserialize_manifest()` 改為委派
  `SaveTypeGate` 做型別檢查,兩側共用同一份實作。
- `save_envelope.gd` — 新增 `SaveEnvelope`:`check_shape()`,依 2026-08-24 裁決不含
  額外鍵拒絕邏輯,必要鍵存在性/型別/雜湊長度/`source_id` 不重複四類檢查全部保留,
  必要鍵清單來自 `SaveFormat.MANIFEST_ENTRY_FIELDS`。
