# production/epics/game-shell/story-001-title-screen-and-scene-switching.md
# 整合測試 —— 涵蓋 AC4(切到戰鬥)/ AC5(戰鬥結束回標題)/ AC6(來回切換的
# tree_exited 迴歸鎖)/ AC9(標題畫面不註冊任何游標表面)。AC1~AC3/AC7/AC8/AC10
# 不在本檔範圍(AC10 為 ADVISORY,待管理者截圖簽核)。
#
# 寫法直接比照 prototypes/shell-layer-scene-switch-probe-2026-10-19/probe_scene_switch.gd
# 這支已經實機證明過「怎麼問才問得到」的探針:load() 真實場景檔(不自組替身節點
# 鏈)、root.call_deferred("add_child", instance) 進樹(_ready() 內直接 add_child
# 會被引擎拒絕)、change_scene_to_file() 之後至少等 2 個 process_frame 才能假設新
# 場景已掛上樹(探針 Q3 的混合時機量測結果)。
#
# 🔴 每個觸碰 get_tree().current_scene / change_scene_to_file() 的測試,開頭先存
# 下 get_tree().current_scene 的原始值,收尾無條件還原 —— 這是本專案第一支會呼叫
# change_scene_to_file() 的測試,GdUnit4 測試執行環境下 current_scene 原本是什麼
# 並無既有先例可循;save/restore 讓本檔不必假設那個值是什麼,也確保不會把一個
# 被切換出去的場景(連同它向 CursorStateHost 註冊的 BOARD_TILE)遺留給下一個
# 完全無關的測試檔,重演 battle_screen.gd 1282~1301 行註解記載的那次事故
# (CursorNavigationApplier._process() 在無關場景撞到已釋放節點)。
extends GdUnitTestSuite


const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"
const _BATTLE_SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


## 把 [param node] 以 production 的真實生命週期掛上樹:call_deferred 進
## [member SceneTree.root],等 2 個 process_frame 讓 [method Node._ready] 跑完
## (比照探針,也是這個專案「不得在 _ready() 內直接 add_child()」紀律的推論結果)。
func _mount_at_root(node: Node) -> void:
	get_tree().root.call_deferred("add_child", node)
	await get_tree().process_frame
	await get_tree().process_frame


