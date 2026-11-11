## audio-foundation story-004 AC-1 ~ AC-4(音樂切換決策)與 AC-5(曲目表解析)。
##
## ## 檔案 I/O 使用揭露(test-standards.md 2026-09-16 裁決)
## 甲類:唯讀 res://assets/data/audio/music_tracks.txt(已進版控的真實資料檔),
## 只驗「真實表解析零壞列」與「battle 曲目池 ≥ 3 首」。🔴 不證明窮盡性:不驗曲目檔案存在
## (2026-11-11 起表已填入真實路徑,見 assets/audio/music/LICENSES.md;檔案存在與否不在本檔斷言)。
## 曲目池(2026-11-11):default_pick_index 為 static 純函式(A 類,無繼承鏈可覆寫,不蓋敏感度證明);
## 宿主挑選走 track_picker 注入,test_host_plays_the_track_the_picker_chose_from_the_pool 以注入值
## 斷言實際播放路徑 —— 若宿主忽略 picker 改播主欄位,第一個斷言即紅(未另留常駐 mutant)。
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
		"ok,res://a.ogg,10,10",
	])
	var result: Dictionary = MusicTrackTable.parse(text)
	assert_int((result["tracks"] as Dictionary).size()).is_equal(1)
	# 2026-11-11 曲目池改版:同 key 不同 path 合法(進池);同 key 同 path 仍是錯誤。
	assert_int((result["errors"] as Array).size()).is_equal(6)
	assert_int((result["tracks"][&"ok"]["pool"] as Array).size()).is_equal(1)


# ---- 曲目池(2026-11-11 管理者裁決「戰鬥BGM可以三四首隨機撥放」)-----------

func test_table_same_key_different_paths_form_a_pool_in_order() -> void:
	var text: String = "\n".join([
		"scene_key,path,fade_in_ms,fade_out_ms",
		"battle,res://b1.ogg,10,20",
		"battle,res://b2.ogg,30,40",
		"battle,res://b3.ogg,50,60",
	])
	var result: Dictionary = MusicTrackTable.parse(text)
	assert_array(result["errors"]).is_empty()
	var entry: Dictionary = result["tracks"][&"battle"]
	assert_str(entry["path"]).is_equal("res://b1.ogg")
	var pool: Array = entry["pool"]
	assert_int(pool.size()).is_equal(3)
	assert_str(pool[1]["path"]).is_equal("res://b2.ogg")
	assert_int(pool[2]["fade_in_ms"]).is_equal(50)


func test_default_pick_never_repeats_last_index_when_pool_has_more_than_one() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	for avoid: int in range(3):
		for i: int in range(50):
			var picked: int = MusicPlayerHost.default_pick_index(rng, 3, avoid)
			assert_bool(picked != avoid and picked >= 0 and picked < 3) \
				.append_failure_message("avoid=%d picked=%d" % [avoid, picked]).is_true()


func test_default_pick_reaches_every_other_track() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 777
	var seen: Dictionary = {}
	for i: int in range(200):
		seen[MusicPlayerHost.default_pick_index(rng, 4, 0)] = true
	assert_bool(seen.has(1) and seen.has(2) and seen.has(3) and not seen.has(0)).is_true()


func test_default_pick_single_track_pool_is_always_zero() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	assert_int(MusicPlayerHost.default_pick_index(rng, 1, 0)).is_equal(0)
	assert_int(MusicPlayerHost.default_pick_index(rng, 1, -1)).is_equal(0)


func test_host_plays_the_track_the_picker_chose_from_the_pool() -> void:
	var host: MusicPlayerHost = auto_free(MusicPlayerHost.new())
	host.playback_enabled = false
	host.muted_check = func() -> bool: return false
	host.asset_exists = func(_p: String) -> bool: return true
	var picks: Array[int] = [2, 0]
	var avoids: Array[int] = []
	host.track_picker = func(size: int, avoid: int) -> int:
		avoids.append(avoid)
		return picks.pop_front()
	var parsed: Dictionary = MusicTrackTable.parse("\n".join([
		"scene_key,path,fade_in_ms,fade_out_ms",
		"title,res://t.ogg,0,0",
		"battle,res://b1.ogg,0,0",
		"battle,res://b2.ogg,0,0",
		"battle,res://b3.ogg,0,0",
	]))
	host.configure(parsed["tracks"])
	add_child(host)
	host.enter_scene(&"battle")
	host.enter_scene(&"title")
	host.enter_scene(&"battle")
	assert_array(host.diagnostic_play_requests).is_equal(["res://b3.ogg", "res://t.ogg", "res://b1.ogg"])
	# 第一次沒有上一首(-1);第二次要避開上次挑到的索引 2。
	assert_array(avoids).is_equal([-1, 2])


func test_real_table_battle_pool_has_at_least_three_tracks() -> void:
	var result: Dictionary = MusicTrackTable.parse(FileAccess.get_file_as_string(MusicTrackTable.TABLE_PATH))
	assert_int((result["tracks"][&"battle"]["pool"] as Array).size()).is_greater_equal(3)


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
