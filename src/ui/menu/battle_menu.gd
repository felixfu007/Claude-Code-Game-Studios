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
## [b]Story U-009 (this story) adds[/b]: the "結束回合" row's real enable/
## disable judgement (AC-M4/AC-M5/AC-M12), wired to the injected [member
## controller] and re-evaluated every frame the menu is visible (see [method
## can_end_faction_phase] / [method end_faction_phase_disabled_reason] /
## [method _refresh_end_phase_row] / [method _process]), and the row's press
## handler (see [method _on_end_phase_row_pressed] for the ADR-0001 write path
## and why it deliberately stops short of draining the enemy phase itself).
##
## [b]Story U-010 (this story) adds[/b]: M4 (離開確認) itself — [method
## open_leave_confirm] / [method close_leave_confirm] / [method
## is_leave_confirm_open] / [method _on_leave_confirmed_pressed] / [method
## leave_confirm_rect], wired to [member _quit_row]'s previously-unconnected
## [signal BaseButton.pressed] (U-007/U-008/U-009 all explicitly left this row
## unconnected — see the "Still Story U-007/U-008 scope" note this paragraph
## replaces below), plus [member quit_callable] / [method
## diagnostic_would_call_real_quit] for the one irreversible action this
## whole file performs, and [method _unhandled_input] for the
## [code]battle_cancel[/code]-closes-M4-only path (`design/ux/battle-menu.md`
## Implementation Note #7). [method leave_confirm_size]'s SIZE arithmetic was
## already verified by U-007 before M4 existed; this story only added the
## POSITION half.
##
## [b]Still Story U-007/U-008 scope, unchanged by this story[/b] — per those
## stories' own "Out of Scope" sections, this file does NOT (yet):
## - get instantiated anywhere in [code]BattleScreen.tscn[/code], or respond to
##   the [code]battle_menu[/code] / [code]battle_cancel[/code] actions ITSELF
##   at the top level (opening/closing the WHOLE menu) — this scene is a
##   standalone, not-yet-wired-in deliverable. This story's file-scope is
##   [code]battle_menu.gd[/code] (+ its companion [code]BattleMenu.tscn[/code])
##   only (dispatch brief: do not touch [code]battle_screen.gd[/code] /
##   [code]board_view.gd[/code]), so the actual "M / Start opens this" wiring
##   — and draining the enemy phase after [signal end_faction_phase_confirmed]
##   fires — is deferred to whichever future story instantiates this scene
##   into the real battle screen (BM-1 in `battle-menu.md`'s Open Questions is
##   still unresolved on whether/how that wiring happens at all). Note this is
##   narrower than it used to read: [method _unhandled_input] DOES now handle
##   [code]battle_cancel[/code], but ONLY to close M4 back to M1 — never to
##   close the whole menu, which remains exactly as unwired as before.
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

## Story U-010 — M4 title, `design/ux/battle-menu.md`'s own wireframe wording,
## verbatim (not this file's invention).
const LEAVE_CONFIRM_TITLE: String = "離開遊戲?"

## Story U-010 — M4 body, `design/ux/battle-menu.md` Implementation Notes #3's
## own literal wording, verbatim: AC-M7 requires the consequence be spelled
## out ("進度會消失"), not a generic "確定要離開嗎?".
const LEAVE_CONFIRM_BODY: String = "目前沒有存檔功能,離開後這場\n戰鬥的進度會消失。"

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

## Story U-009 (AC-M4/AC-M5/AC-M12) — the battle this menu is wired to, or
## [code]null[/code] before anything injects one. Unlike [member
## authoritative_write_in_progress_check] / [member forced_discard_in_progress_check]
## above (narrow single-predicate [Callable]s), this is a direct reference —
## `design/ux/battle-menu.md`'s Data Requirements table names
## [code]BattleController.phase()[/code] / [code]is_card_play_in_progress()[/code] /
## [code]has_pending_discard()[/code] as three EXISTING queries this screen
## must read, not one this screen invents, so there is nothing to wrap in a
## fresh [Callable] the way the two N5 checks above are (those two guard a
## flag that has no [BattleController] method of its own at all).
##
## 🔴 [b]Deliberately a plain public field, not a property setter[/b] — this
## file's own established idiom (see [member authoritative_write_in_progress_check]'s
## doc comment: "an unset Callable ... means never blocked") already uses bare
## injectable fields rather than setters anywhere a caller wires this scene,
## and [method _refresh_end_phase_row] is idempotent and safe to call as many
## times as needed (see [method _process] / [method open] below), so no
## setter-triggered side effect is required for correctness.
##
## Left [code]null[/code] means "unconditionally enabled, no reason text" —
## the exact behavior this row had before this story (U-007/U-008's own class
## doc comment: "that row is unconditionally enabled today"), which keeps
## every pre-existing test in [code]battle_menu_layout_test.gd[/code] /
## [code]battle_menu_gating_test.gd[/code] (none of which inject a controller)
## passing unchanged.
var controller: BattleController = null

