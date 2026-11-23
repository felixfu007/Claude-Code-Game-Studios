# Story 005:戰鬥改從確認後的牌組洗牌

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Blocked —— 依賴 **story-004**(未 Done)。本單自身無待決(第 1 場定位已由管理者 11-23 裁決釐清)。
> (原狀態:Blocked —— 依賴 story-004(牌組放哪尚待 `lead-programmer`)。本單自身無額外待決。)
> **Type**: Integration
> **Estimate**: M(1~1.5 估計天,粗估未驗證;**受影響的既有測試數未量,可能偏高**)
> **依據**:v0.3 第 6B 節「與洗進牌庫」列(牌組每張 1 份、隨機順序、無保證起手、每場以編輯頁確認的牌組為準);v1.0 4.6;管理者 2026-11-23 裁決第 1 題(第 1 場 8 張不動,`docs/reviews/campfire-rulings-2026-11-23.md`)。

## 背景(producer 2026-11-20 實查;2026-11-23 更新)

- 現行每場用固定牌表:`assets/data/cards/vs01_cards.txt` ~ `vs05_cards.txt`(由 `assets/data/levels/campaign_sequence.txt` 的 `cards_path` 欄指定),另有 `tutorial_cards.txt`。
- 戰鬥牌庫:`src/gameplay/cards/card_deck.gd`(`CardDeck`)。
- ✅ 第 1 場:維持 `vs01_cards.txt` 8 張(管理者 11-23 第 1 題)。第 1 場之前沒有營火,不走牌組。教學場(`tutorial_cards.txt`)不變。

## 規則摘要

- **戰役第 2 場起**,牌庫 = 本輪已確認的牌組洗牌;教學場與第 1 場維持既有牌表。
- 發牌隨機屬既有豁免(牌面隨機、節奏固定);**戰鬥結算不得新增任何隨機**。
- 未經戰役注入的戰鬥(多數既有測試)行為不變 —— 比照 `campaign_ledger_override` 的 opt-in 慣例。
- vs02~vs05 牌表在戰役中不再被讀,但不刪(既有測試與非戰役路徑仍用)。

## Acceptance Criteria

- [ ] **AC1** 第 2 場開局:牌庫總張數 = 確認牌組張數,內容逐張相同(以真實戰鬥場景檔載入、注入牌組)。
- [ ] **AC2** 牌組中移出的卡**不會**出現在牌庫;新營火卡會出現。
- [ ] **AC3** 教學場、第 1 場、未注入戰役的戰鬥:牌庫與改動前逐張相同(回歸)。
- [ ] **AC4** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①改回讀固定牌表 → AC1 紅 ②忽略移出 → AC2 紅 ③第 1 場也改讀牌組 → AC3 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- `src/ui/battle/battle_screen.gd`(牌庫來源注入點)、`src/ui/shell/scene_router.gd`(注入)、必要時 `src/gameplay/cards/card_deck.gd`、新測試。
- 🔴 實作者**開工第一步**:量出有幾支既有測試直接讀 `vsNN_cards.txt` 而受影響;超過 5 支先回報再動。
- 超出先問。

## 與其他工單的順序

- 依賴 004。011 依賴本單。
