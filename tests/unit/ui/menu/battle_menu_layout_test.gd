# BattleMenu（src/ui/menu/battle_menu.gd / BattleMenu.tscn）的單元測試。
#
# 對應 story-u007-battle-menu-screen-layout.md 的 AC-M10 / AC-M11(焦點半部)/
# AC-M13,以及 Implementation Notes #2(版面驗算複驗義務,EPIC.md 陷阱十二)。
#
# ─── 敏感度證明門檻(.claude/rules/test-standards.md,2026-09-16 管理者裁決)───
# 每條測試逐條標記於其上方註解:
#   [常駐敏感度證明] = 本檔內有對應的 test_sensitivity_proof_* 佐證偵測方式有效
#   [不可證 - 類 A]  = 斷言對象是 static 純函式,沒有繼承鏈可覆寫
#   [不可證 - 類 C]  = 斷言對象綁在 .tscn 的 @onready 參照,注入需要一份「刻意缺節點」
#                      的替身場景,成本與價值不成比例(見下方個別測試的說明)
#
# 敏感度證明一律採用「間諜/突變子類別」技巧,不採用手動改壞→跑→改回
# （該手法已於 2026-09-16 淘汰,理由是它在版本庫裡不留痕跡）。本檔的突變子類別
# 均為「BattleMenu 的子類別,覆寫特定方法」,swap script 一律在 add_child()
# （進樹、_ready() 觸發)之前完成。
#
# 🔴 2026-09-17 獨立覆核(godot-specialist)更正:本節原本聲稱這個前提「已在
# prototypes/u007-focus-navigation-probe-2026-09-17/ 驗證過」,但覆核實測
# grep 該目錄的 set_script/instantiate/.tscn 皆為零命中——三支既有探針全程
# 用 Button.new() 手搭節點,從未載入過 BattleMenu.tscn 或呼叫過 set_script()。
# 那句話方向是對的(本檔的敏感度證明測試確實用這個技巧且全線通過),但附的
# 路徑內容對不上,比沒附路徑更容易騙過下一個查核的人。
#
# 已補上專門探針 `probe_set_script_timing.gd` 把這句話補成真的(逐字結論見
# 該檔與 run_output_set_script_timing.txt):
#   - 進樹【前】換腳本(本檔採用的技巧):@onready 節點解析正常、繼承呼叫鏈
#     正常觸發、_ready() 填入的實例變數(_row_base_text)保留完整 —— 安全。
#   - 進樹【後】才換腳本(test-standards.md 類 C 描述的未驗證情境,本檔
#     從未使用,只是探針順便量給協調者判斷):get_node() 仍能解析同一顆節點
#     (節點樹本身不受影響),但 _ready() 裡填入的實例變數狀態(_row_base_text)
#     會被重設回宣告時的預設值(空字典)——導致 _apply_unfocused_text() 對
#     字典取值失敗而噴錯。這印證了類 C 原本的疑慮是對的:進樹後換腳本
#     不安全,但這不影響本檔任何一條測試,因為本檔全部用「進樹前」這個
#     已驗證安全的時機。
#
# 命名慣例依 tests/unit/ui/hud_layout_test.gd / world_layout_test.gd 先例：
# test_[scenario]_[expected],extends GdUnitTestSuite。
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/menu/BattleMenu.tscn"

# 與 hud_layout_test.gd / world_layout_test.gd 同一組解析度慣例。
const RESOLUTIONS: Dictionary = {
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2560, 1440),
	"4K": Vector2i(3840, 2160),
	"ultrawide": Vector2i(3440, 1440),
}

const RESOLUTIONS_WITH_MIN_WINDOW: Dictionary = {
	"960x540": Vector2i(960, 540),
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2560, 1440),
	"4K": Vector2i(3840, 2160),
	"ultrawide": Vector2i(3440, 1440),
}

# design/ux/battle-menu.md「四種螢幕 × 三個字級檔位的驗算」表格逐字列舉的四種
# 螢幕——⚠️ 注意這組**不是**專案其他地方慣用的 1080p/2K/4K/ultrawide,而是
# 960x540/1080p/2K/4K（沒有 ultrawide）。逐字核對過表格本身,不是沿用慣例推的。
const BATTLE_MENU_MD_TABLE_RESOLUTIONS: Dictionary = {
	"960x540": Vector2i(960, 540),
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2560, 1440),
	"4K": Vector2i(3840, 2160),
}

