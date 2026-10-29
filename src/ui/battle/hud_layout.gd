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
## height. 🔴 Story U-016 (2026-09-24) changed this from [code]2.0[/code]
## (one line) to [code]3.2[/code] (two lines) — [code]battle_screen.gd[/code]'s
## own [constant BattleScreen.TEXT_CONTROLS_HINT] became a 2-line string that
## story (EPIC.md 陷阱十: the old 1-line string measured 452px against a
## ~464px usable width with 12px to spare, before 5 new epic actions needed
## captions added to it). Same per-line measurement basis as before (~1.2x
## font_px per line): [code]2 * 1.2 + 0.8[/code] (the [code]0.8[/code]
## padding term is what the old comment's [code]2.0 - 1.2[/code] already
## implied) [code]= 3.2[/code].
const CONTROLS_HINT_BG_HEIGHT_MULTIPLIER: float = 3.2

## Multipliers on [method font_size] used for [code]ResultLabel[/code]'s box
## — a "victory/defeat" banner sized well beyond the 2-character strings it
## actually shows (spike's widest measurement: 191px at 4K, N=8; 6x font_size
## gives 528px at that same N, comfortably larger without needing
## per-resolution tuning).
const RESULT_LABEL_WIDTH_MULTIPLIER: float = 6.0
const RESULT_LABEL_HEIGHT_MULTIPLIER: float = 2.2

## Story 028 G:小視窗(倍率 N 不大於 [constant COMPACT_HINT_MAX_SCALE])時底部說明列縮成一行。
## 兩行的列高 3.2 倍字級,在 960x540 會蓋住棋盤最下一列(實測蓋 19px);一行 2.0 倍則不會。
## N 一律來自 [method WorldLayout.compute_scale],不另算。
const COMPACT_HINT_MAX_SCALE: int = 2
const COMPACT_HINT_BG_HEIGHT_MULTIPLIER: float = 2.0
## 單行模式只保留說明文字以全形空白分隔的前幾段(其餘功能有按鈕/選單可達)。
const COMPACT_HINT_SEGMENT_COUNT: int = 2


static func is_compact_hint_bar(window_size: Vector2i) -> bool:
	return WorldLayout.compute_scale(window_size) <= COMPACT_HINT_MAX_SCALE


## Story 029 G 補:四項版 = 第一行前 [constant COMPACT_HINT_WIDE_SEGMENT_COUNT] 段
## + 第二行第 [constant COMPACT_HINT_WIDE_EXTRA_INDEX] 段(選單)。依段落位置取,不寫死文字。
const COMPACT_HINT_WIDE_SEGMENT_COUNT: int = 3
const COMPACT_HINT_WIDE_EXTRA_INDEX: int = 2
## ControlsHintLabel 在 BattleScreen.tscn 相對說明列的左側內縮(offset_left = 4,固定像素)。
const COMPACT_HINT_LABEL_INSET_PX: float = 4.0


## 單行模式可用於說明文字的寬度:說明列左緣到左側按鈕([code]index 1[/code])左緣,再扣標籤內縮。
static func compact_hint_available_width(window_size: Vector2i) -> float:
	var bar: Rect2 = controls_hint_bg_rect(window_size)
	var left_button: Rect2 = hud_action_button_rect(window_size, 1)
	return left_button.position.x - bar.position.x - COMPACT_HINT_LABEL_INSET_PX


## 單行模式用的說明文字。先組四項版(第一行前 3 段 + 第二行選單段);
## 若以 HUD 字型實際量到的寬度超過 [method compact_hint_available_width],退回兩項版
## (第一行前 [constant COMPACT_HINT_SEGMENT_COUNT] 段)。
## [param window_size] 為 ZERO 時取目前主視窗尺寸(相容舊呼叫端)。
static func compact_hint_text(full_text: String, window_size: Vector2i = Vector2i.ZERO) -> String:
	var lines: PackedStringArray = full_text.split("\n")
	var first: PackedStringArray = lines[0].split("　", false)
	var narrow: String = "　".join(first.slice(0, COMPACT_HINT_SEGMENT_COUNT))
	if lines.size() < 2:
		return narrow
	var second: PackedStringArray = lines[1].split("　", false)
	if second.size() <= COMPACT_HINT_WIDE_EXTRA_INDEX:
		return narrow
	var wide_segments: PackedStringArray = first.slice(0, COMPACT_HINT_WIDE_SEGMENT_COUNT)
	wide_segments.append(second[COMPACT_HINT_WIDE_EXTRA_INDEX])
	var wide: String = "　".join(wide_segments)
	var size: Vector2i = window_size
	if size == Vector2i.ZERO:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree == null:
			return narrow
		size = tree.root.size
	var width: float = HudLayoutScaler.HUD_FONT.get_string_size(
		wide, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size(size)).x
	return wide if width <= compact_hint_available_width(size) else narrow


