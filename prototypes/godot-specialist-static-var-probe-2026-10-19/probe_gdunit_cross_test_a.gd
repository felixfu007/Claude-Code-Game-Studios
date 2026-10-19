## 探針(非正式測試,刻意不進 tests/):量測 static var 在 GdUnit4 真實測試執行環境下
## 是否跨「不同測試檔案」共用狀態 —— 不是推論,是實際跑 GdUnit4 CLI 觀察。
## 搭配 probe_gdunit_cross_test_b.gd(檔名刻意排在本檔之後,GdUnit4 掃描目錄內檔案
## 為字母序)。本檔故意在 test_a 結尾【不】呼叫 reset_for_test(),刻意製造洩漏,
## 讓 b 檔的測試觀察殘留值。
extends GdUnitTestSuite


func test_a_writes_true_and_deliberately_does_not_reset() -> void:
	GameSettingsProbe.reset_for_test()
	assert_bool(GameSettingsProbe.is_egm_enabled()).append_failure_message(
		"PROBE 前提:預期一開始是 false"
	).is_false()
	GameSettingsProbe.set_egm_enabled(true)
	print("PROBE test_a: 已寫入 true,刻意不呼叫 reset_for_test(),交給 test_b 觀察")
	assert_bool(GameSettingsProbe.is_egm_enabled()).is_true()