# 同一份表格逐字抄錄的 fpx 欄(僅供交叉核對,不是本檔另外重推的公式——
# 下方測試呼叫的是 HudLayout.font_size()/WorldLayout.compute_scale(),
# 這裡只是把表格本身的數字打成常數方便逐格比對)。
const TABLE_FPX: Dictionary = {
	"960x540": 22, "1080p": 44, "2K": 55, "4K": 88,
}

# 表格「M1(100%)」欄(寬,高)。
const TABLE_M1_100: Dictionary = {
	"960x540": Vector2(220, 198), "1080p": Vector2(440, 396),
	"2K": Vector2(550, 495), "4K": Vector2(880, 792),
}

# 表格「M1(150%)」欄。⚠️ 2560×1440 這格,表格寫 825x742,但
# fpx(55) * 1.5 = 82.5,82.5*9 = 742.5——表格把 742.5 無條件捨去成 742。
# 下方測試對這一格改用 is_equal_approx(容忍 0.5),並在測試裡逐字記下這個
# 發現,而不是悄悄複製表格的捨去值當成「正確答案」。
const TABLE_M1_150: Dictionary = {
	"960x540": Vector2(330, 297), "1080p": Vector2(660, 594),
	"2K": Vector2(825, 742), "4K": Vector2(1320, 1188),
}

# 表格「M4(150%)」欄(僅寬高,M4 本體不在本 story 範圍——見 leave_confirm_size()
# 的 doc comment)。⚠️ 2560×1440 這格,表格寫 1155x578,但 82.5*7 = 577.5——
# 這次表格是「無條件進位」成 578,與上面 M1(150%) 同一列的「無條件捨去」方向
# 相反。兩格在同一列出現兩種不同的捨入方向,詳見本檔下方測試內的斷言與
# 交付回報。
const TABLE_M4_150: Dictionary = {
	"960x540": Vector2(462, 231), "1080p": Vector2(924, 462),
	"2K": Vector2(1155, 578), "4K": Vector2(1848, 924),
}


# ── 輔助函式 ────────────────────────────────────────────────────────────────


func _instantiate() -> Control:
	return auto_free(load(SCENE_PATH).instantiate())


func _real_ui_key_event(action: StringName) -> InputEventKey:
	# 依本專案既有慣例（frame_buffer_ordering_test.gd 等）：從真實 InputMap
	# 抓已綁定的事件再複製,不手猜 keycode——ui_up/ui_down 是引擎內建動作,
	# 這裡仍照專案慣例走,避免「猜錯 keycode 導致測試因錯誤原因通過/失敗」。
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var dup: InputEventKey = (event as InputEventKey).duplicate()
			dup.pressed = true
			return dup
	fail("PRECONDITION: no real InputEventKey bound to %s in this engine's InputMap." % action)
	return null


# ─── Implementation Notes #2 / EPIC.md 陷阱十二:版面驗算複驗義務 ───────────
# [不可證 - 類 A]（BattleMenu.panel_rect() / row_height() / leave_confirm_size()
# 皆為 static 純函式,沒有繼承鏈可覆寫——與 hud_layout_test.gd 對 HudLayout
# 自己那些 static 函式的既有處理一致)。


func test_panel_rect_matches_hud_layout_font_size_and_safe_rect_at_every_defined_resolution() -> void:
	for label: String in RESOLUTIONS_WITH_MIN_WINDOW:
		var window_size: Vector2i = RESOLUTIONS_WITH_MIN_WINDOW[label]
		var fpx: float = float(HudLayout.font_size(window_size))
		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var expected_size: Vector2 = Vector2(fpx * 10.0, fpx * 9.0)
		var expected_pos: Vector2 = safe.position + (safe.size - expected_size) / 2.0
		var rect: Rect2 = BattleMenu.panel_rect(window_size)
		assert_vector(rect.position).append_failure_message(
			"%s: panel_rect() position %s != HudLayout-derived expectation %s" % [label, rect.position, expected_pos]
		).is_equal_approx(expected_pos, Vector2(0.01, 0.01))
		assert_vector(rect.size).append_failure_message(
			"%s: panel_rect() size %s != HudLayout-derived expectation %s (10fpx x 9fpx)" % [label, rect.size, expected_size]
		).is_equal_approx(expected_size, Vector2(0.01, 0.01))


