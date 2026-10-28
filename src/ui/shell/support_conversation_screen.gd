## 支援對話畫面(系統 #11 UI,story-003:台詞播放、跳過整段、回看、游標義務)。
##
## 唯讀顯示:台詞順序來自 [SupportConversationScript],文字一律 [method Loc.localize],
## 本檔不含任何台詞字面值。不持有也不修改遊戲狀態。
## 注入窗:[member conversation_ids] 與兩個 *_path_override 須在 instantiate() 之後、
## add_child() 之前設定(比照 SceneRouter.switch_to 的 configure)。
## 規格:design/ux/support-conversation-screen.md 第 3、4、7、9 節。
##
## 游標表面標籤:[constant CursorTypes.SurfaceType.DIALOGUE_CHOICE]。這**不是**暫行借用 ——
## 該成員本來就是為支援對話預留的(ADR-0005 列舉宣告處的註解逐字為「支援對話選項」,
## 當場查:grep -n "DIALOGUE_CHOICE" docs/architecture/adr-0005-cursor-device-authority-input-architecture.md),
## 故 OBL-013「使用共用列舉成員」已滿足,不需要新增成員。
## (2026-10-28 協調者覆核更正:實作者原寫「OBL-013 未完成、暫行重用」,判定對、理由錯。)
class_name SupportConversationScreen
extends Control

## 所有指定的對話段都播完後發出,只發一次(正常讀完與跳過確認後走同一條路徑)。
signal all_conversations_finished

const LINES_PATH: String = "res://assets/data/narrative/support_conversation_lines.txt"
const CONVERSATIONS_PATH: String = "res://assets/data/narrative/support_conversations.txt"
const FONT_PATH: String = "res://assets/fonts/LXGWWenKaiTC-Regular.ttf"
const CONFIRM_ACTION: StringName = &"battle_confirm"
const CANCEL_ACTION: StringName = &"battle_cancel"
const MENU_ACTION: StringName = &"battle_menu"
const PREV_ACTION: StringName = &"battle_prev_target"
const NEXT_ACTION: StringName = &"battle_next_target"
## 逐字速度(字/秒),固定,不自動前進。
const CHARS_PER_SECOND: float = 30.0
## 缺字標記前綴(UX AC-13)。刻意為 ASCII 開發診斷標記:缺字時要比正常台詞更醒目。
const MISSING_MARKER_PREFIX: String = "[MISSING] "
const MIN_FONT_SIZE: int = 24
const FONT_SIZE_DIVISOR: float = 30.0
const SPEAKER_NAME_KEY_FORMAT: String = "character.name.%d"
const TEXT_PREV: String = "support.ui.prev"
const TEXT_SKIP: String = "support.ui.skip"
const TEXT_SKIP_BODY: String = "support.ui.skip_confirm_body"
const TEXT_SKIP_YES: String = "support.ui.skip_confirm_yes"
const TEXT_SKIP_NO: String = "support.ui.skip_confirm_no"

## 游標目標 id(同一個表面實例內切換目標集合,OBL-018)。
const TARGET_ADVANCE: int = 0
const TARGET_PREV: int = 1
const TARGET_SKIP: int = 2
const TARGET_PANEL_CONFIRM: int = 3
const TARGET_PANEL_CANCEL: int = 4
const NOT_REVIEWING: int = -1

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
var _review_index: int = NOT_REVIEWING
var _skip_panel_open: bool = false
var _surface_registered: bool = false

var _backdrop: ColorRect
var _name_label: Label
var _text_panel: Panel
var _text_label: Label
var _prev_button: Button
var _skip_button: Button
var _skip_panel: Panel
var _skip_body: Label
var _skip_yes_button: Button
var _skip_no_button: Button


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
	_register_cursor_surface()
	tree_exited.connect(_on_tree_exited_cursor_handoff)
	if _begin_conversation(0):
		return
	_finish.call_deferred()


func _process(delta: float) -> void:
	advance_typewriter(delta)


## 推進逐字顯示(公開以便測試不依賴真實幀時間)。回看與確認面板開啟時暫停。
func advance_typewriter(delta: float) -> void:
	if _finished or _review_index != NOT_REVIEWING or _skip_panel_open:
		return
	if _current_text.is_empty() or diagnostic_line_fully_shown():
		return
	_shown_chars += delta * CHARS_PER_SECOND
	_apply_visible()


func _input(event: InputEvent) -> void:
	if handle_input_event(event):
		get_viewport().set_input_as_handled()


