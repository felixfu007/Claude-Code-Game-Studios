## Story U-014（`production/epics/card-play-interface/story-u014-confirm-panel.md`）
## — 確認面板(S3):打牌流程唯一的不可逆寫入點的顯示層
## (`design/ux/skill-card-play.md`「確認面板欄位」節,2026-09-10 管理者裁決)。
## 逐欄拆解甲類/丙類的效果,並落實該節的三項合規重點:
##   1. 甲類「合併後有效值不得取代逐條那一列」——兩者永遠並列顯示。
##   2. 丙類「作用對象」必須回顯玩家在 S2p/S2q 的實際選取,不得從卡片欄位讀
##      (呼叫端 battle_screen.gd 的職責,本檔本身不能也不做這個檢查)。
##   3. 丙類好感度數值以「現值 → 打完後」箭頭呈現,恰好一次——AC-U14。
##
## [b]本檔完全不引用 [Card]/[CardModifier]/[Unit]/[AffinityLink][/b] —— 與
## [HandBar] 的既有紀律相同(`.claude/rules/ui-code.md`:「UI must NEVER own or
## directly modify game state — display only」;`hand_bar.gd` 類別文件註解:
## 「defines its own display-only vocabulary...rather than the gameplay enum it
## is ultimately fed from」)。[enum Category] 是本檔自己的顯示用詞彙,不是
## [enum Card.Category]。battle_screen.gd(「同時認得雙方」的那一個類別,對
## [BoardView]/[HandBar] 皆是如此)才是唯一知道 [Card]/[Unit] 真實形狀的地方。
##
## [b]確認/取消輸入由 battle_screen.gd 分派,本檔不覆寫 [method Node._input][/b]
## —— 同 [HandBar] 的既有分工(其選牌游標移動是被外部呼叫的
## [method HandBar.move_cursor] 驅動,不是自己讀鍵盤)。本檔只暴露三個顯示用
## 公開入口:[method show_temporary_modifier_confirmation]、
## [method show_permanent_write_confirmation]、[method hide_panel]。
##
## [b]2026-09-24 管理者裁決:丙類好感度欄位「維持留白＋提示」[/b] ——
## `combat_strength_read`(UX-13)不接上任何真實資料來源。[method
## show_permanent_write_confirmation] 的 [param strength_available] 參數是
## 為日後接上真值預留的注入點(呼叫端 battle_screen.gd 那個具名、可注入的
## Callable 欄位是實際的接縫;本檔只負責「給了值就畫箭頭,沒給就畫提示」這個
## 純顯示分支),本story 不會、也不應該把它接上任何資料來源。
##
## [b]版面尺寸是本檔自己的判斷,不是規格逐字寫死的數字[/b](同
## `hud_layout.gd` / `battle_menu.gd` 對這類常數的既有揭露慣例)——規格只定了
## 要顯示哪些欄位(「確認面板欄位」節),沒有定尺寸。截圖/像素驗證本批不做
## (`coding-standards.md` 截圖規則本批不適用 UI 型 ADVISORY 證據,且管理者
## 明文本機不得開窗)。
class_name CardConfirmPanel
extends Control

## Which of the two MVP card categories the panel is currently showing — this
## file's own display vocabulary (see class doc comment). [constant NONE] is
## the panel's at-rest / hidden state.
enum Category { NONE, TEMPORARY_MODIFIER, PERMANENT_WRITE }

const HUD_FONT: FontFile = preload("res://assets/fonts/Cubic_11.ttf")

## Panel background size, in [method HudLayout.font_size] multiples — mirrors
## `battle_menu.gd`'s `PANEL_WIDTH_FPX_MULTIPLIER` / `PANEL_HEIGHT_FPX_MULTIPLIER`
## convention exactly. This file's own placeholder judgment (class doc
## comment) — tall enough for 丙類's five stacked rows or 甲類's six, at the
## smallest supported window (960x540, N=2).
const PANEL_WIDTH_FPX_MULTIPLIER: float = 24.0
const PANEL_HEIGHT_FPX_MULTIPLIER: float = 18.0