## Story U-010 — injected [code]func() -> void[/code], called when the player
## CONFIRMS leaving from M4 (pressing "離開"). 🔴 [b]THIS FIELD'S UNSET
## MEANING IS THE OPPOSITE OF EVERY OTHER INJECTABLE [Callable] IN THIS
## FILE.[/b] [member authoritative_write_in_progress_check] and
## [member forced_discard_in_progress_check] above both use "unset means
## NEVER blocked" (a safe, inert default). This field's unset default is NOT
## inert: it means "call the REAL, irreversible [method SceneTree.quit]".
## That asymmetry is deliberate, not an oversight — a leave button wired to
## silently do nothing in production would be a worse defect than a test
## forgetting to inject a stub (fail-loud beats fail-silent for the one
## action in this whole file that cannot be undone) — but a reader who
## pattern-matches this field against the two above WILL guess wrong, and the
## wrong guess costs a live engine process mid test-run, not a wrong pixel.
## 🔴 [b]Every test that presses [member _leave_quit_button] MUST inject a
## stub here first[/b] — see [method diagnostic_would_call_real_quit] for how
## "falls back to real quit when unset" is proven WITHOUT ever calling it,
## and `tests/integration/ui/menu/battle_menu_leave_confirmation_test.gd`'s
## own test pinning this asymmetry as intentional.
var quit_callable: Callable = Callable()

## Story U-010 — read-only, side-effect-free: lets a test assert which branch
## [method _on_leave_confirmed_pressed] WOULD take without ever calling it.
## Mirrors `coding-standards.md`'s "What NOT to Automate" split (assert the
## component's DECISION headless via a diagnostic getter; the engine's real
## APPLICATION is left to a manual/windowed run) — doubly so here, since the
## real application is [method SceneTree.quit], which is fatal to the test
## process itself if actually invoked.
func diagnostic_would_call_real_quit() -> bool:
	return not quit_callable.is_valid()

## Placeholder M3 reason-text color — BM-7 (視覺樣式全部未定) is explicitly
## unowned pending `art-director`, same caveat as [constant MASK_COLOR] /
## [constant PANEL_BG_COLOR] / [constant DIVIDER_COLOR] above.
const REASON_TEXT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)

## M3 font-size multiplier — `design/ux/battle-menu.md` Layout Zones table:
## "M3 不可選原因 | ... | 一行,0.7 fpx 字級".
const REASON_FONT_FPX_MULTIPLIER: float = 0.7

## `design/ux/battle-menu.md`'s wireframe concrete wording for the
## card-play-in-progress cause (N2): the literal string drawn in the "打牌流程
## 進行中開啟" ASCII mockup ("結束回合 ✕ 請先完成或取消打牌"). Used verbatim,
## not this file's invention.
const REASON_CARD_PLAY_IN_PROGRESS: String = "請先完成或取消打牌"

## N3's cause has no wireframe wording in `battle-menu.md` (BM-3: this state's
## very existence is unmeasured — "N3 的存在與否尚未量測"), so this is a
## reasonable interim placeholder in the same category as [constant
## REJECTION_MESSAGE_AUTHORITATIVE_WRITE] above, not a design-authored string.
const REASON_NOT_PLAYER_TURN: String = "現在不是你的回合"

## Reuses [constant REJECTION_MESSAGE_FORCED_DISCARD] verbatim rather than
## declaring a second string for the same underlying cause (`design/ux/battle-menu.md`'s
## own N5 text, "請先完成棄牌") — belt-and-suspenders only: per that spec's N5,
## a pending forced discard is supposed to already have refused this menu from
## ever opening in the first place (once U-015 wires
## [member forced_discard_in_progress_check]), so this row-level branch should
## be structurally unreachable in practice, same status as the third conjunct
## in [method can_end_faction_phase]'s own doc comment below.

