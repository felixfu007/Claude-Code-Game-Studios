# src/ui/

Control 節點、CanvasLayer、螢幕/畫面類程式碼與場景的落點。

## 放什麼

- HUD、對話介面、戰鬥介面
- 游標/高亮狀態系統(對應 ADR-0005,**2026-09-01 已 `Accepted`**)
  🔴 **兩條隨核准生效的硬性實作義務**:
  ①**游標圖層必須獨佔一顆 `CanvasLayer`**,不得與介面圖層共用 ——
    誤把兩者混成同一顆節點的實測誤差:1080p 1440px / 2K 2178px / 4K 3304px,游標系統實質失效。
  ②機制四之二**必須自行過濾 `InputEventKey.echo`** —— 引擎的 `event_is_action()` **不過濾**(已實測)。
- 世界層/介面層分層的根場景(`GameRoot.tscn`)—— 這份場景同時掛了世界層的
  `SubViewportContainer` 與 UI 層的 `CanvasLayer`,放在這裡是因為它的主要職責是
  「畫面分層」這件 UI 基礎設施的事,不是玩法邏輯;世界層底下真正的棋盤/單位內容
  仍應是 `src/gameplay/` 的場景,只是被 instance 進來當 `SubViewport` 的子節點

## ✅ 座標系疑慮已結案(原為「已知的跨文件未決問題」)

> 🔴 **本節退役,原文保留於下方 blockquote,理由是本專案的處置慣例是退役而非刪除。**
> 原文兩條紀律是 2026-08-27 spike 對 `window/stretch/mode = "canvas_items"` 這個模式的
> 結論。**2026-09-04(Story 001,screen-scaling epic)`window/stretch/mode` 改為
> `"disabled"` 後,兩條紀律賴以成立的前提雙雙消失** —— 世界層容器不再滿版貼齊
> (改為手動置中,見下一節),換算也不再有引擎自己的
> `Window.get_final_transform()` 可查(disabled 模式下引擎完全不做縮放)。
> **見下一節「世界層容器改為手動置中」,那裡的兩條紀律是本節的直接後繼,精神一致
> ——「不得自己重刻公式」這條規矩沒有放寬,只是唯一出處換了。**
>
> 原文(2026-08-27,已失效前提):
>
> > 分層後表面上存在兩套座標系(世界層 `SubViewport` 內部座標 vs 外層 UI 的主 viewport
> > 座標)。**曾擔心 ADR-0005 的「單一根 Viewport 假設」因此不成立 —— 已實測回答:
> > 條件成立。**
> >
> > 🔴 **但它收斂成兩條紀律要求,不是「沒事了」。寫座標換算前必讀:**
> >
> > 1. **世界層容器以滿版錨點貼齊基準畫布**,起點恆為 `(0,0)`。
> > 2. **換算一律呼叫引擎的 `Window.get_final_transform()`,絕不自己重刻**
> >    `stretch`/`keep`/`integer` 公式 —— 手刻公式在非 16:9 視窗會**悄悄算錯而不報錯**。
> >
> > 兩條同時滿足時,數學上收斂成單一仿射變換加一個固定位移,呼叫端只需一條轉換公式。
> > 證據:`prototypes/board-render-input-spike-2026-08-27/`、
> > `prototypes/ui-canvas-scale-spike-2026-09-01/`。

## 世界層容器改為手動置中(2026-09-04,Story 001 screen-scaling epic)

`design/art/screen-architecture.md` 2026-09-01 裁決:世界層縮放與定位改為**手動管理**
(取塞得下的最大整數倍,永遠置中),`window/stretch/mode` 改 `"disabled"`。這直接推翻
了上一節退役文字的兩個前提,但**紀律的精神沒有變,只是唯一出處換了**:

1. **世界層容器不再滿版錨點** —— `WorldViewportContainer`(`src/ui/battle/BattleScreen.tscn`)
   改用 `anchors_preset = TOP_LEFT` + 手動 `position`/`size`,由掛在該節點上的
   `world_viewport_scaler.gd` 每次視窗尺寸改變時重新計算並置中。**這是刻意的,不是
   退化** —— 見 `src/ui/battle/world_layout.gd`(`class_name WorldLayout`)的裁決依據。
2. **換算不再呼叫 `Window.get_final_transform()`,改呼叫 `WorldLayout`** ——
   `WorldLayout.canvas_to_window_transform()` / `window_to_canvas_transform()` 是現在
   唯一的出處。🔴 **「不得自己重刻公式」這條規矩沒有放寬**:原本的用意是「不要自己重新
   推導 `stretch`/`keep`/`integer` 這套引擎內部算法」,現在因為引擎不再做任何縮放,
   這段運算變成本專案自己寫的程式碼 —— 但正因為如此,**更不可以在呼叫端各自複製一份**,
   一律呼叫 `WorldLayout`,不得手刻。本專案已有「同一個公式兩份實作、只是今天答案一致」
   的登記案例(好感度與戰鬥模組的曼哈頓距離),這條規矩要防的正是同一件事。
   `BoardCoords`(`src/ui/battle/board_coords.gd`)的純函式簽章本身沒有變 —— 它一直是
   吃 transform 參數,不管 transform 從哪裡來;變的只是呼叫端傳什麼進去。

驗證依據:`prototypes/story-001-manual-scaling-verification-2026-09-04/`(真實 GPU、
非 headless,四種解析度,`WorldViewport.size` 恆為 480x270、擷圖尺寸恆等於視窗尺寸、
畫在世界層本地座標的內容確實出現在數學算出來的螢幕位置)。

## 命名慣例

場景/prefab 用 PascalCase 對應根節點名稱(例如 `GameRoot.tscn` 根節點 `GameRoot`)。
