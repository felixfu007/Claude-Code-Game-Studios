# 交叉驗證專案 — `godot-gdscript-specialist` 對 engine-verification spike 的獨立覆核

> **PROTOTYPE — NOT FOR PRODUCTION / 拋棄式技術驗證,不進 `src/`**
>
> **日期**:2026-08-20
> **作者**:`godot-gdscript-specialist`(**不是**協調者)。協調者只做了兩件事:
> 從 session 專屬的 scratchpad 搶救進 repo、以及寫這份 README。
> **探針與 runner 的每一行都是該 specialist 寫的。**
> **Status**:**concluded** —— 未過濾完整 log 已歸檔(`logs/xcheck{1,2,3}-unfiltered.txt` + 完整
> class cache),`x8_mutable.gd` 已還原為有效版本。**唯一未查證項是 export release 建置**,
> 該項因環境無 export template 而在本專案範圍內不可測,見下方專節。

---

## 為什麼存在

`prototypes/engine-verification-spike-2026-08-20/` 的 18 個 `.gd` 探針**是協調者自己寫的,
那違反了 `.claude/docs/technical-preferences.md` 的 File Extension Routing 表**
(`.gd` → `godot-gdscript-specialist`)。使用者 2026-08-20 裁決要 specialist 回頭覆核。

該 specialist 沒有只讀程式碼 —— 它**另建了這個完全獨立的專案**:不同的 `project.godot`、
不同的 `.godot` 快取、不含 spike 任何檔案,只把 `affinity_types.gd` / `affinity_record.gd` /
`affinity_record_list.gd` 三檔**逐字複製**過來(F-6 的判定必須建立在同一份型別定義上)。

**目的是排除「spike 專案環境污染」這個變因** —— 若結論在一個乾淨的獨立專案裡也成立,
那就不是 spike 自己弄出來的假象。

---

## 覆核結果對 spike 的影響(摘要;完整判定見下方「結論歸屬」)

| spike 的結論 | 覆核判定 |
|---|---|
| F-2 / F-4 / F-6 / F-10 / F-11 / F-13 | **VALID** —— 可直接拿去改 ADR |
| **F-6**(BLOCKING) | **VALID 且更硬** —— 另補測 class member 無初始化 / 函式參數 / 回傳型別**三種形狀**,全部同一個 `Nested typed collections are not supported` |
| **F-9 (d)**「兩層型別都保住」 | **證據無效**(結論湊巧為真)—— spike 用 `get_class()`,那回傳**原生**類別,任何 `RefCounted` 子類都印 `Object(RefCounted)`,無法區辨,更沒碰到內層 |
| **F-9 (c)**「內層型別整個放棄」 | **結論是錯的** —— spike 測錯變因(存的是未型別化字面量)。實測存入 `Array[AffinityRecord]` 後讀回 `is_typed=true`。(c) 真正的代價是**不強制**,不是**無型別** |
| **F-3 層三**(enum 家族不擋) | 結論 VALID,但**推導鏈不成立、措辭過寬** —— spike 從未真的做過「錯家族 enum 鍵寫入」;且編譯器在**別的路徑確實擋** enum 家族。唯一的洞是型別化 Dictionary 的 **subscript 路徑** |
| **F-3** `cross_enum_family_size` | **INCONCLUSIVE** —— 測的是**未型別化** `{}`,不能推論到機制四用的型別化字典 |

### 順帶關閉的兩項(spike 未涵蓋)

- **ADR-0002 VR #5**(型別化 `Dictionary` 值槽在 subscript 賦值下能否推斷元素型別):
  `X9e` 實測 `subscript_assigned_literal_is_typed = false` → **不推斷**。
- **四個容器內省 API 在 4.7.1 全部存在**:`is_typed_key` / `is_typed_value` /
  `get_typed_key_builtin` / `get_typed_value_builtin`,後兩者回傳 `2`(`TYPE_INT`)。
  **`get_typed_key_builtin() == 2` 是「enum 家族在容器層被抹成 int」最短、最直接、
  無附帶條件的證據** —— spike 繞一大圈從錯誤訊息字串推導的東西,答案在這裡一行就有。
  (spike 的 `a1_introspect.gd` 寫了同樣四個方法名,但**從未被呼叫**。)

---

## ⚠️ 已知資料缺口(讀 log 之前必看)

**`logs/xrun2-XCHECK1-FILTERED.txt` 不是原始 stdout。** 它經過:

```
| grep -v "GDScript backtrace\|^ *\[[0-9]\] \|^   at: "
```

