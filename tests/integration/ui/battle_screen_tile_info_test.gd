# Story 012(格位資訊面板)—— 純格式化/組裝函式的測試。
#
# 手法沿用 tests/unit/ui/battle_screen_preview_test.gd 既有先例:這些函式不碰節點、
# 不碰場景樹、不碰 CursorStateHost —— headless 下引擎不送 InputEvent
# (.claude/docs/coding-standards.md),_refresh_view()/_update_tile_info_panel() 本身
# 無法在這裡直接測,能測的是它們呼叫的、已拆成純函式的那一層:地形名稱/行動狀態的顯示
# 名稱對應、七個分欄格式化函式、以及把它們組成完整面板文字的 build_tile_info_text()。
#
# 🔴 本檔放在 tests/integration/ui/ 而非沿用慣例的 tests/unit/ui/ —— 依派工單明文的
# 檔案鎖範圍(本 story 只允許在 tests/integration/ui/ 底下新增測試檔),不是分類判斷
# 錯誤;這些測試實質上與 battle_screen_preview_test.gd 同一種純函式測試。
#
# 敏感度:這批函式全是 match/if 字面量對應與字串格式化,任何一種注入(改分支回傳值、
# 改格式化樣板)都會讓對應斷言的期望字面值當場不相等 —— 不需要另外的間諜子類別或
# test_sensitivity_proof_* 測試(test-standards.md「已知證明不了的五類」之外的情況:
# 這裡沒有繼承鏈,也沒有唯讀的全域狀態,是最直接的「輸入 -> 輸出」純函式驗證)。
extends GdUnitTestSuite


var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	# Restore shared CursorStateHost Autoload state; see tests/helpers/cursor_host_snapshot.gd
	_host_snap.restore()



# ---- terrain_display_name() ------------------------------------------------

func test_terrain_display_name_open() -> void:
	assert_str(BattleScreen.terrain_display_name(Board.TERRAIN_OPEN)).is_equal("開闊地")


func test_terrain_display_name_brush() -> void:
	assert_str(BattleScreen.terrain_display_name(Board.TERRAIN_BRUSH)).is_equal("灌木")


func test_terrain_display_name_fallen_log() -> void:
	assert_str(BattleScreen.terrain_display_name(Board.TERRAIN_FALLEN_LOG)).is_equal("倒木")


func test_terrain_display_name_unregistered_char_falls_back_to_unknown() -> void:
	# Board 本身對未登記地形字元會 push_error() 並回傳明確失敗值(見 Board.get_terrain()/
	# get_move_cost() 的 doc comment)——這裡驗證面板這一層仍能產生某個可顯示文字，
	# 不會直接炸掉。
	assert_str(BattleScreen.terrain_display_name("Z")).is_equal("未知地形")


# ---- action_state_display_name() -------------------------------------------

func test_action_state_display_name_none_used() -> void:
	assert_str(
		BattleScreen.action_state_display_name(TurnOrder.ActionState.NONE_USED)
	).is_equal("皆未用")


func test_action_state_display_name_attack_only() -> void:
	assert_str(
		BattleScreen.action_state_display_name(TurnOrder.ActionState.ATTACK_ONLY)
	).is_equal("只剩攻擊")


func test_action_state_display_name_move_only() -> void:
	assert_str(
		BattleScreen.action_state_display_name(TurnOrder.ActionState.MOVE_ONLY)
	).is_equal("只剩移動")


func test_action_state_display_name_done() -> void:
	assert_str(
		BattleScreen.action_state_display_name(TurnOrder.ActionState.DONE)
	).is_equal("已行動")


func test_action_state_display_name_not_found_has_its_own_defensive_label() -> void:
	assert_str(
		BattleScreen.action_state_display_name(TurnOrder.ActionState.NOT_FOUND)
	).is_equal("（查無此單位）")


# ---- 分欄格式化函式 ----------------------------------------------------------

func test_cost_line_shows_real_cost() -> void:
	assert_str(BattleScreen.format_tile_info_cost_line(2)).is_equal("移動成本：2")


