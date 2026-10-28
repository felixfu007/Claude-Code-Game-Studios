# Story 004:接進轉場流程(勝利 → 對話 → 下一場)

> **Epic**: `production/epics/support-conversation-ui/EPIC.md`
> **Status**: Ready(2026-10-28)
> **Type**: Integration
> **規格權威**: `design/ux/support-conversation-screen.md` 第 1 節、AC-1、AC-2

## 管理者 2026-10-28 裁決

選項逐字「**對話播完直接進下一場(推薦)**」;被跳過:「對話播完回標題畫面(維持現狀)」。
裁決時已告知:這會改一個已驗收的行為(勝利後回標題,game-shell story-001 AC5),對應測試要跟著改。

## 新流程

| 情況 | 現在 | 改成 |
|---|---|---|
| 勝利,且不是最後一場,且本槽位有**實際觸發**的對話 | 結果數秒 → 標題 | 結果數秒 → **支援對話畫面** → 播畢 → **下一場**(`SceneRouter.enter_battle`) |
| 勝利,且不是最後一場,本槽位**沒有**對話(第 4→5 槽、或參與者陣亡被略過) | 結果數秒 → 標題 | 結果數秒 → **直接進下一場**(對話畫面不出現,UX AC-2) |
| 勝利最後一場(戰役完成) | 顯示「戰役完成」→ 標題 | **不變** |
| 戰敗 | → 標題 | **不變** |

- 「實際觸發」= `SupportConversationRules.trigger()` 後該記錄狀態為已完成;因參與者陣亡而 `SKIPPED` 的**不播**(規格第 5 節:不支援陣亡後變體)。`SupportConversationTransition.trigger_for_mission_transition()` 目前把 SKIPPED 的也放進回傳陣列 —— **呼叫端要自己依狀態過濾**,`src/gameplay/narrative/` 底下的檔一律不改(該目錄有寫入呼叫點計數測試)。
- 好感度寫入時機**維持現狀**(勝利當下寫入累積記錄)。協調者判斷:全專案無存檔、對話畫面無離開入口,「先寫後播」與「播完才寫」玩家不可區分。**若實作時發現對話畫面有任何可離開戰役的路徑,停下回報。**
- 換場一律經 `SceneRouter`(新增一支 `go_to_support_conversation(tree, ids)` 之類的函式,比照既有 `enter_battle` / `go_to_title`)。
- 自動回標題的計時器只在「戰敗 / 戰役完成」路徑保留。

## Acceptance Criteria

- [ ] **AC1** 第 1 場勝利(甲乙存活)→ 結果顯示後切到對話畫面,`conversation_ids == ["SC-01"]`;對話畫面發出完成訊號 → 進第 2 場戰鬥。
- [ ] **AC2** 第 4 場勝利 → 不出現對話畫面,直接進第 5 場。
- [ ] **AC3** 參與者陣亡導致 SKIPPED → 不出現對話畫面,直接進下一場。
- [ ] **AC4** 戰敗、戰役完成 → 仍回標題(既有測試照舊綠)。
- [ ] **AC5** 既有斷言「勝利後回標題」的測試:**逐支列出**改了哪幾支、改前改後斷言,理由引用本裁決。不得刪測試。
- [ ] 敏感度證明門檻;每條測試要嘛有常駐證明,要嘛寫下為什麼證明不了。

## Affected Files

`src/ui/battle/battle_screen.gd`、`src/ui/shell/scene_router.gd`、既有斷言勝利後回標題的測試(實作者逐支列出)、`tests/integration/ui/shell/...`(新)。
🔴 不得修改 `src/ui/shell/support_conversation_screen.gd`(另一工作線同時在改)與 `src/gameplay/narrative/*`。
