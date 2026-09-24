## Z1 手牌縮圖帶 — Story U-011(`production/epics/card-play-interface/story-u011-hand-bar-thumbnails.md`)。
## 常駐於玩家回合期間,顯示「有幾張、各是什麼類別」,並讓 S0(常態)/S5(不可用)/
## S7(空手牌)三態在灰階下仍可互相區分(`design/ux/skill-card-play.md` States &
## Variants,`P-F3` 無例外)。
##
## [b]This node owns zero game state and makes zero rule decisions[/b] — mirrors
## [BoardView]'s discipline (per [code].claude/rules/ui-code.md[/code], "UI must
## NEVER own or directly modify game state — display only"): it never
## references [Card] / [CardDeck] / [BattleController], and defines its own
## display-only vocabulary ([enum SlotKind], [enum Availability]) rather than
## the gameplay [enum Card.Category] it is ultimately fed from.
## [code]battle_screen.gd[/code] — the one class allowed to know both sides,
## exactly as its own doc comment already establishes for [BoardView] — is
## where the [Card.Category] -> [enum SlotKind] mapping lives
## ([code]hand_bar_slot_kind_for()[/code]), mirroring that file's existing
## [code]line_tone_for()[/code] pattern precisely.
##
## [b]U-012 / U-015 will keep extending this same file[/b] (EPIC.md's
## serialization-point table: [code]hand_bar.gd[/code] is the file U-011/
## U-012/U-015 all grow, not three separate files) — Z2 expand/Z3 detail/S1
## selection (U-012) and S4 forced-discard (U-015) are explicitly out of scope
## here.
##
## [b]Placeholder art, not final art[/b] (Story U-011 Out of Scope: card face
## pixel size/color count/outline/font is `art-director` + `/art-bible`'s job,
## UX-3 — "不得沿用 128×128 立繪"). Every slot is composed from plain engine
## primitives ([Panel] + [StyleBoxFlat], [ColorRect]) — no custom [code]_draw()[/code]
## anywhere in this file, matching [BoardView]'s own "compose from primitive
## nodes" convention rather than introducing a new raw-draw technique into this
## codebase. 甲(temporary modifier) is an unrotated square outline; 丙
## (permanent write) is the exact same [Panel] rotated 45° — one visual
## technique reused for both the shape channel and the icon-mark channel
## (`Component Inventory`: 類別靠「形狀+圖示」區分,非顏色). This is a
## deliberate, disclosed judgment call about placeholder geometry, not a design
## decision handed down by any spec — the spec only fixes the slot's overall
## [i]size[/i] (`Layout Zones` Z1 row), never its shape vocabulary.
##
## [b]Z1 geometry is composed entirely from existing [HudLayout] functions[/b]
## ([method HudLayout.safe_rect], [method HudLayout.font_size],
## [method HudLayout.controls_hint_bg_rect]) — per this project's registered
## failure pattern (the same formula re-implemented twice, only agreeing
## "today"), [method slot_bar_rect] never re-derives any of those three
## functions' own math; it only combines their already-computed results with
## the Z1-specific arithmetic the UX spec defines (bar width/height in fpx
## multiples, bottom edge pinned half an fpx above the control-hint bar's top
## edge — EPIC.md 陷阱十一: "Z1 必須在操作提示橫條上方,不是螢幕底部").
##
## [b]"決定" vs "套用" split[/b] (`.claude/docs/coding-standards.md`'s
## headless-UI-testing rule, EPIC.md 陷阱十三): every [code]diagnostic_*[/code]
## getter below is a pure state read, verifiable headless without a real
## window; the actual pixel outcome (are the three S5 channels, or the two
## category shapes, genuinely visually distinguishable) can only be confirmed
## from a real windowed capture — see
## [code]production/qa/evidence/story-u011-hand-bar-evidence.md[/code].
class_name HandBar
extends Control

## Which of [Card]'s two MVP categories a filled slot represents — this
## project's own display vocabulary, not [enum Card.Category] itself (see the
## class doc comment). [code]battle_screen.gd[/code]'s
## [code]hand_bar_slot_kind_for()[/code] is the sole mapping point.
enum SlotKind { TEMPORARY_MODIFIER, PERMANENT_WRITE }

## Whether the whole bar is currently usable. [constant LOCKED] covers S5
## (enemy turn) — see [code]battle_screen.gd[/code]'s
## [code]availability_for()[/code] for exactly which
## [enum BattleController.Phase] values map to which value here (a
## 2026-09-17 coordinator ruling, not decided by this file).
enum Availability { NORMAL, LOCKED }

## Placeholder shape vocabulary for a filled slot's category — see the class
## doc comment's "placeholder art, not final art" note.
enum IconShape { SQUARE, DIAMOND }

const HUD_FONT: FontFile = preload("res://assets/fonts/Cubic_11.ttf")

## Z1 `Layout Zones` row, verbatim: "單卡 2×3 fpx,間距 0.5 fpx(合計 12 fpx 寬)".
const SLOT_WIDTH_FPX_MULTIPLIER: float = 2.0
const SLOT_HEIGHT_FPX_MULTIPLIER: float = 3.0
const SLOT_GAP_FPX_MULTIPLIER: float = 0.5

## Z1 `Layout Zones` row, verbatim: "下緣 = 操作提示橫條上緣再往上 0.5 fpx".
const BAR_BOTTOM_MARGIN_FPX_MULTIPLIER: float = 0.5

## Z2 `Layout Zones` row, verbatim: "單卡 4.5 × 6 fpx,間距 0.5 fpx(合計 24.5 fpx
## 寬)". Gap reuses [constant SLOT_GAP_FPX_MULTIPLIER] — the spec states the
## same 0.5 value for both Z1 and Z2, not a coincidence worth a second
## constant. 🔴 Hard ceiling, do not widen without re-verifying
## `design/ux/skill-card-play.md`'s own guard: "任何日後加寬卡面的提案,先驗算
## 5w + 4g ≤ 26.2 fpx".
const EXPANDED_SLOT_WIDTH_FPX_MULTIPLIER: float = 4.5
const EXPANDED_SLOT_HEIGHT_FPX_MULTIPLIER: float = 6.0

## Z3 `Layout Zones` row: "寬 ≥ 該卡,高 ≤ 4 fpx". This file's own judgment
## (not spec-mandated): exactly as wide as the selected card (satisfies "≥"
## with equality — the narrowest legal choice) and exactly the stated
## maximum height.
const DETAIL_PANEL_HEIGHT_FPX_MULTIPLIER: float = 4.0
## Gap between Z3's bottom edge and Z2's top edge — this file's own
## placeholder judgment, same category as [constant CAPTION_GAP_FPX_MULTIPLIER].
const DETAIL_PANEL_GAP_FPX_MULTIPLIER: float = 0.3

## Duration of the Z1<->Z2 expand/collapse transition, in seconds. This
## file's own judgment call: AC-U2 requires "Z2 完全可讀 ≤ 200ms"; 0.15s
## leaves margin for the frame the transition completes on plus whatever
## draws immediately after, on this project's 60fps budget
## (`technical-preferences.md`). ⚠️ Not verified against a real windowed run
## yet — see this story's task report for what headless testing can and
## cannot prove about this value.
const EXPAND_TRANSITION_SECONDS: float = 0.15

