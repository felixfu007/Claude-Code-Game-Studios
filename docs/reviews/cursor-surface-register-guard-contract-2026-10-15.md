# 游標表面註冊守衛執行契約(甲案)

**日期**:2026-10-15 | **作者**:`technical-director` | **狀態**:草案,待管理者核准
**前提**:管理者 2026-10-15 已裁決採**甲案(在 `CursorSurfaceRegistry.register()` 入口擋下來)**。
本文**不重開「做不做」**,只定「怎麼做」。**本文不含實作,未修改任何既有檔案,未執行引擎或測試。**

> ⚠️ **本文全部引擎行為宣稱一律為 (C) 級**(訓練資料/文件推測,未實測)。
> 本次派工明文禁止跑引擎與測試,故凡涉及引擎回傳值的判斷,**都列在第六節的前置探針清單裡**,
> 不得當成既定事實進實作。本專案已為「憑記憶對著沒驗證過的 API 寫程式」付過代價
> (18 處呼叫寫法錯誤,`technical-preferences.md` 登記)。

---

## 〇、一頁結論

| 題 | 結論 |
|---|---|
| 1 | 兩項條件 = ①`focus_mode = Control.FOCUS_NONE`;②不得帶內建滑鼠 hover 主題狀態(逐字見第一節) |
| 2 | **拒絕註冊**(不儲存、回傳失敗值),**並在 `register()` 內 `push_error` 寫出細節**。代價見第二節 |
| 3 | 列舉**尾端新增兩個值**(序數 4、5),絕不插在 0、絕不重排。兩個而非一個的理由見第三節 |
| 4 | 非 `Control` **跳過檢查、回傳 `REGISTERED`**,但**判決必須記成 `NOT_APPLICABLE`,不得記成「通過」** |
| 5 | **現有五處全部不會壞** —— 它們註冊的是 `BattleScreen`,而它 `extends Node`,落在非 `Control` 分支。證據見第五節。🔴 **但這也代表守衛的 `Control` 分支在 production 裡仍是空集合** |
| 6 | **一半成立**。「拒絕/不儲存」那半現在就寫得出 assertion-red 的測試;「判決帳」那半**寫不出來**,照字面寫會踩 exit 105。見第六節 |

---

## 一、兩項條件的逐字原文

**來源**:`docs/architecture/adr-0005-cursor-device-authority-input-architecture.md` 機制十四。
**查法(不寫死行號,行號會漂)**:

```bash
grep -n "^### 機制十四" docs/architecture/adr-0005-cursor-device-authority-input-architecture.md
# → 1565(2026-10-15 當下),再 sed -n '1565,1600p' 讀該節
```

逐字引用(本文作者未改一字):

> **決策(2026-08-18 `godot-specialist` Step 5.5 驗證後修訂 —— 原決策不完整)**:每個已註冊表面的根 Control **必須同時**滿足以下**兩項**條件:
>
> 1. **`focus_mode = Control.FOCUS_NONE`** —— 排除鍵盤/手把焦點通道。
> 2. **不得帶有內建滑鼠 hover 主題狀態** —— 根 Control 不得是 `Button` 或任何在主題中內建 hover StyleBox 的節點型別;若因其他理由必須使用此類型別,**必須顯式清空其 hover/focus StyleBox**(使其 hover 狀態與 normal 狀態在視覺上不可區分)。
>
> 高亮視覺只讀 `CursorState`,不讀任何引擎原生焦點/懸停狀態。

**同節的型別分流表(本契約第四節的唯一依據),亦為逐字**:

> | 根節點型別 | 機制十四的兩項條件 | 理由 |
> |---|---|---|
> | **`Control` 及其子類別** | **兩項皆為硬性要求** | 它在 4.6 雙焦點系統與 GUI hover 管線內,不封住就會出現 GDD Player Fantasy 明訂的最高風險失敗情境「兩種高亮同時存在」 |
> | **非 `Control`**(`Node2D`/`Area2D`/`Node3D` 等) | **結構性不適用,不需要也無法滿足** | 該節點型別根本沒有 `focus_mode`、沒有主題 StyleBox、不參與 GUI 焦點與 hover 判定,兩條會製造第二個高亮的管線都不存在 |

**第 2 項為何是硬性要求而非防禦性建議**(同節逐字節錄,這一句決定了守衛不能只查 `focus_mode`):

> 因此 `focus_mode = FOCUS_NONE` **大概率只關掉一半**:若已註冊表面的根 Control 帶內建 hover 主題,該節點會**獨立於本系統的全部邏輯**、單純因為滑鼠移到它上面就自行繪製原生 hover 視覺

並已由實測關閉(ADR Verification Required 第 9 項):`Button` 設 `FOCUS_NONE` 後滑鼠懸停,
`is_hovered()` 由 false 轉 true、`get_draw_mode()` 由 0(NORMAL)轉 **2(HOVER)**。
證據檔:`prototypes/adr0005-engine-probes-2026-09-01/logs/probe9_windowed.txt`。

