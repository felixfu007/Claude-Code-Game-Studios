## audio-foundation story-004 AC-1 ~ AC-4(音樂切換決策)與 AC-5(曲目表解析)。
##
## ## 檔案 I/O 使用揭露(test-standards.md 2026-09-16 裁決)
## 甲類:唯讀 res://assets/data/audio/music_tracks.txt(已進版控的真實資料檔),
## 只驗「真實表解析零壞列」。🔴 不證明窮盡性:不驗曲目檔案存在(授權未辦,表刻意為空)。
## 敏感度證明:決策函式為 static 純函式(A 類,無繼承鏈可覆寫);AC-1、AC-2 由實作者
## 依派工單做過暫時注入(見交付回報),不在版本庫留痕。
extends GdUnitTestSuite

const A: String = "res://a.ogg"
const B: String = "res://b.ogg"


# ---- AC-1 同曲不重啟 -----------------------------------------------------

func test_same_track_title_to_title_keeps() -> void:
	assert_int(MusicPolicy.decide(A, A, true, false)).is_equal(MusicPolicy.Action.KEEP)


func test_same_track_battle_to_battle_keeps_across_missions() -> void:
	assert_int(MusicPolicy.decide(B, B, true, false)).is_equal(MusicPolicy.Action.KEEP)


# ---- AC-2 切曲決策 -------------------------------------------------------

func test_title_to_battle_is_fade_out_then_switch() -> void:
	assert_int(MusicPolicy.decide(A, B, true, false)).is_equal(MusicPolicy.Action.SWITCH)


func test_battle_to_dialogue_without_track_fades_out() -> void:
	assert_int(MusicPolicy.decide(B, "", false, false)).is_equal(MusicPolicy.Action.FADE_OUT)


func test_nothing_playing_to_track_fades_in() -> void:
	assert_int(MusicPolicy.decide("", A, true, false)).is_equal(MusicPolicy.Action.FADE_IN)


func test_nothing_to_nothing_is_silent() -> void:
	assert_int(MusicPolicy.decide("", "", false, false)).is_equal(MusicPolicy.Action.SILENT)


# ---- AC-3 靜音不送播放請求 -----------------------------------------------

func test_muted_never_requests_playback() -> void:
	for prev: String in ["", A, B]:
		for new_track: String in ["", A, B]:
			var action: MusicPolicy.Action = MusicPolicy.decide(prev, new_track, true, true)
			assert_bool(MusicPolicy.requests_playback(action)).is_false()


func test_muted_with_track_playing_fades_out() -> void:
	assert_int(MusicPolicy.decide(A, B, true, true)).is_equal(MusicPolicy.Action.FADE_OUT)


# ---- AC-4 素材缺席(決策層:不播、無錯誤)---------------------------------

func test_missing_asset_does_not_request_playback() -> void:
	var action: MusicPolicy.Action = MusicPolicy.decide("", A, false, false)
	assert_int(action).is_equal(MusicPolicy.Action.SILENT)
	assert_bool(MusicPolicy.requests_playback(action)).is_false()


func test_missing_asset_while_playing_fades_out() -> void:
	assert_int(MusicPolicy.decide(A, B, false, false)).is_equal(MusicPolicy.Action.FADE_OUT)


func test_requests_playback_only_for_fade_in_and_switch() -> void:
	assert_bool(MusicPolicy.requests_playback(MusicPolicy.Action.FADE_IN)).is_true()
	assert_bool(MusicPolicy.requests_playback(MusicPolicy.Action.SWITCH)).is_true()
	assert_bool(MusicPolicy.requests_playback(MusicPolicy.Action.KEEP)).is_false()
	assert_bool(MusicPolicy.requests_playback(MusicPolicy.Action.FADE_OUT)).is_false()
	assert_bool(MusicPolicy.requests_playback(MusicPolicy.Action.SILENT)).is_false()


# ---- AC-5 曲目表 ---------------------------------------------------------

func test_table_parses_valid_rows() -> void:
	var result: Dictionary = MusicTrackTable.parse("scene_key,path,fade_in_ms,fade_out_ms\ntitle,res://a.ogg,1500,1000\n")
	assert_int((result["tracks"] as Dictionary).size()).is_equal(1)
	assert_array(result["errors"]).is_empty()
	assert_int(result["tracks"][&"title"]["fade_in_ms"]).is_equal(1500)
	assert_int(result["tracks"][&"title"]["fade_out_ms"]).is_equal(1000)
	assert_str(result["tracks"][&"title"]["path"]).is_equal("res://a.ogg")


func test_table_skips_bad_rows_and_reports_them() -> void:
	var text: String = "\n".join([
		"# comment",
		"scene_key,path,fade_in_ms,fade_out_ms",
		"ok,res://a.ogg,10,10",
		"missing_cols,res://a.ogg,10",
		"nonnumeric,res://a.ogg,abc,10",
		"negative,res://a.ogg,10,-5",
		",res://a.ogg,10,10",
		"nopath,,10,10",
		"ok,res://dup.ogg,10,10",
	])
	var result: Dictionary = MusicTrackTable.parse(text)
	assert_int((result["tracks"] as Dictionary).size()).is_equal(1)
	assert_int((result["errors"] as Array).size()).is_equal(6)


func test_table_empty_text_is_empty_without_error() -> void:
	var result: Dictionary = MusicTrackTable.parse("")
	assert_int((result["tracks"] as Dictionary).size()).is_equal(0)
	assert_array(result["errors"]).is_empty()


func test_table_real_file_parses_without_errors() -> void:
	var result: Dictionary = MusicTrackTable.parse(FileAccess.get_file_as_string(MusicTrackTable.TABLE_PATH))
	assert_array(result["errors"]).append_failure_message("真實曲目表有壞列:%s" % [result["errors"]]).is_empty()


func test_scene_key_mapping_settings_shares_title_track() -> void:
	assert_str(String(MusicTrackTable.scene_key_for_path(SceneRouter.TITLE_SCENE_PATH))).is_equal("title")
	assert_str(String(MusicTrackTable.scene_key_for_path(SceneRouter.SETTINGS_SCENE_PATH))).is_equal("title")
	assert_str(String(MusicTrackTable.scene_key_for_path(SceneRouter.BATTLE_SCENE_PATH))).is_equal("battle")
	assert_str(String(MusicTrackTable.scene_key_for_path(SceneRouter.SUPPORT_CONVERSATION_SCENE_PATH))).is_equal("dialogue")
	assert_str(String(MusicTrackTable.scene_key_for_path("res://x.tscn"))).is_equal("")
