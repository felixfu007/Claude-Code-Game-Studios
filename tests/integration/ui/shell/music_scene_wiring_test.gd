## audio-foundation story-004 整合測試:音樂宿主(淡入淡出終值、同曲不重啟、靜音、素材缺席)
## 與 SceneRouter 接線。
##
## - 淡化斷言只看【終值與幀數上限】,不用牆鐘(headless 幀時間不等於牆鐘,見探針 Q3)。
## - 宿主測試自己建立(掛在測試節點下,auto_free);唯一掛 /root 的宿主(ensure_on_root 與
##   SceneRouter 接線測試)在 after_test 清掉(含 root meta),避免跨測試殘留。
## - 聽感與無縫循環不可自動化(家中耳聽);headless 音訊為 no-op,只驗決策與 volume_db。
## - 不讀任何檔案(AC-4 用注入的曲目表與假的 asset_exists)。🔴 例外一條(2026-11-11):
##   test_music_host_default_real_table_plays_title_then_a_battle_pool_track 唯讀已進版控的
##   res://assets/data/audio/music_tracks.txt(甲類,test-standards.md 2026-09-16 裁決)——
##   要驗的就是「真實表」接上宿主後的行為,注入取代即失去意義。不證明窮盡性(只驗 title + battle)。
## - 敏感度:決策核心是 static(A 類),AC-1/AC-2 由實作者暫時注入證明,見交付回報。
extends GdUnitTestSuite

const A: String = "res://fake/a.ogg"
const B: String = "res://fake/b.ogg"
const MAX_FRAMES: int = 300

var _original_scene: Node = null


func before_test() -> void:
	_original_scene = get_tree().current_scene


func after_test() -> void:
	get_tree().paused = false
	_remove_root_host()
	if _original_scene != null and is_instance_valid(_original_scene):
		get_tree().current_scene = _original_scene


func _remove_root_host() -> void:
	var root: Window = get_tree().root
	if root.has_meta(MusicPlayerHost.ROOT_META_KEY):
		var host: Variant = root.get_meta(MusicPlayerHost.ROOT_META_KEY)
		root.remove_meta(MusicPlayerHost.ROOT_META_KEY)
		if is_instance_valid(host):
			var node: Node = host as Node
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()


func _tracks() -> Dictionary:
	return {
		&"title": {"path": A, "fade_in_ms": 60, "fade_out_ms": 60},
		&"battle": {"path": B, "fade_in_ms": 60, "fade_out_ms": 60},
	}


func _make_host(muted: bool = false, exists: bool = true) -> MusicPlayerHost:
	var host: MusicPlayerHost = MusicPlayerHost.new()
	host.configure(_tracks())
	host.muted_check = func() -> bool: return muted
	host.asset_exists = func(_path: String) -> bool: return exists
	host.stream_loader = func(_path: String) -> AudioStream: return _make_stream()
	add_child(host)
	auto_free(host)
	return host


func _make_stream() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	# 20 秒長:太短的串流會在測試期間自然播完,讓 playing 變 false 而與淡出無關(曾因此間歇失敗)。
	var data: PackedByteArray = PackedByteArray()
	data.resize(8000 * 20)
	stream.data = data
	return stream


func _player_of(host: MusicPlayerHost) -> AudioStreamPlayer:
	for child: Node in host.get_children():
		if child is AudioStreamPlayer:
			return child as AudioStreamPlayer
	return null


## 等到條件成立或幀數用盡;回傳條件最終是否成立。
func _wait_until(cond: Callable) -> bool:
	for i: int in range(MAX_FRAMES):
		if bool(cond.call()):
			return true
		await get_tree().process_frame
	return bool(cond.call())


# ---- AC-1 同曲不重啟 -----------------------------------------------------

func test_music_host_same_scene_twice_keeps_and_requests_playback_once() -> void:
	var host: MusicPlayerHost = _make_host()
	host.enter_scene(&"battle")
	host.enter_scene(&"battle")
	assert_int(host.diagnostic_actions[0][1]).is_equal(MusicPolicy.Action.FADE_IN)
	assert_int(host.diagnostic_actions[1][1]).is_equal(MusicPolicy.Action.KEEP)
	assert_int(host.diagnostic_play_requests.size()).is_equal(1)