@onready var _mask: ColorRect = $Mask
@onready var _panel: PanelContainer = $Panel
@onready var _content_margin: MarginContainer = $Panel/ContentMargin
@onready var _rows: VBoxContainer = $Panel/ContentMargin/Rows
@onready var _return_row: Button = $Panel/ContentMargin/Rows/ReturnToBattleRow
@onready var _end_phase_row: Button = $Panel/ContentMargin/Rows/EndPhaseRow
@onready var _end_phase_reason_label: Label = $Panel/ContentMargin/Rows/EndPhaseReasonLabel
@onready var _divider: ColorRect = $Panel/ContentMargin/Rows/Divider
@onready var _quit_row: Button = $Panel/ContentMargin/Rows/QuitRow

## Story U-010 — M4 (leave-confirmation) node refs. [member _leave_confirm_blocker]
## is a transparent, [constant Control.MOUSE_FILTER_STOP] full-rect [ColorRect]
## sitting between M1's rows and M4's own panel — it is what keeps M1 from
## receiving mouse clicks while M4 is open, chosen deliberately over setting
## [member BaseButton.disabled] on M1's rows directly: [method _process] (U-009)
## re-evaluates [member _end_phase_row].disabled every frame from
## [member controller]'s live state, so a manual disable here would race that
## per-frame refresh and could be silently overwritten while M4 is still open.
@onready var _leave_confirm: Control = $LeaveConfirm
@onready var _leave_confirm_blocker: ColorRect = $LeaveConfirm/Blocker
@onready var _leave_confirm_panel: PanelContainer = $LeaveConfirm/Panel
@onready var _leave_confirm_content_margin: MarginContainer = $LeaveConfirm/Panel/ContentMargin
@onready var _leave_confirm_content: VBoxContainer = $LeaveConfirm/Panel/ContentMargin/Content
@onready var _leave_confirm_title_label: Label = $LeaveConfirm/Panel/ContentMargin/Content/TitleLabel
@onready var _leave_confirm_body_label: Label = $LeaveConfirm/Panel/ContentMargin/Content/BodyLabel
@onready var _leave_cancel_button: Button = $LeaveConfirm/Panel/ContentMargin/Content/Buttons/CancelButton
@onready var _leave_quit_button: Button = $LeaveConfirm/Panel/ContentMargin/Content/Buttons/LeaveButton