## Inner content margin / row gap, in fpx — mirrors `battle_menu.gd`'s
## `CONTENT_MARGIN_FPX_MULTIPLIER` convention.
const CONTENT_MARGIN_FPX_MULTIPLIER: float = 0.6
const ROW_GAP_FPX_MULTIPLIER: float = 0.3

## Mirrors `battle_menu.gd`'s own `PANEL_BG_COLOR` / `MASK_COLOR` — this panel
## is the same "模態" vocabulary (`skill-card-play.md` Component Inventory:
## 確認面板 | 模態 | ... | P-M1), so it reuses the same visual language rather
## than inventing a second one.
const PANEL_BG_COLOR: Color = Color(0.10, 0.10, 0.12, 0.92)
const MASK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)

const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const WARNING_COLOR: Color = Color(1.0, 0.75, 0.3, 1.0)

## Implementation Note 2 — 「永久」不可逆警示文字+圖示(圖示以既有字符表示,
## 同 [HandBar] 的既有作法:組合既有字元/圖元,不新增 PNG 資產 — UX-3 卡面
## 美術未定前的既有慣例)。
const TEXT_PERMANENT_WARNING: String = "⚠ 永久效果，無法復原"

## Implementation Note 2 — 「敘事影響」固定為一句定性文字,沿用 Z3 既有文案
## (`skill-card-play.md` Component Inventory「定性提示(Z3)」列)。
const TEXT_NARRATIVE: String = "敘事影響小於戰場影響"

## UX-13 / 2026-09-24 管理者裁決「維持留白＋提示」——`skill-card-play.md`
## 「查無資料時的處理」表:「留白 + 同一句提示,不得顯示 0 或省略欄位」。
const TEXT_STRENGTH_UNAVAILABLE: String = "（好感度數值尚未提供 — 見 UX-13）"

const TEXT_NO_EXISTING_MODIFIERS: String = "（此對象目前無生效中修正）"

## AC-U14 的箭頭字面量——「現值 → 打完後」的分隔符。[method format_strength_arrow]
## 是本檔唯一產生它的地方,[method text_uses_required_arrow_format] 是唯一
## 檢查它的地方,兩者共用同一個常數,不各自寫一份字面量。
const ARROW_GLYPH: String = " → "

var _category: Category = Category.NONE

var _mask: ColorRect
var _background: ColorRect
var _content: VBoxContainer
var _title_label: Label
var _target_label: Label
var _delta_atk_label: Label
var _delta_def_label: Label
var _duration_label: Label
var _existing_modifiers_label: Label
var _effective_label: Label
var _permanent_warning_label: Label
var _strength_label: Label
var _narrative_label: Label

## Every label built by [method _ensure_nodes], populated once — iterated by
## [method _apply_layout] so font-size overrides live in exactly one place.
var _labels: Array[Label] = []

## Story U-014 — one formatted line per entry in the most recent
## [method show_temporary_modifier_confirmation]'s [param existing_modifiers],
## exposed via [method diagnostic_existing_modifier_line] so a test can assert
## a SPECIFIC entry rather than parsing [member _existing_modifiers_label]'s
## joined text.
var _existing_modifier_lines: Array[String] = []

## Story U-014 (AC-U14 discriminator) — the exact text currently shown for
## 丙類's strength row, whatever it is (arrow-formatted or the UX-13
## unavailable placeholder). See [method diagnostic_strength_text].
var _strength_text: String = ""


func _ready() -> void:
	visible = false
	_ensure_nodes()
	_apply_layout()
	get_window().size_changed.connect(_apply_layout)


