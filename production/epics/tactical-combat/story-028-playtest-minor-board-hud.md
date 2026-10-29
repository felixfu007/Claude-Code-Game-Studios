# Story 028:試玩次要問題(棋盤與 HUD)—— I / M / G / N / O

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: ✅ Done-pending-visual(2026-10-29,提交 `42ef85a`;協調者重跑 1628 條全綠)—— I/M/G/O 完成;N 併入 story-029(原狀態:Ready(2026-10-29))
> **Type**: UI
> **Estimate**: M
> **依據**: 管理者 2026-10-29 裁決,選項逐字「**E/F/G/I/M/N/O 照建議做,K/L 先不動(推薦)**」;
> 被跳過:「全部照建議做(含 K/L)」、「先不做,等我在家看完截圖排優先」。
> 來源:`production/qa/playtest-report-2026-10-28.md` 第四節(截圖在 `production/qa/evidence/playtest-2026-10-28/`)。
> ⚠️ 管理者**未先看截圖**,改完後在家一次目視;不滿意再改。

## Acceptance Criteria

- [ ] **I(移動範圍顏色)** 移動範圍由「深灰底藍框」改為**亮藍半透明**,與攻擊範圍的紅色半透明形成「藍=走、紅=打」。紅色攻擊範圍(`BoardView.THREAT_FILL_COLOR`)不變。顏色常數具名,不寫魔術數字。
- [ ] **M(按鈕可辨識)** 右下「手牌」「選單」按鈕(`HudLayout.hud_action_button_rect` 一帶)平常就顯示外框/底色,不必滑鼠移上去才看得出能按。
- [ ] **G(小視窗說明列)** 960×540(最小視窗)時底部說明列不得蓋住棋盤最下一列:小視窗時縮成一行(或依 `HudLayout` 現行倍率判斷)。較大視窗行為不變。
- [ ] **N(文字重疊)** 選單開著時,「效果猜測標記:關閉」那行字不得疊在手牌背板上(截圖 04)。實作者查證重疊成因並寫在回報。
- [ ] **O(敵方回合空框)** 敵方回合時,左側不得殘留空白游標方框(截圖 08、09)。
- [ ] 每項至少一條測試(結構斷言即可:顏色常數、按鈕樣式屬性、矩形不相交等),有前提斷言。
- [ ] 敏感度證明:I、G 各一條。

## Affected Files

`src/ui/battle/board_view.gd`、`src/ui/battle/battle_screen.gd`、`src/ui/battle/hud_layout.gd`、`src/ui/battle/hud_layout_scaler.gd`、`src/ui/battle/BattleScreen.tscn`、新測試檔;斷言舊顏色/舊版面的既有測試(逐一列在回報)。
**範圍外**:`hand_bar.gd`(E/F 在 story-029)。
