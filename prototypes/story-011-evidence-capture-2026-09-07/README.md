# Story 011 擷圖證據 driver

> PROTOTYPE - NOT FOR PRODUCTION / 拋棄式證據擷取驅動,不是完整戰棋系統實作
> **日期**:2026-09-07
> **執行者**:godot-specialist,本機直接執行 Godot 4.7.1(有實體 GPU,非 headless)

## 用途

驗證 `production/epics/cursor-highlight-state/story-011-native-cursor-suppression.md`
的 AC-28c / AC-41 / AC-41b(GDD 原文即定為 Visual/Feel 類、screenshot + lead
sign-off、ADVISORY 等級證據),以及硬性義務「必須包含一次真的開著視窗、用眼睛看畫面的
檢查」。**這些需要真的開視窗擷取,headless 沒有渲染目標可擷取。**

## 做法

`evidence_driver.gd` 直接載入正式場景 `res://src/ui/battle/BattleScreen.tscn` 本體
(不是複本、不是重新實作)當背景,另建一個獨立的 `CanvasLayer` 疊在上面,裡面放
**與正式 `cursor_state_host.gd` 完全相同的兩個類別**
(`SelfDrawnReclaimCursor`、`NativePointerVisibilityArbiter`),但由 driver 自己建構的
`CursorState` + `ThresholdMouseReclaimPolicy` 驅動——理由見
`production/qa/evidence/native-cursor-suppression-evidence.md` 的「為何 driver 自己建
一份」段落(核心原因:ADR-0005 機制六的自動逐幀呼叫是 Story 005 的 SEAM,今天是空的,
且伸手進 Autoload 私有欄位驅動會命中已登記的禁令
`external_access_to_cursor_reclaim_instance`)。

以 `Input.warp_mouse()` 真實移動 OS 滑鼠到三個位置(0px / 32px / 80px,門檻 80px),
在 driver 自己持有的 `policy` 上呼叫對應的 `reset()`/`evaluate()`,每個位置擷取一張
`get_viewport().get_texture().get_image()`,存檔前先做
`.claude/docs/coding-standards.md` Screenshot Evidence Rules 的多點抽樣與主導色佔比
檢查,不通過就不寫檔。

## 如何執行

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . prototypes/story-011-evidence-capture-2026-09-07/EvidenceDriver.tscn
```

`--path .` 指向主專案根目錄,借用主專案當下的真實設定,不會動到 `project.godot` 本身
(比照 `prototypes/story-001-ac-s001c-evidence-capture-2026-09-04/` 的既有慣例)。

## 環境確認(開視窗前的獨立探針,非本 driver 一部分)

開發機的自動化 shell 環境是否真能開出可見 GUI 視窗,先用拋棄式 PowerShell 探針
(未進版控)確認過:非 headless 啟動 Godot 專案後,以 Win32 `EnumWindows` +
`GetWindowThreadProcessId` + `IsWindowVisible` + `GetClassName` 逐輪輪詢,
0.5 秒即偵測到 `class='Engine'` 的可見視窗(`clientRect=768x432`,與本機 125% 顯示縮放
下 960x540 的已知虛擬化關係一致,見 `tools/build/capture_window.ps1` 檔頭的既有記載)。
**結論:這個環境開得出真實可見的 GUI 視窗**,不是只能 headless。

## 結果

見 `run_output.txt` 逐字輸出,以及
`production/qa/evidence/native-cursor-suppression-evidence.md`(正式證據文件,含機械
檢查數字、三件事逐項人眼確認記錄、以及 `Input.mouse_mode` 真實值的引擎級佐證)。

## 狀態

**已完成(2026-09-07)**。AC-28c / AC-41 / AC-41b 的視覺證據與「開視窗用眼睛看」義務皆已
交付。