被剝掉的是 backtrace 標頭、`[0]`~`[4]` 堆疊格、`at: <file>:<line>` 定位行。
**`SCRIPT ERROR:` / `ERROR:` 的訊息本體全部保留。** 剝除理由是輸出量,不是取捨證據 ——
但**若要驗證錯誤的發生位置(哪一行、哪個函式),這份 log 不足,必須重跑**。

`logs/xrun1-no-class-cache-FAILED-unfiltered.txt` 是**未過濾**的,但那是**失敗的一輪** ——
新專案沒有 `.godot/global_script_class_cache.cfg`,所有 `class_name` 都
`Could not find type ... in the current scope`。保留它的價值見下方「對 CI 的意義」。

**未過濾的完整版已歸檔**,四份檔頭皆自帶指令原文、exit code 與判讀陷阱,
下一輪覆核者不需回頭讀對話:

| 檔案 | 內容 |
|---|---|
| `logs/xcheck1-unfiltered.txt` | XCHECK-1 完整未過濾,含全部 `at:` 定位行與 backtrace |
| `logs/xcheck2-unfiltered.txt` | **單一連續 process**,含 X9 完整段落,無 tail/head 裁切 |
| `logs/xcheck3-unfiltered.txt` | XCHECK-3 完整未過濾 |
| `logs/global-script-class-cache-full.cfg` | 完整檔,無 head 裁切 |

**只有未過濾版才看得到的一項新資訊**:X9 的 parse error 定位是
`res://scripts/x9_adr_member_exact.gd:2` —— **第 2 行就是 `var _records:` 那一行本身**。
過濾版把這個資訊剝掉了。**這讓 F-6 的因果更緊:錯誤不在檔案別處。**

### 判讀陷阱兩則(specialist 自陳)

1. **`xrunner.gd` 的 `_try()` 無條件印 `(NOT aborted)`** —— 那是固定字串,不是判定結果。
   **判讀必須看 `returned` 後面有沒有內容。** X3r outer 那行 `returned  (NOT aborted)`
   其實**中止了**(`-> String` 的零初始化空字串)。
   **這與 specialist 在 spike 抓到的 N-3 是同型缺陷,它自己也犯了。**
2. **X3r inner 那行是真的沒中止**(`append` 是方法呼叫而非賦值),`items.size=0` 是真實讀值
   —— 那才是「寫入被丟棄」的直接證據。

---

## 怎麼跑

```bash
GODOT=/c/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe
PROJ=prototypes/xcheck-gdscript-specialist-2026-08-20

# 必須先建 global_script_class_cache,否則全部 class_name 解析失敗
"$GODOT" --headless --path "$PROJ" --editor --quit

"$GODOT" --headless --path "$PROJ" --quit-after 300                          # XCHECK-1
"$GODOT" --headless --path "$PROJ" res://scenes/X2.tscn --quit-after 300     # XCHECK-2
"$GODOT" --headless --path "$PROJ" res://scenes/X3.tscn --quit-after 300     # XCHECK-3
```

**前置**:`scripts/x8_mutable.gd` 在磁碟上可能是被 runner **覆寫後的壞版本**
(X8 那項的測法就是執行期覆寫同一路徑)。重跑前須還原為:

```gdscript
class_name XMutableProbe extends RefCounted
func fine() -> int:
	return 1
```

`project.godot` 已設 `run/flush_stdout_on_print=true` —— **不可省**,否則 `print()`
會被緩衝,程式不退出就一個字都看不到。

---

## 對 CI 的意義(N-8)

`xrun1` 那一輪的失敗是一項**對 CI 有實質影響的環境事實**:**乾淨 checkout 沒有
`.godot/global_script_class_cache.cfg`,所有 `class_name` 都無法解析。** 必須先跑一次
`--headless --editor --quit`(或 `--import`)。

`.github/workflows/tests.yml` 用乾淨 checkout 跑 headless 時會踩到同一件事 ——
`project.godot` 一進 repo、CI 守衛放行之後,這會是第一個失敗原因。

---

## 尚未查證:export release 建置(**跨 ADR-0002 / ADR-0005 的共同待驗證項**)

全部測試都在 **headless editor(debug)建置**下進行。**必須拆成兩層,兩層的風險等級與受影響的 ADR 都不同**:

