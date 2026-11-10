## audio-foundation story-003 AC-4 / AC-9 / AC-10 / AC-8(接線)。
##
## 真實場景載入(technical-preferences「第 5 點」):load() BattleScreen.tscn -> instantiate()
## -> 設 override -> add_child。宿主在 instance 進樹前先加為子節點(= SceneRouter 的做法),
## 由 BattleScreen._ready() 以 group 取得並 bind_battle。
## headless 下音訊是 no-op:host.playback_enabled=false,只驗「決策與請求序列」。
##
## ## 檔案 I/O 使用揭露
## 甲類:唯讀 assets/data/audio/sfx_cues.txt、test_fixture_terrain_duel.txt、
## test_fixture_roster_duel.txt、test_fixture_roster_doomed.txt(已進版控)。
## 🔴 不證明窮盡性:只驗列出的事件路徑;M3 的 BattleMenu.open_rejected、M9 的 entry_appended
## 另由 host 直接 emit 的測試覆蓋接線,不證明真實戰鬥一定走到那些 signal。
##
## 敏感度證明:AC-4(_MutantHostAlwaysHit,擊倒時也發 M5)。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN_DUEL_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_DUEL_PATH: String = "res://assets/data/units/test_fixture_roster_duel.txt"
const _ROSTER_DOOMED_PATH: String = "res://assets/data/units/test_fixture_roster_doomed.txt"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()


func after_test() -> void:
	_host_snap.restore()
	CampaignProgress.reset_for_test()


## mutant:擊倒時也發 M5(違反「M5/M6 二擇一」)。
class _MutantHostAlwaysHit extends SfxPlayerHost:
	func _on_attack_resolved(_a: int, _t: int, _d: int, target_died: bool) -> void:
		request_cue(SfxCueTable.CUE_ATTACK_HIT)
		if target_died:
			request_cue(SfxCueTable.CUE_UNIT_DOWN)


func _make_policy() -> SfxCuePolicy:
	var parsed: Dictionary = SfxCueTable.parse(FileAccess.get_file_as_string(SfxCueTable.CSV_PATH))
	var tick: Array = [0]
	# 每次讀時鐘就前進 10 秒,使最小間隔不干擾「事件對應」測試。
	var clock: Callable = func() -> int:
		tick[0] += 10000
		return int(tick[0])
	return SfxCuePolicy.new(parsed["cues"], clock, func(_p: String) -> bool: return true)


func _make_host(host_script: GDScript = null) -> SfxPlayerHost:
	var host: SfxPlayerHost = host_script.new() if host_script != null else SfxPlayerHost.new()
	host.playback_enabled = false
	host.muted_check = func() -> bool: return false
	host.configure(_make_policy())
	return host


## 載入真實 BattleScreen,宿主先掛上再進樹。set_script(若有)必須最先,見 coding-standards 2026-10-16。
func _load_battle(host: SfxPlayerHost, roster_path: String) -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.terrain_path_override = _TERRAIN_DUEL_PATH
	instance.roster_path_override = roster_path
	instance.add_child(host)
	add_child(instance)
	return instance


# ---- AC-4 ------------------------------------------------------------------

func test_sfx_wiring_select_then_move_emits_m2_m4() -> void:
	var host: SfxPlayerHost = _make_host()
	var instance: BattleScreen = _load_battle(host, _ROSTER_DUEL_PATH)
	assert_that(instance._controller.click_tile(Vector2i(0, 0))["action"]).is_equal(&"selected")
	var moved: Dictionary = instance._controller.click_tile(Vector2i(0, 1))
	assert_that(moved["action"]).is_equal(&"moved")
	assert_array(host.diagnostic_play_requests).is_equal([SfxCueTable.CUE_UNIT_SELECT, SfxCueTable.CUE_UNIT_MOVE])


func test_sfx_wiring_killing_blow_emits_m6_not_m5_then_victory() -> void:
	var host: SfxPlayerHost = _make_host()
	var instance: BattleScreen = _load_battle(host, _ROSTER_DUEL_PATH)
	instance._controller.click_tile(Vector2i(0, 0))
	assert_that(instance._controller.click_tile(Vector2i(1, 0))["action"]).is_equal(&"attacked")
	assert_array(host.diagnostic_play_requests).is_equal([
		SfxCueTable.CUE_UNIT_SELECT, SfxCueTable.CUE_UNIT_DOWN, SfxCueTable.CUE_VICTORY,
	])
	assert_bool(host.diagnostic_play_requests.has(SfxCueTable.CUE_ATTACK_HIT)).is_false()


func test_sfx_wiring_defeat_emits_m6_and_defeat() -> void:
	var host: SfxPlayerHost = _make_host()
	var instance: BattleScreen = _load_battle(host, _ROSTER_DOOMED_PATH)
	await instance._end_faction_phase_pressed()
	assert_bool(host.diagnostic_play_requests.has(SfxCueTable.CUE_DEFEAT)).is_true()
	assert_bool(host.diagnostic_play_requests.has(SfxCueTable.CUE_VICTORY)).is_false()


func test_sfx_wiring_cancel_and_non_lethal_hit_and_affinity_handlers() -> void:
	# M3 / M5 / M9 的處理器接線:直接驅動處理器(M5 需要不致死的戰鬥夾具,本專案沒有現成的)。
	var host: SfxPlayerHost = auto_free(_make_host())
	host._on_selection_cleared()
	host._on_attack_resolved(1, 2, 5, false)
	host._on_entry_appended(AffinityTypes.Pair.C1_C2, null)
	host._on_open_rejected(0, "x")
	assert_array(host.diagnostic_play_requests).is_equal([
		SfxCueTable.CUE_CANCEL, SfxCueTable.CUE_ATTACK_HIT, SfxCueTable.CUE_AFFINITY_UP, SfxCueTable.CUE_CANCEL,
	])


