# 存檔格式設計骨架(2026-08-21)—— 設計層驗證,不是探針

**目的**:把委派任務「設計規格」節的整套存檔格式**寫成可執行的骨架並實機跑起來**,
用途是**現在就把設計錯誤逼出來**,而不是驗證某一個引擎 API。

**理由**(逐字引用委派):探針 E 的教訓是「各型別分別通過 ≠ 該組合通過」,
而**整份設計就是最大的那個組合**。本專案五份技術設計文件停在草案、四天改九次、
`src/` 至今零行程式碼,所有回饋都來自「讀文件」與測單一 API 的探針。

**執行者**:`godot-gdscript-specialist`。**引擎**:`Godot 4.7.1.stable.official.a13da4feb`,headless。
**三階段全部 exit code 0**(逐字見下)。**骨架是拋棄式的**,放 `prototypes/`,與 `src/` 隔離。

**狀態:concluded**(2026-08-21)。驗證 A~G 全部執行完畢,findings 見本檔末的四類分類。
依 `.claude/rules/prototype-code.md`:本骨架**不得**被 `src/` 引用、**不得**直接搬進生產,
若相關設計進入實作階段,必須依生產標準重寫,本目錄僅供參考且**不再擴充**。

**待測試的假說**:「委派任務『設計規格』節所描述的整套存檔格式,能否寫成可執行、
且在真實檔案 I/O 與跨行程情境下行為正確的程式?」——
結論:**大部分成立(13 項),但推翻 7 項、並暴露 16 個文件層的洞。**

> ### 🔴 本骨架推翻的設計內容(摘要,詳見下方 (b) 節)
>
> 1. **兩個 `==` 相等的 `Dictionary`(相同鍵值、不同插入順序)`var_to_bytes()` 出來的位元組不同。**
>    而 ADR-0003 機制四的頂層雜湊輸入 `block_manifest` 的條目型別是 `Dictionary`。
>    ADR 明文宣稱「不依賴容器迭代順序」,但它只處理了**區塊之間**的順序,
>    沒處理**條目內部鍵**的順序 → 邏輯相同的 manifest 會算出不同雜湊 → 誤判資料損毀。
> 2. **`RID` 的 id 跨行程完全相同,而且在新行程裡指向一個「剛好占用同號碼」的真實活體資源。**
>    行程 1 存 `94489280512`,行程 2 第一個 `body_create()` 也是 `94489280512`,
>    `還原的RID == 本行程新配的RID` 為 **`true`**。這是探針 F/G 都標為「最壞情況、未測」的那一格,
>    實測**成立且具決定性**(不是機率碰撞)。
> 3. **規格逐字要求的載入期完整性斷言(`允許.size() + 拒絕.size() == TYPE_MAX`)是必要條件、
>    不是充分條件**,而且對「`TYPE_OBJECT` 被誤加進白名單」這個最壞的錯誤**完全瞎**。
> 4. **循環引用的兩條防線只有一條可達** —— 規格鎖定「先閘門、再 `var_to_bytes`」,
>    所以「斷言 `buffer.size() > 0`」那一條在設計上永遠看不到循環引用。
> 5. **驗證器 `Callable` 不會讓它綁定的 `RefCounted` 續命** —— 擁有者被回收後
>    `is_valid()` 變 `false`,fail-closed 把「有人忘了留參照」變成「**所有存檔都損毀**」。

---

## 如何重跑

```bash
# Godot 執行檔不在 PATH 上
GODOT="$HOME/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"

# 每一階段都必須先建 class cache(本骨架有 8 個 class_name)
"$GODOT" --headless --path . --editor --quit
"$GODOT" --headless --path .
```

**切換階段的方式是改 `project.godot` 的 `run/main_scene`,不是傳參數**
(沿用 `prototypes/xcheck-adr0003-2026-08-21` 的作法):

| 階段 | main_scene | runner | 內容 | exit code |
|---|---|---|---|---|
| 0 | `res://scenes/Stage0.tscn` | `runner_stage0.gd` | 形狀前置量測(pre1~pre6、x1~x3) | STEP1 **0** / STAGE0 **0** |
| 1 | `res://scenes/Run1.tscn` | `runner_run1.gd` | x4、驗證 E/A/D/B/C/G、F 寫檔、H | STEP1 **0** / RUN1 **0** |
| 2 | `res://scenes/Run2.tscn` | `runner_run2.gd` | **獨立行程**:驗證 F 讀檔、追加 I | STEP1 **0** / RUN2 **0** |

本目錄提交時 `main_scene` 停在 `res://scenes/Run2.tscn`(最後執行的一支)。

**為何拆三階段**:階段 0 的結果決定骨架「該怎麼下筆」——
`save_format.gd` 同時用到 39 個 `TYPE_*` 識別字、`static var`、
`const Dictionary` 以 enum 常數當鍵、內部類別的型別化欄位參照外層 enum。
這四項任一不成立就是**整檔 Parse Error,一個測項都跑不出來**,
而失敗形狀是「整段沒有輸出」。階段 1/2 必須拆開,因為驗證 F 的定義就是**跨兩次執行**。

## log 歸檔(全部未過濾)

| 檔案 | 內容 |
|---|---|
| `logs/stage0-unfiltered.txt` | 階段 0 —— 形狀前置量測(含 STEP1 完整輸出) |
| `logs/run1-unfiltered.txt` | 階段 1 —— 驗證 A/B/C/D/E/G + F 寫檔 + H(408 KB,其中約 7,200 行是循環引用的引擎錯誤串) |
| `logs/run2-crossprocess-unfiltered.txt` | 階段 2 —— **獨立行程**的驗證 F + 追加 I |