| 層 | 現象 | 證據原文與位置 | 誰依賴它 | 風險 |
|---|---|---|---|---|
| **A** C++ 容器驗證 | **寫入被丟棄**,`set()` 回傳 false | `Condition "!_p->typed_key.validate(key, "set")" is true. Returning: false` @ `core/variant/dictionary.cpp:205`;`Attempted to set a variable of type 'String' into a TypedDictionary.Key of type 'int'.` @ `core/variant/container_type_validate.h:73` | **ADR-0002 機制四**(F-3 層二) | **低-中** |
| **B** GDScript VM 錯誤處理 | 拋 `SCRIPT ERROR` 並**中止所在函式** | `Invalid assignment of property or key 'not_an_enum' ... on a base object of type 'Dictionary[int, int]'` | **ADR-0005 的 F-10 / S-1 必要性論證** | **中-高** |

**F-3 層二要的是 A,不是 B。** 「寫入被丟棄」是 A;「會噴錯誤並中止」是 B。

### 層 A:證據等級「訓練資料推論,未查證」

`ERR_FAIL_COND_V` 屬 `core/error/error_macros.h`,依 specialist 訓練資料該族為**無條件編譯**(唯一被建置組態閘門的是 `DEV_ASSERT`)。**關鍵論證**:`ERR_FAIL_COND_V(cond, false)` 的 `return false` 與錯誤列印在**同一個巨集內** —— 若巨集被編掉,`return false` 也消失、寫入照樣進行。**兩者綁在一起,不會出現「不印但仍擋」或「印了但不擋」。**

**三項限制(明文記錄)**:(1) specialist 知識截止於 4.7 之前,`container_type_validate.h` 在 4.7 有沒有被加 `#ifdef DEBUG_ENABLED` **不知道**;(2) 無 4.7.1 C++ 原始碼可查;(3) 無 release build 可實測。

### 層 B:真正該擔心的,而且它打到的是 ADR-0005

GDScript VM 的執行期錯誤回報有相當部分是 `#ifdef DEBUG_ENABLED` 閘門的。**若 B 在 release 被編掉,「賦值失敗會中止所在函式」在出貨版本可能不成立** —— 變成靜默失敗、函式繼續往下跑。

**F-10 判定三**(「對已釋放物件 `call()` 會讓所在函式整段中止 → S-1 的 `is_valid()` 守衛從防禦性冗餘升格為必需」)靠的正是 B。若 release 不中止,**該論證的方向反轉**:守衛依然該留(取到的座標是垃圾),但理由從「防止函式被砍斷」變成「防止用到垃圾值」。而且 **debug 與 release 行為不一致本身是更大的問題 —— 會出現「debug 測得出、release 測不出」的 bug。**

### 為什麼本輪不能測(已查證的環境事實)

```
ls -la %APPDATA%/Godot/export_templates/     → 目錄存在,完全是空的
find Downloads AppData -iname "*.tpz" ...    → 零命中
grep -rni "release build|DEBUG_ENABLED|ERR_FAIL" docs/engine-reference/godot/
  → 全庫僅兩行,皆為「4.5+ script backtracing 在 Release 亦可用」
    微弱支持「錯誤回報基礎設施在 release 存在」,完全不回答「檢查本身是否存在」
```

**協調者已獨立複核以上三項,全部成立。** 另排除三條便宜替代路:`--headless` 只換 DisplayServer 不換建置組態;`OS.is_debug_build()` 只回報當前建置、不能切換;沒有 release template binary 可直接跑。

**唯一決定性測法**:下載 export template(約 1 GB,**使用者決定**)→ 匯出 Windows release(取消 Export With Debug)→ 以本專案 X2 / X3r / X6 重跑。

### 比手動測一次更有價值的一件事(免費)

**把探針改成建置無關。** 現在的探針把「有沒有印出錯誤」和「寫入有沒有被丟棄」混在一起 —— 那正是 N-3 的病根。建置無關的探針**只量容器內容**:

```gdscript
var d: Dictionary[AffinityTypes.Pair, int] = ...   # caller 持有
_write_bad_key(d)                                   # 中止或不中止都無所謂
assert_eq(d.size(), 0)                              # ← 唯一的判準
```

同一支測試在 debug 與 release 下都直接產出答案,且可掛進 CI 的 release-export job 成為**永久回歸測試**,而非一次性查證 —— 這個行為在未來每個 Godot patch 版本都可能變。

### 最重要的一點:ADR-0002 不該讓正確性掛在這個答案上

理由是 ADR 系列自己反覆主張的那條:**結構保證優於紀律要求**,而「引擎的容器檢查會擋」是**引擎給的 backstop,不是專案的結構保證** —— 建置組態行為未查證、版本間可能變、且**測不到出貨版本**。

