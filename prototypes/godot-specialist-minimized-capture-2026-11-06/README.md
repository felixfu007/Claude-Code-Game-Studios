# 最小化開窗取像素查證(2026-11-06)

**假說**:Godot 4.7.1 以最小化狀態開窗(`display/window/size/mode=1`)、`--audio-driver Dummy`,能否取到真實像素。
**狀態**:已結論(負面)。拋棄式空白專案,未載入本遊戲任何場景/資源。
**執行**:`timeout 30 <console.exe> --audio-driver Dummy --path <本資料夾>`,原始輸出在 `run_output.txt`。

## 結論
**最小化拿不到像素:腳本在 `_ready()` 等 6 個 process_frame 加一次 `RenderingServer.frame_post_draw` 之後才會讀圖,
但這段等待從未結束,行程跑到 `timeout 30` 被砍(ENGINE EXIT=124),`get_image()`、8 點比對、音訊驅動印出全都沒有執行。**

⚠️ 沒有量到的事(不代填成因):卡住的是 6 個 `process_frame` 還是 `frame_post_draw`,本次沒有區分。
(合理假說為最小化視窗不繪製、`frame_post_draw` 不觸發,但**未驗證**。)依指示未再嘗試其他開窗方式或診斷。

## 原始輸出行(`run_output.txt`)
```
INIT_WINDOW_MODE=1
ENGINE EXIT=124
```
- `INIT_WINDOW_MODE=1`:`_init()` 時 `window_get_mode()` 讀回 1(MINIMIZED),最小化設定有生效。
- 之後沒有任何 `WINDOW_MODE_READBACK` / `IMAGE_IS_NULL` / `CHECK` / `RESULT` 行。
- 音訊驅動名稱原文:**未取得**(腳本在等待處卡住;引擎啟動輸出只有 Godot 版本行與 `Vulkan 1.4.325 - Forward+ - Using Device #0: Intel - Intel(R) Graphics`,沒有印音訊驅動名稱)。

## 過程揭露
- 第 1 次執行:我的腳本寫了 `quit()`(應為 `get_tree().quit()`),Parse Error,視窗未實際跑到腳本。已修正。
- 第 2 次執行:即上述結果。共 2 次引擎啟動,第 2 次才是有效量測。
- 跑完 `tasklist | grep -i godot`:無輸出(grep rc=1),無殘留行程。

## 檔案
`project.godot`、`Probe.tscn`、`probe_main.gd`、`run_output.txt`
