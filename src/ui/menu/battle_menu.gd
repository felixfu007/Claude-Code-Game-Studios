## Battle menu screen (design/ux/battle-menu.md): M0 mask + M1 panel + M2 item
## rows, using Godot's NATIVE Control focus system — explicitly permitted by
## ADR-0005's AC-60 because this surface is deliberately NOT registered with
## [CursorStateHost] (see that GDD's "焦點視覺" section, transcribed into this
## story's Implementation Notes #4).
##
## [b]Story U-008 (this story) adds[/b]: [method open] / [method close] — the
## open/close gating lifecycle. Opening calls
## [method CursorStateHost.suspend_arbitration] and sets
## [member SceneTree.paused] = [code]true[/code]; closing does the symmetric
## reverse. Both calls happen synchronously inside [method open] / [method
## close] with no animation/await in between (`battle-menu.md`
## Transitions & Animations: "開啟的同一幀就要呼叫暫停裁定,不得等動畫").
## [method open] also implements N5 (拒絕開啟) for the authoritative-write
## case, with the rejection mechanism parameterized so U-015 (forced-discard
## rejection) can plug in its own check + message without touching this
## method's body — see [member authoritative_write_in_progress_check] /
## [member forced_discard_in_progress_check] and [signal open_rejected].
##
## 🔴 [b]Confirm-key decision, made explicitly rather than inherited
## silently[/b] (flagged by this story's dispatch as a decision this file must
## record, not silently continue): the three row [Button]s keep responding to
## Godot's built-in [code]ui_accept[/code] action (native [Button] activation),
## NOT the project's custom [code]battle_confirm[/code] action —
## `design/ux/battle-menu.md`'s Interaction Map lists 確認 as
## "既有 battle_confirm", and today [code]ui_accept[/code] and
## [code]battle_confirm[/code] happen to share identical bindings (Enter / KP
## Enter / Space / gamepad A), so this is harmless right now. The decision to
## keep native [Button] + [code]ui_accept[/code] (rather than intercept
## [code]battle_confirm[/code] and manually trigger the focused row) is made
## because ADR-0005's AC-60 exemption for this screen is specifically an
## exemption to use native focus/activation, and rewiring row activation onto
## a custom action would risk DOUBLE activation per keypress (native
## [Button] still also answers [code]ui_accept[/code] unless overridden) for
## a narrow-scope gating story to take on. [b]Known, accepted risk, not
## fixed here[/b]: if [code]battle_confirm[/code] is ever remapped away from
## [code]ui_accept[/code]'s bindings (accessibility remapping — this
## project's Standard-tier commitment), row selection here would silently
## stop matching the rest of the game's confirm gesture. Flagged for whoever
## builds the remapping system (BM-4), not addressed by this story.
##
## 🔴 [b]Corrected 2026-09-17 (`design/art/battle-ui-glyph-spec.md` 第四節,
## art-director)[/b]: this file used to prefix the focused row's [Button.text]
## with [code]"▸ "[/code] (and an equal-width blank filler otherwise) as a
## second, non-color focus channel for `P-F3`. That mechanism is REMOVED —
## the glyph spec traced the reported "focus text jumps sideways" defect to
## [code]▸[/code] (U+25B8) very likely falling outside Cubic 11's covered
## character set, so the engine substitutes a fallback font for that one
## glyph whose rendered width is not guaranteed to match Cubic 11's own
## space width; since [Button] centers its text, that width mismatch shifted
## the whole row's visual center every time focus moved. Row text is now
## fixed for life once [method _ready] reads it — never rewritten — and
## `P-F3`'s required second channel is instead a dedicated [code]"focus"[/code]
## theme [StyleBoxFlat] (border + faint fill) added ON TOP OF whatever
## normal/hover/pressed styling [Button] already has, applied in [method
## _apply_layout] (scales with [code]fpx[/code], same convention as every
## other per-resolution constant in this file) rather than per focus-event —
## see [constant FOCUS_BORDER_COLOR] / [constant FOCUS_FILL_COLOR] and the
## spec's own "為什麼是這個答案" section for why an outline-only channel is
## the more STABLE half of the two (native focus outline geometry does not
## depend on a fallback font's metrics the way rewritten text did).
##
## [b]Story U-007 scope only[/b] — per that story's own "Out of Scope" section,
## this file does NOT (yet):
## - wire the "結束回合" row's real enable/disable judgement to
##   [code]BattleController.phase() / is_card_play_in_progress()[/code] (U-009 —
##   AC-M5), so that row is unconditionally enabled today
## - build M4 (leave-confirmation) itself (U-010) — only its SIZE arithmetic is
##   verified here (see [method leave_confirm_size]), because Implementation
##   Notes #2 requires that verification regardless of M4's build status
## - get instantiated anywhere in [code]BattleScreen.tscn[/code], or respond to
##   the [code]battle_menu[/code] / [code]battle_cancel[/code] actions itself
##   — this scene is a standalone, not-yet-wired-in deliverable. This story's
##   file-scope is [code]battle_menu.gd[/code] only (dispatch brief: do not
##   touch [code]battle_screen.gd[/code]), so the actual "M / Start opens
##   this" wiring is deferred to whichever future story instantiates this
##   scene into the real battle screen.
##
## [b]Layout math is single-sourced[/b]: every size below is expressed as a
## multiple of [method HudLayout.font_size] anchored to [method HudLayout.safe_rect]
## — this class does NOT re-derive either formula (this project's registered
## failure pattern: "same formula reimplemented twice, agreeing only today").
## The multipliers themselves (10/9/2/14/7 fpx) are [b]battle-menu.md[/b]'s own
## Layout Zones table values, transcribed as named constants so the persistent
## regression test in [code]tests/unit/ui/menu/battle_menu_layout_test.gd[/code]
## can assert against the same table without hand-copying magic numbers twice.
##
## [b]M0 mask coverage is anchor-driven, not computed[/b]: [code]Mask[/code]'s
## anchors are FULL_RECT (0,0,1,1) with zero offsets, so it always covers this
## Control's own rect by construction — and this Control itself is expected to
## be placed FULL_RECT under whatever hosts it (a CanvasLayer at native 1:1
## window space, per `design/art/screen-architecture.md`'s "介面設計基準畫布 =
## 當下螢幕實際解析度" ruling). There is deliberately no "mask_rect()" static
## function to test against — the anchor system already guarantees the
## invariant; a duplicate helper nobody consults would just be decoration.
##
## [b]Internal panel padding / divider thickness are THIS FILE's own
## placeholder choices[/b], not numbers battle-menu.md wrote down — visual
## style (BM-7: 遮罩透明度、面板邊框、焦點標記形狀、分隔線) is explicitly
## unowned pending `art-director` + `/art-bible`. Only the OUTER M1 panel size
## (10x9 fpx) and each M2 row's height (2 fpx) are spec-mandated and therefore
## regression-tested; the margin/separation/divider-thickness constants below
## exist only so the three rows + divider fit inside that mandated outer size
## without overflowing, same category of judgement call this project's own
## [code]hud_layout.gd[/code] already documents for [code]controls_hint_bg_rect[/code]
## ("This is a deliberate call, flagged in the task report, not a number the
## spec wrote down").
##
## [b]Up/down "does not wrap" is a verified engine measurement, not an
## assumption[/b] — `design/ux/battle-menu.md` Implementation Notes #3
## explicitly warns "focus_mode 的實際行為本專案從未量測過". Confirmed against
## the real Godot 4.7.1 engine (headless) in
## `prototypes/u007-focus-navigation-probe-2026-09-17/` (see that directory's
## README for the three claims and why v1's structure had to be corrected in
## v2/v3): automatic geometric focus-neighbor search already does not wrap
## (Claim 1), and this file additionally wires an EXPLICIT self-pointing
## [member Control.focus_neighbor_top] / [member Control.focus_neighbor_bottom]
## on the two boundary rows (Claim 2) as a defensive, self-documenting
## guarantee that does not depend on the automatic search continuing to behave
## this way if the surrounding layout changes later (e.g. a footer node added
## below [code]QuitRow[/code] at some future point).
class_name BattleMenu
extends Control

