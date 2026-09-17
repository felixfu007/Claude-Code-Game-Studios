# HandBar（src/ui/battle/hand_bar.gd / HandBar.tscn）的單元測試 —— Story U-011
# （production/epics/card-play-interface/story-u011-hand-bar-thumbnails.md）。
#
# 涵蓋:
#   - AC-U4 前半（空槽輪廓與 0/5,test_empty_hand_shows_empty_slot_outline_and_0_of_5）
#   - test_hand_bar_shows_n_of_5_matching_deck_hand_size（Test Evidence 指定測試名）
#   - test_category_icon_distinguishable_without_color（Test Evidence 指定測試名,
#     白箱,為 U-012 的 AC-U6 預先鋪墊)
#   - S5 三通道（降對比 + 鎖狀圖示 + 文案)的正向測試與敏感度證明
#   - Z1 幾何(呼叫既有 HudLayout 函式合成,不重刻其公式)
#
# 依 .claude/rules/test-standards.md 2026-09-16 管理者裁決的完成門檻,逐條測試的
# 分類(有常駐證明 / 屬已知五類之一)寫在該任務的最終回報裡,不在此複述數字
# ——本檔內容本身才是查證來源,一份摘要一旦漂移就會誤導下一個人。摘要如下,
# 供快速定位,細節與逐條理由以最終回報為準:
#   - 純 static 函式（icon_shape_for / count_text / slot_bar_rect / slot_rect）
#     屬「已知證明不了的五類」之 A 類 —— 沒有繼承鏈可覆寫,不做敏感度證明。
#   - render() 與 diagnostic_* 是有繼承鏈的實例行為,四條
#     test_sensitivity_proof_* 各自用一個間諜子類別證明對應的正向測試斷言確實
#     分得出「正確」與「被動過手腳」——不是巧合綠燈(其中兩條互為鏡像方向:
#     LOCKED 被砍成 NORMAL 的樣子 / NORMAL 被恆套用 LOCKED 效果,兩個相反的
#     錯誤各自需要一條證明,其中一個通過不代表另一個方向也驗證過)。
#   - test_scene_instantiates_and_enters_tree_without_error 屬 D 類 —— 唯一有
#     意義的注入點(從 HandBar.tscn 移除一個節點)本身就是修改正式場景檔案。
#
# 命名慣例依 tests/unit/ui/board_coords_test.gd / hud_layout_test.gd 先例：
# test_[scenario]_[expected],extends GdUnitTestSuite。
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/battle/HandBar.tscn"

const RESOLUTIONS: Dictionary = {
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2560, 1440),
	"4K": Vector2i(3840, 2160),
	"ultrawide": Vector2i(3440, 1440),
}

const MAX_SLOTS: int = 5


# ---- 間諜子類別 —— 不修改 hand_bar.gd 本體,僅用於證明下面三條敏感度證明測試
# 的判斷邏輯真的會抓到對應的錯誤,而不是巧合綠燈 ---------------------------------

# 模擬「S5 的降對比/文案兩個通道,render() 途中被悄悄砍掉」這個 AC-U4 後半要
# 擋下的具體錯誤 —— 覆寫 diagnostic_dim_factor() 讓「降對比」永遠回報 1.0
# (未降對比),並在 super.render() 之後把文案復原成 NORMAL 的樣子。
class _SpyHandBarDropsLockVisuals extends HandBar:
	func diagnostic_dim_factor() -> float:
		return 1.0
	func render(slot_kinds: Array[SlotKind], max_slots: int, availability: Availability) -> void:
		super.render(slot_kinds, max_slots, availability)
		_unavailable_label.visible = false


# 反方向的錯誤(_SpyHandBarDropsLockVisuals 的鏡像):render() 完全忽略傳入的
# availability 參數,永遠套用 LOCKED 的視覺效果 —— 這是
# test_normal_availability_shows_no_lock_glyph_or_caption_and_full_alpha
# 要擋下的錯誤形狀,與「LOCKED 被砍成 NORMAL 的樣子」是相反的兩個錯誤,
# 需要各自的敏感度證明,其中一個測試通過不代表另一個方向也被驗證過。
class _SpyHandBarAlwaysAppliesLockedVisuals extends HandBar:
	func render(slot_kinds: Array[SlotKind], max_slots: int, _availability: Availability) -> void:
		super.render(slot_kinds, max_slots, Availability.LOCKED)