func test_row_height_equals_two_times_hud_layout_font_size_at_every_defined_resolution() -> void:
	for label: String in RESOLUTIONS_WITH_MIN_WINDOW:
		var window_size: Vector2i = RESOLUTIONS_WITH_MIN_WINDOW[label]
		var expected: float = float(HudLayout.font_size(window_size)) * 2.0
		assert_float(BattleMenu.row_height(window_size)).append_failure_message(
			"%s: row_height() = %.1f, expected 2 * HudLayout.font_size() = %.1f" % [
				label, BattleMenu.row_height(window_size), expected
			]
		).is_equal_approx(expected, 0.01)


func test_panel_rect_stays_within_safe_rect_at_every_defined_resolution() -> void:
	# AC-M10 核心主張:「M1... 完整落在安全區內」。
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var panel: Rect2 = BattleMenu.panel_rect(window_size)
		assert_bool(safe.encloses(panel)).append_failure_message(
			"%s: panel_rect() %s is not fully enclosed by safe_rect() %s" % [label, panel, safe]
		).is_true()


func test_leave_confirm_size_matches_hud_layout_font_size_at_every_defined_resolution() -> void:
	# M4 本體不在本 story 範圍（U-010),但版面驗算義務要求驗證它的尺寸算術。
	for label: String in RESOLUTIONS_WITH_MIN_WINDOW:
		var window_size: Vector2i = RESOLUTIONS_WITH_MIN_WINDOW[label]
		var fpx: float = float(HudLayout.font_size(window_size))
		var expected: Vector2 = Vector2(fpx * 14.0, fpx * 7.0)
		assert_vector(BattleMenu.leave_confirm_size(window_size)).append_failure_message(
			"%s: leave_confirm_size() = %s, expected 14fpx x 7fpx = %s" % [
				label, BattleMenu.leave_confirm_size(window_size), expected
			]
		).is_equal_approx(expected, Vector2(0.01, 0.01))


# 逐格核對 design/ux/battle-menu.md 自己的表格數字（不是核對本檔的常數,是核對
# 呼叫 HudLayout 算出來的數字是否等於該文件發佈的表）。2560x1440 的兩格因表格
# 本身的無條件捨去/進位差異改用近似比較,見上方常數的說明。
func test_battle_menu_md_table_values_match_hud_layout_derived_arithmetic() -> void:
	for label: String in BATTLE_MENU_MD_TABLE_RESOLUTIONS:
		var window_size: Vector2i = BATTLE_MENU_MD_TABLE_RESOLUTIONS[label]
		var fpx: int = HudLayout.font_size(window_size)
		assert_int(fpx).append_failure_message(
			"%s: HudLayout.font_size() = %d, battle-menu.md table says %d" % [label, fpx, TABLE_FPX[label]]
		).is_equal(TABLE_FPX[label])

		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var expected_safe_size: Vector2 = Vector2(window_size) * 0.9
		assert_vector(safe.size).append_failure_message(
			"%s: HudLayout.safe_rect() size %s != window*0.9 = %s (table's 安全區 column)" % [
				label, safe.size, expected_safe_size
			]
		).is_equal_approx(expected_safe_size, Vector2(0.01, 0.01))

		var m1_100: Vector2 = BattleMenu.panel_rect(window_size).size
		assert_vector(m1_100).append_failure_message(
			"%s: M1(100%%) = %s, battle-menu.md table says %s" % [label, m1_100, TABLE_M1_100[label]]
		).is_equal_approx(TABLE_M1_100[label], Vector2(0.01, 0.01))

		# M1(150%) — 75%/150% 字級功能本身未實作（BM-6),這裡只驗算術：把
		# fpx 乘以 1.5 之後,面板尺寸公式（10fpx x 9fpx）是否仍等於表格數字。
		var fpx_150: float = float(fpx) * 1.5
		var m1_150: Vector2 = Vector2(fpx_150 * 10.0, fpx_150 * 9.0)
		assert_vector(m1_150).append_failure_message(
			("%s: M1(150%%) 算術 = %s, battle-menu.md table 寫 %s"
				+ " ——2560x1440 這格允許 0.5px 誤差,已知表格本身把 742.5 無條件捨去成 742") % [
				label, m1_150, TABLE_M1_150[label]
			]
		).is_equal_approx(TABLE_M1_150[label], Vector2(0.6, 0.6))

		# M4(150%) — 同上,僅驗算術。
		var m4_150: Vector2 = Vector2(fpx_150 * 14.0, fpx_150 * 7.0)
		assert_vector(m4_150).append_failure_message(
			("%s: M4(150%%) 算術 = %s, battle-menu.md table 寫 %s"
				+ " ——2560x1440 這格允許 0.5px 誤差,已知表格本身把 577.5 無條件進位成 578"
				+ "（與同一列 M1(150%) 的捨去方向相反,兩者於同一份表格內不一致,已在交付回報中登記）") % [
				label, m4_150, TABLE_M4_150[label]
			]
		).is_equal_approx(TABLE_M4_150[label], Vector2(0.6, 0.6))