## Story U-009 (ADR-0001's registered path ⑤, `end_faction_phase()`) — emitted
## right after this row's press handler calls [method BattleController.end_faction_phase]
## successfully (never on a rejected/disabled press). 🔴 [b]Deliberately does
## NOT also call [method BattleController.run_enemy_phase] or [method
## BattleController.step_enemy_phase][/b] — see [method _on_end_phase_row_pressed]'s
## own doc comment for why draining the enemy phase is this signal's listener's
## job, not this file's.
signal end_faction_phase_confirmed()

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
	# unconnected. QuitRow is still deliberately left UNconnected — U-010's job,
	# not this story's. EndPhaseRow is connected below (Story U-009).
	_return_row.pressed.connect(close)

	# Story U-009 (AC-M2/AC-M4/AC-M5/AC-M12) — see [method _on_end_phase_row_pressed]
	# and [method _refresh_end_phase_row] for what this wires up.
	_end_phase_row.pressed.connect(_on_end_phase_row_pressed)

	# 🔴 Story U-009: without this, [method _process] below (this row's ONLY
	# mechanism for the Data Requirements table's "選單開啟期間持續讀" —
	# there is no change-signal for [method BattleController.is_card_play_in_progress]
	# / [method BattleController.has_pending_discard] to connect to) would stop
	# running the instant [method open] sets [member SceneTree.paused] = true
	# (U-008) — [Node._process] is gated by [member Node.process_mode], and the
	# engine default ([constant Node.PROCESS_MODE_INHERIT]) pauses right along
	# with the rest of the tree. Measured directly (not assumed) in
	# `prototypes/u009-menu-pause-input-probe-2026-09-22/`: with the default
	# process_mode, a real ui_down [InputEvent] pushed while paused STILL moved
	# focus (native Control directional-focus dispatch is NOT gated by
	# [member SceneTree.paused] in this engine version) — so this override is
	# NOT needed for input/navigation to keep working while the menu is open;
	# it is needed specifically so [method _process]'s per-frame re-evaluation
	# of this row's judgement does not silently stop the moment the menu that
	# most needs it (a paused game) opens.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Story U-010 — "離開遊戲" opens M4 (State N4). Deliberately left
	# UNconnected by U-007/U-008/U-009 (see this class's own "Still Story
	# U-007/U-008 scope" note above) — this story's own natural completion of
	# a button they built but did not wire, the same shape as U-008 wiring
	# ReturnToBattleRow.pressed -> close() above.
	_quit_row.pressed.connect(open_leave_confirm)

	_leave_confirm_title_label.text = LEAVE_CONFIRM_TITLE
	_leave_confirm_body_label.text = LEAVE_CONFIRM_BODY

	for m4_button: Button in [_leave_cancel_button, _leave_quit_button]:
		m4_button.focus_mode = Control.FOCUS_ALL

	# 🔴 Confirm-key decision, affirmed for M4 explicitly rather than silently
	# inherited (per this story's dispatch instruction that U-008/009/010 each
	# decide explicitly): both buttons answer native [signal BaseButton.pressed]
	# (hence [code]ui_accept[/code]) — the SAME mechanism every other row in
	# this file already uses (see class doc comment's "Confirm-key decision"
	# section). No new decision was needed because M4 does not introduce a new
	# activation mechanism.
	_leave_cancel_button.pressed.connect(close_leave_confirm)
	_leave_quit_button.pressed.connect(_on_leave_confirmed_pressed)

	# Explicit neighbor wiring, matching every other focus transition in this
	# file (see this method's own comment above on why automatic geometric
	# search is never relied on here): Cancel <-> Leave in both left/right
	# directions; up/down self-loop (M4 has no vertical neighbor). This is
	# what STRUCTURALLY prevents directional navigation from ever escaping M4
	# back onto an M1 row while M4 is open — independent of whatever
	# mouse-blocking state M1's rows are in ([member _leave_confirm_blocker]
	# only stops mouse input, not keyboard focus search).
	_leave_cancel_button.focus_neighbor_left = _leave_cancel_button.get_path_to(_leave_quit_button)
	_leave_cancel_button.focus_neighbor_right = _leave_cancel_button.get_path_to(_leave_quit_button)
	_leave_cancel_button.focus_neighbor_top = _leave_cancel_button.get_path_to(_leave_cancel_button)
	_leave_cancel_button.focus_neighbor_bottom = _leave_cancel_button.get_path_to(_leave_cancel_button)
	_leave_quit_button.focus_neighbor_left = _leave_quit_button.get_path_to(_leave_cancel_button)
	_leave_quit_button.focus_neighbor_right = _leave_quit_button.get_path_to(_leave_cancel_button)
	_leave_quit_button.focus_neighbor_top = _leave_quit_button.get_path_to(_leave_quit_button)
	_leave_quit_button.focus_neighbor_bottom = _leave_quit_button.get_path_to(_leave_quit_button)

	_refresh_end_phase_row()


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
	# Story U-010 — force M4 CLOSED on every fresh open, the same "never leak
	# state across a cycle" reasoning [member _return_row].grab_focus() below
	# already applies to M1's own focus. 🔴 This reset lives HERE rather than
	# in [method close] on purpose: [method close]'s own doc comment claims
	# its body is "exactly these three lines" as part of AC-M9's reasoning
	# (never touching board/gameplay state) — that claim is about
	# [BattleState]/[BattleController]/[CursorState], not this menu's own M4
	# visibility, so adding this line there would not violate AC-M9, but it
	# WOULD invalidate a doc comment making a specific, load-bearing claim for
	# a reset [method open] already covers unconditionally on the very next
	# open. The two methods are intentionally asymmetric here, not an
	# oversight.
	_leave_confirm.visible = false
	_return_row.grab_focus()
	# Story U-009 (`design/ux/battle-menu.md` Data Requirements: "開啟選單時查
	# 一次") — re-evaluate the 結束回合 row immediately on open, rather than
	# waiting for the next [method _process] tick, so the very first frame the
	# menu is visible already reflects current battle state.
	_refresh_end_phase_row()
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


