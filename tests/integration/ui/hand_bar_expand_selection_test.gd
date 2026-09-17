# HandBar（src/ui/battle/hand_bar.gd）的 U-012 測試 —— Z2 展開層 + Z3 卡牌細節 +
# 選牌導覽（S1)。工作單:
# production/epics/card-play-interface/story-u012-hand-expand-card-detail-selection.md
#
# 涵蓋範圍(逐項對應本 story 的達成狀況,詳見任務最終回報):
#   - render() 向下相容(既有 3 參數呼叫端與 tests/unit/ui/hand_bar_test.gd 全部
#     不必修改,本檔另外新增等價的顯式回歸)
#   - S1 展開/收合的邊緣觸發轉場(diagnostic_is_expanded / diagnostic_expand_progress /
#     diagnostic_expand_tween_is_running)
#   - move_cursor(delta) 的導覽、clamp(不循環)、非展開態/空手牌的 no-op
#   - AC-U2 後半「轉場動畫期間按 ← 立即選到前一張,輸入未被吞掉」的結構證明
#     (含一條 spy 證明本檔的判斷確實抓得到「動畫中吞掉輸入」這個具體錯誤)
#   - Z3 卡牌細節內容(甲類 ATK/DEF/剩N回合;丙類「永久」;絕不呼叫
#     Unit.active_modifiers() —— 那是 Z5 的資料,不是 Z3 的,見協調者裁決)
#   - Z2/Z3 純 static 版面計算函式(expanded_slot_bar_rect / expanded_slot_rect /
#     detail_panel_rect),比照 hand_bar_test.gd 既有 A 類慣例,不做敏感度證明
#   - 美術三節迴歸:第三節襯底座標(以真實版面函式算出、對照規格 N=2 驗算數字)、
#     第一節鎖圖示 4 矩形座標與鏤空存在性檢查、第二節間距常數
#
# 依 .claude/rules/test-standards.md 的完成門檻,逐條測試的敏感度分類寫在檔內
# 各測試自己的註解裡,不彙整成頂端一張表(彙整表會漂移,見既有 hand_bar_test.gd
# 檔頭對這件事的說明)。
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/battle/HandBar.tscn"
const MAX_SLOTS: int = 5

const RESOLUTIONS: Dictionary = {
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2560, 1440),
	"4K": Vector2i(3840, 2160),
	"ultrawide": Vector2i(3440, 1440),
}

## `design/art/battle-ui-glyph-spec.md`「驗證檔位」欄:所有數值皆以 N=2(最嚴苛
## 檔位)驗算 —— 960x540 是 fpx=22 的那一組,本檔沿用同一檔位核對規格自己的
## 「N=2 下的驗算」worked numbers。
const N2_WINDOW: Vector2i = Vector2i(960, 540)


# ─── 間諜子類別 —— 僅用於證明對應敏感度測試真的抓得到指定錯誤 ─────────────


# 模擬 AC-U2 明文禁止的錯誤形狀:「轉場動畫期間按 ← 輸入被吞掉」——覆寫
# move_cursor() 讓它在 tween 還在跑的時候直接不生效。
class _SpyHandBarBlocksCursorDuringExpandTween extends HandBar:
	func move_cursor(delta: int) -> void:
		if diagnostic_expand_tween_is_running():
			return
		super.move_cursor(delta)


static func _attach_bare_labels(spy: HandBar) -> void:
	var count_label: Label = Label.new()
	count_label.name = "CountLabel"
	spy.add_child(count_label)
	var unavailable_label: Label = Label.new()
	unavailable_label.name = "UnavailableLabel"
	spy.add_child(unavailable_label)


# ─── render() 向下相容 ──────────────────────────────────────────────────────


