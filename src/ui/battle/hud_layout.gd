## Pure, node-independent HUD label layout rules for `BattleScreen.tscn`'s
## `UILayer`, mirroring [WorldLayout]'s split between calculation (this file)
## and node mutation ([code]hud_layout_scaler.gd[/code]) — see that class's
## own doc comment for why call sites must never re-derive this kind of math
## themselves. Every rect returned here is expressed as
## [code]offset_left/top/right/bottom[/code] components
## ([code]rect.position[/code] = left/top, [code]rect.end[/code] =
## right/bottom) in whatever anchor space the target [Control] already uses
## in [code]BattleScreen.tscn[/code] — anchor (0,0,0,0) top-left for four of
## the five nodes, anchor (0.5,0.5,0.5,0.5) center for
## [code]ResultLabel[/code] (see [method result_label_offset_rect]'s own doc
## comment) — so a caller can always assign the four components directly
## without touching any node's [code]anchors_preset[/code].
##
## Story 002 (`production/epics/screen-scaling/story-002-adaptive-font-scale.md`),
## 範圍擴充後兩節的權威實作:
##
## - [b]HUD 字級規則(2026-09-04 管理者裁決,A 案)[/b]:[method font_size] 直接
##   呼叫 [method WorldLayout.compute_scale] —— 不重刻該公式,唯一出處仍是
##   [WorldLayout]。「HUD 字級 = 11 * N,N 就是世界層的棋盤放大倍率」逐字對應
##   這個函式的實作,不是另一份巧合相符的公式。
## - [b]6 個既有元件座標退化的修法[/b](規格「範圍擴充」節記載的兩種失效形狀:
##   前 5 個絕對座標縮到左上角、[code]ResultLabel[/code] 位置正確但尺寸過小):
##   本檔每個 [code]*_rect[/code] 函式都以 [method safe_rect] 為錨點,而不是
##   螢幕物理邊緣。[b]這是本檔做出的一個明確版面判斷,不是規格逐字寫死的數字[/b]:
##   安全區存在的目的就是防止內容碰到物理邊緣,若 [code]ControlsHintBg[/code]
##   背景本身又貼齊真正的螢幕邊緣,安全區對它就形同虛設。已在任務回報中列為
##   需要協調者確認的一項設計取捨,而非規格明文要求。
class_name HudLayout
extends RefCounted

## Cubic 11's native glyph size — the "11" in the A-ruling's "11 * N".
const GLYPH_PX: int = 11

## Title-safe inset, applied independently to each axis
## (`design/art/art-direction.md` §6:水平 5%、垂直 5% —— 例:2560x1440 ->
## 2304x1296 置中,逐字對應 AC-S002-c 自己的範例)。
const TITLE_SAFE_INSET_FRACTION: float = 0.05

## Fraction of [method safe_rect]'s width [code]StatusLabel[/code] occupies —
## checked against `prototypes/story-002-font-scale-spike-2026-09-04/`'s real
## [code]Font.get_string_size()[/code] readings for the A candidate at every
## one of that spike's 8 resolutions (widest requirement: 917px at 4K, N=8).
## 30% of the safe width clears every measured requirement with margin at
## every resolution the spike covered — see
## [code]tests/unit/ui/hud_layout_test.gd[/code] for the regression check
## pinned to those exact spike numbers.
const STATUS_LABEL_WIDTH_FRACTION: float = 0.3

## Multiplier on [method font_size] used for [code]StatusLabel[/code] /
## [code]InfoLabel[/code] box height. The spike's measured line height was
## ~1.2x font_px at every resolution it covered; 1.5x adds margin on top of
## that measurement rather than reproducing it exactly.
const LABEL_HEIGHT_MULTIPLIER: float = 1.5

## Multiplier on [method font_size] used to compute the gap between
## [code]StatusLabel[/code]'s right edge and [code]InfoLabel[/code]'s left
## edge — one glyph-height of breathing room, scaling with the same N as the
## text itself so the gap never looks disproportionate at any resolution.
const LABEL_GAP_MULTIPLIER: float = 1.0

## Multiplier on [method font_size] used for [code]ControlsHintBg[/code]'s
## height — enough for one line of Cubic 11 text (measured ~1.2x font_px)
## plus padding on both sides.
const CONTROLS_HINT_BG_HEIGHT_MULTIPLIER: float = 2.0

## Multipliers on [method font_size] used for [code]ResultLabel[/code]'s box
## — a "victory/defeat" banner sized well beyond the 2-character strings it
## actually shows (spike's widest measurement: 191px at 4K, N=8; 6x font_size
## gives 528px at that same N, comfortably larger without needing
## per-resolution tuning).
const RESULT_LABEL_WIDTH_MULTIPLIER: float = 6.0
const RESULT_LABEL_HEIGHT_MULTIPLIER: float = 2.2


## HUD font size in pixels for [param window_size], per the A ruling
## (story-002-adaptive-font-scale.md, 2026-09-04 manager ruling): 11 times the
## SAME integer N the world layer uses for its own board scale. Delegates the
## entire N computation to [method WorldLayout.compute_scale] — this file
## owns zero scale math of its own, per that class's own "no call site may
## re-derive" doc comment and this project's registered failure pattern of
## the same formula being re-implemented twice and only agreeing "today"
## (see [WorldLayout]'s own doc comment for the citation).
##
## [b]Known, accepted consequence — do not add a floor/clamp here without a
## new manager ruling:[/b] screens whose height is not a clean multiple of
## 270 "fall through" to the same N as a much smaller screen (1366x768 -> 2,
## identical to the 960x540 minimum window despite being 42% taller). See
## story-002's "這個選擇的已知代價" section — accepted, not a defect. Any fix
## for that would decouple the HUD scale from the board scale, which is a NEW
## ruling (candidate B's shape), not an implementation-level adjustment.
static func font_size(window_size: Vector2i) -> int:
	return GLYPH_PX * WorldLayout.compute_scale(window_size)