# 模擬「空槽判斷被誤植為恆真」——即使手牌是空的,diagnostic_slot_is_filled()
# 仍回報每一格都有牌,這正是 AC-U4 前半要擋下的錯誤形狀。
class _SpyHandBarAlwaysReportsSlotsFilled extends HandBar:
	func diagnostic_slot_is_filled(_index: int) -> bool:
		return true


# 模擬「count label 與實際傳入的 slot_kinds 脫鉤」——render() 正常跑完後,把
# 顯示文字覆寫成與傳入張數不符的字串。
class _SpyHandBarDesyncsCountLabel extends HandBar:
	func render(slot_kinds: Array[SlotKind], max_slots: int, availability: Availability) -> void:
		super.render(slot_kinds, max_slots, availability)
		_count_label.text = HandBar.count_text(0, max_slots)


# 四支間諜都是裸 HandBar 子類別的 .new(),不是從 HandBar.tscn 實例化 —— 因此
# 沒有 HandBar.tscn 提供的 CountLabel / UnavailableLabel 子節點,而
# hand_bar.gd 的 `@onready var _count_label: Label = $CountLabel` 等於「節點
# 進樹時,子節點必須已經存在」。這裡手動補上兩個同名子節點,而不是對已載入的
# HandBar.tscn 呼叫 set_script() 換腳本 —— 後者依
# .claude/rules/test-standards.md 的 C 類理由(「@onready 已賦值狀態換腳本後
# 是否保留」本專案從未驗證)不應被信任。
static func _attach_bare_labels(spy: HandBar) -> void:
	var count_label: Label = Label.new()
	count_label.name = "CountLabel"
	spy.add_child(count_label)
	var unavailable_label: Label = Label.new()
	unavailable_label.name = "UnavailableLabel"
	spy.add_child(unavailable_label)


# ─── 場景冒煙測試 —— 同 battle_screen_scene_test.gd 先例，防「.tscn 漏節點」 ──


func test_scene_instantiates_and_enters_tree_without_error() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	assert_object(packed).is_not_null()

	var instance: Node = auto_free(packed.instantiate())
	add_child(instance)

	assert_object(instance).is_not_null()


# ─── Test Evidence 指定測試 1: n/5 與 CardDeck.hand_size() 一致 ────────────


func test_hand_bar_shows_n_of_5_matching_deck_hand_size() -> void:
	# Arrange —— 固定種子,可重現（EPIC.md 陷阱五 / 本 story Implementation Notes #6）。
	# 本測試只驗證「顯示張數與 CardDeck.hand_size() 一致」這件事本身,刻意不經過
	# battle_screen.gd 的 Card.Category -> HandBar.SlotKind 映射函式 —— 那條映射的
	# 正確性由 tests/unit/ui/battle_screen_hand_bar_wiring_test.gd 另外驗證,兩者
	# 職責不同(本檔驗 HandBar 顯示邏輯,不依賴 battle_screen.gd 才能獨立執行)。
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20260917
	var cards: Array[Card] = [
		Card.new_temporary_stat_modifier("c1", 1, 0, 1),
		Card.new_temporary_stat_modifier("c2", 0, 1, 2),
		Card.new_permanent_affinity_write("c3", 1, 2, 1),
	]
	var deck: CardDeck = CardDeck.new(cards, rng)
	deck.deal_opening_hand()
	var hand: Array[Card] = deck.hand()
	var slot_kinds: Array[HandBar.SlotKind] = []
	for _card: Card in hand:
		slot_kinds.append(HandBar.SlotKind.TEMPORARY_MODIFIER)

	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)

	# Act
	hand_bar.render(slot_kinds, MAX_SLOTS, HandBar.Availability.NORMAL)

	# Assert
	assert_int(hand_bar.diagnostic_slot_count()).append_failure_message(
		"HandBar 顯示的張數 %d 與 CardDeck.hand_size() %d 不一致" % [
			hand_bar.diagnostic_slot_count(), deck.hand_size()
		]
	).is_equal(deck.hand_size())
	assert_str(hand_bar.diagnostic_count_label_text()).is_equal(
		HandBar.count_text(deck.hand_size(), MAX_SLOTS)
	)


