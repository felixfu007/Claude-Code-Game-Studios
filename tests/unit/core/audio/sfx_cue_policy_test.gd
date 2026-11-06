## audio-foundation story-003 AC-1 / AC-2 / AC-3(決策核心)與 AC-7(依賴方向)。
##
## headless 下音訊是 no-op:本檔只驗「決策」,不斷言「真的響了」。
##
## ## 檔案 I/O 使用揭露(test-standards.md 2026-09-16 裁決)
## 乙類(唯讀 src/**/*.gd 原始碼文字,斷言原始碼紀律):
##   - AC-7:src/gameplay/** 不得有「非註解行」含 Audio(依賴方向)。
##   - AC-2:sfx_cue_policy.gd 與 sfx_player_host.gd 不得含非註解的 push_error / push_warning
##     (「素材缺席安靜」的結構性證據;GdUnit4 無穩定的引擎錯誤攔截可用,故以原始碼紀律替代)。
## 為什麼不能注入取代:斷言對象就是原始碼文字。
## 🔴 不證明窮盡性:反射呼叫、字串組出的函式名、.tscn 腳本掛載都在掃描視野之外;
## AC-2 的原始碼掃描證明「這兩檔沒寫」,不證明引擎內部不會因素材缺席印訊息。
##
## 敏感度證明:AC-1(_MutantIgnoresMute)、AC-3(_MutantIgnoresInterval),常駐 mutant。
extends GdUnitTestSuite

const _TABLE: Dictionary = {
	&"a": {"path": "res://x/a.ogg", "min_interval_ms": 100, "bus": &"SFX"},
	&"b": {"path": "res://x/b.ogg", "min_interval_ms": 100, "bus": &"SFX"},
}


class _MutantIgnoresMute extends SfxCuePolicy:
	func _blocks_for_mute(_muted: bool) -> bool:
		return false


class _MutantIgnoresInterval extends SfxCuePolicy:
	func _blocks_for_interval(_cue_id: StringName, _now_ms: int, _min_interval_ms: int) -> bool:
		return false


## 假時鐘:回傳 box[0]。box 為 Array(參考型別,lambda 才寫得回)。
func _make_policy(box: Array, exists: bool = true, policy_script: GDScript = null) -> SfxCuePolicy:
	var clock: Callable = func() -> int: return int(box[0])
	var asset: Callable = func(_p: String) -> bool: return exists
	if policy_script != null:
		return policy_script.new(_TABLE, clock, asset)
	return SfxCuePolicy.new(_TABLE, clock, asset)


# ---- AC-1 ------------------------------------------------------------------

func test_sfx_policy_muted_never_plays() -> void:
	var policy: SfxCuePolicy = _make_policy([0])
	assert_int(policy.decide(&"a", true)).is_equal(SfxCuePolicy.Decision.MUTED)
	assert_int(policy.decide(&"b", true)).is_equal(SfxCuePolicy.Decision.MUTED)


func test_sfx_host_muted_sends_zero_play_requests() -> void:
	var host: SfxPlayerHost = auto_free(SfxPlayerHost.new())
	host.playback_enabled = false
	host.muted_check = func() -> bool: return true
	host.configure(_make_policy([0]))
	for i: int in range(5):
		host.request_cue(&"a")
		host.request_cue(&"b")
	assert_int(host.diagnostic_play_requests.size()).is_equal(0)
	assert_int(host.diagnostic_decisions.size()).is_equal(10)


func test_sensitivity_proof_ac1_mute_check_removal_is_caught() -> void:
	var mutant: SfxCuePolicy = _make_policy([0], true, _MutantIgnoresMute)
	# 若靜音檢查被拿掉,靜音下會變成「播」——AC-1 的斷言(必為 MUTED)會因此變紅。
	assert_int(mutant.decide(&"a", true)).is_not_equal(SfxCuePolicy.Decision.MUTED)


# ---- AC-2 ------------------------------------------------------------------

func test_sfx_policy_missing_asset_is_silent_skip_and_cached() -> void:
	var calls: Array = [0]
	var clock: Callable = func() -> int: return 0
	var asset: Callable = func(_p: String) -> bool:
		calls[0] += 1
		return false
	var policy: SfxCuePolicy = SfxCuePolicy.new(_TABLE, clock, asset)
	assert_int(policy.decide(&"a", false)).is_equal(SfxCuePolicy.Decision.ASSET_MISSING)
	assert_int(policy.decide(&"a", false)).is_equal(SfxCuePolicy.Decision.ASSET_MISSING)
	assert_int(policy.decide(&"a", false)).is_equal(SfxCuePolicy.Decision.ASSET_MISSING)
	assert_int(int(calls[0])).append_failure_message("缺席路徑應快取,只查一次").is_equal(1)