# ─── 場景結構 [不可證 - 類 C] ───────────────────────────────────────────────
# 斷言對象是 .tscn 的節點樹是否解析成功（@onready 參照)。這與
# tests/unit/ui/battle_screen_scene_test.gd 的既有測試同一類型/同一類別
# 判定——本專案已有一次真實事故（2026-08-27 UILayer 節點缺失,@onready 崩潰,
# 145 條既有測試全過因為沒人 load() 過那份 .tscn）就是這個形狀。要對這類測試做
# 敏感度證明,需要一份「刻意缺某個節點」的替身 .tscn,成本與這幾條簡單存在性
# 檢查的價值不成比例,故列為不可證,不強做。


func test_scene_instantiates_and_enters_tree_without_error() -> void:
	var instance: Node = _instantiate()
	add_child(instance)
	assert_object(instance).is_not_null()


func test_mask_node_resolves_as_colorrect_covering_full_rect() -> void:
	var instance: Control = _instantiate()
	add_child(instance)
	var mask: Node = instance.get_node("Mask")
	assert_object(mask).is_not_null()
	assert_bool(mask is ColorRect).is_true()
	# AC-M10「M0 覆蓋整個視窗(非安全區)」的決定層檢查:錨點必須是 FULL_RECT
	# (0,0,1,1)、四個 offset 皆 0——這保證 Mask 永遠等於自己父節點(BattleMenu)
	# 的完整 rect,不論視窗尺寸如何變動。視覺上「四周無亮邊」的套用層證據見
	# production/qa/evidence/battle-menu-layout-evidence.md。
	var mask_control: Control = mask as Control
	assert_float(mask_control.anchor_right).is_equal(1.0)
	assert_float(mask_control.anchor_bottom).is_equal(1.0)
	assert_float(mask_control.offset_left).is_equal(0.0)
	assert_float(mask_control.offset_top).is_equal(0.0)
	assert_float(mask_control.offset_right).is_equal(0.0)
	assert_float(mask_control.offset_bottom).is_equal(0.0)


func test_panel_node_resolves_as_panelcontainer() -> void:
	var instance: Control = _instantiate()
	add_child(instance)
	var panel: Node = instance.get_node("Panel")
	assert_object(panel).is_not_null()
	assert_bool(panel is PanelContainer).is_true()


func test_all_three_rows_resolve_as_buttons_with_focus_mode_all() -> void:
	var instance: Control = _instantiate()
	add_child(instance)
	for path in [
		"Panel/ContentMargin/Rows/ReturnToBattleRow",
		"Panel/ContentMargin/Rows/EndPhaseRow",
		"Panel/ContentMargin/Rows/QuitRow",
	]:
		var row: Node = instance.get_node(path)
		assert_object(row).append_failure_message("missing row node: %s" % path).is_not_null()
		assert_bool(row is Button).append_failure_message("%s is not a Button" % path).is_true()
		assert_int((row as Button).focus_mode).append_failure_message(
			"%s.focus_mode should be FOCUS_ALL" % path
		).is_equal(Control.FOCUS_ALL)