## S1's "該卡上浮" (`States & Variants`) — vertical lift applied to the
## cursor's own Z2 slot while expanded, scaled by [member _expand_progress]
## so it only reaches full value once the expand transition completes. This
## file's own placeholder magnitude, not a spec number.
const CURSOR_LIFT_FPX_MULTIPLIER: float = 0.3

## Count-label geometry — not a spec number, this file's own placeholder
## layout judgment (the spec only fixes the card-slot area itself; see the
## class doc comment).
const COUNT_LABEL_WIDTH_FPX_MULTIPLIER: float = 4.0
const COUNT_LABEL_GAP_FPX_MULTIPLIER: float = 0.5

## Lock-glyph / unavailable-caption geometry — same "this file's own
## placeholder judgment" caveat as the count-label constants above. Both sit
## ABOVE the slot row (negative local Y), which only ever grows the bar's
## visual footprint away from [method HudLayout.controls_hint_bg_rect] — never
## toward it — so EPIC.md 陷阱十一's "must stay above the hint bar" constraint
## cannot be violated by adding this row.
const CAPTION_HEIGHT_FPX_MULTIPLIER: float = 1.5
const CAPTION_GAP_FPX_MULTIPLIER: float = 0.3
const LOCK_GLYPH_SIZE_FPX_MULTIPLIER: float = 1.2
## `design/art/battle-ui-glyph-spec.md` 二 (2026-09-17 art-director
## glyph-defect ruling): 0.3 -> 0.6, doubling the gap so it clears the
## Gestalt-proximity threshold at N=2 (6.6px -> 13.2px) — see that section's
## "為什麼" for why this only reads cleanly once [member _backing] (三) gives
## the gap a fixed, predictable background instead of an arbitrary board tile.
const LOCK_GLYPH_GAP_FPX_MULTIPLIER: float = 0.6

## Icon-mark (category-shape child inside a filled slot) geometry.
const ICON_MARK_SIZE_FPX_MULTIPLIER: float = 0.7
const ICON_MARK_MARGIN_FPX_MULTIPLIER: float = 0.25

## S5's "降對比" channel — a multiplier applied directly to each element's OWN
## alpha (slot borders, icon marks, the count label's font colour), never to
## [member CanvasItem.modulate] / [member CanvasItem.self_modulate]. 🔴 That
## exclusion is deliberate, not stylistic: `tests/unit/cursor/
## cursor_modulate_alpha_single_writer_test.gd` enforces ADR-0005 R6-8 —
## [code]modulate.a[/code] anywhere under [code]res://src[/code] must have
## exactly one writer, [code]SelfDrawnReclaimCursor[/code], because
## [member CanvasItem.modulate] is a PER-NODE property two independent
## systems could never safely share even by coincidence. A first draft of
## this file wrote [code]modulate.a = ...[/code] here and that governance
## test caught it immediately (2026-09-17) — dimming this bar's own child
## element colours achieves the same "降對比" channel without touching a
## property this project has reserved exclusively for the cursor system.
## One of S5's three non-color channels (`States & Variants`); the other two
## are the lock glyph and [member _unavailable_label]'s caption.
const LOCKED_DIM_FACTOR: float = 0.4

## Slot outline colour. Deliberately the SAME colour for every category and
## for the empty case — per `Component Inventory` ("類別...靠形狀+圖示區分,
## 非顏色", `P-F3` 無例外), only alpha (filled vs empty) and shape/rotation
## (甲 vs 丙) may differ; hue never carries meaning here.
const SLOT_OUTLINE_COLOR: Color = Color(1.0, 1.0, 1.0)
const FILLED_SLOT_BORDER_ALPHA: float = 0.9
## `design/art/battle-ui-glyph-spec.md` 三 (2026-09-17 art-director glyph-defect
## ruling): 0.3 -> 0.6. The low value was originally a hedge against an
## unpredictable background (the empty outline used to sit directly on
## whatever board tile/piece happened to be underneath); now that
## [member _backing] always sits behind it, the alpha no longer has to "bet"
## against an unknown background, so it can go up to a clearly-visible level
## while keeping [constant FILLED_SLOT_BORDER_ALPHA]'s 0.9 clearly stronger.
const EMPTY_SLOT_BORDER_ALPHA: float = 0.6

## S3's fixed dark backing behind the whole hand-bar row (card slots + count
## label +, when visible, the caption/lock-glyph row above them) —
## `design/art/battle-ui-glyph-spec.md` 三. Always present regardless of
## [enum Availability]/expand state (see that section's "為什麼": a fixed
## footprint avoids a second "when does this resize" state to keep in sync,
## this project's own registered failure pattern of the same value computed
## twice). [member _backing] must be this control's FIRST child (bottom of
## paint order) — see [method _ensure_backing].
const HAND_BAR_BACKING_PADDING_FPX_MULTIPLIER: float = 0.25

## Identical value to `battle_menu.gd`'s `MASK_COLOR` — deliberately reused,
## not a new hue, per the glyph spec's "為什麼": the same "this is the
## interface's own backing, not the board" visual vocabulary in both places.
const HAND_BAR_BACKING_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)

const TEXT_COUNT_FORMAT: String = "%d/%d"
## S5 caption text — one of its three non-color channels. Centralized as a
## constant per [code].claude/rules/ui-code.md[/code]'s "all UI text must go
## through the localization system, no hardcoded strings" rule, matching
## [code]battle_screen.gd[/code]'s existing [code]TEXT_*[/code] convention
## (this project has no localization system yet — building one is out of
## scope here, exactly as that file's own doc comment already states for its
## own [code]TEXT_*[/code] block).
const TEXT_UNAVAILABLE: String = "不可用"
## Z3's 丙類 marker text (`Component Inventory`: "「永久」標示...丙類專用").
## Centralized as a constant for the same reason as [constant TEXT_UNAVAILABLE].
const TEXT_PERMANENT_MARK: String = "永久"

## Story U-015(強制棄牌 S4)—— reuses [member _unavailable_label] (the same
## node [constant TEXT_UNAVAILABLE] uses for S5) rather than adding a second
## caption node, since the two states are mutually exclusive in practice
## (LOCKED only ever occurs outside PLAYER_INPUT; a forced discard only ever
## occurs at the start of the player's own turn, squarely inside
## PLAYER_INPUT — see `design/ux/skill-card-play.md`'s own States & Variants
## table). Deliberately different wording from both [constant TEXT_UNAVAILABLE]
## and `battle_menu.gd`'s [constant BattleMenu.REJECTION_MESSAGE_FORCED_DISCARD]
## ("請先完成棄牌") — this is a DIFFERENT display surface (the hand bar itself,
## always visible while S4 is active) answering a DIFFERENT question ("why
## can't I do anything else right now", not "why did the menu refuse to
## open"), so a verbatim match is not required — see `.claude/docs/ui-code.md`
## conventions this file already follows for its own [code]TEXT_*[/code] block.
const TEXT_FORCED_DISCARD: String = "手牌已滿，請選一張棄掉"

@onready var _count_label: Label = $CountLabel
@onready var _unavailable_label: Label = $UnavailableLabel

## Slot [Panel] nodes currently built by [method _rebuild_slots] — cleared and
## rebuilt on every [method render] call, mirroring [method BoardView._clear_children]'s
## "one throwaway subtree per render" convention.
var _slot_nodes: Array[Panel] = []