📌 **機制十四明文不約束 `mouse_filter`**(同節逐字:「本 ADR **不**對它設限」)。
**守衛因此不得檢查 `mouse_filter`** —— 多查一項就是替下游新增 ADR 沒有授權的約束。

---

## 二、拒絕註冊 vs 註冊但報錯

### 裁決:**拒絕註冊**,且**由 `register()` 自己 `push_error` 寫出細節**

### 兩案的失敗長相(這是選擇的全部內容)

| | 甲-1 **拒絕** | 甲-2 **註冊 + 報錯** |
|---|---|---|
| 違規時畫面上發生什麼 | 該表面的游標導覽**完全不運作**(表面沒進表,`get_surface()` 回 null) | 游標運作,但**畫面上出現兩個高亮** |
| 誰會發現 | 任何人開遊戲都會發現「游標不動」 | 只有看得出「這裡不該有兩個框」的人 |
| 規則還能不能被忽略 | **不能**(結構上擋住) | **能**(log 裡多一行紅字,照樣出貨) |
| 失敗方向 | 大聲、立刻、無法忽略 | 安靜、可忽略、正是本專案登記最多次的形狀 |

### 選拒絕的理由

1. **甲-2 等於沒做甲案。** 本案的全部價值是把「靠紀律遵守」換成「結構上不可能違反」。
   註冊照樣成功 = 規則仍可被忽略 = 甲案退化成一條**新的紀律條文**,
   而本專案三份每次對話開場載入的文件裡,**明文自陳「沒有自動檢查會攔這條」的規則實測 10 處**:

   ```
   $ grep -c "沒有任何自動檢查\|沒有任何 skill、lint 或閘門\|沒有任何 lint\|No lint or hook checks" \
         CLAUDE.md .claude/docs/coding-standards.md .claude/docs/technical-preferences.md
   CLAUDE.md:2
   .claude/docs/coding-standards.md:5
   .claude/docs/technical-preferences.md:3
   ```
   (這是四種措辭的命中數,實際數量只會更多不會更少。)**再加第 11 條的邊際效益接近零。**
2. **違規是靜態且決定性的,不是執行期偶發。** 兩項條件只取決於**節點型別**與
   **`focus_mode` 屬性值**,不取決於玩家輸入、存檔內容或時序。亦即:**違規會在開發機第一次跑到
   那個畫面時 100% 發作**,不可能「開發時沒事、玩家機器上才壞」。
   這把「拒絕」最嚇人的代價(出貨版游標整個不動)壓到很低 —— 它要能出貨,得先在每一次本機執行、
   每一次 CI、每一次截圖證據蒐集時都被忽略。
3. **儲存一個已知違規的節點,會破壞註冊表對下游的契約。** `get_surface()` 的消費方
   (機制十三之二的 hover 判定)預設表內節點是合規的。甲-2 讓表裡躺著一個 ADR 明文說不該在那裡的節點,
   問題從「註冊入口」擴散成「每個消費方都要自己防」。

### 🔴 誠實記錄:拒絕的代價,以及它為什麼不是零

**現有五處呼叫端全部是「`push_error` 之後繼續跑」**(第五節附證據),所以拒絕的實際後果是
**「游標靜悄悄地什麼都不做 + log 裡一行紅字」**,不是程式當掉。

對**非技術的審閱者**(本專案的管理者)而言,**「游標完全不動」比「兩個高亮」更難診斷** ——
後者看得見哪裡壞了,前者看起來像「這個功能還沒做」。這是本裁決接受的代價,不是被忽略的風險。

**緩解(列為契約硬性條款,不是建議)**:

> **守衛拒絕時,`register()` 自己必須 `push_error`,訊息必須包含:**
> **(a) 表面標籤名、(b) 節點的 `get_class()`、(c) 節點路徑(在樹上時)、(d) 兩項條件各自的判定結果
> (不只失敗的那一項)、(e) 一句話的修法。**

**理由是查到的事實,不是風格偏好**:現有五處呼叫端的錯誤訊息全部寫成
`"... returned %s instead of REGISTERED ..." % register_result`
(見第五節 grep 原始輸出)。GDScript 的列舉是 `int`,`%s` 會印出**序數**而不是名稱 ——
下一個人在 log 裡看到的是 `returned 4`,**而 `4` 這個數字在呼叫端那一行查不到意義**。
呼叫端結構上產不出可讀的診斷,所以**診斷責任必須留在 `register()` 內**。

### 被否決的第三案(未在選單上,但會有人提,先寫下理由)

