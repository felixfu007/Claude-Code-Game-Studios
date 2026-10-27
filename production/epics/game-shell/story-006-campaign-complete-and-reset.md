# Story 006:戰役完成 —— 顯示「戰役完成」並歸零

> **Epic**: 遊戲殼層 —— `production/epics/game-shell/EPIC.md`
> **Status**: ✅ Done-pending-visual(2026-10-27)—— AC1~AC5 有測試(`tests/integration/ui/shell/campaign_complete_test.gd` + campaign_progress 單元 2 條);「戰役完成」文字外觀待管理者目視
> **Layer**: Logic + Presentation
> **Type**: Logic(BLOCKING)+ UI 文字(ADVISORY,待管理者目視)
> **Estimate**: S
> **裁決依據**:管理者 2026-10-27,逐字選項「**顯示「戰役完成」後歸零(推薦)**」。
> 被跳過的三個:只靜默歸零 / 標題加「重新開始戰役」 / 先不處理。

## 為什麼存在

2026-10-27 戰役序列表第 2 列接上之後,玩家第一次打得到「最後一場」。
而打贏最後一場之後:自動回標題 → 按「開始」→ **又是最後一場,永遠重打**
(`CampaignProgress.advance_on_victory()` 在最後一場回 `CAMPAIGN_COMPLETE` 但不歸零;
沒有存檔,只有關掉遊戲重開才會歸零)。

## Acceptance Criteria

- **AC1**:最後一場(場次 == 序列表列數)勝利、且有注入戰役累積記錄時,結果文字顯示
  **「戰役完成」**(新鍵 `battle.hud.result_campaign_complete`),不是「勝利」。
  非最後一場勝利仍顯示「勝利」;失敗仍顯示「戰敗」。
- **AC2**:同一情況下,戰役狀態**歸零**:場次回到 1、累積記錄清空。下次從標題按「開始」從第 1 場開始。
- **AC3**:未注入累積記錄的 `BattleScreen`(絕大多數既有測試)行為逐字不變 —— 結果文字仍是「勝利」,不碰 `CampaignProgress`。
- **AC4**:歸零用一個**正式**的公開方法(不是借用 `reset_for_test()`)。
- **AC5**:新字串進 `strings.csv`,同步 `locale_data_integrity_test.gd` 檔尾的列數。

## 本 story 不涵蓋

- 結局畫面/劇情(那是劇情工作)。
- 存檔。

## Affected Files

`src/ui/battle/battle_screen.gd`、`src/core/campaign/campaign_progress.gd`、`assets/data/locales/strings.csv`、
`tests/unit/core/i18n/locale_data_integrity_test.gd`、`tests/integration/ui/battle/` 與 `tests/integration/ui/shell/` 底下相關/新增測試、
`tests/unit/` 底下 campaign_progress 相關測試。