func test_divider_node_resolves_as_colorrect_with_focus_mode_none() -> void:
	var instance: Control = _instantiate()
	add_child(instance)
	var divider: Node = instance.get_node("Panel/ContentMargin/Rows/Divider")
	assert_object(divider).is_not_null()
	assert_bool(divider is ColorRect).is_true()
	assert_int((divider as Control).focus_mode).append_failure_message(
		"Divider must be FOCUS_NONE so directional navigation skips over it (Component Inventory: 分隔線 | ❌)"
	).is_equal(Control.FOCUS_NONE)


# ─── 焦點導覽行為(AC-M13 / 預設焦點 / P-F3)[常駐敏感度證明] ────────────────
# 每條「決定 vs 套用」都拆開驗(EPIC.md 陷阱十三通則):結構/屬性檢查是決定層,
# 真的注入 InputEventKey 走 Viewport 的原生 GUI 派送是套用層——兩者都做,不是
# 二選一。三個 test_sensitivity_proof_* 皆為「突變子類別於進樹前 set_script()」
# 技巧(見本檔開頭說明與
# prototypes/u007-focus-navigation-probe-2026-09-17/probe_set_script_timing.gd
# 的驗證),不是手動改壞正式程式碼。


func test_focus_starts_on_return_to_battle_row_after_ready() -> void:
	var instance: Control = _instantiate()
	add_child(instance)
	var return_row: Button = instance.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")
	assert_bool(return_row.has_focus()).append_failure_message(
		"battle-menu.md Component Inventory: 「回到遊戲」列 predsets 為 ✅ 預設焦點"
	).is_true()


## 突變:_ready() 跑完正常邏輯後,把焦點硬搶到「離開遊戲」列 —— 用來證明
## test_focus_starts_on_return_to_battle_row_after_ready 的斷言技巧
## (檢查 return_row.has_focus())確實能分辨「預設焦點正確」與「預設焦點錯誤」
## 兩種情況,而不是不管怎樣都會通過。
class _MutantStealsDefaultFocus extends BattleMenu:
	func _ready() -> void:
		super._ready()
		var quit_row: Button = get_node("Panel/ContentMargin/Rows/QuitRow")
		quit_row.grab_focus()


func test_sensitivity_proof_default_focus_detection_catches_wrong_row() -> void:
	var mutant: Control = load(SCENE_PATH).instantiate()
	mutant.set_script(_MutantStealsDefaultFocus)
	auto_free(mutant)
	add_child(mutant)
	var return_row: Button = mutant.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")
	assert_bool(return_row.has_focus()).append_failure_message(
		"SENSITIVITY PROOF FAILED: mutant deliberately steals focus to QuitRow in " +
		"_ready(), so return_row.has_focus() must be FALSE here — if it reads TRUE " +
		"the detection technique used by the real test cannot tell correct from broken."
	).is_false()


func test_pressing_up_on_first_row_does_not_wrap_to_last_row() -> void:
	# AC-M13.
	var instance: Control = _instantiate()
	add_child(instance)
	var return_row: Button = instance.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")
	var quit_row: Button = instance.get_node("Panel/ContentMargin/Rows/QuitRow")

	# 決定層:生產碼確實把 focus_neighbor_top 顯式指向自己(不依賴自動搜尋的
	# 隱含行為 —— 探針 Claim 1 已確認自動搜尋本來就不會繞回,但本檔選擇顯式
	# 設定作為防禦性保證,見 battle_menu.gd 的 _ready() 與其 doc comment)。
	assert_str(String(return_row.focus_neighbor_top)).append_failure_message(
		"ReturnToBattleRow.focus_neighbor_top should self-loop (\".\"), got %s" % return_row.focus_neighbor_top
	).is_equal(".")

	# 套用層:真的按一次「上」,確認引擎實際行為與決定層一致。
	assert_bool(return_row.has_focus()).is_true()
	get_viewport().push_input(_real_ui_key_event(&"ui_up"))
	await get_tree().process_frame

	assert_bool(return_row.has_focus()).append_failure_message(
		"AC-M13: pressing up on the first row must keep focus on it, not wrap to the last row."
	).is_true()
	assert_bool(quit_row.has_focus()).append_failure_message(
		"AC-M13: focus must NOT have wrapped to the last row (QuitRow)."
	).is_false()