## 清掉由 change_scene_to_file() 切換出來、目前掛在 current_scene 上的場景,
## 避免把它(與它可能持有的 CursorSurfaceRegistry 註冊)遺留到下一個測試。
func _free_if_valid(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await get_tree().process_frame


# ── AC4:「開始戰鬥」切到 BattleScreen,current_scene 確為 BattleScreen ────────
# 測試直接呼叫公開方法 start_battle(),不模擬 InputEvent(headless 不送
# InputEvent,.claude/docs/coding-standards.md CI 節已登記)。
func test_start_battle_switches_current_scene_to_battle_screen() -> void:
	# Arrange
	var original_current_scene: Node = get_tree().current_scene
	var title: TitleScreen = load(_TITLE_SCENE_PATH).instantiate()
	await _mount_at_root(title)
	get_tree().current_scene = title

	# Act
	title.start_battle()
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert
	var switched: Node = get_tree().current_scene
	assert_object(switched).append_failure_message(
		"start_battle() 之後 current_scene 不應為 null"
	).is_not_null()
	assert_str(switched.name).append_failure_message(
		"AC4: start_battle() 之後 current_scene 應為 BattleScreen,實得 %s" % [switched.name if switched != null else "null"]
	).is_equal("BattleScreen")

	# Cleanup
	await _free_if_valid(switched)
	get_tree().current_scene = original_current_scene


# ── AC5:戰鬥結束之後回到標題畫面 ────────────────────────────────────────────
# 測試直接呼叫公開方法 return_to_title_screen(),不等待 RESULT_DISPLAY_SECONDS
# 的真實時間流逝 —— 與 AC4 同一慣例(battle_screen.gd 該方法自己的 doc comment
# 也這樣寫)。
func test_return_to_title_screen_switches_current_scene_to_title_screen() -> void:
	# Arrange
	var original_current_scene: Node = get_tree().current_scene
	var battle: BattleScreen = load(_BATTLE_SCENE_PATH).instantiate()
	await _mount_at_root(battle)
	get_tree().current_scene = battle

	# Act
	battle.return_to_title_screen()
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert
	var switched: Node = get_tree().current_scene
	assert_object(switched).append_failure_message(
		"return_to_title_screen() 之後 current_scene 不應為 null"
	).is_not_null()
	assert_str(switched.name).append_failure_message(
		"AC5: return_to_title_screen() 之後 current_scene 應為 TitleScreen,實得 %s" % [switched.name if switched != null else "null"]
	).is_equal("TitleScreen")

	# Cleanup
	await _free_if_valid(switched)
	get_tree().current_scene = original_current_scene


# ── AC6:🔴 來回切換的 tree_exited 迴歸鎖(EPIC 全域硬性實作義務的迴歸鎖)───────
# 標題 -> 戰鬥 -> 標題 -> 戰鬥,斷言第二個 BattleScreen 是全新實例(非同一物件
# 被搬回樹),且它自己的 _ready() 乾淨地重新佔住了 BOARD_TILE —— 比照探針的
# Q2-BEFORE-SWITCH / Q2-AFTER-SWITCH / Q4-BOARD-TILE 三步,但這裡用真正的公開
# 方法往返切換,不是像探針那樣手動呼叫 change_scene_to_file() 兩次。
# 「零 SCRIPT ERROR」這件事本身由跑全套時人工核對引擎輸出佐證(見任務報告),
# 本測試能自動斷言的是它的可觀測後果:BOARD_TILE 的註冊狀態全程保持單一佔用。
func test_round_trip_title_battle_title_battle_cleanly_reregisters_board_tile() -> void:
	# Arrange
	var original_current_scene: Node = get_tree().current_scene
	var title_1: TitleScreen = load(_TITLE_SCENE_PATH).instantiate()
	await _mount_at_root(title_1)
	get_tree().current_scene = title_1

	# Act 1 — 標題 -> 戰鬥(第一個 BattleScreen)
	title_1.start_battle()
	await get_tree().process_frame
	await get_tree().process_frame
	var battle_1: Node = get_tree().current_scene
	assert_str(battle_1.name if battle_1 != null else "null").append_failure_message(
		"round-trip 第一步:current_scene 應為 BattleScreen"
	).is_equal("BattleScreen")

	# Assert — BattleScreen#1 自己的 _ready() 應已佔住 BOARD_TILE(非破壞性探測:
	# 用一個全新節點嘗試註冊同一個 tag,DUPLICATE_TAG_REJECTED 時 register() 保證
	# 不寫入,不會干擾 battle_1 自己的註冊)。
	var probe_1: Node = Node.new()
	var result_1: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(
		CursorTypes.SurfaceType.BOARD_TILE, probe_1
	)
	assert_int(result_1).append_failure_message(
		"precondition: BattleScreen#1._ready() 應已佔住 BOARD_TILE"
	).is_equal(CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED)
	probe_1.free()

	# Act 2 — 戰鬥 -> 標題(battle_1 的 tree_exited 安全網應釋放 BOARD_TILE)
	battle_1.return_to_title_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	var title_2: Node = get_tree().current_scene
	assert_str(title_2.name if title_2 != null else "null").append_failure_message(
		"round-trip 第二步:current_scene 應為 TitleScreen"
	).is_equal("TitleScreen")

	# Assert — 🔴 本測試最關鍵的一行:battle_1 的 tree_exited 安全網
	# (battle_screen.gd:1301 一帶)必須已經解除 BOARD_TILE,否則下一個
	# BattleScreen 會被誤判成「重複佔用」。
	var probe_2: Node = Node.new()
	var result_2: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(
		CursorTypes.SurfaceType.BOARD_TILE, probe_2
	)
	assert_int(result_2).append_failure_message(
		"AC6 核心斷言:切回標題畫面後 BOARD_TILE 應已被 BattleScreen#1 的 " +
		"tree_exited 安全網釋放(REGISTERED),而非仍被佔用(DUPLICATE_TAG_REJECTED) " +
		"—— 後者代表 EPIC 全域硬性實作義務的那條 tree_exited 連線被破壞"
	).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	# 探測本身會真的佔住 tag,立刻解除,避免污染下一步。
	CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE)
	probe_2.free()

	# Act 3 — 標題 -> 戰鬥(第二個 BattleScreen,應為全新實例)
	title_2.start_battle()
	await get_tree().process_frame
	await get_tree().process_frame
	var battle_2: Node = get_tree().current_scene
	assert_str(battle_2.name if battle_2 != null else "null").append_failure_message(
		"round-trip 第三步:current_scene 應為 BattleScreen"
	).is_equal("BattleScreen")
	assert_bool(battle_2 == battle_1).append_failure_message(
		"AC6: 第二個 BattleScreen 應為全新實例,不是同一個被重新加回樹的物件"
	).is_false()

	# Assert — battle_2 自己的 _ready() 必須乾淨地重新佔住 BOARD_TILE,不得與
	# 任何殘留註冊衝突。
	var probe_3: Node = Node.new()
	var result_3: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(
		CursorTypes.SurfaceType.BOARD_TILE, probe_3
	)
	assert_int(result_3).append_failure_message(
		"AC6: 第二個 BattleScreen 的 _ready() 應已乾淨地重新佔住 BOARD_TILE"
	).is_equal(CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED)
	probe_3.free()

	# Cleanup
	await _free_if_valid(battle_2)
	get_tree().current_scene = original_current_scene


# ── AC9:TitleScreen 不向 CursorStateHost 註冊任何表面 ───────────────────────
# 對 CursorTypes.SurfaceType 已登記的全部 4 個值逐一探測(非破壞性,見上方
# DUPLICATE_TAG_REJECTED 的保證不寫入特性):掛載 TitleScreen 之後,任何一個
# tag 都不應該已被佔用 —— 若某個 tag 回報 DUPLICATE_TAG_REJECTED,代表有某個
# 東西(理論上只可能是 TitleScreen 自己)佔住了它。
func test_title_screen_does_not_register_any_cursor_surface() -> void:
	# Arrange
	var title: TitleScreen = auto_free(load(_TITLE_SCENE_PATH).instantiate())
	add_child(title)
	await get_tree().process_frame

	var all_surface_types: Array[CursorTypes.SurfaceType] = [
		CursorTypes.SurfaceType.BOARD_TILE,
		CursorTypes.SurfaceType.RELATION_MINIMAP_NODE,
		CursorTypes.SurfaceType.CARD_SLOT,
		CursorTypes.SurfaceType.DIALOGUE_CHOICE,
	]

	for surface_type: CursorTypes.SurfaceType in all_surface_types:
		var probe: Node = Node.new()
		var result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(surface_type, probe)
		assert_int(result).append_failure_message(
			"AC9: TitleScreen 不應佔用任何 CursorSurfaceRegistry tag,但 %s 回報 %s" % [
				CursorTypes.SurfaceType.find_key(surface_type),
				CursorSurfaceRegistry.RegisterResult.find_key(result),
			]
		).is_not_equal(CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED)
		# 探測本身若成功註冊,立刻解除,不留在表裡影響其他測試。
		if result == CursorSurfaceRegistry.RegisterResult.REGISTERED:
			CursorStateHost.unregister_surface(surface_type)
		probe.free()