**甲-3:debug 建置拒絕、release 建置只報錯。** 否決。
與本專案 2026-09-02「裁決二」同形 —— 該裁決的原文(轉錄於
`src/ui/cursor/cursor_surface_registry.gd` 的 `register()` doc comment)要求
「必須活到出貨建置的守衛,回傳明確失敗值,而不是依賴引擎可能在 release 剝除的 `assert()`」。
**debug/release 行為分歧**會讓所有測試證明的是一個玩家拿不到的產品。

### 守衛在 `register()` 內的擺放位置

```
func register(surface, node) -> RegisterResult:
    1. is_instance_valid(node) 檢查      ← 既有,不動
    2. _surfaces.has(surface) 重複標籤檢查 ← 既有,不動
    3. 🔴 新增:機制十四守衛
    4. 儲存 + 回傳 REGISTERED            ← 既有
```

🔴 **契約硬性條款(擺在第 3 位的理由)**:

> **守衛只能把原本會回傳 `REGISTERED` 的輸入變成拒絕,
> 絕不可把原本就會被拒絕的輸入改成另一種拒絕碼。**

亦即:一個「既違反兩項條件、標籤又已被佔用」的節點,**今天回 `DUPLICATE_TAG_REJECTED`,明天也必須回
`DUPLICATE_TAG_REJECTED`**。這讓既有測試檔
`tests/unit/cursor/surface_registry_test.gd` 的全部既有斷言在實作後**應該一條都不會變色** ——
而「既有測試有沒有變色」就是這條契約的驗收方式。
(若實作後既有測試出現非預期的紅,代表守衛的位置放錯了,不是測試該改。)

**`unregister()` 不加守衛** —— 它不把任何節點放進表裡。

🔴 **守衛內絕不可使用 `assert()`。** 依 `.claude/docs/coding-standards.md` 2026-09-15 實測條目:
`assert()` 失敗會中止函式,函式回傳**其宣告回傳型別的序數 0**,而本列舉的序數 0 是
`REGISTERED` —— **一個失敗的斷言會靜默回報「註冊成功」**,正好是守衛要防的事的反面。
`register()` 現行程式碼已遵守這條(doc comment 明載),守衛必須遵守同一條。

---

## 三、`RegisterResult` 怎麼加

### 現況(`src/ui/cursor/cursor_surface_registry.gd`,查法 `grep -n "enum RegisterResult" src/ui/cursor/cursor_surface_registry.gd`)

```gdscript
enum RegisterResult { REGISTERED, DUPLICATE_TAG_REJECTED, UNREGISTERED_NOT_FOUND, INVALID_NODE }
#                     └ 0          └ 1                     └ 2                      └ 3
```

### 契約:**尾端新增兩個值**

```gdscript
enum RegisterResult {
    REGISTERED,                     # 0 — 不動
    DUPLICATE_TAG_REJECTED,         # 1 — 不動
    UNREGISTERED_NOT_FOUND,         # 2 — 不動
    INVALID_NODE,                   # 3 — 不動
    FOCUS_MODE_NOT_NONE_REJECTED,   # 4 — 新增:違反機制十四條件 1
    NATIVE_HOVER_THEME_REJECTED,    # 5 — 新增:違反機制十四條件 2
}
```

**三條硬性約束**:

1. 🔴 **絕不插在序數 0,絕不重排既有四個值。** 該列舉自己的 doc comment 已明文記錄這條紀律
   (逐字:「No enum member was removed or reordered, so no existing caller comparing against the
   other three named members is affected」)。本次沿用,不是新規則。
2. 🔴 **關於 2026-09-15 的序數 0 陷阱 —— 誠實說明新增值做了什麼、沒做什麼。**
   該陷阱是「失敗路徑讓函式回傳序數 0 = 被讀成成功」。**把新值放在尾端,既不惡化也不改善這個坑**
   —— 它本來就存在於這個函式(序數 0 就是 `REGISTERED`)。
   **真正關掉它的唯一手段是第二節最後那條:守衛不得使用 `assert()`。**
   把新值放尾端的理由是**不破壞既有呼叫端與既有測試**,不是因為它能躲開那個坑。
   ⚠️ **不要把「我放在尾端了」當成已經處理了序數 0 陷阱。**
3. **兩個值而不是一個。** 機制十四原文是「**必須同時**滿足以下**兩項**」,
   單一個 `MECHANISM_14_REJECTED` 會讓測試無法證明**是哪一條被實作了** ——
   只實作條件 1 的實作,在單值設計下會讓所有拒絕測試全綠。
   本專案已登記過同形狀的失效(Story 007 的 AC-32:「測試斷言的『仍為無效』有第二個成因」,
   記於 story-012 檔內)。兩個值讓第六節的 T4 成為可能,而 T4 是整批測試裡**唯一**能證明
   條件 2 真的被實作的那條。

### 同時違反兩項時的回傳(決定性,必須寫進 doc comment)

