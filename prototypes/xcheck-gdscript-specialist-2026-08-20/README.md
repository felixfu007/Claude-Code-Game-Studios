# 交叉驗證專案 — `godot-gdscript-specialist` 對 engine-verification spike 的獨立覆核

> **PROTOTYPE — NOT FOR PRODUCTION / 拋棄式技術驗證,不進 `src/`**
>
> **日期**:2026-08-20
> **作者**:`godot-gdscript-specialist`(**不是**協調者)。協調者只做了兩件事:
> 從 session 專屬的 scratchpad 搶救進 repo、以及寫這份 README。
> **探針與 runner 的每一行都是該 specialist 寫的。**
> **Status**:**in-progress** —— 未過濾的完整 log 重跑中,見下方「已知資料缺口」。

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

**未過濾的完整版重跑中**,將產出:
`logs/xcheck1-unfiltered.txt`、`logs/xcheck2-unfiltered.txt`、`logs/xcheck3-unfiltered.txt`、
`logs/global-script-class-cache-full.cfg`。

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

## 尚未查證,且它決定一句話能不能寫進 ADR

**全部測試都在 headless + debug 建置下進行。** export **release** 建置是否有相同的執行期
容器檢查**未測** —— 部分 `ERR_FAIL_COND` 系巨集在 release 會被編掉。

而 `F-3 層二`(執行期擋錯誤內建型別)的**全部證據**都是
`ERROR: Condition "!_p->typed_key.validate(...)" is true. Returning: false` 這個形狀,
那看起來就是 `ERR_FAIL_COND_V`。**若 release 建置把它編掉,ADR-0002 的「執行期會擋」
在出貨版本上就不成立,而那正是玩家實際跑的建置。**

已交回 specialist 判斷風險實質程度與可測性;結論將寫成 **ADR-0002 的 Verification Required
新項**,不當成已知。

---

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
