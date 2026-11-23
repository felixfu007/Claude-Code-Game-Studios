# production/epics/campfire/story-014-title-continue-and-new-game.md
# 標題畫面「繼續」與「新遊戲」(AC1~AC6)。全部載入真實 TitleScreen.tscn。
#
# 檔案存取聲明(.claude/rules/test-standards.md 登記例外之二):AC4 讀 src/ 原始碼
# 文字以斷言「本單新增碼不碰檔案系統」這條靜態紀律。⚠️ 它不證明窮盡 —— 只掃兩支檔案
# 的非註解行。本檔其餘部分不做任何 I/O。
#
# 「有進度」= 本次遊玩進過任一戰役場次(CampaignProgress.has_progress())。
# headless 不送 InputEvent:按鈕以 pressed.emit() 驅動;「停用鈕按了無作用」以
# disabled / focus_mode / 處理函式自身守衛三者斷言。
extends GdUnitTestSuite


const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"
const _ROWS: String = "Panel/ContentMargin/Rows/"


## 常駐變種(敏感度證明)①:「新遊戲」不呼叫重置。
class _MutantNewGameNoReset extends TitleScreen:
	func _start_fresh_campaign() -> void:
		# SENSITIVITY-MUTANT:拿掉 reset_campaign()
		start_tutorial()


## 常駐變種 ②:「繼續」永遠可按(有沒有進度都當作有)。
class _MutantContinueAlwaysEnabled extends TitleScreen:
	func _has_progress() -> bool:
		# SENSITIVITY-MUTANT:永遠回報有進度
		return true


## 常駐變種 ③:無進度時把「繼續」隱藏而非灰掉。
class _MutantContinueHidden extends TitleScreen:
	func _apply_continue_availability(has_progress: bool) -> void:
		# SENSITIVITY-MUTANT:隱藏取代停用
		var row: Button = $Panel/ContentMargin/Rows/ContinueRow
		row.visible = has_progress
		row.disabled = false


var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()
	TutorialProgress.end()


func after_test() -> void:
	_host_snap.restore()
	CampaignProgress.reset_for_test()
	TutorialProgress.end()


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


## 掛上標題(可指定變種腳本),設為 current_scene。
func _mount_title(mutant: Script = null) -> TitleScreen:
	var title: Node = load(_TITLE_SCENE_PATH).instantiate()
	if mutant != null:
		title.set_script(mutant)
	await _mount_at_root(title)
	get_tree().current_scene = title
	return title as TitleScreen


func _row(title: Node, row_name: String) -> Button:
	return title.get_node(_ROWS + row_name) as Button


## 製造「本次遊玩進過戰役場次」:推進到第 2 場並留一筆記錄。
func _make_progress() -> void:
	CampaignProgress.advance_on_victory(3)
	CampaignProgress.start_mission_affinity_ledger().append(
		AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION
	)


func _ledger_count() -> int:
	return CampaignProgress.start_mission_affinity_ledger().records().size()


# ── AC1:剛啟動 ───────────────────────────────────────────────────────────
func test_fresh_launch_continue_is_disabled_and_new_game_is_enabled() -> void:
	var original: Node = get_tree().current_scene
	var title: TitleScreen = await _mount_title()

	var cont: Button = _row(title, "ContinueRow")
	var new_game: Button = _row(title, "StartBattleRow")
	assert_bool(cont.disabled).append_failure_message("AC1:無進度「繼續」應停用").is_true()
	assert_bool(cont.visible).append_failure_message("AC1:停用不是隱藏").is_true()
	assert_bool(new_game.disabled).is_false()
	# 不得只靠顏色:文字改為「繼續(尚無進度)」
	assert_str(cont.text).is_equal(Loc.localize(TitleScreen.TEXT_CONTINUE_NO_PROGRESS))
	assert_bool(cont.text.is_empty()).is_false()
	# 預設焦點落在「新遊戲」
	assert_bool(new_game.has_focus()).is_true()
	assert_bool(cont.has_focus()).is_false()

	await _free_if_valid(title)
	get_tree().current_scene = original


