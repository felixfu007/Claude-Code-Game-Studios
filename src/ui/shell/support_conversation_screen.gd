## 支援對話畫面(系統 #8 UI,story-003 第一段:台詞播放核心)。
##
## 唯讀顯示:台詞順序來自 [SupportConversationScript],文字一律 [method Loc.localize],
## 本檔不含任何台詞字面值。不持有也不修改遊戲狀態。
## 注入窗:[member conversation_ids] 與兩個 *_path_override 須在 instantiate() 之後、
## add_child() 之前設定(比照 SceneRouter.switch_to 的 configure)。
## 第二段才做:跳過整段確認面板、回看、游標系統義務與卸載交接。
class_name SupportConversationScreen
extends Control

## 所有指定的對話段都播完後發出,只發一次。
signal all_conversations_finished

const LINES_PATH: String = "res://assets/data/narrative/support_conversation_lines.txt"
const CONVERSATIONS_PATH: String = "res://assets/data/narrative/support_conversations.txt"
const FONT_PATH: String = "res://assets/fonts/LXGWWenKaiTC-Regular.ttf"
const CONFIRM_ACTION: StringName = &"battle_confirm"
## 逐字速度(字/秒),固定,不自動前進。
const CHARS_PER_SECOND: float = 30.0
## 缺字標記前綴(UX AC-13)。刻意為 ASCII 開發診斷標記:缺字時要比正常台詞更醒目。
const MISSING_MARKER_PREFIX: String = "[MISSING] "
const MIN_FONT_SIZE: int = 24
const FONT_SIZE_DIVISOR: float = 30.0
const SPEAKER_NAME_KEY_FORMAT: String = "character.name.%d"

## 要依序播放的對話 id。
var conversation_ids: Array[String] = []
var lines_path_override: String = ""
var conversations_path_override: String = ""

var _script_data: Dictionary = {}
var _convo_index: int = 0
var _line_index: int = 0
var _current_lines: Array = []
var _shown_chars: float = 0.0
var _finished: bool = false
var _current_text: String = ""
var _font: Font = null

var _backdrop: ColorRect
var _name_label: Label
var _text_panel: Panel
var _text_label: Label


## 暫行規則,管理者尚未核准,待目視 —— 見 docs/reviews/dialogue-font-shortlist-2026-10-28.md。
## 不套 HUD 的 11 x N(那是點陣字規則,對向量字型不適用)。
## 算式:max(24, round(高 / 30)),再往上取偶數。
static func dialogue_font_size(window_size: Vector2i) -> int:
	var size_px: int = maxi(MIN_FONT_SIZE, roundi(float(window_size.y) / FONT_SIZE_DIVISOR))
	if size_px % 2 != 0:
		size_px += 1
	return size_px


## 把 key 轉成顯示文字;缺字時回傳明確標記並 push_error(經 Loc.localize)。
static func resolve_text(key: String) -> String:
	var raw: String = String(TranslationServer.translate(StringName(key)))
	if Loc.is_missing(StringName(key), raw):
		Loc.localize(StringName(key))
		return MISSING_MARKER_PREFIX + key
	return Loc.localize(StringName(key))


func _ready() -> void:
	_build_nodes()
	_load_data()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	if _begin_conversation(0):
		return
	_finish.call_deferred()


func _process(delta: float) -> void:
	advance_typewriter(delta)


## 推進逐字顯示(公開以便測試不依賴真實幀時間)。
func advance_typewriter(delta: float) -> void:
	if _finished or _current_text.is_empty() or diagnostic_line_fully_shown():
		return
	_shown_chars += delta * CHARS_PER_SECOND
	if int(_shown_chars) >= _current_text.length():
		_text_label.visible_characters = -1
	else:
		_text_label.visible_characters = int(_shown_chars)


func _input(event: InputEvent) -> void:
	if handle_input_event(event):
		get_viewport().set_input_as_handled()


## 處理一個輸入事件;若它是「確認」則推進並回傳 true。
func handle_input_event(event: InputEvent) -> bool:
	if _is_echo(event):
		return false
	var is_confirm: bool = false
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		is_confirm = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	elif event.is_action(CONFIRM_ACTION) and event.is_pressed():
		is_confirm = true
	if not is_confirm:
		return false
	request_advance()
	return true