## Story U-010 (`design/ux/battle-menu.md` State N4, AC-M6's default-focus
## requirement). Enters M4 OVER M1 — M1's mask/panel/rows are never touched
## by this method (Implementation Note #2: "M1 的遮罩(M0)與面板持續存在於
## M4 底下"); [member _leave_confirm_blocker] (see its own doc comment) is
## what keeps M1 from receiving mouse input while M4 is up, not any change to
## M1's own visibility/disabled state.
##
## 🔴 Default focus is forced onto [member _leave_cancel_button] on EVERY
## call, never "whatever M4 was left on last time" — this IS the mechanical
## reason this story exists (`battle-menu.md`: "理由是機械性的而非禮貌性的"):
## the player just used the SAME confirm key to select "離開遊戲" from M1; if
## M4 defaulted to "離開", a second press of that key would quit the game.
func open_leave_confirm() -> void:
	_leave_confirm.visible = true
	_leave_cancel_button.grab_focus()


## Symmetric reverse of [method open_leave_confirm] — returns to M1 WITHOUT
## closing the whole menu (`design/ux/battle-menu.md` Implementation Note #7:
## "選定「取消」,或按 battle_cancel...兩者皆回到 M1,不關閉整個選單"). Both
## exit paths ([member _leave_cancel_button]'s [signal BaseButton.pressed]
## and [method _unhandled_input]'s [code]battle_cancel[/code] branch) call
## this same method, matching this file's own established "never let two
## paths to the same outcome drift apart" convention.
func close_leave_confirm() -> void:
	_leave_confirm.visible = false
	_quit_row.grab_focus()


func is_leave_confirm_open() -> bool:
	return _leave_confirm.visible


## Story U-010 (AC-M6's actual destructive action). 🔴 [b]Never calls
## [method SceneTree.quit] directly[/b] — always through
## [member quit_callable] (see that field's own doc comment for why an UNSET
## Callable here means "call the real one", the opposite of this file's other
## two injectable Callables). This indirection exists for exactly one reason:
## an automated test that accidentally executed the real branch would kill
## the test runner's own engine process — see [method diagnostic_would_call_real_quit].
func _on_leave_confirmed_pressed() -> void:
	if quit_callable.is_valid():
		quit_callable.call()
	else:
		get_tree().quit()


## Story U-009 (`design/ux/battle-menu.md` Data Requirements: "選單開啟期間持續
## 讀"). [method BattleController.phase] can change while this menu sits open
## (a card-play interaction closing, or — BM-3, unmeasured — a non-player-turn
## window) with no signal this file can connect to for the other two conjuncts
## ([method BattleController.is_card_play_in_progress] / [method
## BattleController.has_pending_discard] have none), so polling once per frame
## while visible is the mechanism the spec's own wording calls for, not a
## substitute this file invented. No-op while closed ([member Control.visible]
## is false) — no point re-evaluating a row nobody can see or reach.
func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh_end_phase_row()


## Story U-009 (AC-M2/AC-M4/AC-M5/AC-M12) — single place this row's
## enable/disable state and M3 reason text are computed and applied, called
## from three sites ([method _ready], [method open], [method _process]) so
## none of them duplicate the logic. Idempotent: safe to call every frame.
##
## 🔴 [b]Skip-on-navigate is implemented as NEIGHBOR-GRAPH REWIRING, not a
## [member Control.focus_mode] change[/b] — `design/ux/battle-menu.md` itself
## warns this behavior is a design decision, not a verified engine default
## ("`focus_mode` / `disabled` 的實際行為本專案從未量測過"). Rewiring
## [member Control.focus_neighbor_top] / [member Control.focus_neighbor_bottom]
## to route directly between [member _return_row] and [member _quit_row] while
## disabled is a STRUCTURAL guarantee (the neighbor graph physically has no
## edge into this row), matching this file's own established convention (see
## [method _ready]'s doc comment on why every row-to-row transition is wired
## explicitly rather than left to automatic geometric search) — it does not
## depend on how [member BaseButton.disabled] happens to interact with
## directional focus search in this engine version, which is exactly the
## untested assumption the spec warns against. [member Button.focus_mode] is
## deliberately left at [constant Control.FOCUS_ALL] in both states, so this
## does not disturb [code]battle_menu_layout_test.gd[/code]'s existing
## [code]test_all_three_rows_resolve_as_buttons_with_focus_mode_all[/code].
func _refresh_end_phase_row() -> void:
	var can_end: bool = can_end_faction_phase(controller)
	_end_phase_row.disabled = not can_end

	var reason: String = end_faction_phase_disabled_reason(controller)
	_end_phase_reason_label.visible = not can_end
	if not can_end:
		# Accessibility table's explicit two-channel requirement ("不可選用
		# ✕ + 原因文字", not color/graying alone) — the ✕ glyph plus the
		# reason string, verbatim from the wireframe's own formatting.
		_end_phase_reason_label.text = "✕ " + reason

	if can_end:
		_return_row.focus_neighbor_bottom = _return_row.get_path_to(_end_phase_row)
		_end_phase_row.focus_neighbor_top = _end_phase_row.get_path_to(_return_row)
		_end_phase_row.focus_neighbor_bottom = _end_phase_row.get_path_to(_quit_row)
		_quit_row.focus_neighbor_top = _quit_row.get_path_to(_end_phase_row)
	else:
		_return_row.focus_neighbor_bottom = _return_row.get_path_to(_quit_row)
		_quit_row.focus_neighbor_top = _quit_row.get_path_to(_return_row)
		# Defensive: if a still-open menu's focus was already sitting on this
		# row the instant it became disabled (e.g. card play started while the
		# player had navigated here but had not yet pressed anything), do not
		# leave focus stranded on a now-disabled row with no incoming neighbor
		# edge — evict it to the same row [method open] itself defaults to.
		if _end_phase_row.has_focus():
			_return_row.grab_focus()