## Story 025:結果文字字級相對 HUD 字級的整數倍,與結果框可容納行數。
const RESULT_FONT_MULTIPLIER: int = 2
const RESULT_LABEL_LINES: float = 2.0

## relation-minimap story-001: panel height in font-size units (see relation_minimap_rect).
const RELATION_MINIMAP_HEIGHT_MULTIPLIER: float = 10.0

## 關係圖開關按鈕的寬高,以 [method small_font_size] 為單位(「關係圖 [R]」約 5 字寬加留白)。
const RELATION_TOGGLE_WIDTH_MULTIPLIER: float = 6.5
const RELATION_TOGGLE_HEIGHT_MULTIPLIER: float = 1.6

## 底部滑鼠按鈕(見 [method hud_action_button_rect])的寬與內縮,皆為字級倍數。
const HUD_ACTION_BUTTON_WIDTH_MULTIPLIER: float = 5.0
const HUD_ACTION_BUTTON_PAD_MULTIPLIER: float = 0.2


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
	var multiplier: float = (
		COMPACT_HINT_BG_HEIGHT_MULTIPLIER if is_compact_hint_bar(window_size)
		else CONTROLS_HINT_BG_HEIGHT_MULTIPLIER
	)
	var height: float = fpx * multiplier
	var top: float = safe.position.y + safe.size.y - height
	return Rect2(Vector2(safe.position.x, top), Vector2(safe.size.x, height))


## 2026-10-28 管理者試玩回饋第 4 點「全程應該要可以只用滑鼠完成遊玩」——
## 底部說明列右端的滑鼠按鈕(「手牌」「選單」),上下疊兩顆:[param index] 0 在下、1 在上。
## 放在說明列內(說明文字右側的空白),不蓋棋盤;寬高全以字級倍數算,
## 與說明文字同比例縮放,故各解析度下說明文字與按鈕的相對位置不變。
static func hud_action_button_rect(window_size: Vector2i, index: int) -> Rect2:
	var bg: Rect2 = controls_hint_bg_rect(window_size)
	var fpx: float = float(font_size(window_size))
	var width: float = fpx * HUD_ACTION_BUTTON_WIDTH_MULTIPLIER
	var pad: float = fpx * HUD_ACTION_BUTTON_PAD_MULTIPLIER
	if is_compact_hint_bar(window_size):
		# Story 028 G:單行說明列放不下上下兩顆,改左右並排([param index] 0 在右、1 在左)。
		var c_height: float = bg.size.y - 2.0 * pad
		var c_left: float = bg.position.x + bg.size.x - pad - width - float(index) * (width + pad)
		return Rect2(Vector2(c_left, bg.position.y + pad), Vector2(width, c_height))
	var height: float = (bg.size.y - 3.0 * pad) / 2.0
	var left: float = bg.position.x + bg.size.x - pad - width
	var top: float = bg.position.y + bg.size.y - pad - height - float(index) * (height + pad)
	return Rect2(Vector2(left, top), Vector2(width, height))


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
##
## Story 025:結果文字改為畫面中央大字(字級見 [method result_font_size]),
## 框寬 = 安全區全寬(戰敗原因文字較長,靠 autowrap 換行)、高 = 兩行。
## 仍以安全區為界,所以既有「不超出安全區半徑」的回歸測試照舊成立。
static func result_label_offset_rect(window_size: Vector2i) -> Rect2:
	var rpx: float = float(result_font_size(window_size))
	var width: float = safe_rect(window_size).size.x
	var size: Vector2 = Vector2(width, rpx * RESULT_LABEL_HEIGHT_MULTIPLIER * RESULT_LABEL_LINES)
	return Rect2(-(size / 2.0), size)


