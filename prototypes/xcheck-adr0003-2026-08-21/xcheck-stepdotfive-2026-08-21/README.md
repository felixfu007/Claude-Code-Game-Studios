# 探針 H — ADR-0003 修訂草案的 Step 5.5 覆核用實測(2026-08-21)

**目的**:覆核 ADR-0003 修訂草案(尚未寫入)時,有八個問題無法靠讀文件定案。
本探針只量這八個,不重做探針 F/G 已量過的任何一項。

**執行者**:`godot-specialist`(Step 5.5 覆核)。
**引擎**:`Godot 4.7.1.stable.official.a13da4feb`,headless。**三次執行皆 exit code 0。**
**本探針不修改任何既有檔案**(ADR、registry、design、草案一律未動)。

> ### ⚠️ 本探針推翻了**草案自己**的兩項陳述
>
> - **草案第 121–122 行**:「空 `PackedByteArray` 與『合法但空』不可分」——
>   這是草案改變 `serialize_block()` 公開回傳型別的**唯一理由**。**實測為假**:
>   `var_to_bytes({})` = **8 bytes**、`var_to_bytes(null)` = **4 bytes**,
>   合法編碼**最短 4 bytes,永遠不是 0**。見 H-8。
> - **草案第 99–100 行**的遞迴走訪規則**全文沒有深度上限、也沒有已訪節點集合**,
>   而 `d["self"] = d` 在 GDScript 是合法的。照草案逐字實作,實測得到
>   **`SCRIPT ERROR: Stack overflow` + 1024 行 `ERROR: Stack underflow! (Engine Bug)`**。見 H-7。

---

## 如何重跑

```bash
# Godot 執行檔不在 PATH 上 —— which godot 找不到不代表沒有
GODOT="$HOME/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"

cd prototypes/xcheck-adr0003-2026-08-21/xcheck-stepdotfive-2026-08-21
"$GODOT" --headless --path . --editor --quit   # 沿用紀律先建 class cache
"$GODOT" --headless --path .                   # main_scene = res://scenes/H.tscn
```

`runner_h.gd` 的 `files` 字典決定跑哪些測項與順序。三次執行的差異只在該字典內容:

| log | 測項 | 為何分開跑 |
|---|---|---|
| `logs/probeH-run1-unfiltered.txt` | H1 / H2 / H3 / H4 | 首次執行(含 `--editor --quit` 的完整輸出) |
| `logs/probeH-run2-unfiltered.txt` | H1 / H2 / H3 / H4 / **H6** / **H5** | H5(把循環引用餵給引擎)風險未知,**排最後** |
| `logs/probeH-run3-unfiltered.txt` | **H8** / **H7** | H7 預期堆疊溢位。**單獨跑,免得它把 H6 的量測一起葬送** |

**執行者自陳:三份 log 皆為 `2>&1` 合併重導,未經 `grep`/`head`/`tail` 過濾或截斷。**
run2 為 639 KB,絕大部分是引擎的重複錯誤行 —— **那些錯誤行本身就是量測結果**,不是探針故障
(沿用探針 F 判讀陷阱第 6 項)。

**紀律沿用** `../scripts/runner_f1.gd`:每個存在性/arity 未經本專案查證的呼叫各自一檔;
一律以 `ResourceLoader.load(CACHE_MODE_IGNORE)` + `reload()` 的 `Error` 判定編譯成功
(不用 `load() != null`);危險測項排最後且獨立成檔。

---

## 結果

### H-1 —— `FileAccess.get_var()` 到底有沒有 `allow_objects` 參數

草案「明確排除」清單主張 `design/gdd/save-system.md:706` 寫的
`FileAccess.store_var()`/`get_var(allow_objects=false)` **是正確的**。本項核實該判斷。
`FileAccess` 是 `ClassDB` 登記類別,故內省可用(對比全域函式不在 `ClassDB` 內,
見探針 F 的「內省此路不通」)。