**執行者自陳:三份 log 皆為 `2>&1` 合併重導,未經 `grep`/`head`/`tail` 過濾或截斷。**
`run1` 之所以有 408 KB,是因為 `var_to_bytes(循環 Dictionary)` 這一個**對照組**呼叫
產生了 1 次 `Potential infinite recursion detected. Bailing.` 加 **1,025 次**
`Condition "err" is true`(每層巢狀各一次,含完整 GDScript backtrace)——
**這本身就是一項量測結果**:循環引用若真的走到 `var_to_bytes`,log 會被淹掉。

---

## 階段 0 —— 形狀前置量測(規格逐字要求的 GDScript 形狀)

| # | 待答 | 結果 |
|---|---|---|
| **pre1** | 39 個 `TYPE_*` 識別字是否都存在 | ✅ 全部 **COMPILED OK**。`TYPE_MAX = 39`;允許 35(0–22、27–38)+ 拒絕 4(23–26)= **39**,規格的分割在 4.7.1 剛好完整 |
| **pre2** | `static var`(D 的解碼計次器需要它) | ✅ 可用。3 次 bump → 3,reset → 0 |
| **pre3** | `FileAccess.open/store_buffer/close/get_buffer` | ✅ 全部存在。`close()` 後 `is_open()` 為 `false`;6 bytes 往返 identical |
| **pre4** | **內部類別的型別化欄位參照外層 enum**(規格逐字要求的 `rejection: PayloadRejection = PayloadRejection.NONE`) | ✅ **成立**。預設值、指派、以及內部類別讀取外層 `const` 皆正常 |
| **pre5** | `const Dictionary` 以 `TYPE_*` 當鍵 + `has()`/`size()` | ✅ 可用。`is_read_only()` 為 **`true`**(唯讀),手工複製迴圈可得可變副本 |
| **pre6** | `const Dictionary.duplicate()` 是否可變 | ✅ **是**,`is_read_only()` 為 `false`。(驗證 E 因此有兩條可行路徑) |
| **x1** | 型別化容器往返後還型別化嗎 | ✅ **是**。`Array[int]` 往返後 `is_typed()=true`、`get_typed_builtin()=2`、`== 來源`;**直接指派回 `Array[int]` 變數不會中止**;`assign()` 亦可 |
| **x2** | `StringName` 鍵往返後能否以 `String` 查到 | ✅ **能**。鍵的 `typeof` 保住(21 / 4 各自不變),但 `has("alpha")` 與 `has(&"alpha")` **四種組合全部 `true`** —— String 與 StringName 在 Dictionary 查詢上互通 |
| **x3** | `var_to_bytes` 是否隨 `Dictionary` 鍵插入順序改變 | 🔴 **會改變**。見下方 (b)-1 |
| **x4**(在階段 1) | 兩個未查證的型別標註形狀 | ✅ 皆成立:(i) 內部類別欄位標成**另一個** `class_name` 的 enum;(ii) 區域變數標成另一個 `class_name` 的**內部類別** |

---

## 階段 1 —— 逐測項結果

**全部 18 個檔案 `COMPILED OK`**(呼叫任何東西之前先逐檔 compile-check,
`ResourceLoader.load(..., CACHE_MODE_IGNORE)` + `reload()` 的 `Error`)。

### 驗證 A —— 完整往返走真實檔案 ✅

| 量測 | 結果 |
|---|---|
| 寫入 | `SaveWriter.build` 信封 **9,296 bytes**(60 筆記錄 + 第二區塊) |
| 檔案 | 寫 `user://slot_a.sav` → `close()` → 重新 `open(READ)` 讀回 |
| 位元組 | 讀回 9,296 bytes,**與記憶體緩衝區 byte-identical** |
| 讀取 | `read_full` status=OK,`blocks_decoded=2` |
| 正規順序 | `["affinity_data_pool", "tactical_board"]`(字典序) |
| **逐欄位比對** | **ALL FIELDS IDENTICAL** —— 60 筆 × 5 欄位逐一比對值**與 `typeof`**,`campaign_tick_marks` 含 `is_typed()` 比對,`death_marks` 逐鍵比對 |

期望值由**同一個決定性產生器重新產生**(零 RNG),不是拿讀回來的值跟自己比。

### 驗證 B —— 失敗注入:每一種都落在正確那一關 ✅ 6/6(+3 追加)

全部注入都**繞過寫入側**(改解碼後的信封再 `var_to_bytes` 重編),因為真實損毀不會經過組裝器。

| # | 注入 | 攔在 | `blocks_decoded` | 規格要求 | 相符 |
|---|---|---|---|---|---|
| ① | 翻轉 `blocks['affinity_data_pool'][1512]`(99→156),manifest 的 `block_hash` 不動 | **S4 逐區塊雜湊** | 0 | 逐區塊雜湊 | ✅ |
| ② a | `format_version` 3→4,payload 不動 | **S2 頂層雜湊** | 0 | 頂層雜湊 | ✅ |
| ② b | `source_id` → `affinity_data_poo1` | **S2 頂層雜湊** | 0 | 頂層雜湊 | ✅ |
| ③ | 從 manifest 移掉整個條目(blocks 位元組留著) | **S2 頂層雜湊** | 0 | 頂層雜湊 | ✅ |
| ④ | `ruleset_version=9` > 遊戲 5 | **S3 版本比對** → `VERSION_TOO_NEW` | 0,且 **`bytes_to_var` 呼叫次數 = 1** | 不解碼任何區塊 | ✅ |
| ⑤ | 驗證器未登記(刻意留空的登記表) | **S6** → `DATA_CORRUPTED` | 1 | fail-closed | ✅ |
| ⑥ | `records[0].c = 99`(型別合法、值域不合) | **S6** → `SEMANTIC_INVALID`,detail 指名 `records[0].c 超出值域 0..3: 99` | 1 | 語意失敗 | ✅ |
| ③b 追加 | 反方向:`blocks` 條目被 erase、manifest 留著 | **S4**,detail 明說「頂層雜湊涵蓋不到這件事」 | 0 | 規格沒講 | 見 (c)-4 |
| B7 追加 | `block_manifest` 被換成 `int` | **S1B 形狀** | 0 | 規格沒講 | 見 (c)-1 |
| B7b 追加 | `top_level_hash` 整個消失 | **S1B 形狀** | 0 | 規格沒講 | 見 (c)-1 |
| B7c 追加 | manifest 出現重複 `source_id` | **S1B 形狀** | 0 | 規格沒講 | 見 (c)-5 |

