# Active Session State

<!-- STATUS -->
Epic: 架構階段(Foundation + Core 層 ADR 系列)
Feature: 單一游標/高亮狀態系統
Task: **2026-08-21 第二批(最新)—— ADR-0003 軌**。探針 F/G 關閉該 ADR 全部五項 VR(它是五份 ADR 裡唯一從未上引擎的一份),**決策實質成立但寫法錯 18 處**:`bytes_to_var(buffer, false)` 兩引數形狀在 4.7.1 是 **Parse Error**(ADR 寫的是 Godot 3 簽章)。另推翻三項宣稱,並關閉懸置三輪的 E1/R3(核心推理成立,但它舉的例子不成立、**嚴重低估 `Signal`**〔還原後 `emit()` 實測真的執行處理函式〕、建議修法不足)。🔴 **ADR-0003 修訂草案已寫,但 Step 5.5 雙軌覆核皆判不可寫入:6 項 BLOCKING,其中 4 項是草案自己引入的 —— 模式 A 第九場。** 六項:收窄後的核心宣告仍被同一批 log 否證(`EncodedObjectAsID` 實測 `is Object=true`)、遞迴閘門無深度上限致 stack overflow(而引擎自己反而有循環防護)、公開簽章變更的**唯一理由實測為假**(`var_to_bytes({})`=8B,合法編碼永不為 0)、範圍宣告漏掉 ADR 自己示意圖的外層呼叫**與** `FileAccess.store_var/get_var` 等價旁路、讀取側閘門套用點未定(字面上可能什麼都攔不到)、「數學型別」四個字承載 16 個 Variant 型別的命運(且覆核者照表實作出來的實測是**黑名單**)。三項裁決已定:A1 採主案 + 三條件、A2 用既有 `DATA_CORRUPTED` 不新增值、D1 **ADR-0002 不需要改且 ADR-0003 不可替它記帳**(其 `typeof()` 是逐欄位**正向**白名單,天生免疫漏列)。**下一步:依檔末最後一節重建草案 → 修六項 BLOCKING + 約 15 項高 → 窄範圍 Step 5.5 重跑(前次修訂的同型陷阱就在正下方)→ 建 `core-serialization.md` 參考庫 → 第八輪 `/architecture-review`(本 session 原定 A → B,B 未執行)。** ⚠️ **草案在 session 專屬 scratchpad,新 session 讀不到,必須依檔末那節重建。** ／以下為前一批:2026-08-20 /architecture-review **第七輪**已完成(CONCERNS)—— 依第六輪交代重推游標 19 項為 **12/7/0**、好感度 24 項為 **21/3/0**,全域 130 項 **64 ✅ / 34 ⚠️ / 32 ❌**。**🔴 ADR-0002 判定不可進 `Accepted`**:兩項 BLOCKING(R7E-6 `FUTURE_TIME_QUERY` 死碼、R7E-4 enum 參數靜默轉換)+ R7-P1/P2/P3 + R7E-2 共 17 項,成因是修訂新增範圍宣告時漏稽核既有的三個 `Variant` 入口。同日跑三支探針實機確認 R7E-4、把 R7E-2 升為已實測缺口、關閉 R7E-1/R7E-13,並**推翻機制四「INVALID_PAIR/INVALID_SOURCE 理論上不可達」**。R6-6~R6-13 **八項全部仍開**。新增銜接缺口 C7。已順手修正 `current-best-practices.md` 的 `@abstract` 錯誤範例與 registry 兩個過時欄位。✅ **2026-08-21:中斷點已解除** —— 探針 D 執行完畢(exit 0),殘留 #1/#2 **兩項皆關閉**(`values().has()` 越界輸入與 `keys().has()` 非法名皆乾淨回傳 `false`、不中止),**R7-P1/R7-P3 建議修法地基成立,ADR-0002 修訂的前置條件已解除**。✅ **2026-08-21:ADR-0002 第四次修訂已完成並寫入**(17 項全數處理;Step 5.5 雙軌覆核**兩輪**,共抓出 15 項 BLOCKING/高,**其中 12 項是修訂草稿自己引入或漏掉的**;協調者自行 grep 另抓到範圍宣告連續被低估三次 + 一句被自己修法弄假的既有宣稱)。ADR-0002 651 → **974 行**,registry 69 → **78 項**(ADR-0002 佔 22)。**涵蓋分佈不自陳,待第八輪。** ✅ **同日 ADR-0005 第四次修訂亦已完成並寫入**(R6-6~R6-13 八項 + 五項事實層;Step 5.5 雙軌 2 BLOCKING + 11 非阻塞)。ADR-0005 1440 → **1600 行**,registry 78 → **81 項**(ADR-0005 佔 29)。**兩份 ADR 的涵蓋分佈皆不自陳,待第八輪。** ✅ **同日 ADR-0004 / 0003 / 0002 事實層修訂已完成並寫入**(零決策內容,7 項 + Step 5.5 覆核衍生 3 項 + 協調者自行抓到 2 項)。**先跑探針 E 才動筆** —— ADR-0004 第 91 行的 `-> Variant` 不在已測五種之內,屬外推;探針 E 關閉它、並**逐字編譯機制一的完整組合**,額外測出「字面 `ClassName.new()` 構造抽象類別是編譯期 Parse Error」。ADR-0004 的 5 處 `pass` + 第 71 行根因指示句 + VR #6/#6a 全部關閉(新增 #6b 登記三條未查證的間接構造路徑);ADR-0003 第 17 行的 HIGH 評級**維持 HIGH、理由由三項收為兩項**;ADR-0002 第 603 行補上交叉引用。**另關閉兩處「全數覆蓋」過度宣稱:ADR-0003:350 是第五處(唯一不在 ADR-0004 檔內者,第五輪「四處全數清除」的定義域小於措辭)、`design/gdd/systems-index.md:4` 是第六處(同一行的 `TR-save-*` 早已修正,只被修了一半)。** **registry 不新增條目,維持 81 項**(逐節實測 10/11/29/31、零重複鍵)。**三份 ADR 皆不自陳涵蓋分佈,待第八輪。** 下一步:建立 `docs/consistency-failures.md`(第七次提出)、全新 session 跑第八輪 `/architecture-review`。
<!-- /STATUS -->

**最後更新**:2026-08-21(**第二批**)—— 探針 F/G/H/J 四支 + ADR-0003 修訂草案 + Step 5.5 雙軌覆核(**兩軌皆判不可寫入**)。提交 `324fb02`/`27217ec`/`aee86fc`。**詳見檔末最後一節** —— 那一節是 scratchpad 草案的 durable 替代品,草案本身新 session 讀不到。

**前一批**:2026-08-21 —— (1) 探針 D 執行完畢,第七輪兩項殘留未查證項關閉;(2) **ADR-0002 第四次修訂完成並寫入**(17 項 + Step 5.5 雙軌兩輪覆核的 20 項修正)。詳見檔末兩節 Session Extract。以下為前次更新內容。

**前次更新**:2026-08-19 —— `/architecture-decision` **第三次修訂 ADR-0005**,處理第五輪 `/architecture-review` 的 R5-1~R5-6 與 S-1~S-5 共 11 項,並在寫入前先跑 `godot-specialist` Step 5.5 覆核(使用者明文授權),該覆核再抓出 6 項(其中 4 項是本次修法自己新產生的)。**R5-1 為 BLOCKING**。連帶修訂 ADR-0004(Validation Criteria 第 6/7 項順序,R5-4)、`docs/registry/architecture.yaml`(65 → 68 項)與 `.claude/docs/technical-preferences.md`。詳見下方「Session Extract — `/architecture-decision` 第三次修訂」。

### 本次核對出的三項新事實(不在第四輪的 7 項清單內)

