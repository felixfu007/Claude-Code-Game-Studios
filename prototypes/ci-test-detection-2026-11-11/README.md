# CI 測試偵測探針 (2026-11-11)

假設:`GameSettings._detect_headless()`(`DisplayServer.get_name()=="headless"`)在 CI 不成立,
故 CI 下 boot_load 不是 no-op,且該測試失敗。

狀態:concluded(只查證,未改任何既有檔)

## 發現
- CI log 原始行:`xvfb-run --auto-servernum ./addons/gdUnit4/runtest.sh --audio-driver Dummy --display-driver x11 --rendering-driver opengl3 ...`
  失敗訊息 actual = `X11`。CI 的 display server = X11(xvfb),不是 headless。
- 探針 p1(系統暫存目錄,Godot 4.7.1 編輯器執行檔):
  - 直接跑主場景(PLAY.bat 形狀):`editor=true template=false args=[] display=Windows current_scene==self true`
  - `-s` 測試形狀:`editor=true args=["-s","s.gd"] current_scene=null`
  => `OS.has_feature("editor")` 在 PLAY.bat 與測試都是 true,不能用來區分。
- 真實 GdUnit 入口(`args_probe_test.gd` 實跑):
  `args=["-s","res://addons/gdUnit4/bin/GdUnitCmdTool.gd","--ignoreHeadlessMode","-a",...]`
  CI 的 runtest.sh 與本機 runner(`-s tests/gdunit4_runner.gd`)皆含 `-s`。遊戲正式啟動從不帶 `-s`。
- 部分 tests 把 `get_tree().current_scene` 設成 TitleScreen(battle_sfx_wiring_test.gd:207),
  故「current_scene==self」不可靠。