> **先判條件 1,再判條件 2。兩項皆違反時回傳 `FOCUS_MODE_NOT_NONE_REJECTED`(序數小者)。**
> **但 `push_error` 的訊息必須同時列出兩項的判定結果。**

理由:回傳值只能有一個,順序必須決定性(否則測試不可重現);
而「修好第一項、再撞第二項」的來回成本由 `push_error` 一次列全部來消除。

---

## 四、非 `Control` 節點:跳過檢查,但判決記成 `NOT_APPLICABLE`

### 契約

> **型別判定用 `node is Control`**(涵蓋全部子類別,對應 ADR 的「`Control` 及其子類別」)。
> **非 `Control`:跳過兩項條件,回傳 `REGISTERED`。**
> 🔴 **但註冊表必須把這次的判決記為 `NOT_APPLICABLE`,不得記成「通過」。**

依據:story-012 的 **AC-S012-a** 逐字要求「凡屬非 `Control` 型別者(`Node2D` / `Area2D` 等),
記錄為**結構性不適用**,不得視為違規」。
注意它寫的是「**記錄為**結構性不適用」—— 不是「視為通過」。本契約把「記錄」具體化為一個可查詢的 API。

### 為什麼「跳過」與「通過」必須在程式裡可區分

**這是本專案已裁決過的同一個形狀,不是新發明的。**
`.claude/docs/coding-standards.md`「Check 4 世界層量法變更(2026-09-23 管理者裁決)」的**新判準二**逐字:

> 若不存在,證據上必須寫**「沒有可測對象(N/A)」**,**不得**寫「0 個違規 / 通過」——
> 兩者字面上數字可能相同,但前者是「這次沒驗證到任何東西」,後者暗示「驗證了,而且乾淨」,
> 對讀證據的人而言無法區分。

**套到本契約**:今天唯一的已註冊表面是非 `Control`(第五節)。
若守衛對它回傳「通過」,追溯索引與證據檔會顯示「機制十四已在 production 生效並通過」——
**而實際上守衛的兩項條件一次都沒有執行過。** 這正是 story-012 當初被判 Blocked 的同一個理由
(定義域為空集合時,全稱斷言恆真),只是搬到了程式裡。

### 建議形狀(機制十五 `diagnostic_*` 慣例)

```gdscript
## QA/測試專用,下游業務邏輯不得依賴 —— 比照機制十五 diagnostic_* 慣例。
enum GuardVerdict { NOT_APPLICABLE, PASSED, REJECTED }

## 回傳 surface 標籤上「最後一次 register() 呼叫」的機制十四判決。
## 從未被呼叫過的標籤回傳 ... (見下方未決項)
func diagnostic_last_guard_verdict(surface: CursorTypes.SurfaceType) -> GuardVerdict
```

⚠️ **這個 API 的兩個邊界本契約不代為決定,實作前停下來問**:
1. **從未註冊過的標籤**回傳什麼?(第四個列舉值 `NEVER_ATTEMPTED`?還是分開一個
   `diagnostic_has_guard_verdict()`?)—— 兩種都可以,但**不可以回傳 `NOT_APPLICABLE`**,
   那會讓「沒試過」與「試過但不適用」再次混成同一個答案,重演本節要防的事。
2. **`unregister()` 之後**判決帳要不要清掉?(保留 = 歷史帳;清掉 = 現況帳。兩者語意不同。)

**日後加第五種表面型別時,兩種設計的差別就在這裡**:記成 `PASSED` 的話,
守衛從沒跑過的事實會被一個「通過」掩蓋;記成 `NOT_APPLICABLE` 的話,
第一個真的是 `Control` 的表面接上來的那一天,判決會從 `NOT_APPLICABLE` 變成 `PASSED` 或 `REJECTED`
—— **那次變化本身就是「守衛第一次真的執行」的證據。**

### 條件 2 的機械判準(🔴 本節最弱的一環,務必讀完)

機制十四的條件 2 寫的是「**在視覺上不可區分**」—— 那是一個**視覺**判準,
而守衛只能做**機械**判準。本契約提出的機械近似是:

> **判違規的條件**:該 `Control` 在其當下主題脈絡下「有一個 hover StyleBox」,
> **且**它與 normal StyleBox **不是同一個資源實例**。
> focus StyleBox 同理(機制十四原文寫的是「hover/focus StyleBox」兩者)。

**逃生門**(對應 ADR 的「必須顯式清空」):實作者以
`add_theme_stylebox_override(&"hover", <與 normal 同一個實例>)` 覆寫,使兩者參照相等。

🔴 **這個近似會誤拒一種合法寫法**:兩個**不同實例**但長得一模一樣的 `StyleBoxEmpty`
(視覺上確實不可區分,但參照不相等)→ 守衛會判違規。
**這是刻意選的失敗方向**(寧可誤拒,不可誤放),但它是一條**新的、ADR 沒有的約束** ——
實作者必須用「同一個實例」而不是「兩個長得一樣的實例」。
**這一點必須寫進 `register()` 的 doc comment**,否則下一個人會花一小時找「為什麼我明明清空了還被拒」。

