## AttackConfirmPanel — Story 013（攻擊確認面板，二段確認）。
##
## `design/ux/tactical-combat-screen.md` 5(a)/7.3、GDD UI Requirements §4、
## Visual/Audio §2（傷害回饋須拆解 Φ 貢獻）。`P-M2`「預判/確認元件不得共用」——
## 本檔是獨立元件，不與 [CardConfirmPanel] 共用同一個類別（結構雷同是因為兩者
## 都遵循同一個「模態確認面板」既有慣例，見 [CardConfirmPanel] 自己的檔頭）。
##
## 同 [CardConfirmPanel] 的既有紀律：本檔完全不引用 [Unit]/[BattleState]/
## [BattleController] —— battle_screen.gd 是唯一同時認得畫面與遊戲狀態的類別
## （對 [BoardView]/[HandBar]/[CardConfirmPanel] 皆是如此），本檔只暴露顯示用
## 的公開入口（[method show_attack_confirmation]/[method hide_panel]）。
##
## 版面尺寸是本檔自己的判斷（同 [CardConfirmPanel] 的既有慣例），規格只定了
## 要顯示哪些欄位（ATK/DEF/Φ/結果傷害/預估 HP），沒有定尺寸。
class_name AttackConfirmPanel
extends Control

const HUD_FONT: FontFile = preload("res://assets/fonts/Cubic_11.ttf")

## Panel background size, in [method HudLayout.font_size] multiples — same
## convention as `card_confirm_panel.gd`'s own `PANEL_WIDTH_FPX_MULTIPLIER` /
## `PANEL_HEIGHT_FPX_MULTIPLIER`. Smaller than that panel's (fewer rows: no
## 逐條既有修正清單、no 永久警示).
const PANEL_WIDTH_FPX_MULTIPLIER: float = 22.0
const PANEL_HEIGHT_FPX_MULTIPLIER: float = 13.0

const CONTENT_MARGIN_FPX_MULTIPLIER: float = 0.6
const ROW_GAP_FPX_MULTIPLIER: float = 0.3

## Mirrors `card_confirm_panel.gd`'s own `PANEL_BG_COLOR`/`MASK_COLOR` — same
## 模態 vocabulary (`P-M1`), not a second visual language.
const PANEL_BG_COLOR: Color = Color(0.10, 0.10, 0.12, 0.92)
const MASK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)

const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
## 夾限提示列的顏色 — 同 `card_confirm_panel.gd` 的 `WARNING_COLOR`，標出一件
## 玩家需要特別注意的事（這次好感度加成被夾限砍掉了一部分）。
const CLAMP_NOTE_COLOR: Color = Color(1.0, 0.75, 0.3, 1.0)

## Story 013 — every constant below is a [StringName] KEY into
## `assets/data/locales/strings.csv`, not literal display text — every read
## site wraps it in [method Loc.localize] first (same migration discipline
## `card_confirm_panel.gd` already established).
const TEXT_HEADER_FORMAT: StringName = &"battle.attack_confirm.header_format"
const TEXT_ATK_FORMAT: StringName = &"battle.attack_confirm.atk_format"
const TEXT_DEF_FORMAT: StringName = &"battle.attack_confirm.def_format"
const TEXT_PHI_FORMAT: StringName = &"battle.attack_confirm.phi_format"
## 🔴 協調者補件（傷害拆解字典同時有 [code]"phi"[/code] 夾限後與
## [code]"phi_input"[/code] 夾限前兩個鍵）——兩者不同代表好感度加成被夾限砍掉
## 一部分，這一列只在那種情況下顯示，讓玩家看得出發生了什麼事，而不是只看到
## 一個對不上心算的 Φ 數字。
const TEXT_PHI_CLAMPED_FORMAT: StringName = &"battle.attack_confirm.phi_clamped_format"
const TEXT_DAMAGE_FORMAT: StringName = &"battle.attack_confirm.damage_format"
const TEXT_TARGET_HP_FORMAT: StringName = &"battle.attack_confirm.target_hp_format"

var _header_label: Label
var _atk_label: Label
var _def_label: Label
var _phi_label: Label
var _phi_clamp_label: Label
var _damage_label: Label
var _target_hp_label: Label

var _content: VBoxContainer
var _mask: ColorRect
var _background: ColorRect

## Every label built by [method _ensure_nodes], iterated by [method
## _apply_layout] so the font-size override lives in exactly one place —
## same pattern as `card_confirm_panel.gd`'s own [member _labels].
var _labels: Array[Label] = []

