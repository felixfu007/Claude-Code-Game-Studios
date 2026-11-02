## Regression test for 2026-11-02 bug: 選單「回主選單」後 SceneTree 仍 paused,
## 標題畫面全部點不動。成因:[code]BattleMenu._on_return_to_title_pressed()[/code]
## 直接路由、沒呼叫 [code]close()[/code](全 src/ 只有 close() 會復原 paused 與仲裁)。
##
## 分類:無檔案 I/O,無例外需宣告。按鈕以 [code].pressed.emit()[/code] 直接觸發
## (headless 下模擬啟用不會觸發 Button.pressed,見 battle_menu_leave_confirmation_test.gd 檔頭)。
## 🔴 回主選單 callable 一律注入 stub(未注入 = 真的切場景)。
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/menu/BattleMenu.tscn"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	get_tree().paused = false
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host != null:
		host.set(&"_arbitration_suspended", false)


func _return_to_title_button(instance: Node) -> Button:
	return instance.get_node("LeaveConfirm/Panel/ContentMargin/Content/Buttons/ReturnToTitleButton")


## 舊寫法突變:直接路由、不 close()。
class _MutantNoClose extends BattleMenu:
	func _on_return_to_title_pressed() -> void:
		if return_to_title_callable.is_valid():
			return_to_title_callable.call()


func _arbitration_suspended() -> bool:
	return bool(get_tree().root.get_node("CursorStateHost").get(&"_arbitration_suspended"))


## Returns [paused_at_route_time, suspended_at_route_time] after opening and pressing 回主選單.
func _run_scenario(instance: BattleMenu) -> Array[bool]:
	var seen: Array[bool] = [true, true]
	instance.return_to_title_callable = func() -> void:
		seen[0] = get_tree().paused
		seen[1] = _arbitration_suspended()
	add_child(instance)
	assert_int(instance.open()).is_equal(BattleMenu.OpenResult.OPENED)
	# precondition: open() really paused + suspended, else the test proves nothing
	assert_bool(get_tree().paused).is_true()
	assert_bool(_arbitration_suspended()).is_true()
	instance.open_leave_confirm()
	_return_to_title_button(instance).pressed.emit()
	return seen


func test_return_to_title_resumes_tree_and_arbitration_before_routing() -> void:
	var instance: BattleMenu = auto_free(load(SCENE_PATH).instantiate())

	var seen: Array[bool] = _run_scenario(instance)

	assert_bool(seen[0]).append_failure_message("tree still paused when routing to title").is_false()
	assert_bool(seen[1]).append_failure_message("arbitration still suspended when routing to title").is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_arbitration_suspended()).is_false()


func test_sensitivity_proof_return_to_title_without_close_leaves_tree_paused() -> void:
	var mutant: Control = load(SCENE_PATH).instantiate()
	mutant.set_script(_MutantNoClose)
	auto_free(mutant)

	var seen: Array[bool] = _run_scenario(mutant)

	assert_bool(seen[0]).append_failure_message(
		"SENSITIVITY PROOF FAILED: old (no close()) behaviour must leave tree paused at route time."
	).is_true()
	assert_bool(get_tree().paused).is_true()