## M1 panel width, in multiples of [method HudLayout.font_size] — battle-menu.md
## Layout Zones table: "M1 選單面板 | ... | 寬 10 fpx,高 9 fpx".
const PANEL_WIDTH_FPX_MULTIPLIER: float = 10.0
## M1 panel height, same table row.
const PANEL_HEIGHT_FPX_MULTIPLIER: float = 9.0
## M2 each row's height — battle-menu.md Layout Zones table: "M2 項目列 | ... | 每列高 2 fpx".
const ROW_HEIGHT_FPX_MULTIPLIER: float = 2.0
## M4 (leave-confirmation) width — SIZE ONLY, M4 itself is out of scope (U-010).
## Exists so Implementation Notes #2's table-verification obligation can call
## the SAME multiplier the eventual M4 implementation will use, rather than
## the test re-deriving it independently. battle-menu.md: "M4 離開確認 | ... | 寬 14 fpx,高 7 fpx".
const LEAVE_CONFIRM_WIDTH_FPX_MULTIPLIER: float = 14.0
## M4 height — SIZE ONLY, see above.
const LEAVE_CONFIRM_HEIGHT_FPX_MULTIPLIER: float = 7.0

## Placeholder internal spacing (this file's own judgement call, not a spec
## number — see class doc comment). Outer margin on all four sides of the
## panel's content area, in multiples of fpx.
const CONTENT_MARGIN_FPX_MULTIPLIER: float = 0.5
## Placeholder gap between consecutive rows/divider, in multiples of fpx.
const ROW_SEPARATION_FPX_MULTIPLIER: float = 0.25
## Placeholder divider thickness, in multiples of fpx.
const DIVIDER_HEIGHT_FPX_MULTIPLIER: float = 0.3