# ---- AC-2 切曲 + 淡入淡出終值 ---------------------------------------------

func test_music_host_fade_in_reaches_zero_db() -> void:
	var host: MusicPlayerHost = _make_host()
	host.enter_scene(&"title")
	var player: AudioStreamPlayer = _player_of(host)
	var done: bool = await _wait_until(func() -> bool: return is_equal_approx(player.volume_db, 0.0))
	assert_bool(done).append_failure_message("淡入未在幀數上限內到達 0 dB,volume_db=%s" % player.volume_db).is_true()
	assert_bool(player.playing).is_true()
	assert_str(host.current_track).is_equal(A)


func test_music_host_title_to_battle_switches_track_and_fades_back_in() -> void:
	var host: MusicPlayerHost = _make_host()
	host.enter_scene(&"title")
	var player: AudioStreamPlayer = _player_of(host)
	await _wait_until(func() -> bool: return is_equal_approx(player.volume_db, 0.0))
	host.enter_scene(&"battle")
	assert_int(host.diagnostic_actions[1][1]).is_equal(MusicPolicy.Action.SWITCH)
	assert_str(host.current_track).is_equal(B)
	var done: bool = await _wait_until(func() -> bool:
		return host.diagnostic_play_requests.size() == 2 and is_equal_approx(player.volume_db, 0.0) and player.playing)
	assert_bool(done).append_failure_message("切曲後未回到 0 dB,volume_db=%s" % player.volume_db).is_true()


func test_music_host_battle_to_dialogue_fades_out_to_silent_and_stops() -> void:
	var host: MusicPlayerHost = _make_host()
	host.enter_scene(&"battle")
	var player: AudioStreamPlayer = _player_of(host)
	await _wait_until(func() -> bool: return is_equal_approx(player.volume_db, 0.0))
	host.enter_scene(&"dialogue") # 表內沒有此 key = 靜音場景
	assert_int(host.diagnostic_actions[1][1]).is_equal(MusicPolicy.Action.FADE_OUT)
	var done: bool = await _wait_until(func() -> bool: return not player.playing)
	assert_bool(done).append_failure_message("淡出後播放器未停止").is_true()
	assert_float(player.volume_db).is_equal(AudioBuses.SILENT_DB)
	assert_str(host.current_track).is_equal("")


# ---- AC-3 靜音 -------------------------------------------------------------

func test_music_host_muted_sends_no_playback_request() -> void:
	var host: MusicPlayerHost = _make_host(true)
	host.enter_scene(&"title")
	host.enter_scene(&"battle")
	assert_array(host.diagnostic_play_requests).is_empty()
	assert_bool(_player_of(host).playing).is_false()


# ---- AC-4 素材缺席安靜 -----------------------------------------------------

func test_music_host_missing_asset_is_silent_without_requests() -> void:
	var host: MusicPlayerHost = _make_host(false, false)
	host.enter_scene(&"title")
	host.enter_scene(&"battle")
	assert_int(host.diagnostic_actions[0][1]).is_equal(MusicPolicy.Action.SILENT)
	assert_array(host.diagnostic_play_requests).is_empty()
	assert_bool(_player_of(host).playing).is_false()
	assert_str(host.current_track).is_equal("")


## 2026-11-11 改寫:原測試 test_music_host_default_empty_table_is_silent_without_crash 斷言
## 「真實曲目表為空 → 全場景靜音」,依據是「授權辦妥前表刻意為空」。管理者 2026-11-11 裁決
## 授權登記前即放入曲目(見 assets/audio/music/LICENSES.md),該前提消失,改為正向斷言:
## 真實表下標題放標題曲、戰鬥從真實 battle 池挑一首(哪一首由隨機決定,只斷言屬於池)。
func test_music_host_default_real_table_plays_title_then_a_battle_pool_track() -> void:
	var host: MusicPlayerHost = MusicPlayerHost.new()
	host.muted_check = func() -> bool: return false
	add_child(host)
	auto_free(host)
	host.enter_scene(&"title")
	host.enter_scene(&"battle")
	var parsed: Dictionary = MusicTrackTable.parse(FileAccess.get_file_as_string(MusicTrackTable.TABLE_PATH))
	var battle_paths: Array[String] = []
	for entry: Dictionary in parsed["tracks"][&"battle"]["pool"]:
		battle_paths.append(String(entry["path"]))
	assert_int(host.diagnostic_play_requests.size()).is_equal(2)
	assert_str(host.diagnostic_play_requests[0]).is_equal(String(parsed["tracks"][&"title"]["path"]))
	assert_bool(battle_paths.has(host.diagnostic_play_requests[1])) \
		.append_failure_message("戰鬥曲 %s 不在池 %s 內" % [host.diagnostic_play_requests[1], battle_paths]).is_true()
	assert_str(host.current_track).is_equal(host.diagnostic_play_requests[1])