## ADR-0005 義務:引擎 is_action_pressed 不過濾 echo,必須自行過濾。
func _is_echo(event: InputEvent) -> bool:
	return event is InputEventKey and (event as InputEventKey).echo


## 確認一次:逐字中 -> 顯示整句;已完整 -> 下一句 / 下一段 / 結束。
func request_advance() -> void:
	if _finished:
		return
	if not diagnostic_line_fully_shown():
		_shown_chars = float(_current_text.length())
		_text_label.visible_characters = -1
		return
	if _line_index + 1 < _current_lines.size():
		_line_index += 1
		_show_line()
		return
	if not _begin_conversation(_convo_index + 1):
		_finish()


func diagnostic_current_conversation_id() -> String:
	if _convo_index < conversation_ids.size():
		return conversation_ids[_convo_index]
	return ""


func diagnostic_current_line_index() -> int:
	return _line_index


func diagnostic_visible_text() -> String:
	if _text_label == null:
		return ""
	if _text_label.visible_characters < 0:
		return _current_text
	return _current_text.substr(0, _text_label.visible_characters)


func diagnostic_speaker_text() -> String:
	return _name_label.text if _name_label != null else ""


func diagnostic_line_fully_shown() -> bool:
	return _text_label != null and (
		_text_label.visible_characters < 0 or _text_label.visible_characters >= _current_text.length()
	)


func diagnostic_is_finished() -> bool:
	return _finished


func _finish() -> void:
	if _finished:
		return
	_finished = true
	all_conversations_finished.emit()


## 開始第 [param index] 段(跳過找不到的 id)。無可播的段落回傳 false。
func _begin_conversation(index: int) -> bool:
	var i: int = index
	while i < conversation_ids.size():
		var lines: Array = SupportConversationScript.lines_for(_script_data, conversation_ids[i])
		if not lines.is_empty():
			_convo_index = i
			_current_lines = lines
			_line_index = 0
			_show_line()
			return true
		i += 1
	return false


func _show_line() -> void:
	var entry: Dictionary = _current_lines[_line_index]
	_current_text = resolve_text(String(entry[SupportConversationScript.KEY_TEXT_KEY]))
	_name_label.text = resolve_text(
		SPEAKER_NAME_KEY_FORMAT % int(entry[SupportConversationScript.KEY_SPEAKER])
	)
	_text_label.text = _current_text
	_shown_chars = 0.0
	_text_label.visible_characters = 0


func _load_data() -> void:
	var conv_path: String = CONVERSATIONS_PATH
	if not conversations_path_override.is_empty():
		conv_path = conversations_path_override
	var lines_path: String = LINES_PATH
	if not lines_path_override.is_empty():
		lines_path = lines_path_override
	var records: Variant = SupportConversationRecord.records_from_text(_read_text(conv_path))
	var ids: Array[String] = []
	if records != null:
		for record: SupportConversationRecord in records:
			ids.append(record.conversation_id)
	var parsed: Variant = SupportConversationScript.script_from_text(_read_text(lines_path), ids)
	if parsed != null:
		_script_data = parsed


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SupportConversationScreen: cannot open '%s'" % path)
		return ""
	return file.get_as_text()


func _build_nodes() -> void:
	_font = load(FONT_PATH) as Font
	_backdrop = ColorRect.new()
	_backdrop.color = Color.BLACK
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_text_panel = Panel.new()
	_text_panel.anchor_left = 0.05
	_text_panel.anchor_right = 0.95
	_text_panel.anchor_top = 0.72
	_text_panel.anchor_bottom = 0.96
	_text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text_panel)
	_text_label = Label.new()
	_text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_panel.add_child(_text_label)
	_name_label = Label.new()
	_name_label.anchor_left = 0.05
	_name_label.anchor_right = 0.95
	_name_label.anchor_top = 0.64
	_name_label.anchor_bottom = 0.72
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)


func _apply_layout() -> void:
	var win: Vector2 = get_viewport().get_visible_rect().size
	var font_size: int = dialogue_font_size(Vector2i(int(win.x), int(win.y)))
	for label: Label in [_text_label, _name_label]:
		if _font != null:
			label.add_theme_font_override(&"font", _font)
		label.add_theme_font_size_override(&"font_size", font_size)
