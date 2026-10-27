# Story 015 -- 戰鬥畫面離開時的游標交接整合測試
# (production/epics/cursor-highlight-state/story-015-battle-screen-surface-handoff.md AC4)
#
# 📌 這支測試是「日後每個新表面(關係圖、支援對話畫面……)的交接範本」:
# 任何註冊過游標表面、且目前目標可能屬於自己的畫面,離開(tree_exited)時都必須
# 照 GDD Core Rules #7「表面卸載前的目標交接義務」/ AC-51 先 mark_pending_reresolve
# 再解除註冊。新表面請照本檔形狀寫一份:進樹 -> 斷言目標有效 -> 移除 ->
# 斷言 is_current_target_valid() == false 且註冊表已無該表面。
#
# 🔴 I/O 揭露(test-standards.md 甲類例外):load()/instantiate() 真實的
# BattleScreen.tscn,其 _ready() 唯讀 assets/data/ 底下 vs01_* 已進版控的真實資料檔。
# 不寫入任何檔案。無法以注入取代:要驗的就是真實畫面 _ready() 的註冊/播種結果。
#
# 敏感度證明:常駐變種(Case A:進樹前 set_script,且在設任何屬性之前)。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


# 變種:離開時只解除註冊、不交接 -- 即 Story 015 之前的行為。
class _MutantUnregisterOnly extends BattleScreen:
	func _on_tree_exited_cursor_handoff() -> void:
		CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE)


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


func _mount_and_unmount(instance: BattleScreen) -> void:
	auto_free(instance)
	add_child(instance)
	# Arrange sanity: mounted screen owns a valid BOARD_TILE target.
	assert_bool(CursorStateHost.is_current_target_valid()).is_true()
	assert_object(_registered_board_tile()).is_not_null()
	remove_child(instance)


func test_battle_screen_exit_marks_target_pending_and_unregisters_surface() -> void:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	_mount_and_unmount(instance)

	assert_bool(CursorStateHost.is_current_target_valid()).is_false()
	assert_object(_registered_board_tile()).is_null()


func test_sensitivity_proof_unregister_only_mutant_leaves_target_valid() -> void:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.set_script(_MutantUnregisterOnly)
	_mount_and_unmount(instance)

	# 偵測得到:變種不交接,目標殘留為有效(正是本工作單要修的缺陷)。
	assert_bool(CursorStateHost.is_current_target_valid()).is_true()
	assert_object(_registered_board_tile()).is_null()


func _registered_board_tile() -> Object:
	var registry: CursorSurfaceRegistry = CursorStateHost.get(&"_registry") as CursorSurfaceRegistry
	return registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE)