## The lock glyph is built once lazily and toggled via [member
## CanvasItem.visible] — unlike the slots, its shape never depends on
## render() inputs, so it does not need to be rebuilt every call. See
## [method _ensure_lock_glyph] for its current 4-[ColorRect] composition
## (`design/art/battle-ui-glyph-spec.md` 一).
var _lock_glyph: Control = null

## S3's fixed dark backing (`design/art/battle-ui-glyph-spec.md` 三) — built
## once lazily, forced to child index 0. See [method _ensure_backing].
var _backing: ColorRect = null

## Z3's detail panel — built once lazily (see [method _ensure_detail_panel]),
## shown only while [member _expand_progress] > 0. Only ever reads [member
## _card_faces]/[member _slot_kinds]/[member _cursor_index] — never [Card].
var _detail_panel: Panel = null
var _detail_text_label: Label = null
var _detail_effect_label: Label = null

var _slot_kinds: Array[SlotKind] = []
var _max_slots: int = 0
var _availability: Availability = Availability.NORMAL

## Story U-015(強制棄牌 S4)—— 骨架欄位,寫下先於讀 story 之前的最佳猜測,
## 細節待讀完 `story-u015-forced-discard.md` 後修正:
## `design/ux/skill-card-play.md` S4 列明文「Z2 展開,🔴 無法收起」「只能選一張
## 棄掉」「取消鍵在此狀態無效」。**「無法收起」由 battle_screen.gd 的輸入分派
## 保證**(S4 期間不送出會觸發收合的按鍵路徑,同 [enum Availability.LOCKED] 的
## 既有分工:呼叫端決定「能不能」,本檔只負責「畫出來長怎樣」)——本欄位要解決
## 的是另一半:**拒絕須可觀測**(`P-F2`)。玩家必須看得出「這不是我可以隨手關掉
## 的一般選牌畫面」,不能只靠「按了沒反應」讓玩家自己猜。確切呈現方式(文案?
## 邊框?兩者皆有?)待讀 story 的 Implementation Notes 後決定,不在此假設。
var _forced_discard: bool = false

## S1's "游標停在第幾張" — owned entirely by this file (per the work order's
## "hand_bar.gd 只負責『游標停在第幾張』"), never reset by [method render]
## itself except when a fresh S0->S1 expand transition begins (see
## [method render]'s own body) — [method render] runs every frame from the
## caller, so resetting this on every call would make navigation impossible.
var _cursor_index: int = 0

## True from the [param expanded] transition [method render] most recently
## saw flip to [code]true[/code] until it flips back — Z2/Z3's visibility
## gate. See [method render]'s own body for the edge-triggered transition
## logic (this is NOT reset every [method render] call — only on an actual
## change — since [method render] runs every frame).
var _expanded: bool = false

## 0.0 = fully collapsed (Z1 geometry), 1.0 = fully expanded (Z2 geometry).
## Driven only by [member _expand_tween]'s [method _set_expand_progress]
## callback — never written anywhere else, so this is the single source of
## truth [method _apply_layout] reads to interpolate between [method
## slot_bar_rect]/[method slot_rect] and [method expanded_slot_bar_rect]/
## [method expanded_slot_rect].
var _expand_progress: float = 0.0

## The in-flight Z1<->Z2 [Tween], if any — see [method render]'s
## edge-triggered transition logic and [method _start_expand_tween].
var _expand_tween: Tween = null

## Per-card Z2/Z3 display fields from the most recent [method render] call —
## see that method's own [param card_faces] doc for the exact Dictionary
## shape. 🔴 Deliberately [code]Array[Dictionary][/code], never
## [code]Array[Card][/code] — 2026-09-17 `godot-gdscript-specialist` ruling
## (task report): keeping [Card] out of this file preserves the "one class
## (`battle_screen.gd`) knows both sides" boundary this file has held since
## Story U-011, at the cost of the caller building this Dictionary itself.
var _card_faces: Array[Dictionary] = []


func _ready() -> void:
	_ensure_backing()
	_ensure_lock_glyph()
	_ensure_detail_panel()
	_apply_layout()
	get_window().size_changed.connect(_apply_layout)


## Redraws the entire bar from [param slot_kinds] (one entry per card
## currently in hand, in the same order [method CardDeck.hand] returned them),
## [param max_slots] (the caller's [constant CardDeck.HAND_SIZE_LIMIT] — never
## hardcoded here, see the class doc comment on why this file has zero
## [CardDeck] dependency), and [param availability]. Slots
## [code]0..slot_kinds.size()-1[/code] render filled (icon per category);
## the remaining [code]slot_kinds.size()..max_slots-1[/code] render as an
## empty outline — this is S7's definition when [param slot_kinds] is empty
## (AC-U4 前半: "空槽輪廓與 0/5").
##
## [param expanded] (U-012, S1) drives the Z1<->Z2 expand transition —
## defaults to [code]false[/code] so every existing call site (this file's
## own tests, and `battle_screen.gd`'s current U-011 call) keeps compiling
## and behaving exactly as before with zero changes on their end.
## Edge-triggered: a tween only starts when this differs from [member
## _expanded]'s current value, never on every call (this method runs every
## frame from the caller).
##
## [param card_faces] (U-012, Z2/Z3) is one [Dictionary] per entry in
## [param slot_kinds], only consulted while expanded. 🔴 Deliberately
## [code]Array[Dictionary][/code], never [code]Array[Card][/code] — see
## [member _card_faces]'s own doc comment for why. Expected keys per entry
## (all optional — a missing key reads as its shown default, never a
## crash):
## [codeblock]
## {
##   "flavor_text": String,     # full card-face text (name + description).
##                              # default: "" (empty string, not a placeholder).
##   "delta_atk": int,          # 甲類 only. default: 0.
##   "delta_def": int,          # 甲類 only. default: 0.
##   "duration_rounds": int,    # 甲類 only. default: 0.
## }
## [/codeblock]
## Whether a card is 甲類 or 丙類 is read from [param slot_kinds] (already
## known, never duplicated into this dictionary) — a 丙類 entry's
## delta_atk/delta_def/duration_rounds keys are ignored regardless of
## whether the caller populated them, since 丙類 cards carry no duration
## ([code]card.gd[/code]'s own doc comment: "丙類 carries no duration").
## Story U-015 — [param forced_discard] is a placeholder parameter (骨架,
## default [code]false[/code] so every existing call site keeps compiling and
## behaving exactly as before). Intended meaning per
## `design/ux/skill-card-play.md` S4: this bar is in the mandatory-discard
## state (Z2 forced open, no collapse, cancel key inert) — see [member
## _forced_discard]'s own doc comment for what is and is not decided yet.
## 🔴 Wiring TBD after reading the story — this signature/assignment exists so
## the call site in [code]battle_screen.gd[/code] has something real to pass
## once that side is written, not so this file's own S4 visuals are final.
func render(
	slot_kinds: Array[SlotKind],
	max_slots: int,
	availability: Availability,
	expanded: bool = false,
	card_faces: Array[Dictionary] = [],
	forced_discard: bool = false
) -> void:
	_slot_kinds = slot_kinds.duplicate()
	_max_slots = maxi(0, max_slots)
	_availability = availability
	_card_faces = card_faces.duplicate()
	_forced_discard = forced_discard
	_cursor_index = clampi(_cursor_index, 0, maxi(_slot_kinds.size() - 1, 0))

	# Story U-015 — forced_discard structurally implies expanded: Z2 cannot be
	# collapsed while a discard is owed (`States & Variants` S4: "🔴 無法收起"),
	# regardless of what the caller passes for [param expanded] itself. The
	# caller (battle_screen.gd) is expected to never toggle expanded false
	# while this is true, but this guarantees it structurally rather than
	# relying purely on caller discipline — same defense-in-depth judgment
	# this project already applies elsewhere (e.g. registration-result checks
	# after calls that "should never fail").
	var effective_expanded: bool = expanded or forced_discard
	if effective_expanded != _expanded:
		_expanded = effective_expanded
		if effective_expanded:
			_cursor_index = 0
		_start_expand_tween(1.0 if effective_expanded else 0.0)

	_rebuild_slots()
	_count_label.text = count_text(_slot_kinds.size(), _max_slots)
	_count_label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, _current_dim_factor()))
	_unavailable_label.text = TEXT_FORCED_DISCARD if forced_discard else TEXT_UNAVAILABLE
	_ensure_lock_glyph()

	_apply_layout()


