## Applies [HudLayout]'s window-size-driven HUD label positioning and Cubic 11
## font sizing to `BattleScreen.tscn`'s `UILayer` every time the owning
## window's size changes — mirrors [code]world_viewport_scaler.gd[/code]'s
## "not just once at startup" discipline (story-002's own citation of
## story-001 Implementation Notes #1: "視窗尺寸會變...是要持續維持的關係,不是
## 啟動時算一次")。Attached directly to [code]BattleScreen.tscn[/code]'s
## [code]UILayer[/code] node.
##
## Story 002 (adaptive-font-scale) 範圍擴充後的兩件事都在這裡做:
##
## 1. HUD 字級規則(A 案:11 * [method WorldLayout.compute_scale])透過
##    [HudLayout] 套用到 5 個使用 Cubic 11 的 [Label]:
##    [code]StatusLabel[/code] / [code]InfoLabel[/code] /
##    [code]ControlsHintLabel[/code] / [code]LoadErrorLabel[/code] /
##    [code]ResultLabel[/code]。
## 2. Story 001 造成的 6 個節點座標退化,依 [HudLayout] 算出的 rect 重新定位。
##
## [b]This script never touches any node's [code]anchors_preset[/code][/b] —
## [code]StatusLabel[/code] / [code]InfoLabel[/code] / [code]ControlsHintBg[/code]
## / [code]LoadErrorLabel[/code] keep [Control]'s default anchor (0,0,0,0) and
## [code]ResultLabel[/code] keeps its existing 0.5-centered anchor, exactly as
## authored in [code]BattleScreen.tscn[/code]; only the four
## [code]offset_left/top/right/bottom[/code] values are overwritten, via
## [method _apply_rect] below, which [HudLayout]'s doc comment guarantees maps
## correctly onto either anchor shape.
##
## [b]The offset_left/top/right/bottom values still baked into
## [code]BattleScreen.tscn[/code][/b] for [code]StatusLabel[/code] /
## [code]InfoLabel[/code] / [code]ControlsHintBg[/code] /
## [code]LoadErrorLabel[/code] / [code]ResultLabel[/code] are pre-Story-002
## legacy numbers (the 480x270-canvas-era layout Story 001's own report
## documented as degraded) — [b]unconditionally overwritten[/b] the moment
## this script's [method _ready] runs, exactly like [code]StatusLabel[/code]'s
## own [code]text = "Round 1 | PLAYER phase"[/code] placeholder is
## unconditionally overwritten by [method BattleScreen._update_status_label]
## and [code]WorldViewportContainer[/code]'s [code]anchors_preset = 15[/code]
## is unconditionally overwritten by [code]world_viewport_scaler.gd[/code]'s
## own [method Control.set_anchors_preset] call. This file deliberately
## follows that SAME established project precedent (document the override
## here, in the script that performs it, rather than editing the stale
## literal in the [code].tscn[/code] to `0` or annotating it there) instead of
## introducing a third, different convention: anyone opening
## [code]BattleScreen.tscn[/code] in the editor sees numbers that describe a
## LAYOUT, not necessarily the CURRENT layout, and that has always been true
## of this scene even before this file existed.
##
## [code]ControlsHintLabel[/code] itself needs no separate rect calculation —
## it keeps its [code]anchors_preset = 15[/code] in
## [code]BattleScreen.tscn[/code] (fills its parent [code]ControlsHintBg[/code]'s
## entire rect, with a small fixed inset that stays proportionally negligible
## at every resolution). Once [code]ControlsHintBg[/code] itself is positioned
## correctly, [code]ControlsHintLabel[/code] follows automatically; this
## script only applies its font override directly.
class_name HudLayoutScaler
extends CanvasLayer

const HUD_FONT: FontFile = preload("res://assets/fonts/Cubic_11.ttf")

@onready var _status_label: Label = $StatusLabel
@onready var _info_label: Label = $InfoLabel
@onready var _result_label: Label = $ResultLabel
@onready var _controls_hint_bg: ColorRect = $ControlsHintBg
@onready var _controls_hint_label: Label = $ControlsHintBg/ControlsHintLabel
@onready var _load_error_label: Label = $LoadErrorLabel


func _ready() -> void:
	_apply_layout()
	get_window().size_changed.connect(_apply_layout)


func _apply_layout() -> void:
	var window_size: Vector2i = get_window().size
	var font_px: int = HudLayout.font_size(window_size)

	_apply_rect(_status_label, HudLayout.status_label_rect(window_size))
	_apply_rect(_info_label, HudLayout.info_label_rect(window_size))
	_apply_rect(_controls_hint_bg, HudLayout.controls_hint_bg_rect(window_size))
	_apply_rect(_load_error_label, HudLayout.load_error_label_rect(window_size))
	_apply_rect(_result_label, HudLayout.result_label_offset_rect(window_size))

	for label: Label in [_status_label, _info_label, _controls_hint_label, _load_error_label, _result_label]:
		label.add_theme_font_override(&"font", HUD_FONT)
		label.add_theme_font_size_override(&"font_size", font_px)


# Assigns [param rect]'s four components directly to [param control]'s
# offset_left/top/right/bottom — see HudLayout's own doc comment for why this
# is correct regardless of whether [param control]'s anchors are (0,0,0,0)
# (StatusLabel/InfoLabel/ControlsHintBg/LoadErrorLabel) or (0.5,0.5,0.5,0.5)
# (ResultLabel): in both cases HudLayout already returns the rect in the
# space that maps directly onto these four offset properties.
static func _apply_rect(control: Control, rect: Rect2) -> void:
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y