⚠️ 注意 ⑤ 與 ⑥ 的 `blocks_decoded=1`:**規格鎖定的順序讓區塊在驗證器之前就已被解碼**。
「未登記的區塊」這件事**無法**在解碼之前發現(因為要先有 `source_id` 對應的 payload
才輪到 registry)。fail-closed 成立,但它不是「不解碼」。

### 驗證 C —— 毒藥向量 × 兩側 ✅

**寫入側**(`serialize_block`):

| 向量 | rejection | `offending_path` |
|---|---|---|
| 對照組(乾淨) | NONE | (空),80 bytes |
| **值**是 `Object` | FORBIDDEN_TYPE | `payload["poison"] <typeof=24>` |
| **值**是 `Resource` | FORBIDDEN_TYPE | `payload["poison"] <typeof=24>` |
| **鍵**是 `Object` | FORBIDDEN_TYPE | `payload.<KEY typeof=24>` |
| **鍵**是 `Vector2i`(非容器、非白名單鍵) | FORBIDDEN_TYPE | `payload.<KEY typeof=6>` |
| **鍵**是 `Array`(容器當鍵) | FORBIDDEN_TYPE | `payload.<KEY typeof=28>` |
| `Signal` | FORBIDDEN_TYPE | `payload["s"] <typeof=26>` |
| `RID` | FORBIDDEN_TYPE | `payload["r"] <typeof=23>` |
| `Callable` | FORBIDDEN_TYPE | `payload["c"] <typeof=25>` |
| `Object` 藏在第 3 層 | FORBIDDEN_TYPE | `payload["a"]["b"][1] <typeof=24>` |

深度:`MAX_PAYLOAD_DEPTH=64`。巢狀 10/62/63 → NONE;**64/65/100 → DEPTH_EXCEEDED**。
(本骨架的 `_nested(d)` 讓最深的**值**位於深度 `d+1`,故實際可過的最大值深度就是 64,與 `depth > MAX` 一致。)

循環引用:`{self: 自己}` → **DEPTH_EXCEEDED**,`offending_path` 是 65 層 `["self"]` 疊出來的字串;
`Array` 自我參照同樣 DEPTH_EXCEEDED。**對照組**:直接 `var_to_bytes(循環 Dictionary).size() = 0`
(並吐出 1,025 行引擎錯誤)。→ 見 (b)-4。

**讀取側**(`deserialize_block`,全部繞過寫入側直接構造毒位元組):

| 毒位元組 | 擋住了嗎 | 由哪一道 |
|---|---|---|
| plain 編的 `Object`(`EncodedObjectAsID`) | ✅ DATA_CORRUPTED | **對稱型別閘門**(`payload["poison"] <typeof=24>`) |
| plain 編的 `Resource` | ✅ | 同上 |
| `_with_objects` 編的 `Object` | ✅ | `bytes_to_var` 回 NIL → `is Dictionary` 判定失敗 |
| **鍵**是 `Object`(plain) | ✅ | 對稱閘門(`payload.<KEY typeof=24>`) |
| `Signal` / `RID` / `Callable` | ✅ ✅ ✅ | **對稱閘門**(引擎完全不擋) |
| 深度 100 | ✅ | 對稱閘門的 DEPTH_EXCEEDED |
| **全零 16 bytes**(合法 NIL 編碼) | ✅ | `is Dictionary` 判定(`!= null` 會漏) |
| 空 buffer | ✅ | size 0 前置檢查 |
| 頂層是 `Array` 而非 `Dictionary` | ✅ | `is Dictionary` 判定 |

**「讀取側必須再跑一次同一組型別閘門」這條規格要求,實測是必要的而非贅餘**:
plain `var_to_bytes` 寫出的 `EncodedObjectAsID`、以及 `Signal`/`RID`/`Callable`
這四種位元組,`bytes_to_var()` **一律靜默成功**,只有我們自己的閘門會擋。

### 驗證 D —— manifest-only 真的沒解碼區塊 ✅(計數器證明)

`SaveFormat._decode()` 是全骨架**唯一**的 `bytes_to_var()` 呼叫點,包一層 `static var` 計次。

| 路徑 | `decode_calls` | `blocks_decoded` | manifest 讀到了嗎 |
|---|---|---|---|
| `read_manifest_only` | **1** | 0 | ✅ `ruleset_version=5`、2 個條目、ids 齊全;`payloads.size()=0` |
| `read_full` | **3**(= 1 + 2 區塊) | 2 | ✅ |

外層解碼後 `blocks['affinity_data_pool']` 的 `typeof=29`(PACKED_BYTE_ARRAY)、**4,416 bytes 未解碼**。