## 處理一個輸入事件;若它被本畫面消耗則回傳 true。
func handle_input_event(event: InputEvent) -> bool:
	if _is_echo(event):
		return false
	if _skip_panel_open:
		return _handle_panel_event(event)
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT \
				and _text_panel.get_global_rect().has_point(mouse.position):
			request_advance()
			return true
		return false
	# 刻意用 is_action()+is_pressed(),不要改回 is_action_pressed():後者預設
	# allow_echo=false 會自己擋 echo,讓上面的 _is_echo 自行過濾不再承重;ADR-0005 要求自行過濾。
	if _pressed(event, CONFIRM_ACTION):
		request_advance()
		return true
	if _pressed(event, MENU_ACTION):
		open_skip_panel()
		return true
	if _pressed(event, PREV_ACTION):
		review_back()
		return true
	if _pressed(event, NEXT_ACTION):
		review_forward()
		return true
	return false


func _handle_panel_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		# 面板上的按鈕自己處理點擊;不得穿透成「推進」
		return false
	if _pressed(event, CANCEL_ACTION):
		close_skip_panel()
		return true
	if _pressed(event, CONFIRM_ACTION):
		_activate_panel_focus()
		return true
	return false


func _pressed(event: InputEvent, action: StringName) -> bool:
	return event.is_action(action) and event.is_pressed()


## ADR-0005 義務:引擎 is_action_pressed 不過濾 echo,必須自行過濾。
func _is_echo(event: InputEvent) -> bool:
	return event is InputEventKey and (event as InputEventKey).echo


## 確認一次:回看中 -> 往較新一句;逐字中 -> 顯示整句;已完整 -> 下一句 / 下一段 / 結束。
func request_advance() -> void:
	if _finished or _skip_panel_open:
		return
	if _review_index != NOT_REVIEWING:
		review_forward()
		return
	if not diagnostic_line_fully_shown():
		_shown_chars = float(_current_text.length())
		_apply_visible()
		return
	if _line_index + 1 < _current_lines.size():
		_line_index += 1
		_show_line()
		return
	if not _begin_conversation(_convo_index + 1):
		_finish()


# ---- 回看(唯讀,UX 第 7 節 / AC-7)---------------------------------------------

## 回看較早一句。只讀:不動 [member _line_index]、[member _shown_chars]、完成進度。
func review_back() -> void:
	if _finished or _skip_panel_open or _current_lines.is_empty():
		return
	var target: int = _line_index - 1 if _review_index == NOT_REVIEWING else _review_index - 1
	if target < 0:
		return
	_review_index = target
	_render_review()


## 回看往較新一句;到達目前進度(_line_index)即離開回看,因此結構上不可能超過已讀進度。
func review_forward() -> void:
	if _review_index == NOT_REVIEWING:
		return
	var target: int = _review_index + 1
	if target >= _line_index:
		_review_index = NOT_REVIEWING
		_render_current()
		return
	_review_index = target
	_render_review()


# ---- 跳過整段(UX 第 4 節 / AC-8 / AC-16)--------------------------------------

func open_skip_panel() -> void:
	if _finished or _skip_panel_open or _current_lines.is_empty():
		return
	_skip_panel_open = true
	_skip_panel.visible = true
	_set_cursor_target(_default_skip_focus_id())
	if is_inside_tree():
		(_skip_no_button if _default_skip_focus_id() == TARGET_PANEL_CANCEL else _skip_yes_button).grab_focus()


## 確認面板預設焦點:取消(P-M4 破壞性動作確認);子類別測試用於敏感度證明。
func _default_skip_focus_id() -> int:
	return TARGET_PANEL_CANCEL


## 取消:回原句,零狀態變化(只關面板)。
func close_skip_panel() -> void:
	if not _skip_panel_open:
		return
	_skip_panel_open = false
	_skip_panel.visible = false
	_set_cursor_target(TARGET_ADVANCE)


## 確認跳過:先顯示本段最後一句(整句),玩家再按一次確認 -> 走與讀完同一條路徑。
func confirm_skip() -> void:
	if not _skip_panel_open:
		return
	_skip_panel_open = false
	_skip_panel.visible = false
	_review_index = NOT_REVIEWING
	_line_index = _current_lines.size() - 1
	_show_line()
	_shown_chars = float(_current_text.length())
	_apply_visible()
	_set_cursor_target(TARGET_ADVANCE)


