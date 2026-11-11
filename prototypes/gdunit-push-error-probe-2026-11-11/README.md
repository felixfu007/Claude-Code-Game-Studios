# GdUnit4 v6.2.1 對 push_error 的行為(2026-11-11 探針,A 級)

執行檔:`push_error_probe_test.gd`;原始輸出:`run_output.txt`(已去色)。

結論:
1. 預設下被測程式呼叫 `push_error()` **不會**使測試失敗(3 條全 PASSED,exit 0)。
   原始碼依據:`addons/gdUnit4/src/core/GdUnitSettings.gd` 設定 `REPORT_PUSH_ERRORS` 預設 `false`("Report push_error() as failure");專案 `project.godot` 無覆寫。
2. 可斷言:`await assert_error(callable).is_push_error(msg)`(`GdUnitGodotErrorAssert`;專案既有用例 `tests/integration/gameplay/narrative/support_conversation_pool_write_port_test.gd`)。
3. 實際解析器呼叫(`AffinityLink.from_csv_line` 未知極性)印 `ERROR:` 到 log 但測試 PASSED、回 null。
關鍵輸出:`Overall Summary: 3 test cases | 0 errors | 0 failures`、`Exit code: 0`。