func test_fresh_launch_continue_activation_does_nothing() -> void:
	var original: Node = get_tree().current_scene
	var title: TitleScreen = await _mount_title()

	# 手把確認 / 滑鼠點擊在停用鈕上引擎本身不會 emit;這裡連「硬 emit」也要無作用。
	_row(title, "ContinueRow").pressed.emit()
	await _wait_swap()

	assert_object(get_tree().current_scene).append_failure_message(
		"AC1:無進度按「繼續」不得切場景"
	).is_same(title)
	assert_int(_row(title, "ContinueRow").focus_mode).is_equal(Control.FOCUS_NONE)

	await _free_if_valid(title)
	get_tree().current_scene = original


# ── (C) 實測:無進度時上下焦點不得跳到灰掉的「繼續」 ──────────────────────
func test_no_progress_up_neighbor_of_new_game_is_not_the_disabled_continue() -> void:
	var original: Node = get_tree().current_scene
	var title: TitleScreen = await _mount_title()
	var cont: Button = _row(title, "ContinueRow")
	var new_game: Button = _row(title, "StartBattleRow")

	var up: Control = new_game.find_valid_focus_neighbor(SIDE_TOP)
	print("FOCUS-PROBE no-progress find_valid_focus_neighbor(TOP) = ", up.name if up != null else "null")
	assert_bool(up != cont).append_failure_message("無進度時往上不得到「繼續」").is_true()

	await _free_if_valid(title)
	get_tree().current_scene = original


## 對照組:若把停用鈕(FOCUS_ALL)明確指成鄰居,引擎會不會跳過它 —— 只記錄實測值。
func test_probe_engine_behaviour_when_disabled_button_is_explicit_neighbor() -> void:
	var original: Node = get_tree().current_scene
	var title: TitleScreen = await _mount_title()
	var cont: Button = _row(title, "ContinueRow")
	var new_game: Button = _row(title, "StartBattleRow")
	cont.focus_mode = Control.FOCUS_ALL
	new_game.focus_neighbor_top = new_game.get_path_to(cont)

	var up: Control = new_game.find_valid_focus_neighbor(SIDE_TOP)
	print("FOCUS-PROBE explicit-disabled-neighbor FOCUS_ALL find_valid_focus_neighbor(TOP) = ",
		up.name if up != null else "null", " cont.disabled=", cont.disabled)
	# 實測事實:引擎不會替你跳過「被明確指定為鄰居的停用鈕」,所以必須在接線時排除它。
	assert_object(up).is_same(cont)

	await _free_if_valid(title)
	get_tree().current_scene = original


func test_with_progress_up_neighbor_of_new_game_is_continue_and_default_focus_is_continue() -> void:
	_make_progress()
	var original: Node = get_tree().current_scene
	var title: TitleScreen = await _mount_title()
	var cont: Button = _row(title, "ContinueRow")
	var new_game: Button = _row(title, "StartBattleRow")

	assert_bool(cont.disabled).is_false()
	assert_str(cont.text).is_equal(Loc.localize(TitleScreen.TEXT_CONTINUE))
	assert_bool(cont.has_focus()).append_failure_message("有進度預設焦點在「繼續」").is_true()
	assert_object(new_game.find_valid_focus_neighbor(SIDE_TOP)).is_same(cont)
	assert_object(cont.find_valid_focus_neighbor(SIDE_BOTTOM)).is_same(new_game)

	await _free_if_valid(title)
	get_tree().current_scene = original


# ── AC2:有進度 → 繼續回到該場,累積記錄筆數不變 ───────────────────────────
func test_continue_returns_to_current_mission_with_same_ledger_count() -> void:
	_make_progress()
	var original: Node = get_tree().current_scene
	var mission_before: int = CampaignProgress.current_mission()
	var count_before: int = _ledger_count()
	var title: TitleScreen = await _mount_title()

	_row(title, "ContinueRow").pressed.emit()
	await _wait_swap()

	var battle: Node = get_tree().current_scene
	assert_str(battle.name if battle != null else "null").is_equal("BattleScreen")
	assert_int(CampaignProgress.current_mission()).is_equal(mission_before)
	assert_int(_ledger_count()).append_failure_message("AC2:繼續後累積記錄筆數應不變").is_equal(count_before)

	await _free_if_valid(battle)
	get_tree().current_scene = original