⚠️ **這整段的引擎行為全部未驗證**(我沒有跑引擎)。
`has_theme_stylebox()` 在本專案**零使用**(`grep -rn "has_theme_stylebox" src/ tests/` → 零命中),
`get_theme_stylebox()` 僅在 `tests/unit/ui/menu/battle_menu_layout_test.gd` 用過,
**而且那裡是先 `add_child(probe)` 進樹之後才查的**(該檔 `test_focus_border_luminance_differs_from_real_default_button_background`)。
**出樹節點的主題查詢行為沒有任何本專案證據。** 列為第六節探針 P2/P3。

---

## 五、現有五處呼叫端會不會壞:**不會**,零遷移成本

### 證據一:五處註冊的第二個引數全部是 `self`

```
$ grep -rn "register_surface" src/ --include=*.gd | grep -v "func \|unregister"
src/ui/battle/battle_screen.gd:1272:	var register_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)
src/ui/battle/battle_screen.gd:2568:			var register_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)
src/ui/battle/battle_screen.gd:2678:		var register_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)
src/ui/battle/battle_screen.gd:3057:		var register_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)
src/ui/battle/battle_screen.gd:3101:	var register_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)
```
(上面省略了同一次 grep 命中的 5 行錯誤訊息字串,全部是 `"... returned %s instead of REGISTERED ..."`,
第二節引用的就是它們。)

### 證據二:`self` 是什麼型別

```
$ grep -n "^class_name\|^extends" src/ui/battle/battle_screen.gd
58:class_name BattleScreen
59:extends Node

$ grep -n '^\[node name="BattleScreen"' src/ui/battle/BattleScreen.tscn
12:[node name="BattleScreen" type="Node"]
```

### 判定

`BattleScreen extends Node` → **`self is Control` 為 `false`** → 落入第四節的非 `Control` 分支
→ 跳過兩項條件 → **回傳 `REGISTERED`,行為與今天逐字相同**。

**五處呼叫端一行都不必改,沒有遷移路徑要寫。**

### 🔴 但這正是本契約最重要的誠實事項

**今天唯一存在的已註冊表面,落在「結構性不適用」那一側。**
因此:

> **把 story-012 從 `Blocked` 解除,解除的是「現在寫得出會失敗的測試」這一點,
> 不是「機制十四在 production 被驗到了」。守衛的 `Control` 分支在 production 裡
> 仍然是空集合 —— 只是這次這件事在程式裡看得見(判決記為 `NOT_APPLICABLE`),
> 而不是像 2026-09-03 那樣藏在一條恆真的全稱斷言裡。**

**四種表面型別的覆蓋現況**(`grep -n "enum SurfaceType" src/ui/cursor/cursor_types.gd`
→ `enum SurfaceType { BOARD_TILE, RELATION_MINIMAP_NODE, CARD_SLOT, DIALOGUE_CHOICE }`):

| 表面型別 | 今天存在嗎 | 註冊的節點型別 | 守衛判決 |
|---|---|---|---|
| `BOARD_TILE` | ✅ 是(`battle_screen.gd` 五處) | `Node`(`BattleScreen`) | `NOT_APPLICABLE` |
| `RELATION_MINIMAP_NODE` | ❌ 否 | — | 從未呼叫 |
| `CARD_SLOT` | ❌ 否 | — | 從未呼叫 |
| `DIALOGUE_CHOICE` | ❌ 否 | — | 從未呼叫 |

**1/4 存在,0/4 真的執行過守衛的兩項條件。** 這句話必須原樣寫進 story-012 的證據檔
`production/qa/evidence/disable-native-focus-evidence.md`。

📌 **一個有根據但未驗證的預測,寫下來給下一個人**:`CARD_SLOT` 很可能是第一個真的觸發守衛的表面 ——
`src/ui/battle/HandBar.tscn` 的根節點是 `[node name="HandBar" type="Control"]`
(`grep -n '^\[node name="HandBar"' src/ui/battle/HandBar.tscn`)。
**但 `HandBar` 目前沒有註冊成游標表面**(上面的 grep 命中只有 `battle_screen.gd`),
所以這是預測不是事實。

### 守衛看不到的東西(契約的明文範圍,不是漏洞,但必須寫下來)

🔴 **機制十四約束的是「根 Control」,守衛也只檢查根節點,看不到子孫節點。**
今天這件事就有實例:`BattleScreen`(= 已註冊的 `BOARD_TILE` 表面)的子樹裡掛著
`BattleMenu`,而它:

```
$ grep -n '^\[node name="BattleMenu"' src/ui/menu/BattleMenu.tscn
5:[node name="BattleMenu" type="Control"]

$ grep -n "focus_mode = Control.FOCUS_ALL" src/ui/menu/battle_menu.gd
479:		row.focus_mode = Control.FOCUS_ALL

$ grep -n "BattleMenu" src/ui/battle/BattleScreen.tscn
113:[node name="BattleMenu" parent="UILayer" instance=ExtResource("7_battle_menu")]
```

亦即:**已註冊表面的子樹裡,現在就有三個 `focus_mode = FOCUS_ALL` 的 `Button`。**

**這不違反機制十四** —— 機制十四的單位是「表面」,而 `BattleMenu` 是一個**未註冊**表面
(GDD AC-60 明文允許未註冊表面使用原生 focus)。
**但守衛結構上無法分辨這兩種情況**,所以本契約明文界定:

> **守衛的射程 = `register()` 收到的那一個節點,僅此一個。**
> 它不走子樹、不回答「這個子樹裡有沒有別的原生 focus」。

⚠️ **另一個守衛看不到的東西:註冊之後才被改掉的 `focus_mode`。**
守衛是**註冊當下的一次性快照**。任何人在 `register()` 回傳之後寫
`surface.focus_mode = Control.FOCUS_ALL`,守衛不會知道。
要涵蓋它只能逐幀輪詢(= 乙案的形狀 + 幀預算成本),**本契約不涵蓋,登記為已知缺口。**

📌 **一條未查證的線索,留給實作者,不要當成事實**:
`docs/engine-reference/godot/breaking-changes.md:61` 逐字為
`| UI | Recursive Control behavior | Disable mouse/focus interactions across entire node hierarchies |`
(4.4→4.5 節)。若引擎真有這樣一個遞迴屬性,它可能一次解決上面兩個缺口中的第一個。
🔴 **該參考檔只有這一行,沒有 API 名稱,本文作者亦未查證** —— (B) 級線索,
查法以 `current-best-practices.md` / `breaking-changes.md` 為準,**不得照 `modules/ui.md` 查**
(`VERSION.md` 明文:該檔停在 4.6,對 UI 高風險項零命中)。

---

## 六、現在寫得出「會失敗的測試」嗎?

### 對工作單那句宣稱的查證結論:**一半成立**

story-012 文末的表格逐字寫著甲案「✅ 可以 —— 用合成的 `Control` / `Button` / `Node2D`
三種輸入直接驗,不需要真實表面存在」。

**方向正確,但它漏寫了一個會讓整條測試線靜默歸零的前提**:

> 🔴 **測試不得引用尚不存在的符號。**
> `RegisterResult.FOCUS_MODE_NOT_NONE_REJECTED` 或 `diagnostic_last_guard_verdict()`
> 在實作之前都不存在,而 `CursorSurfaceRegistry` 有 `class_name` 且呼叫端是靜態型別
> —— 引用它們是 **parse error**,不是斷言失敗。
> 依 `.claude/docs/coding-standards.md` 已登記的 **exit 105** 條目:parse error 發生在
> **測試收集階段**,`grep -c "Overall Summary"` 與 `grep -c " FAILED"` **兩個都回 0 命中**,
> 看起來與「乾淨通過」逐字相同,而實際上**整條測試線一條都沒跑**。
>
> **亦即:照工作單字面寫出來的「會失敗的測試」,很可能不是紅的,是空的。**

### 因此分兩批。Phase 1 的每一條都只用今天已經存在的符號

| # | 測試 | 輸入 | 斷言 | 今天 | 證明什麼 |
|---|---|---|---|---|---|
| T1 | `test_control_with_focus_all_is_rejected` | `Control`,顯式設 `focus_mode = FOCUS_ALL` | `result != RegisterResult.REGISTERED` | 🔴 **紅** | 條件 1 有被擋 |
| T2 | `test_rejected_control_is_not_stored` | 同 T1 | `get_surface(tag) == null` | 🔴 **紅** | 是**拒絕**不是「報錯但照收」(第二節的裁決本身) |
| T3 | `test_bare_button_is_rejected` | `Button.new()`,不動任何屬性 | `result != REGISTERED` | 🔴 **紅** | 預設 `Button` 進不來 |
| T4 | `test_button_with_focus_none_is_still_rejected` | `Button`,顯式設 `focus_mode = FOCUS_NONE` | `result != REGISTERED` | 🔴 **紅** | 🔴 **整批唯一能證明條件 2 真的被實作的一條** |
| T5 | `test_compliant_control_is_registered` | `Control`,顯式設 `focus_mode = FOCUS_NONE` | `result == REGISTERED` | 🟢 綠 | ⚠️ **今天是重言式** |
| T6 | `test_non_control_is_registered` | `Node2D.new()` | `result == REGISTERED` | 🟢 綠 | ⚠️ **今天是重言式** |