## Story U-009 (AC-M5's shared-predicate requirement) — the single judgement
## `design/ux/battle-menu.md`'s N1/N2/N3 states and this story's Implementation
## Note #1 both name: the conjunction of three EXISTING [BattleController]
## queries, none of which this file re-derives or caches. [param controller]
## is read fresh on every call (see [method _refresh_end_phase_row]'s
## per-frame polling) — there is no cached bool anywhere in this file for this
## question, which is what AC-M5's injection test (flip [method
## BattleController.phase], expect this row to change with ZERO edits to this
## file) actually exercises.
##
## [code]null[/code] (`controller` never injected) returns [code]true[/code]
## (unconditionally enabled) — U-007/U-008's pre-existing baseline behavior;
## see [member controller]'s own doc comment for why that compatibility
## matters.
##
## 🔴 The third conjunct ([method BattleController.has_pending_discard])
## should be structurally unreachable as an ACTUAL cause of [code]false[/code]
## here in practice — `design/ux/battle-menu.md`'s N5 already refuses to let
## this menu open at all while a discard is owed (once U-015 wires [member
## forced_discard_in_progress_check]). It is still included because this
## story's own Implementation Notes name it explicitly as one of exactly three
## conjuncts ("不得新增第四個") and defense-in-depth already at this project's
## own established discipline (every gated [BattleController] command
## re-checks [method BattleController.has_pending_discard] itself rather than
## trusting a caller to have checked first).
static func can_end_faction_phase(controller: BattleController) -> bool:
	if controller == null:
		return true
	return (
		controller.phase() == BattleController.Phase.PLAYER_INPUT
		and not controller.is_card_play_in_progress()
		and not controller.has_pending_discard()
	)


## Story U-009 (AC-M4's "原因文字必須是玩家看得懂的白話") — companion to
## [method can_end_faction_phase], read by [method _refresh_end_phase_row] to
## fill M3. Returns [code]""[/code] whenever [method can_end_faction_phase]
## would return [code]true[/code] for the same [param controller] — the two
## methods are never called with the row in a state where one says "enabled"
## and the other supplies a non-empty reason.
##
## Priority when more than one cause is simultaneously true (not specified by
## `design/ux/battle-menu.md`, which treats the three as independent
## conjuncts, not an ordered list) — this file's own judgement call, same
## category as the placeholder visual constants above: card-play-in-progress
## first (the one cause with a real wireframe string), pending-discard second
## (see [method can_end_faction_phase]'s doc comment on why this branch should
## not be reachable in practice), phase last (N3, BM-3's unmeasured window).
static func end_faction_phase_disabled_reason(controller: BattleController) -> String:
	if controller == null:
		return ""
	if controller.is_card_play_in_progress():
		return REASON_CARD_PLAY_IN_PROGRESS
	if controller.has_pending_discard():
		return REJECTION_MESSAGE_FORCED_DISCARD
	if controller.phase() != BattleController.Phase.PLAYER_INPUT:
		return REASON_NOT_PLAYER_TURN
	return ""