func test_render_without_new_args_defaults_to_collapsed() -> void:
	# 改壞哪一行會變紅:若 render() 的 expanded 參數預設值改成 true(或任何非
	# false 的預設),本測試立刻變紅 —— 直接斷言預設路徑的展開狀態。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)

	hand_bar.render([HandBar.SlotKind.TEMPORARY_MODIFIER], MAX_SLOTS, HandBar.Availability.NORMAL)

	assert_bool(hand_bar.diagnostic_is_expanded()).append_failure_message(
		"僅傳 3 參數呼叫 render() 時應維持 S0 收合態(向下相容既有呼叫端)"
	).is_false()
	assert_float(hand_bar.diagnostic_expand_progress()).is_equal(0.0)


# ─── S1 展開/收合 ───────────────────────────────────────────────────────────


func test_render_with_expanded_true_flips_state_and_starts_tween() -> void:
	# 改壞哪一行會變紅:若 render() 的 `if expanded != _expanded:` 判斷式被
	# 移除或恆為 false,_expanded 永遠不會變 true,第一條斷言變紅;若
	# _start_expand_tween() 呼叫被刪除,第二條斷言變紅(tween 為 null)。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)

	hand_bar.render([HandBar.SlotKind.TEMPORARY_MODIFIER], MAX_SLOTS, HandBar.Availability.NORMAL, false)
	hand_bar.render([HandBar.SlotKind.TEMPORARY_MODIFIER], MAX_SLOTS, HandBar.Availability.NORMAL, true)

	assert_bool(hand_bar.diagnostic_is_expanded()).is_true()
	assert_bool(hand_bar.diagnostic_expand_tween_is_running()).append_failure_message(
		"開手牌(expanded=true)應立即啟動 Z1->Z2 的 tween"
	).is_true()


func test_reexpanding_after_collapse_resets_cursor_to_zero() -> void:
	# 改壞哪一行會變紅:若 render() 裡「if expanded: _cursor_index = 0」被刪除,
	# 重新展開後游標會停在上次收合前的位置(2),而非重置為 0。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)
	var kinds: Array[HandBar.SlotKind] = [
		HandBar.SlotKind.TEMPORARY_MODIFIER, HandBar.SlotKind.TEMPORARY_MODIFIER,
		HandBar.SlotKind.TEMPORARY_MODIFIER,
	]

	hand_bar.render(kinds, MAX_SLOTS, HandBar.Availability.NORMAL, true)
	hand_bar.move_cursor(2)
	assert_int(hand_bar.diagnostic_cursor_index()).is_equal(2)

	hand_bar.render(kinds, MAX_SLOTS, HandBar.Availability.NORMAL, false)
	hand_bar.render(kinds, MAX_SLOTS, HandBar.Availability.NORMAL, true)

	assert_int(hand_bar.diagnostic_cursor_index()).append_failure_message(
		"重新展開(一次新的 S0->S1)應把游標重置到第 0 張,不應殘留上次收合前的位置"
	).is_equal(0)


# ─── move_cursor(delta) 導覽 ────────────────────────────────────────────────


func test_move_cursor_clamps_without_wraparound() -> void:
	# 改壞哪一行會變紅:若 clampi 換成 wrapi(循環),向左超界會變成跳到最後一張
	# 而非停在 0;向右超界會變成跳回 0 而非停在 size-1。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)
	var kinds: Array[HandBar.SlotKind] = [
		HandBar.SlotKind.TEMPORARY_MODIFIER, HandBar.SlotKind.TEMPORARY_MODIFIER,
		HandBar.SlotKind.TEMPORARY_MODIFIER,
	]
	hand_bar.render(kinds, MAX_SLOTS, HandBar.Availability.NORMAL, true)

	hand_bar.move_cursor(-1)
	assert_int(hand_bar.diagnostic_cursor_index()).append_failure_message(
		"從第 0 張再往左應停在 0,不應循環到最後一張"
	).is_equal(0)

	for _i in range(10):
		hand_bar.move_cursor(1)
	assert_int(hand_bar.diagnostic_cursor_index()).append_failure_message(
		"連續往右超過張數應停在最後一張(index 2),不應循環回 0"
	).is_equal(2)