## Story 013 — whether the most recent [method show_attack_confirmation]
## call's phi/phi_input differed, exposed via [method
## diagnostic_phi_clamped_visible] so a test can assert this state directly
## rather than re-parsing label text.
var _phi_clamped: bool = false


func _ready() -> void:
	visible = false
	_ensure_nodes()
	_apply_layout()
	get_window().size_changed.connect(_apply_layout)


## Displays the T2' attack confirm panel. [param phi] is the value that
## actually enters [method CombatRules.damage] (post-clamp, enemy-zeroed per
## [method BattleState._attack_damage_breakdown]'s own rule); [param
## phi_input] is the raw value the caller supplied before any clamping. They
## differ exactly when the affinity bonus got clamped away in part — GDD
## Visual/Audio §2 requires that be observable, not collapsed into a single
## number. [param phi]/[param phi_input] are both shown signed via [method
## format_signed], including [code]0[/code] (never omitted — AC「Φ 帶號，=0
## 仍顯示」).
func show_attack_confirmation(
	attacker_name: String,
	target_name: String,
	atk: int,
	def: int,
	phi: int,
	phi_input: int,
	damage: int,
	target_hp: int,
	target_hp_after: int
) -> void:
	_header_label.text = Loc.localize(TEXT_HEADER_FORMAT) % [attacker_name, target_name]
	_atk_label.text = Loc.localize(TEXT_ATK_FORMAT) % atk
	_def_label.text = Loc.localize(TEXT_DEF_FORMAT) % def
	_phi_label.text = Loc.localize(TEXT_PHI_FORMAT) % format_signed(phi)

	_phi_clamped = phi != phi_input
	_phi_clamp_label.visible = _phi_clamped
	if _phi_clamped:
		_phi_clamp_label.text = Loc.localize(TEXT_PHI_CLAMPED_FORMAT) % [
			format_signed(phi_input), format_signed(phi)
		]

	_damage_label.text = Loc.localize(TEXT_DAMAGE_FORMAT) % damage
	_target_hp_label.text = Loc.localize(TEXT_TARGET_HP_FORMAT) % [target_hp, target_hp_after]

	visible = true
	_apply_layout()


## Closes the panel. Idempotent — calling this while already hidden is a
## harmless no-op (same contract as `card_confirm_panel.gd`'s own [method
## CardConfirmPanel.hide_panel]).
func hide_panel() -> void:
	visible = false


## Formats [param value] with an explicit leading sign, [code]0[/code]
## included (e.g. [code]"+0"[/code], never bare [code]"0"[/code]) — same
## contract as `card_confirm_panel.gd`'s own [method CardConfirmPanel.format_signed].
static func format_signed(value: int) -> String:
	return "%+d" % value


func diagnostic_header_text() -> String:
	return _header_label.text


func diagnostic_atk_text() -> String:
	return _atk_label.text


func diagnostic_def_text() -> String:
	return _def_label.text


func diagnostic_phi_text() -> String:
	return _phi_label.text


## True whenever the most recent [method show_attack_confirmation] call's
## [code]phi != phi_input[/code] — i.e. the affinity bonus was clamped.
func diagnostic_phi_clamped_visible() -> bool:
	return _phi_clamp_label.visible


func diagnostic_phi_clamped_text() -> String:
	return _phi_clamp_label.text


func diagnostic_damage_text() -> String:
	return _damage_label.text


func diagnostic_target_hp_text() -> String:
	return _target_hp_label.text


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

	_header_label = _build_label()
	_atk_label = _build_label()
	_def_label = _build_label()
	_phi_label = _build_label()
	_phi_clamp_label = _build_label()
	_phi_clamp_label.add_theme_color_override(&"font_color", CLAMP_NOTE_COLOR)
	_damage_label = _build_label()
	_target_hp_label = _build_label()

	_labels = [
		_header_label, _atk_label, _def_label, _phi_label, _phi_clamp_label,
		_damage_label, _target_hp_label,
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
## HudLayout.safe_rect] — mirrors `card_confirm_panel.gd`'s own [method
## CardConfirmPanel.panel_rect] convention exactly (this file does not invent
## a second centering formula).
static func panel_rect(window_size: Vector2i) -> Rect2:
	var fpx: float = float(HudLayout.font_size(window_size))
	var safe: Rect2 = HudLayout.safe_rect(window_size)
	var size: Vector2 = Vector2(fpx * PANEL_WIDTH_FPX_MULTIPLIER, fpx * PANEL_HEIGHT_FPX_MULTIPLIER)
	var pos: Vector2 = safe.position + (safe.size - size) / 2.0
	return Rect2(pos, size)