**好消息:結構保證已經存在,只是還沒寫進 ADR。** `x1b` / `x1c` 證明 GDScript 編譯器**確實**強制 enum 家族(`Character` 不能賦給 `Pair`;`Dictionary[Character,int]` 不能賦給 `Dictionary[Pair,int]`)。唯一的洞是型別化 Dictionary 的 **subscript** 路徑。因此機制四該寫的是:

> 所有外部進入 `_records` / `_death_marks` 的鍵一律經 `func x(pair: AffinityTypes.Pair)` 這類**型別化參數邊界**;**禁止**把外來 `Variant` 直接當 subscript 鍵。前者的編譯期強制已實證(`x1b`/`x1c`),後者是唯一已知的靜態檢查空隙(`x1`)。

這樣層 A 在 release 成不成立就降級為**縱深防禦** —— 與 ADR-0002 C3 修訂對 `Mutex`、ADR-0004 對 `SaveIOBackend` 是**同一個手法**。建議登記 forbidden pattern:`raw_variant_subscript_into_typed_container`。

### 最壞影響:不是崩潰,是靜默存檔損壞,且出貨版本專屬

1. 錯誤型別的鍵/值被**靜默寫入** `_records`(無錯誤、無中止、`size()` 增加)
2. 四個讀取函式迭代到型別不符的元素 → 公式一/二產生 NaN 或執行期爆,**爆點離寫入點很遠**,極難追
3. 壞值經 ADR-0003 的 `var_to_bytes()` 寫進存檔,**通過兩層 SHA-256 雜湊鏈** —— 雜湊驗的是位元組完整性,不是語意合法性。**存檔在位元層完全合法、在語意層已損壞**
4. ADR-0003 的 `validate_semantics()` 是唯一防線,而**它目前的檢查範圍未涵蓋「容器元素型別」**

**第 4 點是連帶挖出的跨 ADR 缺口,值得單獨記**:不論層 A 答案為何,`validate_semantics()` 都應納入「`_records` 每個鍵是合法 `Pair` 序數、每個值是 `AffinityRecordList`、其 `items` 每個元素是 `AffinityRecord`」。那是 app 層、與建置組態無關的防線,而 ADR-0003 的整個設計哲學(「結構上不可能產生自訂 `Object`」)本來就走這個方向。

## specialist 自陳的其餘弱點

1. **X6 只測了 `-> Dictionary` 一種回傳型別。** 「中止後 caller 收到依宣告型別零初始化的值」
   在 `-> String` 上有間接支持,但未系統性測過 `-> int` / `-> Vector2` / 無回傳型別註記。
2. **X2 只用了一個序數值**(`CHARACTER_3` = 2)。`Pair` 有 10 個成員、`Character` 只有 5 個,
   所以測試值永遠落在範圍內 —— **「若 enum 值超出目標家族的序數範圍是否仍被接受」未測**。
3. **X7 沒測反方向**:未型別化 Array 存進 `Dictionary[Pair, Array]` 後,能否再被當成
   `Array[AffinityRecord]` 讀出來用。(c) 若真要採,這一項要補。

---

## 結論歸屬(下一輪覆核者請從這裡開始)

| 要引用的結論 | 證據在哪 | 可信度 |
|---|---|---|
| F-6 BLOCKING(巢狀型別容器不支援) | `x9_adr_member_exact.gd` 第 2 行**與 ADR-0002 第 114 行逐位元組相同**(協調者已獨立核對);三種形狀輸出見 XCHECK-2 | **高** —— 兩個獨立專案重現 |
| (d) 兩層型別都保住 | `x3_wrapper_two_layer.gd` `inspect()` 的四列輸出 | **高** —— 但**不可引用 spike 的「值型別 = Object(RefCounted)」那一列** |
| (c) 不強制而非無型別 | `x7_typed_inner_in_bare_slot.gd` 三列輸出(含刻意保留的未型別化對照) | **高** |
| 層三:subscript 路徑不擋 enum 家族 | `x2_runtime_crossfamily.gd`,輸出 `NOT ABORTED size=1 keys=[2]`,**零錯誤訊息** | **高** |
| 層三的機制:容器層鍵型別被抹成 int | `x4_dict_introspect.gd`,`get_typed_key_builtin = 2` | **高** —— 比錯誤訊息字串推導乾淨 |
| 編譯期**確實**擋 enum 家族 | `x1b` / `x1c` 的 parse error 原文 | **高** |
| 層二:執行期擋錯誤內建型別 | `Returning: false` 系訊息 | **中** —— **release 建置未測,見上** |
| 中止只影響一格、不傳染上層 | XCHECK-1 兩次 `_try` 各自獨立、RISKY 2 照跑 | **高** |
