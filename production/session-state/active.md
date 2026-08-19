# Active Session State

<!-- STATUS -->
Epic: 架構階段(Foundation + Core 層 ADR 系列)
Feature: 單一游標/高亮狀態系統
Task: ADR-0005 已完成 F1~F5+N1~N4 全部 9 項修訂;下一步為全新 session 跑第四輪 /architecture-review 獨立驗證
<!-- /STATUS -->

**最後更新**:2026-08-19 —— `/architecture-decision` 修訂 ADR-0005,處理第三輪 `/architecture-review` 判定的全部 9 項待修訂(F1/F5 BLOCKING、F2/F3/F4、N1~N4)。**本次修訂尚未提交 git**。2026-08-18 的 3 個提交此前已推送完畢。

### 2026-08-19 ADR-0005 修訂摘要(本次工作)

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
| **架構登記處** | **55 項立場**(10 state-ownership、8 interface contracts、20 API decisions、17 forbidden patterns) |
| **需求涵蓋** | 130 項 TR:**61 ✅ / 34 ⚠️ / 35 ❌**(第三輪 `/architecture-review` 判定,已計入 ADR-0005) |
| **最新審查判定** | **CONCERNS**(2026-08-19 第三輪)—— 第二輪 FAIL 的唯一成因(游標 19/19 零涵蓋)已解除。**35 項 ❌ 中 25 項在戰棋系統**,但該 GDD 尚未 Approved,故沿用第二輪標準不判 FAIL;⚠️ 若戰棋 GDD 先於其演算法層 ADR 達 Approved,判定退回 FAIL |
| **實作** | `src/` 為空,尚無任何程式碼 |

### ⚠️ 兩個結構性阻擋(比任何單一缺口都重要)

1. **5 份 ADR 全為 `Proposed`。** 依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被**自動阻擋** —— 即使把剩餘 ADR 全寫完,也還不能進實作。**ADR-0002 是最接近可 `Accepted` 的一份**(24 項 `TR-affinity-*` 零缺口)。
2. **`/gate-check pre-production` 目前不可執行**,**五項** pre-gate 全缺(2026-08-19 實測確認):`tests/unit/`、`tests/integration/`、`.github/workflows/tests.yml`、`design/accessibility-requirements.md`、`design/ux/interaction-patterns.md`。

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

1. ~~全新 session 跑 `/architecture-review`~~ —— **✅ 已於 2026-08-19 完成**,判定 CONCERNS。ADR-0005 自陳 16/3 被推翻為 11/8,零缺口成立。見下方「Session Extract 第三輪」。
2. **全新 session 修 ADR-0005 的 9 項待修訂** —— **F1/F5 為 BLOCKING,修好前該 ADR 不得進 `Accepted`**。屬 `/architecture-decision` 領域。建議與 C1/C3/C6 一併處理(5 份 ADR 皆 `Proposed`,現在改動成本最低)。
3. **`/test-setup`** —— 與架構軌零依賴,可平行推進;是 pre-gate 的硬需求(5 項中的 3 項)。
4. **`/ux-design`** —— pre-gate 剩餘 2 項(`accessibility-requirements.md`、`interaction-patterns.md`)。注意 `cursor-highlight-state.md` 已登記一項**孤兒義務**:運動無障礙需求(奪權門檻可調整性、瞄準輔助)先前口頭轉交至一個**不存在的檔案**。
5. **剩餘 2 份 ADR**(第三輪判定此為投入產出比最高的單一動作 —— 第一項一次移動 35 項 ❌ 中的大部分):戰棋盤面演算法層(可達格/威脅範圍/視線,`TR-tactical-002`~`-010`、`-019`~`-021`、`-037`~`-039`);回合結構擁有權 + 缺席的 AI/遭遇系統(`TR-tactical-034`、`-041`)—— **全專案無人認領回合結構**,而 `tactical-combat-system.md` Core Rules #9 明文要求敵方回合消費這些查詢。

---

## 四、待處理清單

### A. 跨 ADR 銜接缺口(C2/C4/C5 已修;C1/C3 自第二輪仍開,C6 為第三輪新增)

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

- registry `state: mouse_reclaim_accumulator` 的 `interface:` 仍寫直綁 `modulate.a`(F3 已廢除),`revised:` 空白
- ADR-0005 Consequences 仍留「19 項全部有機制支撐(其中 3 項為部分)」的舊自陳
- `systems-index.md` 第 28 列游標 GDD 狀態維持 `Approved`