1. **四個重置觸發點裡有三個沒有呼叫點** —— `ResetTrigger` 列舉在第一次修訂建立了 (a)(b)(c)(d),但全文只有 (c) 真的有 `_reclaim.reset()` 呼叫位置。與 `-015`(a) 漏掉「甲/乙分支重置為 0」是**同一根因**:補了列舉與訊號,沒補呼叫點地圖。已於機制二的列舉逐值標註呼叫點。
2. **`CursorState` 拿不到滑鼠座標** —— F2 把 `evaluate()` 改收「目前滑鼠座標」,但它是 `RefCounted`、不在場景樹上,全文唯一取得座標的方式在機制九的 `CursorStateHost`。建構子新增 `mouse_position_provider: Callable`(單元測試可直接注入常數 lambda,Validation Criteria #2 仍成立)。
3. **ADR-0004 第 498 行第四處「全數覆蓋」** —— `TR-save-* 系列至此三份 ADR 全數覆蓋`,與同檔第 27/421 行已在 `1c3d5d0` 改成的「22/7/1」矛盾。已修正。

### 2026-08-19 ADR-0005 第二次修訂摘要(本次工作)

| 項 | 修法 |
|---|---|
| **R4-2**(BLOCKING) | `diagnostic_seed_position()` 改標 `@abstract`,實作下放子類別。基底讀子類別欄位是純靜態閱讀即可 100% 確認的編譯期錯誤 |
| **R4-1**(視同 BLOCKING) | `arbitrate_frame()` 拆為 `arbitrate_device_authority()`(−100)+ `apply_buffered_navigation()`(**新增 −25 子節點 `CursorNavigationApplier`**)。梯子五→**六**行為者,定序自 1&3→2→4 改為 GDD 的 1→2→3→4。緩衝清空責任移到 −25 |
| **R4-3**(視同 BLOCKING) | 平滑器改為**上升立即同步、只對下降(且非觸發點 (d))限速**。原版對上升也限速 → 結構上不可能在跨門檻當下達 100% |
| **R4-4** | 明文區分五個掛閘門的公開入口 vs 不掛閘門的私有 `_write_target_internal()`;公開入口**不得互相呼叫**。另補:兩個回傳 `void` 的入口不可能回傳 `REJECTED_REENTRANT`,其閘門語意為 no-op + 診斷計數 |
| **R4-5** | `ui_*` action 改為**明文三分割**(NAVIGATION / CONFIRM / 明文承認的 OTHER)+ 機制七 (c) 載入期 `UI_ACTION_UNCLASSIFIED` 驗證。不採「未命中即回報」是因為會把數十個引擎內建報成噪音,反而被關掉 |
| **R4-6** | 刪除 `call_deferred()` 路線,只留旗標路線 |
| **R4-7** | **部分修正第四輪採納的修法方向** —— 陳述順序只對**相鄰**角色成立;②與⑥之間隔著③④,雙角色系統**必須拆兩個節點** |
| **`-015`(a)** | 新增第五個 `ResetTrigger` 值 `SURFACE_HANDOFF`(來源 Core Rules #7,非 #3 的四點),甲/乙分支呼叫 |
| **`-015`(b)** | 丙分支自無條件「重新計算」改回 GDD 的條件式:原目標仍有效得直接沿用,僅失效才依 Core Rules #6 重算 |

**跨 ADR**:C1 由 ADR-0004 接下 `TOKEN_TIMEOUT_MS`(定死推導規則 + 版本連動測試,不定死毫秒數);C3 ADR-0002 的 `Mutex` 保留為**縱深防禦**、措辭不再宣稱是唯一已成立的執行緒安全義務;C6 ADR-0004 補回指 ADR-0005 機制十一並寫明義務歸呼叫方。

**Registry**:61 → **65** 項(新增 4:1 api + 3 forbidden;就地修訂 7 項,`revised: 2026-08-19b`)。實測各節 10 state / 10 interface / 23 api / 22 forbidden。

> **未執行 `godot-specialist` 驗證(Step 5.5)** —— 本 session 的環境設定明文禁止在使用者未要求的情況下呼叫 Agent 工具。第三、四輪的紀錄顯示該驗證每次都抓到主審漏掉的東西(N1~N4、R4-4),**這是本次修訂與前兩次相比缺少的一道關卡**,已列為下方待辦。

### 2026-08-19 ADR-0005 第一次修訂摘要

逐項處理第三輪審查的 9 項待修訂,並經 `godot-specialist` 對修法本身做第二輪技術驗證(7 項確認 SOUND,2 項標記 UNVERIFIABLE-FLAG-AS-RISK 已登記為 Verification Required):

- **F1(BLOCKING)**:機制六由四行為者改為五行為者,新增「呼叫方主動改標」(priority −50),下游確認動作判讀提升為明文架構約束(必須在 `_process()`,絕不可掛 `_input()`/`_unhandled_input()`)。補上 `process_priority` 不跨 `_process`/`_physics_process` 兩鏈的前提說明。
- **F5(BLOCKING)**:`_process()` 補上 `_arbitration_suspended` 檢查;suspend/resume/FOCUS_OUT/FOCUS_IN 四個進出點全數補 `_frame_events.clear()`。
- **F2**:`MouseReclaimPolicy.evaluate()` 改收目前滑鼠座標而非位移量,策略內部持有 `_seed` 自算淨位移,結構性杜絕路徑總和實作。新增「單一根 Viewport」明文假設。
- **F3**:新增 `reset_triggered` 訊號 + 呈現層平滑器(`move_toward()` 收斂,僅觸發點 (d) 瞬間歸零),取代原本直綁 `modulate.a`。誠實記錄 Validation Criteria #8 契約寬度已從「三方法」變為「三方法+一訊號」。
- **F4**:機制十五診斷欄位改採樣呈現值而非判定值。
- **N1**:新增機制四之二 `classify_action()`(`InputMap.event_is_action()`),補入核心依賴涵蓋率表。
- **N2**:新增 Verification Required #10(`_notification()` 時序未定義)。
- **N3**:新增機制十三之二——未登記表面 hover 時暫時恢復原生指標,並明文承認此為技術層解法、不越權替 GDD 做設計裁決。
- **N4**:`CursorState` 新增 `target_changed()`/`device_authority_changed()` 訊號(正式採訊號推送),新增 `_mutation_in_progress` 重入閘門與 `REJECTED_REENTRANT` 回傳值,比照 ADR-0001 `settlement_in_progress`。
- **附帶關閉**:TR-cursor-001 的條件式涵蓋(F2 修法的必然結果,新增 `diagnostic_seed_position()`)。

**新增 Verification Required 3 項(共 12 項)**、**Requirements 新增第 11 項**、**Constraints 新增 2 項**。ADR 本身明文聲明**不自陳修訂後的涵蓋分佈**——留給獨立 session 的第四輪 `/architecture-review` 重新推導,避免重蹈第三輪抓到的自陳膨脹模式(16/3 → 11/8)第三次發生。

**待辦**:(1) Registry 更新提案待使用者核准(見下方);(2) 全新 session 跑第四輪 `/architecture-review`;(3) 本次修訂與 registry 更新待 commit。

> **本檔案是現況快照,不是流水帳。** 歷史細節在 `docs/architecture/architecture-review-*.md`、`design/gdd/reviews/*.md` 與 git history;此處只保留「下一個 session 需要知道什麼」。

---

## 一、現況

| 項目 | 狀態 |
|---|---|
| **專案階段** | 架構階段(Technical Setup → Pre-Production 之間) |
| **GDD** | 4 份系統 GDD:好感度數值池、存檔系統、單一游標/高亮狀態系統 = **Approved**;戰棋移動與交戰系統 = **Designed,尚未 Approved** |
| **ADR** | **5 份,全部 `Proposed`,無一 `Accepted`**。ADR-0002 已於 2026-08-21 完成第四次修訂(第七輪 17 項),**但涵蓋分佈與可否 `Accepted` 皆待第八輪獨立 `/architecture-review`** —— 本 ADR 明文不自陳 |
| **架構登記處** | **81 項立場**(10 state-ownership、11 interface contracts、**29** API decisions、**31** forbidden patterns)—— 2026-08-21 ADR-0005 第四次修訂新增 3 項,ADR-0005 佔 29 項。以下為前次紀錄:**78 項立場**(10、11、**28**、**29**)—— 2026-08-21 ADR-0002 第四次修訂新增 9 項(5 api / 4 forbidden)+ 就地修訂 2 項,**ADR-0002 佔 22 項**(逐節實測)。以下為前次紀錄:**69 項立場**(…23 API、25 forbidden)—— 2026-08-20 ADR-0002 修訂新增 `raw_variant_subscript_into_typed_container`,ADR-0002 佔 13 項。以下為前次紀錄:**68 項立場**(10 state-ownership、11 interface contracts、23 API decisions、24 forbidden patterns)—— 2026-08-19 第三次修訂後逐節實測,**第六輪獨立重測確認零落差**(修掉 2 處 `revised:` 欄未同步與 1 處 YAML 重複鍵之後)。ADR-0005 佔 26 項(3/5/7/11) |
| **需求涵蓋** | 130 項 TR:**64 ✅ / 34 ⚠️ / 32 ❌**(2026-08-20 **第七輪** `/architecture-review` 獨立重推);游標系統 **12 ✅ / 7 ⚠️ / 0 ❌**、好感度 **21 ✅ / 3 ⚠️ / 0 ❌**。⚠️ **下降不是 ADR 退步** —— 第五輪的 68/30/32 與游標 15/4/0 是在 R6-6~R6-13 被發現**之前**算的,第六輪發現了那 8 項但範圍限縮未重推;本輪是第一次把它們算進涵蓋判定。三個 Foundation 系統合計 73 項**仍只有 1 項缺口**(`TR-save-030`)|
| **最新審查判定** | **CONCERNS**(2026-08-20 **第七輪**;第三~七輪皆 CONCERNS)。但與第六輪(零 BLOCKING)有實質差異:**三份 ADR 各帶 BLOCKING 級項目,且沒有一項屬於涵蓋缺口** —— 全部是已寫下的決策內容與已實測的引擎現實不符(ADR-0002 兩項 BLOCKING;ADR-0004/0005 共 13 處 `@abstract func ...: pass` 為已證實的編譯期錯誤)。**32 項 ❌ 中 25 項在戰棋系統**,該 GDD 尚未 Approved,故沿用第二輪標準不判 FAIL;⚠️ 若戰棋 GDD 先於其演算法層 ADR 達 Approved,判定退回 FAIL |
| **實作** | `src/` 為空,尚無任何程式碼。**但 2026-08-20 已實證 Godot 4.7.1 可在本機 headless 執行**(執行檔在 `~/Downloads/Godot_v4.7.1-stable_win64.exe/`,不在 `PATH` 上)—— 多份 ADR 寫的「本專案無 Godot 執行環境」是錯的,見檔尾 Session Extract |

### ⚠️ 兩個結構性阻擋(比任何單一缺口都重要)

1. **5 份 ADR 全為 `Proposed`。** **🔴 2026-08-20 第三次更新(第七輪 `/architecture-review` 判定):ADR-0002 仍不可進 `Accepted`。** 2026-08-20 的修訂確實關掉了 F-6 BLOCKING(改採包裝類別 `AffinityRecordList`,且第七輪探針 A 已實機確認該宣告兩形皆編譯、兩層型別皆保住),**但第七輪抓出 17 項新的待關項,其中 2 項 BLOCKING**:R7E-6(`ReadRejection.FUTURE_TIME_QUERY` 是死碼 —— `t_query: Variant` 才是本 ADR 真正的 `Variant` 入口,而機制四之三的範圍宣告完全沒稽核它)、R7E-4(enum 型別化參數對數值近親**靜默轉換**,已由探針 B 實機確認 → 記錄寫進錯誤配對且回傳 `NONE`)。**探針另推翻機制四「`INVALID_PAIR`/`INVALID_SOURCE` 理論上不可達」那句話**(R7-P1,高)。**因此「ADR-0002 是最接近可 `Accepted` 的一份」這個說法在結構上仍成立(`Depends On: None`、零缺口),但「可以現在裁決」不成立。** 全框架五個消費者、零個生產者 —— `Accepted` 是使用者裁決,而現在還不到那一步。依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被**自動阻擋**。
2. **`/gate-check pre-production` 仍不可執行,但缺口性質已完全改變**(2026-08-19 實測):✅ `tests/unit/`、✅ `tests/integration/`、✅ `.github/workflows/tests.yml`(`/test-setup` 建立);⚠️ **`design/ux/accessibility-requirements.md` 一直都存在**(2026-08-06 建立)——**第一~五輪 `/architecture-review` 全部報「不存在」是查錯路徑**(查 `design/accessibility-requirements.md`,少了 `ux/`),框架側引用已於 2026-08-19 分兩次修正——第一次修 17 處(缺 `ux/`),**當日稍後重掃又發現另外兩類殘留**:3 份 template 指向第三條錯路徑 `docs/accessibility-requirements.md`(頂層目錄就錯),以及 1 份 ux-designer agent-memory 明文斷言「該檔不存在於專案任何地方」(寫於 2026-08-05,檔案 2026-08-07 進 git——會自動載入該 agent 的脈絡,等於每次都餵它假事實)。兩類皆已於同日修正;該檔的 Tier 亦已定案為 **Standard**;✅ `design/ux/interaction-patterns.md` **已於 2026-08-19 由 `/ux-design patterns` 建立**(15 個模式)。**pre-gate 五項至此全部具備**——但 `/gate-check pre-production` 仍不保證通過:閘門另有 ADR `Accepted`、UX 規格覆蓋等條件,且本檔尚未經 `/ux-review` 驗證。**注意**:CI 目前帶一個暫時性守衛(`project.godot` 不存在時跳過並直接成功),綠燈**不代表測試通過**——移除條件寫在 `tests/README.md` 與 workflow 註解裡。

---

## 二、2026-08-18 完成(3 個提交,已推送)

| 提交 | 內容 |
|---|---|
| `1c3d5d0` | **第二輪 `/architecture-review`** —— FAIL,涵蓋率 5/16/109 → **50/24/56**。重建 `traceability-index.md` 全部 130 列。**獨立推翻三處文件宣稱「全部 30 項 `TR-save-*` 皆有 ADR 覆蓋」**(實為 22/7/1;`TR-save-030` 被列在 ADR-0004 表內但同格寫「本 ADR 不解決此問題」),三處已修正 |
| `a56dd10` | 補登 **3 項專案級 forbidden pattern**(`rng_in_combat_settlement`、`networking_features`、`procedural_terrain_generation`,連續兩輪審查缺席);修正 C2/C4/C5 三項銜接缺口 |
| `c282803` | **ADR-0005 游標裝置權威輸入架構** —— 關閉第二輪審查的唯一 FAIL 成因。Registry 41 → 55 |

### 本日兩次自我修正(記錄以免重蹈)

- **grep 命中 ≠ 實際使用**:一度懷疑 ADR-0001 仍活用 `duplicate_deep()`(grep 2 處),逐行核對後推翻 —— 兩處分別在**已拒絕的** Alternative 與「本方案不複製盤面故不相關」的聲明裡。`godot-specialist` 獨立得到同一結論。
- **等死掉的背景任務**:ADR-0005 的 Step 5.5 專家驗證因行程結束而中斷,我沒偵測到就一直等。**教訓:背景任務需主動查狀態,不要無限期等待。**

---

## 三、下一步(建議順序)

> **⚠️ 本節為 2026-08-18 撰寫的舊清單,已被檔案末尾「Session Extract — /architecture-review 第六輪」的「下一步」取代。** 第 1~4 項全部完成(第三~六輪審查、三次 ADR-0005 修訂、`/test-setup`、`/ux-design patterns` + accessibility Tier 定案)。保留原文供追溯,**規劃時請以末尾那份為準**。

1. ~~全新 session 跑 `/architecture-review`~~ —— **✅ 第三、四輪皆已於 2026-08-19 完成**,兩輪皆判 CONCERNS。第三輪推翻 ADR-0005 自陳 16/3 為 11/8;第四輪重推為 13/6,並抓到「修法本身引入新缺陷」的新模式。**第五輪待跑(針對第二次修訂)。**
2. ~~全新 session 修 ADR-0005 的 9 項待修訂 + C1/C3/C6~~ —— **✅ 已於 2026-08-19 完成兩輪**(第一次修訂處理 F1~F5+N1~N4;第二次修訂處理第四輪的 R4-1~R4-7 + `-015` 兩項落差 + C1/C3/C6)。**下一步是全新 session 跑第五輪 `/architecture-review`。**
3. ~~**`/test-setup`**~~ —— **✅ 已於 2026-08-19 完成**,補齊 pre-gate 五項中的三項。注意 CI 帶暫時性守衛,綠燈不代表測試通過。
4. ~~**`/ux-design`**~~ —— **✅ 已於 2026-08-19 完成**(`interaction-patterns.md` 15 個模式;`accessibility-requirements.md` 一直都存在、Tier 定案 Standard)。原文:pre-gate 剩餘 2 項(`accessibility-requirements.md`、`interaction-patterns.md`)。注意 `cursor-highlight-state.md` 已登記一項**孤兒義務**:運動無障礙需求(奪權門檻可調整性、瞄準輔助)先前口頭轉交至一個**不存在的檔案**。
5. **剩餘 2 份 ADR**(第三輪判定此為投入產出比最高的單一動作 —— 第一項一次移動 35 項 ❌ 中的大部分):戰棋盤面演算法層(可達格/威脅範圍/視線,`TR-tactical-002`~`-010`、`-019`~`-021`、`-037`~`-039`);回合結構擁有權 + 缺席的 AI/遭遇系統(`TR-tactical-034`、`-041`)—— **全專案無人認領回合結構**,而 `tactical-combat-system.md` Core Rules #9 明文要求敵方回合消費這些查詢。

---

## 四、待處理清單

### A. 跨 ADR 銜接缺口 —— **✅ C1/C3/C6 已於 2026-08-19 第二次修訂關閉,C2/C4/C5 早前已修。本節六項全數關閉**

> 以下三段保留原始描述供追溯,**處置結果**:C1 —— ADR-0004 接下 `TOKEN_TIMEOUT_MS`(機制六新增推導規則 `TOKEN_TIMEOUT_MS ≥ SAFETY_FACTOR × (鏈深上界 × 幀預算 + 兩階段回寫最壞 I/O)`,`SAFETY_FACTOR ≥ 10`;Validation Criteria 新增版本連動測試;registry 新增 `token_timeout_ms_ownership`)。C3 —— ADR-0002 的 `Mutex` 保留為縱深防禦,措辭改為不再宣稱是唯一已成立的執行緒安全義務,並明文交叉引用 ADR-0004 已把條件判為「否」。C6 —— ADR-0004 `Related Decisions` 補回指 ADR-0005 機制十一,寫明游標交接義務歸呼叫方而非存檔系統。**三者皆未改動任何機制決策,只動擁有權與措辭。**

#### (原始描述,已關閉)

- **C6(第三輪新增,低嚴重度)**:ADR-0005 宣稱機制十一與 ADR-0004 的存檔讀取路徑「直接交接」,但實測 **ADR-0002/0003/0004 對「游標」/「cursor」零命中**。不是矛盾(GDD Core Rules #7 把義務歸給呼叫方戰棋系統,而非存檔系統 —— 兩者皆宣稱不理解遊戲實體語意),但 ADR-0004 不宜在單方面被宣稱交接的狀態下逕行 `Accepted`。**建議解:ADR-0004 的 `Related Decisions` 補一句指回 ADR-0005 機制十一並說明義務歸屬。**

- **C1 —— `TOKEN_TIMEOUT_MS` 無人擁有**:ADR-0002 Risks 表明文委派給「存檔系統 ADR」,ADR-0004 機制六明文退回「該系統的職責,非本系統補償」。而 ADR-0004 的分步遷移跨越「數個至數十個影格」,正是 ADR-0002 自己預測會誤判為逾時回收的情境。**建議解:由 ADR-0004 接下**(只有它掌握遷移鏈深度上界)。
- **C3 —— `Mutex` 條件已解未回傳**:`TR-affinity-016` 是條件式需求(「**若**選擇背景執行緒序列化」),ADR-0004 已把條件判為「否」(不引入背景執行緒 + 主執行緒斷言),但 ADR-0002 仍宣稱其無條件 `Mutex` 是「專案唯一執行緒安全義務」。**建議解:保留為縱深防禦,但明文交叉引用 ADR-0004。**

> 兩者都會**新增/改變 ADR 決策內容**,屬 `/architecture-decision` 領域,不應在審查 session 處理。5 份 ADR 皆 `Proposed`,現在調和成本最低。

### B. 引擎參考庫的結構性缺口(兩份 ADR 各自獨立撞到)

- **`modules/` 全部 8 份文件標記 `Engine: Godot 4.6`,而專案釘選 4.7.1** —— 落後一個大版本。
- **ADR-0005 的 8 項核心引擎依賴中 6 項在參考庫零命中**(`process_priority`、Autoload、`focus_mode`/`FOCUS_NONE`、`accept_event`、`CanvasLayer`、`Input.mouse_mode`),另 2 項只在 4.6 文件裡。ADR 已明文承認其機制五/六/十四的證據基礎**弱於**本專案其他 ADR。
- **建議新增兩份模組文件**:`core-scripting.md`(序列化/雜湊/檔案 I/O/並發原語 —— ADR-0001~0004 的高風險項整批落在此)、以及一份涵蓋 **Node 生命週期與輸入派發語意**的文件(`process_priority`、`_input`/`_unhandled_input`/`_gui_input` 派發鏈與 `accept_event()`、Autoload 語意、`CanvasLayer`、雙焦點下的 `focus_mode`)。

### C. ADR-0005 實作第一天應先跑的 4 項驗證

成本都極低、後果全有全無 —— 跑完才知道要不要回頭改 ADR:

1. `process_priority` 不涵蓋 `_input()`,且「該影格全部 `_input()` 完成後才進 `_process()`」—— **機制六定序的全部基礎**,幀精準測試
2. Agile Event Flushing 的確切設定鍵字串 —— 一次 `ProjectSettings.has_setting()` 查詢
3. `Button` 設 `focus_mode = FOCUS_NONE` 後滑鼠懸停**是否仍畫 hover 主題** —— 決定機制十四第 2 項條件是硬性要求或防禦性建議
4. `@abstract class_name Foo extends RefCounted` 最小檔案語法 —— **🔴 2026-08-20 更正:本項在第三輪被判定為「可從印象升級為已查證」,那次升級無效。** 依據是逐字比對 `current-best-practices.md` 第 41–49 行,而**該範例本身是錯的**(`@abstract func ...: pass` 在 4.7.1 是 `Parse Error: An abstract function cannot have a body.`,正確形式是裸簽章)。**該錯誤範例已於 2026-08-20 第七輪修正**(第 47–48 行 + 更正註記)。**現況:裸簽章已實測對 `Array[T]`/`bool`/`float`/`void`/`Vector2` 五種回傳型別皆合法,`@abstract` 類別內可同時含 `signal` 與多個 `@abstract func`,漏實作抽象方法是編譯期錯誤 —— 語法問題本身已關閉。** 真正的殘留是:**ADR-0004 五處、ADR-0005 八處(共 13 處)`pass` 主體尚未刪除**,外加兩處明文指示句(ADR-0004:71、ADR-0005:1151「下方沿用該形式」)—— 只刪 `pass` 不改那兩句,下一個實作者會照著加回來。
5. **(第三輪新增)`_notification()` FOCUS_IN/OUT 相對 `process_priority` 的時序** —— 餵給 F5,現有 9 項 Verification Required 沒有這一項

> 第 2 項(Agile Flushing 鍵字串)第三輪已確認**參考庫 6 份文件全域零命中** —— `has_setting()` 防衛必須保留,不得改成信任推測鍵名。

### D. 其他未處理

- **R3(第二輪審查)**:ADR-0003 補一條 Validation Criteria(payload 建構路徑不得含 `Callable`/`Signal`/`RID` —— 它們不是 `Object` 衍生類,不受 `allow_objects=false` 管控);ADR-0002 的 Post-Cutoff 欄措辭易被誤讀為「不依賴 `Dictionary[K,V]`」。
- **戰棋系統文件自陳的下游阻擋項**:OQ-2 `player_baseline_stat` 全專案無擁有者;OQ-10 無「不可通行」地形層級;OQ-16 敵方單位數上限無擁有者 + 效能測試須以「格數 × 敵數」兩軸參數化。
- **戰棋系統 DEFER 未落地**:`enemy_advantage_pct < 0` 無驗證拒絕(與既有 `≥1.0` 拒絕不對稱,會靜默反轉 Core Rules #7);公式二 `ceil()` 浮點精度邊界噪聲。
- **戰棋系統收斂狀態**:連續零 BLOCKING-NOW 輪數 = **0**(四輪皆 body-scoped)。距 Approved 尚需**連續兩輪**零 BLOCKING-NOW。
- **`docs/consistency-failures.md` 不存在** —— 依 skill 規定未建立(該 skill 只在檔案已存在時附加,不建立)。**至第七輪已第五次提出建立。** 後果:七輪的 C1~C7 與各輪模式警示只存在於各輪審查報告內,**沒有跨輪的模式累積**。七輪累積的同型別重複:自陳膨脹 ×1、修法引入新缺陷 ×4、散文改了但結構化欄位/示意圖/歷史表沒跟著改 ×5、「只修了觸發我注意的那一處」×8。
- **R4(第三輪新增)**:ADR-0005 補 Verification Required —— `_notification()` 時序(N2)、`InputMap` 動作語意分類依賴(N1,連 ADR 自己的 8 項核心依賴表都漏列)、座標空間 API 與「全程單一根 Viewport」的明文假設(F2)。

### E. 已凍結(不是待辦,是明文暫停)

**滑鼠奪權子機制**(`cursor-highlight-state.md` Core Rules #3)—— 使用者第十二輪(2026-08-11)裁決:硬性閘門降級為建議事項、重新設計**暫停**、候選修法停止投入,待取得手把硬體。兩項已確認缺陷維持未修復:

- **E1**(spike log 實測,100% 可重現):類比搖桿持續按住造成滑鼠奪權**永久鎖死**
- **E2**(真人口語觀察,僅測鍵盤路徑):奪權成功後被反方向零門檻豁免規則**秒搶回**

ADR-0005 機制八把它隔離在單一檔案(`MouseReclaimPolicy`),**明文不宣稱已緩解**。待辦:取得一支手把後補測 D-pad 與類比搖桿。**不得假設「未測 = 沒問題」。**

---

## Session Extract — `/architecture-review` 第三輪 2026-08-19

- **判定:CONCERNS**(第二輪為 FAIL)—— 第二輪的唯一硬阻塞(游標 19/19 零涵蓋、Foundation 層)**已解除**
- **需求:130 項 —— 61 ✅ / 34 ⚠️ / 35 ❌**(第二輪 50/24/56)
- **新增 TR-ID:無** —— 5 份 GDD 自第二輪以來零修改,130 項基線未動(已以 git 查證)
- **GDD 修訂旗標:`cursor-highlight-state.md`**(2 項,皆為**設計文件內部張力**,非引擎衝突;`systems-index.md` 未改動,狀態變更留待使用者裁決)
- **報告**:`docs/architecture/architecture-review-2026-08-19.md`

### 本輪最重要的一件事:ADR-0005 的自陳被推翻

ADR-0005 自陳 19 項中 **16 完整 / 3 部分**。獨立重推為 **11 完整 / 8 部分 / 0 缺口** ——
`TR-cursor-001`/`-008`/`-015`/`-017`/`-019` 五項由 ✅ 降為 ⚠️。**零缺口成立,但自評膨脹了 5 項**
(與第二輪在 ADR-0004 身上抓到的是同一個模式)。

### ADR-0005 的 9 項待修訂(修好前不得進 `Accepted`)

| # | 缺陷 | 級別 |
|---|---|---|
| **F1** | 機制六的「四個行為者」是節點渲染更新序,**不是** GDD Core Rules #2 的「四方完整定序」。呼叫方主動改標被排到緩衝內確認讀取**之後**,**違反 AC-52**(該 AC 也不在 ADR 的 Validation Criteria 清單裡)。修法需**新增對下游系統的約束**——確認動作判讀不得掛 `_unhandled_input()`(`process_priority` 完全管不到它) | **BLOCKING** |
| **F5** | `_process()` 沒有比照 `_input()` 檢查 `_arbitration_suspended`,失焦/暫停當幀已緩衝事件仍被裁定;suspend/resume/FOCUS_IN/FOCUS_OUT 四個進出點**沒有任何一個** `clear()` 緩衝區。**`suspend_arbitration()` 路徑的競窗不依賴任何未驗證引擎行為,100% 確定存在** | **BLOCKING** |
| **F2** | `MouseReclaimPolicy` 對累積起點的擁有權自相矛盾(`reset(seed)` vs `evaluate(net_delta)`);參數命名 `_net_delta` **邀請 GDD 明文禁止的路徑總和實作**(累加 `event.relative`)。建議改收絕對座標由策略內部相減 | 高 |
| **F3** | `modulate.a` 直綁 `reclaim_progress()`,無呈現層平滑器,契約也無管道辨識是哪個重置觸發點 → 對觸發點 (a)(b)(c) **必然違反 AC-41**。**修法會擴充機制八的契約寬度,動搖 ADR 自陳的 Validation Criteria #8「隔離邊界只有三個方法寬」——是連動修訂** | 高 |
| **F4** | 收斂上限的量測儀器量錯對象(量判定值而非呈現透明度)。隨 F3 解決 | 中 |
| **N1** | `ActionClass`(NAVIGATION/CONFIRM/OTHER)如何從原始 `InputEvent` 判定,**完全沒給機制**。必然需要查 `InputMap`,而該依賴**連 ADR 自己的 8 項核心依賴涵蓋率表都漏列** | 中 |
| **N2** | `_notification()` FOCUS_IN/OUT 相對 `process_priority` 的時序未定義,且不在現有 9 項 Verification Required 內 | 中 |
| **N3** | `Input.mouse_mode` 是**全域**設定,與 GDD AC-60「未登記表面得用原生 hover」的 carve-out 未調和 —— 手把持權威時玩家用滑鼠點未登記側欄看不到指標 | 中 |
| **N4** | 下游更新是輪詢還是訊號推送未定案;若採訊號,**回頭寫入 `_state` 會重入而 ADR 無閘門**(ADR-0001 對同類問題設了 `settlement_in_progress`) | 中 |

> F1~F5 由主審獨立推導,`godot-specialist` 逐項對抗性覆核**五項全部成立**,其中 F1/F5 判定比初審更嚴重;
> N1~N4 為該專家在五項之外自行額外發現。**修訂屬 `/architecture-decision` 領域,不得與審查同 session。**

### 判定標準的一致性(下一輪必讀)

戰棋系統仍有 **25 項 ❌ 且屬 Core 層**,字面上符合 FAIL 條件。但第二輪在同樣有 27 項戰棋缺口下仍稱
「游標是唯一硬阻塞」,隱含理由是**該 GDD 尚未 Approved**。本輪沿用同一標準。
**⚠️ 若戰棋 GDD 在其演算法層 ADR 之前先達 Approved,判定會退回 FAIL。**

### 本輪新增/確認的銜接缺口

- **C6(新,低嚴重度)**:ADR-0005 宣稱機制十一與 ADR-0004 存檔讀取路徑「直接交接」,但 **ADR-0002/0003/0004 對「游標」零命中**。不是矛盾(GDD 把義務歸給呼叫方而非存檔系統),但 ADR-0004 不宜在單方面被宣稱交接的狀態下逕行 `Accepted`
- **C1 / C3 仍開**,與第二輪相同
- **C2 / C4 / C5** 已於 `a56dd10` 修正,本輪覆核成立;該提交對 ADR-0003/0004 的 19 行改動**未移動任何一格涵蓋率**

### 本輪覈實過、可直接引用的事實

- `tr-registry.yaml` 133 個 `id:` 中 3 個在註解區(`TR-combat-*` 是格式範例)→ **實為 130 項 active**
- `docs/registry/architecture.yaml`:ADR-0005 共 **14 個條目**;`forbidden_patterns` 共 **17 項**;`logic_in_cursor_autoload_shell` **確實已登記**(非僅「候選」);55 = 52 具 ADR 來源 + 3 項 `adr: none`。**全部自陳成立**
- **棄用 API 對 ADR-0005 逐列比對零命中**
- ~~**`@abstract` 語法可從「印象」升級為「已查證」** —— 與 `current-best-practices.md` 第 41–49 行範例逐字格式一致。~~ **🔴 2026-08-20 第七輪推翻:那次升級無效,因為該範例本身是錯的**(`pass` 主體在 4.7.1 是 parse error)。此處保留原文作為歷史紀錄,**但不得再被引用為事實** —— 現況見上方「待處理清單 C 第 4 項」與檔尾第七輪 Session Extract。原文殘留部分(範例只有一種回傳型別)已由 2026-08-20 spike 實測關閉:五種回傳型別皆合法。
- **Agile Event Flushing 鍵字串:6 份參考文件全域零命中** —— `has_setting()` 防衛應保留,不得改成信任推測鍵名
- `_input()` 全數完成後才進 `_process()`:專家判定**印象等級(信心偏高),不算已查證** —— ADR 的「高風險待驗證」標記不應被拿掉

---

## Session Extract — `/architecture-review` 第四輪 2026-08-19

- **判定:CONCERNS**(與第三輪同)—— 沿用同一標準(32 項 ❌ 中 25 項在尚未 Approved 的戰棋 GDD)
- **需求:130 項 —— 65 ✅ / 33 ⚠️ / 32 ❌**(第三輪 61/34/35)
- **新增 TR-ID:無** —— 5 份 GDD 自第三輪以來 git 改動數皆為 0,`tr-registry.yaml` 本輪零改動
- **GDD 修訂旗標**:第三輪兩項全部維持開啟,`systems-index.md` 未改動(使用者本輪未選擇標記 `Needs Revision`)
- **報告**:`docs/architecture/architecture-review-2026-08-19-round4.md`

### 更正本檔案先前的一項自陳

上方「**本次修訂尚未提交 git**」**不成立** —— ADR-0005 修訂、registry、technical-preferences、active.md
四者全在 `7bb033b`;工作區乾淨,與 `origin/main` 同步(0/0)。

### 游標系統重推:13 ✅ / 6 ⚠️ / 0 ❌(第三輪 11/8/0)

9 項待修訂中 **6 項完整關閉**(F5、F2、F4、N1、N2、N4),**F1 只關一半**,**F3 修法引入新違反**。
`-010`/`-019` 升 ✅;`-001`/`-008`/`-009`/`-011`/`-015`/`-017` 仍 ⚠️。

### ADR-0005 進 `Accepted` 前必須關閉(7 項 + `-015` 兩項落差)

| # | 缺陷 | 級別 |
|---|---|---|
| **R4-2** | `diagnostic_seed_position()` 寫在抽象基底卻 `return _seed`,`_seed` 只宣告於子類別 → 編譯期錯誤。專家建議改標 `@abstract` | **BLOCKING** |
| **R4-1** | F1 只關一半:步驟三仍融在 −100,實際定序 1&3 → 2 → 4,與 GDD 明文四步序列相反(GDD 稱該方向為硬性行為要求);②→③ 這組無任何測試涵蓋 | 高(視同 BLOCKING) |
| **R4-3** | F3 平滑器 `move_toward()` 對上升方向也限速 → 結構上無法滿足「達到門檻的當下透明度達 100%」。應只對下降限速 | 高(視同 BLOCKING) |
| **R4-4** | N4 重入閘門可能鎖死 `arbitrate_frame()` 內部的導覽寫入(若重用公開 `set_target()`)。須明文區分私有寫入路徑 | 高 |
| **R4-5** | `ActionClass` 硬編碼白名單無完整性驗證,新增導覽類 action 靜默降級為 `OTHER` | 中高 |
| **R4-6** | 機制六的 `call_deferred()` 路線與旗標路線不等價,沖洗時點未查證,可重開 F1 剛關的洞 | 中 |
| **R4-7** | ②/⑤ 角色重疊未討論(專家推翻「無解」判斷:單一 `_process()` 內陳述順序即可解,屬文件缺口) | 中 |
| **`-015`** | 甲/乙分支累積位移量未重置為 0;丙分支收窄 GDD 允許的「原目標仍有效得直接沿用」。**第三輪未編號,修訂 session 依 9 項清單作業而漏掉** | 中 |

> R4-1~R4-3、R4-5 由主審獨立推導,`godot-specialist` 對抗性覆核**全部成立**(R4-2 被升為 BLOCKING);
> R4-4 為該專家額外發現;R4-7 為專家**部分推翻主審初判**後採納的更正版本。

### 本輪覈實過、可直接引用的事實

- **registry 61 項立場實測成立**(10 state / 10 interfaces / 22 api / 19 forbidden);ADR-0005 佔 **20 項**;
  58 具 ADR 來源 + 3 項 `adr: none` = 61(另有 7 行位於註解區的範例不計)
- 本次修訂**就地修訂 3 項既有條目**(`cursor_target_write`、`cursor_actor_process_priority_ladder`、
  `cursor_visual_carrier_split`),commit message 與 technical-preferences 皆只提「2 項 api_decisions」,
  漏記 `cursor_target_write` 這項 interface
- **棄用 API 對修訂新增內容零命中**(主審與專家各自逐列比對)
- **引擎參考庫自相矛盾(新發現)**:`breaking-changes.md` 標 4.4→4.5 為 `POST-CUTOFF, HIGH RISK`,
  `VERSION.md` 卻標 4.5 為 `LOW (pre-cutoff)` —— 而 `@abstract` 賭注正押在 4.5
- **專家更正 VR #11**:機制八的淨位移**全程停留在 viewport 座標系,不受 `CanvasLayer` 變換影響**;
  真風險只有機制十三把 viewport 座標畫到 CanvasLayer 子節點上那一半。**應拆成兩條 Verification Required**
- **`InputMap.event_is_action()` 印象中不過濾 `InputEventKey.echo`** —— 按住方向鍵的重複事件會與初次
  按下同樣判為 NAVIGATION,ADR 完全未討論。專家判定為本次最值得回頭確認的一項
- `move_toward()` 為專家唯一給高信心背書的新增依賴(已查證,優於每幀重啟 `Tween`)

### 本輪順手修正的文件

- `.claude/docs/technical-preferences.md`:forbidden patterns 計數 17→19、其餘 14→16、
  ADR-0005 新增 4→共 6 並補上兩項新禁令名稱(使用者核准)
- `docs/architecture/traceability-index.md`:19 列游標 + **修正第三輪的傳播遺漏**
  (`TR-concept-005`/`-006`/`-007` 三列在 ADR-0005 已存在下仍留著第二輪的「架構層 ADR 未見」判定)

### 仍未處理(使用者本輪未選擇)

- ~~registry `state: mouse_reclaim_accumulator` 的 `interface:` 仍寫直綁 `modulate.a`~~ —— **✅ 已修**(`revised: 2026-08-19b`,並同步 R4-3 的方向拆分)
- ~~ADR-0005 Consequences 仍留「19 項全部有機制支撐(其中 3 項為部分)」的舊自陳~~ —— **✅ 已刪除**
- `systems-index.md` 第 28 列游標 GDD 狀態維持 `Approved` —— **仍未處理**(需使用者裁決,見下方)

---

## Session Extract — `/architecture-decision` 第二次修訂 2026-08-19

### 本次的一項方法論調整

第四輪抓到的模式是**修法本身引入新缺陷**(R4-2/R4-3/R4-4 三項皆為第一次修訂新產生,不存在於初版)。本次修訂因此對每一項修法額外自問「這個修法會不會製造下一個 R4-x」,答案寫進各機制的修訂標記段落——例如機制十三的三點自問(`_pending_snap` 分支順序、`>=` vs `>`、量測對象隨之改變)、機制五對「拆節點製造的新中間狀態」的明文接受與理由、機制十的「公開入口不得互相呼叫」紀律。**這不保證有效,但至少讓下一輪審查有東西可以直接反駁。**

### 兩處我主動偏離既有判定的地方(下一輪審查應優先檢視)

1. **R4-7 —— 部分推翻第四輪採納的修法方向。** 該輪 `godot-specialist` 推翻主審初判(「優先序梯無解」)、提出「同節點內陳述順序即可」,主審採納。**該推翻的前提正確**(`process_priority` 管不到函式內部),**但結論在②+⑥ 這組角色上不成立** —— 兩者之間隔著③(−25)與④(0),單節點方案不論設 −50 或 100,都會各自違反四步序列的一段。本次改為「相鄰角色可合併、不相鄰必須拆節點」。
2. **`SURFACE_HANDOFF` 新增為第五個 `ResetTrigger` 值。** 沒有複用 `TARGET_CHANGED`,理由是兩者來源規則不同(Core Rules #7 vs #3),且甲分支**目標並未改變**,複用會對訂閱訊號的呈現層說謊。代價是列舉值多一個,可能被誤讀為「Core Rules #3 有五個觸發點」——已在列舉註解與 registry 兩處明文否認。

### 未執行的一道關卡

**`godot-specialist` 技術驗證(skill Step 5.5)未跑** —— 本 session 環境設定明文禁止在使用者未要求的情況下呼叫 Agent 工具。第三、四兩輪的紀錄顯示該驗證每次都抓到主審漏掉的項目(第三輪 N1~N4、第四輪 R4-4),**這是本次修訂與前兩次相比少掉的一道關卡**。第五輪審查應對本次修法的引擎假設特別加壓,尤其:`add_child()` 建立的子節點其 `process_priority` 是否確實獨立於父節點參與同一條 `_process` 鏈排序(本次修訂的**全部**定序論證都押在這件事上,而參考庫對 `process_priority` 本來就零命中)。

---

## Session Extract — /architecture-review 第五輪 2026-08-19

- **Verdict**: CONCERNS(第三、四輪亦為 CONCERNS)
- **Requirements**: 130 總數 — 68 covered / 30 partial / 32 gaps(第四輪 65/33/32)
- **游標系統**: 15 完整 / 4 部分 / 0 缺口(第四輪 13/6/0)。⚠️ = -009、-011(凍結子機制)、-015(R5-1)、-017(R5-6)
- **第四輪 9 項處置**: **8 項完整關閉**(R4-1~R4-7 全數 + `-015`(b)),只有 `-015`(a) 只關甲分支
- **New TR-IDs registered**: None(5 份 GDD 自第二輪起零改動,130 項基線未動)
- **GDD revision flags**: None(引擎現實層面);第三輪的兩處設計文件內部張力維持開啟,其中 Core Rules #5 vs AC-60 那項因 R5-6 而多了一個技術層理由
- **本輪 6 項新發現**: R5-1(**BLOCKING** — 乙分支 `SURFACE_HANDOFF` 無合法呼叫路徑,與自己的 Validation Criteria #16 矛盾,需新增介面面)、R5-6(中高 — `MOUSE_FILTER_IGNORE` 使機制十三之二誤判)、R5-3(中高 — `MouseReclaimPolicy` 三方持有無管道)、R5-2(中)、R5-4/R5-5(低)。另 `godot-specialist` 自行發現 S-1~S-5
- **跨 ADR**: **C1/C3/C6 全部關閉 — 五輪來第一次零懸置銜接缺口**。ADR-0004 第四處「TR-save-* 全數覆蓋」過度宣稱亦已清除(至此四處全清)
- **Registry**: 65 項逐節實測(10/10/23/22),依 `adr:` 欄 13/12/6/8/23/3(none),ADR-0005 佔 23(3/4/7/9)—— **與檔頭及 technical-preferences 完全對帳,零落差**(四輪來第一次)
- **引擎**: 棄用 API 零命中(主審與 `godot-specialist` 各自獨立比對);5 份 ADR 版本一致 4.7.1;參考庫自相矛盾(breaking-changes 標 4.5 HIGH vs VERSION 標 LOW)仍開;`modules/` 8 份仍停 4.6
- **引擎專家覆核**: **已執行**(使用者明文核准)—— R5-1~R5-5 全部 CONFIRMED,R5-1 由該專家升為 BLOCKING、R5-3 升為中高,R5-6 為其自行發現
- **Top ADR gaps**: 戰棋盤面演算法層(25 項 ❌)、回合結構擁有權 + AI/遭遇系統、`TR-save-030` 雲端同步
- **Pre-gate**: 五項全缺,`/gate-check pre-production` 不可執行(**已於同日 `/test-setup` 補足其中三項,見上方第二節**)
- **Report**: docs/architecture/architecture-review-2026-08-19-round5.md

---

## Session Extract — /architecture-decision 第三次修訂 ADR-0005 2026-08-19(**約定為最後一次全面修訂**)

**輸入**:第五輪 `/architecture-review` 的 R5-1~R5-6 + `godot-specialist` 自行發現 S-1~S-5,共 11 項。
**流程差異**:本次**在寫入前先跑 `godot-specialist` Step 5.5 覆核**(使用者明文授權呼叫 Agent)。第二次修訂缺的就是這道關卡,結果第五輪抓出一項 BLOCKING。**這次覆核再抓出 6 項,其中 4 項是本次修法自己新產生的** —— 這道關卡有效。

### 17 項處置

| 項 | 修法 |
|---|---|
| **R5-1**(BLOCKING) | 乙分支 `SURFACE_HANDOFF` 無合法呼叫路徑。根因是**私有路徑地圖只畫了一格**。私有路徑 1 → **4**(`_write_target_internal(target, reset_policy)`、`_mark_pending_reresolve_internal()`、`_validate_target_writable()`、`_safe_mouse_position()`);新增乙分支專用公開入口 `handoff_after_mount(target)`,與甲的 `handoff_before_unload()` 成對 |
| **同源缺陷**(第五輪未點名) | 甲分支 `handoff_before_unload()` 依機制十一要呼叫**公開的** `mark_pending_reresolve()` → 被自己的重入閘門鎖死。與 R4-4 同形狀,**第四輪只修了三處中的一處** |
| **發現 A**(Step 5.5) | 兩條 reset 路徑未明文互斥 → 乙分支會在同一次寫入內連發 `SURFACE_HANDOFF` + `TARGET_CHANGED`。明文要求 `if`/`elif`,並登記為 forbidden pattern |
| **發現 B**(Step 5.5) | 我在私有層種回公開層剛否決的 boolean trap(GDScript 無呼叫端具名引數)→ 改用 `TargetResetPolicy` enum |
| **發現 2b**(Step 5.5) | `handoff_after_mount()` 的前置驗證無處可放 → 新增 `_validate_target_writable()`。專家判定這是「本次批量修法最可能製造的下一個 R5-x」 |
| **發現 D**(Step 5.5) | `reseed_reclaim_on_focus_regained()` 掛不掛閘門未定案 → 納入第七個掛閘門入口(`void` + 診斷計數)。順帶釐清 `_notification()` **不可能**打斷執行中的公開入口(單執行緒非搶佔、鏈上無 `await`);真風險是下游在 `target_changed()` 處理函式內呼叫 `resume_arbitration()` 造成的跨方法雙重重置 |
| **R5-6 + 發現 F** | **一個修法一次關掉兩個**:機制十三之二的 hover 判定由**黑名單反轉為白名單**。失敗方向從「錯誤顯示原生指標(違反 Core Rules #5 硬性規則)」翻轉為「錯誤隱藏(僅 AC-60 便利性失效)」。連帶:不需把 `mouse_filter` 約束推給下游;非 `Control` 表面的不適用問題一併消失。機制十四改為**按節點型別分流**,不強制統一型別 |
| **R5-3** | `_reclaim` 唯一擁有者為 `CursorState`(私有、無 getter);Host 與呈現層各走一條轉發;滑鼠座標三條路徑收成一條(`get_viewport().get_mouse_position()` 全專案只准出現一次) |
| **R5-2** | ② 由 −50 改為 **−60**,區間改開區間;統一「同 `process_priority` 無 tie-break」立場 → 六個架構強制值必須兩兩相異 |
| **S-1 + 發現 G** | 新增 `_safe_mouse_position()` 每次取值前 `is_valid()`;注入形式由 lambda 改為**具名方法綁定**。**但 `is_valid()` 對已釋放綁定物件的偵測行為未查證** → 新增 VR #15 + Day-1 spike |
| **S-2 / S-3 / S-4 / S-5** | `Input.mouse_mode` 賦值前守衛(第四輪已建議、第二次修訂未採納)/ `_notification()` 派發為**樹序**不是優先序序,明文區辨 / `_reclaim` 無執行期熱替換管道,替換即重建 `CursorState` / Risks 明列本 ADR 引入的 10 個 `class_name` |
| **R5-4 / R5-5** | ADR-0005 Validation Criteria 重新編號為 **1~19**(原跳過 #12);ADR-0004 第 6/7 項順序調正 / Architecture Diagram 同步 `UI_ACTION_UNCLASSIFIED`、−60、新介面、白名單判定 |

### 介面帳(誠實記錄)

`CursorState` 公開入口 **5 → 7**、私有路徑 **1 → 4**、生命週期類寫入入口 **1 → 2**。Requirements 第 10 項「2 個寫入方法」指 GDD Core Rules #2 的雙寫入,**該項未被擴大**;被擴大的是本 ADR 自己為承載 Core Rules #7 而設的類別。

### Registry

**65 → 68 項**(逐節實測 10 state / 11 interface / 23 api / 24 forbidden),ADR-0005 佔 **26** 項(3/5/7/11)。新增 3 項、就地修訂 8 項(皆 `revised: 2026-08-19c`)。

### 待辦

1. **全新 session 跑第六輪 `/architecture-review`** —— 依本次約定,範圍限縮為「這 17 項是否確實關閉」,不再全域重推 130 項需求。
2. Day-1 spike 由六項增為**七項**(新增 VR #15 `Callable.is_valid()`)。
3. 與架構軌零依賴、pre-gate 五項全缺:`/test-setup`(補三項)、`/ux-design`(補兩項)。

---

## Session Extract — /test-setup 2026-08-19

**成果**:pre-gate 五項補足三項(`tests/unit/`、`tests/integration/`、`.github/workflows/tests.yml`)。

### 兩項先前未被發現的文件矛盾(本次實測抓到)

| 矛盾 | 兩側說法 | 裁決 |
|---|---|---|
| **測試框架** | `technical-preferences.md:43` 寫 `GUT`;`coding-standards.md:64` 的 CI 指令寫 `tests/gdunit4_runner.gd` —— **兩者是不相容的框架**,選錯則每個測試檔都要重寫 | **使用者裁決採 GdUnit4**。判 `GUT` 為範本預設值:同區塊其餘欄位皆為未設定佔位符,而 CI 指令具體到檔名。`technical-preferences.md` 已更正 |
| **測試證據落點** | `tests/evidence/`(test-setup、smoke-check 兩處)vs `production/qa/evidence/`(coding-standards + create-epics/create-stories/dev-story/story-done/gate-check 共六處) | 採 **`production/qa/evidence/`**(六比二,且 coding-standards 每 session 載入)。此為對 `/test-setup` 範本的明文偏離,已記於 `tests/README.md` |

### 修正的一項範本缺陷

`/test-setup` 的 Godot runner 範本在跑完測試後**無條件 `quit(0)`** —— 那會讓「測試失敗」的 CI
依然顯示綠燈,比沒有 CI 更危險。已改為傳遞實際結果,且回傳值無法判讀時**一律視為失敗**。

### 建立的檔案

`tests/README.md`、`tests/gdunit4_runner.gd`、`tests/unit/.gdignore_placeholder`、
`tests/integration/.gdignore_placeholder`、`tests/smoke/critical-paths.md`、
`tests/unit/harness/harness_selfcheck_test.gd`、`production/qa/evidence/.gitkeep`、
`.github/workflows/tests.yml`。

### 兩個必須被記住的暫時狀態

1. **CI 守衛**:`project.godot` 不存在時跳過測試並直接成功。**綠燈不代表測試通過**
   (Summary 會明文印出這句)。移除條件:專案建立 + GdUnit4 安裝 + 首次真實綠燈確認。
   這不是「關掉失敗的測試」——現在還沒有測試可跑,而長期紅燈會訓練所有人忽略 CI。
2. **六項未驗證**(無 Godot 執行環境,全數未實測):GdUnit4 CLI 入口路徑、
   `gdUnit4-action@v1` 對 4.7.1 的支援、`run_tests()` 回傳型別、GdUnit4 對 4.7.1 的整體相容性、
   `GdUnitTestSuite` 基底類別名稱、`assert_failure()` 的 API 形狀。
   **六項的失敗方向全部被安排在會被看見的那一側,沒有一項會造成假綠燈。**

### 下一步

`/ux-design` 補剩餘兩項 pre-gate(`design/accessibility-requirements.md`、
`design/ux/interaction-patterns.md`)。注意 `cursor-highlight-state.md` 登記的孤兒義務
——運動無障礙需求先前口頭轉交至一個不存在的檔案(第五輪審查報告第 351 行起)。

---

## ⚠️ 更正紀錄 — 五輪審查的同一個誤報(2026-08-19 發現)

**`design/ux/accessibility-requirements.md` 自 2026-08-06 起就存在**(5609 bytes,含 Motor Accessibility 矩陣與三個 Open Questions),但**第一~五輪 `/architecture-review` 全部報「❌ 不存在」**。

**根因是路徑分裂,不是檔案缺失**:

| 路徑 | 使用者 |
|---|---|
| `design/ux/accessibility-requirements.md`(**檔案實際所在**) | `design/CLAUDE.md`、三份 GDD、`systems-index.md`、兩份 cross-review、review log、ux-designer agent memory |
| `design/accessibility-requirements.md`(**框架側查的**) | 8 個框架檔共 17 處:gate-check ×4、ux-design ×3、team-ui ×3、create-architecture ×2、WORKFLOW-GUIDE ×2、ux-review ×1、architecture-review ×1、workflow-catalog.yaml ×1 |

**已修**:17 處框架引用全部改為 `design/ux/`(2026-08-19)。`architecture-review` 的 pre-gate 檢查另加一行明文警告,寫明前五輪誤報此項。

**另修一項相關的錯誤宣稱**:gate-check、create-architecture(兩處)、architecture-review 共四處寫「run `/ux-design` 來產生 accessibility-requirements.md」——**`/ux-design` 的模式表從來沒有這個輸出**,它只讀不寫。正確做法是依 `.claude/docs/templates/accessibility-requirements.md` 撰寫(WORKFLOW-GUIDE Step 3.5)。四處已更正並明文標註「無任何 skill 產出此檔」。

> **給下一輪審查的提醒**:歷史審查報告(round1~5)內的 pre-gate 表格**未修改**——那是當時的紀錄,改了等於竄改歷史。但其中對本項的判定是錯的,重讀時請以本節為準。

### Tier 已定案:Standard(2026-08-19 使用者裁決)

該檔原本 Tier 寫「待定」,理由是系統樣本不足。定案 **Standard** 的核心理由:專案早已散落承諾的項目(全手把對等、禁 hover-only、不僅靠色彩、全套重新綁定)**實際上就落在 Standard 這一層**,定案不是新增義務,是把已有承諾收斂成可被檢查的層級;降到 Basic 會讓 Tier 宣告低於實際承諾,升到 Comprehensive 則無資源支撐(無專職無障礙工程師、未聘顧問)。

**定案立刻產生兩項對現有設計的約束,已寫入該檔並登記為 Open Questions**:

1. **「不存在無法延長或關閉的限時輸入」** vs 好感度對話卡牌的**固定發牌節奏**(`game-concept.md` 第三輪裁決)——是否構成限時輸入**尚未釐清,不得預設為不衝突**,須在支援對話系統設計時回答。
2. **全平台完整輸入重新綁定**——「輸入設定/重新綁定」系統**尚未列入 `systems-index.md`**,本 Tier 使它由可選變為必要,下次系統盤點必須納入。

另登記(不構成新約束):滑鼠奪權 E1 缺陷(類比搖桿持續按住永久鎖死)高度命中動作無障礙——切換式輔助裝置的持續觸發模式正好會踩中。子機制維持凍結,但**重啟其重新設計時必須把本 Tier 的動作無障礙要求列為輸入條件**。

---

## Session Extract — /ux-design patterns 2026-08-19

**產出**:`design/ux/interaction-patterns.md`,**15 個模式**,478+ 行,零佔位符。**pre-gate 最後一項補齊。**

### 一處對 skill 流程的偏離(已記錄於文件 Overview)

patterns 模式的 Phase 1 設計是「從既有 UX 規格萃取模式」,但**既有規格是零份**。改從**已 Approved 的 GDD 行為規格**萃取——主要是戰棋 GDD UI Requirements §1~§7 加上游標 GDD Core Rules。這反而更穩:模式的權威來源是已收斂的行為契約,不是別人的版面選擇。

### 15 個模式

| 類別 | 模式 |
|---|---|
| 導覽 3 | P-N1 游標即檢視、P-N2 單一高亮不變式、P-N3 取消/返回(零狀態寫入) |
| 輸入 2(全域約束) | P-I1 裝置權威交接、P-I2 全手把對等(**無例外**) |
| 資料呈現 5 | P-D1 三態範圍疊加圖、P-D2 並存疊加圖、P-D3 決定性路徑預覽、P-D4 回合層級總覽查詢、P-D5 結算飄字 |
| 回饋與模態 5 | P-F1 未解析態、P-F2 可區分的拒絕回饋、P-F3 非色彩單一通道禁令(**無例外**)、P-M1 確認面板、P-M2 預判模式 |

### 抽出的三條通則(寫進 Overview,供本庫未涵蓋的新情境套用)

1. **顯示與結算必須一致,且「零/空」不得被隱藏** —— P-D1/P-D3/P-D5/P-M1 四者的共同根,全部指向「玩家事後才發現系統跟他看到的不一樣」。
2. **用生命週期做區隔,比用外觀做區隔更穩固** —— P-M2 的核心洞見。玩家快速操作時不看外觀差異,但「這東西只在我停在候選格時存在」是身體記得住的。
3. **結構保證優於紀律要求** —— P-I2 寫成原則而非清單(該清單兩輪內漏兩項)、P-F2 拆成兩個獨立查詢而非合併布林、P-N2 靠單一狀態源而非各表面自律。**優先問「怎麼讓錯誤的實作寫不出來」,而不是「怎麼提醒實作者不要寫錯」。**

### 交叉核對抓到的兩處自身涵蓋缺口(已登記為 Gaps)

1. **字幕(含說話者標示)與字級可調** —— 無障礙 Tier Standard 的基準要求,本庫 **15 個模式一項都沒碰到**。它們是呈現能力而非互動模式,落在尚未設計的系統裡,但 **Tier 已經承諾了,不能因為沒人做就當作不存在**。
2. **空狀態(Empty State)** —— P-F1 要求「未解析態」與「空狀態」必須可區分,但**本庫從未定義空狀態長什麼樣**。只定義兩者之一,「必須可區分」就無從驗證。

### 七項 Open Questions(文件內)

art bible 未執行(影響全部 15 個模式的外觀,其中 P-D2 並存疊加圖最關鍵)、無 player journey、**好感度對話卡牌固定發牌節奏是否構成 Tier 禁止的限時輸入**、戰棋 OQ-21/OQ-6/OQ-11、滑鼠奪權 E1/E2 凍結缺陷。

### 下一步

1. **`/ux-review design/ux/interaction-patterns.md`** —— 本檔尚未驗證。**Pre-Production 閘門要求關鍵規格有審查判定。**
2. `/ux-design [畫面]` —— 目前**零份**畫面 UX 規格。
3. **維護規則已寫進文件末尾**:每次產出新畫面規格後回頭檢查是否用了本庫沒有的互動;若有,**先登記為新模式再實作**。

---

## Session Extract — 流程缺失三項的 P0/P1 修補(2026-08-19)

使用者指定把前一段收尾點出的三項重大缺失排進優先計畫。**實查後,三項裡有兩項並未真的關閉**——
上一輪的修法本身就犯了它自己指出的錯。

### 實查推翻的兩項

1. **路徑誤報有三條錯路徑,先前只修了一條。**
   `design/accessibility-requirements.md`(缺 `ux/`,框架 8 檔 17 處)已修;
   但 **`docs/accessibility-requirements.md`(頂層目錄就錯)在 3 份 template 裡從未被碰過**;
   更嚴重的是 `.claude/agent-memory/ux-designer/feedback_verify_punted_obligations.md`
   有 **3 處明文斷言該檔不存在**(round 8/9/10 三次追蹤加碼)。memory 最後修改 2026-08-05,
   檔案 2026-08-07 進 git——**寫的當下為真,現在為假**,而 agent-memory 會自動載入 ux-designer
   的脈絡,等於每次跑該 agent 都在餵它假事實,偏偏 ux-designer 正是該檔的負責 agent。

2. **先前在 `architecture-review/SKILL.md` 加的 `⚠️ CHECK THE PATH` 警語是紀律要求,不是結構保證**
   ——恰好違反同日寫進 `design/ux/interaction-patterns.md` 的通則三。已刪除警語,改為結構解。

3. **第三項(寫入前覆核有效)的根因比原本的說法精確**:`/architecture-decision` 只有 retrofit 與
   new-authoring 兩個模式,**Step 5.5 只掛在 new-authoring 路徑上**(第 338 行),retrofit 在第 62 行
   就分岔走了永遠碰不到。而 **ADR-0005 的三次修訂兩者都不是**——修訂根本不是這個 skill 的模式,
   是臨場開的。所以那道關卡在結構上就沒掛在最需要它的操作上。Step 5.5 唯一的跳過條件是「引擎未設定」,
   **對「Agent 工具不可用」零指示**——第二次修訂正是撞到這個然後靜默跳過。

### 已完成(P0 + P1,7 檔案)

| 項 | 檔案 | 修法 |
|---|---|---|
| P0-1 | `agent-memory/ux-designer/feedback_verify_punted_obligations.md` | frontmatter 後插入 STATUS CORRECTION 塊。**歷史敘述保留**(刪掉等於竄改紀錄),但擋在前面聲明現況,並把新教訓寫進規則本身:「glob by **filename**, never by the path the prose happens to quote」 |
| P0-2 | 3 份 template(hud-design / interaction-pattern-library / ux-spec) | `docs/` → `design/ux/`,各 1 處 |
| P0-3 | `gate-check/SKILL.md`(`## 2` 下,governs 全部六道閘門)+ `architecture-review/SKILL.md` Phase 9 | **存在性檢查改為 glob by FILENAME**。找到但路徑不同 ⇒ 標 ✅ 並附實際路徑 + 另報路徑不符;**絕不標 ❌**。❌ 只在該檔名全庫不存在時才成立 |
| P1-1 | `architecture-decision/SKILL.md` | 新增 **revision 模式**(標題改 `Retrofit / Revision`,分岔句同步)。六步:讀報告原文而非記憶摘要 → findings ledger 先對範圍 → 草稿 → **強制 Step 5.5 於寫入前** → 寫入核准 → **不得自陳修訂後涵蓋分佈**。retrofit 亦補第 8 步:若補了 Engine Compatibility 章節,寫入前須跑 5.5 |
| P1-2 | 同上 Step 5.5 | 補「Task/Agent 工具不可用」處置:**不得靜默跳過**,須停下來讓使用者三選一(授權/明文標記未覆核/延後寫入),並把選擇記進 ADR |

**刻意保留的 3 處舊路徑字串**:全在新規則內文裡當反例引述(memory ×1、arch-review ×1、gate-check ×1)。

**刻意不動**:`CCGS Skill Testing Framework/` 的 6 處(獨立 v1.0.0 釋出框架,自有 CLAUDE.md,
最後提交 2026-05-13;那些路徑是測試 skill 行為的固定樣本,改了可能弄壞測試斷言)。
歷史審查報告與 session-logs 亦不動——改寫會竄改紀錄。

### 未做:P2(使用者裁決另開)

`grep` 出 **49 處**「跑 `/X` 來產生/建立 Y」型宣稱,先前只驗過 4 處。
其餘 **45 處從未對帳過各 skill 實際宣告的輸出**。需逐一比對每個 SKILL.md 的輸出表,面積大,獨立成一次作業。

### 對第六輪的影響

P0-3 必須先落地才跑第六輪,否則會第六次踩同一顆雷。**現已落地。**

---

## Session Extract — /architecture-review 第六輪(範圍限縮)2026-08-19

- **Verdict**: **CONCERNS**(第三~六輪皆為 CONCERNS)。**本輪零 BLOCKING** —— 第五輪唯一的 BLOCKING(R5-1)經 `godot-specialist` 逐一展開七個公開入口 × 四條私有路徑的呼叫圖後判定**核心修法成立**,這是本輪最重要的正面結論
- **範圍**:依 2026-08-19 與使用者的約定,**未重推 130 項需求**。因此 `traceability-index.md` 與 `tr-registry.yaml` **本輪零改動**;引用涵蓋分佈仍須沿用第五輪的 130 項 68 ✅ / 30 ⚠️ / 32 ❌ 與游標 15/4/0。**第三次修訂後的分佈至今仍未被獨立推導**
- **17 項處置**:**16 項完整關閉,1 項只關一半**(R5-2)。R5-1 / 同源缺陷 / 發現 A、B、2b、D / R5-6+F / R5-3 / S-1~S-5 / R5-4 / R5-5 全數關閉,逐項覈實依據見報告第一節
- **New TR-IDs registered**: None(GDD 自第二輪起零改動)
- **GDD revision flags**: None(本輪未重驗;第三輪登記的兩處設計文件內部張力維持開啟)
- **本輪 13 項發現**:R6-1(−50 殘留 13 處,R5-2 只關一半)、R6-5(**高** —— registry YAML 重複鍵)、R6-2、R6-3、R6-4 —— **此 5 項已於本 session 修補**;R6-6(中高 —— `handoff_before_unload(surface)` 參數懸空)、R6-7(中高 —— 乙分支同值寫入時 `is_valid` 翻轉無訊號涵蓋,根因是 `equals()` 語意未定案)、R6-8(中 —— 機制六⑤「同一節點」與機制十二/十三「兩個元素」矛盾)、R6-9(中 —— 「兩兩相異」只管角色不管實例)、R6-10(中 —— `reseed_reclaim_on_focus_regained()` 掛閘門的反方向失敗未討論)、R6-11(中 —— `_safe_mouse_position()` fallback 製造靜默凍結)、R6-12(低中 —— 第五輪的 `add_child()` 前設優先序建議掉件)、R6-13(低 —— 第二張登記表共用 enum + 無自動反登記)—— **此 8 項需改動 ADR 決策內容,留給第四次修訂**
- **引擎專家覆核**: **已執行**(使用者明文核准)。任務一 4 項**全部 CONFIRMED,無一 REFUTED**;主審的 R6-1 與 R6-2 定義域被判過窄,各補一層(R6-1 漏 ADR 第 427 行且**完全未查 registry 那一側**的 6 處;R6-2 底下藏著結構性的 R6-5)。R6-5~R6-13 為該專家自行發現
- **Registry**: **修後零落差** —— 逐節實測 10/11/23/24 = 68,依 `adr:` 欄 13/12/6/8/**26**/3(none),ADR-0005 佔 26(3/5/7/11),與檔頭及 `technical-preferences.md` 三處計數完全一致
- **引擎**: 棄用 API 零命中。專家加強論證:第三次修訂相對第二次修訂**沒有引入任何新的引擎 API 面**(新增全是 GDScript 語言層構造),故第五輪的零命中結論可結構性繼承
- **Pre-gate**: **五項全備**(依 P0-3 以檔名 glob,前五輪的誤報未再發生)。但 `/gate-check pre-production` 仍不保證通過:ADR `Accepted` 0/5、畫面 UX 規格 0 份、`interaction-patterns.md` 未經 `/ux-review`
- **Report**: `docs/architecture/architecture-review-2026-08-19-round6.md`

### 模式警示(第四次一致,且本輪有新的診斷)

第三輪抓自陳膨脹;第四、五、六輪抓到的**都是修法本身引入新缺陷**。第三次修訂在寫入前跑了 Step 5.5 覆核(該關卡當場抓出 6 項、其中 4 項是該次修法自己新產生的)——**這道關卡有效,但不充分**:本輪 9 項新發現裡 **7 項出自第三次修訂自身**。覆核抓到的是「R5-1 的骨架不完整」,沒抓到「補完骨架後**甲分支的簽章沒跟著重新設計**」(R6-6)與「同一次修訂新增的**正交性宣告**讓 `is_valid` 翻轉失去訊號涵蓋」(R6-7)。

**`godot-specialist` 的建議(本輪採納,寫進第四次修訂的作業要求)**:下一次修法的自問應改為 **「這個修法會不會讓某個既有簽章、既有正交性宣告變得不成立」**,而不只是「這個修法會不會製造下一個 R-x」。前者管修法對周邊的**回頭影響**,後者只管修法本身 —— 而連續三輪的缺陷全都出在回頭影響那一側。

### 本輪修補的 5 項(純文件/登記處,零機制改動)

| 項 | 檔案 | 改動 |
|---|---|---|
| R6-1 | ADR-0005 ×7、`architecture.yaml` ×6 | `−50` → `−60`。**registry 的殘留比 ADR 的更該修** —— `description:` 欄是程式碼審查者實際拿去比對的規則文字。4 處歷史敘述刻意保留(2 處在 ADR、2 處在 registry 的 `kept only as a record` 段落) |
| R6-5 | `architecture.yaml` | 刪除 `cursor_unregistered_surface_hover_visibility` 的重複 `revised:` 鍵。寬鬆解析器會採後者(空字串)靜默抹掉 c 戳記,嚴格解析器直接拋錯 |
| R6-2 | `architecture.yaml` ×2 | `mouse_reclaim_accumulator`、`cursor_visual_carrier_split` 的 `revised:` 由 `2026-08-19b` 改為 `c`。兩者**內文都已更新**,只有結構化欄位沒跟上 |
| R6-3 | ADR-0005 | 涵蓋歷史表補第五輪(15/4/0)與第三次修訂兩列;表題由「第四輪修訂後」改為「第三次修訂後」 |
| R6-4 | `.claude/docs/technical-preferences.md` | `Mutex` 摘要句改為縱深防禦措辭。**專家判定此項影響面被主審低估** —— 該檔由 `CLAUDE.md` 以 `@` 引入,已撤回的宣稱會注入每一個 session 的系統脈絡 |

### 未修、留待裁決的一項措辭

`.claude/docs/technical-preferences.md` 的 ADR-0002 條目寫 "Covers all 24 `TR-affinity-*` requirements",而第五輪獨立推導為 22 ✅ / 2 ⚠️ / **0 缺口**。零缺口成立,故此句勉強可辯護,與 ADR-0004 被連續清除四次的「全數覆蓋」過度宣稱(該處實為 22/7/**1**,有真缺口)嚴重度不同。**建議下次修訂時一併改為「24 項零缺口(其中 2 項部分涵蓋,成因在他系統)」。**

### 下一步

1. **`/architecture-decision` 第四次修訂 ADR-0005** —— R6-6~R6-13 共 8 項。使用者已裁決另開 session。**寫入前必須跑 Step 5.5,且自問改為上述新版本。** 關於「第三次修訂為最後一次全面修訂」的約定:本輪判定不被違反(約定的是最後一次**全面**修訂,這 8 項是點狀、有明確清單的修訂)
2. **`/ux-review design/ux/interaction-patterns.md`** —— 與架構軌零依賴,可平行推進
3. 戰棋盤面演算法層 ADR(一次移動 25 項 ❌ 中的大部分)
4. 回合結構擁有權 + AI/遭遇系統 ADR
5. **(自第三輪起第四次提出)建立 `docs/consistency-failures.md`** —— 六輪下來的同型別重複已足夠:自陳膨脹 ×1、修法引入新缺陷 ×3、散文改了但結構化欄位/示意圖/歷史表沒跟著改 ×4

### 給第七輪的交代

**本輪的範圍限縮是一次性的,不建立慣例。** 第三次修訂後的 19 項 `TR-cursor-*` 涵蓋分佈至今未被獨立推導;若第四次修訂後仍不重推,ADR-0005 會在「連續兩次修訂未經涵蓋驗證」的狀態下逼近 `Accepted`。**第七輪範圍建議**:R6-6~R6-13 是否關閉 **+ 游標 19 項涵蓋分佈重推(不可再延後)**。130 項全域重推可維持沿用,前提是 GDD 仍零改動。

---

## Session Extract — 引擎行為驗證 spike + specialist 交叉覆核 2026-08-20

**起因**:六輪審查後五份 ADR 全停 `Proposed`,而 `docs/CLAUDE.md` 自動阻擋引用 `Proposed` ADR 的 story
——這是比任何涵蓋缺口都更接近實作路徑的結構性阻擋,已連續四輪未動。使用者裁決把「推一份 ADR 上
`Accepted`」提前。ADR-0002 最接近(`Depends On: None`、24 項 TR 零缺口、C1/C3 已關),**唯一硬阻擋是
5 項 VR,其中 2 項 ADR 自陳不影響可實作性,剩 3 項是純腳本、二十行 GDScript**。

### ⚠️ 兩項貫穿多份文件的錯誤宣稱,已被實測推翻

1. **「本專案無 Godot 執行環境可實測」是錯的。** 執行檔在
   `~/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`,
   `--headless --path <proj>` 可完整跑完(exit 0)。`which godot` 找不到只代表**不在 `PATH` 上**。
   該句寫在 **ADR-0002 第 22/254 行、ADR-0003 第 17 行、ADR-0005 第 121 行(列為 `Constraints`)、
   `tests/README.md`**。根因:2026-08-05 spike 的 README 說的是「**本 agent 的環境**沒有安裝 Godot」
   (當時為真),被壓縮成「本專案跑不了」後沿用,**沒有重新查證**。
   **⚠️ headless 必須 `application/run/flush_stdout_on_print=true`**,否則 `print()` 全被緩衝、
   程式不退出就一個字都看不到。
2. **`current-best-practices.md` 第 41–49 行的 `@abstract` 範例是錯的。**
   `@abstract func ...: pass` 在 4.7.1 是 `Parse Error: An abstract function cannot have a body.`
   正確形式是**裸簽章**(無冒號、無主體)。**ADR-0004 有 5 處、ADR-0005 有 8 處帶 `pass` 主體,
   共 13 處要刪。** 而**第三輪 `/architecture-review` 把該假設由「印象」升級為「已查證」,
   依據就是逐字比對這個錯誤範例** —— 那次升級無效。**六輪來第一次抓到參考庫本身有錯**,
   先前所有輪次都預設它是可信基準。

### 產出兩個 prototype 目錄

| 目錄 | 作者 | Status |
|---|---|---|
| `prototypes/engine-verification-spike-2026-08-20/` | **協調者(越權,見下)** | Phase 1 **concluded**;Phase 2(GdUnit4)未跑 |
| `prototypes/xcheck-gdscript-specialist-2026-08-20/` | `godot-gdscript-specialist` | **concluded** |

原始 log 全部歸檔,檔頭自帶指令、exit code、判讀陷阱,**下一輪不需回讀對話**:
`engine-verification-spike.../logs/run-final-2026-08-20-headless.txt`(430 行)、
`xcheck.../logs/xcheck{1,2,3}-unfiltered.txt` + `global-script-class-cache-full.cfg`。

### 🔴 F-6 · BLOCKING · ADR-0002 機制四的核心宣告在 4.7.1 無法編譯

```
Parse Error: Nested typed collections are not supported.
   at: GDScript::reload (res://scripts/x9_adr_member_exact.gd:2)
```

`var _records: Dictionary[AffinityTypes.Pair, Array[AffinityRecord]]`(ADR-0002 **第 114 行**)
——**型別註記與探針逐位元組相同**(協調者已獨立核對),parse error 定位在**宣告那一行本身**。
specialist 另補測 **class member 無初始化 / 函式參數 / 回傳型別三種形狀,全部同一錯誤**,
並在**完全獨立的專案**重現(不同 `project.godot`、不同 `.godot` 快取)。
**爆炸半徑**:`grep` 僅命中 ADR-0002 五處 + `registry` 第 87 行 + GDD 兩處敘述,ADR-0003/0004/0005 零命中。

**替代方案實測(四項皆實際 `build()` 出資料)**:

| 選項 | 結果 |
|---|---|
| (a) `Dictionary[Character, int]`(`_death_marks` 形式) | OK |
| (b) `Array[AffinityRecord]` 單獨 | OK,`is_typed=true` |
| (c) `Dictionary[Pair, Array]` | OK,但**代價是「不強制」而非「無型別」**——見下方推翻 |
| **(d) `Dictionary[Pair, AffinityRecordList]`** | **OK,且是唯一同時保住兩層型別的選項**(需新增一個 `class_name`;代價是多一層 `.items`) |

**這正是「核准前必須實測」的證據**:若照原計畫直接把 ADR-0002 推上 `Accepted` 再往下走 story,
這一行會在實作第一天就爆,而那時它已是「已核准的架構決策」。

### ✅ 已關閉的 VR(可直接拿去改 ADR)

| 項 | 結果 |
|---|---|
| **ADR-0002 VR #3** | `pow(0.0, 0.0)` = `1.0`(`**` 運算子與 `pow(int,int)` 同)。**顯式特判仍須保留** ——GDD 管的是「不建立依賴」,不是「數值是否碰巧相符」;改變的只有理由措辭 |
| **ADR-0002 VR #5** | subscript 賦值**不**推斷內層元素型別(`subscript_assigned_literal_is_typed = false`)。spike 未涵蓋,specialist 順帶關掉 |
| **ADR-0005 VR #3** | `input_devices/buffering/agile_event_flushing` **存在**,現值 `false`(正是機制七要的)。**推測鍵名猜對了**;`has_setting()` 防衛照留,理由改為「鍵名可能隨版本改變」 |
| **ADR-0005 VR #1 / ADR-0004 VR #6** | 裸簽章對 `Array[T]`/`bool`/`float`/`void`/**`Vector2`** 全部合法;類別內同時有 `signal` + 多個 `@abstract func` 亦合法;`@abstract func` 同一行也合法。→ **R4-2(BLOCKING)修法語法基礎確認** |
| **ADR-0004 VR #6a** | `Parse Error: Class "..." must implement "...diagnostic_seed_position()" ... or be marked as "@abstract"` → **編譯期錯誤,是結構保證**。⚠️ 精確範圍是「**具體**(非 `@abstract`)子類別必須實作」,ADR 若寫成硬性保證須把「除非該子類別自己也標 `@abstract`」寫進去 |
| **ADR-0005 VR #15** | 釋放後 `named.is_valid()` 與 `lambda.is_valid()` **皆為 `false`** → S-1 防禦成立、VC #18 的假設成立 |
| **四個容器內省 API** | 在 4.7.1 **全部存在**。**`get_typed_key_builtin() == 2`(TYPE_INT)是「enum 家族在容器層被抹成 int」最短最乾淨的證據** |

### ⚠️ specialist 推翻協調者三條結論(**下一個 session 最容易重犯的地方**)

| 我的結論 | 判定 | 為什麼 |
|---|---|---|
| **F-9 (d)**「兩層型別都保住」 | **證據無效,結論湊巧為真** | `_describe()` 用 `get_class()`,那回傳**原生**類別 —— 任何 `RefCounted` 子類都印 `Object(RefCounted)`,**無法區辨 `AffinityRecordList`,也從未碰到內層**。**ADR 不可引用「值型別 = Object(RefCounted)」那一列**,須改引 xcheck 的 `script.get_global_name()` / `v is AffinityRecordList` / `inner.items.is_typed()` |
| **F-9 (c)**「內層型別整個放棄」 | **結論是錯的** | 我存的是未型別化字面量 `[rec]`,`is_typed=false` 是那個字面量的屬性、與容器無關。實測存入 `Array[AffinityRecord]` 讀回是 **`true`**。(c) 真正的代價是**不強制**(兩種都收)—— 「無強制」可用 setter 收斂,「無型別」只能換結構,**兩者導出不同修法** |
| **F-3 層三**「enum 家族完全不擋」 | **結論 VALID,推導鏈不成立、措辭過寬** | spike **從未真的做過**錯家族 enum 鍵寫入,我是從一條無關訊息的子字串推導。specialist 做了:`Dictionary[Pair,int][Character.CHARACTER_3] = 99` → **完全接受、`size=1`、`keys=[2]`、零錯誤**。而編譯器**確實**擋 enum 家族(`Cannot assign a value of type "AffinityTypes.Character" as "AffinityTypes.Pair"`)—— **唯一的洞是型別化 Dictionary 的 subscript 路徑** |

**第三點改變 ADR-0002 的修法**:經型別化函式參數存取是真的會被靜態檢查擋。要禁止的是
**「裸 subscript 接受外來鍵」**,不是「型別標註沒有保證」。

### 🔶 唯一未查證項,且它跨兩份 ADR:export release 建置

必須拆兩層,**ADR-0002 只依賴 A**:

| 層 | 現象 | 依賴者 | 風險 |
|---|---|---|---|
| **A** C++ 容器驗證 → **寫入被丟棄** | **ADR-0002 機制四** | 低-中 |
| **B** GDScript VM 拋錯 → **中止所在函式** | **ADR-0005 的 F-10 / S-1 必要性論證** | **中-高** |

**層 A 的關鍵論證**:`ERR_FAIL_COND_V(cond, false)` 的 `return false` 與錯誤列印在**同一巨集內**
—— 若巨集被編掉,`return false` 也消失、寫入照樣進行。**兩者綁在一起**,故在 release build
觀察到那行 ERROR 即足以確認 A。**證據等級:訓練資料推論,未查證**(知識截止早於 4.7、
無 C++ 原始碼、無 release build)。

**層 B 若在 release 被編掉,F-10 判定三的論證方向反轉** —— 守衛仍該留,但理由從
「防止函式被砍斷」變成「防止用到垃圾值」;且 **debug/release 不一致本身更糟:會出現
debug 測得出、release 測不出的 bug**。

**本輪不可測(協調者已獨立複核)**:`%APPDATA%\Godot\export_templates\` 存在但**完全是空的**、
全域零個 `.tpz`、參考庫僅兩行講 release(皆為 script backtracing,不回答此題)。
三條替代路已排除:`--headless` 只換 DisplayServer、`OS.is_debug_build()` 不能切換、無 template binary。
**唯一決定性測法**:下載 export template(約 1 GB,**待使用者決定**)→ 匯出 release(取消
Export With Debug)→ 以 xcheck 的 X2/X3r/X6 重跑。

**兩個比「測一次」更有價值的建議**:

1. **把探針改成建置無關(免費)** —— 只量容器內容(caller 持有字典、中止與否無所謂、
   `assert_eq(d.size(), 0)` 是唯一判準),兩種建置都直接產出答案,並可掛進 CI 的
   release-export job 成為**永久回歸測試**。
2. **讓答案變得不重要** —— 機制四明訂「所有外部鍵一律經型別化參數邊界、禁止外來 `Variant`
   當 subscript 鍵」,層 A 即降級為**縱深防禦**,與 C3 對 `Mutex`、ADR-0004 對 `SaveIOBackend`
   同一手法。建議 forbidden pattern:**`raw_variant_subscript_into_typed_container`**。

**最壞影響**:不是崩潰,是**靜默存檔損壞且出貨版本專屬** —— 壞值寫進 `_records` → 讀取時
在遠處爆 → 經 `var_to_bytes()` 序列化並**通過兩層 SHA-256**(雜湊驗位元組完整性,不驗語意)
→ 存檔在位元層合法、語意層已損壞。**連帶挖出跨 ADR 缺口:ADR-0003 的 `validate_semantics()`
目前不涵蓋容器元素型別**,不論層 A 答案為何都該納入(app 層、與建置組態無關)。

### 待改清單(**必須走 `/architecture-decision`,協調者不得直接改**)

| 目標 | 內容 |
|---|---|
| **ADR-0002** | 機制四改宣告 (d);型別安全宣稱重寫(三層圖像 + 型別化參數邊界規則);VR #1/#2/#3/#5 標已查證;VR **新增** release 建置項(跨 ADR-0005) |
| **ADR-0003** | `validate_semantics()` 補容器元素型別檢查 |
| **ADR-0004** | 機制一 `SaveIOBackend` **5 處 `pass` 主體刪除**;VR #6/#6a 標已查證 |
| **ADR-0005** | **8 處 `pass` 主體刪除**;VR #1/#3/#15 標已查證;**S-1 必要性論證改寫**(層 B 未查證);**「發現 G」前提更正**(兩種綁定行為相同,改採具名綁定可辯護但**非必要**);第 121 行 `Constraints` 的「無 Godot 執行環境」刪除 |
| `current-best-practices.md` | `@abstract` 錯誤範例修正(歸 **`godot-specialist`**) |
| `docs/registry/architecture.yaml` | 新增 `raw_variant_subscript_into_typed_container` |
| `tests/README.md` | **N-8**:乾淨 checkout 無 `global_script_class_cache.cfg` → 所有 `class_name` 解析失敗,CI 須先跑 `--headless --editor --quit`(或 `--import`)。**`project.godot` 一進 repo、守衛放行後,這會是第一個失敗原因** |
| 兩個 spike | N-1~N-6 + Phase 2 三項必修(清單在 specialist 交付內),**待 ADR 定案後一併處理**,避免改了又改 |

### 流程:協調者越權,使用者已裁決

**18 個 `.gd` 探針是協調者自己寫的,違反 `technical-preferences.md` 的 File Extension Routing 表**
(`.gd` → `godot-gdscript-specialist`)。`.claude/rules/prototype-code.md` 放寬的是**程式碼品質標準**,
**不是「誰有權寫」**。

**使用者 2026-08-20 給了常設授權**:只要工作落在路由表明列的領域,**直接委派,不必每次問**;
環境那條「未經要求不呼叫 Agent」在此已被明文覆蓋。路由表**之外**的委派仍須先問。
已記入記憶 `domain_routing_no_overreach.md`。

### 模式警示:協調者四次自傷,且第五次同型

| 項 | 內容 |
|---|---|
| **F-5** | 已知會編譯失敗的 `load()` 排在報告中間 → debugger 暫停擋住其餘檢查。假設「硬中止只來自執行期崩潰」 |
| **F-8** | 用 `load(path) != null` 判定編譯成功 —— **`load()` 對 parse error 不回傳 `null`**。RISKY 0 五項全誤報 `COMPILED OK`,其中兩項引擎明明印了 Parse Error。已改 `CACHE_MODE_IGNORE` + 型別檢查 + `reload()` 回傳 `Error`(specialist 以「同 process 覆寫同路徑判定值翻轉」證明可靠) |
| **F-14(3)** | 批次字串替換弄壞字串轉義 → runner 編譯不過,**使用者白跑一輪** |
| 第四次 | README 表格替換其實**沒配對到**,我卻去 grep 旁邊的字串就當成功 |
| **N-3 / N-4** | **「修法宣稱關閉缺陷,實際只關一族」** —— 與第六輪對 R4-4「三處只修一處」**完全同形,第五次** |

**specialist 建議的自問(已採納)**:

> **「這個缺陷的全部出現位置我列過清單了嗎,還是只修了觸發我注意的那一處?」**

搭配第六輪的那一條(「這個修法會不會讓某個既有簽章、既有正交性宣告變得不成立」)一起用。

**值得記的正面事實**:specialist 主動揭露自己的 log 經過 `grep -v` 過濾、兩段被 `tail`/`head` 截斷、
**自己的 `_try()` 犯了與 N-3 同型的錯**(無條件印 `(NOT aborted)`,X3r outer 其實中止了)、
並**撤回**一項自己的懷疑(`get_script_method_list()` 不含繼承方法——實測含)。
它也自陳 5 項探針弱點(X6 只測一種回傳型別、X2 只用一個序數值且永在範圍內、X7 未測反方向等)。

### 下一步

1. **`/architecture-decision`** 處理上表 —— 建議**先做 ADR-0002**(它是原始目標,且證據最完整)
2. **待使用者決定**:要不要下載 export template(約 1 GB)以決定性回答 release 那題
3. 第六輪遺留的 **R6-6~R6-13**(ADR-0005 第四次修訂)仍未做 —— 與上表的 ADR-0005 項目**可合併成一次修訂**
4. `/ux-review design/ux/interaction-patterns.md`(與架構軌零依賴)

---

## Session Extract — `/architecture-decision` ADR-0002 引擎行為實機驗證修訂 2026-08-20

**起因**:2026-08-20 的引擎驗證 spike 抓到 ADR-0002 機制二的核心宣告在 4.7.1 無法編譯(F-6 BLOCKING)。
使用者裁決範圍為 ledger 全部 14 項(A1~A14)+ GDD 加實作註記不改規則。

### 已寫入的五份檔案

| 檔案 | 變更 |
|---|---|
| `docs/architecture/adr-0002-…md` | 523 → **651 行**。Status 新增修訂註記、Date、Engine Compatibility(VR 欄改為指向新增的「VR 明細」表,**五項擴為八項**)、機制二新增 `AffinityRecordList` 定義段、型別改宣告、**新增機制四之二**(三層型別保證圖像 + 鍵/值兩條邊界規則)、**新增機制四之三**(呼叫端型別義務)、機制八 `validate_semantics()` 擴充、Key Interfaces 新增區塊、**Alternative 7**、Risks +2 列、Consequences Positive +1 / Negative +2、Validation Criteria +3 項(9/10/11)、Related Decisions +2 |
| `docs/registry/architecture.yaml` | 第 87 行型別字串;新增 forbidden pattern `raw_variant_subscript_into_typed_container`。**68 → 69**(逐節實測 10/11/23/**25**),ADR-0002 佔 12 → **13** |
| `design/gdd/affinity-data-pool.md` | 第 60/539 行各加實作註記。**規則層完全未動** —— 原文本就寫「例如…**或等效結構**」,包裝類別滿足該豁免 |
| `.claude/docs/technical-preferences.md` | ADR-0002 條目、Forbidden 清單 24→25、Registry 累計 68→69 |
| `production/session-state/active.md` | 本段 |

### 核心決策:選項 (d) 包裝類別

```gdscript
class_name AffinityRecordList extends RefCounted
var items: Array[AffinityRecord] = []
```
`var _records: Dictionary[AffinityTypes.Pair, AffinityRecordList]`

實測三項(`x3_wrapper_two_layer.gd`):`script.get_global_name() = AffinityRecordList`、
`v is AffinityRecordList = true`、`inner.items.is_typed() = true`。
⚠️ **不可引用 `get_class()`** —— 它回傳原生類別,任何 `RefCounted` 子類都印 `RefCounted`。

**Alternative 7 記錄了 (c) `Dictionary[Pair, Array]` 的拒絕**:代價不是「無型別」而是「**不強制**」
(型別化 `Array` 存進裸值槽後 `is_typed()` 仍為 `true`)。拒絕理由是本 ADR 系列的立場
**結構保證優於紀律要求**,加上 (c) 還有一項未測(未型別化 Array 存進去後能否當
`Array[AffinityRecord]` 讀出)。

**原巢狀宣告不列為 Alternative** —— 它不是被權衡後拒絕,是**被引擎否決的原決策**。

### 三層型別保證圖像(機制四之二,新增)

| 層 | 實測 | 可依賴 |
|---|---|---|
| 一 · 編譯期 | **確實擋** enum 家族與容器整體賦值(`x1b`/`x1c`) | **是** |
| 二 · C++ 容器驗證 | debug 生效;**兩路徑行為不同**:值槽賦值→**中止函式**;`append`→**丟棄寫入**。⚠️ 成因是「賦值運算子 vs 方法呼叫」,**不是** Dictionary vs Array | 否(release 未查證) |
| 三 · subscript 鍵 | **完全不擋**:`size=1, keys=[2]`,零錯誤。機制 `get_typed_key_builtin()==2` | 否(已證為空隙) |

**兩條邊界規則,不可互相代用** —— 規則一(鍵)關層三、規則二(值)關對層二的依賴。

### ⚠️ 本次修訂初稿自己引入 2 項缺陷,由寫入前 Step 5.5 雙軌覆核抓出

| 項 | 內容 |
|---|---|
| **B1(BLOCKING)** | 用**鍵**邊界規則去支撐**值**層(層二)降級 —— 論證的是另一件事。兩位覆核者獨立得到同一結論與同一修法。已改為兩條獨立規則,並把「不可互相代用」寫進 registry `why:` 欄 |
| **VR 計數低估** | 寫成「五項關閉、**一項**新增」,實為**三項**新增;少算會讓讀者漏掉 **#7(release 建置,仍未查證)** —— 而 #7 正是 B1 缺口所在的同一項 |

**與 ADR-0005 第三/四/五輪「修法本身引入新缺陷」同一模式,第六次。Step 5.5 這道關卡再次證明有效。**

### B2 未用 hedge,改以 `XCHECK-4` 探針實測關閉 —— 並測出原草稿沒涵蓋的洞

初稿把「`is_finite("abc")` 是執行期錯誤」當論證地基,但那是**訓練資料推論、零探針涵蓋**。
委派 `godot-gdscript-specialist` 補測(`.gd` 依 File Extension Routing 表)。
Godot `4.7.1.stable.official.a13da4feb`,exit 0,`logs/xcheck4-unfiltered.txt`(178 行)。

| 操作 | 結果 |
|---|---|
| `is_finite`/`is_nan`/`is_inf` 餵 `String` | **中止所在函式**(原句成立) |
| `m == 0.0` / `t >= 1` 餵 `String` | **同樣中止** —— ⚠️ 「比較運算子比較安全」是**錯的假設,被推翻** |
| **`var t: int = <float 1.5>`** | **不中止、不報錯、靜默截斷為 `1`** —— ⚠️ **唯一「不出錯但也不安全」的情況,原草稿完全沒涵蓋** |
| 中止傳染範圍 | 只影響直接執行該操作的函式,不往上傳 |
| `append_record(pair, m: float, …)` 餵 `String` | **呼叫端**就被擋(函式本體未執行)—— 但那是**值**邊界保證,不是鍵邊界 |

**兩項連帶結論**:(i) 機制八的型別檢查**只能用 `typeof()` 內省**,不能用「賦值進型別化變數、
指望賦值失敗」——賦值對 `String` 會中止、對 `float` 會靜默截斷,兩者都不是可判斷的檢查;
(ii) **`t`/`c` 的型別檢查不可寬鬆到「int 或 float 皆可」** ——`t` 是 Delta Log 的全域排序鍵,
截斷會違反跨結構不變量 3,且是**寫進內部狀態之後**才顯現。

### 機制四之三(新增):型別錯誤是拒絕碼機制唯一涵蓋不到的失敗類別

型別化參數的阻擋方式是**整段呼叫端函式中止**,不是可判斷的回傳值。
`append_record()` 不可能回傳 `INVALID_TYPE` —— 那個呼叫到不了函式本體。
故:**7 類 `WriteRejection` 的範圍界線明文化為「值域與狀態的非法,不含型別的非法」**,
上游持有來源不明 `Variant` 時**必須自行以 `typeof()` 收斂**。
**刻意不新增 `INVALID_TYPE`** —— 那是結構上不可能被回傳的死碼,會誤導呼叫方以為型別錯誤會被攔下並回報。

### 跨 ADR 三處分工宣稱,`godot-specialist` 逐一核實成立

- **ADR-0003 互補不重疊**:`bytes_to_var(buffer, false)` 只擋**自訂 `Object` 類別**注入,
  不管內建型別錯配(`String` 存進本該是 `float` 的欄位仍會成功解碼)。故機制八補的是另一維度。
  ⚠️ 由於 `TR-affinity-019` 明訂本系統是驗證規則唯一權威,**這條規則歸 ADR-0002 而非 ADR-0003**
  ——原本 spike 判定的「ADR-0003 缺口」其實是本 ADR 的責任,已在此關閉。
- **ADR-0005 共用未查證項但方向不同**:本 ADR 依賴層 A(容器驗證是否丟棄寫入)且**已由規則二降為縱深防禦**;
  ADR-0005 的 S-1 必要性論證依賴層 B(VM 是否中止所在函式),**尚未降級**。
- registry 第 87 行為唯一目標,新 pattern 全庫零命中、無重複鍵覆蓋風險。

### 仍未關閉的兩項 VR

- **#4 `Mutex` 可重入** —— 未查證,但原因已從「不能測」改為「**尚未寫探針**」
  (「本專案無 Godot 執行環境」的前提已被推翻)。機制七的鎖定模式在兩種答案下皆正確,不影響可實作性。
- **#7 export release 建置下容器驗證是否生效** —— **本專案目前無法查證**
  (`export_templates/` 為空、零 `.tpz`,三條替代路已排除)。
  **建議的關閉方式不是手動測一次**,而是把探針改成建置無關(只斷言容器 `size()`),
  掛進 CI 的 release-export job 成為永久回歸測試。

### 下一步

1. **🔴 2026-08-20 第七輪已執行,判定為不可進 `Accepted`** —— 本項的建議(「先讓第七輪獨立重推涵蓋分佈,再由使用者裁決」)**已完成**,答案是不行。第七輪獨立推導好感度為 **21 ✅ / 3 ⚠️ / 0 缺口**(此前 22/2/0,`TR-affinity-011` 因 R7E-4 降級),並抓出 2 項 BLOCKING + 15 項其他發現。詳見檔尾「Session Extract — /architecture-review 第七輪」與 `docs/architecture/architecture-review-2026-08-20-round7.md`。**下一個動作是 `/architecture-decision` 修訂 ADR-0002,不是裁決 `Accepted`。**
   但 `Accepted` 是**使用者裁決**,全框架五個消費者、零個生產者。
   建議先讓**第七輪獨立 `/architecture-review`**(全新 session)重推涵蓋分佈,再裁決。
2. **剩餘 ADR 修訂**:ADR-0003(`validate_semantics()` 的責任已改判歸 ADR-0002,故 ADR-0003 側可能無事可做,需核對)、
   **ADR-0004**(刪 5 處 `pass` 主體、VR #6/#6a 標已查證)、
   **ADR-0005**(刪 8 處 `pass`、VR #1/#3/#15 標已查證、S-1 必要性論證改寫、發現 G 前提更正、
   刪第 121 行「無 Godot 執行環境」Constraint,**與第六輪遺留的 R6-6~R6-13 合併成一次修訂**)。
3. ~~`docs/engine-reference/godot/current-best-practices.md` 第 41–49 行的 `@abstract` 錯誤範例(歸 `godot-specialist`)。~~ **✅ 已於 2026-08-20 第七輪修正**(第 47–48 行改裸簽章 + 12 行更正註記,記載實測證據與錯誤傳播到兩份 ADR 共 13 處的事實)。使用者核准為「純事實更正、零決策內容」。
4. `tests/README.md` 記 N-8(乾淨 checkout 無 `global_script_class_cache.cfg`)。
5. 兩個 spike 的 N-1~N-6 + Phase 2 三項必修,**待 ADR 全數定案後一併處理**。
6. `/ux-review design/ux/interaction-patterns.md`(與架構軌零依賴)。

### 流程紀錄

- **常設授權運作正常**:`.gd` 探針全程委派 `godot-gdscript-specialist`,協調者只做編排、判讀、寫 ADR 文字、git。
- **Step 5.5 在 revision mode 是強制的,且這次再次證明必要** —— skill 明文寫「revision 是本 skill 風險最高的操作」。
- **採納的第三條自問(來自本次 B1)**:
  > **「我這句『因為 X 所以 Y』,X 和 Y 講的是同一個對象嗎?」**
  搭配既有兩條:「這個修法會不會讓某個既有簽章/正交性宣告變得不成立」、
  「這個缺陷的全部出現位置我列過清單了嗎」。

---

## Session Extract — /architecture-review 第七輪 2026-08-20

- **Verdict**: **CONCERNS**(第三~七輪皆 CONCERNS)。但與第六輪(零 BLOCKING)有實質差異:**三份 ADR 各帶 BLOCKING 級項目,且沒有一項屬於涵蓋缺口** —— 全部是已寫下的決策內容與已實測的引擎現實不符
- **Requirements**: 130 項 —— **64 ✅ / 34 ⚠️ / 32 ❌**(第五輪 68/30/32)
- **游標系統**: **12 完整 / 7 部分 / 0 缺口**(第五輪 15/4/0)。⚠️ = `-008`、`-009`、`-010`、`-011`、`-013`、`-015`、`-017`
- **好感度**: **21 完整 / 3 部分 / 0 缺口**(第五輪 22/2/0)。⚠️ = `-008`、`-011`(新)、`-020`
- **New TR-IDs registered**: None —— `affinity-data-pool.md` 2026-08-20 的 2 行改動經逐行核對確認**只加實作註記、規則層未動**,`tr-registry.yaml` 本輪零改動
- **GDD revision flags**: None(引擎現實層面)。第三輪的兩處**設計文件內部張力**(Core Rules #5 全域隱藏 vs AC-60 未登記表面例外)維持開啟,ADR-0005 自陳「該張力本身仍未被裁決」。`systems-index.md` 未改動
- **Report**: `docs/architecture/architecture-review-2026-08-20-round7.md`

### 🔴 最重要的一件事:ADR-0002 判定為不可進 `Accepted`

2026-08-20 的 `/architecture-decision` session 把 ADR-0002 推到「最接近可核准」並建議先跑第七輪再裁決。**本輪答案是不行。**

**理由不是修訂做錯方向** —— 包裝類別、兩條邊界規則的分工、`validate_semantics()` 改用 `typeof()` 內省,這三段是全 ADR 最紮實的部分,「兩條規則不可互相代用」的推導鏈本輪覆核判定**正確關閉**。**理由是修訂新增範圍宣告時,只稽核了自己剛寫的那兩個方法(`append_record`/`notify_death`,參數全是型別化 enum),漏掉 ADR 既有的三個 `Variant` 公開入口。**

| 項 | 內容 | 級別 |
|---|---|---|
| **R7E-6** | `t_query: Variant`(機制五三個讀取函數)才是本 ADR 真正的 `Variant` 入口,而機制四之三的範圍宣告完全沒稽核它 → **`ReadRejection.FUTURE_TIME_QUERY` 是死碼**(第 294 行那條比較正是本次修訂自己實測出「對 `String` 中止所在函式」的比較)。機制八為 `import_state()` 立的「先 `typeof()`」規則完全適用於機制五,機制五卻沒引用它。**需新增/擴大拒絕碼,屬決策變更** | **BLOCKING** |
| **R7E-4** | enum 型別化參數對數值近親**靜默轉換**(已由探針 B 實機確認)→ `Variant(3.7)` 靜默變成合法序數 3、記錄寫進**錯誤配對**、`append_record()` 回傳 `NONE`。結論(不加 `INVALID_TYPE`)仍對,**理由必須改寫** | **BLOCKING** |
| **R7-P1** | **探針額外推翻機制四的另一句宣稱**:步驟 4/5 註解寫「GDScript enum 本身型別化後這條理論上不可達」—— 實測越界 int(`-1`/`999`)**原封不動抵達函式本體、零錯誤零檢查**。`INVALID_SOURCE`/`INVALID_PAIR` 不是防禦層,是**唯一防線** | 高(新) |
| **R7-P2** | float/bool 截斷後若落在合法序數範圍內,會**靜默通過任何值域檢查** —— 檢查看到的已是「合法的 3」,無從得知它原本是型別錯誤 | 中高(新) |
| **R7-P3** | 機制八 `from_dict()` **不可對不可信字串裸用 `Pair[name]`** —— 動態非法字串索引是**執行期中止**,`validate_semantics()` 會在走到自己的拒絕碼邏輯前先中止,契約承諾的 `ImportResult` 永遠回不去。正確寫法:先 `values().has()`/`keys().has()` 存在性檢查,或改用已驗證乾淨回傳 `null` 的 `find_key()` | 中高(新) |
| **R7E-2** | **由「引擎行為未查證」升級為已實測的正確性缺口** —— 型別化 `Dictionary` 對從未寫入的鍵做 subscript 讀取是 `SCRIPT ERROR` 並**中止呼叫函式**(不是 `null`、不是預設值)。而機制二明文「首次寫入時才建立 `AffinityRecordList`」→ 任何寫入前的讀取(`n(p)=0`,GDD 明文要處理的合法情境)會當場中止。**必須二選一並明文寫入 ADR**:(a) 建構子預填 10 對空 list,或 (b) 讀取入口一律 `has()` 守衛。`_death_marks`/`t_death()` 同理 | 中高 |

其餘:R7E-7/**C7**(中高,跨 ADR)、R7E-8(`death_marks` 字串鍵值域缺席)、R7E-3(層三歸因寫錯、三層不正交)、R7E-9(頂層 `data` 鍵集合未驗)、R7E-12(`AffinityRecordList.items` 是公開可變欄位 —— **Alternative 7 被拒的「不強制」理由原封不動重現**)、R7E-11(R6-4 的 `Mutex` 矛盾句在 ADR-0002 本體未修)、R7E-14(`_reclaimed_tokens` 次要逾時 = C1 孤兒義務的同構複本)、R7E-15、R7E-10、R7E-5、R7E-16。**R7E-1 與 R7E-13 已由探針關閉。**

### R6-6~R6-13:**8 項全部仍開**,無一被 R6-1~R6-5 順帶關掉

`godot-specialist` 逐項讀 ADR-0005 現行檔案並附行號證據。這是游標系統四項降級的**唯一成因** —— 第五輪的 15/4/0 是在這 8 項被發現**之前**算的,第六輪發現了但明文未重推,ADR-0005 第四次修訂尚未執行。**ADR-0005 沒有變差,是我們對它的認識變準了。** R6-1 回歸檢查:已關閉(現存 −50 皆為歷史敘述);唯一落差是第六輪報告記載「4 處刻意保留」而 ADR 側現存 3 處,差一處未查證。

### 三支探針(同日執行,`prototypes/xcheck-round7-2026-08-20/`)

Godot `4.7.1.stable.official.a13da4feb` headless,三支皆 exit code 0,log 未過濾。**探針執行者主動自陳一項過程失誤並保留證據**:探針 C 第一版把「預期會過」與「預期會失敗」的測試放同一檔,Parse Error 擋掉整檔四項 —— 正是 spike F-5 的教訓。修法為一判定一檔案 + 逐檔 `reload()` 的 `Error` 檢查,第一版失敗 log 刻意保留(`probeC-v1-flawed-unfiltered.txt`)而非刪除。

**探針自陳的殘留未查證項(兩項是 R7-P1/R7-P3 建議修法的地基,下次修訂前應補測)**:(1) `values().has(-1)`/`.has(999)` 越界輸入的實際回傳值(本輪只測合法值);(2) `keys().has(name)` 是否與 `values().has()` 對稱;(3) 只測單一配對存入,未測 `_death_marks` 的功能性存讀;(4) 只測 `Pair` 一個 enum,`Source`/`Character` 屬合理外推非直接測量。

### 本輪順手修正的兩項(使用者核准的純事實更正,零決策內容)

1. **`docs/engine-reference/godot/current-best-practices.md` 第 47–48 行** —— `@abstract` 錯誤範例已修:簽章改裸簽章、`pass` 刪除,並加 12 行更正註記。**這一項必須先於任何 ADR 修訂執行**,否則修完 13 處 `pass`,下一份 ADR 又會從同一個地方抄回來。⚠️ **第三輪把 `@abstract` 由「印象」升級為「已查證」的依據就是逐字比對這個錯誤範例 —— 那次升級無效。**
2. **`docs/registry/architecture.yaml`** —— `last_updated` `2026-08-19c` → `2026-08-20`;`affinity_delta_log`(第 93 行)`revised: ""` → `"2026-08-20"`。**這是第六輪 R6-2 已修過兩次的同一族缺陷,第五次出現**(內文改了、結構化欄位沒跟上)。逐節計數複查未變動。

### 引擎審計

- **棄用 API**:主審 grep 涵蓋五份,零有效命中(`Time.get_ticks_msec()` 是替代者;`duplicate_deep()` 兩處在已拒絕的 Alternative 內)。⚠️ `godot-specialist` **自陳未逐行比對 ADR-0001/0003**,那兩份在專家側為「未查證」
- **版本一致**:五份皆釘 4.7.1,無過時釘選
- **13 處 `pass` 主體仍在**(ADR-0004 五處:80/83/86/89/92;ADR-0005 八處:533/537/542/556/1180/1183/1186/1189)。**專家另抓到 spike 清單漏掉的 2 處指示句**(ADR-0004:71、ADR-0005:1151「下方沿用該形式」)—— 只刪 `pass` 不改這兩句,下一個實作者會照著加回來。**「同一缺陷的全部出現位置」問題第八次**
- **2026-08-20 的證據只套用到五份中的一份**:ADR-0001/0003/0004/0005 對 `2026-08-20` **全部零命中**。雙向後果 —— 低報已知的洞(13 處 `pass`;ADR-0003:17 與 ADR-0005:121 的「無 Godot 執行環境」仍是**現在式**,後者還位在 `Constraints` 即架構約束),同時高報未知的洞(ADR-0005 Day-1 spike 七項中 **#12/#15 已可劃掉**、ADR-0004 VR #6/#6a 已關閉)
- **參考庫矛盾其實有兩處**:4.5(LOW vs HIGH,已登記)之外,**4.6 也有**(`VERSION.md` MEDIUM vs `breaking-changes.md` HIGH,**本輪新發現**)—— 4.6 影響面更大,`technical-preferences.md` 的「Jolt(4.6+ 預設)」正押在那個版本。另 `modules/` 8 份仍標 4.6
- **`VERSION.md` 的 `LLM Knowledge Cutoff` 欄位**被當成事實引用(ADR-0002 第 25 行),但它不等於任何特定模型的實際截止日 —— 建議改為「本專案假設的最低共同截止日」並註明是保守下界
- **正面**:ADR-0005 以 `InputEvent` 子類別分類而非 `.device`,對 4.7 device ID 重編號是**結構性免疫**,做法**優於棄用表的要求**(該表只要求 runtime query);ADR-0002 機制七「單一進入點取鎖」讓正確性不依賴未查證的 `Mutex` 可重入性,專家判為**全專案處理未查證引擎行為的最佳範例**

### Registry / Pre-gate

- **Registry 69 項逐節實測零落差**:10 state / 11 interface / 23 api / 25 forbidden;依 `adr:` 欄 13/13/6/8/26/3(none)= 69,與檔頭及 `technical-preferences.md` 三處一致
- **Pre-gate 五項全備**(以檔名 glob)。但 `/gate-check pre-production` 仍不保證通過:ADR `Accepted` 0/5、畫面 UX 規格 0 份、`interaction-patterns.md` 未經 `/ux-review`

### 流程紀錄

- **兩個背景 agent 各中斷一次,兩次都偵測到並以 SendMessage 接續、未重跑、未無限期等待** —— 這是 2026-08-18「等死掉的背景任務」教訓的第一次正面應用。第一次回傳只有一句開場白;第二次停在「正要修探針 C」
- **常設授權運作正常**:引擎覆核走 `godot-specialist`(路由表「General architecture review」),`.gd` 探針走 `godot-gdscript-specialist`(File Extension Routing 表),協調者只做編排、判讀、寫報告
- **模式警示,第七次一致**:本輪 ADR-0002 的兩項 BLOCKING 都是**修訂自己引入的範圍宣告讓既有簽章不成立**,而非修訂寫錯。第六輪的自問「這個修法會不會讓某個既有簽章、既有正交性宣告變得不成立」方向正確但不充分。**本輪採納第四條自問**:
  > **「我這次新增的範圍宣告,涵蓋了本文件全部同類的介面面嗎?我列過那份清單嗎?」**

### 下一步

1. **`/architecture-decision` 修訂 ADR-0002** —— R7E-6/R7E-4 兩項 BLOCKING + R7-P1/P2/P3 + R7E-2 的二選一裁決 + 其餘 11 項。**修訂前先補測探針殘留的兩項**(`values().has()` 越界、`keys().has()` 對稱性),因為 R7-P1/R7-P3 的建議修法押在它們上面
2. **`/architecture-decision` 第四次修訂 ADR-0005** —— R6-6~R6-13 八項 + 8 處 `pass` + 第 1151 行指示句 + 第 121 行 `Constraints` + VR #1/#3/#12/#15 標已查證。可合併成一次
3. **ADR-0004** —— 5 處 `pass` + 第 71 行指示句 + VR #6/#6a 標已查證。**ADR-0003** —— 第 17 行「無 Godot 執行環境」刪除
4. **C7 現在調和成本最低**(C1~C6 花了三~五輪才關完)
5. **建立 `docs/consistency-failures.md`** —— 自第三輪起**第五次**提出。七輪累積:自陳膨脹 ×1、修法引入新缺陷 ×4、散文改了但結構化欄位沒跟上 ×5、「只修了觸發我注意的那一處」×8
6. 戰棋盤面演算法層 ADR(一次移動 25 項 ❌ 中的大部分)、回合結構擁有權 + AI/遭遇系統 ADR
7. `/ux-review design/ux/interaction-patterns.md`(與架構軌零依賴)
8. **兩個 spike 目錄的 N-1~N-6 + Phase 2 三項必修**,待 ADR 全數定案後一併處理

---

## Session Extract — 探針 D 2026-08-21(**中斷點已解除**)

**接續情境**:2026-08-20 的系統中斷發生在「補測第七輪探針殘留未查證項 #1/#2」的中途 —— `godot-gdscript-specialist` 已交付 4 個 `.gd` 檔(`bb3c164`,commit message 明文標 `NOT YET EXECUTED`),但缺 `D.tscn`、未執行、無 log。本次接續完成剩餘全部 7 個步驟。

### 執行結果:**兩項殘留皆關閉,零中止**

Godot `4.7.1.stable.official.a13da4feb` headless,`main_scene` = `res://scenes/D.tscn`,**exit code 0**,log 未過濾(`logs/probeD-unfiltered.txt`,檔頭自帶兩步指令與 exit code)。D0 的三檔逐檔 `reload()` 編譯檢查**全部 `COMPILED OK`**。

| 判定 | 結果 |
|---|---|
| `Pair.values().has(-1)`(越界但合法 int) | **不中止,回傳 `false`** |
| `Pair.values().has(999)` | **不中止,回傳 `false`** |
| `Pair.keys().has("C1_C2")`(合法名) | **不中止,回傳 `true`** |
| `Pair.keys().has("NO_SUCH_PAIR")`(非法名,**靜態字面量**) | **編譯通過、不中止,回傳 `false`** |
| 同一非法名,執行期 `"".join()` 組出 | **不中止,回傳 `false`** |

- **殘留 #1 關閉** → **R7-P1 的建議修法地基成立**:機制四步驟 4/5 可用 `Pair.values().has(ordinal)` 作為 `INVALID_PAIR`/`INVALID_SOURCE` 的實際檢查手段。
- **殘留 #2 關閉** → **R7-P3 的建議修法地基成立**:`keys().has()` 與 `values().has()` 對稱,機制八 `from_dict()` 三條替代路徑(`values().has()` / `keys().has()` / `find_key()`)現已全部實測可用。
- **殘留 #3/#4 仍開**,但**不阻擋 ADR-0002 修訂** —— #3 影響實作期單元測試設計而非 ADR 決策內容(R7E-2 二選一裁決所需的缺鍵行為已由探針 A 實測);#4 的機制級結論不依賴特定 enum 的成員數,**但那仍是外推,不得記為已測**。

### 本次量到的新事實(探針 C 未區分)

同一個非法名字串,走 `.has()` **方法呼叫**與走 `[]` **subscript** 是兩種完全不同的命運:

| 形狀 | 字面量 | 執行期動態組出 |
|---|---|---|
| `Pair["NO_SUCH_PAIR"]` | **Parse Error,整檔編譯失敗** | **`SCRIPT ERROR`,中止呼叫函式** |
| `Pair.keys().has("NO_SUCH_PAIR")` | **編譯通過,回傳 `false`** | **回傳 `false`** |

**因此 ADR-0002 的規則措辭必須點名形狀,不能只點名輸入來源** —— 「不對不可信字串裸用 `Pair[name]`」禁的是形狀,「改用 `keys().has()` 先檢查」給的是替代形狀,**兩句都必須寫**,不是同一件事的兩種說法。

> **紀律註記(值得保留)**:探針 D 的檔頭註解已推測 `.has(字串)` 與 c2 的 enum-as-Dictionary 字面量 subscript 不同形狀,但仍把預期會過(d1)與預期可能失敗(d2/d3)拆三檔並逐檔編譯檢查。**量完證實那個推測正確且方向有利,但拆檔紀律不因結果良好而追認為多餘** —— d2 若與 d1 同檔而結果相反,會原地重演探針 C 第一版的整檔封鎖。

### 本次更新的檔案

| 檔案 | 改動 |
|---|---|
| `prototypes/xcheck-round7-2026-08-20/scenes/D.tscn` | **新建**(6 行,照 `C.tscn` 複製,`uid://bround7d`,腳本指 `runner_d.gd`) |
| `.../project.godot` | `run/main_scene` `A.tscn` → `D.tscn` |
| `.../logs/probeD-unfiltered.txt` | **新建**,未過濾,檔頭自帶兩步指令與兩個 exit code |
| `.../README.md` | 檔頭改「四支探針」+ 探針 D 分工說明;「如何重跑」補**切換探針是改 `main_scene` 不是傳參數**;log 表加一列;新增「探針 D」結果節;殘留表 #1/#2 劃掉並改寫 #3/#4 為何不阻擋 |
| `docs/architecture/architecture-review-2026-08-20-round7.md` | 第四之二節標題與前言、新增探針 D 小節、殘留清單 #1/#2 劃掉、「實測待辦」表加 D 列並改標題為四支、結論節第 1 項改寫 |
| `prototypes/index.md` | 第七輪探針列:三支→四支、日期範圍、探針 D 結論 |

### 分工紀錄

`.gd` 檔(4 個)為 `godot-gdscript-specialist` 於 2026-08-20 中斷前的交付,**本次未修改任何一行**。`D.tscn`(6 行機械複製,檢查點原文已明文列為協調者步驟)、執行、log 歸檔、README/報告/index 回填由協調者完成。

### 下一步(取代原「中斷檢查點」)

**前置條件已解除,可直接進 `/architecture-decision` 修訂 ADR-0002(17 項)** —— R7E-6/R7E-4 兩項 BLOCKING + R7-P1/P2/P3 + R7E-2 的二選一裁決((a) 建構子預填 10 對空 list / (b) 讀取入口一律 `has()` 守衛)+ 其餘 11 項。其後為 ADR-0005 第四次修訂(R6-6~R6-13 八項 + 8 處 `pass` + 第 1151 行指示句 + 第 121 行 `Constraints`)。

---

## Session Extract — `/architecture-decision` ADR-0002 第四次修訂 2026-08-21

**處理第七輪 `/architecture-review` 的 17 項,全數寫入。** ADR-0002 **651 → 974 行**;registry **69 → 78 項**(ADR-0002 佔 **22**);連帶改 `design/gdd/affinity-data-pool.md` 第 60 行與 `.claude/docs/technical-preferences.md`。

### 使用者的四項裁決

| 項 | 裁決 |
|---|---|
| **R7E-2**(空配對讀取會中止) | `_records` 建構子預填 10 對;**`_death_marks` 刻意不預填**、一律 `has()` 守衛 —— 因為它的鍵存在本身就是「已陣亡」的語意 |
| **R7E-12**(`items` 公開可變) | 改私有 `_items` + `append()`/`size()`/`get_at()` 最小存取面 |
| **R7E-6 / R7E-5**(拒絕回報形狀) | 結果物件加 `rejection` 欄位,`SpeculativeRejection` 併入 `ReadRejection`,**四個簽章全部不再回傳 `Variant`** |
| **R7E-14**(`_reclaimed_tokens` 次要逾時) | **撤回**比例規則,改自足公式;**ADR-0002 維持 `Depends On: None`** |

### Step 5.5 雙軌覆核跑了兩輪,共抓出 15 項 BLOCKING/高 —— **12 項是草稿自己引入或漏掉的**

**第一輪**(`godot-gdscript-specialist` + `godot-specialist` 平行):11 BLOCKING/高 + 12 非阻塞。

- **架構軌最重要一項**:R7-P1 的修法**只補了 `append_record`**,`notify_death` 與四個讀取函數的同型 enum 參數零防線 —— 非法序數會踩缺鍵讀取而**當場中止**(比 R7E-4 的靜默寫錯更嚴重,因為讀取是每回合熱路徑),且 `DeathNotifyResult`/`ReadRejection` 都沒有能容身的值
- **兩軌獨立收斂**:哨兵值清單混淆了兩個結果類別(`AffinityReadResult` 沒有 `c_now`、`ShapeFeatureResult` 沒有 `value`,且後者專屬 5 個欄位完全沒交代)
- **GDScript 軌**:`value = 0.0` / `diagnostic_visited_count = 0` **違反草稿自己寫的哨兵原則**(淨值相消本來就可能是 `0.0`)→ 改 `NAN` / `-1`;清單**漏了 `AffinityRecord.from_dict()`**(公開靜態方法,可繞過兩段式契約);機制四的「實作提醒」在預填生效後**自相矛盾**;`AffinityRecordList` 在 ADR 裡**被定義了兩次**
- **架構軌**:**Key Interfaces 整節完全沒被草稿改到** —— 那是 ADR 自稱「定案的契約形狀」的權威摘要,只改內文等於沒關 R7E-12 與 R7E-5;變更九的推導鏈**自我矛盾**且替 ADR-0004 開了一張它不知道的帳單(**C7 同形,而同一份草稿才剛修好 C7**)

**協調者自行 grep 核實**(不接受任何一份清單):範圍宣告**連續被低估三次** —— 第一版「機制二/四/八所有 `.items`」= 4 處 → 第二版經覆核 17 處 → grep 實測**約 30 處**。並抓到**兩軌都不可能抓到的一項**:**修正 A 讓 ADR 第 238 行「兩條規則都不改變任何既有簽章」變成假話** —— 該句逐字點名 `can_write`,而修正 A 改了它的回傳型別。**「修法讓某個既有宣稱變得不成立」第八次,且這次是在同一份草稿內由自己的修正造成。**

**第二輪**(窄範圍,只驗覆核後才產生的修正 A/H):再抓 4 項。

- **兩軌獨立收斂**:`can_write() -> WriteRejection` 有 **3 個**結構上不可達的值,不是 1 個 —— `ZERO_AMPLITUDE`/`NON_FINITE_AMPLITUDE` 依賴 `m`,而 `can_write()` **沒有 `m` 參數**。與 R7E-5 同形,而本次修訂正在消滅那個形狀
- **架構軌**:`pair_of()` 是**第 8 個**帶 enum 參數的入口,且**唯一無拒絕通道**者(回傳裸 `Pair`,不可為 null)。已排除改回傳 `Variant`(違反本次方向)、`Pair.INVALID = -1`(會讓 `values().has(-1)` 判為合法、自毀修法)、`push_error()` + 哨兵(違反 Constraints)。**採用:三個驗證器改為 `AffinityTypes` 上的公開靜態函式 + `pair_of()` 明文前置條件 + forbidden pattern**,並誠實聲明**第 8 個入口不與前 7 個同級保護**
- **GDScript 軌 B7 推翻了一項宣稱**:FIFO 在 `Dictionary[int, bool]` 上**不是「少一條路徑」**。三層理由,**第三層是協調者完全沒想到的** —— 權杖移入 `_reclaimed_tokens` 的時點是「逾時掃描發現它」的時點,**不等於 token id 的大小順序**(先發放的可能因操作較久而更晚被掃進來),故連「用 key 數值大小近似最舊」也不成立。已改採明確的 `_reclaimed_token_order: Array[int]`,並把宣稱改寫為「**換掉**一條路徑」。**選這條路的理由與機制七的取鎖模式同一個手法**:讓正確性完全不依賴未查證的 `Dictionary` 迭代順序,因此那個未查證項不需成為本 ADR 的依賴
- **架構軌 N1**:`can_write` 在 registry **零命中** —— 機制九的裁決從一開始就沒被登記過,故 registry 影響的動詞應為「**新增**」而非「就地修訂」

### 本次誠實登記、不假裝已解決的項目

1. **VR #9**(`match typeof(x)` 對 `TYPE_NIL` 的比對)、**VR #11**(型別化 `Array` 越界索引 —— 四支探針零覆蓋,**不得沿用探針 A 對 `Dictionary` 的結論**)、**VR #12**(`var_to_bytes()` 型別保真 —— **歸屬 ADR-0003**,本 ADR 只登記依賴)
2. **C7 只關本 ADR 這一半**,另一半需 ADR-0005 第四次修訂
3. **機制七對 `TOKEN_TIMEOUT_MS` 的引用是 `Depends On: None` 的既存例外**(C1 舊帳,本次裁決範圍不含它)—— 已明文標註,避免下一輪誤讀為新引入的依賴
4. **`pair_of()` 是呼叫端義務,不是結構保證**;**序數驗證有兩條實作路徑**(公開靜態 vs 內部讀快取),刻意接受,只以測試補償
5. **`_items` 私有化不是結構保證** —— GDScript 無真正的私有成員,ADR 明文不宣稱達到據以拒絕 Alternative 7 的那個標準
6. ⚠️ **修正 A/H 是第一輪覆核之後才產生的機制變更**;第二輪雖已窄範圍重驗,但**第二輪的修法(公開驗證器、`_reclaimed_token_order`、可達性表)本身未再經覆核** —— 依本專案八輪經驗,這是新缺陷最可能藏身處,**已列為第八輪的優先查核點**

### 下一步

1. **ADR-0005 第四次修訂** —— R6-6~R6-13 八項 + 8 處 `pass` 主體 + 第 1151 行指示句 + 第 121 行 `Constraints` 的「無 Godot 執行環境」+ VR #1/#3/#12/#15 標已查證。可合併成一次
2. **ADR-0004** —— 5 處 `pass` + 第 71 行指示句 + VR #6/#6a 標已查證;**ADR-0003** —— 第 17 行「無 Godot 執行環境」刪除
3. **C7 的另一半**(ADR-0005 側)
4. **建立 `docs/consistency-failures.md`** —— 自第三輪起**第六次**提出。八輪累積:自陳膨脹 ×1、修法引入新缺陷 ×5、散文改了但結構化欄位沒跟上 ×5、「只修了觸發我注意的那一處」×9(本次 +1)
5. **全新 session 跑第八輪 `/architecture-review`**(不得與本 session 同一個)

---

## Session Extract — `/architecture-decision` ADR-0005 第四次修訂 2026-08-21

**R6-6~R6-13 八項全數處理 + 五項事實層。** ADR-0005 **1440 → 1600 行**;registry **78 → 81 項**(ADR-0005 佔 **29**)。

### 使用者的兩項裁決

- **R6-7 的訊號形狀**:沿用 `target_changed()`,明訂 `is_valid` 翻轉也算改變(**不**新增 `target_validity_changed()`)—— 契約寬度不增加;代價是只想監測有效性變化的下游要自己 diff
- **Step 5.5 雙軌覆核**:授權

### 機制層面的實質變更

| 項 | 修法 |
|---|---|
| **R6-6** | 刪除 `handoff_before_unload()` 的懸空 `surface` 參數(4 處)。**不**新增 `SURFACE_MISMATCH` —— 甲分支的呼叫時機是「舊表面拆除前」,呼叫方本來就知道在拆哪一個 |
| **R6-7** | `equals()` 定案**只比表面 + `id`**(保住 `mark_pending_reresolve(expected)` 的競態語意 —— 若 `is_valid` 參與比較,該入口會**恆回 `STALE_NOT_APPLIED`**);`is_valid` 翻轉納入 `target_changed()` |
| **R6-8 + R6-9** | CanvasLayer 下**拆三節點**(待機指示器 / 自繪游標〔**唯一**承載 `modulate.a`〕/ hover 判定器),三者同為呈現層**一個角色的三個實例**、彼此無定序需求 → 同值 50 不違反「兩兩相異」,因為該規則依 R6-9 只管**角色之間** |
| **R6-10** | 閘門反方向失敗改記 `_pending_reseed` 旗標,由當前公開入口在清 `_mutation_in_progress` **之前**經 `_drain_pending_reseed()` 補做。另補明文說明 `suspend`/`resume` 的閘門不對稱**是刻意的** |
| **R6-11** | provider 失效由「座標層 fallback」升為**系統層降級**(`evaluate()` 整段跳過 + `push_error()` 恰一次 + 保留診斷計數)。**VC #18 改寫** —— 它原本把「凍結」斷言為期望結果 |
| **R6-12** | `process_priority` 必須在 `add_child()` **之前**(成本為零,故列強制寫法而非建議 —— 直接消掉一個印象等級的引擎依賴) |
| **R6-13** | 第二張登記表拆出 `ExceptionRegisterResult`(4 值)+ `tree_exited` 自動反登記 |

**私有路徑 4 → 6**(`_target_changed_from()` + `_drain_pending_reseed()`)。

### 五項事實層

8 處 `@abstract func ...: pass` 改**裸簽章** —— 並**同時改掉根因的指示句**(它原本明文寫「本專案唯一已查證的 `@abstract` 範例採冒號 + `pass` 形式,**下方沿用該形式**」,而那個範例本身是錯的;只刪 `pass` 不改那句,下一個實作者會照著加回來)。`Constraints` 的「**無 Godot 執行環境可供實機驗證**」刪除。VR #12/#15 標已查證(#1/#3 維持未查證)。**C7 的另一半** —— 本 ADR 自己認定依賴層 B,不再被 ADR-0002 單方面記帳。**R6-1 的 −50 計數落差已關閉**。

### Step 5.5 雙軌:2 BLOCKING + 11 非阻塞,並關閉草稿自標的全部 3 處「需覆核」

- **B-1(GDScript 軌)** —— 變更六寫了「provider 無效時 `evaluate()` 整段跳過」的**行為**,但 `_safe_mouse_position() -> Vector2` 失效時回傳陳舊座標,**呼叫方結構上無從得知**。**與 R6-6 懸空參數、R5-1 無合法呼叫路徑同型:寫了行為,沒寫接線。** 已改為在 `arbitrate_device_authority()` 內前置檢查 `_mouse_position_provider.is_valid()`;`_safe_mouse_position()` 自己的契約**不動**(它的其他呼叫點是一次性播種,無永久鎖死的病理)
- **B-2(架構軌)** —— 變更二與變更五各需一個共用私有方法,使全文**至少 7 處**「四條私有路徑」的宣告當場失效。**協調者另發現其中第 705 行的「三者」在本次修訂之前就已與第 774 行的「四個」不一致** —— 第三次修訂把私有路徑由一擴為四時漏改那一處
- **架構軌另抓到 registry 的既有缺陷**:`cursor_target_write` 的 `signal_signature:` 欄仍寫「PUBLIC GATED ENTRIES (**5**)」且遺漏兩個第三次修訂新增的入口,而同條目的散文已寫「SEVEN」—— **兩處自相矛盾,第七輪的 registry 對帳是逐節「數量」核對而非逐欄「內容」核對,所以漏網**
- **變更三只修了自己點名的 4 處中的 2.5 處**(942 的「同一節點」在三節點方案下是事實錯誤、1391 的「至多 2 個繪製元素」)—— 已補
- **待機指示器的資料來源未定義**(`CursorState` 裡沒有任何 idle 概念的欄位)—— 不是本次拆分造成,但拆分前被「同一節點」措辭蓋住了。**已誠實登記為下一輪缺口,不臆造欄位**

### ⚠️ 一項我自己的判斷被推翻(值得記住的檢索紀律)

VR #15 我草稿寫「在四支探針的 log 裡找不到這項量測,不自行標為已查證」。**量測其實做過了** —— 在更早那批 `engine-verification-spike-2026-08-20`,C2 段的標頭逐字寫「來源:ADR-0005 VR #15 / S-1 / 發現 G」。我搜的是 `xcheck-round7` 那四支,**搜錯批次**。已獨立核實 log 確認。結論比原本要驗的問題更有價值:

- 具名綁定與 lambda 的 `is_valid()` **行為一致**(皆 `false`)→ **「發現 G」的前提被推翻**
- 對已釋放物件呼叫 `.call()` **讓所在函式整段中止**(中止範圍只到直接呼叫的函式,不往上傳播)→ **S-1 的 `is_valid()` 守衛從「防禦性冗餘」升格為「必需」**

**教訓**:「未查證」在多批探針並存時容易被誤讀成「哪一批都沒測」,實際可能是「你查的那批沒測、另一批測過」。已寫進 ADR-0005 的 `Constraints`。

### 另一項不成立的疑慮

我擔心 `push_error()` 在 release 建置被編掉會讓 R6-11 的修法退回「靜默」。**`push_error()` 不是 `assert()`** —— 後者在 release 被剝離(那是設計目的),前者是一般執行期呼叫、不受建置影響,且不會讓函式中止。(印象-高信心,本專案未查證,參考庫零命中。)

### 誠實登記、未關閉的

`tree_exited` 必發生於 `queue_free()` 路徑(印象-高信心,三批探針與參考庫皆零命中)、`push_error()` 不受 release 剝離(同上)、對已釋放物件呼叫 **`connect()`** 是否同樣中止(只測過 `.call()`,屬外推)、**以 `add_child`/`remove_child` 管理生命週期的例外表面會靜默失去例外資格**(失敗方向在安全側,但 AC-60 便利性會無聲失效 —— 已明文寫下假設)、待機指示器資料來源、ADR-0005 名下另約 15 個未被觸及的 registry 條目是否間接過期、VC 19 項未逐條重驗斷言用詞。

### 下一步

1. ~~**ADR-0004** —— 5 處 `pass` + 第 71 行指示句 + VR #6/#6a~~ **✅ 2026-08-21 完成**,見下方最末節
2. ~~**ADR-0003** —— 第 17 行「無 Godot 執行環境」刪除~~ **✅ 2026-08-21 完成**(HIGH 評級維持,理由收為兩項)
3. **全新 session 跑第八輪 `/architecture-review`** —— 優先查核點:ADR-0002 的修正 A/H、ADR-0005 的 B-1/B-2 修法(皆為 Step 5.5 之後才產生的機制變更)、`can_write()` 與 `handoff_before_unload()` 兩處簽章變更、待機指示器缺口。**2026-08-21 追加**:ADR-0004 機制一新增的「編譯期保證」段落及其範圍界線是否被後續讀者擴讀為「不可能被實例化」、ADR-0004 VR #6b(三條間接構造路徑)、以及**過度宣稱是否還有第七處**(本次已找到第五、六處,而第五輪那句「四處全數清除」證明前一輪的清除宣稱不可信)
4. ~~**建立 `docs/consistency-failures.md`**~~ —— **✅ 2026-08-21 已建立**(264 行,7 個模式 A~G + 8 個逐筆 CONFLICT 條目)。格式已驗證可被那五個 skill 消費:條目標頭符合 spec、五個必要欄位各 8 次、檔頭逐字沿用 `consistency-check` 樣板。已登記進 `docs/CLAUDE.md`。

   **建檔時的第一個發現:既有彙總計數不可對帳。** 第五輪報告記「自陳膨脹 ×3」,第六、七輪記「×1」—— 同一個量在相鄰兩輪之間**減少了**,而沒有任何一輪列出構成那個數字的實例。四輪的四組數字互相矛盾。**故本檔不採信任何既有彙總數**,只列得出出處的實例,並以「發生場次」為計數單位(那才是 `CLAUDE.md` 既有措辭「第八次」實際在數的東西);早期差額明文登記為無法對帳、不予推測補齊。**我先前寫進本檔的 ×8 / ×7 / ×11 / ×3 亦屬同一類未逐筆化的數字,已被本次逐筆化取代。**

   **實測結果**:模式 A(修法引入新缺陷)**8 場**、模式 B(結構化欄位沒跟上)**至少 9 個實例**、模式 C(只修觸發注意那處)**至少 9 個**、模式 D(全稱定義域小於措辭)**至少 4 個**、模式 E(自陳膨脹)**1 場,已有結構性對策**、模式 F(證據等級混淆)**6 個**、模式 G(跨 ADR 記帳失效)**2 個,解法已實證**。**模式 E 與 G 是目前唯二有結構性解法的**:E 靠「修訂不得自陳涵蓋分佈」、G 靠「registry 條目 + 雙向 `referenced_by`」。

---

## Session Extract — ADR-0004 / 0003 / 0002 事實層修訂(2026-08-21)

**零決策內容**:不改任何機制、簽章、介面語意或風險評級。7 項計畫 + Step 5.5 衍生 3 項 + 協調者自行抓到 2 項,共 12 項處理完畢。

### 先測後寫:探針 E

ADR-0004 機制一第 91 行 `read_file(path: String) -> Variant` 的回傳型別**不在 2026-08-20 已測的五種之內**,ADR 對它純屬外推。**沒有先測就直接改,等於用一個未驗證的假設去關閉一個未驗證項。** 探針 E(`prototypes/xcheck-round7-2026-08-20/`,exit 0,執行者 `godot-gdscript-specialist`):

| 測項 | 結果 |
|---|---|
| E1 `-> Variant` 裸簽章 | `COMPILED OK`(第 6 種) |
| E2 `-> String` / `-> PackedByteArray` | 皆 `COMPILED OK`(第 7、8 種) |
| **E3 機制一 `SaveIOBackend` 逐字組合** | `COMPILED OK` —— **本探針主要價值**,各型別分別通過 ≠ 該組合通過 |
| E4 具體子類別完整實作五方法 | 編譯 OK、可 `.new()`、`-> Variant` 兩分支正常、**含經抽象基底靜態型別的多型呼叫** |

**額外發現**:對 `@abstract` 類別以**字面 `ClassName.new()`** 構造是 `Parse Error: Cannot construct abstract class` —— **編譯期**,連寫在永不執行的分支上也擋。⚠️ **但只有這一條路徑已驗證**:`Object.new()`+`set_script()`、`load().new()`、`ClassDB` 三條間接路徑既無實測亦無反證,已登記 ADR-0004 VR #6b。**次要發現**:`is_abstract` 進 `.godot/global_script_class_cache.cfg` 結構化欄位(協調者獨立覆核)。**執行者自陳未做任何結構替換**,`class_name` 逐字照 ADR 寫法 —— 量測與 ADR 實際寫法零落差。

### Step 5.5(單軌 `godot-specialist`,使用者明文授權):零 BLOCKING,3 項可行動

1. **草稿遺漏(中)** —— registry `why:` 欄記著具體行號 `80/83/86/89/92`,而變更一刪掉那 5 行會讓其後全部位移。已改為描述性說明並**明說為何不留行號**(死行號掛在「CLOSED」註記底下,會被讀成「行號仍對得上現況」)。
2. **宣稱過強(高)** —— 「結構保證優於紀律要求」超出已驗證範圍。專家**誠實說明它只搭了空探針骨架、沒跑、不編造結果**。已收窄:明文限定在字面直接構造,三條間接路徑列 VR #6b。
3. **範圍外新發現(高)** —— ADR-0003:350 是「`TR-save-*` 全數覆蓋」的**第五處**,且是**唯一不在 ADR-0004 檔案內**者。第五輪曾核實並宣稱「該過度宣稱至此四處全數清除」,**但那四處全在 ADR-0004 自己檔內** —— 那句全稱宣稱的定義域小於它的措辭。**納入本次範圍而非留給下一輪**:同類、同一個已在改的檔案、一行的事。留著就正好是本專案記過 11 次的「只修了觸發我注意的那一處」。

### 協調者自行抓到、兩軌都沒抓到的

- **第六處過度宣稱**:`design/gdd/systems-index.md:4` 寫「ADR-0002(**涵蓋全部 24 項** `TR-affinity-*`)」,與第七輪的 21/3/0 矛盾。**而同一行的 `TR-save-*` 部分早已修正為 22/7/1 並附修正註記** —— 同一行**只被修了一半**。
- **`prototypes/index.md` 自相矛盾**:同一格同時寫「四支獨立探針」與「**三支**皆 exit 0」。
- **用詞過強**:漏實作抽象方法的訊息實測是 `must implement "X" and other inherited abstract methods` —— **只指名其中一個**,不逐一列舉。registry 原寫 "naming the method",缺多個時就只點一個;已同步。
- **擴大搜尋確認範圍完整**:第七輪報告自陳「只搜了四種字串」。協調者以 14 種措辭重搜、專家另以一組不同措辭再搜,兩軌皆確認「無執行環境」殘留只有已知那三處。

### 寫入清單(9 個檔 + 探針 E 的 8 個新檔)

ADR-0004(5 處裸簽章 / 第 71 行根因 / 機制一新段落 / VR #6·#6a·#6b / 第 44 行 Constraints)、ADR-0003(第 17 行 + 第 350 行)、ADR-0002(第 603 行)、registry(`abstract_func_with_body` 就地修訂,**不新增條目**)、`technical-preferences.md`(第 54 行權威鏡像句 + ADR-0004 條目)、`systems-index.md`、探針 README、`prototypes/index.md`、本檔。

**registry 寫入後逐節重測:10 state / 11 interface / 29 api / 31 forbidden = 81,零重複鍵,與檔頭自陳一致。**

### 誠實登記、未關閉的

`@abstract` 的三條間接構造路徑(VR #6b,低優先 —— 會被誤寫的形狀已關閉)、ADR-0003 VR 五項全開(**性質已改**:從「無法查證」變成「尚未撰寫探針」,其中第 2 項 `bytes_to_var(bytes, false)` 是該 ADR 型別安全論證的地基,優先級最高)、ADR-0002 VR #4(`Mutex` 可重入)與 #7(release 建置容器驗證)、過度宣稱是否有第七處、`docs/consistency-failures.md` 仍未建立。

---

## Session Extract — 探針 F/G + ADR-0003 修訂草案 + Step 5.5 雙軌(2026-08-21)

**結論:草案未寫入。兩軌 Step 5.5 皆判 ❌ 不可寫入,6 項 BLOCKING,其中 4 項是草案自己引入的 —— 模式 A 第九場。**
⚠️ **草案本身在 scratchpad(session 專屬),下一個 session 讀不到。本節即是它的 durable 替代品。**

四支探針,全部 exit 0,引擎 `4.7.1.stable.official.a13da4feb` headless,未過濾 log 已提交:
`prototypes/xcheck-adr0003-2026-08-21/`(F、G 在 `logs/`;H 在 `xcheck-stepdotfive-2026-08-21/`;J 在 `xcheck-gdscript-shape-2026-08-21/`)。
提交:`324fb02`(F)、`27217ec`(G)、`aee86fc`(H+J)。

### ✅ ADR-0003 的決策實質成立(VR 五項全關)

格式選擇、分層結構、雜湊機制、manifest-only 安全前提**全部實測成立**。VR#2(型別安全論證的地基)三個子宣稱全中:原子性失敗、回傳 `null` **不中止呼叫函式**、伴隨 `ERR_UNAUTHORIZED`(引擎 C++ 斷言 `!p_allow_objects`,`marshalls.cpp:718`)→ **機制三步驟 5 可實作**。
VR#4 是最有利的一項:含 Object 的**毒區塊**塞進外層,外層仍解碼成功、manifest 完整可讀。
VR#5:64MB 線性無懸崖;單槽數十 KB 三項操作 < 2ms。VR#3 的 SHA-256 對照 `"hello"`/`"abc"` 標準答案逐字相符。

### 🔴 但寫法錯 18 處,且三項宣稱被推翻

- **B-1**:`bytes_to_var(buffer, false)` **兩引數形狀是 Parse Error**。ADR 全文 **18 處 / 16 行**(17、20×2、58、62、66、95×2、103、107、151、181、191、218、290、297、308、338),寫的是 **Godot 3 簽章**。4.7.1 是四個獨立全域函式:`var_to_bytes(v)`/`var_to_bytes_with_objects(v)`/`bytes_to_var(b)`/`bytes_to_var_with_objects(b)`。
- **B-2**:第 66 行的 `allow_objects` 縱深防禦論述**前提整體不成立**(沒有參數可傳)。須重寫,非刪字。
- **B-3**:VR#3a 的 `sha256_buffer()` 簡化機會**不適用** —— 只在 `String` 上,`PackedByteArray` 上不存在,而 ADR 的雜湊輸入正是後者。
- **根因**:`FileAccess.get_var(allow_objects)` **確實有此參數且預設 false**(探針 H-1 `ClassDB` 內省)。4.7.1 對同一件事有**兩種 API 形狀**,`FileAccess` 保留布林參數、全域函式拆變體。**這是 B-1 最可能被重新加回去的路徑,ADR 必須明文警示。**
- **參考庫零覆蓋**:`grep -rn "var_to_bytes|bytes_to_var|allow_objects|HashingContext|sha256" docs/engine-reference/` → **零命中**。與 `@abstract` 那次不同 —— 這次不是錯誤範例,是**完全沒有**。應建 `docs/engine-reference/godot/modules/core-serialization.md`。

### 🔴 N-1 + E1:「不能製造」≠「不能交出」(四條靜默管道)

| 管道 | 寫入側 | 讀取側(1 引數) | 危險度 |
|---|---|---|---|
| `EncodedObjectAsID` | plain `var_to_bytes()` 對任何 Object **靜默成功**(`RefCounted` 60B / `Resource` 56B,零錯誤) | `typeof=24`、**`is Object=true`**、欄位全 `<null>`;**`instance_from_id()` 同行程內可復活完整原物件** | 高 |
| `Signal` | 靜默成功,8 byte ObjectID 進流(44B) | **完整還原且可用** —— `connect()` 回 0、`emit(777)` 實測處理函式**真的執行**(`emit_count` 0→1) | **最高** |
| `RID` | 靜默成功 | 完整還原,`is_valid=true`、`get_id=94489280512` 逐位元相同 | 高 |
| `Callable` | 裸 Callable 只編 **4 bytes**(純型別標頭) | 型別還原、**綁定丟失**,`is_valid=false`;**誤呼中止呼叫函式**,且 `has()`/`is Callable` 兩守衛都通過 | 中 |

**鐵證:含 Callable 的 Dict,plain 與 `_with_objects` 編碼 48 bytes 逐位元組相同 —— 四者根本不經過閘門。**
**E1(第二輪提出、第三輪列 R3、懸置三輪)核心推理成立,但三項修正**:它舉的例子(驗證器 Callable 被還原)**不成立**;它**嚴重低估 `Signal`**(三者並列掩蓋了其中一個還原出全功能物件);它建議的修法(Validation Criteria 補一條)**不足**,應升級為格式層結構閘門。
**registry `resource_based_save_payload`(第 1544 行)的 `why:` 說 raw Resource「would fail to serialize at all」—— 實測為假**,靜默成功 56B、欄位全失。禁令保留,理由要改。

### 六項 BLOCKING(兩軌去重後)—— 修訂草案必須先關掉這些

1. **收窄後的核心宣告仍為假**:草案寫「拒絕實例化**任何** `Object` 衍生類別」,而 `EncodedObjectAsID` 實測 `is Object=true`,是 `bytes_to_var()` 親手實例化交出的。**「任何」又是紅旗字;收窄版本被它正在引用的同一批 log 否證。** 修法:改為「拒絕實例化任何**由腳本或 `ClassDB` 指名的**類別;唯一能產生的 Object 是引擎內建標記類別 `EncodedObjectAsID`,不帶腳本不帶欄位,只帶 8 byte ObjectID」。
2. **遞迴閘門無深度上限**:循環 payload 實測 **stack overflow + 1024 行 `Stack underflow! (Engine Bug)`**,回傳 `false` 是「中止後展開拿 `bool` 零值」的**意外正確**,極性反寫即 fail-open。**而主案的物件回傳型別讓它變糟**:物件零值是 `null`,呼叫端 `result.rejection` = null 取屬性 = **無聲中止**。**引擎自己反而有防護**(`marshalls.cpp:1363` `Potential infinite recursion detected. Bailing.` → size 0)。修法:`MAX_PAYLOAD_DEPTH`(64~128;實測合法深度 256 正常)+ 第三個列舉值 `DEPTH_EXCEEDED`。
3. **簽章變更的唯一理由為假**:草案寫「空 `PackedByteArray` 與『合法但空』不可分」;實測 `var_to_bytes({})`=**8B**、`var_to_bytes([])`=8B、`var_to_bytes(null)`=**4B**。**合法編碼最短 4 bytes,永不為 0** → `size()==0` 是可靠訊號,且**正是引擎自己的失敗訊號**。結論可留(採主案),理由整條換掉。**同形雙胞胎草案沒抓到**:循環 → size 0 → 對空緩衝區算 SHA-256 得完全合法的 `e3b0c442…` → 頂層雜湊也對 → **寫出結構完整、雜湊全符、內容為空的存檔**,玩家載入時才發現資料沒了。必須加「`var_to_bytes()` 後斷言 `size() > 0`」。
4. **「層一」範圍宣告有兩個洞**(同一句話):(a) 漏掉 ADR **自己示意圖第 177 行**的**外層** `var_to_bytes()`,而 Key Interfaces 根本沒有承載它的函式 —— **R7E-6 完全重演,範圍宣告只稽核了我剛寫的東西**;(b) 「沒有參數可傳」這個全稱句對 `FileAccess.store_var(v, true)`/`get_var(false)` **不成立**,而 **ADR-0003:66 自己就寫著兩者「底層共用相同的 Variant 編碼/解碼核心邏輯(線格式相同)」**,且 ADR-0004 的 `SaveIOBackend` 正是被授權碰 `FileAccess` 的檔案(`ADR-0004:97` 已選擇不用 `store_var()`,但那是散文選擇、非登記禁令)。修法:禁令定義域改為「任何能把 Variant 編成位元組或解回 Variant 的入口」並**逐一列名六個**;**不要再寫數字**(ADR-0005 的「四條私有路徑」在至少 7 處失效就是這麼來的)。⚠️ `Marshalls.variant_to_base64()`/`base64_to_variant()` **未查證**,措辭用「包含但不限於」並登記待查。
5. **讀取側閘門的套用點未定,字面上可能什麼都攔不到**:機制二/三有**至少四個**編解碼點,而 VR#4 已實測**外層解碼不遞迴進區塊**。若閘門套在外層解碼,它看到的 `blocks` 值全是未解碼 `PackedByteArray` → **一個都攔不到**。修法:逐點指名(寫入側套第 3 點、讀取側套第 4 點即機制三步驟 5 之後)。
6. **「數學型別」四個字承載 16 個型別的命運**:實測 4.7.1 共 **39 個型別(0–38),`TYPE_MAX=39`**。草案逐一列名 19 + 拒絕 4,**剩 5–20 共 16 個全靠那四個字**,而 **`Color`(20) 在任何通常讀法下都不是數學型別**(`Projection`(19)/`Basis`(17)/`AABB`(16)/`Transform3D`(18) 同理)。**且已實測發生**:專家照那兩張表實作出來的是**黑名單**(4 個 `or` 條件),`Color`/`Transform3D`/`Projection` 通過**不是因為在白名單上,是因為不在黑名單上**。修法:允許表**逐一列名 35 個**;拒絕表改標題為「說明用,非實作依據」並明文「必須以允許集合 `has()` 為判準」;**加 `TYPE_MAX` 完整性斷言**(`允許 ∪ 拒絕 == 0..TYPE_MAX-1`,載入期或 CI)—— 先例是 ADR-0005 的 `UI_ACTION_UNCLASSIFIED`。**沒有這條,「未來新增型別預設被拒」只是願望。**

### 裁決(兩軌一致,方向確認)

- **A1 採主案**(`serialize_block() -> SerializeResult` 結果物件),**但必須附三條件**:深度上限 + `DEPTH_EXCEEDED`、`var_to_bytes()` 後斷言 `size() > 0`、型別閘門**另外公開**為可獨立呼叫的 `validate_payload_types()`(供遷移鏈重用)。備案單獨採用**不可辯護** —— 它與 ADR-0002 第四次修訂**剛新增**的禁令 `unvalidated_character_into_pair_of` 同形狀,同一波修訂裡一邊禁一邊採。
  形狀已實測可編譯:`class SerializeResult extends RefCounted:` 內部類別、欄位型別可為外層檔案層 enum、`static func -> SerializeResult` 成立、呼叫端寫 `SaveFormat.SerializeResult`。**與 ADR-0002 既有先例一致,不是第三種形狀。** 額外收益:內部類別**不進入全域命名空間**。
  ⚠️ 但 `typeof(r)`=24、`get_class()`=`"RefCounted"` 不是 `"SerializeResult"`;且結果物件自己**永遠不可進 payload**(會被自家閘門拒)。
- **A2 用既有 `DATA_CORRUPTED`,不新增值。** 理由**不是**草案寫的「語意上算損毀」,而是 **ADR-0003 第 50 行自己就這麼要求**;且新增值會迫使 ADR-0004(第 285–291 行**逐字複製了 `ReadRejection`**)同步 = 模式 B 第 10 個實例候選。⚠️ **草案漏了第 212 行** —— 那是 `DATA_CORRUPTED` 的**成因清單**註解,讀取側閘門是第四個成因,必須加進去。
- **A3 ADR-0004 不受影響**:`serialize_block`/`deserialize_block` 全專案僅 **3 處命中,全在 ADR-0003 自己檔內**。但須明文寫下交接點:`ADR-0004:81 write_temp(path, buffer: PackedByteArray)` 與 `:141 replace(slot, buffer: PackedByteArray)` 吃**裸 `PackedByteArray`**,改結果物件後**解包 `.buffer` 的義務歸呼叫方**;`ADR-0004:99` 維持成立。
- **D1 ADR-0002 不需要改,且 ADR-0003 不可替它記帳。** `validate_semantics()` 是**逐欄位正向白名單**(`adr-0002:640-643`:頂層恰含 3 鍵、`pair`/`source` 須 `TYPE_STRING`、`m` 嚴格 `TYPE_FLOAT`、`t`/`c` 嚴格 `TYPE_INT`…)—— **正向白名單天生免疫黑名單的漏列問題**,任何位置塞 Object/Signal/RID 都被該位置自己的檢查擋下,「多出來的鍵」被兩處「恰含 N 鍵」擋下。**覆蓋完整。** 草案「另需評估」那一句**就是 C7 的形狀,必須刪掉**,改為 ADR-0003 自我強化(機制六驗證器契約由「值域」補成「型別 + 值域」,ADR-0002 第 639 行早已是後者 —— **ADR-0003 定義通用契約卻比唯一實作弱**)。
- **B2 查證為不成立(非 BLOCKING)**:`AffinityDataPool.export_state()` 輸出**純 `Dictionary`**(`adr-0002:609-613`),`AffinityRecordList` 只是 `_records` 的**內部**容器、不跨 export 邊界。真正風險點是**手寫的 `to_dict()`** 未來加欄位時漏手 —— 寫入側閘門正是對這件事的防線。

### 高:必須同批處理

- **D 的三項補充(N-3 不足)**:①**`start()` 的 `ERR_ALREADY_IN_USE(22)` 必須當致命錯誤** —— 跨區塊重用 `HashingContext` 而忘了 `finish()`,實測得到「前一區塊 ‖ 本區塊」的雜湊,而**長度是正確的 32 bytes**(實測 `"abc"`+`"abc"` → `bbb59da3af939f7af5f360f2ceb80a496e3bae1cd87dde426db0ae40677e1c2c`,協調者以 `sha256sum` 獨立核實 = `sha256("abcabc")`)。**草案的 `size()==32` 斷言完全擋不住它,只有檢查 `start()` 的 `Error` 擋得住。兩條規則不是二選一的縱深防禦,是各擋不同的一種失敗。** ②**`update(空陣列)` 回傳 `FAILED(1)`**,而空分段**不是損壞** —— 草案的規則會誤判為 `DATA_CORRUPTED`(假損傷)。須先斷言 `chunk.size() > 0`、零長度跳過,並把 `FAILED(1)` 與 `ERR_UNCONFIGURED(3)`/`ERR_ALREADY_IN_USE(22)` 分開處理。③**`finish()` 會銷毀 context**(之後 `update()` 回 err=3),須寫出來。
- **E4 讀取側簽章不對稱,方向與同日先例相反**:`deserialize_block(buffer) -> Variant # Dictionary 或 null` 修訂後有**三種**失敗塌成同一個 `null`(引擎解碼失敗、解出合法非 Dictionary、新增的讀取側閘門拒絕)。而 **ADR-0002 第四次修訂(同一天)剛把這形狀判為 BLOCKING 並全數移除**(`:460`、`:15`「四個簽章全部不再回傳 `Variant`」)。ADR-0003 另有三處同形狀:`:140`/`:231`(`get_validator() -> Variant`)、`:238-242`(`read_manifest_only`/`read_block`)。**草案正在編輯這個介面區塊卻只改一半** —— 須裁決:一併改為 `DeserializeResult`,或明文寫「刻意不改,理由 X」並登記銜接缺口。**現狀是第三種:沒有討論。**
- **E5 enum 欄位不擋非法值**:`r.rejection = 1.7`(float **字面量**)→ Parse Error;`= 7`(越界 int 字面量)→ **編譯通過**,存 7,兩個 `==` 比較皆 false → `match` 兩分支**靜默落空**;經無型別 `Variant` 持有 `1.7` → **靜默截斷為 1**。**「編譯期會擋」只對字面量成立**;第三列是 R7E-4 同形狀,但**這次量的是內部類別的欄位而非函式參數**,是新觀測點。修法:寫出預設值 `= PayloadRejection.NONE`(沿用 `adr-0002:416`)+ Validation Criteria 加呼叫端義務(`adr-0002:526` 有逐字可沿用的措辭)。
- **H-1 Consequences → Positive 第 1 點(第 281 行)與新機制直接矛盾**:「型別白名單不是靠維護清單實現,而是格式選擇的結構性副產品」—— 機制一之二**正是一張要維護的清單**。須拆兩句:**類別實例化**白名單仍是結構性副產品(不變);**Variant 型別**白名單是本次新增、非零的維護義務。
- **H-2 Architecture Diagram 除呼叫形狀外還缺兩處**:(a) 第 161 行 `export_state() → var_to_bytes(payload)` 之間**沒有閘門方塊**;(b) 第 191–192 行「④`bytes_to_var(...)` 解碼(**= 型別白名單閘門**)」—— 修訂後它**已不再是**完整閘門,那個括號**變成假的**。
- **H-3** 機制三步驟 5(第 107 行)**沒有安放讀取側閘門**;**H-4** 與 Requirements 第 3 項(第 50 行)「此閘門必須**先於反序列化本身**生效」**字面衝突**(讀取側閘門在 `bytes_to_var()` 回傳**之後**)—— 須明文和解:引擎層拒絕實例化才是「先於」那道;遞迴閘門是**事後的縱深濾網**。不寫這段,文件內部即互斥。
- **H-5** 機制七(第 151 行,Open Question 4)推導鏈斷了:「從不產生任何自訂 Object,因此**不存在「型別」這個維度**需要按版本分域」—— 修訂後**存在**。須明文:新白名單是**格式層的 Variant 型別集合,刻意不依規則集版本分域**。否則 OQ4 被重新打開而無人知。
- **H-6** `TR-save-028`(第 318 行)部分為假:保護來自新閘門,不來自格式選擇。**草案改了 registry 的同一句話卻漏了 ADR 內這一句 —— 模式 C。**
- **H-7** 第 66 行「不含任何**自訂** `Object`/`Resource`」—— **「自訂」二字現在是錯的**(內建 `Resource.new()` 與自訂子類別行為完全一致;`Signal`/`RID` 根本不是 Object)。
- **H-9** Performance Implications(320–324 行)**完全沒提閘門成本**,而該節現行寫「可忽略」。**探針 F 的 F5 量的是引擎成本,不能用來推論閘門成本。**
- **H-10** Validation Criteria **沒有一條驗證新閘門**。須加六類毒藥向量(值為 Object / **鍵**為 Object / Signal / RID / Callable / 循環引用)× 兩側 × 巢狀深度。
- **H-11** 機制六驗證器契約(第 138 行)只寫「值域」,漏「型別」,而 ADR-0002 第 639 行早已是「型別 + 值域」。

### 閘門成本(實測,草案零數字)

| payload | 編碼後 | 寫入閘門 | `var_to_bytes` | `bytes_to_var` | 讀取閘門 | 閘門佔比 |
|---|---|---|---|---|---|---|
| **500 筆(GDD 估計規模)** | 52.1 KB | **1.9 ms** | 0.6 ms | 0.6 ms | **1.9 ms** | ~76% |
| 100,000 筆 | 10.4 MB | 435.5 ms | 132.1 ms | 171.5 ms | 391.0 ms | ~73% |
| 500,000 筆 | 52.0 MB | 2028.4 ms | 822.3 ms | 1669.6 ms | 3387.8 ms | ~68% |

**閘門約為引擎 C++ 編解碼的 3 倍。** GDD 規模下總計由 < 2ms 變 ~5ms,可接受(非每幀路徑)。⚠️ 大規模時**讀取側比寫入側更貴**(3388 vs 2028 ms),**成因未查證,只記現象**。這些數字是覆核者為量測寫的一版,**不是規格值**,只支撐「同一量級、約 3 倍」。

### 中/低(清單,詳見兩軌報告)

B1 鍵側規則須補一句(**`Dictionary` 以 Object 當鍵實測可往返**,`registry:1511` 的 `mutable_container_as_dictionary_key` **不覆蓋它**;建議鍵只允許 `STRING`/`STRING_NAME`/`INT`)、B3 `typeof()` 無法區分 typed/untyped **但閘門不需區分**(typed 往返後**保留**,`get_typed_builtin()=2`)、C2 指名 `DATA_CORRUPTED`、E6 `rejection` 預設 0 = 成功(與 ADR-0002 `AffinityReadResult` 同性質,不改慣例但須明寫)、E7 驗證器 `Callable` 呼叫前須 `is_valid()`(⚠️ **會繼承 ADR-0005 發現 G 的未查證項**,不可靜默押上)、E8 `offending_path` 成本與格式未定**且草案例子筆誤**(`records/0/source_i` → 欄位名是 `source`)、E9 `PayloadRejection` 應一次定完 4 值、E10 內部類別不佔全域命名空間(正面點)、M-1~M-9(Knowledge Risk 敘事過期、HIGH 評級須明文維持理由、`Post-Cutoff APIs Used` 須註明 **B-1 不是後截止失敗** —— `allow_objects` 拆分發生在 Godot **4.0**(pre-cutoff),真正來源是**過期的 Godot 3 記憶**,而本 ADR 整套風險框架只防「後截止」、機制四步驟 5 的 `DATA_CORRUPTED` 在寫入側是錯的分類、M-6 第 220 行括號例子已死、M-9 registry 1559–1560 的 type-instantiation 措辭)。

### 範圍:連帶檔案 7 個(**registry 是 4 處不是 3 處**)

`adr-0003`(18 + 3)、**`registry` 4 處**(764 `api:` 逐字寫著不存在的簽章、771 `reason:`、**1552–1553 `why:` 第一句** ←草案漏掉,**就在它已指名要改的 1558–1559 上面 6 行、同一個 YAML 欄位裡**、1559–1560)、`traceability-index:123`、`technical-preferences:106`、`systems-index:4,157`、`adr-0002:657`。
**另兩個 `revised:` 欄** —— `save_serialization_format` 第 **780** 行是 `revised: ""` 空字串待填;`resource_based_save_payload` **根本沒有 `revised:` 這個鍵**,須新增。**這是模式 B 第三次重犯。**
**排除**:`session-logs/`(gitignored 稽核軌跡)、**恰好 3 份**帶日期的 `architecture-review-*.md`、`save-system.md:706`(**實測確認正確** —— H-1 `ClassDB` 內省證實 `FileAccess.get_var(allow_objects) default_args=[false]`)。`active.md:820`/`:1146` 建議排除但**須寫下理由**(時點快照)。

### 下一步

0. 🔴 **下次必須以 `/architecture-decision --review full` 呼叫(2026-08-21 使用者裁決)。** 原因:`production/review-mode.txt` **從未建立**,依 `director-gates.md:56` 預設 `lean`,而 `lean` 會跳過所有非 PHASE-GATE 的 per-skill 閘門 —— 包含 **`TD-ADR`(technical-director 的架構一致性覆核)**。結果是五份 ADR 的撰寫與九次修訂期間 `TD-ADR` **一次都沒跑過**;而本次草案 6 項 BLOCKING 中的 4 項,性質全部落在 `TD-ADR` 的職責而非引擎專家的職責。⚠️ **使用者明文選擇不建立 `review-mode.txt`**(不想讓每次 skill 都多付一輪成本),改為**逐次**在高風險修訂上加 `--review full`。已登記為 `docs/consistency-failures.md` 第 9 則(該處的**文件矛盾本身仍開**:`director-gates.md:802` 的 Required 與 `lean` 規則尚未調和)。
1. **修訂草案**(六項 BLOCKING → 「數學型別」逐一列名 + `TYPE_MAX` 斷言 → 刪替 ADR-0002 記帳那句 → 高級約 15 項 → registry 第 4 處 + 兩個 `revised:` 欄)。⚠️ **草案在 scratchpad,新 session 需依本節重建。**
2. **修完必須重跑窄範圍 Step 5.5** —— 第一軌明文警告:BLOCKING #2(深度上限 + 第三列舉值)與 #4(新增兩個 manifest 層函式)是**覆核後才產生的機制變更**,正落在同一個陷阱的正下方。ADR-0002 第四次修訂的第二輪窄覆核就**又抓到 4 項,全部出自第一輪覆核後才產生的那兩項變更**。
3. **建 `docs/engine-reference/godot/modules/core-serialization.md`** —— 探針 F/G/H/J 現有 39 個型別、完整簽章、`TYPE_MAX`、效能數字、`HashingContext` 全部失敗模式。**不建,下一個 ADR 作者會踩同一個 Godot 3 記憶。**
4. **C8 候選(範圍外,勿靜默省略)**:ADR-0002 的 `:747`/`:895`(三個結果類別為**獨立 `class_name`**、計入七個全域名稱)與 `:415-430`(欄位型別為**巢狀於 `AffinityDataPool` 的** enum)**同時主張兩者,而前者讀法實測不編譯**(`Parse Error: Could not find type "ReadRejection" in the current scope.`)。只能選一。另 `ImportResult` **全 ADR-0002 無任何宣告**,只作為回傳型別出現 6 次,而 ADR-0003 機制六消費它。
5. **仍未查證**:跨行程 `Signal`/`RID`/`EncodedObjectAsID`(VR#6,**不阻擋機制一之二的決策** —— 不論答案為何寫入側都須拒絕,但**須在任何存檔 story 進實作前關閉**)、release 建置(VR#7,與 ADR-0002 VR#7 同一個洞,**可一次關三份**)、`Marshalls.variant_to_base64()` 存在性與 arity、引擎遞迴 bail 的確切深度門檻、讀取側閘門大規模時較貴的成因。
6. 第八輪 `/architecture-review` **仍未跑**(本 session 原定 A → B,B 未執行)。**優先查核點須加上 ADR-0003 本次修訂。**

### 方法論教訓(三項,值得進 `docs/consistency-failures.md`)

1. **「收窄宣稱到實測範圍」本身也會出錯** —— BLOCKING #1:收窄後的版本被它正在引用的同一批 log 否證。收窄不等於安全,收窄後仍須逐字回頭對證據。
2. **「比較輸入與輸出」的斷言,在輸入本身就錯時仍會通過** —— 探針 F 第一版浮點測試 13 列全綠,而兩個向量的輸入位元與 `-0.0` 相同,根本沒測到宣稱在測的東西。位元級測試必須額外斷言「輸入確實等於指定位元」。
3. **一句宣示擋不住一張表的結構誘導** —— 草案明寫「白名單制,非黑名單」,但同時給了一張結構完整、可直接轉成 4 個 `or` 的拒絕表,而允許側有一格是無法逐一比對的散文詞。**照著實作最省力的路就是黑名單,而覆核者實測寫出來的就是黑名單。**
