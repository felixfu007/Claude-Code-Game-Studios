# Active Session State

<!-- STATUS -->
Epic: 架構階段(Foundation + Core 層 ADR 系列)
Feature: 單一游標/高亮狀態系統
Task: ADR-0005 已完成第三次修訂(約定為最後一次全面修訂;R5-1~R5-6 + S-1~S-5 + Step 5.5 新發現 A/B/2b/D/F/G,共 17 項);下一步為全新 session 跑第六輪 /architecture-review —— 範圍限縮為「這 17 項是否確實關閉」,不再全域重推 130 項需求
<!-- /STATUS -->

**最後更新**:2026-08-19 —— `/architecture-decision` **第三次修訂 ADR-0005**,處理第五輪 `/architecture-review` 的 R5-1~R5-6 與 S-1~S-5 共 11 項,並在寫入前先跑 `godot-specialist` Step 5.5 覆核(使用者明文授權),該覆核再抓出 6 項(其中 4 項是本次修法自己新產生的)。**R5-1 為 BLOCKING**。連帶修訂 ADR-0004(Validation Criteria 第 6/7 項順序,R5-4)、`docs/registry/architecture.yaml`(65 → 68 項)與 `.claude/docs/technical-preferences.md`。詳見下方「Session Extract — `/architecture-decision` 第三次修訂」。

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
| **ADR** | **5 份,全部 `Proposed`,無一 `Accepted`** |
| **架構登記處** | **68 項立場**(10 state-ownership、11 interface contracts、23 API decisions、24 forbidden patterns)—— 2026-08-19 第三次修訂後逐節實測。ADR-0005 佔 26 項(3/5/7/11) |
| **需求涵蓋** | 130 項 TR:**68 ✅ / 30 ⚠️ / 32 ❌**(第五輪 `/architecture-review` 判定);游標系統 15 ✅ / 4 ⚠️ / 0 ❌。**第三次修訂後的分佈未經獨立推導,待第六輪** |
| **最新審查判定** | **CONCERNS**(2026-08-19 第五輪)—— 第二輪 FAIL 的唯一成因(游標 19/19 零涵蓋)已解除。**32 項 ❌ 中 25 項在戰棋系統**,但該 GDD 尚未 Approved,故沿用第二輪標準不判 FAIL;⚠️ 若戰棋 GDD 先於其演算法層 ADR 達 Approved,判定退回 FAIL。三個 Foundation 層系統合計 73 項需求**僅 1 項缺口**(`TR-save-030` 雲端同步) |
| **實作** | `src/` 為空,尚無任何程式碼 |

### ⚠️ 兩個結構性阻擋(比任何單一缺口都重要)

1. **5 份 ADR 全為 `Proposed`。** 依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被**自動阻擋** —— 即使把剩餘 ADR 全寫完,也還不能進實作。**ADR-0002 是最接近可 `Accepted` 的一份**(24 項 `TR-affinity-*` 零缺口)。
2. **`/gate-check pre-production` 仍不可執行,但缺口性質已完全改變**(2026-08-19 實測):✅ `tests/unit/`、✅ `tests/integration/`、✅ `.github/workflows/tests.yml`(`/test-setup` 建立);⚠️ **`design/ux/accessibility-requirements.md` 一直都存在**(2026-08-06 建立)——**第一~五輪 `/architecture-review` 全部報「不存在」是查錯路徑**(查 `design/accessibility-requirements.md`,少了 `ux/`),框架側 17 處引用已於 2026-08-19 統一修正,該檔的 Tier 亦已定案為 **Standard**;✅ `design/ux/interaction-patterns.md` **已於 2026-08-19 由 `/ux-design patterns` 建立**(15 個模式)。**pre-gate 五項至此全部具備**——但 `/gate-check pre-production` 仍不保證通過:閘門另有 ADR `Accepted`、UX 規格覆蓋等條件,且本檔尚未經 `/ux-review` 驗證。**注意**:CI 目前帶一個暫時性守衛(`project.godot` 不存在時跳過並直接成功),綠燈**不代表測試通過**——移除條件寫在 `tests/README.md` 與 workflow 註解裡。

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

