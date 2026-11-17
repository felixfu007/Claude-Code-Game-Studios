# Story 021:戰場資訊卡/手牌顯示兩人當前關係三態(友好/冷淡/敵對,不得只靠顏色)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Blocked —— **`ux-designer` 規格尚未存在**;依賴 012。
> **Type**: UI
> **Estimate**: M(1~1.5 天,粗估未驗證;排程 N7)
> **依據**:規格 v1.0 第 6.3 (3)(4);數值提案建議三態名稱「友好/冷淡/敵對」(`docs/reviews/affinity-zero-state-proposal-2026-11-12.md`)。

## 派工前須先決定

1. ux 規格:顯示位置(戰場資訊卡?手牌?兩者?)、圖示/文字、`Loc` 鍵。**ux-designer 先出。**
2. 顯示是即時反映 S 翻轉(戰鬥中丙類寫池)還是出牌時才更新:規格 5.1/3 節要求即時 → 預設即時。

## 規則

- 只讀 012 `state_of`,不自行判斷;文字 + 形狀/圖示,**不只靠顏色**(art-direction 既有規定)。
- 像素證據走真實 `BattleScreen`(第 5 點),Check 4 N/A 須寫明。

## Acceptance Criteria(骨架)

- [ ] **AC1** 三態各有專屬文字 + 非顏色標記,測試以真實場景檔讀取節點內容。
- [ ] **AC2** S 在戰鬥中翻轉後畫面下一幀反映。
- [ ] **AC3** 與 012 一致:對 10 組各自顯示與 `state_of` 輸出相同(含非人設配對、含麥子健配對)。
- [ ] **AC4 Check 5 人眼確認**,限定受測者只有管理者本人。
- [ ] **AC5 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①UI 自判 S → AC3 紅 ②只換顏色不換文字 → AC1 紅 ③快取顯示 → AC2 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 營火寫入前後狀態顯示(營火,不在本批)、關係線圖(排程 N10 未查)。

## Affected Files(暫定)

- `src/ui/battle/` 資訊卡/手牌相關檔、`strings.csv` 新鍵、新測試 `tests/integration/ui/battle/relation_state_display_test.gd`

超出此清單先問。

## 與其他工單的順序

- **依賴 012;與 020 共用 ux 規格**。