## S1's card-browsing navigation (`Interaction Map` step 2: "← → ... 該卡上浮").
## Moves [member _cursor_index] by [param delta] (typically ±1), clamped to
## [code][0, 目前手牌張數 - 1][/code] — no wraparound (this file's own
## placeholder judgment; neither the Interaction Map nor Component Inventory
## specifies wrap behavior for card browsing, unlike AC-U3's explicit
## wraparound requirement for the board target-jump cursor, which is a
## different control entirely). No-op while the hand is not expanded or is
## empty — matches [method diagnostic_is_expanded]'s own scope (this cursor
## is only meaningful during S1).
##
## 🔴 Deliberately has ZERO dependency on [member _expand_progress] or any
## tween state — this is what makes AC-U2's "轉場動畫期間按 ← 立即選到前一張,
## 輸入未被吞掉" true by construction rather than by a race against the
## animation: this method changes [member _cursor_index] synchronously no
## matter what the expand transition is doing.
func move_cursor(delta: int) -> void:
	if not _expanded or _slot_kinds.is_empty():
		return
	_cursor_index = clampi(_cursor_index + delta, 0, _slot_kinds.size() - 1)


# Starts (or redirects, if one is already running) the Z1<->Z2 tween toward
# [param target] (0.0 or 1.0) from [member _expand_progress]'s CURRENT
# value — not from the OLD target — so reversing mid-transition (open then
# immediately close) does not jump.
func _start_expand_tween(target: float) -> void:
	if _expand_tween != null and _expand_tween.is_valid():
		_expand_tween.kill()
	_expand_tween = create_tween()
	_expand_tween.tween_method(_set_expand_progress, _expand_progress, target, EXPAND_TRANSITION_SECONDS)


# The tween's per-step callback — the ONLY writer of [member _expand_progress]
# (see that member's own doc comment). Re-runs [method _apply_layout] every
# step so the interpolated geometry actually redraws each frame, not just at
# the end.
func _set_expand_progress(value: float) -> void:
	_expand_progress = value
	_apply_layout()


# ─── diagnostic_* — headless-testable "decision" surface (陷阱十三) ─────────


## True if slot [param index] is currently rendered filled (has a card) —
## i.e. [code]index < 目前手牌張數[/code]. Out-of-range [param index] (>=
## [method diagnostic_max_slots]) is meaningless and returns false.
func diagnostic_slot_is_filled(index: int) -> bool:
	return index < _slot_kinds.size()


## Number of filled slots — always equal to the [param slot_kinds] array size
## passed to the most recent [method render] call.
func diagnostic_slot_count() -> int:
	return _slot_kinds.size()


## Story U-015 — actual number of [Panel] nodes [method _rebuild_slots] built,
## as opposed to [method diagnostic_slot_count]/[method diagnostic_slot_is_filled]
## (both PURE computations over [member _slot_kinds]/[member _max_slots] that
## say nothing about whether a node was actually created for a given index).
## This is the getter that would have caught the real regression this story
## fixed: before [method _rebuild_slots]'s loop bound became
## [code]maxi(_max_slots, _slot_kinds.size())[/code], a temporarily-overfull
## hand (S4's ONLY trigger condition — GDD Detailed Rules 二: 手牌達 6 張,一律
## [constant CardDeck.HAND_SIZE_LIMIT] + 1) left the 6th card with no [Panel]
## at all — invisible and unselectable via cursor navigation, even though
## [method diagnostic_slot_is_filled(5)] would have (wrongly, for this
## purpose) reported [code]true[/code] the whole time, since that check never
## looked at [member _slot_nodes] in the first place.
func diagnostic_slot_node_count() -> int:
	return _slot_nodes.size()


## The most recent [method render] call's [param max_slots].
func diagnostic_max_slots() -> int:
	return _max_slots


## The most recent [method render] call's [param availability].
func diagnostic_availability() -> Availability:
	return _availability


## Current S1 cursor index — see [member _cursor_index]'s own doc comment.
func diagnostic_cursor_index() -> int:
	return _cursor_index


## True from the [param expanded] transition [method render] most recently
## saw flip true, until it flips back — see [member _expanded]'s own doc
## comment.
## Story U-015 — 骨架 getter,見 [member _forced_discard] 的 doc comment。
## 讀出最近一次 [method render] 呼叫傳入的 [param forced_discard]。
func diagnostic_is_forced_discard() -> bool:
	return _forced_discard


func diagnostic_is_expanded() -> bool:
	return _expanded


## Current Z1<->Z2 tween progress, 0.0 (collapsed) .. 1.0 (fully expanded) —
## see [member _expand_progress]'s own doc comment.
func diagnostic_expand_progress() -> float:
	return _expand_progress


## True while the Z1<->Z2 tween is actively running. Purely structural — it
## does NOT prove the visual result is smooth or reads as "growing"; that is
## a Category C screenshot/manual judgment (`.claude/docs/coding-standards.md`).
func diagnostic_expand_tween_is_running() -> bool:
	return _expand_tween != null and _expand_tween.is_valid() and _expand_tween.is_running()


## True while Z3's detail panel is showing — see [method
## _update_detail_panel_content]'s own doc comment for the exact gate
## ([member _expand_progress] >= 1.0 and at least one card face).
func diagnostic_detail_panel_visible() -> bool:
	return _detail_panel != null and _detail_panel.visible


## Z3's own-text line (`flavor_text`) currently shown, exactly as [method
## _update_detail_panel_content] set it — lets a test assert the panel
## reflects the [param card_faces] entry at [member _cursor_index], not
## merely that SOME text is showing.
func diagnostic_detail_panel_text() -> String:
	return _detail_text_label.text if _detail_text_label != null else ""


## Z3's effect-summary line — either [constant TEXT_PERMANENT_MARK] (丙類) or
## [method _format_temporary_effect_summary]'s output (甲類), depending on
## [member _slot_kinds] at [member _cursor_index].
func diagnostic_detail_effect_text() -> String:
	return _detail_effect_label.text if _detail_effect_label != null else ""


## True while the lock glyph (one of S5's three non-color channels) is
## visible.
func diagnostic_lock_glyph_visible() -> bool:
	return _lock_glyph != null and _lock_glyph.visible


## Number of child [ColorRect]s composing the lock glyph —
## `design/art/battle-ui-glyph-spec.md` 一 requires 4 (body, two shackle
## posts, one shackle cap), replacing the previous 2-rect composition. A
## structural, headless-verifiable stand-in for "does this still read as a
## lock" — actual readability is a Category C screenshot judgment (`.claude/docs/coding-standards.md`),
## not something this getter can prove on its own.
func diagnostic_lock_glyph_child_count() -> int:
	return _lock_glyph.get_child_count() if _lock_glyph != null else 0