1. ~~全新 session 跑 `/architecture-review`~~ —— **✅ 第三、四輪皆已於 2026-08-19 完成**,兩輪皆判 CONCERNS。第三輪推翻 ADR-0005 自陳 16/3 為 11/8;第四輪重推為 13/6,並抓到「修法本身引入新缺陷」的新模式。**第五輪待跑(針對第二次修訂)。**
2. ~~全新 session 修 ADR-0005 的 9 項待修訂 + C1/C3/C6~~ —— **✅ 已於 2026-08-19 完成兩輪**(第一次修訂處理 F1~F5+N1~N4;第二次修訂處理第四輪的 R4-1~R4-7 + `-015` 兩項落差 + C1/C3/C6)。**下一步是全新 session 跑第五輪 `/architecture-review`。**
3. **`/test-setup`** —— 與架構軌零依賴,可平行推進;是 pre-gate 的硬需求(5 項中的 3 項)。
4. **`/ux-design`** —— pre-gate 剩餘 2 項(`accessibility-requirements.md`、`interaction-patterns.md`)。注意 `cursor-highlight-state.md` 已登記一項**孤兒義務**:運動無障礙需求(奪權門檻可調整性、瞄準輔助)先前口頭轉交至一個**不存在的檔案**。
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
4. `@abstract class_name Foo extends RefCounted` 最小檔案語法 —— **第三輪已部分關閉**:專家逐字比對 `current-best-practices.md` 第 41–49 行,ADR 的寫法格式一致,可從「印象」升級為「已查證」。**殘留**:文件範例只有 `Array[Attack]` 一種回傳型別,ADR 用到 `bool`/`float`/`void` 三種 —— spike 應**三種各建一檔分別編譯**,不是只測一種
5. **(第三輪新增)`_notification()` FOCUS_IN/OUT 相對 `process_priority` 的時序** —— 餵給 F5,現有 9 項 Verification Required 沒有這一項

> 第 2 項(Agile Flushing 鍵字串)第三輪已確認**參考庫 6 份文件全域零命中** —— `has_setting()` 防衛必須保留,不得改成信任推測鍵名。

### D. 其他未處理

- **R3(第二輪審查)**:ADR-0003 補一條 Validation Criteria(payload 建構路徑不得含 `Callable`/`Signal`/`RID` —— 它們不是 `Object` 衍生類,不受 `allow_objects=false` 管控);ADR-0002 的 Post-Cutoff 欄措辭易被誤讀為「不依賴 `Dictionary[K,V]`」。
- **戰棋系統文件自陳的下游阻擋項**:OQ-2 `player_baseline_stat` 全專案無擁有者;OQ-10 無「不可通行」地形層級;OQ-16 敵方單位數上限無擁有者 + 效能測試須以「格數 × 敵數」兩軸參數化。
- **戰棋系統 DEFER 未落地**:`enemy_advantage_pct < 0` 無驗證拒絕(與既有 `≥1.0` 拒絕不對稱,會靜默反轉 Core Rules #7);公式二 `ceil()` 浮點精度邊界噪聲。
- **戰棋系統收斂狀態**:連續零 BLOCKING-NOW 輪數 = **0**(四輪皆 body-scoped)。距 Approved 尚需**連續兩輪**零 BLOCKING-NOW。
- **`docs/consistency-failures.md` 不存在** —— 依 skill 規定未建立,故**三輪**審查的 C1~C6 只存在於各輪審查報告內,沒有跨輪的模式累積。
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
- **`@abstract` 語法可從「印象」升級為「已查證」** —— 與 `current-best-practices.md` 第 41–49 行範例逐字格式一致。殘留:範例只有 `Array[Attack]` 一種回傳型別,ADR 用到 `bool`/`float`/`void` 三種,Day-1 spike 應**三種各建一檔分別編譯**
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