| 方法 | 實測簽章 | 預設值 | 回傳 |
|---|---|---|---|
| `FileAccess.get_var` | `get_var(allow_objects: bool)` | `[false]` | `Variant` |
| `FileAccess.store_var` | `store_var(value: Variant, full_objects: bool)` | `[false]` | `bool` |
| `FileAccess.get_buffer` | `get_buffer(length: int)` | — | `PackedByteArray` |
| `FileAccess.store_buffer` | `store_buffer(buffer: PackedByteArray)` | — | `bool` |

**判讀:草案的排除判斷成立。**

⚠️ **但這是 4.7.1 的一個真實不對稱,值得寫進 ADR**:同一件事在兩處有兩種 API 形狀 ——
**`FileAccess` 的方法保留布林參數,全域函式則拆成 `_with_objects` 變體**;`store_var()` 的第二
參數名還是 `full_objects` 而非 `allow_objects`。一個記得 `FileAccess.get_var(false)` 可用的讀者,
會很自然地以為 `bytes_to_var(b, false)` 也可用。**這正是 B-1 最可能的來源,
也是它最可能被重新加回去的路徑。**

### H-2 / H-3 —— 4.7.1 完整 Variant 型別列舉與 `TYPE_MAX`

`TYPE_MAX = 39`。`type_string(0..38)` 全部有效;`type_string(39..63)` 一律
`ERROR: Invalid type argument to type_string()` 並回傳 `<invalid type>`。

| # | 型別 | # | 型別 | # | 型別 | # | 型別 |
|---|---|---|---|---|---|---|---|
| 0 | Nil | 10 | Vector3i | 20 | **Color** | 30 | PackedInt32Array |
| 1 | bool | 11 | Transform2D | 21 | StringName | 31 | PackedInt64Array |
| 2 | int | 12 | Vector4 | 22 | NodePath | 32 | PackedFloat32Array |
| 3 | float | 13 | Vector4i | 23 | **RID** | 33 | PackedFloat64Array |
| 4 | String | 14 | Plane | 24 | **Object** | 34 | PackedStringArray |
| 5 | Vector2 | 15 | Quaternion | 25 | **Callable** | 35 | PackedVector2Array |
| 6 | Vector2i | 16 | AABB | 26 | **Signal** | 36 | PackedVector3Array |
| 7 | Rect2 | 17 | Basis | 27 | Dictionary | 37 | PackedColorArray |
| 8 | Rect2i | 18 | Transform3D | 28 | Array | 38 | PackedVector4Array |
| 9 | Vector3 | 19 | Projection | 29 | PackedByteArray | 39 | *(TYPE_MAX 哨兵,`typeof()` 永不回傳)* |

**對草案白名單的判讀**:草案逐一列名的允許型別為 0/1/2/3/4/21/22/27/28 加「全部 `Packed*Array`」
(29–38),合計 19 個;拒絕 23/24/25/26 共 4 個。**剩下的 16 個(型別 5–20)全部靠
「數學型別」這四個字承載** —— 而 **`Color`(20) 不是數學型別**,`Projection`(19)/`Basis`(17)/
`AABB`(16)/`Transform3D`(18) 也不是多數人列舉「數學型別」時會想到的。
在白名單語意下(未列到 = 拒絕),這四個字直接決定 16 個型別的命運。

### H-4 —— `Object` 能不能當 `Dictionary` 的**鍵**

| 測項 | 結果 |
|---|---|
| `d[RefCounted.new()] = 1` | ✅ **合法**,`keys()` typeof 為 `[24, 4]` |
| `var_to_bytes()` 該 Dict | **靜默成功**,48 bytes,零錯誤 |
| `bytes_to_var()` | `typeof=27`,**鍵**還原為 `<EncodedObjectAsID#...>`,還原後 `keys()` typeof 仍為 `[24, 4]` |
| `Array` 內含 Object | 靜默成功(40 bytes),解回 `[1, <EncodedObjectAsID#...>, "x"]` |
| `Array[int]` 往返 | `typeof=28`,**`get_typed_builtin()` 往返後仍為 2** —— 型別化資訊**保住了** |

