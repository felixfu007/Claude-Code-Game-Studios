# Story 002:設定畫面加主音量/音樂/音效三滑桿與靜音開關

> **Epic**: `production/epics/audio-foundation/EPIC.md`
> **Status**: Blocked(前置 story-001 完成後轉 Ready)
> **Type**: UI(結構與互動 headless 可測;外觀為開窗人眼)
> **需求來源**: `docs/reviews/minimal-audio-scope-draft-2026-11-06.md` 第四節需求 1;管理者 2026-11-06 裁決
> **指派**: `ui-programmer`(`.gd` 路由 `godot-gdscript-specialist`;`.tscn` 路由 `godot-specialist`)
> **前置**: story-001

## 範圍

1. `SettingsScreen` 新增四列:主音量滑桿、音樂音量滑桿、音效音量滑桿(`HSlider`,0~1)、靜音開關(`CheckButton`,比照既有兩個開關)。
2. (持久化已由 story-001 的 `GameSettings` setter 內建,本畫面**不需**自行存檔,也不得直接碰檔案。)進畫面時以 `GameSettings` 目前值同步顯示(只讀一次,畫面不持有第二份狀態,比照現行 EGM 做法)。
3. 操作即寫回 `GameSettings` 並呼叫 story-001 的套用入口(拖動時即時聽到變化是設計意圖;headless 不驗)。
4. **三種輸入平權**(專案規則,無 hover-only):滑鼠拖動/點擊、鍵盤方向鍵、手把 d-pad/類比。`HSlider` 取得焦點時引擎是否以 `ui_left`/`ui_right` 原生調整、`step` 設多少才適合手把操作,**未驗證,實作者須以探針或 `docs/engine-reference/godot/` 確認**;焦點鏈改為「EGM → 隱藏好感度 → 主音量 → 音樂 → 音效 → 靜音 → 返回」有界不環繞(比照現行手動 `focus_neighbor_*`)。滑桿上下鍵與左右鍵的職責衝突(上下換列、左右調值)要明確保持。
5. 字串全走 `Loc.localize`,**新增**鍵到 `strings.csv`(只准新增列):建議 `shell.settings.volume_master`、`volume_music`、`volume_sfx`、`mute_toggle`。
6. 版面:現行 `SettingsScreen.tscn` 的 `Panel` 是寫死 320×160,加四列會溢出——**面板高度/結構如何調**屬排版決定,先以最小改動容納,並於回報揭露;AC9 字級縮放延續現行「明文缺口」狀態,不在本 story 解決。

## Affected Files

- `src/ui/shell/settings_screen.gd`
- `src/ui/shell/SettingsScreen.tscn` —— 新增節點列、調高面板
- `assets/data/locales/strings.csv` —— 只新增列
- `tests/unit/core/i18n/locale_data_integrity_test.gd` —— 僅當它釘死 CSV 列數,只改列數
- `tests/integration/ui/shell/egm_setting_test.gd` —— **可能**因焦點鏈變動而紅,有意識改斷言,不得刪(以實跑為準)
- 新檔:`tests/integration/ui/shell/settings_audio_controls_test.gd`

不得動:`src/core/settings/game_settings.gd`(story-001 範圍)、`project.godot`、`scene_router.gd`。

## Acceptance Criteria

- [ ] **AC-1 初值同步**:`GameSettings` 預先設值後載入 `SettingsScreen.tscn`,四個控件顯示值等於設定值。**[自動]**
- [ ] **AC-2 寫回**:直接設定滑桿 `value`/開關 `button_pressed`(headless 不送 `InputEvent`,比照既有慣例)後,`GameSettings` 對應欄位等於新值。**[自動]**
- [ ] **AC-3 四種輸入同一路徑**:鍵盤/手把/滑鼠最終都經同一個 `value_changed`/`toggled` 處理函式,不另寫第二套分派。**[自動]**(信號連線檢查)+ **[開窗人眼]** 實際以三種輸入各操作一次
- [ ] **AC-4 焦點鏈**:六個可聚焦控件的 `focus_neighbor_*` 形成有界鏈,首尾不環繞,返回鈕可達。**[自動]**
- [ ] **AC-5 無硬編字串**:四列文字經 `Loc.localize`,四個新鍵在 CSV 中存在且非空。**[自動]**
- [ ] **AC-6 不污染**:測試收尾呼叫 `GameSettings.reset_for_test()`。**[自動]**
- [ ] **AC-7 靜音不改音量**:切換靜音後三滑桿 `value` 不變。**[自動]**
- [ ] 不得寫「真的聽得到音量變化」的斷言(headless 無聲)。
- [ ] 🔴 交付硬性義務:全套 `run_tests_with_import.sh`,貼 `ENGINE EXIT` 與 `Overall Summary` 三行。
- [ ] 敏感度證明:AC-2、AC-4 各一次。

## Test Evidence

`tests/integration/ui/shell/settings_audio_controls_test.gd`。UI 類證據 gate 為 ADVISORY:另附開窗截圖與三種輸入操作紀錄於 `production/qa/evidence/`(**管理者上班時螢幕不得出現遊戲畫面**,開窗擷取由協調者安排,實作者不得自行長時間開窗)。截圖分類與檢查依 `coding-standards.md`(整窗 = Category A;Check 4 若無被縮放對象寫「沒有可測對象(N/A)」)。

## 未決點

1. 滑桿 `step` 與手把類比搖桿的連續調整手感:需家中實測,先給保守初值並登記。
2. 面板版面調整幅度(見範圍 6)。
3. 音量數字是否要顯示(百分比文字)——規格未講,預設不顯示,有需要另裁。

## Out of Scope

存檔(story-001)、播放(story-003)、AC9 字級縮放、任何新設定項。
