# Story 010:標題畫面顯示遊戲名稱「盲目於微光」

> **Epic**: `production/epics/game-shell/EPIC.md`
> **Status**: ✅ Done-pending-visual(2026-11-03;協調者重跑全套全綠)(原狀態:Ready(2026-11-03))
> **Type**: UI
> **Estimate**: S
> **依據**:管理者裁決逐字(2026-11-03):「現在用現有字型顯示(推薦)」(被跳過:等美術做標題字 / 名稱還沒定案)。名稱來源:`project.godot` 的 `config/name="盲目於微光"`。

## Acceptance Criteria

- [ ] **AC1** `src/ui/shell/TitleScreen.tscn` 在按鈕上方顯示遊戲名稱,字串走 `strings.csv` 新鍵(例 `shell.title.game_name`),**不寫死在場景裡**。
- [ ] **AC2** 只用專案已有字型(`assets/fonts/` 內,含授權),不新增字型檔;字級若用 HUD 點陣字,倍率一律取自 `WorldLayout.compute_scale()`(見 `technical-preferences.md` 字級義務)。用哪個字型、多大,回報中寫明。
- [ ] **AC3** 名稱不得擋住或推移既有按鈕的焦點順序;手把/鍵盤焦點行為不變(既有標題測試全綠)。
- [ ] **AC4** 一條測試斷言名稱節點存在且文字等於 `Loc.localize()` 該鍵;`locale_data_integrity_test.gd` 列數常數跟著改。

## 不在範圍

設計過的標題字(日後美術再換)、開窗目視(交管理者在家)。

## Affected Files(可直接改)

`src/ui/shell/TitleScreen.tscn`、`src/ui/shell/title_screen.gd`(若存在)、`assets/data/locales/strings.csv`、對應 `tests/` 檔。
