## audio-foundation story-003 AC-5 / AC-6(CSV 解析與 bus 名稱)。
##
## ## 檔案 I/O 使用揭露(test-standards.md 2026-09-16 裁決)
## 甲類:唯讀 res://assets/data/audio/sfx_cues.txt(已進版控的真實資料檔)。
## 為什麼不能注入取代:要驗的就是「真實資料檔九個 cue 都在、bus 合法」,
## 改寫死假資料抓不到資料檔打錯字。其餘解析行為用 in-test 字串驗,不讀檔。
## 🔴 不證明窮盡性:只驗九個必要 cue_id 與 bus 欄位,不驗路徑檔案存在(素材尚未到)。
## 敏感度證明:甲類真實資料檔斷言屬「A′ 類」(沒有類別可注入錯誤版本),不蓋證明;
## 解析函式為 static 純函式(「A 類」,無繼承鏈可覆寫),亦不蓋常駐 mutant。
extends GdUnitTestSuite


func test_sfx_table_parses_valid_rows() -> void:
	var result: Dictionary = SfxCueTable.parse("cue_id,path,min_interval_ms,bus\nui_click,res://a.ogg,60,UI\n")
	assert_int((result["cues"] as Dictionary).size()).is_equal(1)
	assert_array(result["errors"]).is_empty()
	assert_int(result["cues"][&"ui_click"]["min_interval_ms"]).is_equal(60)
	assert_str(String(result["cues"][&"ui_click"]["bus"])).is_equal("UI")


func test_sfx_table_skips_bad_rows_and_reports_them() -> void:
	var text: String = "\n".join([
		"# comment",
		"cue_id,path,min_interval_ms,bus",
		"ok,res://a.ogg,10,SFX",
		"missing_cols,res://a.ogg,10",
		"nonnumeric,res://a.ogg,abc,SFX",
		"negative,res://a.ogg,-5,SFX",
		"badbus,res://a.ogg,10,Nope",
		",res://a.ogg,10,SFX",
		"ok,res://dup.ogg,10,SFX",
	])
	var result: Dictionary = SfxCueTable.parse(text)
	assert_int((result["cues"] as Dictionary).size()).is_equal(1)
	assert_int((result["errors"] as Array).size()).is_equal(6)


func test_sfx_table_empty_text_gives_empty_table_without_error() -> void:
	var result: Dictionary = SfxCueTable.parse("")
	assert_int((result["cues"] as Dictionary).size()).is_equal(0)
	assert_array(result["errors"]).is_empty()


func test_sfx_table_real_csv_has_all_nine_cues_no_errors() -> void:
	var text: String = FileAccess.get_file_as_string(SfxCueTable.CSV_PATH)
	var result: Dictionary = SfxCueTable.parse(text)
	assert_array(result["errors"]).append_failure_message("真實 CSV 有壞列:%s" % [result["errors"]]).is_empty()
	assert_array(SfxCueTable.missing_required(result["cues"])).is_empty()
	assert_int((result["cues"] as Dictionary).size()).is_equal(SfxCueTable.REQUIRED_CUE_IDS.size())
	assert_int(SfxCueTable.REQUIRED_CUE_IDS.size()).is_equal(9)


func test_sfx_table_real_csv_buses_are_story001_constants() -> void:
	var result: Dictionary = SfxCueTable.parse(FileAccess.get_file_as_string(SfxCueTable.CSV_PATH))
	for cue_id: StringName in result["cues"]:
		var bus: StringName = result["cues"][cue_id]["bus"]
		assert_bool(AudioBuses.CHILD_BUSES.has(bus)).append_failure_message("%s 的 bus '%s' 不合法" % [cue_id, bus]).is_true()


func test_sfx_table_unknown_bus_is_rejected() -> void:
	assert_bool(SfxCueTable.is_valid_bus(&"SFX")).is_true()
	assert_bool(SfxCueTable.is_valid_bus(&"Bogus")).is_false()