func test_move_cursor_is_noop_when_not_expanded() -> void:
	# 改壞哪一行會變紅:若 move_cursor() 的 `if not _expanded: return` 守衛被
	# 刪除,S0(未展開)狀態下按左右鍵游標仍會移動。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)
	var kinds: Array[HandBar.SlotKind] = [
		HandBar.SlotKind.TEMPORARY_MODIFIER, HandBar.SlotKind.TEMPORARY_MODIFIER,
	]
	hand_bar.render(kinds, MAX_SLOTS, HandBar.Availability.NORMAL, false)

	hand_bar.move_cursor(1)

	assert_int(hand_bar.diagnostic_cursor_index()).append_failure_message(
		"S0(未展開)時 move_cursor() 應為 no-op"
	).is_equal(0)


func test_move_cursor_is_noop_when_hand_empty() -> void:
	# 改壞哪一行會變紅:若 `_slot_kinds.is_empty()` 守衛被刪除,S7(空手牌)
	# 展開時呼叫 move_cursor() 可能造成 clampi(x, 0, -1) 的無效範圍。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)
	hand_bar.render([], MAX_SLOTS, HandBar.Availability.NORMAL, true)

	hand_bar.move_cursor(1)

	assert_int(hand_bar.diagnostic_cursor_index()).is_equal(0)


# ─── AC-U2 後半:轉場動畫期間輸入不被吞掉(結構證明 + 敏感度證明) ──────────


func test_move_cursor_works_while_expand_tween_is_still_running() -> void:
	# AC-U2:「轉場動畫期間按 ← 立即選到前一張,輸入未被吞掉」。
	# 改壞哪一行會變紅:若 move_cursor() 被改成依賴 _expand_progress 或
	# tween 完成與否才生效(即 AC-U2 明文禁止的錯誤),第二條斷言變紅。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)
	var kinds: Array[HandBar.SlotKind] = [
		HandBar.SlotKind.TEMPORARY_MODIFIER, HandBar.SlotKind.TEMPORARY_MODIFIER,
		HandBar.SlotKind.TEMPORARY_MODIFIER,
	]
	hand_bar.render(kinds, MAX_SLOTS, HandBar.Availability.NORMAL, true)

	# 展開剛觸發,tween 應仍在跑(尚未經過任何 idle frame)。
	assert_bool(hand_bar.diagnostic_expand_tween_is_running()).append_failure_message(
		"本測試的前提是 tween 仍在執行中 —— 若這條斷言本身失敗,代表前提不成立," +
		"下面那條 move_cursor 斷言就不構成 AC-U2 的驗證"
	).is_true()

	hand_bar.move_cursor(1)

	assert_int(hand_bar.diagnostic_cursor_index()).append_failure_message(
		"AC-U2:轉場動畫期間(tween 仍在跑)按右鍵應立即選到下一張,不得被動畫吞掉"
	).is_equal(1)


func test_sensitivity_proof_ac_u2_would_catch_a_cursor_blocked_during_tween() -> void:
	# 證明上一條測試的判斷邏輯確實抓得到 AC-U2 要擋下的具體錯誤形狀 ——
	# 用一支「動畫還在跑就吞掉輸入」的間諜,證明同一組斷言在它身上必須為假。
	var spy: _SpyHandBarBlocksCursorDuringExpandTween = auto_free(
		_SpyHandBarBlocksCursorDuringExpandTween.new()
	)
	_attach_bare_labels(spy)
	add_child(spy)
	var kinds: Array[HandBar.SlotKind] = [
		HandBar.SlotKind.TEMPORARY_MODIFIER, HandBar.SlotKind.TEMPORARY_MODIFIER,
	]

	spy.render(kinds, MAX_SLOTS, HandBar.Availability.NORMAL, true)
	spy.move_cursor(1)

	var would_have_passed: bool = spy.diagnostic_cursor_index() == 1
	assert_bool(would_have_passed).append_failure_message(
		"AC-U2 斷言未能分辨出一個「轉場動畫期間吞掉游標移動輸入」的 move_cursor()"
	).is_false()