# ─── Test Evidence 指定測試 2 / AC-U4 前半 ─────────────────────────────────


func test_empty_hand_shows_empty_slot_outline_and_0_of_5() -> void:
	# Arrange
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)

	# Act
	hand_bar.render([], MAX_SLOTS, HandBar.Availability.NORMAL)

	# Assert —— 5 個空槽輪廓,無一格回報「有牌」
	for i in range(MAX_SLOTS):
		assert_bool(hand_bar.diagnostic_slot_is_filled(i)).append_failure_message(
			"slot %d 應為空槽輪廓,但 diagnostic_slot_is_filled() 回報 true" % i
		).is_false()
	assert_str(hand_bar.diagnostic_count_label_text()).is_equal("0/5")


# ─── Test Evidence 指定測試 3: 類別圖示可不靠顏色區分（白箱）──────────────


func test_category_icon_distinguishable_without_color() -> void:
	var square: HandBar.IconShape = HandBar.icon_shape_for(HandBar.SlotKind.TEMPORARY_MODIFIER)
	var diamond: HandBar.IconShape = HandBar.icon_shape_for(HandBar.SlotKind.PERMANENT_WRITE)
	assert_int(square).append_failure_message(
		"甲類與丙類的 icon_shape_for() 回傳同一個形狀,無法只靠形狀(非顏色)區分"
	).is_not_equal(diamond)


# ─── S5 三通道 —— 正向測試 ──────────────────────────────────────────────────


func test_locked_availability_dims_bar_shows_lock_glyph_and_caption() -> void:
	# Arrange
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)

	# Act
	hand_bar.render([], MAX_SLOTS, HandBar.Availability.LOCKED)

	# Assert —— 三通道:降對比 + 鎖狀圖示 + 文案
	assert_float(hand_bar.diagnostic_dim_factor()).append_failure_message(
		"S5 應降對比(dim factor < 1.0),實際為 %f" % hand_bar.diagnostic_dim_factor()
	).is_less(1.0)
	assert_bool(hand_bar.diagnostic_lock_glyph_visible()).append_failure_message(
		"S5 應顯示鎖狀圖示"
	).is_true()
	assert_bool(hand_bar.diagnostic_caption_visible()).append_failure_message(
		"S5 應顯示不可用文案"
	).is_true()
	# S5「保持可見」——不得因為不可用就把張數也藏起來。
	assert_str(hand_bar.diagnostic_count_label_text()).is_equal("0/5")


func test_normal_availability_shows_no_lock_glyph_or_caption_and_full_alpha() -> void:
	# Arrange
	var hand_bar: HandBar = auto_free(load(SCENE_PATH).instantiate())
	add_child(hand_bar)

	# Act
	hand_bar.render([], MAX_SLOTS, HandBar.Availability.NORMAL)

	# Assert —— S7(空手牌,常態可用)必須與 S5 在這三個通道上都不同。
	assert_float(hand_bar.diagnostic_dim_factor()).is_equal(1.0)
	assert_bool(hand_bar.diagnostic_lock_glyph_visible()).is_false()
	assert_bool(hand_bar.diagnostic_caption_visible()).is_false()


# ─── 敏感度證明（.claude/rules/test-standards.md 2026-09-16 門檻）──────────


