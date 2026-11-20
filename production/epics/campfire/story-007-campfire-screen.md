# Story 007:營火畫面 —— 選兩人、關心/質問、寫入前看見後果

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Blocked —— 卡在 `ux-designer`:**營火畫面規格不存在**(2026-11-20 `ls design/ux/` 實查無此檔)。
> **Type**: UI
> **Estimate**: M(1.5~2 估計天,粗估未驗證;排程 F2 1.5~2 + N6 0.5~1 合併後應有重疊)
> **依據**:v1.0 規格 6.3 第 (1) 項(寫入前顯示該配對當前關係與寫入後的預期關係)、6.1(關心麥子健時確認面板須提示「麥子健將失去騎牆」;文案同 `design/ux/card-rework-ui-2026-11-17.md` 第 156 行)、6.3 第 (4) 項(不得只靠顏色表示關係);三態玩家用詞「好感/冷淡/敵意」(管理者 11-17 自填,同上 UX 檔 Status 行);`technical-preferences.md` 平台規則(滑鼠與手把同等、無 hover-only)。

## 派工前須先決定

| # | 題目 | 誰決定 |
|---|---|---|
| 1 | 營火畫面規格:版面、選人流程、預覽怎麼呈現、產出卡怎麼展示、手把操作 | `ux-designer`(美術項交 `art-director`) |
| 2 | 介面不得依賴「棋盤旁邊有空位」的限制是否適用(營火不是棋盤畫面,推論不適用) | `ux-designer` 確認 |

## 規則摘要

- 選兩名角色(10 組任一)→ 選關心/質問 → **寫入前**顯示當前關係與寫入後預期關係(呼叫 `AffinityRelation.state_of()` 對預覽池算,**不得另寫判斷**)→ 確認 → 呼叫 002 寫入、003 產卡 → 顯示產出的卡。
- 麥子健四組全冷淡、且本次寫入會讓其中一組跨出冷淡區 → 確認前顯示「麥子健將失去騎牆」。
- 字級一律呼叫 `HudLayout`/`WorldLayout`;最小視窗 1280×720。

## Acceptance Criteria

- [ ] **AC1** 寫入前預覽的「寫入後關係」與實際寫入後 `state_of` 一致(對 10 組 × 2 動作逐一斷言,以真實營火場景檔載入)。
- [ ] **AC2** 騎牆提示:會使麥子健失去騎牆時顯示,不會時不顯示(兩側各一條)。
- [ ] **AC3** 全流程可只用手把完成、可只用滑鼠完成(互動測試)。
- [ ] **AC4** 關係三態除顏色外另有文字或形狀區分(依 UX 規格)。
- [ ] **AC5** 人眼:截圖依 coding-standards 截圖分類執行,管理者或 `art-director` 確認。
- [ ] **AC6** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①預覽讀寫入前的值 → AC1 紅 ②騎牆提示條件反置 → AC2 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- 新檔:`src/ui/campfire/`(場景 `.tscn` + 腳本)、新測試;`assets/data/locales/strings.csv` 新增鍵(既有檔,**只追加列**,依派工單範圍)。
- 超出先問。

## 與其他工單的順序

- 依賴 001、002、003 與 UX 規格。006 先用殼層接線,本單替換成正式畫面。