func test_sfx_wiring_without_host_battle_screen_still_loads() -> void:
	# 取不到宿主(測試直接載入)靜默不接,不崩潰。
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.terrain_path_override = _TERRAIN_DUEL_PATH
	instance.roster_path_override = _ROSTER_DUEL_PATH
	add_child(instance)
	assert_object(instance._controller).is_not_null()


func test_sensitivity_proof_ac4_both_m5_and_m6_on_kill_is_caught() -> void:
	var host: SfxPlayerHost = _make_host(_MutantHostAlwaysHit)
	var instance: BattleScreen = _load_battle(host, _ROSTER_DUEL_PATH)
	instance._controller.click_tile(Vector2i(0, 0))
	instance._controller.click_tile(Vector2i(1, 0))
	# 真測試斷言「擊倒時不含 attack_hit」;mutant 下此條件為假 -> 真測試會紅。
	assert_bool(host.diagnostic_play_requests.has(SfxCueTable.CUE_ATTACK_HIT)).is_true()


# ---- AC-8:素材全缺席(真實 ResourceLoader)整場戰鬥不崩潰 ------------------

func test_sfx_wiring_all_assets_missing_full_battle_runs_clean() -> void:
	# 自製「全缺席」:九個 cue 皆指向不存在的路徑,走真實 ResourceLoader.exists。
	var absent: Dictionary = {}
	for cue_id: StringName in SfxCueTable.REQUIRED_CUE_IDS:
		absent[cue_id] = {"path": "res://assets/audio/sfx/__absent_for_test__.ogg", "min_interval_ms": 0, "bus": &"SFX"}
	var host: SfxPlayerHost = SfxPlayerHost.new()
	host.playback_enabled = false
	host.configure(SfxCuePolicy.new(absent, Callable(Time, "get_ticks_msec"),
			func(path: String) -> bool: return ResourceLoader.exists(path)))
	host.muted_check = func() -> bool: return false
	var instance: BattleScreen = _load_battle(host, _ROSTER_DUEL_PATH)
	instance._controller.click_tile(Vector2i(0, 0))
	instance._controller.click_tile(Vector2i(1, 0))
	assert_int(instance._controller.outcome()).is_equal(BattleState.Outcome.VICTORY)
	assert_int(host.diagnostic_play_requests.size()).is_equal(0)
	assert_bool(host.diagnostic_decisions.size() > 0).is_true()


# ---- AC-9 ------------------------------------------------------------------

func test_sfx_wiring_button_pressed_emits_m1_and_detaches_on_exit() -> void:
	var holder: Node = auto_free(Node.new())
	var existing: Button = Button.new()
	holder.add_child(existing)
	var host: SfxPlayerHost = _make_host()
	holder.add_child(host)
	add_child(holder)
	# 既有按鈕(走訪補連)
	existing.pressed.emit()
	assert_int(host.diagnostic_play_requests.size()).is_equal(1)
	# 執行期建立的按鈕(node_added)
	var runtime: Button = Button.new()
	holder.add_child(runtime)
	runtime.pressed.emit()
	assert_int(host.diagnostic_play_requests.size()).is_equal(2)
	assert_bool(host.diagnostic_play_requests.all(func(c: StringName) -> bool: return c == SfxCueTable.CUE_UI_CLICK)).is_true()
	# 離樹後不再產生請求
	holder.remove_child(runtime)
	runtime.pressed.emit()
	assert_int(host.diagnostic_play_requests.size()).is_equal(2)
	runtime.free()


func test_sfx_wiring_button_outside_host_scope_is_ignored() -> void:
	var scope: Node = auto_free(Node.new())
	var host: SfxPlayerHost = _make_host()
	scope.add_child(host)
	add_child(scope)
	var outsider: Button = auto_free(Button.new())
	add_child(outsider)
	outsider.pressed.emit()
	assert_int(host.diagnostic_play_requests.size()).is_equal(0)


# ---- AC-10 -----------------------------------------------------------------

func _mount_at_root(node: Node) -> void:
	get_tree().root.call_deferred("add_child", node)
	await get_tree().process_frame
	await get_tree().process_frame


func _hosts_under(root: Node) -> int:
	var n: int = 0
	for child: Node in root.get_children():
		if child is SfxPlayerHost:
			n += 1
	return n


func test_sfx_wiring_scene_router_leaves_exactly_one_host_per_scene() -> void:
	var original: Node = get_tree().current_scene
	var title: TitleScreen = load(SceneRouter.TITLE_SCENE_PATH).instantiate()
	await _mount_at_root(title)
	get_tree().current_scene = title
	assert_int(_hosts_under(title)).append_failure_message("TitleScreen 自行加一個宿主").is_equal(1)

	var created: Node = SceneRouter.switch_to(get_tree(), SceneRouter.TITLE_SCENE_PATH)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_int(_hosts_under(created)).append_failure_message("經 SceneRouter 切換後恰好一個宿主(不重複)").is_equal(1)
	assert_int(get_tree().get_nodes_in_group(SfxPlayerHost.GROUP_NAME).size()).is_equal(1)

	var settings: Node = SceneRouter.go_to_settings(get_tree())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(_hosts_under(settings)).is_equal(1)
	assert_int(get_tree().get_nodes_in_group(SfxPlayerHost.GROUP_NAME).size()).is_equal(1)

	settings.queue_free()
	await get_tree().process_frame
	get_tree().current_scene = original
