# src/ui/

Control 節點、CanvasLayer、螢幕/畫面類程式碼與場景的落點。

## 放什麼

- HUD、對話介面、戰鬥介面
- 游標/高亮狀態系統(對應 ADR-0005,目前仍 `Proposed`,1609 行、四次修訂,
  是否凍結未決——引用它的正式開發前請先確認狀態)
- 世界層/介面層分層的根場景(`GameRoot.tscn`)——這份场景同時掛了世界層的
  `SubViewportContainer` 與 UI 層的 `CanvasLayer`,放在這裡是因為它的主要職責是
  「畫面分層」這件 UI 基礎設施的事,不是玩法邏輯;世界層底下真正的棋盤/單位內容
  仍應是 `src/gameplay/` 的場景,只是被 instance 進來當 `SubViewport` 的子節點

## 已知的跨文件未決問題

分層後畫面同時存在两套座標系(世界層 `SubViewport` 內部座標 vs 外層 UI 的主 viewport
座標),轉換係數隨螢幕尺寸/`stretch_shrink` 變動。若 ADR-0005 假設全螢幕僅一套座標系,
該假設不成立——見 `.claude/docs/technical-preferences.md`「美術方向與像素風專案設定」節。

## 命名慣例

場景/prefab 用 PascalCase 對應根節點名稱(例如 `GameRoot.tscn` 根節點 `GameRoot`)。
