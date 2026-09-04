# Story 001（screen-scaling:世界層手動縮放定位）測試證據

**Story Type**：Integration
**日期**：2026-09-04
**執行者**：godot-specialist

## AC-S001-a（倍率正確）— 自動化測試涵蓋

`tests/unit/ui/world_layout_test.gd`，四種解析度（1080p/2K/4K/超寬）逐一斷言
`WorldLayout.compute_scale()` 等於裁決表的 4x/5x/8x/5x，另外斷言
`WorldLayout.compute_rect()` 的世界層尺寸與裁決表一致。純函式測試，headless 可跑。

## AC-S001-b（永遠置中）— 自動化測試涵蓋

同一檔案：四種解析度逐一斷言左右邊區相等、上下邊區相等（含 1080p/4K 的零邊區案例）。

## AC-S001-c（不再有引擎未涵蓋的黑邊）— 真實視窗擷圖，已完成

**這一條需要真的開視窗擷取畫面**（headless 沒有渲染目標可擷取）。

### 擷取方式

`prototypes/story-001-ac-s001c-evidence-capture-2026-09-04/EvidenceDriver.tscn`
（拋棄式驅動場景，**直接載入正式場景 `res://src/ui/battle/BattleScreen.tscn`
本體，不是複本**），以
`godot --path . prototypes/story-001-ac-s001c-evidence-capture-2026-09-04/EvidenceDriver.tscn`
執行（真實 GPU、非 headless；`project.godot` 此時已是本張改完的最終狀態，
`window/stretch/mode="disabled"`）。流程：把正式場景掛進 `get_tree().root`、
`DisplayServer.window_set_size(2560, 1440)`、等待數個 frame 讓佈局穩定、
`get_viewport().get_texture().get_image()` 擷取、存檔為
`production/qa/evidence/screen-scaling-2k-window-capture-2026-09-04.png`。

### 機械檢查（`.claude/docs/coding-standards.md` Screenshot Evidence Rules）

| 檢查項 | 門檻 | 實測值 | 結果 |
|---|---|---|---|
| 擷圖尺寸 = 視窗尺寸 | 2560×1440 | **2560×1440** | ✅ 通過（舊 `canvas_items` 模式下會是 2400×1350） |
| 12 點抽樣相異色數 | ≥ 3 | 5 | ✅ 通過 |
| 主導色佔比 | ≤ 80% | 45.32%（每 4px 全圖抽樣） | ✅ 通過 |
| PNG 檔頭實際尺寸（協調者獨立覆核） | 2560×1440 | 2560×1440 | ✅ 通過 |

逐字輸出：`prototypes/story-001-ac-s001c-evidence-capture-2026-09-04/run_output.txt`

### 人眼確認（規則第 5 條，機械檢查不能取代）

**已由本 agent 用 Read 工具開圖檢視、並由協調者獨立打開圖檔覆核確認**：畫面確實是
真實戰鬥畫面（回合狀態列文字、13×6 地形含灌木/倒木、我方五色單位方塊與敵方深紫
單位方塊、每個單位下方的綠色血條、操作提示文字），不是空白幀、不是開機畫面。

⚠️ **同一張圖也是下方「本張造成的介面圖層退化」段落的直接證據** —— 圖中可見操作
提示深色橫條縮在左上角一小塊,而非原設計的螢幕底部滿版橫條,見
`production/session-state/screen-scaling-story-001/PROGRESS.md`與最終回報的獨立段落。
**這是本張範圍外、Story 002 負責的已知後果,不是本次擷圖或縮放邏輯的缺陷** ——
世界層本身（棋盤地形、單位、血條）的縮放與置中在同一張圖裡是正確的。

### 邊界精確性交叉覆核

`WorldLayout`/`world_viewport_scaler.gd` 的置中數學已在
`prototypes/story-001-manual-scaling-verification-2026-09-04/`（獨立、乾淨的最小場景，
無 UI 層干擾）用像素級標記逐一驗證四種解析度全部正確（見該目錄 README）。
本次 `BattleScreen.tscn` 實機擷圖引用的是**同一份** `world_viewport_scaler.gd`
（`res://src/ui/battle/world_viewport_scaler.gd`，非複本），故邊界數學的正確性
由那份 spike 覆蓋，本次擷圖只需另外證明 AC-S001-c 本身（擷圖尺寸=視窗尺寸）與
「正式場景真的接上了這份腳本、畫面看起來是遊戲」這兩件事。

## 已知未涵蓋

- 沒有測試真人拖曳視窗邊框改變尺寸的路徑（沿用既有 spike 的一貫揭露：無真人操作環境）。
- 沒有對全螢幕切換路徑（fullscreen toggle）另外驗證。
- 介面圖層（UILayer 底下的 5 個節點）的正確排版不在本張驗證範圍內 —— 見最終回報
  「本張造成的介面圖層退化」段落，該問題留給 Story 002。
