# Story 017:補血卡與雙人甲類(距離過濾、夾限、免選目標路徑)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Ready(依序:010、011、015 完成後才可派工)—— 派工前三題皆為實作者第一步查證,不是待裁決;原寫「卡 F7 距離函式」是 lead-programmer 自問,不擋派工。
> **Type**: Logic
> **Estimate**: M~L(2~2.5 天,粗估未驗證;data-format S3)
> **依據**:規格 v1.0 第 0 節(c04~c14 沿用 v0.3 第 4 節卡池;c05~c11 沿用 `TEMPORARY_STAT_MODIFIER`,c06「ATK+3 且 DEF−2」現有欄位可表達);`docs/reviews/card-rework-data-format-2026-11-12.md` F7、F8、F9。c04「≤1」、c07「≤2」、c13「≤3」、c14「≤2」補血/雙人距離每張不同(`target_range` 欄,011)。v0.3 第 4 節卡池原文**本單撰寫者未讀**(`design/quick-specs/card-rework-cost-and-pool-2026-11-12.md`,實作者第一步讀)。

## 派工前須先決定

1. **距離函式**:曼哈頓距離現有兩份(戰鬥模組、好感度模組各一;`technical-preferences.md` 提及,位置**未驗證**)。**新卡必須呼叫既有的一份,不得第三份。**實作者第一步當場找出兩份並回報,選用哪一份由 lead-programmer 在回報中說明並經協調者確認。
2. **補血是否有視線/距離以外限制**、補血對象是否可為自己、補血量是否可超過最大 HP(規格 v0.3 第 4 節是否已定:**未驗證**)—— 實作者讀 v0.3 第 4 節確認;有缺口 → 停下回報,不自行定案。
   - **已決(管理者 2026-11-18 裁決,依 `docs/reviews/card-rule-gaps-answers-2026-11-18.md`)**:c04 **不能補付款人自己**(承受者 = 距離 ≤`target_range` 的缺血**隊友**,排除付款人);c07 = **玩家選一名** 2 格內隊友(不含麥子健自己,走既有單人甲類選目標流程,不觸發 AC5 免選目標路徑);c10/c11 兩人距離 **≤2**(同 c09)。
3. **F9 免選目標路徑**:雙人甲類(c09~c11)目標由卡面決定(點名者+夥伴),不需選目標;`BattleScreen.select_card()` 內有「`legal_targets()` 為空即視為已到確認」的慣例(**未驗證**),與新路徑可能碰撞。實作者第一步讀該段,列出碰撞點,**若需改 `battle_screen.gd` 超出範圍 → 停下問**。

## 規則

- 補血:提交窗口內走受守衛 `hp` setter,夾限最大 HP;不使用 `take_damage()` 的反向。
- 雙人甲類:兩人**皆存活**且距離 ≤ `target_range` 才可打(F8);對兩人各掛一個 `CardModifier`(沿用 story-001/002 模型)。
- 有向卡(c13 徐→藍、c14 秦→董):付款人/承受者有向,但好感度配對無向(`AffinityTypes.pair_of`),有向只用於誰付/誰收。
- **已決(答案檔題 1)**:補血卡 c13/c14 `named_unit_id` = 付款人、`partner_unit_id` = 承受者;NONE 時只有付款人付血(`hp>cost`);雙人加成 c09~c11 則兩人皆付(015 的純函式決定,本單只接收結果)。
- 全部在 010 的提交窗口內、015 的「先驗證後扣款」順序之後。

## Acceptance Criteria

- [ ] **AC1 補血**:補血量 = `effect_value`;不超過最大 HP;對滿血者的行為依派工前第 2 題結論(測試鎖住);c04 付款人不在合法承受者內、c07 只對所選一名生效(2026-11-18 裁決,各 1 條測試)。
- [ ] **AC2 距離**:`target_range` 內可打、距離 +1 不可打(各 1 條,c04/c07/c13/c14 各一個邊界;c09/c10/c11 兩人距離 ≤2 各一個邊界 —— 2026-11-18 裁決補 c10/c11);距離計算呼叫既有那一份函式(AC6 grep 證據)。
- [ ] **AC3 雙人存活**:任一人不在場/已陣亡 → 不可打、零寫入。
- [ ] **AC4 雙人甲類**:兩人各掛修正器(ATK/DEF 數值、持續規則依 story-001/002),c06「ATK+3 且 DEF−2」以現有 `delta_atk`/`delta_def` 表達且**不新增機制**。
- [ ] **AC5 免選目標**:雙人甲類打牌流程不要求選目標、不卡在 `SELECTING_TARGET`;既有單人甲類流程不變(回歸)。
- [ ] **AC6 不新增距離實作**:`grep -rn "abs(.*\.x.*)\s*+\s*abs\|manhattan" src --include=*.gd | grep -v "^\S*:[0-9]*:\s*#"` 回報原始輸出(**對照本單改動前後命中數相同**);🔴 搜尋指令不得寫進被搜尋檔。
- [ ] **AC7 提交內**:補血在窗口內不被守衛拒,版本號每次確認 +1(010 契約)。
- [ ] **AC8 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①距離判斷 `<` 取代 `≤` → AC2 紅 ②補血不夾限 → AC1 紅 ③只掛一人修正器 → AC4 紅 ④雙人不查存活 → AC3 紅 ⑤自寫一份曼哈頓 → AC6 紅 ⑥窗口外補血 → AC7 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 直傷(018)、合擊(019)、牌面文字與 14 張卡資料(022)、確認面板(020)。

## Affected Files

- `src/gameplay/cards/card_play_session.gd`、`src/gameplay/battle/battle_state.gd`(補血寫入口)、必要時 `src/ui/battle/battle_screen.gd` 僅限 `select_card()` 的空目標慣例(超出先問)
- 新測試:`tests/unit/gameplay/cards/card_heal_and_buff_test.gd`

超出此清單先問。

## 與其他工單的順序

- **依賴 010、011、015**;019 依賴 018,不依賴本單。
