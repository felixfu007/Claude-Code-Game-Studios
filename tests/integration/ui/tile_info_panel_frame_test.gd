# Story 048 AC1 -- 資訊卡不透明底與框。
#
# 手法:載入真實 BattleScreen.tscn,進樹後讀真實節點(底色 ColorRect、內框/外隔線 Panel 的
# StyleBoxFlat、標籤內距),而不只驗常數。色值斷言對照色盤既有列(色盤檔 design/art/color-palette.csv):
# ui_panel_bg_01 #1A1A1F、cloth_neutral_highlight_01 #B0A897、nature_void_shadow_01 #0E0F14。
# 本檔只涵蓋 AC1;AC2(位置)依管理者裁決本次不做。
# 敏感度:已手動注入(見交付報告),本檔不含常駐間諜子類別。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


func _make_screen() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _u(screen: BattleScreen) -> int:
	return maxi(1, HudLayout.small_font_size(screen.get_window().size) / HudLayout.GLYPH_PX)


func test_ac1_constants_match_palette_rows() -> void:
	assert_str(BattleScreen.TILE_INFO_PANEL_BG_COLOR.to_html(false).to_upper()).is_equal("1A1A1F")
	assert_float(BattleScreen.TILE_INFO_PANEL_BG_COLOR.a).is_equal(1.0)
	assert_str(BattleScreen.TILE_INFO_PANEL_FRAME_COLOR.to_html(false).to_upper()).is_equal("B0A897")
	assert_str(BattleScreen.TILE_INFO_PANEL_OUTER_LINE_COLOR.to_html(false).to_upper()).is_equal("0E0F14")
	assert_float(BattleScreen.TILE_INFO_PANEL_OUTER_LINE_COLOR.a).is_equal_approx(0.8, 0.001)


func test_ac1_real_panel_background_is_opaque_palette_color() -> void:
	var screen: BattleScreen = _make_screen()
	var bg: ColorRect = screen._tile_info_panel_bg
	assert_str(bg.color.to_html(true).to_upper()).is_equal("1A1A1FFF")
	assert_float(bg.color.a).is_equal(1.0)


func test_ac1_real_panel_has_inner_frame_and_outer_line() -> void:
	var screen: BattleScreen = _make_screen()
	var u: int = _u(screen)
	assert_object(screen._tile_info_frame_inner).is_not_null()
	assert_object(screen._tile_info_frame_outer).is_not_null()
	var inner: StyleBoxFlat = screen._tile_info_frame_inner.get_theme_stylebox(&"panel") as StyleBoxFlat
	var outer: StyleBoxFlat = screen._tile_info_frame_outer.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_bool(inner.border_color.is_equal_approx(BattleScreen.TILE_INFO_PANEL_FRAME_COLOR)).is_true()
	assert_int(inner.border_width_left).is_equal(u)
	assert_int(inner.border_width_bottom).is_equal(u)
	assert_bool(outer.border_color.is_equal_approx(BattleScreen.TILE_INFO_PANEL_OUTER_LINE_COLOR)).is_true()
	assert_int(outer.border_width_top).is_equal(u)
	# 外隔線在面板外緣外側 1u。
	assert_float(screen._tile_info_frame_outer.offset_left).is_equal(-float(u))
	assert_float(screen._tile_info_frame_outer.offset_right).is_equal(float(u))
	assert_float(screen._tile_info_frame_inner.offset_left).is_equal(0.0)


func test_ac1_real_label_padding_is_proportional_not_fixed_4px() -> void:
	var screen: BattleScreen = _make_screen()
	var u: int = _u(screen)
	var fpx: float = float(HudLayout.small_font_size(screen.get_window().size))
	var label: Label = screen._tile_info_panel_label
	assert_float(label.offset_left).is_equal_approx(float(u) + fpx * 0.5, 0.001)
	assert_float(label.offset_top).is_equal_approx(float(u) + fpx * 0.4, 0.001)
	assert_float(label.offset_right).is_equal_approx(-(float(u) + fpx * 0.5), 0.001)
	assert_float(label.offset_bottom).is_equal_approx(-(float(u) + fpx * 0.4), 0.001)


func test_ac1_panel_outer_size_follows_spec_formula() -> void:
	var screen: BattleScreen = _make_screen()
	var u: int = _u(screen)
	var fpx: float = float(HudLayout.small_font_size(screen.get_window().size))
	var bg: ColorRect = screen._tile_info_panel_bg
	var want_w: float = fpx * 8.0 + 2.0 * (fpx * 0.5 + float(u))
	var want_h: float = fpx * (1.2 * 8.0 + 0.8) + 2.0 * float(u)
	assert_float(bg.offset_right - bg.offset_left).is_equal_approx(want_w, 0.001)
	assert_float(bg.offset_bottom - bg.offset_top).is_equal_approx(want_h, 0.001)
