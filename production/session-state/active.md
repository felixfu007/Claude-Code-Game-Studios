# Active Session State

<!-- STATUS -->
Epic: 架構階段(Foundation + Core 層 ADR 系列)
Feature: 單一游標/高亮狀態系統
Task: ADR-0005 已撰寫並提交;下一步為全新 session 跑 /architecture-review 驗證涵蓋
<!-- /STATUS -->

**最後更新**:2026-08-18 —— 本日三個 session 段落(第二輪 `/architecture-review` → forbidden pattern 補登 + C2/C4/C5 修正 → ADR-0005)。工作區乾淨,3 個提交待推送。

> **本檔案是現況快照,不是流水帳。** 歷史細節在 `docs/architecture/architecture-review-*.md`、`design/gdd/reviews/*.md` 與 git history;此處只保留「下一個 session 需要知道什麼」。

---

## 一、現況

| 項目 | 狀態 |
|---|---|
| **專案階段** | 架構階段(Technical Setup → Pre-Production 之間) |
| **GDD** | 4 份系統 GDD:好感度數值池、存檔系統、單一游標/高亮狀態系統 = **Approved**;戰棋移動與交戰系統 = **Designed,尚未 Approved** |
| **ADR** | **5 份,全部 `Proposed`,無一 `Accepted`** |
| **架構登記處** | **55 項立場**(10 state-ownership、8 interface contracts、20 API decisions、17 forbidden patterns) |
| **需求涵蓋** | 130 項 TR:**50 ✅ / 24 ⚠️ / 56 ❌**(第二輪 `/architecture-review` 判定,**未計入 ADR-0005**) |
| **最新審查判定** | **FAIL** —— 唯一硬阻塞為游標系統 19/19 零涵蓋,**該項已由 ADR-0005 處理,但尚未經獨立審查驗證** |
| **實作** | `src/` 為空,尚無任何程式碼 |

### ⚠️ 兩個結構性阻擋(比任何單一缺口都重要)

1. **5 份 ADR 全為 `Proposed`。** 依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被**自動阻擋** —— 即使把剩餘 ADR 全寫完,也還不能進實作。**ADR-0002 是最接近可 `Accepted` 的一份**(24 項 `TR-affinity-*` 零缺口)。
2. **`/gate-check pre-production` 目前不可執行**,四項 pre-gate 全缺:`tests/unit/`、`tests/integration/`、`.github/workflows/tests.yml`、`design/accessibility-requirements.md`、`design/ux/interaction-patterns.md`。

---

## 二、今日完成(3 個提交,已 commit 未 push)

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

1. **全新 session 跑 `/architecture-review`** —— 驗證 ADR-0005 對 19 項 `TR-cursor-*` 的涵蓋。**硬性規定:不得與 `/architecture-decision` 同 session**,審查代理必須獨立於撰寫脈絡。ADR-0005 自陳 16 完整 / 3 部分,**刻意不宣稱 19/19**,待獨立重推。
2. **`/test-setup`** —— 與架構軌零依賴,可平行推進;是 pre-gate 的硬需求(4 項中的 3 項)。
3. **`/ux-design`** —— pre-gate 剩餘 2 項(`accessibility-requirements.md`、`interaction-patterns.md`)。注意 `cursor-highlight-state.md` 已登記一項**孤兒義務**:運動無障礙需求(奪權門檻可調整性、瞄準輔助)先前口頭轉交至一個**不存在的檔案**。
4. **剩餘 2 份 ADR**:戰棋盤面演算法層(可達格/威脅範圍/視線,`TR-tactical-002`~`-010`、`-019`~`-021`、`-037`~`-039`);回合結構擁有權 + 缺席的 AI/遭遇系統(`TR-tactical-034`、`-041`)—— **全專案無人認領回合結構**,而 `tactical-combat-system.md` Core Rules #9 明文要求敵方回合消費這些查詢。

---

## 四、待處理清單

### A. 跨 ADR 銜接缺口(第二輪審查發現,C2/C4/C5 已修,兩項仍開)

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
4. `@abstract class_name Foo extends RefCounted` 最小檔案語法 —— 寫錯是**整檔案編譯失敗**(承 ADR-0004 Verification Required 6/6a)

### D. 其他未處理

- **R3(第二輪審查)**:ADR-0003 補一條 Validation Criteria(payload 建構路徑不得含 `Callable`/`Signal`/`RID` —— 它們不是 `Object` 衍生類,不受 `allow_objects=false` 管控);ADR-0002 的 Post-Cutoff 欄措辭易被誤讀為「不依賴 `Dictionary[K,V]`」。
- **戰棋系統文件自陳的下游阻擋項**:OQ-2 `player_baseline_stat` 全專案無擁有者;OQ-10 無「不可通行」地形層級;OQ-16 敵方單位數上限無擁有者 + 效能測試須以「格數 × 敵數」兩軸參數化。
- **戰棋系統 DEFER 未落地**:`enemy_advantage_pct < 0` 無驗證拒絕(與既有 `≥1.0` 拒絕不對稱,會靜默反轉 Core Rules #7);公式二 `ceil()` 浮點精度邊界噪聲。
- **戰棋系統收斂狀態**:連續零 BLOCKING-NOW 輪數 = **0**(四輪皆 body-scoped)。距 Approved 尚需**連續兩輪**零 BLOCKING-NOW。
- **`docs/consistency-failures.md` 不存在** —— 依 skill 規定未建立,故兩輪審查的 C1~C5 只存在於審查報告內。

### E. 已凍結(不是待辦,是明文暫停)

**滑鼠奪權子機制**(`cursor-highlight-state.md` Core Rules #3)—— 使用者第十二輪(2026-08-11)裁決:硬性閘門降級為建議事項、重新設計**暫停**、候選修法停止投入,待取得手把硬體。兩項已確認缺陷維持未修復:

- **E1**(spike log 實測,100% 可重現):類比搖桿持續按住造成滑鼠奪權**永久鎖死**
- **E2**(真人口語觀察,僅測鍵盤路徑):奪權成功後被反方向零門檻豁免規則**秒搶回**

ADR-0005 機制八把它隔離在單一檔案(`MouseReclaimPolicy`),**明文不宣稱已緩解**。待辦:取得一支手把後補測 D-pad 與類比搖桿。**不得假設「未測 = 沒問題」。**
