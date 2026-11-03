# Story 004:介面蓋到棋盤 —— 指到才變淡 + 一鍵隱藏 + 說明列一律單行

> **Epic**: `production/epics/battle-hud/EPIC.md`
> **Status**: Ready(2026-11-03)
> **Type**: UI
> **Estimate**: M
> **依據**:
> - 管理者裁決逐字(2026-11-03):「指到才變淡+一鍵隱藏(推薦)」(被跳過:只做一鍵隱藏 / 介面依游標自動換邊)
> - 方案全文:`docs/reviews/hud-board-overlap-options-2026-11-03.md`(ux-designer)A 案 + B 案;資訊框本輪不單獨處理(提案第五節第 3 題,協調者依推薦採用)
> - 說明列單行:`docs/reviews/hint-bar-single-line-art-decision-2026-11-03.md`(art-director 依管理者常設授權決定)—— **推翻** tactical story-028 G 的「較大視窗行為不變」

## 為什麼

1080p/4K 棋盤滿版、邊區為零,介面只能疊在棋盤上(`.claude/docs/technical-preferences.md`「畫面架構裁決」)。實測四處重疊:底部說明列蓋最下一列、收合手牌擋右下、左上計數/關係圖按鈕蓋我方、右上資訊框。

## Acceptance Criteria

- [ ] **AC1 變淡** 當「目前高亮格」(鍵盤/手把/滑鼠共用的那一格,**不是**滑鼠螢幕座標)的格子矩形與某介面框矩形重疊時,該框降到約 30~40% 不透明度;離開即恢復。至少涵蓋:收合手牌、左上計數 + 關係圖按鈕、底部說明列。資訊框不在本 AC 範圍。
  - 重疊判斷放在可單元測試的純函式(建議 `HudLayout` 旁),輸入矩形、輸出布林;框的矩形一律取自既有 `HudLayout`/`HandBar` 的真實矩形函式,不得另算一份。
- [ ] **AC2 一鍵隱藏** 新增一個輸入動作,切換「隱藏全部戰鬥介面 / 恢復」;鍵盤與手把各一顆(實作者選未被佔用的鍵,回報中寫明;注意 4.7 裝置 ID 重編號,見 `docs/engine-reference/godot/breaking-changes.md`)。隱藏期間棋盤游標與選取照常運作;任何會開新面板的操作(開手牌、開選單)自動恢復介面。
- [ ] **AC3 說明列單行** 所有倍率 N 一律走單行(現行只在 N≤2),沿用 `HudLayout.compact_hint_text()`;更新斷言「大視窗為兩行」的既有測試。回報 1920×1080、2560×1440、3840×2160 三種尺寸下單行實際放進幾項。
- [ ] **AC4** 新增測試:三種尺寸下說明列矩形不與棋盤最下一列格子矩形重疊(結構斷言,headless 可)。
- [ ] **AC5** AC1、AC2 各至少一條測試與一條敏感度證明(故意改壞 → 變紅 → 還原;還原後掃一次注入標記)。
- [ ] **AC6** 960×540 與既有小視窗畫面除 AC1 變淡外**行為不變**。

## 不在範圍

- 資訊框換邊或變淡;展開態手牌;C 案自動換邊。
- 開窗目視(公司不能開遊戲畫面;交管理者在家)。

## Affected Files(可直接改)

`src/ui/battle/hud_layout.gd`、`src/ui/battle/hand_bar.gd`、`src/ui/battle/battle_screen.gd`、`project.godot`(僅 `[input]` 新增一個動作)、`assets/data/locales/strings.csv`(若說明列需列出新鍵)、對應 `tests/` 檔。超出清單先停下回報。
