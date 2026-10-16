# 暫停狀態下的介面輸入探針(U-009,2026-09-22)

**這不是試作,是一組一次性的量測探針。** 2026-10-16 補寫 README —— 當時只留了程式,
每次 session 啟動檢查都會把它報成「未文件化的試作」。

## 它回答什麼

`BattleMenu.open()` 會設 `get_tree().paused = true`(U-008 既有行為)。
U-009 要依賴兩件事,而**兩件在當時都沒有被量測過**:

- 暫停之後,`process_mode` 維持**引擎預設**(`PROCESS_MODE_INHERIT`)的 `Control`
  還收不收得到方向焦點導覽(`ui_down`)與按鈕啟動(`ui_accept`)?
- 滑鼠點擊在暫停狀態下還到不到得了?

📌 探針檔頭特別指出一件事:`battle-menu.md` 雖然警告過
「`focus_mode` 的實際行為本專案從未量測過」,**但那句話針對的是另一個問題**
(disabled/skip),**暫停 vs 輸入不在它的涵蓋範圍內**,是一個獨立假說。

## 證據等級:(A)

引擎執行的是專案釘死的那一版,量的是引擎自己的暫停與輸入行為。

## 檔案

| 檔案 | 是什麼 |
|---|---|
| `probe_pause_input.gd` | 主探針(暫停 × 焦點導覽 / 按鈕啟動)。**兩個問題的完整敘述在它的檔頭** |
| `probe_action_press.gd` | `Input.action_press()` 在 headless 下的行為 |
| `probe_mouse_click.gd` | 暫停狀態下的滑鼠點擊 |
