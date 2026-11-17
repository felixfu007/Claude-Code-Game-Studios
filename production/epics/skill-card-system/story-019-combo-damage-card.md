# Story 019:合擊直傷卡 c12(雙人各一擊同一敵人、射程交集)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Blocked —— 依賴 018、015;卡在 018 的 F7/反擊裁決;另有派工前第 1 題(c12 規格細節)。
> **Type**: Logic
> **Estimate**: M(1~1.5 天,粗估未驗證;data-format S5)
> **依據**:規格 v1.0 第 3.8 節(沿用 v0.3:合擊距離 ≤2)與 v0.3 第 4 節 c12;data-format 文件 F8。**c12 的逐字規格本單撰寫者未讀**(`design/quick-specs/card-rework-cost-and-pool-2026-11-12.md` 第 4 節),實作者第一步讀。

## 派工前須先決定

1. **c12 細節**:「各一擊」是兩次獨立傷害(各自可擊殺、各自觸發擊殺鏈)還是一次合併傷害?兩人與敵人的射程交集如何判定(兩人各自到敵人距離 ≤ 各自射程,還是兩人之間距離 ≤2 + 敵人在任一人射程)?**game-designer 確認**;規格 v1.0 第 3.8 與 v0.3 c12 兩處是否一致:**未驗證**。
2. 第一擊擊殺後,第二擊如何處理(目標已死)—— 需規格定案(建議:第二擊作廢、不退款;**未裁決**)。

## 規則

- 重用 018 的直傷結算方法與擊殺鏈,**不得再寫一份**;雙人存活與距離檢查重用 017/015 已有的函式(F8)。
- 付款走 015(PAIR:POS/NEG 折損、NONE 各付血)。
- 全部在 010 的單一提交窗口內,版本號 +1(不是 +2)。

## Acceptance Criteria

- [ ] **AC1 兩擊**:兩人各造成一次 `effect_value` 傷害(依派工前第 1 題:各自/合併)。
- [ ] **AC2 第一擊擊殺**:第二擊依第 2 題結論處理,擊殺鏈只觸發一次且無重複移除(不 `push_error`)。
- [ ] **AC3 射程交集/雙方存活/距離 ≤2**:各邊界 1 條(任一人死亡、距離 3、敵人不在射程)。
- [ ] **AC4 版本號 +1**。
- [ ] **AC5 共用結算**:不新增第二份直傷/清佔位實作(mutant 見 AC6;`grep` 證據同 017 AC6 形式,貼原始輸出)。
- [ ] **AC6 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①只有一人出手 → AC1 紅 ②第二擊打已死目標且重複擊殺鏈 → AC2 紅 ③射程交集改聯集 → AC3 紅 ④版本號 +2 → AC4 紅 ⑤複製一份直傷結算 → AC5 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 面板與選敵畫面(020)、牌面文字(022)。

## Affected Files

- `src/gameplay/cards/card_play_session.gd`、`src/gameplay/battle/battle_state.gd`、`src/gameplay/battle/battle_controller.gd`(僅接 018 的鏈)
- 新測試:`tests/unit/gameplay/cards/card_combo_damage_test.gd`

超出此清單先問。

## 與其他工單的順序

- **依賴 015、018**。025 的 M6/M8 戰鬥量測要等本單完成(直傷卡沒有就量不了)。