## Implementation Note 1 — 甲類確認面板欄位,逐欄轉錄(`skill-card-play.md`
## 「確認面板欄位」節):卡名與牌面文字、作用對象、`Δatk`/`Δdef`(帶號,`0`
## 仍顯示)、存續回合 `r`、該對象生效中的既有修正逐條、合併後有效值。
## 🔴 合併後有效值不得取代逐條那一列(GDD UI Requirements #7)——
## [param existing_modifiers] 與 [param effective_atk]/[param effective_def]
## 兩者永遠同時顯示,呼叫端沒有任何方式只傳其中一個。
##
## [param existing_modifiers] — 每筆
## [code]{"source_name":String,"atk_delta":int,"def_delta":int,
## "remaining_turns":int}[/code],呼叫端從 [method Unit.active_modifiers] 映射
## 而來(本檔不引用 [CardModifier] 本身,見類別文件註解)。空陣列合法(代表
## 該對象目前無生效中修正),不是資料缺失,顯示 [constant TEXT_NO_EXISTING_MODIFIERS]
## 而非空白。
func show_temporary_modifier_confirmation(
	card_id: String,
	flavor_text: String,
	target_name: String,
	delta_atk: int,
	delta_def: int,
	duration_rounds: int,
	existing_modifiers: Array[Dictionary],
	effective_atk: int,
	effective_def: int
) -> void:
	_category = Category.TEMPORARY_MODIFIER
	_title_label.text = _format_title(card_id, flavor_text)
	_target_label.text = "作用對象：%s" % target_name
	_delta_atk_label.text = "ΔATK：%s" % format_signed(delta_atk)
	_delta_def_label.text = "ΔDEF：%s" % format_signed(delta_def)
	_duration_label.text = "存續回合：%d" % duration_rounds

	_existing_modifier_lines = []
	for entry: Dictionary in existing_modifiers:
		_existing_modifier_lines.append(
			"%s：ATK %s／DEF %s，剩 %d 回合" % [
				entry.get("source_name", ""),
				format_signed(int(entry.get("atk_delta", 0))),
				format_signed(int(entry.get("def_delta", 0))),
				int(entry.get("remaining_turns", 0)),
			]
		)
	_existing_modifiers_label.text = (
		TEXT_NO_EXISTING_MODIFIERS if _existing_modifier_lines.is_empty()
		else "\n".join(PackedStringArray(_existing_modifier_lines))
	)
	_effective_label.text = "合併後：ATK_eff %d／DEF_eff %d" % [effective_atk, effective_def]

	_set_row_visibility(true)

	visible = true
	_apply_layout()


## Implementation Notes 2/3 — 丙類確認面板欄位(同上節):卡名與牌面文字、
## 作用對象(配對雙方姓名,🔴 [param target_a_name]/[param target_b_name] 必須
## 來自玩家在棋盤上的實際選取,不得從卡片欄位讀——battle_screen.gd 的呼叫端
## 已依此紀律,本檔本身不作也不能作這個檢查)、「永久」不可逆警示、好感度數值
## (現值 → 打完後箭頭,恰好一次)、敘事影響(固定一句,零數字)。
##
## [param strength_available]/[param current_strength]/[param projected_strength]
## — UX-13:`combat_strength_read` 依 2026-09-24 管理者裁決「維持留白＋提示」,
## 不接上任何真實資料來源;呼叫端(battle_screen.gd)今天必然傳
## [code]strength_available = false[/code]。為 false 時不論後兩個參數傳什麼
## 都不顯示——顯示 [constant TEXT_STRENGTH_UNAVAILABLE] 佔位提示,不顯示 `0`,
## 也不省略這個欄位(見「查無資料時的處理」表)。
func show_permanent_write_confirmation(
	card_id: String,
	flavor_text: String,
	target_a_name: String,
	target_b_name: String,
	strength_available: bool,
	current_strength: int,
	projected_strength: int
) -> void:
	_category = Category.PERMANENT_WRITE
	_title_label.text = _format_title(card_id, flavor_text)
	_target_label.text = "作用對象：%s ↔ %s" % [target_a_name, target_b_name]
	_permanent_warning_label.text = TEXT_PERMANENT_WARNING
	_strength_text = (
		format_strength_arrow(current_strength, projected_strength) if strength_available
		else TEXT_STRENGTH_UNAVAILABLE
	)
	_strength_label.text = "好感度：%s" % _strength_text
	_narrative_label.text = TEXT_NARRATIVE

	_set_row_visibility(false)

	visible = true
	_apply_layout()


## Closes the panel — reverses whatever the most recent [method
## show_temporary_modifier_confirmation] / [method show_permanent_write_confirmation]
## call set. Idempotent (calling this while already hidden is a harmless
## no-op).
func hide_panel() -> void:
	_category = Category.NONE
	visible = false


## Formats [param value] with an explicit leading sign — Implementation Note 1's
## "帶號,`0` 仍顯示" requirement ([code]0[/code] formats as [code]"+0"[/code],
## never bare [code]"0"[/code]).
static func format_signed(value: int) -> String:
	return "%+d" % value