func test_sfx_policy_unknown_cue_is_silent() -> void:
	assert_int(_make_policy([0]).decide(&"nope", false)).is_equal(SfxCuePolicy.Decision.UNKNOWN_CUE)


func test_sfx_real_resource_loader_missing_asset_does_not_crash_host() -> void:
	# 真實 ResourceLoader.exists:素材目前不存在 -> 決策為 ASSET_MISSING,不崩潰。
	var host: SfxPlayerHost = auto_free(SfxPlayerHost.new())
	host.muted_check = func() -> bool: return false
	add_child(host)
	assert_int(host.request_cue(SfxCueTable.CUE_UI_CLICK)).is_equal(SfxCuePolicy.Decision.ASSET_MISSING)


func test_sfx_audio_code_never_pushes_errors_or_warnings() -> void:
	for path: String in ["res://src/core/audio/sfx_cue_policy.gd", "res://src/ui/audio/sfx_player_host.gd",
			"res://src/core/audio/sfx_cue_table.gd"]:
		var offenders: Array[String] = _noncomment_lines_matching(path, ["push_error", "push_warning"])
		assert_array(offenders).append_failure_message("%s 含 push_*:%s" % [path, offenders]).is_empty()


# ---- AC-3 ------------------------------------------------------------------

func test_sfx_policy_min_interval_drops_then_allows() -> void:
	var box: Array = [1000]
	var policy: SfxCuePolicy = _make_policy(box)
	assert_int(policy.decide(&"a", false)).is_equal(SfxCuePolicy.Decision.PLAY)
	box[0] = 1099
	assert_int(policy.decide(&"a", false)).is_equal(SfxCuePolicy.Decision.TOO_SOON)
	box[0] = 1100
	assert_int(policy.decide(&"a", false)).is_equal(SfxCuePolicy.Decision.PLAY)


func test_sfx_policy_different_cues_do_not_affect_each_other() -> void:
	var box: Array = [1000]
	var policy: SfxCuePolicy = _make_policy(box)
	assert_int(policy.decide(&"a", false)).is_equal(SfxCuePolicy.Decision.PLAY)
	box[0] = 1010
	assert_int(policy.decide(&"b", false)).is_equal(SfxCuePolicy.Decision.PLAY)


func test_sfx_policy_dropped_request_does_not_extend_window() -> void:
	var box: Array = [1000]
	var policy: SfxCuePolicy = _make_policy(box)
	policy.decide(&"a", false)
	box[0] = 1050
	policy.decide(&"a", false) # 被丟棄,不得重置視窗
	box[0] = 1100
	assert_int(policy.decide(&"a", false)).is_equal(SfxCuePolicy.Decision.PLAY)


func test_sensitivity_proof_ac3_interval_check_removal_is_caught() -> void:
	var box: Array = [1000]
	var mutant: SfxCuePolicy = _make_policy(box, true, _MutantIgnoresInterval)
	mutant.decide(&"a", false)
	box[0] = 1001
	assert_int(mutant.decide(&"a", false)).is_not_equal(SfxCuePolicy.Decision.TOO_SOON)


# ---- AC-7 ------------------------------------------------------------------

func test_sfx_gameplay_layer_has_no_audio_dependency() -> void:
	var offenders: Array[String] = []
	for path: String in _list_gd_files("res://src/gameplay"):
		for hit: String in _noncomment_lines_matching(path, ["Audio"]):
			offenders.append("%s: %s" % [path, hit])
	assert_array(offenders).append_failure_message("src/gameplay 出現音訊依賴:%s" % [offenders]).is_empty()


# ---- helpers ---------------------------------------------------------------

func _list_gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d: String in DirAccess.get_directories_at(dir_path):
		out.append_array(_list_gd_files(dir_path.path_join(d)))
	return out


func _noncomment_lines_matching(path: String, needles: Array[String]) -> Array[String]:
	var hits: Array[String] = []
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		for needle: String in needles:
			if stripped.contains(needle):
				hits.append(stripped)
				break
	return hits