## Placeholder mask darkening — BM-7 (遮罩透明度) is explicitly unowned;
## this is a reasonable interim value, not a design-authored one.
const MASK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
## Placeholder panel background — same caveat as above.
const PANEL_BG_COLOR: Color = Color(0.10, 0.10, 0.12, 0.92)
## Placeholder divider color — same caveat as above.
const DIVIDER_COLOR: Color = Color(0.5, 0.5, 0.5, 0.8)

const HUD_FONT: FontFile = preload("res://assets/fonts/Cubic_11.ttf")

## Focus indicator border width, in multiples of fpx —
## `design/art/battle-ui-glyph-spec.md` 第四節: "邊框寬度 | round(0.1 × fpx) px,
## 最小 1px". Applied only to each row [Button]'s [code]"focus"[/code] theme
## slot (see [method _focus_stylebox]) — `P-F3`'s required second,
## non-color focus channel, replacing the removed [code]▸[/code] text-prefix
## mechanism (see class doc comment's 2026-09-17 correction).
const FOCUS_BORDER_FPX_MULTIPLIER: float = 0.1
## Focus indicator border color — same spec section: "純白,不透明". Reuses
## `hand_bar.gd`'s existing [code]SLOT_OUTLINE_COLOR[/code] white, not a new hue.
const FOCUS_BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
## Focus indicator fill color — same spec section: "純白,10% 不透明". Same hue
## as the border, different alpha only — gives the focused row visible "weight"
## rather than a bare outline.
const FOCUS_FILL_COLOR: Color = Color(1.0, 1.0, 1.0, 0.10)

## Result of calling [method open] — States & Variants N1/N2/N3 collapse to
## [constant OPENED] at this layer (N2/N3's "結束回合不可選" is a per-row
## enable/disable concern, U-009's job, orthogonal to whether the MENU itself
## opened). The two rejection members correspond to N5's two causes, kept
## distinguishable per Implementation Note #5's requirement — a caller (or
## test) can branch on this without parsing [signal open_rejected]'s message
## text.
enum OpenResult {
	OPENED,                        ## Menu opened; suspend/pause/focus applied.
	REJECTED_AUTHORITATIVE_WRITE,  ## N5 cause 1 — see [member authoritative_write_in_progress_check].
	REJECTED_FORCED_DISCARD,       ## N5 cause 2 — see [member forced_discard_in_progress_check].
	                               ## 🔴 Mechanism only — this story does not wire a real check
	                               ## (U-015's job; see this file's class doc comment and
	                               ## story-u008-battle-menu-gating.md's "Out of Scope").
}

