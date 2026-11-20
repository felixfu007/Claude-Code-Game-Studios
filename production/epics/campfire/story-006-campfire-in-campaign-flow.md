# Story 006:營火接進戰役流程

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Blocked —— 卡在 ①**管理者**:打輸後回到哪裡(第 1 題);②`game-designer`:營火與支援對話誰先(第 2 題)。
> **Type**: Integration
> **Estimate**: M(1~1.5 估計天,粗估未驗證;排程 F1 原估 1~1.5,`scene_router.gd` 有支援對話插入範本可照抄)
> **依據**:v0.3 第 6 節第 6 點(營火結束後強制進牌組編輯,確認後才往下);v0.3 6B「位置」;v1.0 4.6(「一輪」邊界);`design/gdd/vertical-slice-level-01.md` 第 75 行(戰敗回滾,見下)。

## 背景(producer 2026-11-20 實查)

- 現行勝利後流程:`battle_screen.gd` 勝利 → `_trigger_support_conversations_for_finished_mission()` → `CampaignProgress.advance_on_victory()` → 結果畫面 → `SceneRouter.go_to_support_conversation()` → `_enter_battle_after_conversations()` → 下一場。
- 🔴 **規格與 GDD 對戰敗的說法不一致**:
  - `design/gdd/vertical-slice-level-01.md` 第 75 行:「回到本切片開始前的整備點(對應『上一次營火』)……好感度、腐蝕、牌組與營火配對選擇**一併回滾重來**」。
  - v1.0 規格 4.6:「戰敗後重打同一場是否保留牌組:預設**保留**」。
  - 現行程式:戰敗只回滾「這一場打的過程中」新增的好感度記錄;營火寫入發生在下一場開打之前,**依現行機制不會被回滾**(推論,未逐行驗證)。

## 派工前須先決定

| # | 題目 | 誰決定 | 白話 |
|---|---|---|---|
| 1 | 打輸後:**甲**直接重打這一場,營火的選擇與牌組都保留;**乙**回到上一次營火,重新選關心/質問與牌組 | **管理者** | 甲好做(現行機制自然如此)、玩家不必重選;乙符合 GDD 原文、讓玩家改選,但要把營火寫入也做成可回滾,多約 0.5~1 估計天(未驗證) |
| 2 | 勝利後順序:營火 → 編輯牌組 → 支援對話 → 下一場,或 支援對話 → 營火 → 編輯 → 下一場 | `game-designer` | 協調者看法:十組關係前提已裁決「優先挑剛在營火選過的組」看對話(`pair-premises-10-2026-11-12.md` 第五節題 1),**推論**營火應在前;但現行「依關係挑段落」程式不存在(屬第 4 階段),本 EPIC 只需定順序 |
| 3 | 最後一場勝利後、教學場後:不進營火(推論) | `game-designer` 確認 | |

## 規則摘要

- `scene_router.gd` 新增進營火的路由,照支援對話的注入模式(進樹前注入、接完成訊號)。
- 營火 → 牌組編輯(強制)→ 確認後才往下;中途不得跳過編輯。
- 回標題 → 本輪結束,牌組與收藏區重置(與 004 AC4 同一行為)。

## Acceptance Criteria

- [ ] **AC1** 第 1 場勝利(非最後一場)→ 進營火 → 牌組編輯 → 依第 2 題順序 → 第 2 場(以真實場景檔載入、走真實 `SceneRouter`)。
- [ ] **AC2** 牌組未確認不得進下一場。
- [ ] **AC3** 最後一場勝利、教學場 → 不進營火。
- [ ] **AC4** 戰敗 → 依第 1 題裁決的回到點與保留/回滾行為。
- [ ] **AC5** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①勝利後略過營火 → AC1 紅 ②編輯頁未確認即放行 → AC2 紅 ③最後一場仍進營火 → AC3 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- `src/ui/shell/scene_router.gd`、`src/ui/battle/battle_screen.gd`(勝利後分流)、新測試(`tests/integration/`)。
- 營火/編輯畫面本身在 007/008,本單可用最小殼層場景先接線。
- 超出先問。

## 與其他工單的順序

- 可在 007/008 之前用殼層場景先做;正式畫面完成後由 011 驗整條。
- 🔴 第 1 題若選乙,002(寫入口)與 004(牌組)都要支援回滾,兩張的 AC 須補。