## True while [member _unavailable_label]'s caption (a second S5 channel) is
## visible.
func diagnostic_caption_visible() -> bool:
	return _unavailable_label.visible


## Story U-015 — exact text currently shown by [member _unavailable_label].
## Lets a test assert S4's caption specifically says [constant
## TEXT_FORCED_DISCARD], not merely that SOME caption is visible (which S5's
## [constant TEXT_UNAVAILABLE] would also satisfy).
func diagnostic_caption_text() -> String:
	return _unavailable_label.text


## Current dim factor (1.0 normal, [constant LOCKED_DIM_FACTOR] when locked)
## — the third S5 channel ("降對比"), applied directly to element alpha
## rather than [member CanvasItem.modulate] (see [constant LOCKED_DIM_FACTOR]'s
## own doc comment for why).
func diagnostic_dim_factor() -> float:
	return _current_dim_factor()


## Exact text currently shown by the count label — lets a test assert the
## label actually reflects the [param slot_kinds] array [method render] was
## given, not merely that SOME render happened.
func diagnostic_count_label_text() -> String:
	return _count_label.text


# ─── pure static functions — geometry/vocabulary, no node needed ───────────


## Placeholder shape vocabulary for [param kind] — see the class doc comment.
## Distinct return values for the two categories is the whole point this
## function exists to prove (white-box groundwork for U-012's AC-U6, per this
## story's own Test Evidence section).
static func icon_shape_for(kind: SlotKind) -> IconShape:
	match kind:
		SlotKind.PERMANENT_WRITE:
			return IconShape.DIAMOND
		_:
			return IconShape.SQUARE


## Formats the [constant TEXT_COUNT_FORMAT] "n/max" readout.
static func count_text(count: int, max_slots: int) -> String:
	return TEXT_COUNT_FORMAT % [count, max_slots]


## Z1's card-slot rect for [param window_size] at [param max_slots] slots —
## see the class doc comment for why this composes [HudLayout]'s existing
## functions rather than re-deriving any of their math. Horizontally centered
## in [method HudLayout.safe_rect]; bottom edge sits
## [constant BAR_BOTTOM_MARGIN_FPX_MULTIPLIER] fpx above
## [method HudLayout.controls_hint_bg_rect]'s top edge (EPIC.md 陷阱十一).
static func slot_bar_rect(window_size: Vector2i, max_slots: int) -> Rect2:
	var safe: Rect2 = HudLayout.safe_rect(window_size)
	var fpx: float = float(HudLayout.font_size(window_size))
	var hint_bg: Rect2 = HudLayout.controls_hint_bg_rect(window_size)

	var width: float = _slots_total_width_fpx(max_slots) * fpx
	var height: float = SLOT_HEIGHT_FPX_MULTIPLIER * fpx
	var margin: float = BAR_BOTTOM_MARGIN_FPX_MULTIPLIER * fpx

	var left: float = safe.position.x + (safe.size.x - width) / 2.0
	var bottom: float = hint_bg.position.y - margin
	var top: float = bottom - height
	return Rect2(Vector2(left, top), Vector2(width, height))


## Individual slot [param index]'s rect, in the same local space
## [method slot_bar_rect]'s returned rect's top-left corner would map to
## (0,0) — i.e. this is what a caller adds to [method slot_bar_rect]'s
## [code]position[/code] to get a window-space rect, and exactly what
## [method _position_slots] assigns to each slot [Panel]'s own
## [code]position[/code]/[code]size[/code] (which are already relative to
## this control's own top-left, since this control's own [code]position[/code]
## is set from [method slot_bar_rect] in [method _apply_layout]).
static func slot_rect(index: int, window_size: Vector2i) -> Rect2:
	var fpx: float = float(HudLayout.font_size(window_size))
	var slot_w: float = SLOT_WIDTH_FPX_MULTIPLIER * fpx
	var slot_h: float = SLOT_HEIGHT_FPX_MULTIPLIER * fpx
	var gap: float = SLOT_GAP_FPX_MULTIPLIER * fpx
	return Rect2(Vector2(float(index) * (slot_w + gap), 0.0), Vector2(slot_w, slot_h))


## Total slot-row width in fpx multiples for [param max_slots] slots —
## [code]max_slots[/code] card widths plus [code]max_slots - 1[/code] gaps.
## At [param max_slots] = 5 this is exactly 12 fpx, matching the spec's stated
## total ("合計 12 fpx 寬") — but the formula itself is not hardcoded to 5, so
## it stays correct if [constant CardDeck.HAND_SIZE_LIMIT] is ever retuned by
## a future ruling.
static func _slots_total_width_fpx(max_slots: int) -> float:
	if max_slots <= 0:
		return 0.0
	var gap_count: int = max_slots - 1
	return SLOT_WIDTH_FPX_MULTIPLIER * float(max_slots) + SLOT_GAP_FPX_MULTIPLIER * float(gap_count)


## Z2's card-slot rect — same anchor as [method slot_bar_rect] (horizontally
## centered in [method HudLayout.safe_rect], bottom edge pinned the same
## [constant BAR_BOTTOM_MARGIN_FPX_MULTIPLIER] fpx above [method
## HudLayout.controls_hint_bg_rect]'s top edge), sized from [constant
## EXPANDED_SLOT_WIDTH_FPX_MULTIPLIER]/[constant EXPANDED_SLOT_HEIGHT_FPX_MULTIPLIER]
## instead of Z1's — `Layout Zones` Z2 row: "同 Z1 錨點,原地向上長大". Sharing
## the same bottom edge as [method slot_bar_rect] at every [param max_slots]
## is what makes growth read as purely upward, not a jump.
static func expanded_slot_bar_rect(window_size: Vector2i, max_slots: int) -> Rect2:
	var safe: Rect2 = HudLayout.safe_rect(window_size)
	var fpx: float = float(HudLayout.font_size(window_size))
	var hint_bg: Rect2 = HudLayout.controls_hint_bg_rect(window_size)

	var width: float = _expanded_slots_total_width_fpx(max_slots) * fpx
	var height: float = EXPANDED_SLOT_HEIGHT_FPX_MULTIPLIER * fpx
	var margin: float = BAR_BOTTOM_MARGIN_FPX_MULTIPLIER * fpx

	var left: float = safe.position.x + (safe.size.x - width) / 2.0
	var bottom: float = hint_bg.position.y - margin
	var top: float = bottom - height
	return Rect2(Vector2(left, top), Vector2(width, height))


## Individual Z2 slot [param index]'s rect — same local-space convention as
## [method slot_rect] (top-left maps to [method expanded_slot_bar_rect]'s
## own top-left).
static func expanded_slot_rect(index: int, window_size: Vector2i) -> Rect2:
	var fpx: float = float(HudLayout.font_size(window_size))
	var slot_w: float = EXPANDED_SLOT_WIDTH_FPX_MULTIPLIER * fpx
	var slot_h: float = EXPANDED_SLOT_HEIGHT_FPX_MULTIPLIER * fpx
	var gap: float = SLOT_GAP_FPX_MULTIPLIER * fpx
	return Rect2(Vector2(float(index) * (slot_w + gap), 0.0), Vector2(slot_w, slot_h))