🔴 **T4 是這批的核心,理由要寫進測試檔的 doc comment**:
沒有 T4 的話,一個**只實作了條件 1** 的實作會讓 T1、T2、T3 全部變綠
(`Button` 預設的 `focus_mode` 若是 `FOCUS_ALL`,T3 會被條件 1 擋掉,條件 2 一行都不必寫)。
T4 把條件 1 這個成因**從輸入端移除**,剩下唯一能解釋拒絕的就是條件 2。
**這正是本專案 Story 007 AC-32 登記過的形狀的解法**(「斷言的結果有第二個成因」)。

⚠️ **T5 / T6 今天就是綠的,而且綠得毫無意義** —— 今天的 `register()` 對任何有效節點都回
`REGISTERED`。依第四節引用的 Check 4 新判準二的精神,它們在證據檔裡**必須標成
「今天為重言式,實作後才具迴歸價值」**,不得寫成「已驗證合規表面可以註冊」。

### Phase 2(只能在實作之後寫,否則 exit 105)

| # | 測試 | 斷言 | 為什麼不能提前寫 |
|---|---|---|---|
| T7 | 拒絕碼精確性 | `result == RegisterResult.FOCUS_MODE_NOT_NONE_REJECTED` / `NATIVE_HOVER_THEME_REJECTED` | 引用不存在的列舉成員 → parse error |
| T8 | 逃生門 | `Button` + `FOCUS_NONE` + hover/focus 覆寫成與 normal **同一實例** → `REGISTERED` | 同上(語意上今天也綠,無迴歸價值) |
| T9 | 判決帳 | 註冊 `Node2D` 後 `diagnostic_last_guard_verdict(tag) == NOT_APPLICABLE` | 呼叫不存在的方法 → parse error |
| T10 | 判決帳 | 註冊合規 `Control` 後 `== PASSED` | 同上 |
| T11 | 既有行為不變 | 違規節點 + 已佔用標籤 → 仍回 `DUPLICATE_TAG_REJECTED`(第二節的擺放位置條款) | 可提前寫,但今天綠且實作後也該綠 —— 迴歸測試,不是紅測試 |

### 🔴 測試線本身的四個已登記陷阱,寫測試前先讀

1. **同一個 suite 內,第一個失敗會中止其餘測試。**(`coding-standards.md` 已登記,2026-08-31 實測)
   T1~T4 四條今天都該是紅的,但**一次執行只看得到 T1 變紅**,T2~T4 根本沒跑。
   **「四條都紅」要花四次執行證明**(把前面的 `test_` 暫時改名移出收集,再還原)。
   **先把這個成本算進工時,不要在回報裡寫「四條都證明會紅」而只跑了一次。**
2. **合成節點一律 `auto_free()`**,否則 orphan → **exit 101**(通過但有警告,不是失敗,也不是 0)。
   本專案既有寫法可直接抄:
   `grep -n "auto_free(Node.new())" tests/integration/cursor/frame_buffer_ordering_test.gd`
   → `744:	registry.register(_SURFACE, auto_free(Node.new()))`
3. **交付時必須貼引擎自己的 `ENGINE EXIT` 與 `Overall Summary` 原始三行**
   (`CLAUDE.md` 2026-10-12 裁決的硬性義務),不是只說「測試通過」。
4. **`Overall Summary` 的 `failures` 數的是失敗斷言數,不是失敗測試數**(已登記)。
   不要用它估算壞了幾條。

### 🔴 實作前必跑的五支探針(本文作者被禁止執行,全部未驗證)

| # | 要問什麼 | 不先問會怎樣 |
|---|---|---|
| **P1** | `Control.new()` 與 `Button.new()` 的**預設 `focus_mode` 實際值** | T3 到底被條件 1 還是條件 2 擋的,會變成猜的。**訓練資料說 `Control`=`FOCUS_NONE`、`Button`=`FOCUS_ALL`,本專案零證據** |
| **P2** | **未 `add_child()` 的出樹節點**,`has_theme_stylebox(&"hover")` / `get_theme_stylebox(&"hover")` 回傳什麼 | 🔴 `register()` **不要求節點在樹上**,而本專案唯一的主題查詢前例(`tests/unit/ui/menu/battle_menu_layout_test.gd`)是**先 `add_child(probe)` 才查的**。若出樹查詢回傳不同結果,守衛會依「節點註冊時在不在樹上」給出不同判決 —— 那是最糟的一種不決定性 |
| **P3** | `add_theme_stylebox_override(&"hover", x)` 之後,`get_theme_stylebox(&"hover")` 是否回傳**同一個實例**(參照相等) | **第四節的整個機械判準押在這上面。** 若引擎回傳複本,逃生門(T8)永遠無法通過,合法的「顯式清空」會被守衛擋死 |
| **P4** | GdUnit4 下,production 程式碼內的 `push_error` 會不會讓該測試**自動判紅** | 🔴 若會,T1~T4 這四條「預期被拒絕」的測試會被守衛自己的 `push_error` 弄紅,變成**無論實作對錯都過不了**。那會**推翻第二節的 `push_error` 條款**,必須改設計(例如改 `print_rich` 或加旗標),不是改測試 |
| **P5** | Godot 4.7 對 `focus_mode` / 雙焦點 / 主題查詢有無 API 層變更 | 已初步查:`breaking-changes.md:34` 與 `current-best-practices.md:133` **各只有一行**,都只寫「Mouse/touch focus now separate from keyboard/gamepad focus」,**沒有任何 API 層細節**。🔴 **不得查 `modules/ui.md`** —— `VERSION.md` 明文該檔停在 4.6、對 UI 高風險項零命中 |