## Story U-009 (Events Fired: "選定「結束回合」→ 陣營回合結束 → 敵方回合開始
## ✅ 必須" — ADR-0001 registered path ⑤). Re-checks [method can_end_faction_phase]
## itself immediately before acting (defense in depth, matching every gated
## [BattleController] command's own "always re-check right before" discipline
## — e.g. [method BattleController._apply_attack]'s doc comment) rather than
## trusting [member Button.disabled] alone to have prevented this signal from
## ever firing.
##
## 🔴 [b]Deliberately calls ONLY [method BattleController.end_faction_phase],
## never [method BattleController.run_enemy_phase] or [method
## BattleController.step_enemy_phase][/b] — a deviation from this story's own
## Implementation Notes text (which names `run_enemy_phase()` as part of the
## required call sequence), flagged explicitly rather than followed silently:
##
## That text was written against [code]battle_screen.gd[/code]'s PRE-U-018
## [code]_end_faction_phase_pressed()[/code] (a flat three-call sequence:
## [code]end_faction_phase() -> run_enemy_phase() -> _refresh_view()[/code]).
## Story-018-enemy-phase-stepped-playback.md REWROTE that function into a
## cross-frame coroutine driving [method BattleController.step_enemy_phase]
## in a loop with an [code]await[/code] between steps — and [method
## step_enemy_phase]'s own doc comment is explicit that the two enemy-phase
## drivers "MUST NOT be interleaved... call exactly one of the two for a
## phase's entire duration... [b]Production code only ever calls this
## method[/b]; [method run_enemy_phase] remains the whole-phase entry point
## for tests and any future non-presentation driver." Calling
## [method run_enemy_phase] here would make this row a SECOND, differently-
## behaved production driver of the enemy phase (instant, unanimated) living
## alongside [code]battle_screen.gd[/code]'s stepped/animated one — exactly
## the "另寫一條平行路徑" this same Implementation Notes paragraph says must
## not happen, just reached by literally following its own now-stale example.
##
## This file's file-scope for this story is [code]battle_menu.gd[/code] only
## (dispatch: do not touch [code]battle_screen.gd[/code] / [code]board_view.gd[/code]),
## and [method BattleScreen._refresh_view] — the other half of the quoted
## sequence — is private to that screen regardless. So the mutating half of
## the sequence ([method BattleController.end_faction_phase], the actual
## ADR-0001 write) happens here, directly, matching every other write this
## project's UI layer performs by calling straight into [BattleController]
## (see [code]battle_screen.gd[/code]'s own class doc comment: "player input
## becomes [method BattleController.click_tile] calls" — this project's
## established command-layer pattern, not a game-state ownership violation);
## draining whichever enemy-phase driver is actually wired into the live game
## is left to [signal end_faction_phase_confirmed]'s listener — whichever
## future story instantiates this menu into [code]BattleScreen.tscn[/code]
## (BM-1 in `battle-menu.md`'s Open Questions is still unresolved on whether/
## how that wiring happens at all) already has to touch that file, so it is
## the one place that can correctly pick "call the SAME driver
## `_end_faction_phase_pressed()` already uses", not a second, independent
## guess made from inside this file.
## 🔴 Confirm-key decision, affirmed for THIS row rather than silently
## inherited (per this story's dispatch instruction that U-008/009/010 each
## decide explicitly): this row is connected to native [signal
## BaseButton.pressed], the exact same mechanism [member _return_row] already
## uses — so it answers to [code]ui_accept[/code], not [code]battle_confirm[/code],
## for the identical reasons the class doc comment's "Confirm-key decision"
## section already gives (ADR-0005 AC-60's native-focus/activation exemption).
## No new decision was needed because this row does not introduce a new
## activation mechanism — it reuses the one this file already decided on.
func _on_end_phase_row_pressed() -> void:
	if controller == null:
		return
	if not can_end_faction_phase(controller):
		return
	controller.end_faction_phase()
	end_faction_phase_confirmed.emit()