### 驗證 E —— 白名單完整性斷言 ⚠️(擋得住規格設想的情境,但對更壞的情境瞎)

| 情境 | `size` 和 | 規格那一條斷言 | 較強那一條 |
|---|---|---|---|
| 現行(正確)表 | 35+4=39 | ✅ true | ✅ 通過 |
| **拿掉 `TYPE_COLOR`** | 34+4=**38** | **false(擋住)** | 抓到「typeof=20 兩個集合都沒列到」 |
| **拿掉 `TYPE_COLOR`、同時把 `TYPE_OBJECT` 誤加進允許集合** | 35+4=**39** | 🔴 **true —— 完全沒看到** | 抓到 |

→ 見 (b)-3。

### 驗證 G / 追加 I —— 成本

500 筆記錄的單槽:編碼後區塊 **69,744 bytes(68.1 KB)**,信封 **70,456 bytes**。

| 項目 | Run 1(冷) | Run 2(熱,3 次) |
|---|---|---|
| 產生 payload | 1.82 ms | — |
| **型別閘門(規格形狀)** | **20.57 ms** | 17.87 / 25.78 / 19.09 ms |
| **型別閘門(精簡實作)** | — | **3.26 / 4.24 / 2.45 ms** |
| `var_to_bytes` | 1.32 ms | 1.76 / 1.84 / 1.44 ms |
| SHA-256 | 0.44 ms | — |
| `SaveWriter.build` 全程(2 區塊 + 兩層雜湊 + 信封) | 43.51 ms | — |
| 檔案寫入 | 42.53 ms(**冷**) | **8.54 / 7.82 / 6.57 ms** |
| 檔案讀取 | 29.47 ms(**冷**) | **1.70 / 2.53 / 1.52 ms** |
| `read_manifest_only` | **0.54 ms** | — |
| `read_full` | 66.14 ms | **18.91 / 19.39 / 22.23 ms** |
| └ 其中讀取側型別閘門 | 19.87 ms(**30% of read_full**) | — |
| └ 其中語意驗證器 | 1.75 ms(2.6%) | — |

**結論:整條路徑的最大單項成本是型別閘門,而且 85% 的閘門成本是「實作形狀」而非「語意」。**
熱狀態下存檔約 **25 ms**、讀檔約 **21 ms**、manifest-only **0.5 ms**。→ 見 (c)-9。

### 追加 H —— 驗證器 `Callable` 的生命期 🔴

| 量測 | 結果 |
|---|---|
| 函式內(擁有者仍在作用域) | `is_valid=true`,`get_object()=<RefCounted#...>` |
| **函式外(擁有者離開作用域)** | `typeof=25` 仍是 Callable、`get_method()` 仍是 `validate_semantics`,但 **`is_valid()=false`、`get_object()=<Object#null>`** |
| 拿這個登記表跑 `read_full` | `DATA_CORRUPTED`,攔在 S6,detail「驗證器 Callable 已失效」 |
| 重複登記同一 `source_id` | 骨架的 fail-loud 生效:`push_error` + 保留第一個(`get_method()` 仍是 `validate_semantics`) |
| `get_validator('never_registered')` | `<null>`,`typeof=0` |

---

## 階段 2 —— 驗證 F:跨兩次執行(關掉探針 F 未查證 #5 / 探針 G 未查證 #1)

行程 1 寫檔並讓來源物件被回收;**行程 2 是獨立行程**,讀同一批 `user://` 檔案。

### F-1 `EncodedObjectAsID`(plain 寫入側靜默編出的 ObjectID)

| 量測 | 結果 |
|---|---|
| 行程 1 的 `instance_id` | `-9223371889668258322`(低 32 bits = 1157629422) |
| 行程 2 讀出的 `object_id` | **完全相同** —— 號碼**確實**跨行程寫進了檔案 |
| 欄位 | `marker` = `<null>`(靜默資料遺失,與探針 G 的 G-2b 一致) |
| `instance_from_id(舊 id)` **churn 之前** | **`null`,不中止** |
| `instance_from_id(舊 id)` **churn 之後**(配置 2,000 個物件並保持存活) | **仍 `null`**。新物件的 slot 範圍 318768585..3791654312 **涵蓋**舊 slot 1157629422,但**沒有任何新物件的完整 id 等於舊 id** |
| 骨架的閘門 | `deserialize_block` → **DATA_CORRUPTED**,`payload["obj"] <typeof=24>` |

**判讀**:ObjectID 的高位 validator 計數讓「同號碼被別人占用」在跨行程**沒有發生**
(2,000 次配置、slot 範圍覆蓋仍不重現)。**但這是觀察到的行為,不是保證** ——
見 (d)-2。

### F-2 `Signal`(同行程曾經是**全功能**的那一個)

| 量測 | 行程 1(探針 G 已測) | **行程 2(本次新測)** |
|---|---|---|
| `typeof` / `is Signal` | 26 / true | 26 / true |
| `get_name()` | `pinged` | **`pinged`(名字還在)** |
| `get_object_id()` | 與來源相同 | **與行程 1 的來源 id 完全相同** |
| `is_null()` | — | **`false`(⚠️ 說自己不是空的)** |
| `get_object()` | **活體物件** | **`<Object#null>`** |
| `connect()` | `0`(OK) | **`3` = `ERR_UNCONFIGURED`**,並報 `Parameter "obj" is null.` |
| `emit()` | **處理函式真的執行** | **沒送達**(`ping_count` 停在 0) |