## 突變:_ready() 跑完正常邏輯後,把第一列的 focus_neighbor_top 改指向最後一列
## ——模擬「繞回」這一類迴歸缺陷,證明上面那條測試的偵測方式(按上鍵後檢查
## return_row.has_focus())確實會在這種情況下轉紅。
class _MutantWrapsToLastRow extends BattleMenu:
	func _ready() -> void:
		super._ready()
		var return_row: Button = get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")
		var quit_row: Button = get_node("Panel/ContentMargin/Rows/QuitRow")
		return_row.focus_neighbor_top = return_row.get_path_to(quit_row)


func test_sensitivity_proof_no_wrap_detection_catches_reintroduced_wrap() -> void:
	var mutant: Control = load(SCENE_PATH).instantiate()
	mutant.set_script(_MutantWrapsToLastRow)
	auto_free(mutant)
	add_child(mutant)
	var return_row: Button = mutant.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")
	var quit_row: Button = mutant.get_node("Panel/ContentMargin/Rows/QuitRow")

	assert_bool(return_row.has_focus()).is_true()
	mutant.get_viewport().push_input(_real_ui_key_event(&"ui_up"))
	await get_tree().process_frame

	assert_bool(quit_row.has_focus()).append_failure_message(
		"SENSITIVITY PROOF FAILED: mutant deliberately reintroduces a wrap-to-last-row " +
		"regression, so QuitRow must have focus here — if it does not, the detection " +
		"technique used by the real AC-M13 test cannot tell correct from broken."
	).is_true()


func test_pressing_down_from_end_phase_row_skips_divider_reaches_quit_row() -> void:
	# 非 AC 明文要求,但是 M2 三列可用導覽的基本前提(分隔線不可擋住導覽)。
	var instance: Control = _instantiate()
	add_child(instance)
	var end_phase_row: Button = instance.get_node("Panel/ContentMargin/Rows/EndPhaseRow")
	var quit_row: Button = instance.get_node("Panel/ContentMargin/Rows/QuitRow")

	end_phase_row.grab_focus()
	assert_bool(end_phase_row.has_focus()).is_true()
	get_viewport().push_input(_real_ui_key_event(&"ui_down"))
	await get_tree().process_frame

	assert_bool(quit_row.has_focus()).append_failure_message(
		"Pressing down from EndPhaseRow should skip the FOCUS_NONE divider and land on QuitRow."
	).is_true()


## 突變:把「結束回合」列的 focus_neighbor_bottom 誤指向分隔線本身(並把分隔線
## 一併設為可聚焦,讓這條錯誤的接線真的可以被「走到」)——模擬「跳過分隔線的
## 顯式接線被誤接到分隔線本身」這一類迴歸缺陷。
##
## 🔴 本突變已於本檔第一輪撰寫後修正過一次:最初版本只把 Divider.focus_mode
## 改成 FOCUS_ALL、不動任何 focus_neighbor 接線,結果這條敏感度證明本身失敗
## (跑出來仍然是 QuitRow 拿到焦點)——因為生產碼在同一輪撰寫期間已經改用
## 「三列彼此直接顯式接線」(見 battle_menu.gd _ready() 的更正說明),不再依賴
## 自動幾何搜尋,所以單獨把分隔線設為可聚焦不會被自動搜尋撿到,不再是真正
## 會發生的迴歸缺陷形狀。本版改成直接竄改接線本身,才是接線機制底下真正
## 可能發生的錯誤。
class _MutantWrongNeighborPointsAtDivider extends BattleMenu:
	func _ready() -> void:
		super._ready()
		var end_phase_row: Button = get_node("Panel/ContentMargin/Rows/EndPhaseRow")
		var divider: Control = get_node("Panel/ContentMargin/Rows/Divider")
		divider.focus_mode = Control.FOCUS_ALL
		end_phase_row.focus_neighbor_bottom = end_phase_row.get_path_to(divider)