## AC-U14 — 「現值 → 打完後」箭頭格式,本檔產生這個字串的唯一函式。
static func format_strength_arrow(current: int, projected: int) -> String:
	return "%s%s%s" % [format_signed(current), ARROW_GLYPH, format_signed(projected)]


## AC-U14 鑑別力測試用的判準函式——判斷 [param text] 是否符合「恰好一組
## 『現值 → 打完後』箭頭」的形狀:[constant ARROW_GLYPH] 恰好出現一次,且兩側
## 各自是一個帶號整數字串。「兩欄並排、無箭頭關聯」的版本(例如以 tab 或換行
## 分隔兩個數字,不含 [constant ARROW_GLYPH])必須讓這個函式回傳
## [code]false[/code]——這正是 AC-U14 後半句要求的鑑別力來源。
static func text_uses_required_arrow_format(text: String) -> bool:
	if text.count(ARROW_GLYPH) != 1:
		return false
	var parts: PackedStringArray = text.split(ARROW_GLYPH, true, 1)
	if parts.size() != 2:
		return false
	return _looks_like_signed_int(parts[0]) and _looks_like_signed_int(parts[1])


static func _looks_like_signed_int(token: String) -> bool:
	var trimmed: String = token.strip_edges()
	if trimmed.is_empty():
		return false
	if trimmed[0] != "+" and trimmed[0] != "-":
		return false
	return trimmed.substr(1).is_valid_int()


static func _format_title(card_id: String, flavor_text: String) -> String:
	if flavor_text.is_empty():
		return card_id
	return "%s\n%s" % [card_id, flavor_text]


## Which category the panel is currently showing ([constant Category.NONE]
## while hidden) — lets a test assert the panel actually switched to the
## expected variant, not merely that SOME text is showing.
func diagnostic_category() -> Category:
	return _category


## Exact text currently shown in the title row (卡名 + 牌面文字, see [method
## _format_title]) — lets a test assert the specific card's id/flavor text was
## used, not merely that the row is non-empty.
func diagnostic_title_text() -> String:
	return _title_label.text


## Exact text currently shown in the「作用對象」row — one target's name for
## 甲類, or the "A ↔ B" pair for 丙類 (see [method
## show_temporary_modifier_confirmation] / [method
## show_permanent_write_confirmation]).
func diagnostic_target_text() -> String:
	return _target_label.text


## Exact text currently shown in the甲類 ΔATK row — always signed via [method
## format_signed], including [code]"+0"[/code] (Implementation Note 1: 0 is a
## legal value, never omitted).
func diagnostic_delta_atk_text() -> String:
	return _delta_atk_label.text


## Same as [method diagnostic_delta_atk_text] for the ΔDEF row.
func diagnostic_delta_def_text() -> String:
	return _delta_def_label.text


## Exact text currently shown in the 甲類「存續回合」row.
func diagnostic_duration_text() -> String:
	return _duration_label.text


## Number of entries in the most recent [method
## show_temporary_modifier_confirmation]'s [param existing_modifiers] — 0 is a
## legal, distinct state from "no card shown at all" (see [constant
## TEXT_NO_EXISTING_MODIFIERS]).
func diagnostic_existing_modifier_count() -> int:
	return _existing_modifier_lines.size()


## One formatted line from the most recent [method
## show_temporary_modifier_confirmation]'s existing-modifiers list — lets a
## test assert a SPECIFIC entry's content (source/delta/remaining turns)
## rather than parsing [member _existing_modifiers_label]'s joined text.
## Out-of-range [param index] returns [code]""[/code] rather than crashing.
func diagnostic_existing_modifier_line(index: int) -> String:
	if index < 0 or index >= _existing_modifier_lines.size():
		return ""
	return _existing_modifier_lines[index]


## Exact text currently shown in the 甲類「合併後有效值」row (ATK_eff/DEF_eff) —
## GDD UI Requirements #7: this row and [method diagnostic_existing_modifier_line]
## are always both populated, never one in place of the other.
func diagnostic_effective_text() -> String:
	return _effective_label.text


