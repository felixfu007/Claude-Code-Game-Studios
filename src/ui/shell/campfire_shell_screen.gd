class_name CampfireShellScreen
extends Control
## 營火畫面的【最小殼層】(campfire story-006 接線用;真畫面由 story-007 取代)。玩家離開營火時發出 [signal left_campfire];去哪裡由 [SceneRouter] 決定。
##
## 畫面只有一行暫時標題與一顆按鈕(文字走 [Loc],key 見常數;字級 = [method HudLayout.font_size],
## 倍率唯一出自 [method WorldLayout.compute_scale],不自行計算)。


const TEXT_TITLE: StringName = &"shell.campfire_wip.title"
const TEXT_CONTINUE: StringName = &"shell.campfire_wip.continue"

## 玩家離開營火。
signal left_campfire

@onready var _title_label: Label = %TitleLabel
@onready var _button: Button = %LeaveButton


func _ready() -> void:
	_title_label.text = Loc.localize(TEXT_TITLE)
	_button.text = Loc.localize(TEXT_CONTINUE)
	for control: Control in [_title_label, _button]:
		control.add_theme_font_override(&"font", HudLayoutScaler.HUD_FONT)
	_apply_font_size()
	get_viewport().size_changed.connect(_apply_font_size)
	_button.pressed.connect(_on_leave_pressed)
	_button.grab_focus()


func _apply_font_size() -> void:
	if not is_inside_tree():
		return
	var window_size: Vector2i = Vector2i(get_viewport().get_visible_rect().size)
	var px: int = HudLayout.font_size(window_size)
	_title_label.add_theme_font_size_override(&"font_size", px)
	_button.add_theme_font_size_override(&"font_size", px)


func _on_leave_pressed() -> void:
	left_campfire.emit()