## Story U-010 — the ONLY way [member _leave_confirm] closes other than
## selecting "取消" itself (`design/ux/battle-menu.md` Implementation Note
## #7). Scoped to M4 alone: while M4 is closed, this method does nothing and
## does not mark the event handled, leaving [code]battle_cancel[/code]'s
## handling for the whole menu (closing M1 itself) to whichever future story
## wires this scene's top-level open()/close() into [code]battle_screen.gd[/code]
## — unchanged by this story (class doc comment's "Still Story U-007/U-008
## scope" note). Reachable while [member SceneTree.paused] is true because
## [method _ready] already sets [member Node.process_mode] =
## [constant Node.PROCESS_MODE_ALWAYS] (U-009) — that override applies to
## every per-node engine callback gated by process_mode, not only
## [method _process].
func _unhandled_input(event: InputEvent) -> void:
	if not _leave_confirm.visible:
		return
	if event.is_action_pressed(&"battle_cancel"):
		close_leave_confirm()
		get_viewport().set_input_as_handled()


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

	# Story U-009 (M3) — `design/ux/battle-menu.md` Layout Zones table: "M3
	# 不可選原因 | ... | 一行,0.7 fpx 字級". Styled unconditionally (even while
	# hidden) so the very first frame it becomes visible already has correct
	# sizing — matches this loop's own convention for the three row Buttons
	# above, which are also styled regardless of enabled/disabled state.
	_end_phase_reason_label.add_theme_font_override(&"font", HUD_FONT)
	_end_phase_reason_label.add_theme_font_size_override(
		&"font_size", int(fpx * REASON_FONT_FPX_MULTIPLIER)
	)
	_end_phase_reason_label.add_theme_color_override(&"font_color", REASON_TEXT_COLOR)

	# Story U-010 — M4 sizing/position via the SAME anchor math [method
	# panel_rect] already established for M1 (see [method leave_confirm_rect]);
	# style/margin/separation placeholders reuse M1's own placeholder
	# constants rather than inventing a second set — BM-7 (視覺樣式全部未定)
	# is unowned regardless of which modal it applies to, so a second
	# placeholder surface for a second modal is not worth the extra drift
	# risk. Styled unconditionally even while hidden, matching every other
	# element in this function.
	var leave_r: Rect2 = leave_confirm_rect(window_size)
	_leave_confirm_panel.offset_left = leave_r.position.x
	_leave_confirm_panel.offset_top = leave_r.position.y
	_leave_confirm_panel.offset_right = leave_r.end.x
	_leave_confirm_panel.offset_bottom = leave_r.end.y
	_leave_confirm_panel.add_theme_stylebox_override(&"panel", _panel_stylebox())

	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_leave_confirm_content_margin.add_theme_constant_override(side, content_margin_px)
	_leave_confirm_content.add_theme_constant_override(&"separation", int(fpx * ROW_SEPARATION_FPX_MULTIPLIER))

	_leave_confirm_title_label.add_theme_font_override(&"font", HUD_FONT)
	_leave_confirm_title_label.add_theme_font_size_override(&"font_size", int(fpx))
	_leave_confirm_body_label.add_theme_font_override(&"font", HUD_FONT)
	_leave_confirm_body_label.add_theme_font_size_override(
		&"font_size", int(fpx * REASON_FONT_FPX_MULTIPLIER)
	)

	for m4_button: Button in [_leave_cancel_button, _leave_quit_button]:
		m4_button.custom_minimum_size = Vector2(0, row_h)
		m4_button.add_theme_font_override(&"font", HUD_FONT)
		m4_button.add_theme_font_size_override(&"font_size", int(fpx))
		# `P-F3`'s required second, non-color focus channel — same stylebox
		# instance M1's rows already use (StyleBox resources are safely
		# shared read-only across multiple Controls in Godot).
		m4_button.add_theme_stylebox_override(&"focus", focus_style)


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


## M4 (leave-confirmation) SIZE ONLY — this size arithmetic was verified by
## U-007 (Implementation Notes #2's obligation) before M4 itself existed; see
## `tests/unit/ui/menu/battle_menu_layout_test.gd`'s own regression test
## against this function, which this story does not touch.
static func leave_confirm_size(window_size: Vector2i) -> Vector2:
	var fpx: float = float(HudLayout.font_size(window_size))
	return Vector2(fpx * LEAVE_CONFIRM_WIDTH_FPX_MULTIPLIER, fpx * LEAVE_CONFIRM_HEIGHT_FPX_MULTIPLIER)


## Story U-010 — M4's rect in window-pixel space: the POSITION half
## [method leave_confirm_size] never provided (that function is SIZE only —
## see its own doc comment). Centers M4 within [method HudLayout.safe_rect],
## the exact same anchor and centering formula [method panel_rect] already
## established for M1 — this function does not invent a second convention.
static func leave_confirm_rect(window_size: Vector2i) -> Rect2:
	var safe: Rect2 = HudLayout.safe_rect(window_size)
	var size: Vector2 = leave_confirm_size(window_size)
	var pos: Vector2 = safe.position + (safe.size - size) / 2.0
	return Rect2(pos, size)
