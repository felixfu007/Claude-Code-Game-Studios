# Story 025:勝利/戰敗改為畫面中央大字 + 半透明遮罩

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: ✅ Done-pending-visual(2026-10-29,提交 `568f3f7`;協調者重跑 1597 條全綠)—— 截圖 AC 延後,待管理者在家目視(原狀態:Ready(2026-10-29)—— 🔴 **須在 story-024 交付後才開工**(同一個檔))
> **Type**: UI
> **Estimate**: S
> **依據**: `production/qa/playtest-report-2026-10-28.md` 第四節問題 C 的建議;管理者 10/28 明言「明天開工我會照你這份報告修復跟調整」。
> ⚠️ 協調者註:本項**未經單獨的選項裁決**,依據是上面那句總括授權 —— 若管理者看了畫面不滿意,這是第一個可以撤的。

## 為什麼

截圖 09:「勝利」兩字小、壓在棋子上,狀態列仍寫「第 5 回合・我方行動」—— 看不出戰鬥已結束。

## Acceptance Criteria

- [ ] **AC1** 戰鬥結束(勝利/戰敗/戰役完成)時,畫面中央顯示結果文字,字級明顯大於 HUD 字(字級來源須走既有的 `HudLayout`/`WorldLayout.compute_scale()` 倍率,**不得自行算倍率**)。
- [ ] **AC2** 結果文字下方鋪滿版半透明遮罩,蓋住棋盤(含非 16:9 視窗的四角與邊緣)。
- [ ] **AC3** 狀態列不再顯示「第 N 回合・我方行動」;改顯示結果(或隱藏,實作者擇一並寫明)。
- [ ] **AC4** 結果文字**內容逐字不變**(story-022 的戰敗原因、戰役完成文字),既有斷言文字的測試全綠。
- [ ] **AC5** 結果顯示後的流程(支援對話 / 下一場 / 回標題)**行為不變**。
- [ ] 敏感度證明:AC1 或 AC2 至少一條。
- [ ] 截圖:1440×810 與 1920×1080 各一張勝利畫面,放 `production/qa/evidence/`(必須 `load()` 真實 `BattleScreen.tscn`,見 technical-preferences 第 5 點)。

## Affected Files

`src/ui/battle/battle_screen.gd`、`src/ui/battle/BattleScreen.tscn`(新增遮罩節點)、`src/ui/battle/hud_layout.gd`、新測試檔。