func test_entering_battle_via_router_marks_progress_and_title_after_it_enables_continue() -> void:
	var original: Node = get_tree().current_scene
	assert_bool(CampaignProgress.has_progress()).is_false()
	var battle: Node = SceneRouter.enter_battle(get_tree())
	await _wait_swap()
	assert_bool(CampaignProgress.has_progress()).is_true()
	await _free_if_valid(battle)
	await _free_if_valid(get_tree().current_scene)

	var title: TitleScreen = await _mount_title()
	assert_bool(_row(title, "ContinueRow").disabled).is_false()

	await _free_if_valid(title)
	get_tree().current_scene = original


func test_tutorial_alone_does_not_count_as_progress() -> void:
	var original: Node = get_tree().current_scene
	TutorialProgress.begin()
	var battle: Node = SceneRouter.enter_tutorial_battle(get_tree())
	await _wait_swap()
	assert_bool(CampaignProgress.has_progress()).is_false()
	await _free_if_valid(get_tree().current_scene)
	get_tree().current_scene = original


# ── AC3:新遊戲 ───────────────────────────────────────────────────────────
func test_new_game_without_progress_starts_tutorial_directly_without_confirm() -> void:
	var original: Node = get_tree().current_scene
	var title: TitleScreen = await _mount_title()

	_row(title, "StartBattleRow").pressed.emit()
	await _wait_swap()

	var battle: Node = get_tree().current_scene
	assert_str(battle.name if battle != null else "null").is_equal("BattleScreen")
	assert_bool(TutorialProgress.is_active()).is_true()

	await _free_if_valid(battle)
	get_tree().current_scene = original


func test_new_game_with_progress_opens_confirm_and_changes_nothing_yet() -> void:
	_make_progress()
	var original: Node = get_tree().current_scene
	var count_before: int = _ledger_count()
	var title: TitleScreen = await _mount_title()

	_row(title, "StartBattleRow").pressed.emit()
	await _wait_swap()

	assert_bool(title.is_confirm_open()).is_true()
	assert_object(get_tree().current_scene).is_same(title)
	assert_int(CampaignProgress.current_mission()).is_equal(2)
	assert_int(_ledger_count()).is_equal(count_before)
	# 預設焦點在「取消」,文案走在地化
	var cancel: Button = title.get_node("ConfirmOverlay/Panel/ContentMargin/Content/CancelButton")
	var restart: Button = title.get_node("ConfirmOverlay/Panel/ContentMargin/Content/RestartButton")
	assert_bool(cancel.has_focus()).is_true()
	assert_str(cancel.text).is_equal(Loc.localize(TitleScreen.TEXT_CONFIRM_CANCEL))
	assert_str(restart.text).is_equal(Loc.localize(TitleScreen.TEXT_CONFIRM_RESTART))

	await _free_if_valid(title)
	get_tree().current_scene = original


func test_confirm_cancel_closes_and_keeps_progress() -> void:
	_make_progress()
	var original: Node = get_tree().current_scene
	var count_before: int = _ledger_count()
	var title: TitleScreen = await _mount_title()
	_row(title, "StartBattleRow").pressed.emit()

	title.get_node("ConfirmOverlay/Panel/ContentMargin/Content/CancelButton").pressed.emit()
	await get_tree().process_frame

	assert_bool(title.is_confirm_open()).is_false()
	assert_int(CampaignProgress.current_mission()).is_equal(2)
	assert_int(_ledger_count()).is_equal(count_before)
	assert_bool(_row(title, "StartBattleRow").has_focus()).is_true()

	await _free_if_valid(title)
	get_tree().current_scene = original


func test_confirm_restart_resets_campaign_and_enters_tutorial() -> void:
	_make_progress()
	var original: Node = get_tree().current_scene
	var title: TitleScreen = await _mount_title()
	_row(title, "StartBattleRow").pressed.emit()

	title.get_node("ConfirmOverlay/Panel/ContentMargin/Content/RestartButton").pressed.emit()
	await _wait_swap()

	assert_int(CampaignProgress.current_mission()).append_failure_message("AC3:場次回起點").is_equal(1)
	assert_int(_ledger_count()).append_failure_message("AC3:累積記錄為空").is_equal(0)
	assert_bool(TutorialProgress.is_active()).is_true()
	var battle: Node = get_tree().current_scene
	assert_str(battle.name if battle != null else "null").is_equal("BattleScreen")

	await _free_if_valid(battle)
	get_tree().current_scene = original