## Placeholder N5 rejection copy for the authoritative-write cause. `design/ux/battle-menu.md`
## N5 requires only that the TWO rejection appearances be distinguishable from
## each other, not that this specific cause spell out a reason (unlike the
## forced-discard cause below, which N5 explicitly requires to "明說原因").
## 🔴 Final player-facing visual/copy is BM-7 (視覺樣式全部未定), unowned
## pending `art-director` — same placeholder-pending-design status as
## [constant MASK_COLOR] / [constant PANEL_BG_COLOR] above. This string is a
## non-empty, non-generic placeholder ONLY so it is provably distinguishable
## from [constant REJECTION_MESSAGE_FORCED_DISCARD] today (see
## [code]test_rejection_appearance_differs_between_authoritative_write_and_forced_discard[/code]),
## not a copy decision.
const REJECTION_MESSAGE_AUTHORITATIVE_WRITE: String = "（權威寫入進行中，暫時無法開啟選單）"

## Placeholder N5 rejection copy for the forced-discard cause (U-015's future
## real trigger — see [member forced_discard_in_progress_check]).
## `design/ux/battle-menu.md` N5 explicitly requires this cause to "明說原因"
## with text along the lines of "請先完成棄牌" — used verbatim here as the
## design doc's own example text, not this file's invention. Same
## BM-7-pending caveat as the constant above.
const REJECTION_MESSAGE_FORCED_DISCARD: String = "請先完成棄牌"

## Emitted whenever [method open] is rejected (N5) — never emitted on a
## successful open. Two separate payloads on purpose, mirroring this
## project's established "never merge two semantically different signals
## into one" convention (see e.g. [code]cursor_state.gd[/code]'s own
## documented reasoning for keeping [method CursorState.is_current_target_valid]
## and [method CursorState.get_device_authority] as two separate queries
## rather than one merged boolean): [param result] is for a caller that
## branches programmatically, [param message] is for a caller that just wants
## to render text — neither needs to derive its answer from the other.
signal open_rejected(result: OpenResult, message: String)

## Injected — [code]func() -> bool[/code], "is an authoritative write in
## progress right now". Mirrors [code]CardPlaySession._authoritative_write_in_progress_check[/code]'s
## established idiom exactly (see that class's doc comment,
## [code]src/gameplay/cards/card_play_session.gd[/code]): an unset
## [Callable] (the default) means "never blocked". This project's
## [code]BattleState.authoritative_write_in_progress[/code] has zero
## implementation anywhere in [code]src/[/code] as of this writing — verified
## [code]grep -rn "authoritative_write_in_progress" src/ --include=*.gd[/code]
## returns only doc-comment mentions (in [code]battle_state.gd[/code] and
## [code]card_play_session.gd[/code]), never a real field or method. AC-M8 can
## therefore only prove "the gate is wired and observably rejects", not "the
## real flag can become true" — see this story's report and EPIC.md's
## registered Limitation #1.
var authoritative_write_in_progress_check: Callable = Callable()

## Injected — [code]func() -> bool[/code], "is a forced discard owed right
## now". Same unset-means-never-blocked idiom as above. 🔴 Unlike the field
## above, a REAL implementation of this predicate already exists
## ([method BattleController.has_pending_discard]) — but wiring it in here is
## explicitly U-015's job (story-u008-battle-menu-gating.md's "Out of Scope"
## section: "本 story 只交付『權威寫入進行中』這一種拒絕情境的完整驗證"), not
## this story's. This field exists purely so U-015 only has to inject the
## real [Callable] at whatever call site constructs/wires this scene — it
## does not need to touch [method open]'s body, [enum OpenResult], or
## [signal open_rejected] at all.
var forced_discard_in_progress_check: Callable = Callable()