# ─── Z3 卡牌細節內容 ────────────────────────────────────────────────────────
# 🔴 內容只讀 [param card_faces] 與 [enum SlotKind] —— 不呼叫
# Unit.active_modifiers()(那是 Z5 逐條修正明細的資料來源,不是 Z3 的;
# 2026-09-17 協調者裁決,見任務最終回報)。
#
# 這裡直接呼叫 _set_expand_progress(1.0) 跳過真實 Tween 的計時,只為了在不
# 依賴任何 await/frame 假設的前提下,獨立驗證「進度到達 1.0 時內容管線畫出
# 什麼」——不證明 tween 本身會在真實時間內走到 1.0(那是動畫時序,Category C,
# 見任務最終回報)。


func test_detail_panel_shows_temporary_card_effect_summary_at_cursor() -> void:
	# 改壞哪一行會變紅:若 _update_detail_panel_content() 的 is_permanent 分支
	# 判斷寫反,或 _format_temporary_effect_summary() 的欄位順序/正負號格式跑掉,
	# 這兩條 assert_str 其中一條會變紅。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)
	var kinds: Array[HandBar.SlotKind] = [HandBar.SlotKind.TEMPORARY_MODIFIER]
	var faces: Array[Dictionary] = [{
		"flavor_text": "甲的鼓勵讓乙站得更穩",
		"delta_atk": 0,
		"delta_def": 2,
		"duration_rounds": 2,
	}]

	hand_bar.render(kinds, MAX_SLOTS, HandBar.Availability.NORMAL, true, faces)
	hand_bar._set_expand_progress(1.0)

	assert_bool(hand_bar.diagnostic_detail_panel_visible()).is_true()
	assert_str(hand_bar.diagnostic_detail_panel_text()).is_equal("甲的鼓勵讓乙站得更穩")
	assert_str(hand_bar.diagnostic_detail_effect_text()).append_failure_message(
		"甲類效果摘要格式跑掉:實得 '%s'" % hand_bar.diagnostic_detail_effect_text()
	).is_equal("ATK+0 · DEF+2 · 剩2回合")


func test_detail_panel_shows_permanent_mark_for_permanent_write_card() -> void:
	# 改壞哪一行會變紅:若 is_permanent 判斷式改成恆 false,丙類卡也會走甲類
	# 的效果摘要格式而非顯示「永久」—— 本測試連 delta 欄位都故意填非零值,
	# 證明丙類分支確實忽略它們而不是「剛好沒填所以看起來對」。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)
	var kinds: Array[HandBar.SlotKind] = [HandBar.SlotKind.PERMANENT_WRITE]
	var faces: Array[Dictionary] = [{
		"flavor_text": "丙⇄丁 並肩",
		"delta_atk": 99,
		"delta_def": 99,
		"duration_rounds": 99,
	}]

	hand_bar.render(kinds, MAX_SLOTS, HandBar.Availability.NORMAL, true, faces)
	hand_bar._set_expand_progress(1.0)

	assert_str(hand_bar.diagnostic_detail_panel_text()).is_equal("丙⇄丁 並肩")
	assert_str(hand_bar.diagnostic_detail_effect_text()).append_failure_message(
		"丙類卡應顯示「永久」,不得顯示 ATK/DEF/剩N回合格式(丙類本無存續回合)"
	).is_equal("永久")


