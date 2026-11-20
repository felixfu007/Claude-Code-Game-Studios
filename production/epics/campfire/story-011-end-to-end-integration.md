# Story 011:端到端整合 —— 戰鬥 → 營火 → 編輯 → 下一場

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Blocked —— 依賴 001~010 全部。
> **Type**: Integration
> **Estimate**: S~M(1 估計天,粗估未驗證)
> **依據**:v1.0 規格第 9 節驗收 (7)(營火寫池後下一場讀到新關係,真實場景檔載入)、(9)(牌組不出現在任何存檔資料、回標題回預設)、(10)(含麥子健雙人卡可打);體驗題「我有沒有因為營火的選擇,在戰場上看到差別?看得懂為什麼嗎?」。
> 🔴 **不含**驗收 (8)(營火寫入計入結局)—— 管理者 11-13 裁決移到結局系統。

## 規則摘要

- 一條測試走完整條:第 1 場勝利 → 營火(關心一組非人設配對、質問一組人設配對)→ 編輯牌組(移出 1 張、保留新卡)→ 第 2 場開局。全程走真實 `SceneRouter` 與真實場景檔,不得自組替身節點鏈(technical-preferences 第 5 點)。

## Acceptance Criteria

- [ ] **AC1** 第 2 場開局:被關心的配對 `state_of` 依寫入量變化;被質問的配對同理;棋盤關係線與三態顯示跟著變。
- [ ] **AC2** 第 2 場牌庫含新營火卡、不含移出的卡。
- [ ] **AC3** 營火卡在第 2 場可打,代價依當下關係走對的那一種。
- [ ] **AC4** 回標題 → 新遊戲 → 牌組回預設、營火卡消失。
- [ ] **AC5** 管理者試玩一次並回答體驗題(紀錄進 `production/qa/evidence/`)。
- [ ] **AC6** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①營火寫入不進累積記錄 → AC1 紅 ②牌組不注入戰鬥 → AC2 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- 新測試 `tests/integration/campfire/`;原則上不改產品碼(要改 = 前面某張漏了,回報)。

## 與其他工單的順序

- 最後一張實作工單;012 可與本單平行。
