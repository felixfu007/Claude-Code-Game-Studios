# Story 012:共用關係狀態判定 `state_of(pair)` + 冷淡區旋鈕(k=0 回歸)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Ready(以 `k=0` 先行;`k` 的正式值待 025 量測,**不得用占位值 50 上線**)—— 第 1 題已由技術總監裁決(2026-11-17,`docs/reviews/state-of-adr0002-ruling-2026-11-17.md`:不修訂 ADR-0002,新檔 `AffinityRelation`);`k=0` 先行已由管理者 2026-11-17 裁決「冷淡區量測前先設 0」
> **Type**: Logic
> **Estimate**: M(1~1.5 天,粗估未驗證;排程文件 N1)
> **依據**:
> - 規格 v1.0 第 3 節(`S(pair)`:`n==0` 或 `|v|≤k` → NONE;`v>k` → POS;`v<−k` → NEG;**不看配對名字,10 組同一條式子**)、第 8 節旋鈕 `affinity,neutral_band_centi`、第 9 節驗收 (1)(2)。
> - `docs/reviews/affinity-zero-state-proposal-2026-11-12.md`(管理者裁決「冷淡區」)。
> - 現況(2026-11-17 查):`grep -rn "func state_of\|neutral_band" src --include=*.gd` **無命中**(函式與旋鈕都不存在);`src/gameplay/affinity/affinity_phi_provider.gd` 第 105 行 `func links()`、第 169 行 `func _link_for_pair(`(規格稱 `links()` 全掃 10 對、第 3 分支 `value==0.0`,**本單撰寫者未逐行讀,二手**)。

## 派工前須先決定

1. **放哪裡/是否動 ADR-0002**:`state_of(pair)` 是好感度池的**唯讀判定**。放在池(`affinity_data_pool.gd`)還是 `AffinityPhiProvider`?加在已 `Accepted` 的池介面上是否算契約變更(ADR-0002 契約「不變,新增的是呼叫者」是規格 4.3 對營火寫入說的,對**新讀取函式**未驗證)。**lead-programmer 須先對照 ADR-0002 與 `docs/registry/architecture.yaml` 的 interfaces 節回答;若算契約變更 → 停下問技術總監,不自行改 ADR。**

   > **✅ 2026-11-17 技術總監建議(`docs/reviews/state-of-adr0002-ruling-2026-11-17.md`)**:不放池、不放 `AffinityPhiProvider`;新增 `src/gameplay/affinity/affinity_relation.gd`(`AffinityRelation.state_of(pool, pair, neutral_band) -> RelationState`,靜態純函式),`k` 經 `AffinityTuning` 載入。**不觸及 ADR-0002 契約,不修訂 ADR。** 本單不改 `affinity_phi_provider.gd` 與 `affinity_data_pool.gd`(第 3 分支改讀 `state_of` 屬 story-013)。
2. **`n` 的讀取來源**:`n_pair`(互動筆數)現有讀取介面是什麼(`combat_strength_read(pair)` 是否已含 `n`)—— 規格 3 節標二手。實作者第一步當場查。
   - **已決(TD 裁決檔第 4 節末)**:`n` 取自 `combat_strength_read(pair)` 回傳的 `AffinityReadResult.n_pair`;不需要新的讀取介面。必須先確認 `result.rejection == AffinityDataPool.ReadRejection.NONE` 才讀其他欄位,拒絕時 `push_error` + 回傳 `NONE`(拒絕時 `value` 為 `NAN`,必須是明確分支)。
3. `k` 初值:本單預設 `0`(現狀行為);正式值由 025 的 M9 量測後由管理者/數值設計師定。
   - **已決:量測前先設 `k=0`**(管理者 2026-11-17 裁決「量測前先設 0(設計師推薦)」;`docs/reviews/straddle-q3-q4-recommendation-2026-11-17.md` Q4-A)。k=0 是唯一有回歸保證的值(與現行 `_link_for_pair` 逐位相同)。若試玩覺得麥子健太快失去騎牆,正確動作是提前做 025,不是塞暫定非零值。

## 規則

- 一個函式 `state_of(pair) -> RelationState{NONE, POS, NEG}`(列舉**第 0 值 = NONE = 最安全預設**,且 `push_error`+明確 return,**不用 `assert`**)。
- **每次查詢即時讀池、不快取**。
- `k` 來自 `assets/data/` 旋鈕檔(整數 `neutral_band_centi` ÷ 100),經既有 `TuningKnobs` 載入路徑,**不得寫死**;載入失敗/缺鍵 → `k=0` 並 `push_warning`(與現況行為一致)。
- 與名字無關:函式簽章只收 pair,**不得出現任何 `if pair == 藍×徐` 之類分支**。

## Acceptance Criteria

- [ ] **AC1 四條判定**:`n==0`→NONE(即使 `v≠0`)、`|v|≤k`→NONE、`v>k`→POS、`v<−k`→NEG;邊界 `v==k`、`v==−k` 各 1 條(皆 NONE)。
- [ ] **AC2 與名字無關**:10 組各以同一函式判定;至少 1 組非人設配對、1 組含麥子健的配對有專條斷言(規格驗收 (2))。
- [ ] **AC3 `k=0` 回歸**:`k=0` 時,對既有好感度測試用的全部池狀態,`state_of` 的 POS/NEG/NONE 與現行 `links()`/`_link_for_pair` 的有線/無線/正負**逐位相同**(同一組輸入兩邊都跑,比對輸出;**不是**只測 state_of 自己)。
- [ ] **AC4 即時讀取**:池被寫入後,下一次 `state_of` 立即反映(不快取);同一測試內連續兩次寫入、各查一次。
- [ ] **AC5 旋鈕載入**:`k` 由資料檔旋鈕決定;缺鍵 → `k=0` + `push_warning`;非整數 → 拒絕並 `k=0`(沿用既有 `TuningKnobs` 慣例,實作者讀懂後照辦)。
- [ ] **AC6 唯讀**:呼叫 `state_of` 前後池的 Delta Log 筆數、各配對累積值不變。
- [ ] **AC7 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①冷淡區用 `<` 而非 `≤` → AC1 邊界紅 ②忽略 `n==0` → AC1 紅 ③以配對名字分支 → AC2 紅 ④快取第一次結果 → AC4 紅 ⑤POS/NEG 符號對調 → AC1 紅 ⑥`k` 寫死 50 → AC3/AC5 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 位置系統改讀 S(013)、騎牆(014)、`k` 量測(025)、UI 三態顯示(021)。

## Affected Files

- `src/gameplay/affinity/affinity_relation.gd`(新檔)
- `src/gameplay/tuning/affinity_tuning.gd`、`src/gameplay/tuning/tuning_knobs.gd`(加 `neutral_band_centi`,當場確認載入路徑)
- `assets/data/` 旋鈕檔 + 對應載入端(`src/gameplay/tuning/tuning_knobs.gd`,當場確認)
- 新測試:`tests/unit/gameplay/affinity/relation_state_of_pair_test.gd`

超出此清單先問。

## 與其他工單的順序

- 無前置;**013、014、015(PAIR 代價)、016、021、025 依賴本單**。