func test_cost_line_unknown_terrain_sentinel_never_prints_as_a_number() -> void:
	# Board.MOVE_COST_UNKNOWN_TERRAIN(-1)是明確失敗哨兵，不是合法成本——絕不可讓
	# 面板把它當成本數字印出來（協調者 dispatch 2026-10-15 明文提醒的陷阱）。
	assert_str(
		BattleScreen.format_tile_info_cost_line(Board.MOVE_COST_UNKNOWN_TERRAIN)
	).is_equal("移動成本：未知")


func test_concealment_line_true_and_false_are_distinct_and_never_merged_with_cost() -> void:
	assert_str(BattleScreen.format_tile_info_concealment_line(true)).is_equal("遮蔽：是")
	assert_str(BattleScreen.format_tile_info_concealment_line(false)).is_equal("遮蔽：否")


func test_terrain_line_format() -> void:
	assert_str(BattleScreen.format_tile_info_terrain_line(Board.TERRAIN_OPEN)).is_equal("地形：開闊地")


func test_faction_line_player_and_enemy() -> void:
	assert_str(
		BattleScreen.format_tile_info_faction_line(Unit.Faction.PLAYER)
	).is_equal("陣營：我方")
	assert_str(
		BattleScreen.format_tile_info_faction_line(Unit.Faction.ENEMY)
	).is_equal("陣營：敵方")


func test_hp_line_format() -> void:
	assert_str(BattleScreen.format_tile_info_hp_line(7, 20)).is_equal("HP：7/20")


func test_state_line_format() -> void:
	assert_str(
		BattleScreen.format_tile_info_state_line(TurnOrder.ActionState.MOVE_ONLY)
	).is_equal("狀態：只剩移動")


func test_weapon_range_line_format() -> void:
	assert_str(BattleScreen.format_tile_info_weapon_range_line(1, 4)).is_equal("武器射程：1–4")


func test_mp_line_format() -> void:
	assert_str(BattleScreen.format_tile_info_mp_line(5)).is_equal("MP：5")


# ---- build_tile_info_text() —— 完整面板文字組裝（Visual/Audio §1.4 正交性） ------

func test_build_tile_info_text_empty_tile_shows_three_terrain_lines_and_occupant_none() -> void:
	# Arrange / Act —— 無佔位單位的倒木格
	var text: String = BattleScreen.build_tile_info_text(
		Board.TERRAIN_FALLEN_LOG, 3, true,
		false, Unit.Faction.PLAYER, 0, 0, TurnOrder.ActionState.NOT_FOUND, 0, 0, 0
	)
	var lines: PackedStringArray = text.split("\n")

	# Assert —— terrain_cost 與遮蔽各自獨立一行，不得合併成單一「特殊地形」欄位
	assert_int(lines.size()).is_equal(4)
	assert_str(lines[0]).is_equal("地形：倒木")
	assert_str(lines[1]).is_equal("移動成本：3")
	assert_str(lines[2]).is_equal("遮蔽：是")
	assert_str(lines[3]).is_equal("（無佔位單位）")


func test_build_tile_info_text_with_occupant_appends_five_more_lines() -> void:
	# Arrange / Act —— 開闊地，站著一個敵方單位
	var text: String = BattleScreen.build_tile_info_text(
		Board.TERRAIN_OPEN, 1, false,
		true, Unit.Faction.ENEMY, 12, 30, TurnOrder.ActionState.ATTACK_ONLY, 2, 4, 3
	)
	var lines: PackedStringArray = text.split("\n")

	# Assert —— 3 行地形資訊（終-成本-遮蔽）+ 5 行佔位單位資訊 = 8 行
	assert_int(lines.size()).is_equal(8)
	assert_str(lines[0]).is_equal("地形：開闊地")
	assert_str(lines[1]).is_equal("移動成本：1")
	assert_str(lines[2]).is_equal("遮蔽：否")
	assert_str(lines[3]).is_equal("陣營：敵方")
	assert_str(lines[4]).is_equal("HP：12/30")
	assert_str(lines[5]).is_equal("狀態：只剩攻擊")
	assert_str(lines[6]).is_equal("武器射程：2–4")
	assert_str(lines[7]).is_equal("MP：3")
