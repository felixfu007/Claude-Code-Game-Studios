extends GdUnitTestSuite

# Story 030:手牌縮圖四種卡類別形狀。檔案存取:無(遮罩為測試內獨立抄寫的常數)。
# AC1 類別對應、AC2 遮罩逐格相等(headless 取不到像素 → 斷言 HandKindIcon.filled_rects()
# 這份「實際被 _draw 使用的繪製資料」,並非讀回螢幕像素;已揭露)、AC5 常駐敏感度證明。
# 遮罩抄自 docs/reviews/hand-thumbnail-shapes-art-spec-2026-11-20.md 第 1 節,刻意不引用 HandBar 的常數。

const _SCENE_PATH: String = "res://src/ui/battle/HandBar.tscn"
const _MAX_SLOTS: int = 5

const _SPEC_SQUARE: PackedStringArray = [
	"#######", "#######", "#######", "#######", "#######", "#######", "#######",
]
const _SPEC_DIAMOND: PackedStringArray = [
	"...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#...",
]
const _SPEC_TRIANGLE: PackedStringArray = [
	"...#...", "..###..", "..###..", ".#####.", ".#####.", "#######", "#######",
]
const _SPEC_CROSS: PackedStringArray = [
	"..###..", "..###..", "#######", "#######", "#######", "..###..", "..###..",
]


func _spec_for(kind: HandBar.SlotKind) -> PackedStringArray:
	match kind:
		HandBar.SlotKind.PERMANENT_WRITE:
			return _SPEC_DIAMOND
		HandBar.SlotKind.DAMAGE:
			return _SPEC_TRIANGLE
		HandBar.SlotKind.HEAL:
			return _SPEC_CROSS
		_:
			return _SPEC_SQUARE


