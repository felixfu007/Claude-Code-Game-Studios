## 探針(非正式測試,刻意不進 tests/):見 probe_gdunit_cross_test_a.gd 的檔頭說明。
## 本檔觀察 a 檔刻意留下的殘留值,印出實測結果(不預設方向,讓實際輸出說話),
## 再呼叫 reset_for_test() 清理,避免污染同一次 run 裡的其他測試。
extends GdUnitTestSuite


func test_b_observes_whatever_state_test_a_left_behind() -> void:
	var observed: bool = GameSettingsProbe.is_egm_enabled()
	print("PROBE test_b: 觀察到 GameSettingsProbe.is_egm_enabled() = ", observed,
		" (true 代表 static var 真的跨測試檔案共用狀態;false 代表每個測試檔案是獨立行程/獨立狀態)")
	GameSettingsProbe.reset_for_test()