func test_detail_panel_hidden_while_collapsed() -> void:
	# 改壞哪一行會變紅:若 _update_detail_panel_content() 的 showable 判斷式
	# 拿掉 _expand_progress 條件,S0 收合態下 Z3 仍會顯示。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)
	var faces: Array[Dictionary] = [{"flavor_text": "測試"}]

	hand_bar.render([HandBar.SlotKind.TEMPORARY_MODIFIER], MAX_SLOTS, HandBar.Availability.NORMAL, false, faces)

	assert_bool(hand_bar.diagnostic_detail_panel_visible()).append_failure_message(
		"S0(收合)時 Z3 不應顯示"
	).is_false()


func test_detail_panel_hidden_mid_transition() -> void:
	# 記錄本檔的揭露簡化:Z3 只在 progress 到達 1.0 才顯示(見
	# _update_detail_panel_content() 自己的註解)——過渡中途(例如 0.5)刻意
	# 不顯示,不是遺漏。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)
	var faces: Array[Dictionary] = [{"flavor_text": "測試"}]
	hand_bar.render([HandBar.SlotKind.TEMPORARY_MODIFIER], MAX_SLOTS, HandBar.Availability.NORMAL, true, faces)

	hand_bar._set_expand_progress(0.5)

	assert_bool(hand_bar.diagnostic_detail_panel_visible()).is_false()


# ─── Z2/Z3 純 static 版面計算函式(A 類,比照既有慣例不做敏感度證明)────────


func test_expanded_slot_bar_rect_width_equals_five_slots_plus_four_gaps_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var fpx: float = float(HudLayout.font_size(window_size))
		var bar: Rect2 = HandBar.expanded_slot_bar_rect(window_size, MAX_SLOTS)
		# 5*4.5 + 4*0.5 = 24.5 fpx —— 規格「合計 24.5 fpx 寬」逐字對應。
		assert_float(bar.size.x).append_failure_message(
			"%s: Z2 寬度應為 24.5 fpx" % label
		).is_equal_approx(24.5 * fpx, 0.01)


func test_expanded_slot_bar_rect_height_equals_six_fpx_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var fpx: float = float(HudLayout.font_size(window_size))
		var bar: Rect2 = HandBar.expanded_slot_bar_rect(window_size, MAX_SLOTS)
		assert_float(bar.size.y).is_equal_approx(6.0 * fpx, 0.01)


func test_expanded_slot_bar_rect_shares_bottom_edge_with_collapsed_bar_at_every_resolution() -> void:
	# 規格「同 Z1 錨點,原地向上長大」的字面驗證:Z1/Z2 下緣必須逐 px 相同,
	# 差異只能出現在上緣(往上長)。
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var collapsed: Rect2 = HandBar.slot_bar_rect(window_size, MAX_SLOTS)
		var expanded: Rect2 = HandBar.expanded_slot_bar_rect(window_size, MAX_SLOTS)
		assert_float(expanded.end.y).append_failure_message(
			"%s: Z2 下緣應與 Z1 下緣完全相同(原地向上長大,不是往下也長)" % label
		).is_equal_approx(collapsed.end.y, 0.01)
		assert_float(expanded.size.y).is_greater(collapsed.size.y)


func test_expanded_slot_bar_rect_is_horizontally_centered_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var bar: Rect2 = HandBar.expanded_slot_bar_rect(window_size, MAX_SLOTS)
		var expected_center_x: float = safe.position.x + safe.size.x / 2.0
		var actual_center_x: float = bar.position.x + bar.size.x / 2.0
		assert_float(actual_center_x).is_equal_approx(expected_center_x, 0.01)


func test_detail_panel_rect_width_equals_its_cards_width_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var card: Rect2 = HandBar.expanded_slot_rect(0, window_size)
		var detail: Rect2 = HandBar.detail_panel_rect(0, window_size)
		assert_float(detail.size.x).append_failure_message(
			"%s: Z3 寬度應等於該卡寬度(「寬 ≥ 該卡」以等號滿足)" % label
		).is_equal_approx(card.size.x, 0.01)