## Story 025:結果文字字級 = [method font_size] 的整數倍([constant RESULT_FONT_MULTIPLIER]),
## 倍率 N 仍唯一出自 [method WorldLayout.compute_scale](經 [method font_size]),
## 整數倍保持點陣字不糊。
static func result_font_size(window_size: Vector2i) -> int:
	return font_size(window_size) * RESULT_FONT_MULTIPLIER


## battle-hud story-003 -- EGM consistency counter ("猜中 6/8") box. Sits
## directly under [method status_label_rect] (top-left corner, one
## [constant LABEL_GAP_MULTIPLIER] gap below), same width as the status
## label. Overlay on the board, no side column. It cannot overlap the tile
## info panel (right-aligned, 40% of safe width: it starts right of 60%, this
## box ends at 30%) nor [method info_label_rect] (different row).
static func consistency_counter_rect(window_size: Vector2i) -> Rect2:
	var status: Rect2 = status_label_rect(window_size)
	var fpx: float = float(font_size(window_size))
	var gap: float = fpx * LABEL_GAP_MULTIPLIER
	return Rect2(
		Vector2(status.position.x, status.position.y + status.size.y + gap),
		Vector2(status.size.x, status.size.y)
	)


## relation-minimap story-001 -- the always-visible toggle button ("關係圖")
## under [method consistency_counter_rect]: same left edge, same width, one
## gap below it. Overlay on the board, no side column.
##
## 2026-10-28 管理者試玩回饋:「會一直不小心按到關係圖,把按鈕做小一點」。
## 原本與一致率計數器同寬(安全區 30%)、同高;改為以小一級字級
## ([method small_font_size])為基準的小按鈕,左上角位置不變。
static func relation_minimap_toggle_rect(window_size: Vector2i) -> Rect2:
	var counter: Rect2 = consistency_counter_rect(window_size)
	var fpx: float = float(font_size(window_size))
	var small: float = float(small_font_size(window_size))
	var gap: float = fpx * LABEL_GAP_MULTIPLIER
	return Rect2(
		Vector2(counter.position.x, counter.position.y + counter.size.y + gap),
		Vector2(small * RELATION_TOGGLE_WIDTH_MULTIPLIER, small * RELATION_TOGGLE_HEIGHT_MULTIPLIER)
	)


## 比 HUD 字級小一級:少一個像素字型基準 [constant GLYPH_PX],仍是它的整數倍(像素字不糊),
## 最小不低於 1 倍。右上格位資訊框與關係圖按鈕共用。
static func small_font_size(window_size: Vector2i) -> int:
	return maxi(GLYPH_PX, font_size(window_size) - GLYPH_PX)


## relation-minimap story-001 -- the panel itself, directly under
## [method relation_minimap_toggle_rect]. Height is a fixed multiple of the
## font size (RELATION_MINIMAP_HEIGHT_MULTIPLIER) rather than equal to the
## width: at the 960x540 minimum a width-equal square would run into
## [method controls_hint_bg_rect]. Left column, so it cannot meet the tile
## info panel (right-aligned) and sits left of the centred hand bar; the
## no-overlap claim is asserted by test against the real rect functions.
static func relation_minimap_rect(window_size: Vector2i) -> Rect2:
	var toggle: Rect2 = relation_minimap_toggle_rect(window_size)
	var counter: Rect2 = consistency_counter_rect(window_size)
	var fpx: float = float(font_size(window_size))
	var gap: float = fpx * LABEL_GAP_MULTIPLIER
	# 寬度取計數器寬(按鈕縮小後不再與面板同寬,面板維持原寬)。
	return Rect2(
		Vector2(toggle.position.x, toggle.position.y + toggle.size.y + gap),
		Vector2(counter.size.x, fpx * RELATION_MINIMAP_HEIGHT_MULTIPLIER)
	)