## Z2 total width in fpx multiples — mirrors [method _slots_total_width_fpx]
## exactly, using [constant EXPANDED_SLOT_WIDTH_FPX_MULTIPLIER] instead of
## Z1's. At [param max_slots] = 5 this is exactly 24.5 fpx, matching the
## spec's stated total ("合計 24.5 fpx 寬").
static func _expanded_slots_total_width_fpx(max_slots: int) -> float:
	if max_slots <= 0:
		return 0.0
	var gap_count: int = max_slots - 1
	return (
		EXPANDED_SLOT_WIDTH_FPX_MULTIPLIER * float(max_slots)
		+ SLOT_GAP_FPX_MULTIPLIER * float(gap_count)
	)


## Z3's rect for the card currently at [param index], in [method
## expanded_slot_bar_rect]'s local space — directly above that card
## (`Layout Zones` Z3 row: "選定卡的正上方"), exactly as wide as the card
## itself (see [constant DETAIL_PANEL_HEIGHT_FPX_MULTIPLIER]'s own doc
## comment for why "≥" is satisfied with equality here) and [constant
## DETAIL_PANEL_HEIGHT_FPX_MULTIPLIER] tall.
static func detail_panel_rect(index: int, window_size: Vector2i) -> Rect2:
	var card: Rect2 = expanded_slot_rect(index, window_size)
	var fpx: float = float(HudLayout.font_size(window_size))
	var gap: float = DETAIL_PANEL_GAP_FPX_MULTIPLIER * fpx
	var height: float = DETAIL_PANEL_HEIGHT_FPX_MULTIPLIER * fpx
	return Rect2(Vector2(card.position.x, -(gap + height)), Vector2(card.size.x, height))


## Linear interpolation between two [Rect2]s — used by [method _apply_layout]
## / [method _position_slots] to blend Z1<->Z2 geometry by [member
## _expand_progress]. A tiny helper, but centralizing it means the
## interpolation formula for the container rect and each per-slot rect is
## written once, not copy-pasted at each of the (currently 2) call sites.
static func _lerp_rect(a: Rect2, b: Rect2, t: float) -> Rect2:
	return Rect2(a.position.lerp(b.position, t), a.size.lerp(b.size, t))


## [member _backing]'s rect, in the same local space [method slot_rect] and
## [method slot_bar_rect] use (added to [method slot_bar_rect]'s own
## position to get a window-space rect). Covers the slot row + count label
## to the right, AND the caption/lock-glyph row above (negative local Y) —
## `design/art/battle-ui-glyph-spec.md` 三.
##
## 🔴 [b]This does NOT match that section's own literal formula table[/b]
## (which only accounts for the slot+count row: left/top = [code]0 -
## HAND_BAR_BACKING_PADDING_FPX_MULTIPLIER[/code], giving 3.5 fpx tall / 17
## fpx wide at any resolution). It instead reproduces that same section's
## OWN worked N=2 numbers (18.8 fpx wide / 5.3 fpx tall), which require
## extending left/up far enough to cover [member _lock_glyph] and
## [member _unavailable_label] too:
## [codeblock]
## left = -(LOCK_GLYPH_SIZE_FPX_MULTIPLIER + LOCK_GLYPH_GAP_FPX_MULTIPLIER + PADDING) * fpx
## top  = -(CAPTION_GAP_FPX_MULTIPLIER + CAPTION_HEIGHT_FPX_MULTIPLIER + PADDING) * fpx
## [/codeblock]
## 2026-09-17 coordinator-verified resolution (task report): the literal
## table is the error, not the worked example — reproduced independently
## from the section's own already-committed constants
## ([constant SLOT_HEIGHT_FPX_MULTIPLIER], [constant CAPTION_GAP_FPX_MULTIPLIER],
## [constant CAPTION_HEIGHT_FPX_MULTIPLIER], [constant LOCK_GLYPH_SIZE_FPX_MULTIPLIER],
## [constant COUNT_LABEL_WIDTH_FPX_MULTIPLIER], [constant COUNT_LABEL_GAP_FPX_MULTIPLIER]).
## A backing that stopped at the slot row's own top edge would leave the
## lock glyph — which sits ABOVE that edge — without the "predictable dark
## background" 一 says its cutout depends on to read as a cutout rather than
## a stray white patch; the literal table's formula would make 一's own
## fix inert.
static func backing_rect(max_slots: int, window_size: Vector2i) -> Rect2:
	var fpx: float = float(HudLayout.font_size(window_size))
	var padding: float = HAND_BAR_BACKING_PADDING_FPX_MULTIPLIER

	var left: float = -(LOCK_GLYPH_SIZE_FPX_MULTIPLIER + LOCK_GLYPH_GAP_FPX_MULTIPLIER + padding) * fpx
	var top: float = -(CAPTION_GAP_FPX_MULTIPLIER + CAPTION_HEIGHT_FPX_MULTIPLIER + padding) * fpx
	var right: float = (
		_slots_total_width_fpx(max_slots) + COUNT_LABEL_GAP_FPX_MULTIPLIER
		+ COUNT_LABEL_WIDTH_FPX_MULTIPLIER + padding
	) * fpx
	var bottom: float = (SLOT_HEIGHT_FPX_MULTIPLIER + padding) * fpx

	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


# ─── node mutation — never called from a pure/static context ──────────────


# Applies HandBar's own rect ([method slot_bar_rect]) to this Control, then
# repositions every child that depends on window size / _max_slots. Called
# from _ready() (before the first real render(), using whatever _max_slots
# currently is — 0 by default, a harmless zero-width rect since no slot
# children exist yet) and again at the end of every render() call (the point
# _max_slots first becomes a real value, and the point most likely to
# coincide with a resize in a live game).
func _apply_layout() -> void:
	var window_size: Vector2i = get_window().size
	var collapsed_rect: Rect2 = slot_bar_rect(window_size, _max_slots)
	var expanded_rect: Rect2 = expanded_slot_bar_rect(window_size, _max_slots)
	var rect: Rect2 = _lerp_rect(collapsed_rect, expanded_rect, _expand_progress)
	position = rect.position
	size = rect.size

	var fpx: float = float(HudLayout.font_size(window_size))
	_position_slots(window_size, fpx)
	_position_count_label(fpx)
	_position_caption_and_lock_glyph(fpx)
	_position_backing(window_size)
	_position_detail_panel(window_size)
	_update_detail_panel_content()

	# Z1's count label / S5 caption / lock glyph share the collapsed row's
	# local coordinate space, which stops matching the container's own local
	# origin once [member _expand_progress] > 0 (the container has grown
	# past Z1's footprint) — rather than re-deriving THEIR geometry for every
	# intermediate expand state (a spec that does not exist yet, see this
	# story's task report on 問題一/U-012 scope), this file's own disclosed
	# simplification is to hide all three for the duration of the expand
	# transition and beyond. [member _backing] is NOT hidden here — per
	# `design/art/battle-ui-glyph-spec.md` 三's "永遠存在", it keeps its
	# fixed Z1 footprint through every state, expanded or not.
	var mid_or_fully_expanded: bool = _expand_progress > 0.0
	_count_label.visible = not mid_or_fully_expanded

	# Story U-015 (強制棄牌 S4) — the "hide once expanded" simplification above
	# does NOT apply to forced_discard: S4 is expanded BY DEFINITION (see
	# render()'s own effective_expanded computation) and this caption's text
	# IS the "拒絕須可觀測" signal S4 exists to provide
	# (`design/ux/skill-card-play.md` S4 row) — hiding it here would silently
	# defeat that requirement.
	# 🔴 Known placeholder, disclosed rather than fixed: this reuses the
	# COLLAPSED-width caption geometry computed in
	# [method _position_caption_and_lock_glyph] even while the bar is
	# visually at its EXPANDED width — this file has never derived proper
	# caption geometry for the expanded state (see the comment above this
	# block), and this story does not add it either. This story's
	# Integration-type ACs are state/behavior (is the caption visible, does
	# it say the right thing), not pixel placement, and this batch does not
	# screenshot-verify (see this story's own QA evidence for why).
	_unavailable_label.visible = (
		(_availability == Availability.LOCKED and not mid_or_fully_expanded)
		or _forced_discard
	)
	if _lock_glyph != null:
		_lock_glyph.visible = _availability == Availability.LOCKED and not mid_or_fully_expanded