## Title-safe rect for [param window_size]: each axis inset by
## [constant TITLE_SAFE_INSET_FRACTION] on both sides, centered — e.g.
## 2560x1440 -> position (128, 72), size (2304, 1296), matching AC-S002-c's
## own worked example exactly.
static func safe_rect(window_size: Vector2i) -> Rect2:
	var size: Vector2 = Vector2(window_size)
	var inset: Vector2 = size * TITLE_SAFE_INSET_FRACTION
	return Rect2(inset, size - inset * 2.0)


## [code]StatusLabel[/code] box ("左上角回合狀態" per the story's own table):
## anchored at [method safe_rect]'s top-left corner — not the raw screen
## corner, so the text itself is never in the inset title-unsafe margin.
## [code]StatusLabel[/code]'s anchors in [code]BattleScreen.tscn[/code] are
## the [Control] default (0,0,0,0), so this rect's components map directly to
## [code]offset_left/top/right/bottom[/code].
static func status_label_rect(window_size: Vector2i) -> Rect2:
	var safe: Rect2 = safe_rect(window_size)
	var fpx: float = float(font_size(window_size))
	var width: float = safe.size.x * STATUS_LABEL_WIDTH_FRACTION
	var height: float = fpx * LABEL_HEIGHT_MULTIPLIER
	return Rect2(safe.position, Vector2(width, height))


## [code]InfoLabel[/code] box — "緊接其右,同一列" (immediately to
## [code]StatusLabel[/code]'s right, same row) per the story's table: fills
## every pixel between [method status_label_rect]'s right edge (plus one
## glyph-height gap) and [method safe_rect]'s right edge.
## [code]InfoLabel[/code]'s existing [code]horizontal_alignment = 2[/code]
## (RIGHT) in [code]BattleScreen.tscn[/code] means its text hugs the safe
## area's right edge regardless of how much empty space this box leaves on
## wide screens — that emptiness is deliberate, not a sizing bug, since the
## box only has to be wide enough to never clip the text it actually renders.
static func info_label_rect(window_size: Vector2i) -> Rect2:
	var safe: Rect2 = safe_rect(window_size)
	var status: Rect2 = status_label_rect(window_size)
	var fpx: float = float(font_size(window_size))
	var gap: float = fpx * LABEL_GAP_MULTIPLIER
	var left: float = status.position.x + status.size.x + gap
	var right: float = safe.position.x + safe.size.x
	return Rect2(Vector2(left, status.position.y), Vector2(maxf(right - left, 0.0), status.size.y))


## [code]ControlsHintBg[/code] box — "螢幕底部滿版操作提示橫條" (full-width
## bottom control-hint bar) per the story's table, reinterpreted as
## full-[b]safe-width[/b] rather than full-physical-screen-width: the bar's
## bottom edge sits exactly on [method safe_rect]'s bottom edge and its
## left/right edges match the safe rect's, so the bar (and the
## [code]ControlsHintLabel[/code] it fully contains, per that node's own
## [code]anchors_preset = 15[/code] in [code]BattleScreen.tscn[/code]) never
## needs separate safe-area math of its own.
##
## [b]This is a deliberate call, flagged in the task report, not a number the
## spec wrote down:[/b] a background that instead bled all the way to the
## physical screen edge would defeat the purpose of a safe area existing at
## all for the text riding on top of it.
static func controls_hint_bg_rect(window_size: Vector2i) -> Rect2:
	var safe: Rect2 = safe_rect(window_size)
	var fpx: float = float(font_size(window_size))
	var height: float = fpx * CONTROLS_HINT_BG_HEIGHT_MULTIPLIER
	var top: float = safe.position.y + safe.size.y - height
	return Rect2(Vector2(safe.position.x, top), Vector2(safe.size.x, height))


## [code]LoadErrorLabel[/code] box — "近全螢幕錯誤訊息" (near-fullscreen
## failure message) per the story's table, taken to mean exactly
## [method safe_rect]: the largest box guaranteed to satisfy AC-S002-c by
## construction, since it IS the title-safe rect. See
## [code]tests/unit/ui/hud_layout_test.gd[/code] for the measured
## wrapped-text-height check at the smallest supported window (960x540) —
## this rect's height must exceed that measured wrap height for the message
## to actually fit without overflowing, and that is verified there against
## the real engine and the real message text rather than assumed here.
static func load_error_label_rect(window_size: Vector2i) -> Rect2:
	return safe_rect(window_size)


## [code]ResultLabel[/code] box, expressed as offsets from its own anchor
## point rather than a top-left rect — [code]ResultLabel[/code]'s anchors in
## [code]BattleScreen.tscn[/code] are already 0.5 on all four sides (a single
## centered point; the story's table diagnosis is "位置其實是正確的", only its
## fixed 160x40 size is wrong), so this function only fixes the SIZE half of
## the problem, never the position. It returns a [Rect2] centered on the
## origin ([code]position = -size / 2[/code]) whose four corners map directly
## to [code]offset_left/top/right/bottom[/code] the same way the other rects
## do — for a 0.5-anchored [Control], [code]offset_left[/code] IS the
## distance left of the anchor point, so a negative [code]position.x[/code]
## here is exactly that distance.
static func result_label_offset_rect(window_size: Vector2i) -> Rect2:
	var fpx: float = float(font_size(window_size))
	var size: Vector2 = Vector2(fpx * RESULT_LABEL_WIDTH_MULTIPLIER, fpx * RESULT_LABEL_HEIGHT_MULTIPLIER)
	return Rect2(-(size / 2.0), size)
