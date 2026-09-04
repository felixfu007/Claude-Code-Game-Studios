# AC-S001-c 擷圖證據 driver

> PROTOTYPE - NOT FOR PRODUCTION / 拋棄式證據擷取驅動,不是完整戰棋系統實作
> **日期**:2026-09-04
> **執行者**:godot-specialist,本機直接執行 Godot 4.7.1(有實體 GPU,非 headless)

## 用途

驗證 `production/epics/screen-scaling/story-001-manual-world-scaling.md` 的
AC-S001-c:2560×1440 視窗下擷取整個畫面,影像尺寸必須等於視窗尺寸,而不是舊
`canvas_items` 模式下的 2400×1350。**這一條需要真的開視窗擷取,headless 沒有渲染
目標可擷取。**

## 做法

`evidence_driver.gd` **直接載入正式場景 `res://src/ui/battle/BattleScreen.tscn`
本體**(不是複本、不是重新實作),掛進 `get_tree().root`,呼叫
`DisplayServer.window_set_size(2560, 1440)`,等待數個 frame 讓佈局穩定,
`get_viewport().get_texture().get_image()` 擷取,存檔到
`production/qa/evidence/screen-scaling-2k-window-capture-2026-09-04.png`,
並就地做 `.claude/docs/coding-standards.md` Screenshot Evidence Rules 的多點抽樣
與主導色佔比檢查。

## 如何執行

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . prototypes/story-001-ac-s001c-evidence-capture-2026-09-04/EvidenceDriver.tscn
```

`--path .` 指向**主專案根目錄**,不是這個子資料夾自己的 project——這支 driver
沒有自己的 `project.godot`,刻意借用主專案當下的真實設定(`window/stretch/mode
="disabled"`)來驗證,而不是另開一個模擬環境。場景路徑當參數傳入,是 Godot
支援的「這次執行覆寫 `run/main_scene`」寫法,不會動到 `project.godot` 本身。

## 撞到的一個坑(過程記錄)

第一版在 `_ready()` 裡直接同步呼叫 `get_tree().root.add_child(battle_scene)`,
噴 `ERROR: Parent node is busy setting up children, add_child() failed`——
因為 root 當時還在處理「把這支 driver 自己掛進樹」這件事,不能在同一個回呼裡
再同步掛一個新的子節點。改成 `await get_tree().process_frame` 讓出一個 frame
再 `add_child()` 即解決。**這次失敗會安靜地留下一張「尺寸對、內容全空白」的
擷圖**(12 點抽樣相異色數量到 1、主導色佔比 100%)——如果沒有檢查抽樣結果,
只看「尺寸符合」就會誤判成功。修正後重跑,抽樣結果變成正常的 5 種相異色、
45.32% 主導色佔比。

## 結果

見 `run_output.txt` 逐字輸出,以及
`production/qa/evidence/screen-scaling-evidence.md`(正式證據文件,含機械檢查
數字與人眼確認記錄)。`verify_margin.gd` 是擷圖後另外對存檔的 PNG 做像素級
邊界抽樣的輔助腳本(用於釐清介面圖層退化現象時的除錯,不是 AC-S001-c 本身
要求的檢查——世界層邊界的像素級驗證由
`prototypes/story-001-manual-scaling-verification-2026-09-04/` 那支獨立、無 UI
干擾的最小場景覆蓋)。

## 狀態

**已完成(2026-09-04)**。AC-S001-c 尺寸層與內容真實性(人眼+機械雙重確認)皆已驗證。
