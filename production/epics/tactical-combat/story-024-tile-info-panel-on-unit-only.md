# Story 024:右上資訊框只在游標指到單位時出現

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: ✅ Done(2026-10-29,提交 `8a6750e`;協調者獨立重跑 1592 條全綠)—— ⚠️ 未實測項:敵方回合結束後資訊框是否立即回來,待開窗目視(原狀態:Ready(2026-10-29)—— 🔴 須在 story-023 交付後才開工(同一個檔))
> **Type**: UI
> **Estimate**: S
> **依據**: 管理者 2026-10-29 裁決,選項逐字「**只在游標指到單位時出現(推薦)**」;
> 被跳過:「移到棋盤外上方」、「游標在右半邊時自動移到左上」。
> 來源問題:`production/qa/playtest-report-2026-10-28.md` 第四節問題 A(截圖 01、05)。

> 📌 **2026-11-12 加註(管理者核准加註;原文一字未改)**:
> ① **AC5「框高隨內容」實際未做** —— `battle_screen.gd` 仍以常數 `_TILE_INFO_PANEL_LINE_COUNT` 寫死 8 行(有減傷列時 9)。
>   當場查:`grep -n "_TILE_INFO_PANEL_LINE_COUNT" src/ui/battle/battle_screen.gd`。本單標 Done 時此項未被驗出。
> ② **AC2「空地 → 隱藏」已被新裁決取代方向**:管理者 2026-11-12 裁決空格也要顯示地形,但**等畫面捲動完成後再做**
>   (玩家可自行挪地圖避開遮擋),且捲動須允許拉過地圖邊緣約一個資訊框的距離。在那之前本單行為不變。
>   出處:`production/session-state/active.md` 第九十九批節;選項分析 `docs/reviews/tile-info-and-attack-reason-options-2026-11-12.md`。

## 為什麼

1440×810 等「棋盤貼滿視窗」的尺寸下,右上資訊框常駐顯示,蓋住棋盤右上角的敵方棋子。
專案硬性約束:介面不得依賴棋盤旁有空位(`.claude/docs/technical-preferences.md`「畫面架構裁決」),
故採「平常隱藏、需要時才出現」。

## Acceptance Criteria

- [ ] **AC1** 游標(鍵盤/手把游標或滑鼠懸停)所在格**有單位**(敵我皆可)→ 資訊框顯示,內容同現行。
- [ ] **AC2** 游標所在格**沒有單位**(空地)→ 資訊框隱藏。
- [ ] **AC3** 手牌懸停顯示卡面說明(10/28 晚間加的 `_hover_hand_card`)**不受影響** —— 懸停卡片時框照樣顯示卡面。
- [ ] **AC4** 敵方回合中游標不動時,不得殘留顯示上一個單位的框(或依現行敵方回合規則;實作者查證現況並在報告寫明)。
- [ ] **AC5** 框高隨內容(報告問題 H):顯示時不留大片空白行。若此項會擴散到 `hud_layout.gd` 以外的版面計算,先做 AC1~4 並回報。
- [ ] 敏感度證明:AC1/AC2 各一條。

## Affected Files

`src/ui/battle/battle_screen.gd`、`src/ui/battle/hud_layout.gd`、新測試檔;斷言資訊框常駐的既有測試(逐一列在交付報告)。