@onready var _mask: ColorRect = $Mask
@onready var _panel: PanelContainer = $Panel
@onready var _content_margin: MarginContainer = $Panel/ContentMargin
@onready var _rows: VBoxContainer = $Panel/ContentMargin/Rows
@onready var _return_row: Button = $Panel/ContentMargin/Rows/ReturnToBattleRow
@onready var _end_phase_row: Button = $Panel/ContentMargin/Rows/EndPhaseRow
@onready var _divider: ColorRect = $Panel/ContentMargin/Rows/Divider
@onready var _quit_row: Button = $Panel/ContentMargin/Rows/QuitRow

## The three focusable rows, captured once at [method _ready] purely as an
## iteration convenience for [method _apply_layout] (and, previously, for the
## now-removed focus-marker text rewrite — see class doc comment's
## 2026-09-17 correction). 🔴 Row TEXT itself is fixed for life once
## [method _ready] returns — never rewritten again by anything in this file.
var _focusable_rows: Array[Button] = []


func _ready() -> void:
	_focusable_rows = [_return_row, _end_phase_row, _quit_row]

	for row: Button in _focusable_rows:
		row.focus_mode = Control.FOCUS_ALL

	_divider.focus_mode = Control.FOCUS_NONE

	# 🔴 Corrected during this story's own test-writing pass (not assumed up
	# front): ALL row-to-row transitions are wired EXPLICITLY here, not left to
	# Godot's automatic geometric focus-neighbor search — even the "normal"
	# (non-boundary) transitions this project initially expected to rely on
	# automatic search for. Reason, discovered empirically while writing
	# `tests/unit/ui/menu/battle_menu_layout_test.gd`'s down-navigation test:
	# immediately after this Control enters the tree (the same frame
	# [method _ready] runs), [VBoxContainer]'s child layout pass has NOT run
	# yet — every row's [method Control.get_rect] reads (0,0,0,0) until at
	# least one process frame has elapsed (measured directly: a throwaway
	# probe printed [P: (0,0), S: (0,0)] for all three rows immediately after
	# [method Node.add_child], and real, distinct positions only after 3
	# awaited [signal SceneTree.process_frame] cycles). Automatic geometric
	# search depends on real geometry, so a player who navigates before that
	# first layout pass completes could hit a genuine "down does nothing"
	# defect in production, not just a test-timing artifact — this is why the
	# fix is here, not just "await more frames in the test". Explicit
	# NodePath wiring has no such dependency: it is resolved once, by name,
	# regardless of whether any layout pass has run.
	#
	# battle-menu.md Implementation Notes #3's second decision ("到底停住")
	# only requires the top/bottom BOUNDARY behavior (AC-M13 tests the top
	# edge only); wiring the two INTERIOR transitions explicitly as well is
	# this file's own extension, made for the layout-timing reason above, not
	# a design-mandated requirement.
	_return_row.focus_neighbor_top = _return_row.get_path_to(_return_row)
	_return_row.focus_neighbor_bottom = _return_row.get_path_to(_end_phase_row)
	_end_phase_row.focus_neighbor_top = _end_phase_row.get_path_to(_return_row)
	_end_phase_row.focus_neighbor_bottom = _end_phase_row.get_path_to(_quit_row)
	_quit_row.focus_neighbor_top = _quit_row.get_path_to(_end_phase_row)
	_quit_row.focus_neighbor_bottom = _quit_row.get_path_to(_quit_row)

	_apply_layout()
	get_window().size_changed.connect(_apply_layout)

	# AC-M13's GIVEN precondition ("焦點在「回到遊戲」(第一列)") — default
	# focus per battle-menu.md Component Inventory: "「回到遊戲」列 | ... | ✅ 預設焦點".
	_return_row.grab_focus()

	# Story U-008: "回到遊戲" is one of only three documented ways to leave the
	# menu (`battle-menu.md`'s "離開" table: battle_cancel / re-press
	# battle_menu / select this row) — wiring its activation to close() is
	# this story's own natural completion of a button U-007 built but left
	# unconnected. The other two rows (EndPhaseRow / QuitRow) are deliberately
	# left UNconnected — U-009 / U-010's jobs respectively, not this story's.
	_return_row.pressed.connect(close)


