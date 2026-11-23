class_name DeckEditShellScreen
extends Control
## 牌組編輯畫面的【最小殼層】(campfire story-006 接線用;真畫面由 story-008 取代)。唯一出口是 [signal confirmed];結構上沒有回營火的訊號或按鈕(管理者 2026-11-20 第 8 題)。
##
## 畫面只有一行暫時標題與一顆按鈕(文字走 [Loc],key 見常數;字級 = [method HudLayout.font_size],
## 倍率唯一出自 [method WorldLayout.compute_scale],不自行計算)。


const TEXT_TITLE: StringName = &"shell.deck_edit_wip.title"
const TEXT_CONTINUE: StringName = &"shell.deck_edit_wip.continue"

## 玩家確認牌組。
signal confirmed

@onready var _title_label: Label = %TitleLabel
@onready var _button: Button = %ConfirmButton


func _ready() -> void:
	_title_label.text = Loc.localize(TEXT_TITLE)
	_button.text = Loc.localize(TEXT_CONTINUE)
	for control: Control in [_title_label, _button]:
		control.add_theme_font_override(&"font", HudLayoutScaler.HUD_FONT)
	_apply_font_size()
	get_viewport().size_changed.connect(_apply_font_size)
	_button.pressed.connect(_on_confirm_pressed)
	_button.grab_focus()


func _apply_font_size() -> void:
	if not is_inside_tree():
		return
	var window_size: Vector2i = Vector2i(get_viewport().get_visible_rect().size)
	var px: int = HudLayout.font_size(window_size)
	_title_label.add_theme_font_size_override(&"font_size", px)
	_button.add_theme_font_size_override(&"font_size", px)


func _on_confirm_pressed() -> void:
	confirmed.emit()
