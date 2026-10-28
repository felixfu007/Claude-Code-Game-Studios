# Story 015 未涵蓋缺口:「出牌中途離開戰鬥」的游標交接
# (production/epics/cursor-highlight-state/story-015-battle-screen-surface-handoff.md 「未涵蓋」一行)
#
# 規格依據 -- design/gdd/cursor-highlight-state.md:
#   Core Rules #7「表面卸載前的目標交接義務」:表面卸載前,若「目前游標目標的表面類型標籤
#   等於自己的類型」,必須 mark_pending_reresolve 或設定新目標,不得直接卸載。
#   AC-51:卸載完成後,不存在「目前游標目標的表面類型標籤沒有任何已掛載實例」的情況。
#   規格的判準是【目標的表面類型】,不是「該表面此刻是否登記在註冊表」。
#
# 本戰鬥畫面的出牌流程(battle_screen.gd,已讀):
#   - 戰鬥畫面不使用 CARD_SLOT;手牌選擇(S1)用 hand_bar 自己的索引,不改游標目標。
#   - S0->S1(open_hand)會【解除註冊 BOARD_TILE】,但游標目標仍是 BOARD_TILE。
#   - S1->S2(confirm 選卡)再【重新註冊 BOARD_TILE】。
#   所以出牌中途存在兩種形狀:S1 =「目標屬 BOARD_TILE、但 BOARD_TILE 未註冊」;
#   S2 =「目標屬 BOARD_TILE、且已註冊」。
#
# 預期(由上述規格推出,規格對此情境有明文適用,無需另行裁定):
#   兩種形狀下離開戰鬥後,CursorStateHost.is_current_target_valid() == false,
#   且 BOARD_TILE 註冊表無殘留。
#
# 🔴 I/O 揭露(test-standards.md 甲類例外):load()/instantiate() 真實的 BattleScreen.tscn,
# 其 _ready() 唯讀 assets/data/ 底下 vs01_* 已進版控的真實資料檔,不寫入任何檔案;
# 無法以注入取代 -- 要驗的就是真實畫面的 _ready()/出牌流程/離開行為。
#
# 敏感度證明:常駐變種(Case A:進樹前 set_script,且未設任何 override 屬性)。
#   變種模擬一種看似合理的誤改:「只有當 BOARD_TILE 仍登記在註冊表時才交接」。
#   該變種在 S1(表面已解除註冊)會漏交接。
#
# 涵蓋範圍自陳:只釘 S1、S2 兩個出牌步驟;未涵蓋 S3(確認面板)與敵方回合中離開。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


# 變種:只有 BOARD_TILE 仍登記時才交接(S1 時表面已被 open_hand 解除註冊 -> 漏交接)。
class _MutantHandoffOnlyIfRegistered extends BattleScreen:
	func _on_tree_exited_cursor_handoff() -> void:
		var registry: CursorSurfaceRegistry = CursorStateHost.get(&"_registry") as CursorSurfaceRegistry
		if registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE) != null:
			var current: CursorTarget = CursorStateHost.get_current_target()
			if current != null and current.surface == CursorTypes.SurfaceType.BOARD_TILE:
				CursorStateHost.mark_pending_reresolve(current)
		CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE)


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


func _real_pressed_event(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


func _mount(instance: BattleScreen) -> BattleScreen:
	auto_free(instance)
	add_child(instance)
	return instance


func _enter_s1(instance: BattleScreen) -> void:
	instance._input(_real_pressed_event(&"battle_open_hand"))
	assert_bool(instance._card_selecting_from_hand).is_true()
	# S1 形狀:目標屬 BOARD_TILE,但 BOARD_TILE 已解除註冊。
	assert_bool(CursorStateHost.is_current_target_valid()).is_true()
	assert_object(_registered_board_tile()).is_null()


func _enter_s2(instance: BattleScreen) -> void:
	_enter_s1(instance)
	instance._input(_real_pressed_event(&"battle_confirm"))
	assert_int(instance._controller._card_play_session.step()).is_equal(CardPlaySession.Step.SELECTING_TARGET)
	# S2 形狀:BOARD_TILE 已重新註冊。
	assert_object(_registered_board_tile()).is_not_null()


func _registered_board_tile() -> Object:
	var registry: CursorSurfaceRegistry = CursorStateHost.get(&"_registry") as CursorSurfaceRegistry
	return registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE)


func test_leave_battle_while_selecting_card_s1_marks_target_pending_and_leaves_no_registration() -> void:
	var instance: BattleScreen = _mount(load(_SCENE_PATH).instantiate())
	_enter_s1(instance)

	remove_child(instance)

	assert_bool(CursorStateHost.is_current_target_valid()).append_failure_message(
		"S1 出牌中離開戰鬥:目標屬 BOARD_TILE,規格(Core Rules #7/AC-51)要求卸載前已標待重新解析"
	).is_false()
	assert_object(_registered_board_tile()).is_null()


func test_leave_battle_while_selecting_target_s2_marks_target_pending_and_unregisters_surface() -> void:
	var instance: BattleScreen = _mount(load(_SCENE_PATH).instantiate())
	_enter_s2(instance)

	remove_child(instance)

	assert_bool(CursorStateHost.is_current_target_valid()).append_failure_message(
		"S2 選目標中離開戰鬥:目標屬 BOARD_TILE,規格(Core Rules #7/AC-51)要求卸載前已標待重新解析"
	).is_false()
	assert_object(_registered_board_tile()).is_null()


func test_sensitivity_proof_registered_only_guard_mutant_misses_handoff_in_s1() -> void:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.set_script(_MutantHandoffOnlyIfRegistered)
	_mount(instance)
	_enter_s1(instance)

	remove_child(instance)

	# 偵測得到:變種在 S1 漏交接,目標殘留為有效。
	assert_bool(CursorStateHost.is_current_target_valid()).is_true()