**判讀:`Signal` 跨行程是惰性的 —— 危險程度從「全功能物件」降為「指向 nothing」。**
⚠️ 但 `is_null()` 回 **`false`** 而 `get_object()` 回 `null`:**`is_null()` 不能當守衛**。

### F-3 🔴 `RID` —— **這一格就是「最壞情況」,而且實測成立**

| 量測 | 結果 |
|---|---|
| 行程 1 存下的 `RID.get_id()` | `94489280512` |
| **行程 2 第一個 `PhysicsServer2D.body_create()`** | **`94489280512` —— 完全相同** |
| 還原出來的 RID | `is_valid=true`、`get_id=94489280512`、與行程 1 相同 |
| **`還原的RID == 本行程剛配的RID`** | **`true`** |
| 骨架的閘門 | `deserialize_block` → **DATA_CORRUPTED**,`payload["rid"] <typeof=23>` |

**判讀**:RID 沒有 validator 計數這種保護。伺服器從乾淨狀態起算是**決定性**的,
所以存檔裡的 RID 在新行程裡**指向一個真實存在、屬於別人的活體資源**。
這不是機率碰撞 —— 兩次獨立執行逐字相同。**探針 F 未查證 #5 與探針 G 未查證 #1 的
「或指向剛好占用同號碼的另一個物件 —— 後者是最壞情況,未測」,答案是:對 `RID` 而言,會。**
(本骨架**刻意不**拿它對伺服器發指令 —— 沿用探針 G 未查證 #3 的處置。)

### F-4 `_with_objects` 跨行程(僅為界定基準,骨架的讀取路徑不走這條)

| 量測 | 結果 |
|---|---|
| 用 **1 引數** `bytes_to_var()` 讀 | `ERR_UNAUTHORIZED` + `typeof=0` / `is_null=true`(與同行程一致) |
| 用 `bytes_to_var_with_objects()` 讀 | **成功**:`is SkelPoisonTarget = true`、**`marker = 987654321` 欄位跨行程完整還原**,但 `instance_id` 是新的 |
| 其中的 `Callable` | `typeof=25`、`is_valid=false`(刻意不呼叫) |

⚠️ **這意味著 `_with_objects` 跨行程會依存檔內容載入並實例化一個腳本類別。**
本 ADR 的格式選擇(只用 1 引數版)正是擋掉這件事的東西 —— 實測再次確認該選擇的價值,
**同時確認「絕不可為了方便而改用 `_with_objects`」**。

---

## 判讀陷阱(本骨架新增;前人的 8 項見 `prototypes/xcheck-adr0003-2026-08-21/README.md`)

9. **`Signal.is_null()` 回 `false` 但 `get_object()` 回 `null`** —— 跨行程還原的 Signal
   會通過 `is_null()` 這個守衛。要判活體只能用 `get_object() != null`。
10. **兩個 `==` 相等的 `Dictionary` 位元組可以不同** —— 任何「先比較 Variant 相等性、
    再推論位元組相同」的斷言都不成立(反之亦然)。位元級測試必須直接比位元組。
11. **`size` 相加正確的白名單表可以有洞** —— 兩個集合都是 `Dictionary`,
    集合**內**不可能重複,所以「總數對」只能靠**集合之間的交集**來偽造。
    對「某型別被誤搬進另一個集合」是瞎的。
12. **本骨架的 `_walk` 白名單是 `const` 綁死的,無注入點** ——
    可以測「斷言看不看得到壞表」,**不能**測「壞表會不會真的放毒藥過去」。
    這是刻意記錄的測試力上限,不是漏測。
13. **循環引用若真的走到 `var_to_bytes`,log 會被 1,000+ 行引擎錯誤淹掉**(本次 408 KB)。
    在 CI 上這會是「測試看起來掛了」而不是「一個回傳值是 0」。

---

## 檔案清單

```
project.godot                    # flush_stdout_on_print=true,main_scene 停在 Run2
scenes/Stage0.tscn / Run1.tscn / Run2.tscn

# ── 骨架本體(設計規格的實作)────────────────────────────
scripts/save_format.gd           # class_name SaveFormat  —— 純靜態工具集
scripts/save_block_registry.gd   # class_name SaveBlockRegistry —— 依賴注入實例
scripts/save_reader.gd           # class_name SaveReader  —— 六階段鎖定順序
scripts/save_writer.gd           # class_name SaveWriter  —— 規格沒有的類別,見 (c)-2
scripts/save_import_result.gd    # class_name SaveImportResult —— ADR 只給名字沒給欄位
scripts/fake_affinity_source.gd  # class_name FakeAffinitySource —— 假資料 + 正向白名單驗證器
scripts/skel_fixture.gd          # class_name SkelFixture —— 共用夾具
scripts/skel_poison_target.gd    # class_name SkelPoisonTarget —— 可觀測受害者

# ── 階段 0:形狀前置量測 ────────────────────────────────
scripts/pre1_type_constants.gd   scripts/pre2_static_var.gd
scripts/pre3_file_close.gd       scripts/pre4_inner_class_enum.gd
scripts/pre5_const_dict.gd       scripts/pre6_dup_of_const.gd
scripts/x1_typed_array.gd        scripts/x2_stringname_key.gd
scripts/x3_dict_key_order.gd     scripts/x4_cross_class_enum.gd

# ── 驗證測項 ───────────────────────────────────────────
scripts/t_self_and_e.gd          # E 白名單完整性斷言
scripts/t_a_roundtrip.gd         # A 完整往返走真實檔案
scripts/t_b_injection.gd         # B 失敗注入 x 10
scripts/t_c_poison.gd            # C 毒藥向量 x 兩側
scripts/t_d_manifest_only.gd     # D 計數器證明
scripts/t_g_cost.gd              # G 成本
scripts/t_h_callable_lifetime.gd # H 驗證器 Callable 生命期(追加)
scripts/t_f_write.gd  t_f_write_rid.gd   # F 第一半(行程 1)
scripts/t_f_read.gd   t_f_read_rid.gd    # F 第二半(行程 2)
scripts/t_i_gate_cost.gd         # I 閘門成本歸因 + 熱 I/O(追加)
scripts/runner_stage0.gd  runner_run1.gd  runner_run2.gd

logs/stage0-unfiltered.txt  logs/run1-unfiltered.txt  logs/run2-crossprocess-unfiltered.txt
```

**決定性**:全骨架零 RNG。假資料由索引算術產生(`i % 41`、`i * 3`、`i * 7`),
壞位元組用 XOR `0xFF` 固定翻轉,浮點只有一個字面量 `0.25`
(刻意避開探針 F 的 F4'-c 零字面量去重陷阱)。重跑結論應逐字相同,
唯一非決定性輸出是毫秒數與 ObjectID 具體數值 —— 而**所有判準都是「兩個值是否相同」**。
⚠️ 例外:`RID` 的 `94489280512` 兩次執行**逐字相同**,那不是巧合,是 F-3 的結論本身。

## 本骨架自身的過程失誤(執行者自陳)

1. **第一次寫 `save_format.gd` 用 bash heredoc,整檔沒落地**,而 `cat > file <<EOF`
   的失敗訊息是 shell 的 `unexpected EOF`,不是 Godot 的錯誤 —— 差一步就會在
   「檔案不存在」的情況下去跑 runner 並得到一堆 `FAILED (load->null)`。
   改用 Write 工具後正常。**教訓:骨架的每一個檔案在跑之前都要確認「真的在磁碟上」。**
2. **`t_c_poison` 的讀取側對照組印出 `!!! 通過了`** —— 那是給毒藥用的警告字樣,
   套在乾淨的對照組上會誤導讀者。措辭缺陷,不影響結果(該列本來就該通過)。
3. **驗證 G 的檔案 I/O 數字(42 ms / 29 ms)是冷啟動值**,當下沒有第二次量測可對照。
   追加的 I 才把它降到 7 ms / 1.7 ms。**單次量測的 I/O 數字不可用於預算推導。**

---

# 四類分類

## (a) 設計實測成立

1. **分層 manifest 結構 + manifest-only 路徑**:計數器證明 `read_manifest_only` 只呼叫
   `bytes_to_var` **一次**,`blocks_decoded=0`,而 manifest 完整可讀。`read_full` 為 1+n。
2. **鎖定的讀取順序在位元組層級自然成立**:六種規格要求的失敗注入全部落在指定那一關,
   `blocks_decoded` 逐項符合(④ 為 0 是硬證據)。
3. **`VERSION_TOO_NEW` 完全建立在一個整數比較上**:`decode_calls=1`。
4. **兩層雜湊的分工正確**:改區塊內容 → 逐區塊雜湊;改 manifest 中繼資料 → 頂層雜湊。
   兩者互不越界(改區塊內容時頂層雜湊仍通過,所以才會落到 S4)。
5. **讀取側必須再跑一次型別閘門 —— 這條要求是必要的,不是贅餘**:
   `EncodedObjectAsID`/`Signal`/`RID`/`Callable` 四種位元組 `bytes_to_var()` 一律靜默成功。
6. **白名單制(`has()`)而非黑名單**:35+4=39 在 4.7.1 剛好完整,且 `Color` 的通過
   是因為它在白名單上。
7. **鍵位置收緊為 `STRING`/`STRING_NAME`/`INT`**:`Vector2i` 鍵與 `Array` 鍵都被擋,
   且容器鍵不遞迴。
8. **深度上限是有效防線**:64/65/100 全部 DEPTH_EXCEEDED,**不靠堆疊溢位**。
9. **`is Dictionary` 而非 `!= null`**:全零 16 bytes 被正確判為損毀。
10. **`var_to_bytes` 每個區塊各自 `HashingContext.new()` + 檢查 `Error` + 斷言 32 bytes**:
    無任何雜湊失敗,SHA-256 只花 0.44 ms / 68 KB。
11. **型別化容器(`Array[int]`)可以安全放進 payload**:往返後仍 `is_typed()`,
    直接指派回 `Array[int]` 不中止。
12. **格式選擇(只用 1 引數版)的價值在跨行程再次被確認**:`_with_objects` 會依
    存檔內容實例化腳本類別並還原欄位 —— 1 引數版擋掉了它。
13. **fail-closed(未登記驗證器 → `DATA_CORRUPTED`)可實作且行為正確**。

## (b) 🔴 設計實測不成立

| # | 內容 | 證據 |
|---|---|---|
| **b-1** | **頂層雜湊的輸入若含 `Dictionary`,雜湊就依賴鍵插入順序。** 兩個 `==` 相等、鍵值相同、插入順序不同的 `Dictionary`,`var_to_bytes` 出來的位元組**不同**(88 bytes 各自 hex 不同);改成陣列位置元組則**相同**。ADR-0003 機制四宣稱「固定順序採 `source_id` 字典序,不依賴容器迭代順序」並自稱在套用 `relying_on_container_iteration_order` 禁令 —— 但它只管了**區塊之間**,沒管**條目內部的鍵**,而 Key Interfaces 把 `block_manifest` 的型別寫成 `Array[Dictionary]` | 階段 0 `x3` |
| **b-2** | **`RID` 跨行程指向「剛好占用同號碼」的別人的活體資源,且具決定性。** 行程 1 `94489280512` = 行程 2 第一個 `body_create()`,`==` 為 `true` | 階段 2 F-3 |
| **b-3** | **規格逐字的載入期完整性斷言對最壞的錯誤是瞎的。** 「拿掉 `TYPE_COLOR` + 誤加 `TYPE_OBJECT`」→ 35+4=39,斷言回 `true`,而 `TYPE_OBJECT` 已在白名單上 | 階段 1 E2 |
| **b-4** | **循環引用的兩條防線只有一條可達。** 規格鎖定「先閘門、再 `var_to_bytes`」,故 `buffer.size() > 0` 那條斷言永遠看不到循環引用(實測 rejection = DEPTH_EXCEEDED,路徑是 65 層 `["self"]`) | 階段 1 C-循環 |
| **b-5** | **驗證器 `Callable` 不會讓綁定的 `RefCounted` 續命。** 擁有者離開作用域後 `is_valid()=false`、`get_object()=<Object#null>`,而 `get_method()` 仍回 `validate_semantics`(看起來還活著)。fail-closed 讓後果變成「**所有存檔都 `DATA_CORRUPTED`**」 | 階段 1 H1/H2 |
| **b-6** | **`Signal.is_null()` 不可當守衛。** 跨行程還原的 Signal `is_null()=false` 但 `get_object()=null`、`connect()` 回 `ERR_UNCONFIGURED` | 階段 2 F-2 |
| **b-7** | **「fail-closed 的未登記檢查」無法在解碼之前發生。** ⑤ 與 ⑥ 的 `blocks_decoded=1` —— 規格把驗證器放在第 6 關,所以「manifest 列出一個沒人宣告的區塊」這件事必然是**解碼之後**才發現 | 階段 1 B5/B6 |

## (c) 設計沒講到、但實作時非決定不可(每一項都是那份文件的一個洞)

| # | 洞 | 我的決定 | 為什麼 |
|---|---|---|---|
| **c-1** | **信封欄位的形狀檢查是誰的責任、排在第幾關**。步驟 ② 必須先「讀出」`ruleset_version` 與 `block_manifest` 才能重算頂層雜湊 —— 也就是在雜湊驗證通過**之前**就已經必須信任這些欄位的形狀 | 新增 **S1B** 一關,在 ① 之後 ② 之前,逐欄位 `has()` + `typeof()` | 缺鍵 subscript 讀取已實測會**中止呼叫函式**。沒有 S1B,一份把 `block_manifest` 寫成 `int` 的檔案不會回 `DATA_CORRUPTED`,而是讓讀取函式從中間斷掉 |
| **c-2** | **沒有任何寫入側的組裝者**。規格只列 SaveFormat/Registry/Reader;ADR-0003 把外層 `var_to_bytes()` 畫在示意圖裡而介面清單沒有對應函式;ADR-0004 管的是「把 buffer 換到磁碟」不是「怎麼組出 buffer」 | 新增 `SaveWriter`,並依委派要求補上具名的 `serialize_manifest()` / `deserialize_manifest()` | 正規順序、雙層雜湊鏈、信封組裝是實質工作,不是膠水。這個空隙落在 ADR-0003 與 ADR-0004 之間 |
| **c-3** | **`size() == 0` 的失敗要回哪一個拒絕碼**(enum 只有 3 個值且規格要求「一次定完」) | `DEPTH_EXCEEDED`,並在 `offending_path` 寫 `<var_to_bytes returned size 0>` | 已知唯一成因是循環引用,引擎自己印的是 `Potential infinite recursion` |
| **c-4** | **`blocks` 的鍵集合不被任何雜湊涵蓋**。manifest 少一條 → 頂層雜湊抓到;但 `blocks` 少一條 → 頂層雜湊完全看不到 | 在 S4 加明確守衛(`blocks.has(sid)` + `typeof` 檢查),detail 明說「頂層雜湊涵蓋不到這件事」;**刻意不**把它提前到 S1B | 若在 S1B 做 manifest↔blocks 交叉檢查,驗證 B③(移除 manifest 條目)就會提前在 S1B 被攔,而規格要求它**由頂層雜湊攔**。兩者不能同時滿足 → 這是設計的一個真實張力。**副作用:`blocks` 裡多出來的條目會被靜默忽略**(從未讀取、從未檢查) |
| **c-5** | **重複 `source_id` 沒有規定** | 寫入側 `INPUT_INVALID`、讀取側 S1B `DATA_CORRUPTED` | 兩個條目排序相等 → 「依 `source_id` 字典序」失去唯一性 → 頂層雜湊不再是輸入的函數 |
| **c-6** | **`ImportResult` 只有名字,從未有欄位定義**(ADR-0002/0003 都只出現名字) | 自定 `SaveImportResult { ok, errors }`,**刻意改名**避免與未來 ADR-0002 真正的定義撞名 | 沒有欄位定義就無法寫驗證器,也無法讓讀取器判斷成敗 |
| **c-7** | **雜湊函式失敗時回傳什麼**(規格只說「斷言 32 bytes」) | 回空 `PackedByteArray`,並**強制所有比較走 `hash_matches()`**(先驗長度再比內容) | 若直接寫 `a == b`,兩邊都失敗時 `empty == empty` 為 `true` → **雜湊驗證被靜默繞過**。這是「失敗值選錯會製造假通過」的典型 |
| **c-8** | **`validate_payload_types()` 的公開簽章無法帶出 `offending_path`**,但 `SerializeResult` 規定要有這個欄位 | 公開簽章照規格保留(遷移鏈重用它),另加 `validate_payload_types_detailed()` 供寫入側取路徑 | 遷移鏈那條路徑因此**拿不到出錯位置**,只知道「有毒」。若遷移鏈需要診斷,規格的簽章要改 |
| **c-9** | **型別閘門的實作形狀沒規定,而它是整條路徑最大的單項成本** | 骨架照「每個節點回一個結果物件 + 組路徑字串」寫,並額外量了精簡版當對照 | 500 筆記錄:規格形狀 **18–26 ms**、精簡版 **2.4–4.2 ms**、`var_to_bytes` 1.4–1.8 ms。**建議:成功路徑走精簡版(只回 int),偵測到失敗後再跑一次帶路徑的版本**取診斷資訊 —— 失敗是罕見路徑,重跑一次不花錢 |
| **c-10** | **逐區塊處理是「交錯」還是「先驗全部雜湊再解全部區塊」** | 交錯(A 的雜湊→解碼→驗證跑完才輪到 B) | 規格寫的是「對每個需要處理的區塊:先雜湊、再解碼」,字面上是交錯。**副作用:B 損毀時 A 已被解碼並驗證** —— 讀取不是跨區塊 all-or-nothing,呼叫端要自己決定要不要套用 |
| **c-11** | **重複 `register()` 同一 `source_id`** | `push_error` + 拒絕覆寫(fail-loud) | 靜默覆寫等於讓後載入的系統綁架別人的驗證器,而症狀會出現在「別人的區塊驗證通過了但值是錯的」 |
| **c-12** | **`get_validator()` 回傳 `Variant`(ADR 原簽章)的呼叫端義務** | 一律 `typeof(v) != TYPE_CALLABLE` 判定,**不用 `== null`** | `Callable` 永遠不是 `null`;而登記時有效的 Callable 之後可能失效(見 b-5),故呼叫前**再**檢查一次 `is_valid()` |
| **c-13** | **`ruleset_version` 與每個區塊的 `format_version` 誰管版本比對** | 只用頂層 `ruleset_version` 做 `VERSION_TOO_NEW`;區塊的 `format_version` 骨架**只驗形狀不比大小** | 規格只說「版本比對」。區塊層的「比遊戲新」屬遷移鏈(ADR-0004)範圍,但**沒有任何一份文件明說這件事** |
| **c-14** | **信封裡出現未知的額外鍵怎麼辦** | 不檢查、不拒絕(只驗必要鍵存在且形狀正確) | 未來版本可能加欄位。但這意味著**存檔可以夾帶任意額外資料而不被發現**(它不進頂層雜湊也不被拒絕) |
| **c-15** | **`canonical_block_order()` 是否可以改動呼叫端的陣列** | 回傳新陣列,原陣列不動;手工插入排序(不用 `sort_custom` + lambda) | 回傳內部容器參照是本專案已登記的 forbidden pattern;插入排序天然穩定,且不賭「靜態情境下的 lambda」這個未查證形狀 |
| **c-16** | **`export_state()` 的 payload 若含 `StringName` 鍵,讀取端用 `String` 查得到嗎** | 鍵白名單同時允許 `STRING` 與 `STRING_NAME` | 實測 `has("alpha")` 與 `has(&"alpha")` 四種組合全部 `true`(x2),故兩者並存是安全的 —— 但這一條**沒有任何文件寫下來**,它是本骨架量出來才敢這樣寫的 |

## (d) 未查證(明說卡在哪)

| # | 項目 | 卡在哪 |
|---|---|---|
| 1 | **release build 行為** | 全部量測在 debug/headless。`ERR_UNAUTHORIZED` 是否仍輸出、型別閘門的容器驗證在 release 是否仍生效,未查證(與 ADR-0002 三層圖像「層二 release 未查證」同性質) |
| 2 | **`instance_from_id()` 跨行程是否「永遠」不會命中** | 已測 2,000 次配置、slot 範圍涵蓋舊 slot 仍為 `null`。但 ObjectID 的 validator 計數規則未讀原始碼確認,**不能宣稱是保證**。長時間執行 / 極大量物件配置後是否會繞回,未測 |
| 3 | **還原出來的 valid `RID` 拿去對伺服器發指令** | 刻意未測(崩潰風險 + 會污染後續測項)。已量到的是「號碼相同且 `==` 為 `true`」——**這已足以判定 b-2** |
| 4 | **`RID` 號碼相同是否適用於其他伺服器**(RenderingServer / NavigationServer 等) | 只測了 `PhysicsServer2D.body_create()` |
| 5 | **`Signal` 來源物件在同行程內「已死但行程未結束」** | 未測(H 只測了 Callable 的等價情境) |
| 6 | **多次寫入同一槽位的原子置換** | ADR-0004 範圍,本骨架只做單次寫入 |
| 7 | **遷移鏈重用 `validate_payload_types()`** | 骨架把它做成公開的,但沒有遷移鏈可接。c-8 指出的「拿不到路徑」是推論,未實作驗證 |
| 8 | **`MAX_PAYLOAD_DEPTH = 64` 是否夠用** | 已測合法深度 64 可過、65 被擋。真實 payload 的最大深度取決於各系統的 `export_state()`,無資料 |
| 9 | **`var_to_bytes` 對 `Dictionary` 的位元組是否只受插入順序影響** | 已測「同鍵值不同插入順序 → 位元組不同」。是否還有其他非決定性來源(例如同一 Dictionary 多次編碼)未測 —— 本骨架的 A 驗證間接顯示同一物件重複編碼是穩定的 |