func test_detail_panel_rect_height_equals_four_fpx_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var fpx: float = float(HudLayout.font_size(window_size))
		var detail: Rect2 = HandBar.detail_panel_rect(0, window_size)
		assert_float(detail.size.y).is_equal_approx(4.0 * fpx, 0.01)


func test_detail_panel_rect_sits_directly_above_its_card_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var fpx: float = float(HudLayout.font_size(window_size))
		var card: Rect2 = HandBar.expanded_slot_rect(1, window_size)
		var detail: Rect2 = HandBar.detail_panel_rect(1, window_size)
		assert_float(detail.position.x).append_failure_message(
			"%s: Z3 應與第 1 張卡同一條 X 起點" % label
		).is_equal_approx(card.position.x, 0.01)
		assert_float(detail.end.y).append_failure_message(
			"%s: Z3 下緣應在該卡上緣再往上 DETAIL_PANEL_GAP_FPX_MULTIPLIER fpx" % label
		).is_equal_approx(card.position.y - 0.3 * fpx, 0.01)


# ─── 美術三節迴歸 —— 以真實版面函式定向取樣,不用盲目均勻網格/整圖色數 ──────


func test_backing_rect_matches_glyph_spec_n2_worked_numbers() -> void:
	# `design/art/battle-ui-glyph-spec.md` 三「N=2 下的驗算」逐字:寬約 18.8
	# fpx、高約 5.3 fpx。本測試不是重刻規格公式後比對——兩數字從
	# HAND_BAR_BACKING_PADDING_FPX_MULTIPLIER / LOCK_GLYPH_* / CAPTION_* /
	# COUNT_LABEL_* 這些既有常數算出,恰好與 18.8/5.3 精確相等(非四捨五入
	# 巧合,見 backing_rect() 自己的 doc comment 推導),故用嚴格誤差比對。
	var fpx: float = float(HudLayout.font_size(N2_WINDOW))
	assert_float(fpx).append_failure_message(
		"前提失真:N2_WINDOW 應對應規格的 N=2(fpx=22)檔位,實得 fpx=%.2f" % fpx
	).is_equal_approx(22.0, 0.001)

	var r: Rect2 = HandBar.backing_rect(MAX_SLOTS, N2_WINDOW)
	assert_float(r.size.x).append_failure_message(
		"N=2 下襯底寬度應為 18.8 fpx(=%.2f px),實得 %.2f px" % [18.8 * fpx, r.size.x]
	).is_equal_approx(18.8 * fpx, 0.01)
	assert_float(r.size.y).append_failure_message(
		"N=2 下襯底高度應為 5.3 fpx(=%.2f px),實得 %.2f px" % [5.3 * fpx, r.size.y]
	).is_equal_approx(5.3 * fpx, 0.01)


func test_backing_rect_fully_contains_lock_glyph_footprint_at_every_resolution() -> void:
	# 正向存在性檢查(截圖規則第 (a) 類):襯底必須完整覆蓋鎖圖示的座標範圍,
	# 這是第一節鏤空「背後有可預期深色底」這個前提能否成立的直接幾何證據。
	# 鎖圖示座標鏡射 _position_caption_and_lock_glyph() 自己的公式(同一份,
	# 用於交叉核對兩個已各自實作的函式是否互相一致,不是重新推導一條新規則)。
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var fpx: float = float(HudLayout.font_size(window_size))
		var caption_top: float = -(HandBar.CAPTION_GAP_FPX_MULTIPLIER + HandBar.CAPTION_HEIGHT_FPX_MULTIPLIER) * fpx
		var glyph_size: float = HandBar.LOCK_GLYPH_SIZE_FPX_MULTIPLIER * fpx
		var glyph_gap: float = HandBar.LOCK_GLYPH_GAP_FPX_MULTIPLIER * fpx
		var glyph_rect: Rect2 = Rect2(
			Vector2(-(glyph_size + glyph_gap), caption_top), Vector2(glyph_size, glyph_size)
		)

		var backing: Rect2 = HandBar.backing_rect(MAX_SLOTS, window_size)

		assert_float(backing.position.x).append_failure_message(
			"%s: 襯底左緣應在鎖圖示左緣之外(或等於)" % label
		).is_less_equal(glyph_rect.position.x)
		assert_float(backing.position.y).append_failure_message(
			"%s: 襯底上緣應在鎖圖示上緣之外(或等於)" % label
		).is_less_equal(glyph_rect.position.y)
		assert_float(backing.end.x).is_greater_equal(glyph_rect.end.x)
		assert_float(backing.end.y).is_greater_equal(glyph_rect.end.y)