**判讀:草案「遞迴走訪 `Dictionary` 的**鍵**與值」這半條規則是可達的,不是死碼。**
本項是刻意去找 R7E-6(範圍宣告涵蓋一個結構上不可能的入口)那個形狀 —— **沒找到,草案在此正確。**

⚠️ **附帶事實(草案與探針 F/G 都沒提)**:型別化 `Array[int]` 經位元組流往返後**仍是型別化的**。
即 `bytes_to_var()` 可以從不可信來源交出一個型別化容器。與 ADR-0002 的「三層圖像」有交集,
不是本草案的缺陷,僅記錄。

### H-5 —— 引擎自己怎麼處理循環引用容器

| 測項 | 結果 |
|---|---|
| 建構 `d["self"] = d` | ✅ GDScript **允許**(`Dictionary` 是參照型別) |
| `var_to_bytes(d)` | `ERROR: Potential infinite recursion detected. Bailing.`(`core/io/marshalls.cpp:1363`)+ **1025 行**串聯的 `Condition "err" is true` → **回傳 `size=0` 的 `PackedByteArray`**。**不崩潰、不卡死** |
| `bytes_to_var(該空緩衝區)` | `Condition "len < 4" ... ERR_INVALID_DATA` → 回傳 `null` |
| 互相參照的兩個 `Array` | **同行為**(size=0 → `null`) |

🔴 **這條路徑的危險形狀**:`var_to_bytes()` 的**失敗回傳值是長度 0 的 `PackedByteArray`,不是 `null`**。
若 `serialize_block()` 維持 `-> PackedByteArray` 且不檢查長度,後續流程會:
對空緩衝區算 SHA-256(空輸入的雜湊是完全合法的 `e3b0c442...`,見探針 F 的 F3)→ 寫入
`blocks[source_id]` → 算頂層雜湊 → **寫出一份結構完整、雜湊全部相符、但區塊內容是空的存檔**。
失敗延後到**下一次讀取**才以 `DATA_CORRUPTED` 現形 —— 玩家在**載入時**才發現資料沒了。

**這與草案變更五抓到的 `HashingContext.finish()` 回傳空 `PackedByteArray` 是同一形狀的第二個實例。
草案只抓到其中一個。**

### H-6 —— 照草案實作的遞迴閘門,GDScript 下的實際成本

payload 形狀模擬好感度區塊
(`{records: [{pair, source_i, m, t} × n], campaign_tick_marks: [], death_marks: {}}`)。

| n | 編碼後 | **寫入側閘門** | `var_to_bytes` | `bytes_to_var` | **讀取側閘門** | 閘門佔比 |
|---|---|---|---|---|---|---|
| **500**(GDD 估計規模) | 52 KB | **1.9 ms** | 0.6 ms | 0.6 ms | **1.9 ms** | **~76%** |
| 100,000 | 10.4 MB | **435.5 ms** | 132.1 ms | 171.5 ms | **391.0 ms** | ~73% |
| 500,000 | 52.0 MB | **2028.4 ms** | 822.3 ms | 1669.6 ms | **3387.8 ms** | ~68% |

**判讀:雙側閘門是本專案自己的 GDScript 迴圈,成本約為引擎 C++ 編解碼的 3 倍。**
在 GDD 估計的單槽數十 KB 規模下,總計由探針 F 量到的「< 2 ms」變成 **~5 ms** —— 仍可接受。
但 500k 規模下閘門單獨貢獻 **5.4 秒**,而 GDD 有 `migration_chain_load_time_budget_ms` 這個預算。
**探針 F 的 F5 量的是引擎成本,不能用來推論閘門成本 —— 這是兩份不同的量測。**

**毒藥對照(閘門真的擋得下)**:值為 Object → `false`;**鍵**為 Object → `false`;
`Signal` → `false`;`Callable` → `false`。四者全部攔下。

