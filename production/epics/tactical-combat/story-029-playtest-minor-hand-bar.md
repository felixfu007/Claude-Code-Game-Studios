# Story 029:試玩次要問題(手牌列)—— E / F

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: ✅ Done-pending-visual(2026-10-29,提交 `1420179` + G 補 `1e4bff5`;協調者重跑 1643 條全綠)—— F 仍壓最下列右端 3 格(1080p 滿版)(原狀態:Ready(2026-10-29)—— 🔴 **須在 story-028 交付後才開工**(兩者都會碰 `hud_layout.gd`))
> **Type**: UI
> **Estimate**: S
> **依據**: 同 story-028,管理者 2026-10-29 裁決「**E/F/G/I/M/N/O 照建議做,K/L 先不動(推薦)**」。
> 來源:`production/qa/playtest-report-2026-10-28.md` 第四節 E、F(截圖 01、02、03、05)。

## Acceptance Criteria

- [ ] **E1** 展開手牌時,深色背板矩形須涵蓋展開後全部卡片的範圍(不再是一條與卡片錯位的橫帶)。
- [ ] **E2** 菱形卡與相鄰卡片不得互相重疊:改為**不旋轉的方形卡 + 卡面菱形圖示**(報告建議)。若「菱形卡」承載了某種規則意義(例:卡片類別),實作者查證並在回報寫明,不得刪掉那個資訊。
- [ ] **F** 收合狀態的手牌不得壓到棋盤最下一列中間的格子:再縮小、或移到底部說明列左側(實作者擇一並寫明理由;須在 1440×810、1920×1080、960×540 三種尺寸都成立,以 `HudLayout` 現行函式計算矩形)。
- [ ] 10/28 晚間的「收合半尺寸、選牌時恢復原尺寸」行為不變。
- [ ] **N(2026-10-29 併入,管理者裁決「要,併入手牌列那張(story-029)一起做(推薦)」)** 選單開著時,`src/ui/menu/battle_menu.gd` 的 `_egm_status_label`(「效果猜測標記:關閉」)不得疊在手牌背板上。story-028 實作者建議:移進選單面板內部或面板上方。
- [ ] **G 補(2026-10-29,管理者裁決「接受,但單行改留「移動/確認/取消/選單」(推薦)」)** story-028 的單行說明列(`HudLayout.compact_hint_text()`,倍率 N≤2 時)目前只留「移動/確認」,改為留「移動/確認/取消/選單」四項;四項放不下時,回報實測寬度再決定,不得自行刪減。
- [ ] 每項至少一條結構測試(矩形包含/不相交),有前提斷言;敏感度證明 E1、F 各一條。

## Affected Files

`src/ui/battle/hand_bar.gd`、`src/ui/battle/HandBar.tscn`、`src/ui/battle/hud_layout.gd`、`src/ui/menu/battle_menu.gd`(N,10/29 裁決擴大)、`tests/integration/ui/battle/battle_screen_story_028_minor_hud_test.gd`(G 補的斷言)、新測試檔;斷言舊版面的既有手牌/選單測試(逐一列在回報)。