func test_music_host_unloadable_stream_leaves_no_current_track() -> void:
	var host: MusicPlayerHost = MusicPlayerHost.new()
	host.configure(_tracks())
	host.muted_check = func() -> bool: return false
	host.asset_exists = func(_path: String) -> bool: return true
	host.stream_loader = func(_path: String) -> AudioStream: return null
	add_child(host)
	auto_free(host)
	host.enter_scene(&"title")
	assert_str(host.current_track).is_equal("")
	assert_bool(_player_of(host).playing).is_false()


# ---- 宿主掛 root / 接線 ----------------------------------------------------

func test_music_host_ensure_on_root_is_idempotent_and_single() -> void:
	var first: MusicPlayerHost = MusicPlayerHost.ensure_on_root(get_tree())
	var second: MusicPlayerHost = MusicPlayerHost.ensure_on_root(get_tree())
	assert_bool(first == second).is_true()
	await get_tree().process_frame
	await get_tree().process_frame
	var count: int = 0
	for child: Node in get_tree().root.get_children():
		if child is MusicPlayerHost:
			count += 1
	assert_int(count).is_equal(1)
	assert_bool(first.get_parent() == get_tree().root).is_true()


func test_music_host_enter_scene_before_ready_is_applied_after_ready() -> void:
	var host: MusicPlayerHost = MusicPlayerHost.ensure_on_root(get_tree())
	host.enter_scene(&"title") # deferred 加入前呼叫:暫存
	assert_array(host.diagnostic_actions).is_empty()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(host.diagnostic_actions.size()).is_equal(1)
	assert_str(String(host.diagnostic_actions[0][0])).is_equal("title")


func test_scene_router_switch_to_notifies_music_host_with_scene_key() -> void:
	var title: Node = load(SceneRouter.TITLE_SCENE_PATH).instantiate()
	get_tree().root.call_deferred("add_child", title)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = title
	# 開機場景(TitleScreen)自己確保宿主 —— 同時驗證 title_screen 接線。
	var host: MusicPlayerHost = get_tree().root.get_meta(MusicPlayerHost.ROOT_META_KEY) as MusicPlayerHost
	assert_object(host).append_failure_message("TitleScreen 應已確保音樂宿主").is_not_null()
	var before: int = host.diagnostic_actions.size()

	var created: Node = SceneRouter.go_to_settings(get_tree())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_int(host.diagnostic_actions.size()).is_equal(before + 1)
	assert_str(String(host.diagnostic_actions[before][0])).is_equal("title")
	assert_int(_count_hosts()).is_equal(1)

	if is_instance_valid(created):
		created.queue_free()
		await get_tree().process_frame


func _count_hosts() -> int:
	var count: int = 0
	for child: Node in get_tree().root.get_children():
		if child is MusicPlayerHost:
			count += 1
	return count


# ---- 暫停中音樂繼續播(管理者裁決 2026-11-10:選單打開時音樂繼續播)--------

func test_music_host_keeps_playing_and_fades_while_tree_paused() -> void:
	var host: MusicPlayerHost = _make_host()
	assert_int(host.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	get_tree().paused = true
	host.enter_scene(&"title") # 暫停中換曲:淡入 Tween 必須仍能推進
	var player: AudioStreamPlayer = _player_of(host)
	var done: bool = await _wait_until(func() -> bool: return is_equal_approx(player.volume_db, 0.0))
	var playing: bool = player.playing
	var paused_flag: bool = player.stream_paused
	get_tree().paused = false
	assert_bool(done).append_failure_message("暫停中淡入未到 0 dB,volume_db=%s" % player.volume_db).is_true()
	assert_bool(playing).is_true()
	assert_bool(paused_flag).is_false()