func test_lock_glyph_gap_constant_is_point_six() -> void:
	# `design/art/battle-ui-glyph-spec.md` 二:0.3 -> 0.6。
	assert_float(HandBar.LOCK_GLYPH_GAP_FPX_MULTIPLIER).is_equal(0.6)


func test_lock_glyph_rects_match_glyph_spec_8x8_grid_coordinates() -> void:
	# 第一節座標表的直接迴歸——四個矩形各自的 anchor 分數必須精確等於規格表。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)
	var glyph: Control = hand_bar._lock_glyph

	assert_int(glyph.get_child_count()).append_failure_message(
		"鎖圖示應由 4 個矩形組成(body + 左柱 + 右柱 + 頂蓋),實得 %d" % glyph.get_child_count()
	).is_equal(4)

	var expected: Array[Array] = [
		[0.125, 0.875, 0.5, 1.0],    # body
		[0.25, 0.375, 0.125, 0.5],   # 左柱
		[0.625, 0.75, 0.125, 0.5],   # 右柱
		[0.25, 0.75, 0.0, 0.125],    # 頂蓋
	]
	for i in range(4):
		var child: ColorRect = glyph.get_child(i)
		assert_float(child.anchor_left).append_failure_message(
			"矩形 %d 的 anchor_left 不符規格表" % i
		).is_equal_approx(expected[i][0], 0.001)
		assert_float(child.anchor_right).is_equal_approx(expected[i][1], 0.001)
		assert_float(child.anchor_top).is_equal_approx(expected[i][2], 0.001)
		assert_float(child.anchor_bottom).is_equal_approx(expected[i][3], 0.001)


func test_lock_glyph_gap_between_posts_and_body_is_not_covered_by_any_rect() -> void:
	# 正向存在性檢查:鏤空洞口(左柱右緣到右柱左緣之間、頂蓋下緣到 body 上緣
	# 之間)必須真的沒有任何矩形覆蓋——這是第一節「鎖環有開口」的幾何前提,
	# 不是用色數判斷,是直接檢查座標覆蓋範圍。
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)
	var glyph: Control = hand_bar._lock_glyph

	var probe: Vector2 = Vector2(0.5, 0.3)  # 鏤空範圍正中央(0.375~0.625, 0.125~0.5)
	for i in range(glyph.get_child_count()):
		var child: ColorRect = glyph.get_child(i)
		var covers: bool = (
			probe.x >= child.anchor_left and probe.x <= child.anchor_right
			and probe.y >= child.anchor_top and probe.y <= child.anchor_bottom
		)
		assert_bool(covers).append_failure_message(
			"矩形 %d 覆蓋了理應鏤空的座標 %s —— 鎖環開口不成立" % [i, probe]
		).is_false()


func test_empty_slot_border_alpha_is_point_six() -> void:
	# `design/art/battle-ui-glyph-spec.md` 三:0.3 -> 0.6(有了固定深色襯底
	# 之後才成立)。
	assert_float(HandBar.EMPTY_SLOT_BORDER_ALPHA).is_equal(0.6)
	assert_float(HandBar.FILLED_SLOT_BORDER_ALPHA).append_failure_message(
		"填滿槽位的對比仍須明顯強於空槽(0.9 vs 0.6)"
	).is_equal(0.9)