func _activate_panel_focus() -> void:
	var focus_id: int = _default_skip_focus_id()
	var current: CursorTarget = CursorStateHost.get_current_target()
	if current != null and current.is_valid and current.surface == CursorTypes.SurfaceType.DIALOGUE_CHOICE:
		focus_id = current.id
	if focus_id == TARGET_PANEL_CONFIRM:
		confirm_skip()
	else:
		close_skip_panel()


# ---- 游標系統義務(UX 第 9 節)----------------------------------------------------

func _register_cursor_surface() -> void:
	var result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(
		CursorTypes.SurfaceType.DIALOGUE_CHOICE, self
	)
	if result != CursorSurfaceRegistry.RegisterResult.REGISTERED:
		push_error("SupportConversationScreen: register_surface(DIALOGUE_CHOICE) returned %s instead of REGISTERED" % result)
		return
	_surface_registered = true
	# 進場初始目標為「推進」區域(OBL:不得有無目標空白期);新場景接手走 handoff_after_mount。
	var seeded: CursorState.SetTargetResult = CursorStateHost.handoff_after_mount(
		CursorTarget.make(CursorTypes.SurfaceType.DIALOGUE_CHOICE, TARGET_ADVANCE)
	)
	if seeded != CursorState.SetTargetResult.APPLIED:
		push_error("SupportConversationScreen: handoff_after_mount returned %s instead of APPLIED" % seeded)


func _set_cursor_target(id: int) -> void:
	if not _surface_registered:
		return
	var result: CursorState.SetTargetResult = CursorStateHost.set_target(
		CursorTarget.make(CursorTypes.SurfaceType.DIALOGUE_CHOICE, id)
	)
	if result != CursorState.SetTargetResult.APPLIED:
		push_error("SupportConversationScreen: set_target(%d) returned %s instead of APPLIED" % [id, result])


## ADR-0005 duck-typed 導覽入口。目標集合:一般模式 推進/上一句/跳過 縱向排列;
## 確認面板開啟時只在 確定跳過/取消 之間水平切換。回傳 null = 該方向無合法目標。
func cursor_navigate(from_id: int, direction: Vector2i) -> Variant:
	if _skip_panel_open:
		if from_id == TARGET_PANEL_CONFIRM and direction.x > 0:
			return TARGET_PANEL_CANCEL
		if from_id == TARGET_PANEL_CANCEL and direction.x < 0:
			return TARGET_PANEL_CONFIRM
		return null
	var order: Array[int] = [TARGET_ADVANCE, TARGET_PREV, TARGET_SKIP]
	var step: int = direction.y if direction.y != 0 else direction.x
	var at: int = order.find(from_id)
	if at < 0 or step == 0:
		return null
	var next_at: int = at + signi(step)
	if next_at < 0 or next_at >= order.size():
		return null
	return order[next_at]


## 卸載前交接(OBL-021):目標若屬本表面,先標記待重新解析,再註銷表面。
## 子類別測試覆寫為空以做敏感度證明。
func _on_tree_exited_cursor_handoff() -> void:
	var current: CursorTarget = CursorStateHost.get_current_target()
	if current != null and current.surface == CursorTypes.SurfaceType.DIALOGUE_CHOICE:
		var mark_result: CursorState.MarkResult = CursorStateHost.mark_pending_reresolve(current)
		if mark_result != CursorState.MarkResult.APPLIED and mark_result != CursorState.MarkResult.NO_CURRENT_TARGET:
			push_error("SupportConversationScreen: mark_pending_reresolve returned %s while unloading" % mark_result)
	if _surface_registered:
		CursorStateHost.unregister_surface(CursorTypes.SurfaceType.DIALOGUE_CHOICE)
		_surface_registered = false


# ---- 診斷 -----------------------------------------------------------------------

func diagnostic_current_conversation_id() -> String:
	if _convo_index < conversation_ids.size():
		return conversation_ids[_convo_index]
	return ""


func diagnostic_current_line_index() -> int:
	return _line_index


func diagnostic_visible_text() -> String:
	if _text_label == null:
		return ""
	if _review_index != NOT_REVIEWING:
		return _text_label.text
	if _shown_chars >= float(_current_text.length()):
		return _current_text
	return _current_text.substr(0, int(_shown_chars))


func diagnostic_speaker_text() -> String:
	return _name_label.text if _name_label != null else ""


func diagnostic_line_fully_shown() -> bool:
	return _text_label != null and _shown_chars >= float(_current_text.length())