func test_sensitivity_proof_locked_rendering_would_catch_a_dropped_lock_visual() -> void:
	# Arrange —— 間諜:render() 跑完後,把 LOCKED 該有的兩個效果復原成 NORMAL 的樣子。
	var spy: _SpyHandBarDropsLockVisuals = auto_free(_SpyHandBarDropsLockVisuals.new())
	_attach_bare_labels(spy)
	add_child(spy)

	# Act
	spy.render([], MAX_SLOTS, HandBar.Availability.LOCKED)

	# Assert —— test_locked_availability_dims_bar_shows_lock_glyph_and_caption()
	# 斷言 dim factor < 1.0 且 caption 可見;在這支間諜身上,同一組斷言必須為假,
	# 否則代表該測試分不出「正確」與「被動過手腳的 render()」。
	var would_have_passed: bool = (
		spy.diagnostic_dim_factor() < 1.0 and spy.diagnostic_caption_visible()
	)
	assert_bool(would_have_passed).append_failure_message(
		"locked-state 斷言未能分辨出一個悄悄砍掉降對比與文案兩個通道的 render()"
	).is_false()


# 上一條的鏡像方向:證明 test_normal_availability_shows_no_lock_glyph_or_caption_and_full_alpha()
# 真的能分辨「NORMAL 該有的乾淨樣子」與「render() 忽略 availability、恆套用
# LOCKED 效果」——這是與上一條相反的錯誤,兩者互不蘊含,各自需要一條證明。
func test_sensitivity_proof_normal_rendering_would_catch_a_render_that_ignores_availability() -> void:
	# Arrange —— 間諜:render() 完全忽略傳入的 availability,恆套用 LOCKED。
	var spy: _SpyHandBarAlwaysAppliesLockedVisuals = auto_free(_SpyHandBarAlwaysAppliesLockedVisuals.new())
	_attach_bare_labels(spy)
	add_child(spy)

	# Act —— 明明傳入 NORMAL。
	spy.render([], MAX_SLOTS, HandBar.Availability.NORMAL)

	# Assert —— test_normal_availability_shows_no_lock_glyph_or_caption_and_full_alpha()
	# 斷言 dim factor == 1.0 且鎖圖示/文案皆不可見;在這支間諜身上,同一組斷言
	# 必須為假,否則代表該測試分不出「正確的 NORMAL」與「render() 恆套用 LOCKED」。
	var would_have_passed: bool = (
		spy.diagnostic_dim_factor() == 1.0
		and not spy.diagnostic_lock_glyph_visible()
		and not spy.diagnostic_caption_visible()
	)
	assert_bool(would_have_passed).append_failure_message(
		"normal-state 斷言未能分辨出一個忽略 availability、恆套用 LOCKED 效果的 render()"
	).is_false()


func test_sensitivity_proof_empty_slot_detection_would_catch_a_spy_that_always_reports_filled() -> void:
	# Arrange —— 間諜:diagnostic_slot_is_filled() 永遠回報 true。
	var spy: _SpyHandBarAlwaysReportsSlotsFilled = auto_free(_SpyHandBarAlwaysReportsSlotsFilled.new())
	_attach_bare_labels(spy)
	add_child(spy)

	# Act
	spy.render([], MAX_SLOTS, HandBar.Availability.NORMAL)

	# Assert —— test_empty_hand_shows_empty_slot_outline_and_0_of_5() 斷言每一格
	# diagnostic_slot_is_filled() 皆為 false;在這支間諜身上必須至少有一格為真,
	# 否則代表該測試分不出「真的是空的」與「回報恆真」。
	var would_have_passed: bool = true
	for i in range(MAX_SLOTS):
		if spy.diagnostic_slot_is_filled(i):
			would_have_passed = false
	assert_bool(would_have_passed).append_failure_message(
		"empty-slot 斷言未能分辨出一個恆報告「有牌」的 diagnostic_slot_is_filled()"
	).is_false()


