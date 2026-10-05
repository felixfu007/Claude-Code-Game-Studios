# i18n Export-Build Headless Feasibility — 2026-10-05

**目的**:回答 `story-001-core-lookup-api-and-locale-structure.md` E 節派工單的可行性評估
三題 —— 本機有無匯出範本、匯出建置能否 `--headless` 跑且四項 locale 讀值皆為真值、
若不行則退路選項為何。**本探針不是 E 節本身的正式驗收證據**(E 節要求的是對 production
專案真正匯出建置的量測,須在 Story 001 的 A/B/C 落地後,由 D 節 API 完成並至少一個
key 端到端可用時再正式執行)——這裡只驗證「機制本身是否可行」,用的是一個最小拋棄式
專案,不是 `BlindInTheFaintLight` 本體。

**驗證方式**:本機 `Godot_v4.7.1-stable_win64_console.exe`,於系統暫存目錄建立一個最小
拋棄式專案(`project.godot` + `main.tscn` + `main.gd` + 一份 `keys,zh_TW` 兩欄 CSV),
headless 匯入 CSV → headless 匯出 Windows Desktop release 建置 → 用 `--headless` 執行
匯出後的 `.exe` → 同時用 PowerShell 輪詢該行程是否曾經出現任何非零 `MainWindowHandle`。
**未觸碰專案根目錄的 `project.godot`、`export_presets.cfg` 或 `build/`** —— 匯出的
`.exe`/`.pck` 留在系統暫存目錄,未提交(太大且可重現);本目錄只留劇本、設定與原始
log,供覆核與重跑。

**(A) 級來源**:本目錄 `main.gd` / `main.tscn` / `project.godot` / `export_presets.cfg`
(皆為原樣留存,與實際執行的版本逐字相同)。
**原始輸出**:`import_output.txt`、`export_output.txt`、`run_exported_output.txt`、
`window_poll_output.txt`(皆為引擎/PowerShell 真實 stdout,未經整理或摘要)。

引擎路徑(本機專用):
`C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`

**狀態**:已結案(concluded)—— 三題皆有實機答案,見下方。

---

## 結論先講

1. **本機有現成的 Windows release 匯出範本**(`4.7.1.stable`,`windows_release_x86_64.exe`
   / `windows_release_x86_64_console.exe` 皆存在於 `%APPDATA%/Godot/export_templates/`),
   且本機先前已有一次 production 匯出建置(`build/windows/BlindInTheFaintLight.exe`,
   2026-09-15)證明匯出管線本身在本機可用。
2. **匯出建置可以帶 `--headless` 跑,且本次測試的四項對應內容全部讀到真值,完全命中
   `zh_TW` 翻譯,且全程沒有任何視窗出現。** 見下方「逐項結果」。
3. **因此第三題(最小曝光的退路選項)不需要動用** —— `--headless` 本身就是零曝光
   方案,不必等開發者回家、不必縮小視窗,直接可行。

---

## 逐項結果(`run_exported_output.txt` 全文照錄)

```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

FEASIBILITY OS.get_locale() = zh_TW
FEASIBILITY OS.get_locale_language() = zh
FEASIBILITY TranslationServer.get_locale() = zh_TW
FEASIBILITY tr(test_key) = 測試_zhTW_export
FEASIBILITY DONE
```

對照 story-001 E 節要求的四項:

| E 節要求 | 本次測得 | 判定 |
|---|---|---|
| `OS.get_locale()` 原始字串 | `zh_TW` | 讀到真值 |
| `OS.get_locale_language()` 原始字串 | `zh` | 讀到真值 |
| `TranslationServer.get_locale()` 原始字串 | `zh_TW` | 讀到真值 |
| 對已知 key 做一次 `tr()`,確認命中 `zh_TW` 那份翻譯 | `tr(test_key) = 測試_zhTW_export`,CSV 裡 `zh_TW` 欄位的值就是 `測試_zhTW_export` | 命中正確,非 fallback、非裸 key |

**視窗曝光檢查**(`window_poll_output.txt` 全文):

```
ExitCode=0
SawMainWindowHandleNonZero=False
IterationsPolled=8
```

以 20ms 間隔輪詢行程的 `MainWindowHandle`,直到行程自行退出(`get_tree().quit()`
在 `_ready()` 最後一行呼叫)為止,全程 8 次輪詢(約 160ms 內结束)**沒有任何一次
偵測到非零視窗控制代碼** —— 與 `--headless` 使用「null display server」的引擎架構
設計一致:這不是「碰巧沒看到」,而是結構性保證,headless 模式從未初始化任何視窗子系統。

---

## 做不到的部分 / 刻意未涵蓋

- **這不是對 `BlindInTheFaintLight` 本體的量測。** 真正的 E 節證據必須在 Story 001
  A/B/C 落地後(已完成,見 `project.godot` 的 `[internationalization]` 區塊與
  `assets/data/locales/strings.csv`),對 production 專案實際匯出一次建置、用相同手法
  量測,才能正式關閉 E 節。本探針只回答「機制本身可不可行」。
- **沒有測試 Steam 客戶端語言**(E 節原文已明講這一半留給未來的 Steam 整合工作單)。
- **匯出時引擎印出一則警告**,照錄:`Export: Using editor embedded text server data,
  text display in the exported project might be broken if export template was built
  with different ICU version!`(見 `export_output.txt`)。本次測試的中文字串
  (`測試_zhTW_export`)顯示正常,**但這是警告,不是本探針刻意驗證的項目**——
  若正式 E 節量測時中文顯示異常,這是第一個該查的方向。
- **沒有測試混合大小寫 / 真實 Windows 系統 locale 格式**(`EPIC.md` 技術總監裁決第五節
  (b) 登記的洞)—— 本探針的 `OS.get_locale()` 讀到的是本機開發機的真實系統 locale
  (`zh_TW`),不是人工輸入的測試值,但本機系統 locale 本身是否「乾淨」未知,這與
  `EPIC.md` 該洞的性質相同:只能在真實目標機器上才能窮盡。
