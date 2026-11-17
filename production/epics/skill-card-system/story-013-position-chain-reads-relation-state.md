# Story 013:好感度位置系統改讀關係狀態(`_link_for_pair` 第 3 分支、10 組全掃不看名字)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Blocked —— 等 `design/gdd/affinity-position-chain.md` **整份重寫完成**(管理者 2026-11-17 裁決 B:整份重寫,進行中;013/014/016 一併等它)。原卡點(已被取代,留作紀錄):**公式五「麥子健恆無線」須先修訂**(既有文件,須管理者逐檔核准;排程文件 `docs/reviews/card-campfire-schedule-v1-2026-11-12.md` 第 2 節稱此為 N2 的阻擋)。另依賴 story-012。
> **Type**: Logic
> **Estimate**: M(1~1.5 天,粗估未驗證;排程 N2)
> **依據**:規格 v1.0 第 7 節(`_link_for_pair` 第 3 分支 `value==0.0` 併入 `|v|≤k`;公式五須修訂)、第 3 節。現況:`src/gameplay/affinity/affinity_phi_provider.gd` 第 105 行 `links()`、第 169 行 `_link_for_pair(`(**撰寫者未逐行讀,實作者第一步讀全函式**)。程式側 `legal_pairs()`/`INVALID_PAIR` 受「任何兩人」裁決影響,範圍見下。

## 派工前須先決定

1. **文件先改**:`affinity-position-chain.md` 公式五、`characters.md` 第三節、`affinity-data-pool.md`、`skill-card-system.md` 的連帶修訂(規格第 7 節「文件連帶」)—— 須先逐檔取得管理者核准並完成。**本單開工條件 = `affinity-position-chain.md` 整份重寫完成(管理者 2026-11-17 裁決 B,取代原「公式五已改完」)。** 不要自己改文件。
2. `legal_pairs()` 對丙類卡 card_07/08 的約束(`skill-card-system.md` 界線 3/4)是否重寫 —— 規格 4.2 / 10B 交 creative-director,**本單不動丙類合法性**,只動「位置系統讀關係」。
3. 位置系統對 `NEG` 配對的距離規則(`delta()`、`DELTA_*`)是否沿用既有 POS/NEG 兩張表:規格 5.1 稱沿用(已自讀 `affinity_rules.gd` 第 35~98 行),**非人設配對的 NEG/POS 沿用同一表是否是設計意圖:未驗證**。

## 規則

- `_link_for_pair` 不再依「這對是不是人設線」決定有無線;改讀 012 的 `state_of(pair)`:`NONE` 無線、`POS`/`NEG` 有線並取對應極性。
- 10 組全掃,**不看名字**。`k=0` 時行為與現行逐位相同(回歸,012 AC3 的位置層版本)。
- 不改 `amp`、不改 `PHI_MIN/PHI_MAX` 夾限位置(規格 5.1)。
- 不改 `CombatRules` 對好感度池的無知性(騎牆以布林傳入,014)。

## Acceptance Criteria

- [ ] **AC1 `k=0` 回歸**:現有位置系統測試全綠,斷言不改。
- [ ] **AC2 非人設配對有線**:池中寫入一對非人設配對使 S=POS 後,該對在 Φ 計算中產生相鄰/遠離貢獻(依 `delta()` 表);S=NEG 同。
- [ ] **AC3 冷淡區**:`k>0` 且 `|v|≤k` 的配對無線(測試用夾具設 `k`)。
- [ ] **AC4 即時讀**:戰鬥中池被寫入使 S 翻轉,下一次 Φ 計算立即反映。
- [ ] **AC5 真實場景檔載入驗證**(規格驗收 (7) 精神):以 `BattleScreen` 真實場景 + 合成資料注入(`*_path_override`,兩份夾具先驗彼此相容,見 `technical-preferences.md` 第 5 點),寫池後觀察戰鬥讀到的 Φ。
- [ ] **AC6 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①仍以名字判定人設線 → AC2 紅 ②忽略冷淡區 → AC3 紅 ③快取 S → AC4 紅 ④POS/NEG 對調 → AC2 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 騎牆(014)、既有測試「固定兩對」假設改寫(024)、關係線畫面(排程 N10,未查,不在本批)。

## Affected Files

- `src/gameplay/affinity/affinity_phi_provider.gd`(必要時 `affinity_rules.gd`,先問)
- 新測試:`tests/integration/gameplay/affinity/position_chain_reads_relation_state_test.gd`

超出此清單先問。

## 與其他工單的順序

- **依賴 012;被 014、016、024 依賴**。