func test_sensitivity_proof_count_label_would_catch_a_desynced_render() -> void:
	# Arrange —— 間諜:render() 跑完後,把 count label 覆寫成與傳入張數不符的字串。
	var spy: _SpyHandBarDesyncsCountLabel = auto_free(_SpyHandBarDesyncsCountLabel.new())
	_attach_bare_labels(spy)
	add_child(spy)
	var kinds: Array[HandBar.SlotKind] = [
		HandBar.SlotKind.TEMPORARY_MODIFIER,
		HandBar.SlotKind.PERMANENT_WRITE,
		HandBar.SlotKind.TEMPORARY_MODIFIER,
	]

	# Act
	spy.render(kinds, MAX_SLOTS, HandBar.Availability.NORMAL)

	# Assert —— test_hand_bar_shows_n_of_5_matching_deck_hand_size() 斷言 count
	# label 文字等於 HandBar.count_text(實際張數, max_slots);在這支間諜身上
	# 必須不相等,否則代表該測試分不出「同步」與「脫鉤」。
	var would_have_passed: bool = (
		spy.diagnostic_count_label_text() == HandBar.count_text(kinds.size(), MAX_SLOTS)
	)
	assert_bool(would_have_passed).append_failure_message(
		"count label 斷言未能分辨出一個與傳入張數脫鉤的 render()"
	).is_false()


# ─── Z1 幾何 —— 呼叫既有 HudLayout 函式合成,不重刻其公式(A 類,static 純函式)──


func test_slot_bar_rect_is_horizontally_centered_in_safe_rect_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var bar: Rect2 = HandBar.slot_bar_rect(window_size, MAX_SLOTS)
		var expected_center_x: float = safe.position.x + safe.size.x / 2.0
		var actual_center_x: float = bar.position.x + bar.size.x / 2.0
		assert_float(actual_center_x).append_failure_message(
			"%s: Z1 應水平置中於安全區(中心 x=%.2f),實際中心 x=%.2f" % [
				label, expected_center_x, actual_center_x
			]
		).is_equal_approx(expected_center_x, 0.01)


func test_slot_bar_rect_bottom_edge_is_half_fpx_above_controls_hint_bg_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var fpx: float = float(HudLayout.font_size(window_size))
		var hint_bg: Rect2 = HudLayout.controls_hint_bg_rect(window_size)
		var bar: Rect2 = HandBar.slot_bar_rect(window_size, MAX_SLOTS)
		var expected_bottom: float = hint_bg.position.y - 0.5 * fpx
		assert_float(bar.end.y).append_failure_message(
			"%s: Z1 下緣應在操作提示橫條上緣再往上 0.5 fpx(=%.2f),實際下緣=%.2f" % [
				label, expected_bottom, bar.end.y
			]
		).is_equal_approx(expected_bottom, 0.01)
		# 陷阱十一的字面驗證:下緣必須嚴格在 hint bar 上緣「之上」,不得疊住。
		assert_float(bar.end.y).is_less_equal(hint_bg.position.y)


func test_slot_bar_rect_width_equals_five_slots_plus_four_gaps_in_fpx_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var fpx: float = float(HudLayout.font_size(window_size))
		var bar: Rect2 = HandBar.slot_bar_rect(window_size, MAX_SLOTS)
		# 5*2 + 4*0.5 = 12 fpx —— 規格「合計 12 fpx 寬」逐字對應。
		var expected_width: float = 12.0 * fpx
		assert_float(bar.size.x).append_failure_message(
			"%s: Z1 寬度應為 12 fpx(=%.2f),實際=%.2f" % [label, expected_width, bar.size.x]
		).is_equal_approx(expected_width, 0.01)


func test_slot_bar_rect_height_equals_three_fpx_at_every_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var fpx: float = float(HudLayout.font_size(window_size))
		var bar: Rect2 = HandBar.slot_bar_rect(window_size, MAX_SLOTS)
		var expected_height: float = 3.0 * fpx
		assert_float(bar.size.y).append_failure_message(
			"%s: Z1 高度應為 3 fpx(=%.2f),實際=%.2f" % [label, expected_height, bar.size.y]
		).is_equal_approx(expected_height, 0.01)


func test_count_text_formats_current_over_max() -> void:
	assert_str(HandBar.count_text(3, 5)).is_equal("3/5")
	assert_str(HandBar.count_text(0, 5)).is_equal("0/5")
	assert_str(HandBar.count_text(5, 5)).is_equal("5/5")