func _spec_rects(mask: PackedStringArray, cell: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for y: int in range(mask.size()):
		for x: int in range(mask[y].length()):
			if mask[y][x] == "#":
				out.append(Rect2i(x * cell, y * cell, cell, cell))
	return out


# 「類別 → SlotKind」對應是否符合工單 AC1(傳入對應函式以便敏感度證明換成突變版)。
func _mapping_violations(mapper: Callable) -> Array[String]:
	var expected: Dictionary = {
		Card.Category.TEMPORARY_STAT_MODIFIER: HandBar.SlotKind.TEMPORARY_MODIFIER,
		Card.Category.PERMANENT_AFFINITY_WRITE: HandBar.SlotKind.PERMANENT_WRITE,
		Card.Category.DIRECT_DAMAGE: HandBar.SlotKind.DAMAGE,
		Card.Category.COMBO_DAMAGE: HandBar.SlotKind.DAMAGE,
		Card.Category.HEAL: HandBar.SlotKind.HEAL,
	}
	var bad: Array[String] = []
	for category: int in expected:
		var got: int = mapper.call(category)
		if got != int(expected[category]):
			bad.append("category %d -> %d (expected %d)" % [category, got, int(expected[category])])
	return bad


# 以真實 HandBar 渲染四種卡,回傳「每格圖示的繪製矩形是否等於規格遮罩 × cell」的違規清單。
# swap_triangle_cross = true 時把期望遮罩的三角與十字對調(敏感度證明用的突變期望)。
func _shape_violations(z2_expanded: bool, swap_triangle_cross: bool) -> Array[String]:
	var bar: HandBar = auto_free(load(_SCENE_PATH).instantiate())
	add_child(bar)
	var kinds: Array[HandBar.SlotKind] = [
		HandBar.SlotKind.TEMPORARY_MODIFIER, HandBar.SlotKind.PERMANENT_WRITE,
		HandBar.SlotKind.DAMAGE, HandBar.SlotKind.HEAL,
	]
	bar.render(kinds, _MAX_SLOTS, HandBar.Availability.NORMAL)
	if z2_expanded:
		bar._set_expand_progress(1.0)
	var bad: Array[String] = []
	for i: int in range(kinds.size()):
		var icon: HandKindIcon = bar._slot_nodes[i].get_child(0) as HandKindIcon
		if icon == null:
			bad.append("slot %d: child 0 is not HandKindIcon" % i)
			continue
		var spec: PackedStringArray = _spec_for(kinds[i])
		if swap_triangle_cross:
			if kinds[i] == HandBar.SlotKind.DAMAGE:
				spec = _SPEC_CROSS
			elif kinds[i] == HandBar.SlotKind.HEAL:
				spec = _SPEC_TRIANGLE
		var want: Array[Rect2i] = _spec_rects(spec, icon.cell_px)
		if icon.filled_rects() != want:
			bad.append("slot %d (kind %d): drawn rects != spec mask" % [i, kinds[i]])
	return bad


# ---- AC1 -------------------------------------------------------------------

func test_category_to_slot_kind_mapping_covers_all_five_categories() -> void:
	var bad: Array[String] = _mapping_violations(
		func(c: int) -> int: return BattleScreen.hand_bar_slot_kind_for(c as Card.Category)
	)
	assert_array(bad).append_failure_message("對應表違規").is_empty()


func test_damage_and_combo_share_damage_kind() -> void:
	assert_int(BattleScreen.hand_bar_slot_kind_for(Card.Category.DIRECT_DAMAGE)).is_equal(HandBar.SlotKind.DAMAGE)
	assert_int(BattleScreen.hand_bar_slot_kind_for(Card.Category.COMBO_DAMAGE)).is_equal(HandBar.SlotKind.DAMAGE)


func test_new_slot_kinds_are_appended_without_renumbering() -> void:
	assert_int(HandBar.SlotKind.TEMPORARY_MODIFIER).is_equal(0)
	assert_int(HandBar.SlotKind.PERMANENT_WRITE).is_equal(1)
	assert_int(HandBar.SlotKind.DAMAGE).is_equal(2)
	assert_int(HandBar.SlotKind.HEAL).is_equal(3)


# ---- AC2 -------------------------------------------------------------------

func test_z1_drawn_masks_equal_art_spec_cell_by_cell() -> void:
	assert_array(_shape_violations(false, false)).is_empty()


func test_four_shapes_have_pairwise_distinct_masks() -> void:
	var masks: Array[PackedStringArray] = [_SPEC_SQUARE, _SPEC_DIAMOND, _SPEC_TRIANGLE, _SPEC_CROSS]
	for a: int in range(masks.size()):
		for b: int in range(a + 1, masks.size()):
			assert_bool(masks[a] == masks[b]).is_false()


func test_icon_cell_px_is_integer_multiple_of_native_pixel() -> void:
	var bar: HandBar = auto_free(load(_SCENE_PATH).instantiate())
	add_child(bar)
	var kinds: Array[HandBar.SlotKind] = [HandBar.SlotKind.HEAL]
	bar.render(kinds, _MAX_SLOTS, HandBar.Availability.NORMAL)
	var icon: HandKindIcon = bar._slot_nodes[0].get_child(0) as HandKindIcon
	assert_int(icon.cell_px).is_greater_equal(1)
	assert_float(icon.rotation_degrees).is_equal(0.0)
	assert_vector(icon.size).is_equal(Vector2(7 * icon.cell_px, 7 * icon.cell_px))


func test_z2_scale_is_integer_multiple_of_z1() -> void:
	var bar: HandBar = auto_free(load(_SCENE_PATH).instantiate())
	add_child(bar)
	var kinds: Array[HandBar.SlotKind] = [HandBar.SlotKind.DAMAGE]
	bar.render(kinds, _MAX_SLOTS, HandBar.Availability.NORMAL)
	var z1: int = (bar._slot_nodes[0].get_child(0) as HandKindIcon).cell_px
	bar._set_expand_progress(1.0)
	var z2: int = (bar._slot_nodes[0].get_child(0) as HandKindIcon).cell_px
	assert_int(HandBar.ICON_Z2_SCALE).is_greater_equal(2)
	assert_int(z2).is_equal(z1 * HandBar.ICON_Z2_SCALE)


func test_z2_drawn_masks_equal_same_spec_scaled() -> void:
	assert_array(_shape_violations(true, false)).is_empty()


# ---- AC5 常駐敏感度證明 ----------------------------------------------------

func test_sensitivity_proof_damage_mapped_to_temporary_modifier_is_caught() -> void:
	var mutant: Callable = func(c: int) -> int:
		if c == Card.Category.DIRECT_DAMAGE:
			return HandBar.SlotKind.TEMPORARY_MODIFIER
		return BattleScreen.hand_bar_slot_kind_for(c as Card.Category)
	assert_array(_mapping_violations(mutant)).is_not_empty()


func test_sensitivity_proof_swapped_triangle_and_cross_masks_are_caught() -> void:
	assert_array(_shape_violations(false, true)).is_not_empty()
