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

分層後表面上存在兩套座標系(世界層 `SubViewport` 內部座標 vs 外層 UI 的主 viewport 座標)。
**曾擔心 ADR-0005 的「單一根 Viewport 假設」因此不成立 —— 已實測回答:條件成立。**

🔴 **但它收斂成兩條紀律要求,不是「沒事了」。寫座標換算前必讀:**

1. **世界層容器以滿版錨點貼齊基準畫布**,起點恆為 `(0,0)`。
2. **換算一律呼叫引擎的 `Window.get_final_transform()`,絕不自己重刻**
   `stretch`/`keep`/`integer` 公式 —— 手刻公式在非 16:9 視窗會**悄悄算錯而不報錯**。

兩條同時滿足時,數學上收斂成單一仿射變換加一個固定位移,呼叫端只需一條轉換公式。
證據:`prototypes/board-render-input-spike-2026-08-27/`、
`prototypes/ui-canvas-scale-spike-2026-09-01/`。

## 命名慣例

場景/prefab 用 PascalCase 對應根節點名稱(例如 `GameRoot.tscn` 根節點 `GameRoot`)。
