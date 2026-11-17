# Story 015:卡牌代價結算(付血、付好感度折損、PAIR 依當下 S、先驗證後扣款)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Blocked —— 依賴 010、011、012(尚未完成);另卡在派工前第 1、2 題裁決。
> **Type**: Logic
> **Estimate**: L(2~3 天,粗估未驗證;data-format S2 + 排程 N4/N5)
> **依據**:規格 v1.0 第 4.1 節(`PAIR`:S∈{POS,NEG} 走本場折損 `cost_amount` 點;S=NONE 付款人各付 `hp_cost_none` 點血,條件 `hp>cost`)、第 4.2 節(基礎卡不再要求人設關係線、不再「含麥子健拒絕」;打牌合法性只剩兩人存活 + 距離 ≤`target_range` + 付得起 + 折損未達上限)、第 6.1(`hp ≤ cost` 不可打、不扣款)、第 8 節旋鈕;`docs/reviews/card-rework-data-format-2026-11-12.md` F5、F6。裁決:丙類只加深、好感度代價只在這場戰鬥、付血須 `hp>cost`。

## 派工前須先決定

1. **折損計數器歸屬**:每場每配對累計折損 `N`(上限 `pair_cost_cap`)放 `BattleState`(data-format F6-2 建議,**未驗證** `BattleScreen` 切關時是否重建 `BattleState`)。lead-programmer 第一步查證;若不重建,停下問。
2. **配對合法性重用**:F6-1 要求驗證階段重用 `PermanentAffinityWriteRules` 的合法性判斷、不另寫一份;但規格 4.2 說基礎雙人卡**不再**依 `legal_pairs()`。兩者看似衝突 —— **以規格為準**:PAIR 卡不查 `legal_pairs()`;「付好感度」的**折損不寫池**(規格 5.2/第 3 節「折損不改 S」),因此**本單不呼叫 `AffinityWritePort`**,F6-1/F6-3 的「抽 `validate_pair()`」**不在本單**(僅丙類寫池才需要)。⚠️ 若管理者最終要「好感度代價真的寫池」(`cost_type=AFFINITY` 的原意),本單範圍要重估 —— 請設計師確認 `AFFINITY` 與 `PAIR` 的分工(規格 4.1 只定義了 PAIR;`AFFINITY` 是否仍用在單人卡:**未驗證**)。
3. 單付款人卡(c13、c14)在 NONE 時「僅付款人付」(規格 4.1)—— 付款人欄來自 011 的 F1 裁決。
4. 付血是否可讓付款人 HP 到 1(`hp>cost` ⇒ 付後至少 1):規格已定,無待裁決,僅列出。

## 規則

- **順序**(沿用 F6-1):①全部驗證(存活、距離、`hp>cost`、折損未達上限、S 解析)→ ②進 010 的提交窗口 → ③扣款 → ④效果。**窗口內不得有失敗路徑**。
- 付血走**受守衛的 `hp` setter、在提交窗口內**,不用 `take_damage()`(會觸發死亡清理);不使用 `assert`(發行版被移除)。
- `PAIR` 在**驗證時**解析 S(呼叫 012 `state_of`),面板文字所需資料(走折損/各付血、數字)由同一函式回傳,供 020 顯示 —— **面板與實際扣款共用同一個結果物件**,不得各算一次。
- 折損累計 `N` 存 `BattleState`;`N` 不改池、不改 S。
- `is_card_playable()` 擴為可回傳**不可打原因**(列舉,第 0 值 = 一個明確的「可打」以外的安全預設需謹慎:用 `NONE` = 可打 是現行慣例則照慣例,**不得用 `assert` 守衛 enum 回傳**)。

## Acceptance Criteria

- [ ] **AC1 付血**:單人 HP 卡:`hp>cost` 可打、扣款後 `hp==舊hp−cost`;`hp==cost`、`hp<cost` 不可打、**不扣款、版本號不變**。
- [ ] **AC2 PAIR 依 S**:POS、NEG 走折損(`N` 累加 `cost_amount`,封頂 `pair_cost_cap`,達上限不可打);NONE 走各付 `hp_cost_none` 點血(雙人卡兩人都付;c13/c14 僅付款人)。
- [ ] **AC3 S 戰鬥中翻轉**:同一場內丙類寫池使 S 由 POS→NONE,下一次打 PAIR 卡改走付血(規格驗收 (5))。
- [ ] **AC4 麥子健與非人設配對可打**:含麥子健的雙人卡、非人設配對皆可打(規格驗收 (10));任何 S 皆可打。
- [ ] **AC5 先驗證後扣款**:任一驗證失敗 → 零寫入(HP、`N`、牌位置、版本號皆不變)。
- [ ] **AC6 面板資料與實際扣款一致**:同一輸入下,面板資料物件說的扣款(種類+數字)等於實際 HP/`N` 變化(規格驗收 (4))。
- [ ] **AC7 不可打原因**:`is_card_playable()` 對「付不起者」「折損已達上限」「夥伴不在場」回不同原因(各 1 條)。
- [ ] **AC8 折損不寫池**:打 PAIR 卡前後池的 Delta Log 筆數與各配對累積值不變。
- [ ] **AC9 旋鈕**:`hp_cost_none`、`pair_cost_cap` 取自 `assets/data/` 旋鈕檔(`.txt`,不得 `.csv`),缺鍵/非整數 → 預設值 + `push_warning`;值域 2~5 外被拒。
- [ ] **AC10 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①先效果後扣款 → AC5 紅 ②付血用 `take_damage()` → AC1(HP 歸 0 時修正器被清)紅 ③`hp>=cost` 取代 `hp>cost` → AC1 紅 ④忽略 S(恆走折損)→ AC2/AC3 紅 ⑤面板自行重算 → AC6 紅 ⑥扣款寫池 → AC8 紅 ⑦`pair_cost_cap` 寫死 → AC9 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 折損如何扣減 Φ 貢獻(016)、效果本身(017~019)、確認面板畫面(020)。
- 牌組記憶、戰敗重打保留牌組(牌組編輯,不在本批;**本單不依賴它**)。

## Affected Files

- `src/gameplay/cards/card_play_session.gd`、`src/gameplay/battle/battle_state.gd`(折損計數器)、`src/gameplay/cards/card.gd`(僅讀 011 新欄)、旋鈕檔與載入端
- 新測試:`tests/unit/gameplay/cards/card_cost_settlement_test.gd`、`tests/integration/gameplay/cards/card_cost_pair_state_test.gd`

超出此清單先問。

## 與其他工單的順序

- **依賴 010、011、012**;016、017、018、019、020 依賴本單。