func test_sensitivity_proof_divider_skip_detection_catches_wrong_neighbor_wiring() -> void:
	var mutant: Control = load(SCENE_PATH).instantiate()
	mutant.set_script(_MutantWrongNeighborPointsAtDivider)
	auto_free(mutant)
	add_child(mutant)
	var end_phase_row: Button = mutant.get_node("Panel/ContentMargin/Rows/EndPhaseRow")
	var quit_row: Button = mutant.get_node("Panel/ContentMargin/Rows/QuitRow")
	var divider: Control = mutant.get_node("Panel/ContentMargin/Rows/Divider")

	end_phase_row.grab_focus()
	mutant.get_viewport().push_input(_real_ui_key_event(&"ui_down"))
	await get_tree().process_frame

	assert_bool(quit_row.has_focus()).append_failure_message(
		"SENSITIVITY PROOF FAILED: mutant deliberately makes the divider focusable, so " +
		"focus should land on the divider (not QuitRow) here — if QuitRow still has " +
		"focus, the detection technique used by the real test cannot tell correct from broken."
	).is_false()
	assert_bool(divider.has_focus()).append_failure_message(
		"Expected the mutant's focusable divider to actually receive focus, proving the " +
		"skip really was defeated (not some unrelated reason QuitRow lost focus)."
	).is_true()


# ─── 焦點視覺第二通道(P-F3)[常駐敏感度證明] ────────────────────────────────


func test_focus_visual_has_position_marker_not_color_only() -> void:
	var instance: Control = _instantiate()
	add_child(instance)
	var return_row: Button = instance.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")
	var end_phase_row: Button = instance.get_node("Panel/ContentMargin/Rows/EndPhaseRow")

	# 預設焦點在 ReturnToBattleRow —— 應該看得到標記字元。
	assert_str(return_row.text).append_failure_message(
		"Focused row's text should contain the position-marker glyph %s, got '%s'" % [
			BattleMenu.FOCUS_MARKER, return_row.text
		]
	).contains(BattleMenu.FOCUS_MARKER)
	# 未聚焦的列不應該看得到標記字元 —— 這是第二通道存在的直接證據:即使把
	# 灰階截圖裡的顏色資訊全部拿掉,「有沒有這個字元」仍然可以分辨。
	assert_str(end_phase_row.text).append_failure_message(
		"Unfocused row's text should NOT contain the position-marker glyph, got '%s'" % end_phase_row.text
	).not_contains(BattleMenu.FOCUS_MARKER)

	# 移動焦點後,標記應該跟著移動(而不是黏在原本那一列)。
	end_phase_row.grab_focus()
	assert_str(end_phase_row.text).contains(BattleMenu.FOCUS_MARKER)
	assert_str(return_row.text).not_contains(BattleMenu.FOCUS_MARKER)


## 突變:覆寫 _on_row_focus_entered() 使其不套用任何標記(模擬「焦點視覺
## 標記邏輯被移除/寫壞」的迴歸缺陷),證明上面測試的偵測方式(檢查 .text 是否
## 含有標記字元)確實會在這種情況下轉紅。前置技巧(進樹前 set_script() 保留
## @onready 節點解析、實例變數狀態與繼承呼叫鏈皆正常)實測見
## prototypes/u007-focus-navigation-probe-2026-09-17/probe_set_script_timing.gd
## 與其 run_output_set_script_timing.txt。
class _MutantNoFocusMarker extends BattleMenu:
	var mutant_focus_entered_called: bool = false
	func _on_row_focus_entered(_row: Button) -> void:
		mutant_focus_entered_called = true
		# 刻意什麼都不做 —— 標記邏輯被拿掉。


func test_sensitivity_proof_focus_marker_detection_catches_missing_marker_logic() -> void:
	var mutant: Control = load(SCENE_PATH).instantiate()
	mutant.set_script(_MutantNoFocusMarker)
	auto_free(mutant)
	add_child(mutant)
	var return_row: Button = mutant.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")

	# PRECONDITION:覆寫確實生效(排除「根本沒呼叫到覆寫」這個混淆因素)。
	assert_bool(mutant.get("mutant_focus_entered_called")).append_failure_message(
		"PRECONDITION: mutant's _on_row_focus_entered override was never invoked — " +
		"this sensitivity proof would be vacuous."
	).is_true()
	assert_str(return_row.text).append_failure_message(
		"SENSITIVITY PROOF FAILED: mutant deliberately disables the marker-apply logic, " +
		"so the focused row's text must NOT contain the marker glyph here — if it does, " +
		"the detection technique used by the real test cannot tell correct from broken."
	).not_contains(BattleMenu.FOCUS_MARKER)
