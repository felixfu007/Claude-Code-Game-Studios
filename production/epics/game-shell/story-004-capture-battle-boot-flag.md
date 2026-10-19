# Story 004:直接開進戰鬥的啟動旗標(修復自動截圖證據)

> **Epic**: 遊戲殼層 —— `production/epics/game-shell/EPIC.md`
> **Status**: ✅ **Done(2026-10-19,協調者獨立重跑驗收)**
> **Layer**: Presentation + Tools
> **Type**: Logic(旗標判定有雙向測試)+ Tools(截圖工具文件)
> **裁決依據**:管理者 2026-10-19,逐字選項「**今天補,跟著 story-002 一起做(推薦)**」。
> 被跳過的兩個:「不補,人工多按一下就好」、「改天再說」。
> **📌 本工作單是【事後補寫】** —— 實作與裁決同日發生,工作單在交付後才落檔。

## 為什麼要有它

`story-001` 把 `run/main_scene` 改成 `TitleScreen` 之後,**匯出建置開機進標題畫面**,
而截圖工具 `tools/build/capture_window.ps1` **完全沒有輸入能力**:

```bash
grep -c "SendInput\|keybd_event\|mouse_event" tools/build/capture_window.ps1   # → 0
```

**自動截「戰鬥畫面」當 QA 證據這條路因此失效。** 這不是小事 ——
`.claude/docs/coding-standards.md` 明文記載:**本專案至今每一個畫面缺陷都是人開圖看到的,
自動檢查一次也沒抓到過**。截圖是那道人眼防線的輸入,不是裝飾。

## 做了什麼

- `TitleScreen.AUTO_START_BATTLE_FLAG = "--capture-battle"`。
- 判定抽成**純函式** `should_auto_start_battle(args: PackedStringArray) -> bool`,
  `_ready()` 呼叫 `should_auto_start_battle(OS.get_cmdline_args())`。
- **雙向測試**:有旗標會切、沒旗標不會(只測一邊等於沒測)。
- `tools/build/capture_window.ps1` 檔頭補上用法說明。

## 🔴 已知限制(實測,不是推論):**不要加 `--` 分隔符**

探針 `prototypes/godot-specialist-static-var-probe-2026-10-19/`,逐字:

```
不帶 -- :  get_cmdline_args()      = ["-s", "...", "--capture-battle"]
           get_cmdline_user_args() = []
帶 -- :    get_cmdline_args()      = ["-s", "..."]              ← 旗標不在這裡
           get_cmdline_user_args() = ["--capture-battle"]        ← 跑到另一個 API
```

**`exe -- --capture-battle` 會安靜地什麼都不做,不會報錯。**
截圖工具用的是 `exe --capture-battle`(無分隔符),該形式下行為正確。
**日後若要支援 `--` 形式,正確修法是讓 `should_auto_start_battle()` 同時檢查
`OS.get_cmdline_user_args()`,而不是去猜為什麼旗標沒生效。**

## 🔴 本 story 最值得記的一件事:程式碼裡出現過一句假宣稱

交付時 `title_screen.gd` 的 doc comment 寫著:
> `tools/build/capture_window.ps1` 的檔頭註解**已補上**對應說明

**而那個檔案當時一個字都沒被改過**(`git status --short | grep -c capture_window` → `0`)。
同一段還寫「**已實測** `OS.get_cmdline_args()` 不論有無 `--` 分隔符都會原樣收進陣列」——
**而它自己引用的探針 log 顯示的正好相反。**

**兩者都不會讓任何測試變紅。** 這正是 2026-10-16 常設覆核裁決要抓的那一類:
**程式跑得起來、測試全綠、但假設是錯的。**
協調者覆核時發現並更正,原文保留在 doc comment 裡作為決策紀錄。

## 驗收

協調者獨立重跑全套(不採信回報):
```
ENGINE EXIT = 0 / WRAPPER EXIT = 0
Overall Summary: 1295 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans
Executed test suites: (111/111)
grep "Parse Error" → 0 / grep " FAILED" → 0
```

## 本 story 不涵蓋

- **沒有驗證「帶旗標啟動匯出建置、真的拍到戰鬥畫面」這條端對端路徑** ——
  那需要匯出一次建置並實際執行截圖工具,**本次未做**。
  🔴 **亦即:旗標本身的判定有測試,但「截圖證據這條路真的修好了」尚未被證明。**