## Story U-008 (ADR-0005 機制九, `battle-menu.md`'s "① 開啟時須呼叫
## suspend_arbitration()" + "③ 開啟時須設定 SceneTree.paused = true"). Implements
## N1/N2/N3 (opens normally) and N5's authoritative-write half (rejects
## observably, without opening).
##
## [b]Rejection checks run BEFORE any state changes[/b] — a caller/test that
## receives [constant OpenResult.REJECTED_AUTHORITATIVE_WRITE] or
## [constant OpenResult.REJECTED_FORCED_DISCARD] back is guaranteed nothing
## about this menu (visibility, [member SceneTree.paused], cursor
## arbitration) moved at all; the reject-then-open ordering also matches
## [method CardPlaySession.open_hand]'s established shape (check the injected
## predicate synchronously before flipping any state).
##
## [b]On success, every side effect happens in this same call, synchronously
## — no animation, no [code]await[/code][/b] (`battle-menu.md` Transitions &
## Animations: "不得阻塞輸入;且開啟的同一幀就要呼叫暫停裁定,不得等動畫"):
## becomes visible, pauses the tree, suspends cursor arbitration, and resets
## focus to [member _return_row] (Component Inventory's declared default —
## reset on EVERY open, not merely the first, matching "習慣動作不看畫面":
## whatever row focus was on when the menu was last closed must not leak into
## the next opening).
func open() -> OpenResult:
	if authoritative_write_in_progress_check.is_valid() and bool(authoritative_write_in_progress_check.call()):
		open_rejected.emit(OpenResult.REJECTED_AUTHORITATIVE_WRITE, REJECTION_MESSAGE_AUTHORITATIVE_WRITE)
		return OpenResult.REJECTED_AUTHORITATIVE_WRITE
	if forced_discard_in_progress_check.is_valid() and bool(forced_discard_in_progress_check.call()):
		open_rejected.emit(OpenResult.REJECTED_FORCED_DISCARD, REJECTION_MESSAGE_FORCED_DISCARD)
		return OpenResult.REJECTED_FORCED_DISCARD

	visible = true
	get_tree().paused = true
	CursorStateHost.suspend_arbitration()
	_return_row.grab_focus()
	return OpenResult.OPENED


## Story U-008. Symmetric reverse of a successful [method open] — same
## synchronous, no-animation requirement (`battle-menu.md`: "恢復裁定同樣在
## 同一幀,不得等動畫播完"). [b]Idempotent[/b]: calling this while already
## closed is harmless (re-sets the same values, calls
## [method CursorStateHost.resume_arbitration] again) — this file does not
## guard against a redundant call, matching [method CursorStateHost.resume_arbitration]'s
## own tolerance for being called from more than one path (機制九's
## [code]_notification[/code] FOCUS_IN branch has the identical shape).
##
## 🔴 [b]Never touches board/gameplay state[/b] (AC-M9) — this method's body
## is exactly these three lines; it does not reference [BattleState],
## [BattleController], or [CursorState]'s target at all. Preservation of the
## board's current selection is therefore structural, not a separate check
## this method performs: [method CursorStateHost.suspend_arbitration] /
## [method CursorStateHost.resume_arbitration] are themselves documented as
## never touching device authority or the cursor target (see their own doc
## comments in [code]cursor_state_host.gd[/code]) — this method's only job is
## calling them, not re-deriving that guarantee.
func close() -> void:
	visible = false
	get_tree().paused = false
	CursorStateHost.resume_arbitration()


