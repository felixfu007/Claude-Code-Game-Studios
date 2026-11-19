# Story 021:戰場資訊卡/手牌顯示兩人當前關係三態(好感/冷淡/敵意,不得只靠顏色)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: In Progress(2026-11-19:第一輪資訊卡 + 手牌 `c1984ab`;第二輪友敵線 + 關係圖詳情在 worktree `agent-ae7d87c8b52f2a5d8` `29ea8e9` 未合入 —— 管理者 2026-11-19 裁決「面板往上長(推薦)」「要,寫方向詞(推薦)」,須重做版面與加效果方向詞後合入;AC4 截圖未做)(原狀態:Ready(2026-11-17 管理者核准文件包)—— **前置工單 012 須先 Done 才可開工**(與 020 共用 UX 規格,兩單互不阻擋)。UX 規格已存在:`design/ux/card-rework-ui-2026-11-17.md`(第 4 節、AC-8~AC-13、AC-16);美術決定:`docs/reviews/card-rework-ui-art-2026-11-17.md`。)
> **Type**: UI
> **Estimate**: M(1~1.5 天,粗估未驗證;排程 N7)
> **依據**:規格 v1.0 第 6.3 (3)(4);數值提案原建議三態名稱「友好/冷淡/敵對」,**管理者 2026-11-17 裁決改為「好感/冷淡/敵意」**(自填;見 `production/session-state/active.md` grep「好感/冷淡/敵意」)(`docs/reviews/affinity-zero-state-proposal-2026-11-12.md`)。

## 派工前須先決定

1. ux 規格已出(`design/ux/card-rework-ui-2026-11-17.md` 第 4 節):顯示位置 = 棋盤友敵線、戰場資訊卡、手牌雙人卡(Z2/Z3,Z1 不放)、關係圖面板四處;徽記:好感 = 實線短段、敵意 = 鋸齒短段、冷淡 = 空心點(美術 2026-11-17 已定畫法)。`Loc` 鍵名由 `localization-lead` 定;三詞 + `騎牆：有效/失效` 各只一個鍵。
2. 顯示是即時反映 S 翻轉(戰鬥中丙類寫池)還是出牌時才更新:規格 5.1/3 節要求即時 → 預設即時。

## 規則

- 只讀 012 `state_of`,不自行判斷;文字 + 形狀/圖示,**不只靠顏色**(art-direction 既有規定)。
- 像素證據走真實 `BattleScreen`(第 5 點),Check 4 N/A 須寫明。

## Acceptance Criteria(已接 ux 規格,AC-n 指 `design/ux/card-rework-ui-2026-11-17.md` 第 5 節)

- [ ] **AC1** 三態(好感/冷淡/敵意)各有專屬文字 + 非顏色標記,測試以真實場景檔讀取節點內容(規格 AC-8、AC-12)。另:關係圖詳情區**冷淡也列文字**(管理者 2026-11-17 裁決「兩項都要」之一;規格 AC-11)。
- [ ] **AC2** S 在戰鬥中翻轉後畫面下一幀反映(規格 AC-9、AC-13;含麥子健 `騎牆：有效/失效` 只顯示在麥子健身上,失效可再變回有效)。
- [ ] **AC3** 與 012 一致:對 10 組各自顯示與 `state_of` 輸出相同(含非人設配對、含麥子健配對);棋盤冷淡配對不產生線節點(規格 AC-9、AC-10)。
- [ ] **AC4 Check 5 人眼確認**,限定受測者只有管理者本人;截圖解析度 1280×720(最小視窗)與 1920×1080(原稿無此規定;規格 AC-14)。
- [ ] **AC5 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行;對應規格 AC-16 ④⑤⑥):①UI 自判 S 或自帶門檻 `k` → AC3 紅 ②只換顏色不換文字 → AC1 紅 ③快取顯示 → AC2 紅 ④騎牆顯示自算而非讀判定 → AC2 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 營火寫入前後狀態顯示(營火,不在本批)、關係線圖(排程 N10 未查)。

## Affected Files(暫定)

- `src/ui/battle/` 資訊卡/手牌相關檔、`strings.csv` 新鍵、新測試 `tests/integration/ui/battle/relation_state_display_test.gd`

超出此清單先問。

## 與其他工單的順序

- **依賴 012;與 020 共用 ux 規格**。