func test_skip_tutorial_with_progress_also_asks_confirm() -> void:
	_make_progress()
	var original: Node = get_tree().current_scene
	var title: TitleScreen = await _mount_title()

	_row(title, "SkipTutorialRow").pressed.emit()
	await _wait_swap()

	assert_bool(title.is_confirm_open()).is_true()
	assert_object(get_tree().current_scene).is_same(title)

	await _free_if_valid(title)
	get_tree().current_scene = original


# ── AC4:不碰檔案系統(只掃非註解行)────────────────────────────────────────
func test_new_code_does_not_touch_filesystem() -> void:
	var needles: Array[String] = ["File" + "Access", "user" + ":" + "//", "Dir" + "Access"]
	for path: String in ["res://src/ui/shell/title_screen.gd", "res://src/core/campaign/campaign_progress.gd"]:
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		var text: String = f.get_as_text()
		f.close()
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for needle: String in needles:
				assert_bool(line.contains(needle)).append_failure_message(
					"AC4:%s 非註解行含 %s" % [path, needle]
				).is_false()


# ── AC5:按鈕位置固定 ─────────────────────────────────────────────────────
func _rects_of(title: Node) -> Array[Rect2]:
	return [_row(title, "ContinueRow").get_global_rect(), _row(title, "StartBattleRow").get_global_rect()]


func test_button_rects_identical_with_and_without_progress() -> void:
	var original: Node = get_tree().current_scene
	var title_a: TitleScreen = await _mount_title()
	var rects_a: Array[Rect2] = _rects_of(title_a)
	await _free_if_valid(title_a)

	_make_progress()
	var title_b: TitleScreen = await _mount_title()
	var rects_b: Array[Rect2] = _rects_of(title_b)

	assert_object(rects_a[0]).append_failure_message("AC5:繼續矩形").is_equal(rects_b[0])
	assert_object(rects_a[1]).append_failure_message("AC5:新遊戲矩形").is_equal(rects_b[1])
	assert_float(rects_a[0].size.x).is_greater(0.0)

	await _free_if_valid(title_b)
	get_tree().current_scene = original


# ── AC6:敏感度證明(常駐變種;一個 mutant 一次獨立執行)─────────────────────
func test_sensitivity_proof_mutant_new_game_without_reset_keeps_progress() -> void:
	_make_progress()
	var original: Node = get_tree().current_scene
	var title: TitleScreen = await _mount_title(_MutantNewGameNoReset)
	_row(title, "StartBattleRow").pressed.emit()
	title.get_node("ConfirmOverlay/Panel/ContentMargin/Content/RestartButton").pressed.emit()
	await _wait_swap()

	# 變種不重置:場次仍為 2、記錄仍在 —— 證明 AC3 斷言偵測得到。
	assert_int(CampaignProgress.current_mission()).is_equal(2)
	assert_int(_ledger_count()).is_greater(0)

	await _free_if_valid(get_tree().current_scene)
	get_tree().current_scene = original


func test_sensitivity_proof_mutant_continue_always_enabled_is_detected() -> void:
	var original: Node = get_tree().current_scene
	var title: TitleScreen = await _mount_title(_MutantContinueAlwaysEnabled)

	assert_bool(_row(title, "ContinueRow").disabled).is_false()

	await _free_if_valid(title)
	get_tree().current_scene = original


func test_sensitivity_proof_mutant_continue_hidden_moves_layout() -> void:
	var original: Node = get_tree().current_scene
	var normal: TitleScreen = await _mount_title()
	var rects_normal: Array[Rect2] = _rects_of(normal)
	await _free_if_valid(normal)

	var mutant: TitleScreen = await _mount_title(_MutantContinueHidden)
	var rects_mutant: Array[Rect2] = _rects_of(mutant)

	assert_bool(rects_mutant[1] != rects_normal[1]).append_failure_message(
		"隱藏「繼續」會讓「新遊戲」位置位移"
	).is_true()

	await _free_if_valid(mutant)
	get_tree().current_scene = original