⚠️ **邊界型別對照,以及一項關於「白名單 vs 黑名單」的第一手觀察**:
`Color`(20)→ 通過、`Transform3D`(18)→ 通過、`Projection`(19)→ 通過。
**它們之所以通過,是因為我照草案的表寫出來的 `_gate()` 是黑名單**(拒絕那 4 個、其餘放行)。
我不是刻意寫成黑名單的 —— 草案雖寫著「白名單制,非黑名單」,但它同時給了一張**拒絕表**,
且允許側有一格是「數學型別」這種無法逐一比對的字眼,**照著實作最省力的路就是黑名單**。
這是實作者的第一手證據,不是推測。

### H-7 —— 草案逐字寫法(無深度上限、無已訪集合)對循環 payload

```
H7: 即將對自我參照 Dict 呼叫無防護的遞迴閘門(草案逐字寫法)...
SCRIPT ERROR: Stack overflow. Check for infinite recursion in your script.
ERROR: Stack underflow! (Engine Bug)      ← 共 1024 行
H7: 回傳 false,走訪步數=8177
```

**判讀,逐項**:

1. **不會無限迴圈,也不會殺掉行程** —— GDScript 有遞迴上限(由 1024 行 `Stack underflow`
   **推得**上限約 1024 個堆疊框;步數 8177 是因為每層遞迴走訪 2 鍵 + 2 值)。
2. **但它會在玩家的 log 裡吐出 1024 行帶「(Engine Bug)」字樣的錯誤** —— 對一份「防護意外損毀」
   的系統,這個診斷輸出本身就是缺陷。
3. **`false` 這個回傳值是「意外正確」,不是設計出來的** —— 堆疊溢位中止最內層框後,每一層
   展開都拿到宣告型別 `bool` 的零值 `false`。在**目前的極性**下(`false` = 拒絕)恰好 fail-closed。
   **若極性反過來寫,同一個機制就是 fail-open。這不是可依賴的保證。**
4. 🔴 **對草案「主案」的直接衝擊**:若 `serialize_block()` 改為 `-> SerializeResult`(物件型別),
   堆疊溢位展開時回傳的零值是 **`null`**,而不是一個 `rejection == FORBIDDEN_TYPE` 的結果物件。
   呼叫端接著寫 `result.rejection` 就是**在 null 實例上取屬性 → 中止呼叫端函式**
   (與探針 G 的 G-N1「呼叫空 `Callable` 會中止呼叫端」同一家族)。
   **主案在沒有深度上限的前提下,會把 H-7 這個「意外的 fail-closed」轉成「呼叫端無聲中止」。**

### H-8 —— 空容器的編碼長度,與合法深層巢狀

| 輸入 | `var_to_bytes()` size |
|---|---|
| `{}` | **8** |
| `[]` | **8** |
| `null` | **4** |
| `PackedByteArray()` | **8** |
| `{"v": 1}`(對照) | 28 |

`bytes_to_var(var_to_bytes({}))` → `typeof=27`,空 `Dictionary` 正常往返。

🔴 **合法編碼的最短長度是 4 bytes,「合法但空」永遠不會是 0 bytes。**
草案第 121–122 行「空 `PackedByteArray` 與『合法但空』不可分」**實測為假**。
`size() == 0` 在 4.7.1 是一個**可靠且無歧義的失敗訊號**,而且(見 H-5)它正是引擎自己在
遞迴 bail 時使用的訊號。

**合法深層巢狀**(非循環,`{"n": {"n": ... {"leaf": 1}}}`):深度 16 / 32 / 64 / 96 / 128 / **256**
全部 encode + decode 正常(深度 256 → 5148 bytes,decode `typeof=27`)。
→ 閘門的深度上限設在遠高於真實 payload 巢狀深度(約 4 層)、又遠低於 GDScript 約 1024 框上限
的任何值(例如 64 或 128)都是安全的。

---

## 未查證(明說卡在哪,不編造)

