# Story 006:設定持久化的「測試期」判斷改看啟動指令(修 CI 紅燈 + CI 測試期不碰 user://)

> **Epic**: `production/epics/audio-foundation/EPIC.md`(story-001 的設定檔持久化)
> **Status**: Ready(2026-11-11 協調者起草)
> **Type**: Logic
> **指派**: `godot-gdscript-specialist`

## 裁決來源

管理者 2026-11-11 逐字選項:「**改判斷方式:看啟動指令(推薦)**」(被跳過:結構性改法 / 只修紅燈)。

## 事實(協調者已核原始行)

- GitHub CI 自 2026-11-06 `3623d98` 起每次紅;唯一失敗 `tests/unit/core/settings/game_settings_persistence_guard_test.gd::test_headless_detection_true_under_test_run`(期望 `'headless'`)。
- CI 以 `xvfb-run ... --display-driver x11` 執行(display = X11),`GameSettings._detect_headless()` 回 false → `boot_load()` 不再是 no-op。
- 調查與方案:`prototypes/ci-test-detection-2026-11-11/README.md`(godot-specialist;方案 A)。實測:PLAY.bat 形狀 `OS.get_cmdline_args()=[]`;GdUnit 入口帶 `-s`。

## 範圍

1. `src/core/settings/game_settings.gd`:測試期判斷改為「`DisplayServer.get_name() == "headless"` **或** `OS.get_cmdline_args()` 含 `-s` / `--script`」。函式名可改為更貼切的名稱(例如 `_detect_test_run()`),呼叫端同步。
2. 測試:`test_headless_detection_true_under_test_run` 改為斷言「測試行程中該判斷為 true」(不再斷言 display 名稱);新增純函式層測試:給定參數陣列/顯示名稱的組合 → 判斷結果(把判斷拆成可注入參數的純函式)。

## Affected Files

- `src/core/settings/game_settings.gd`
- `tests/unit/core/settings/game_settings_persistence_guard_test.gd`

## Acceptance Criteria

- [ ] **AC-1**:純函式:`([], "Windows")` → false(PLAY.bat/匯出版形狀);`(["-s","res://..."], "X11")` → true(CI 形狀);`([], "headless")` → true;`(["--script", "x"], "Windows")` → true。**[自動]**
- [ ] **AC-2**:本機全套中該判斷為 true(取代舊斷言)。**[自動]**
- [ ] **AC-3**:**提交後 GitHub CI 轉綠**(協調者看 `gh run list` / log 的 `Overall Summary`)。
- [ ] 敏感度證明:把 `-s` 判斷拿掉 → AC-1 CI 形狀那條紅 → 還原。
- [ ] 🔴 交付硬性義務:全套跑完,貼 `ENGINE EXIT`、`Overall Summary`、`Executed test suites` 原始三行。
- PLAY.bat 下設定仍會記住:在家驗收(順手:改音量 → 關遊戲 → 再開)。
