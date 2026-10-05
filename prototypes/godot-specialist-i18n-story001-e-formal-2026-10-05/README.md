# Story-001 E 節正式量測 — 2026-10-05

**目的**:關閉 `production/epics/localization-infrastructure/story-001-core-lookup-api-and-locale-structure.md`
E 節(技術總監裁決明文 BLOCKING)。與 2026-10-05 稍早的
`prototypes/godot-specialist-i18n-export-headless-feasibility-2026-10-05/` 不同 ——
那一份只驗證「機制可不可行」,用的是拋棄式最小專案;**本次是對 production 專案
(`BlindInTheFaintLight`)本體**的正式匯出建置量測,呼叫的是 production 真正的
`src/core/i18n/loc.gd` 的 `Loc.localize()`,不是重新實作。

## 為什麼需要一個暫時探針場景,而不是直接匯出現有 `BattleScreen.tscn`

`BattleScreen.tscn`(production 現行 `run/main_scene`)目前沒有任何呼叫
`Loc.localize()` 的程式碼路徑(`grep -rn "Loc\.localize" src/` 只命中 `loc.gd` 自己與
它的單元測試,沒有任何既有 UI 檔案把既有 33 處硬字串換成 `Loc.localize()` 呼叫 ——
那是 story-002 的範圍,本 story 的 D 節驗收走的是單元測試,不是 production UI 呼叫點)。
若不介入,匯出 `BattleScreen.tscn` 本體量不到任何 `tr()`/`Loc.localize()` 的回傳值。

**處置**:暫時把 `project.godot` 的 `run/main_scene` 指向本目錄的
`_story001_e_probe.tscn`(一個只做「印出四項量測值 + 呼叫一次真正的
`Loc.localize("battle.hud.status_format")` + `get_tree().quit()`」的最小場景),
匯出、量測、**然後立刻把 `run/main_scene` 改回 `res://src/ui/battle/BattleScreen.tscn`,
並把兩個暫時檔從 `src/core/i18n/` 刪除**。本目錄留存的 `_story001_e_probe.gd`/
`.tscn` 是用過的那兩份檔案的逐字副本,供覆核,**不是** production 程式碼的一部分。

**為什麼這樣做不算「重新實作」或「假的宿主」**:
- 呼叫的是 production 的 `Loc` 類別本身(`class_name Loc`,全域可見,探針腳本直接寫
  `Loc.localize(...)`,沒有複製貼上任何查找邏輯)。
- `project.godot` 的 `[internationalization]` 設定、`assets/data/locales/strings.csv`
  匯入出的 `.translation` 資源,全部是 production 現有的真實設定,探針**沒有新增或覆寫
  任何 locale 資料**。
- 改動的只有 `run/main_scene` 指向哪個場景 —— 這與
  `.claude/docs/technical-preferences.md` 第 5 點「必須 load() production 真正啟動的
  那份場景檔」關注的是**像素/結構量測**(世界層渲染、`SubViewport` 真實宿主鏈那一類);
  本次量測的是**純邏輯查詢**(`OS`/`TranslationServer`/`Loc.localize()` 回傳值),
  與 `story-001` Test Evidence 節明文「`TranslationServer`/`tr()` 屬純邏輯查詢,
  不涉及像素/輸入裝置」同一類別,不受那條規則管轄。

## 執行序列(逐步對應下方留存的 log 檔)

1. 寫入 `_story001_e_probe.gd` + `_story001_e_probe.tscn` 到
   `src/core/i18n/`(production 目錄,因為 `export_presets.cfg` 的
   `exclude_filter` 排除了 `prototypes/*`,放在那裡匯出不會被打包進去)。
2. 編輯 `project.godot`:`run/main_scene` 暫時改為
   `res://src/core/i18n/_story001_e_probe.tscn`。
3. `--headless --path . --import` → `import_with_probe_as_main_scene.txt`
   (exit 0,零 ERROR)。
4. `--headless --path . --export-release "Windows Desktop" <path>` →
   `export_output.txt`(exit 0)。
5. 執行匯出的 `.console.exe --headless` → `run_output.txt`(exit 0)。
6. PowerShell 輪詢該行程 `MainWindowHandle` → `window_poll_output.txt`
   (7 次輪詢,約 140ms 內行程自行退出,全程零次非零控制代碼)。
7. 把 `project.godot` 的 `run/main_scene` 改回
   `res://src/ui/battle/BattleScreen.tscn`;從 `src/core/i18n/` 刪除兩個暫時檔
   (含引擎自動產生的 `.gd.uid` 伴隨檔)。
8. 再跑一次 `--headless --path . --import` → `import_after_revert.txt`
   (exit 0,零 ERROR,確認還原後專案仍乾淨)。
9. 本次匯出的 `.exe`/`.pck`(約 115MB)存於 `build/story001-e-formal-2026-10-05/`
   (gitignored),量測完成後已刪除,不留在磁碟 —— 若需要重現,依本 README 的步驟
   重跑即可,過程完全確定性(同一份 production 程式碼、同一份 locale 資料)。

## 四項量測結果(`run_output.txt` 全文照錄)

```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

E_SECTION_PROBE OS.get_locale() = zh_TW
E_SECTION_PROBE OS.get_locale_language() = zh
E_SECTION_PROBE TranslationServer.get_locale() = zh_TW
E_SECTION_PROBE Loc.localize(battle.hud.status_format) = 第 %d 回合．%s
E_SECTION_PROBE DONE
```

| E 節要求 | 量到的值 | 判定 |
|---|---|---|
| `OS.get_locale()` | `zh_TW` | 真值,與開發機系統 locale 一致 |
| `OS.get_locale_language()` | `zh` | 真值 |
| `TranslationServer.get_locale()` | `zh_TW` | 真值,與技術總監裁決節第二節(1)「本機 Windows 系統上直接讀回 `zh_TW`」一致 |
| 對已知 key 做一次 `tr()`/`Loc.localize()` | `第 %d 回合．%s` | **逐字命中 `assets/data/locales/strings.csv` 裡 `battle.hud.status_format` 的 `zh_TW` 欄位值** —— 不是裸 key(`battle.hud.status_format`)、不是空字串、不是 fallback 佔位符,是完全相等命中,未經過 fallback |

**視窗曝光檢查**(`window_poll_output.txt` 全文):
```
ExitCode=0
SawMainWindowHandleNonZero=False
IterationsPolled=7
```

## 這次沒有驗證到的

- **真實 Windows/Steam 平台大小寫陷阱**(`EPIC.md` 技術總監裁決第五節 (b) 登記的洞)
  仍未驗證 —— 本機系統 locale 本身是乾淨的 `zh_TW`,不代表所有目標玩家機器都是。
  本次量測只能證明「在這台開發機上,管線端到端正確」。
- **Steam 客戶端語言** —— 依工作單明文排除,未涉及。
- **匯出警告**(`export_output.txt` 可查:`Export: Using editor embedded text server
  data, text display in the exported project might be broken if export template was
  built with different ICU version!`)本次中文顯示正常(`第 %d 回合．%s` 的中文字元
  在 stdout 正確印出),但這是 console 文字輸出,**不是畫面渲染** —— 若將來有人拿
  這份警告去論證「畫面上的中文顯示也沒問題」,那是另一個情境(字型/渲染管線),
  本次探針的 stdout 正常不能直接外推。