| # | 項目 | 卡在哪 |
|---|---|---|
| 1 | 引擎 `encode_variant` 的「Potential infinite recursion」**確切深度門檻** | 只測到「合法深度 256 正常」與「循環會 bail」兩端,中間未二分搜尋 —— 對本次建議(閘門自帶深度上限)不影響結論,故刻意未測 |
| 2 | **release build** 行為 | 全部量測皆 debug/headless。`Stack overflow`/`Stack underflow`/`Potential infinite recursion` 三種訊息在 release 是否仍產生、`var_to_bytes()` 是否仍回傳 size 0,**未查證**(與探針 F 未查證 #3、ADR-0002 VR#7 同性質) |
| 3 | **跨行程** `Signal`/`RID`/`EncodedObjectAsID` | 本探針未觸及,仍是探針 F 未查證 #5 / 探針 G 未查證 #1 的同一個洞,**本探針未縮小它** |
| 4 | H-6 的閘門實作是**為量測而寫的一個版本**,不是 ADR 定案的實作 | 量級可信(它就是 `typeof()` + 遞迴的最小形式),但若最終實作改成非遞迴 / 加已訪集合 / 加深度計數,常數會變。**不可把 1.9 ms / 2028 ms 當規格值引用**,只能支撐「閘門與引擎編解碼同一量級、約 3 倍」這個結論 |
| 5 | GDScript 遞迴上限「約 1024 框」是由 1024 行 `Stack underflow` **推得**,非直接量測 | 未寫專門的深度計數探針確認。對建議(上限設 64~128)不影響 |
| 6 | 循環引用是否**真的會出現在本專案的 payload 建構路徑**上 | 這是實作層問題,不是引擎問題。已量到的是「語言允許、閘門會爆」,**沒有量到「會不會發生」** |

## 本探針自身的過程失誤(主動自陳)

**第一版 `h2_type_enum.gd` 掃到 i=64 才停**,而 `TYPE_MAX = 39` —— 於是產生 25 次
`ERROR: Invalid type argument to type_string()`,把 run1/run2 的 log 各撐大幾十 KB。
**刻意不修**:那 25 行本身就是「39 以上不存在」的證據,而 `h3` 已獨立取得 `TYPE_MAX = 39`。
若當初先跑 `h3` 再寫 `h2` 的迴圈上限就不會有這批雜訊 —— **測項之間的依賴順序也該規劃**,
不只規劃「哪些測項要隔離」。

## 檔案清單

```
project.godot                          # main_scene = res://scenes/H.tscn
scenes/H.tscn
scripts/runner_h.gd                    # 協調者(files 字典決定跑哪些、順序)
scripts/h1_fileaccess_introspect.gd    # H1 FileAccess.get_var/store_var 真實簽章
scripts/h2_type_enum.gd                # H2 完整 Variant 型別列舉(type_string arity 未查證故隔離)
scripts/h3_type_max.gd                 # H3 TYPE_MAX(存在性未查證故隔離)
scripts/h4_object_as_dict_key.gd       # H4 Object 當 Dictionary 鍵 / Array 元素 / 型別化 Array
scripts/h5_cyclic_engine.gd            # H5 引擎對循環引用的行為(危險,排最後)
scripts/h6_gate_cost.gd                # H6 閘門成本 + 毒藥 + 邊界型別(自帶深度上限 64)
scripts/h7_naked_recursive_gate.gd     # H7 草案逐字寫法(無防護)→ 堆疊溢位(單獨跑)
scripts/h8_empty_and_depth.gd          # H8 空容器編碼長度 + 合法深層巢狀
logs/probeH-run1-unfiltered.txt        # 未過濾
logs/probeH-run2-unfiltered.txt        # 未過濾(639 KB,含 H5 的 1025 行引擎錯誤 —— 那是量測結果)
logs/probeH-run3-unfiltered.txt        # 未過濾(含 H7 的 1024 行 Stack underflow)
```

**決定性**:零 RNG。唯一非決定性輸出是 ObjectID 具體數值與 H-6 的毫秒數;
所有判準均為「型別 / 長度 / 布林 / 是否相同」,重跑結論應逐字相同(H-6 的數字有機器差異)。
