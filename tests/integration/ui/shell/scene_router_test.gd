# production/epics/game-shell/story-005-manual-scene-handoff-and-leave-to-title.md
# 整合測試 —— Unit A:SceneRouter 本身(AC1、AC2 的純新增部分)。
# 掛載/等幀/還原 current_scene 的慣例照抄 title_screen_scene_switch_test.gd:
# 每條測試開頭存 current_scene 原值、結尾無條件還原;切換後至少等 2 個 process_frame。
#
# 🔴 敏感度證明:本檔沒有常駐 test_sensitivity_* —— 理由屬 test-standards.md 的【A 類】:
# SceneRouter 全部是 static 函式,沒有繼承鏈可覆寫成變種。(a)(c) 斷言的是 switch_to() 本體
# 「在 add_child 之前呼叫 configure」,唯一有意義的注入點就是那一行正式程式碼(兼屬 D 類)。
# 實作者 2026-10-27 依協調者派工單做過一次【暫時注入】(把 configure 呼叫改成 if false),
# 結果 exit 100、(a) FAILED,已還原、grep 零殘留 —— 但 2026-09-16 裁決已淘汰暫時注入,
# 因為它在版本庫裡不留痕跡,上述結果只能憑實作者回報,不可查證。允許暫時注入是協調者
# 派工單的錯,不是實作者的。
extends GdUnitTestSuite


const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"


var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()


func after_test() -> void:
	# Full shared-Autoload restore (target/authority/flags/buffer/registry); see
	# tests/helpers/cursor_host_snapshot.gd. Kept the pre-existing cleanup below.
	_host_snap.restore()
	CampaignProgress.reset_for_test()


func _mount_at_root(node: Node) -> void:
	get_tree().root.call_deferred("add_child", node)
	await get_tree().process_frame
	await get_tree().process_frame


func _free_if_valid(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await get_tree().process_frame


func _wait_swap() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


# ── (a) configure 在 add_child 之前被呼叫 ──────────────────────────────────
func test_scene_router_switch_to_calls_configure_before_instance_enters_tree() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	var title: TitleScreen = load(_TITLE_SCENE_PATH).instantiate()
	await _mount_at_root(title)
	get_tree().current_scene = title
	var seen: Dictionary = {"calls": 0, "inside_tree": true}
	var configure: Callable = func(instance: Node) -> void:
		seen["calls"] = int(seen["calls"]) + 1
		seen["inside_tree"] = instance.is_inside_tree()

	# Act
	var created: Node = SceneRouter.switch_to(get_tree(), _TITLE_SCENE_PATH, configure)
	await _wait_swap()

	# Assert
	assert_int(int(seen["calls"])).append_failure_message("configure 應恰好被呼叫一次").is_equal(1)
	assert_bool(bool(seen["inside_tree"])).append_failure_message(
		"configure 被呼叫的當下 instance 不應已進樹(注入窗在 add_child 之前)"
	).is_false()

	# Cleanup
	await _free_if_valid(created)
	get_tree().current_scene = original


# ── (b) 舊場景被釋放、current_scene 換成新實例 ─────────────────────────────
func test_scene_router_switch_to_replaces_current_scene_and_frees_old() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	var old_title: TitleScreen = load(_TITLE_SCENE_PATH).instantiate()
	await _mount_at_root(old_title)
	get_tree().current_scene = old_title

	# Act
	var created: Node = SceneRouter.switch_to(get_tree(), _TITLE_SCENE_PATH)
	await _wait_swap()

	# Assert
	assert_bool(get_tree().current_scene == created).append_failure_message(
		"current_scene 應為 switch_to 回傳的新實例"
	).is_true()
	assert_bool(created != old_title).is_true()
	assert_bool(is_instance_valid(old_title)).append_failure_message(
		"舊場景等幀後應已被釋放"
	).is_false()

	# Cleanup
	await _free_if_valid(created)
	get_tree().current_scene = original


# ── (c) enter_battle 注入的是 CampaignProgress 同一個帳本物件 ──────────────
func test_scene_router_enter_battle_injects_campaign_ledger_from_progress() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	var title: TitleScreen = load(_TITLE_SCENE_PATH).instantiate()
	await _mount_at_root(title)
	get_tree().current_scene = title

	# Act
	SceneRouter.enter_battle(get_tree())
	await _wait_swap()

	# Assert
	var battle: BattleScreen = get_tree().current_scene as BattleScreen
	assert_object(battle).append_failure_message("current_scene 應為 BattleScreen").is_not_null()
	assert_object(battle.campaign_ledger_override).append_failure_message(
		"BattleScreen 應已收到戰役帳本"
	).is_not_null()
	# start_mission_affinity_ledger() 回傳進行中那份(同一物件);再呼叫一次不得換新物件。
	assert_bool(battle.campaign_ledger_override == CampaignProgress.start_mission_affinity_ledger()).append_failure_message(
		"注入的帳本應與 CampaignProgress 的進行中帳本是同一個物件"
	).is_true()

	# Cleanup
	await _free_if_valid(battle)
	get_tree().current_scene = original


# ── (d) 戰鬥 → go_to_title 之後 BOARD_TILE 已釋放 ──────────────────────────
func test_scene_router_go_to_title_after_battle_releases_board_tile() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	var title: TitleScreen = load(_TITLE_SCENE_PATH).instantiate()
	await _mount_at_root(title)
	get_tree().current_scene = title
	SceneRouter.enter_battle(get_tree())
	await _wait_swap()
	var probe_busy: Node = Node.new()
	var busy_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(
		CursorTypes.SurfaceType.BOARD_TILE, probe_busy
	)
	probe_busy.free()
	assert_int(busy_result).append_failure_message(
		"precondition: 戰鬥場景應已佔住 BOARD_TILE"
	).is_equal(CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED)

	# Act
	SceneRouter.go_to_title(get_tree())
	await _wait_swap()

	# Assert
	var scene: Node = get_tree().current_scene
	assert_str(scene.name if scene != null else "null").is_equal("TitleScreen")
	var probe: Node = Node.new()
	var result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(
		CursorTypes.SurfaceType.BOARD_TILE, probe
	)
	assert_int(result).append_failure_message(
		"離開戰鬥後 BOARD_TILE 應已釋放(REGISTERED)"
	).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE)
	probe.free()

	# Cleanup
	await _free_if_valid(scene)
	get_tree().current_scene = original