## True while the 丙類「永久」不可逆警示 row is visible — should be
## [code]true[/code] whenever [method diagnostic_category] is [constant
## Category.PERMANENT_WRITE], per Implementation Note 2.
func diagnostic_permanent_warning_visible() -> bool:
	return _permanent_warning_label.visible


## Exact text currently shown in the 丙類「永久」警示 row.
func diagnostic_permanent_warning_text() -> String:
	return _permanent_warning_label.text


## Exact text currently shown for 丙類's「好感度」row — either [method
## format_strength_arrow]'s output or [constant TEXT_STRENGTH_UNAVAILABLE],
## whichever [method show_permanent_write_confirmation]'s [param
## strength_available] selected. AC-U14's discriminator ([method
## text_uses_required_arrow_format]) is meant to be run against exactly this
## value.
func diagnostic_strength_text() -> String:
	return _strength_text


## Exact text currently shown in the 丙類「敘事影響」row — always [constant
## TEXT_NARRATIVE] today (Implementation Note 2: fixed one-line text, zero
## numbers).
func diagnostic_narrative_text() -> String:
	return _narrative_label.text


func _set_row_visibility(is_temporary_modifier: bool) -> void:
	_delta_atk_label.visible = is_temporary_modifier
	_delta_def_label.visible = is_temporary_modifier
	_duration_label.visible = is_temporary_modifier
	_existing_modifiers_label.visible = is_temporary_modifier
	_effective_label.visible = is_temporary_modifier
	_permanent_warning_label.visible = not is_temporary_modifier
	_strength_label.visible = not is_temporary_modifier
	_narrative_label.visible = not is_temporary_modifier


func _ensure_nodes() -> void:
	if _mask != null:
		return

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_mask = ColorRect.new()
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.color = MASK_COLOR
	add_child(_mask)

	_background = ColorRect.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.color = PANEL_BG_COLOR
	add_child(_background)

	_content = VBoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_child(_content)

	_title_label = _build_label()
	_target_label = _build_label()
	_delta_atk_label = _build_label()
	_delta_def_label = _build_label()
	_duration_label = _build_label()
	_existing_modifiers_label = _build_label()
	_effective_label = _build_label()
	_permanent_warning_label = _build_label()
	_permanent_warning_label.add_theme_color_override(&"font_color", WARNING_COLOR)
	_strength_label = _build_label()
	_narrative_label = _build_label()

	_labels = [
		_title_label, _target_label, _delta_atk_label, _delta_def_label,
		_duration_label, _existing_modifiers_label, _effective_label,
		_permanent_warning_label, _strength_label, _narrative_label,
	]
	for label: Label in _labels:
		_content.add_child(label)


func _build_label() -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", HUD_FONT)
	label.add_theme_color_override(&"font_color", TEXT_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _apply_layout() -> void:
	if _background == null:
		return
	var window_size: Vector2i = get_window().size
	_mask.position = Vector2.ZERO
	_mask.size = Vector2(window_size)

	var rect: Rect2 = panel_rect(window_size)
	_background.position = rect.position
	_background.size = rect.size

	var fpx_int: int = HudLayout.font_size(window_size)
	var fpx: float = float(fpx_int)
	var margin: float = fpx * CONTENT_MARGIN_FPX_MULTIPLIER
	_content.position = Vector2(margin, margin)
	_content.size = rect.size - Vector2(margin, margin) * 2.0
	_content.add_theme_constant_override(&"separation", int(round(fpx * ROW_GAP_FPX_MULTIPLIER)))

	for label: Label in _labels:
		label.add_theme_font_size_override(&"font_size", fpx_int)


## Panel background rect in window-pixel space, centered within [method
## HudLayout.safe_rect] — mirrors `battle_menu.gd`'s `panel_rect()` convention
## exactly (this file does not invent a second centering formula).
static func panel_rect(window_size: Vector2i) -> Rect2:
	var fpx: float = float(HudLayout.font_size(window_size))
	var safe: Rect2 = HudLayout.safe_rect(window_size)
	var size: Vector2 = Vector2(fpx * PANEL_WIDTH_FPX_MULTIPLIER, fpx * PANEL_HEIGHT_FPX_MULTIPLIER)
	var pos: Vector2 = safe.position + (safe.size - size) / 2.0
	return Rect2(pos, size)