func _position_backing(window_size: Vector2i) -> void:
	if _backing == null:
		return
	var r: Rect2 = backing_rect(_max_slots, window_size)
	_backing.position = r.position
	_backing.size = r.size


# Positions [member _detail_panel] via [method detail_panel_rect]. Only
# meaningful once [member _expand_progress] reaches 1.0 (see
# [method _update_detail_panel_content] for the visibility gate and why
# mid-transition positioning is deliberately not attempted) — computed
# every call regardless so it is already correct the instant it becomes
# visible.
func _position_detail_panel(window_size: Vector2i) -> void:
	if _detail_panel == null:
		return
	var index: int = clampi(_cursor_index, 0, maxi(_slot_kinds.size() - 1, 0))
	var r: Rect2 = detail_panel_rect(index, window_size)
	_detail_panel.position = r.position
	_detail_panel.size = r.size


# Shows/hides and fills [member _detail_panel] from [member _card_faces] at
# [member _cursor_index]. Gated on [member _expand_progress] >= 1.0 rather
# than [member _expanded] alone — this file's own disclosed simplification:
# [method detail_panel_rect] is computed in [method expanded_slot_bar_rect]'s
# local space, which only actually coincides with this control's own
# interpolated local origin once the transition finishes (see
# [method _apply_layout]'s [code]_lerp_rect[/code] call) — showing it
# earlier would place it correctly only at the two endpoints of a lerp, not
# in between.
func _update_detail_panel_content() -> void:
	if _detail_panel == null:
		return
	var showable: bool = _expand_progress >= 1.0 and not _card_faces.is_empty()
	_detail_panel.visible = showable
	if not showable:
		return

	var index: int = clampi(_cursor_index, 0, _card_faces.size() - 1)
	var face: Dictionary = _card_faces[index]
	var is_permanent: bool = (
		index < _slot_kinds.size() and _slot_kinds[index] == SlotKind.PERMANENT_WRITE
	)

	_detail_text_label.text = String(face.get("flavor_text", ""))
	if is_permanent:
		_detail_effect_label.text = TEXT_PERMANENT_MARK
	else:
		_detail_effect_label.text = _format_temporary_effect_summary(
			int(face.get("delta_atk", 0)),
			int(face.get("delta_def", 0)),
			int(face.get("duration_rounds", 0))
		)


# "ATK+3 · DEF+0 · 剩2回合" — both channels always shown, never just the
# non-zero one (a card whose only real effect is DEF must not read as
# "nothing happens to ATK"; matches this project's existing "0 仍顯示"
# convention for signed deltas elsewhere, e.g. the confirm-panel spec).
static func _format_temporary_effect_summary(
	delta_atk: int, delta_def: int, duration_rounds: int
) -> String:
	return "ATK%s · DEF%s · 剩%d回合" % [
		_signed_int_text(delta_atk), _signed_int_text(delta_def), duration_rounds
	]


static func _signed_int_text(value: int) -> String:
	return ("+%d" % value) if value >= 0 else str(value)


func _position_slots(window_size: Vector2i, fpx: float) -> void:
	for i in range(_slot_nodes.size()):
		var panel: Panel = _slot_nodes[i]
		var collapsed: Rect2 = slot_rect(i, window_size)
		var expanded: Rect2 = expanded_slot_rect(i, window_size)
		var r: Rect2 = _lerp_rect(collapsed, expanded, _expand_progress)

		# S1's "該卡上浮" — see [constant CURSOR_LIFT_FPX_MULTIPLIER]'s own
		# doc comment. Scaled by _expand_progress so a still-collapsed Z1
		# card is never lifted.
		if _expanded and i == _cursor_index:
			r.position.y -= CURSOR_LIFT_FPX_MULTIPLIER * fpx * _expand_progress

		panel.position = r.position
		panel.size = r.size
		panel.pivot_offset = panel.size / 2.0

		var filled: bool = i < _slot_kinds.size()
		var is_diamond: bool = filled and icon_shape_for(_slot_kinds[i]) == IconShape.DIAMOND
		panel.rotation_degrees = 45.0 if is_diamond else 0.0

		if panel.get_child_count() > 0:
			var icon_mark: ColorRect = panel.get_child(0)
			var icon_size: float = ICON_MARK_SIZE_FPX_MULTIPLIER * fpx
			var icon_margin: float = ICON_MARK_MARGIN_FPX_MULTIPLIER * fpx
			icon_mark.size = Vector2(icon_size, icon_size)
			icon_mark.position = Vector2(icon_margin, icon_margin)


func _position_count_label(fpx: float) -> void:
	var slots_width: float = _slots_total_width_fpx(_max_slots) * fpx
	var gap: float = COUNT_LABEL_GAP_FPX_MULTIPLIER * fpx
	var slot_h: float = SLOT_HEIGHT_FPX_MULTIPLIER * fpx

	_count_label.position = Vector2(slots_width + gap, 0.0)
	_count_label.size = Vector2(COUNT_LABEL_WIDTH_FPX_MULTIPLIER * fpx, slot_h)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_override(&"font", HUD_FONT)
	_count_label.add_theme_font_size_override(&"font_size", int(fpx))


func _position_caption_and_lock_glyph(fpx: float) -> void:
	var caption_h: float = CAPTION_HEIGHT_FPX_MULTIPLIER * fpx
	var caption_gap: float = CAPTION_GAP_FPX_MULTIPLIER * fpx
	var glyph_size: float = LOCK_GLYPH_SIZE_FPX_MULTIPLIER * fpx
	var glyph_gap: float = LOCK_GLYPH_GAP_FPX_MULTIPLIER * fpx

	var caption_top: float = -(caption_gap + caption_h)
	_unavailable_label.position = Vector2(0.0, caption_top)
	_unavailable_label.size = Vector2(_slots_total_width_fpx(_max_slots) * fpx, caption_h)
	_unavailable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unavailable_label.add_theme_font_override(&"font", HUD_FONT)
	_unavailable_label.add_theme_font_size_override(&"font_size", int(fpx))

	if _lock_glyph != null:
		_lock_glyph.size = Vector2(glyph_size, glyph_size)
		_lock_glyph.position = Vector2(-(glyph_size + glyph_gap), caption_top)


