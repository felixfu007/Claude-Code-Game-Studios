# Spike: verify the Story 001 manual-scaling design before writing production code

> PROTOTYPE - NOT FOR PRODUCTION / 拋棄式技術驗證
> **日期**:2026-09-04
> **執行**:godot-specialist,本機直接執行 Godot 4.7.1(有實體 GPU,非 headless)

## 為什麼需要這支

`production/epics/screen-scaling/story-001-manual-world-scaling.md` 要求「取塞得下的最大整
數倍,永遠置中」,且世界層內部要維持 480x270(BoardView 的既有內容全部假設這個內部解析
度)。既有兩支 spike 沒有直接覆蓋這個組合:

- `prototypes/board-render-input-spike-2026-08-27/` 只驗證了 `canvas_items` 模式下滿版錨點
  的容器。
- `prototypes/ui-canvas-scale-spike-2026-09-01/` Scenario 2 驗證了 `disabled` 模式下手動
  `position`/`size`,但 `stretch_shrink` 全程維持預設值 `1`(容器多大,內部 SubViewport
  就渲染多大)——沒有測試「容器手動置中變形」與「`stretch_shrink>1` 讓內部畫布縮回
  480x270」**同時**發生會不會出錯。

這正是 Story 001 需要的組合,兩份既有 spike 都沒有直接驗證過,故不能只憑推論寫production code。

## 驗證什麼

1. 從 `project.godot` 移除 `display/window/stretch/aspect` / `scale_mode` 兩個鍵後,
   `ProjectSettings.get_setting()` 回傳什麼(空值?引擎預設值?)。
2. `WorldViewportContainer` 用 `anchors_preset=TOP_LEFT` + 手動 `position`/`size`
   + `stretch_shrink = 該解析度的整數倍率`,在 `content_scale_mode=DISABLED` 下,
   `WorldViewport.size` 是否仍精確等於 `(480, 270)`。
3. 畫在 `WorldViewport` 本地座標(480x270 空間)的內容,擷取實際畫面後,是否真的出現在
   數學算出來的、正確縮放、正確置中的螢幕位置上。
4. `WorldLayout`(打算寫進正式程式碼的那個 pure 工具類別,本檔逐字複製過來測)的
   `canvas_to_window_transform` / `window_to_canvas_transform` 是否互為反函數。

## 如何執行

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path .
```

（不加 `--headless` 執行——`DisplayServer.window_set_size()` 需要真實視窗建立流程。）

逐字輸出見 `run_output.txt`。

## 結果(全部通過,2026-09-04 實測)

### 1. ProjectSettings 移除鍵探針

```
aspect has_setting=true value=keep
scale_mode has_setting=true value=fractional
```

**移除鍵不會讓 `get_setting()` 回傳空值** —— 引擎會回退到該設定鍵自己的內建預設值。
`aspect` 的預設剛好也是 `"keep"`(與本專案原本手動設定的值一致,巧合);
`scale_mode` 的預設是 `"fractional"`,**不是**本專案原本手動設定的 `"integer"`。
兩者在 `mode="disabled"` 下都不影響任何畫面行為(已由本次量測的 4 種解析度全部
正確驗證),但如果要在測試裡斷言這兩個鍵的值,現在有實測數字可以斷言,不必用猜的。

### 2+3. 四種解析度,`viewport.size` 恆等於 480x270,標記全部落在正確位置

| 解析度 | 倍率 | 容器位置 | `WorldViewport.size` | 左上標記取樣 | 右下標記取樣 | 背景取樣 | 邊區取樣(有邊區時) |
|---|---|---|---|---|---|---|---|
| 1080p | 4 | (0,0) | **(480,270)** ✅ | 紅 ✅ | 藍 ✅ | 綠 ✅ | 無邊區 |
| 2K | 5 | (80,45) | **(480,270)** ✅ | 紅 ✅ | 藍 ✅ | 綠 ✅ | (0.298,0.298,0.298)——引擎預設清除色,非世界層內容 ✅ |
| 4K | 8 | (0,0) | **(480,270)** ✅ | 紅 ✅ | 藍 ✅ | 綠 ✅ | 無邊區 |
| 超寬 3440×1440 | 5 | (520,45) | **(480,270)** ✅ | 紅 ✅ | 藍 ✅ | 綠 ✅ | (0.298,0.298,0.298) ✅ |

四種解析度的倍率/矩形與 `design/art/screen-architecture.md` 的裁決表完全一致
(4×/5×/8×/5×,2K 與超寬的邊區數字亦一致)。**`stretch_shrink` 與手動
`position`/`size` 同時作用,沒有互相干擾** —— 這正是本次要驗證、兩份既有 spike
都沒覆蓋到的組合。

### 4. Transform 互逆

12 組來回換算(4 解析度 × 3 個測試點)全部 `match=true`(其中一組因浮點誤差顯示
`478.9999` 而非 `479.0`,`is_equal_approx` 判定仍為 true,屬正常浮點雜訊)。

## 已知簡化

- 全程用 `DisplayServer.window_set_size()` 觸發 resize,依循既有 spike 的量測慣例;
  沒有測試真人拖曳視窗邊框的路徑(理由與既有 spike 相同:無真人操作環境)。
- 沒有測試視窗縮小到低於 480×270 的邊界(該邊界已由管理者裁決 `min_size=960x540`
  在引擎層解決,見 `prototypes/story-010-headless-resolution-probe-2026-09-04/`)。
- 標記取樣點刻意避開縮放格線邊緣(每個標記內縮 2px 取樣),避免整數縮放邊界的取樣
  歧義,不代表格線邊緣本身有問題。

## 狀態

**已完成(2026-09-04)**。設計在寫入正式程式碼前已通過驗證,可以按此設計實作
`src/ui/battle/world_layout.gd` 與世界層容器的縮放腳本。

## 追加(同日,實作過程中另外驗證的兩個問題)

### `settings_probe/check.gd` — project.godot 移除 aspect/scale_mode 兩鍵後 ProjectSettings 回傳什麼？

用途與結果已併入本檔「結果」節第 1 小節（`aspect` 回退引擎預設 `keep`，
`scale_mode` 回退引擎預設 `fractional`，兩者皆 `has_setting()=true`，不是空值）。

### `verify_minsize_clamp.gd` — 設定 `Window.min_size` 高於視窗「當下」尺寸會怎樣？

**發現：立即把 `size` 夾到新的 min_size，不是只影響之後的 resize。** 逐字輸出：

```
before min_size set: root.size = (480, 270)
after min_size=960x540 set:  root.size = (960, 540)
```

**用途**：這個發現直接推翻了 `tests/unit/ui/battle_screen_mouse_coords_test.gd`
原本一條「測 1x（480x270）」的測試——`world_viewport_scaler.gd` 的 `_ready()`
一設 `min_size=(960,540)`，任何小於它的視窗尺寸會被立即夾起來，1x 因此是
結構性不可達的狀態，不是可以拿來測試的正常路徑。已改測真正可達的最小值
960x540（scale=2）。