## Whether the menu is currently open (N1/N2/N3/N4 collapse to
## [code]true[/code]; N0 is [code]false[/code]) — equivalent to
## [member Control.visible] today (this class uses visibility as its
## open/closed signal; see [method open] / [method close]), exposed as a
## named query so callers do not need to know that implementation detail.
func is_open() -> bool:
	return visible


func _apply_layout() -> void:
	var window_size: Vector2i = get_window().size
	var fpx: float = float(HudLayout.font_size(window_size))

	_mask.color = MASK_COLOR

	var panel_r: Rect2 = panel_rect(window_size)
	_panel.offset_left = panel_r.position.x
	_panel.offset_top = panel_r.position.y
	_panel.offset_right = panel_r.end.x
	_panel.offset_bottom = panel_r.end.y
	_panel.add_theme_stylebox_override(&"panel", _panel_stylebox())

	var content_margin_px: int = int(fpx * CONTENT_MARGIN_FPX_MULTIPLIER)
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_content_margin.add_theme_constant_override(side, content_margin_px)

	_rows.add_theme_constant_override(&"separation", int(fpx * ROW_SEPARATION_FPX_MULTIPLIER))

	var row_h: float = row_height(window_size)
	var focus_style: StyleBoxFlat = _focus_stylebox(fpx)
	for row: Button in _focusable_rows:
		row.custom_minimum_size = Vector2(0, row_h)
		row.add_theme_font_override(&"font", HUD_FONT)
		row.add_theme_font_size_override(&"font_size", int(fpx))
		# `P-F3`'s required second, non-color focus channel (design/art/
		# battle-ui-glyph-spec.md 第四節) — applied to the "focus" slot only;
		# normal/hover/pressed stay at the engine default, untouched.
		row.add_theme_stylebox_override(&"focus", focus_style)

	_divider.color = DIVIDER_COLOR
	_divider.custom_minimum_size = Vector2(0, fpx * DIVIDER_HEIGHT_FPX_MULTIPLIER)


func _panel_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG_COLOR
	return style


## Row focus indicator — `design/art/battle-ui-glyph-spec.md` 第四節's
## replacement for the removed [code]▸[/code] text-prefix mechanism (see class
## doc comment). Border width scales with [param fpx] (minimum 1px so it never
## rounds away to nothing at the smallest supported window); fill is the same
## hue at a much lower alpha, giving the focused row visible "weight" rather
## than a bare 1px outline.
func _focus_stylebox(fpx: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FOCUS_FILL_COLOR
	var border_px: int = maxi(1, int(round(FOCUS_BORDER_FPX_MULTIPLIER * fpx)))
	style.border_width_left = border_px
	style.border_width_top = border_px
	style.border_width_right = border_px
	style.border_width_bottom = border_px
	style.border_color = FOCUS_BORDER_COLOR
	return style


## M1 panel rect in window-pixel space (top-left anchored, matching
## [HudLayout]'s established convention for four of its five nodes — see that
## class's own doc comment). Centered within [method HudLayout.safe_rect].
static func panel_rect(window_size: Vector2i) -> Rect2:
	var fpx: float = float(HudLayout.font_size(window_size))
	var safe: Rect2 = HudLayout.safe_rect(window_size)
	var size: Vector2 = Vector2(fpx * PANEL_WIDTH_FPX_MULTIPLIER, fpx * PANEL_HEIGHT_FPX_MULTIPLIER)
	var pos: Vector2 = safe.position + (safe.size - size) / 2.0
	return Rect2(pos, size)


## Each M2 row's height in window pixels.
static func row_height(window_size: Vector2i) -> float:
	return float(HudLayout.font_size(window_size)) * ROW_HEIGHT_FPX_MULTIPLIER


## M4 (leave-confirmation) SIZE ONLY — see class doc comment for why M4 itself
## is not built by this story.
static func leave_confirm_size(window_size: Vector2i) -> Vector2:
	var fpx: float = float(HudLayout.font_size(window_size))
	return Vector2(fpx * LEAVE_CONFIRM_WIDTH_FPX_MULTIPLIER, fpx * LEAVE_CONFIRM_HEIGHT_FPX_MULTIPLIER)