# Clears and rebuilds _slot_nodes for the current _max_slots / _slot_kinds —
# same "one throwaway subtree per render" shape as BoardView's render_*()
# methods. A filled slot gets one ColorRect icon-mark child (index 0); an
# empty slot gets none — that child's presence/absence is itself a third,
# non-color cue separating "empty" from "filled" beyond the border alpha
# difference.
func _rebuild_slots() -> void:
	for panel: Panel in _slot_nodes:
		remove_child(panel)
		panel.free()
	_slot_nodes.clear()

	# Story U-015 — GDD Detailed Rules 二's forced-discard trigger is a hand
	# that just grew PAST _max_slots (`CardDeck.HAND_SIZE_LIMIT`, 5): "回合開始
	# 補牌後手牌達 6 張". Looping only [member _max_slots] times would leave the
	# 6th card with no panel at all — invisible and, worse, unselectable via
	# cursor navigation despite [method move_cursor]'s own clamp already
	# allowing the cursor to reach it (that clamp uses [member _slot_kinds]'s
	# size, not [member _max_slots]). [method slot_rect]/[method
	# expanded_slot_rect] are pure functions of an index with no upper bound
	# of their own, so extending this loop's bound costs nothing beyond the
	# extra node — the temporarily-overfull row simply runs one slot further
	# right than the 5-slot layout was designed for, which is this file's own
	# disclosed placeholder-geometry judgment (see class doc comment), not a
	# new one invented for this story.
	for i in range(maxi(_max_slots, _slot_kinds.size())):
		var panel: Panel = Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override(&"panel", _slot_style(i))
		add_child(panel)
		_slot_nodes.append(panel)

		if i < _slot_kinds.size():
			var icon_mark: ColorRect = ColorRect.new()
			icon_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_mark.color = Color(
				SLOT_OUTLINE_COLOR.r, SLOT_OUTLINE_COLOR.g, SLOT_OUTLINE_COLOR.b,
				FILLED_SLOT_BORDER_ALPHA * _current_dim_factor()
			)
			panel.add_child(icon_mark)


# S5's "降對比" multiplier — see LOCKED_DIM_FACTOR's own doc comment for why
# this is applied to individual element alpha rather than
# CanvasItem.modulate/self_modulate.
func _current_dim_factor() -> float:
	return LOCKED_DIM_FACTOR if _availability == Availability.LOCKED else 1.0


# Outline-only StyleBoxFlat for slot `index` — transparent fill, border alpha
# is the sole difference between a filled and an empty slot's OWN box (the
# icon-mark child is the other, see _rebuild_slots()). Hue never differs
# (SLOT_OUTLINE_COLOR is the same white for every case) — only alpha and,
# for filled slots, the panel's rotation (see _position_slots()). Alpha is
# further scaled by _current_dim_factor() for S5's "降對比" channel.
func _slot_style(index: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(1)
	var filled: bool = index < _slot_kinds.size()
	var base_alpha: float = FILLED_SLOT_BORDER_ALPHA if filled else EMPTY_SLOT_BORDER_ALPHA
	style.border_color = Color(
		SLOT_OUTLINE_COLOR.r, SLOT_OUTLINE_COLOR.g, SLOT_OUTLINE_COLOR.b,
		base_alpha * _current_dim_factor()
	)
	return style


# Builds [member _backing] once (idempotent, mirrors _ensure_lock_glyph()'s
# lazy-build shape below) and forces it to child index 0 —
# `design/art/battle-ui-glyph-spec.md` 三's "必須是 HandBar 最先加入的子節點
# (或明確移到最底層)". Done via move_child() rather than relying on add
# order alone: CountLabel/UnavailableLabel already exist as HandBar.tscn's
# pre-authored children (indices 0/1) by the time _ready() runs, so simply
# appending here would put the backing AFTER them (on top), not before.
func _ensure_backing() -> void:
	if _backing != null:
		return
	var backing: ColorRect = ColorRect.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.color = HAND_BAR_BACKING_COLOR
	add_child(backing)
	move_child(backing, 0)
	_backing = backing


# Builds Z3's detail panel once (idempotent, same lazy-build shape as the
# other _ensure_*() methods). Reuses [constant HAND_BAR_BACKING_COLOR] for
# its own background — this file's own placeholder judgment (not a spec
# number): a bordered box with the same dark fill this file already uses
# elsewhere for "this is the interface's own surface", rather than
# inventing a second background treatment for one more panel.
func _ensure_detail_panel() -> void:
	if _detail_panel != null:
		return
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HAND_BAR_BACKING_COLOR
	style.set_border_width_all(1)
	style.border_color = SLOT_OUTLINE_COLOR
	panel.add_theme_stylebox_override(&"panel", style)

	var text_label: Label = Label.new()
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.anchor_right = 1.0
	text_label.anchor_bottom = 0.6
	panel.add_child(text_label)

	var effect_label: Label = Label.new()
	effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_label.anchor_top = 0.6
	effect_label.anchor_right = 1.0
	effect_label.anchor_bottom = 1.0
	panel.add_child(effect_label)

	add_child(panel)
	_detail_panel = panel
	_detail_text_label = text_label
	_detail_effect_label = effect_label


# Builds the lock glyph once — 4 ColorRects on an 8x8 grid
# (`design/art/battle-ui-glyph-spec.md` 一, 2026-09-17 art-director
# glyph-defect ruling), replacing the previous 2-rect body+shackle
# composition. Idempotent: a second call is a no-op if _lock_glyph already
# exists, since its shape never depends on render() inputs (only its
# .visible toggles, in render()).
#
# The two "shackle post" rects (left/right) plus the "shackle cap" rect
# leave a deliberate 2/8-wide x 3/8-tall gap UNFILLED between them and the
# body below — that gap is the whole point: it is what reads as the lock's
# open loop rather than an anvil-shaped solid block (see the glyph spec's
# "為什麼" section). The gap only reads as a cutout — rather than a stray
# unpainted patch that could be mistaken for whatever the board happens to
# show through it — because [member _backing] (`design/art/battle-ui-glyph-spec.md`
# 三, built by _ensure_backing() before this method ever runs) sits behind
# this whole control with a fixed, predictable dark fill.
func _ensure_lock_glyph() -> void:
	if _lock_glyph != null:
		return
	var root: Control = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false

	var body: ColorRect = _lock_glyph_rect(0.125, 0.875, 0.5, 1.0)
	root.add_child(body)

	var shackle_left_post: ColorRect = _lock_glyph_rect(0.25, 0.375, 0.125, 0.5)
	root.add_child(shackle_left_post)

	var shackle_right_post: ColorRect = _lock_glyph_rect(0.625, 0.75, 0.125, 0.5)
	root.add_child(shackle_right_post)

	var shackle_cap: ColorRect = _lock_glyph_rect(0.25, 0.75, 0.0, 0.125)
	root.add_child(shackle_cap)

	add_child(root)
	_lock_glyph = root


# One of the lock glyph's 4 ColorRects, anchored to the given 8ths-of-own-size
# fractions (`design/art/battle-ui-glyph-spec.md` 一's coordinate table).
# Every rect uses the same [constant SLOT_OUTLINE_COLOR] — the spec adds no
# new hue, only new shapes.
func _lock_glyph_rect(
	anchor_left: float, anchor_right: float, anchor_top: float, anchor_bottom: float
) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = SLOT_OUTLINE_COLOR
	rect.anchor_left = anchor_left
	rect.anchor_right = anchor_right
	rect.anchor_top = anchor_top
	rect.anchor_bottom = anchor_bottom
	return rect