func diagnostic_is_finished() -> bool:
	return _finished


func diagnostic_review_index() -> int:
	return _review_index


func diagnostic_skip_panel_open() -> bool:
	return _skip_panel_open


## 對話框(推進區域)的全域中心點,測試用來造「點對話框」的滑鼠事件。
func diagnostic_advance_area_center() -> Vector2:
	return _text_panel.get_global_rect().get_center()


func diagnostic_skip_panel_texts() -> Array[String]:
	return [_skip_body.text, _skip_yes_button.text, _skip_no_button.text]


func diagnostic_button_texts() -> Array[String]:
	return [_prev_button.text, _skip_button.text]


# ---- 內部 -----------------------------------------------------------------------

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
			_review_index = NOT_REVIEWING
			_show_line()
			return true
		i += 1
	return false


func _speaker_text_of(entry: Dictionary) -> String:
	return resolve_text(SPEAKER_NAME_KEY_FORMAT % int(entry[SupportConversationScript.KEY_SPEAKER]))


func _show_line() -> void:
	var entry: Dictionary = _current_lines[_line_index]
	_current_text = resolve_text(String(entry[SupportConversationScript.KEY_TEXT_KEY]))
	_name_label.text = _speaker_text_of(entry)
	_text_label.text = _current_text
	_shown_chars = 0.0
	_apply_visible()


func _apply_visible() -> void:
	if _shown_chars >= float(_current_text.length()):
		_text_label.visible_characters = -1
	else:
		_text_label.visible_characters = int(_shown_chars)


func _render_current() -> void:
	var entry: Dictionary = _current_lines[_line_index]
	_name_label.text = _speaker_text_of(entry)
	_text_label.text = _current_text
	_apply_visible()


func _render_review() -> void:
	var entry: Dictionary = _current_lines[_review_index]
	_name_label.text = _speaker_text_of(entry)
	_text_label.text = resolve_text(String(entry[SupportConversationScript.KEY_TEXT_KEY]))
	_text_label.visible_characters = -1


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


func _make_button(key: String, left: float, right: float, top: float, bottom: float, parent: Control) -> Button:
	var button: Button = Button.new()
	button.text = resolve_text(key)
	button.anchor_left = left
	button.anchor_right = right
	button.anchor_top = top
	button.anchor_bottom = bottom
	parent.add_child(button)
	return button


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
	_name_label.anchor_right = 0.60
	_name_label.anchor_top = 0.64
	_name_label.anchor_bottom = 0.72
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	_prev_button = _make_button(TEXT_PREV, 0.62, 0.77, 0.64, 0.71, self)
	_prev_button.pressed.connect(review_back)
	_skip_button = _make_button(TEXT_SKIP, 0.79, 0.95, 0.64, 0.71, self)
	_skip_button.pressed.connect(open_skip_panel)
	_skip_panel = Panel.new()
	_skip_panel.anchor_left = 0.2
	_skip_panel.anchor_right = 0.8
	_skip_panel.anchor_top = 0.25
	_skip_panel.anchor_bottom = 0.6
	_skip_panel.visible = false
	add_child(_skip_panel)
	_skip_body = Label.new()
	_skip_body.text = resolve_text(TEXT_SKIP_BODY)
	_skip_body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_skip_body.anchor_left = 0.05
	_skip_body.anchor_right = 0.95
	_skip_body.anchor_top = 0.05
	_skip_body.anchor_bottom = 0.6
	_skip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_panel.add_child(_skip_body)
	_skip_yes_button = _make_button(TEXT_SKIP_YES, 0.05, 0.47, 0.68, 0.95, _skip_panel)
	_skip_yes_button.pressed.connect(confirm_skip)
	_skip_no_button = _make_button(TEXT_SKIP_NO, 0.53, 0.95, 0.68, 0.95, _skip_panel)
	_skip_no_button.pressed.connect(close_skip_panel)


func _apply_layout() -> void:
	var win: Vector2 = get_viewport().get_visible_rect().size
	var font_size: int = dialogue_font_size(Vector2i(int(win.x), int(win.y)))
	var themed: Array[Control] = [
		_text_label, _name_label, _prev_button, _skip_button, _skip_body, _skip_yes_button, _skip_no_button
	]
	for control: Control in themed:
		if _font != null:
			control.add_theme_font_override(&"font", _font)
		control.add_theme_font_size_override(&"font_size", font_size)