**P4 是唯一一支會推翻本契約條款的探針,建議第一支跑。**

---

## 七、我沒有考慮進去的因素(誠實清單)

1. **註冊之後才被改掉的 `focus_mode`。** 守衛是註冊當下的一次性快照。
   任何人在 `register()` 回傳後寫 `surface.focus_mode = FOCUS_ALL`,守衛不會知道。
   涵蓋它只能逐幀輪詢(= 乙案形狀 + 幀預算成本)。**本契約不涵蓋,登記為已知缺口。**
2. **子孫節點。** 守衛只看 `register()` 收到的那一個節點。
   今天 `BattleScreen` 子樹裡就有三個 `FOCUS_ALL` 的 `Button`(第五節附證據)。
   那些不違反機制十四(它們屬未註冊的 `BattleMenu` 表面),**但守衛結構上分不出來。**
3. **「視覺上不可區分」被我換成了「參照相等」。** 這是一個比 ADR 更嚴的機械近似,
   會誤拒「兩個長得一樣但不同實例的 `StyleBoxEmpty`」。第四節已寫明,
   但**我沒有評估這會不會讓某個真實的 UI 寫法做不下去** —— 四種表面型別裡有三種還不存在,無從評估。
4. **執行期換主題。** `Control.theme` 被換掉、或祖先的主題傳播改變,會讓同一個節點在不同時間
   對同一個查詢給出不同答案。守衛只在註冊那一刻看一次。**完全未考慮。**
5. **非 `Control` 但自己畫高亮的節點。** ADR 說非 `Control` 的「兩條管線都不存在」,
   指的是**引擎原生**管線。一個 `Node2D` 自己畫第二個高亮框,機制十四射不到,守衛也射不到。
   **這不是守衛的漏洞,是機制十四的射程** —— 但下一個人可能會以為守衛保證了「只有一個高亮」。
6. **其餘三種表面型別的實際節點型別未知。** `CARD_SLOT` 很可能是 `Control`
   (`HandBar.tscn` 根節點是 `Control`),但它今天沒有註冊。
   **本契約從未被一個真的是 `Control` 的已註冊表面測試過。**
7. **效能完全未量測。** 守衛替 `register()` 加了一次型別判定 + 最多四次主題查詢。
   非逐幀路徑,但 `battle_screen.gd` 在狀態機轉換時會反覆 register/unregister(S0↔S2↔S3,
   第五節的五處就是這些轉換點)。**我判斷可忽略,但這是判斷不是量測。**
8. **判決帳的兩個邊界我沒有決定**(從未註冊過的標籤回傳什麼、`unregister()` 後要不要清),
   第四節已標為「實作前停下來問」。
9. **我沒有跑引擎、沒有跑測試、沒有開任何 `.tscn` 看畫面**(派工明文禁止)。
   本文全部引擎行為宣稱為 **(C) 級**,全部集中在第六節的 P1~P5。
   依 `technical-preferences.md` 的規定,**本文不得被引用為任何 (A) 級結論的來源。**
10. **乙案、丙案我沒有重新評估** —— 管理者已裁決甲案,重開那個比較不是本次職權。
11. **我沒有查 `tr-registry.yaml` 的 TR-cursor-018 原文。** story-012 自己註明
    「審查時請當場讀最新版」,而本次任務的六題都不依賴它。
    **若 TR-cursor-018 對執行點有額外要求,本契約可能與它衝突 —— 這一點未查證。**

---

## 本文的後續動作(不由本文執行)

1. 管理者核准本契約 → 2. 跑 P1~P5 五支探針(**P4 優先**) → 3. 依探針結果回頭修本契約
→ 4. 實作 + Phase 1 測試 → 5. 更新 ADR-0005 機制十四(加一段「執行點」)、
`docs/registry/architecture.yaml`、story-012 解除 `Blocked`。

🔴 **第 5 步會動到 ADR-0005,而依 `technical-preferences.md` 的流程劑量上限規則 4
「同一份文件不做第三次以上修訂」—— ADR-0005 的修訂次數本文未清點。**
動它之前先當場數,不要假設還有額度。
