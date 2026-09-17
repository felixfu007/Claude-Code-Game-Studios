extends Node
## Throwaway Story U-011 evidence capture driver — AC-U4 後半
## ("手牌 0 張 → Z1 顯示空槽輪廓與 0/5;且該畫面與 S5「不可用」畫面外觀可區分,
## 兩張截圖並列比對")。PROTOTYPE code — relaxed per
## `.claude/rules/prototype-code.md` (hardcoded values / minimal abstraction
## are fine here); doc comments kept longer than typical prototype code only
## because this file's own history (see git log / README.md) already went
## through two rejected approaches and the reasoning for the final one is the
## most useful thing to leave behind for whoever reads this next.
##
## 🔴 兩張圖的證據強度不同,分開的原因見 README.md(2026-09-17 協調者裁決三):
## S7 走完整、真正的正式場景;S5 不經過完整 BattleScreen(敵方階段同步執行,
## 現行遊戲畫不出這一格,見下方 _capture_s5() 的註解)。
##
## 🔴 2026-09-17 第二次協調者裁決,取代本檔第一版的做法(取代原因與失敗數字都
## 留在 README.md,不在此重複):裁切圖不得用 12 點稀疏取樣 / 全域相異色數這類
## 統計指標 —— `coding-standards.md` 自己的表格明文警告「色數越多越像真的」指向
## 錯誤方向(啟動畫面 493 色 > 真實畫面 247 色)。改為**定向檢查**,座標一律取自
## `HandBar.slot_rect()` / `HandBar.slot_bar_rect()`(版面說「應該在那裡」的座標),
## 不是隨機/均勻撒點:
##   A. 每一格空槽輪廓的頂邊,在 S7 與 S5 兩張圖裡各自都與同一格內部(無邊框處)
##      有可測得的亮度差 —— 證明外框真的畫在版面算出來的位置,兩張圖都算。
##   B. S5 的鎖狀圖示區域,亮度明顯高於「確定是空白背景」的參考點(S5 是獨立
##      擷取、視窗其餘部分是純背景)—— 正面證明鎖圖示確實畫出來了。
##      ⚠️ S7 沒有對應的「不存在」像素檢查:S7 是完整戰鬥畫面,同一螢幕位置的
##      背景是真實棋盤內容,不是純色,無法用像素比對排除「那裡剛好也很亮」的
##      可能。S7 的「不可用鎖圖示應為 false」由
##      tests/unit/ui/hand_bar_test.gd 的
##      test_normal_availability_shows_no_lock_glyph_or_caption_and_full_alpha
##      (headless,diagnostic_lock_glyph_visible() == false)負責證明 ——
##      這是陷阱十三「決定 vs 套用」split 的「決定」半部,本檔只證「套用」半部
##      做得到的那一格(B 的正面案例)。
##   C. 兩張裁切圖逐像素亮度差的「標準差」必須明顯大於 0 —— 若差異只是整體
##      壓暗(降對比),每個像素的差會趨近同一個常數,標準差會趨近 0;
##      標準差夠大代表兩圖的差異有結構(某些位置差很多、某些位置幾乎不差),
##      對應規格要求的「不只靠對比」三通道設計。
##
## Rule 1~3(尺寸/12 點取樣/主色佔比)只套用在兩張【整張視窗畫面】的擷圖上 ——
## 那是這組規則本來校準的對象,不動規則本身,也不套到裁切圖上。
##
## Run via: godot --path . <this scene>.tscn(真實 GPU 視窗;headless 沒有可
## 擷取的渲染目標,見 .claude/docs/coding-standards.md)。

const S7_OUTPUT_PATH: String = "res://production/qa/evidence/story-u011-hand-bar-s7-empty-2026-09-17.png"
const S5_OUTPUT_PATH: String = "res://production/qa/evidence/story-u011-hand-bar-s5-locked-2026-09-17.png"
const S7_CROP_OUTPUT_PATH: String = "res://production/qa/evidence/story-u011-hand-bar-s7-crop-2026-09-17.png"
const S5_CROP_OUTPUT_PATH: String = "res://production/qa/evidence/story-u011-hand-bar-s5-locked-crop-2026-09-17.png"
const TARGET_SIZE: Vector2i = Vector2i(1920, 1080)

## Breathing-room margin (fpx) around HandBar's visual bounding box for the
## saved crop images (Check C reads pixels from these, not the full frame).
const CROP_MARGIN_FPX: float = 0.5

## Minimum luminance delta (HSV value, 0..1) counted as "a real difference",
## for Checks A and B below. Not a spec number — a judgment call sized well
## above float/PNG-compression noise (typical noise floor observed in this
## project's other screenshot work is well under 0.01).
const LUMINANCE_DELTA_THRESHOLD: float = 0.03


func _ready() -> void:
	await get_tree().process_frame

	var s7_img: Image = await _capture_s7()
	var s5_img: Image = await _capture_s5()

	var fpx: float = float(HudLayout.font_size(TARGET_SIZE))
	var bar_rect: Rect2 = HandBar.slot_bar_rect(TARGET_SIZE, CardDeck.HAND_SIZE_LIMIT)

	print("=== Story U-011 evidence capture — directional checks ===")
	var check_a_s7: bool = _check_a_slot_outlines_at_layout_positions(s7_img, bar_rect, fpx, "S7")
	var check_a_s5: bool = _check_a_slot_outlines_at_layout_positions(s5_img, bar_rect, fpx, "S5")
	var check_b: bool = _check_b_lock_glyph_present_in_s5(s5_img, bar_rect, fpx)
	var check_c: bool = _check_c_non_uniform_difference()

	var s7_whole_frame_ok: bool = _dimensions_ok(s7_img)
	var s5_whole_frame_ok: bool = _dimensions_ok(s5_img)

	print("--- summary ---")
	print("S7 whole-frame dimensions ok = ", s7_whole_frame_ok)
	print("S5 whole-frame dimensions ok = ", s5_whole_frame_ok)
	print("Check A (slot outlines at layout position) S7 = ", check_a_s7, " S5 = ", check_a_s5)
	print("Check B (S5 lock glyph positively present) = ", check_b)
	print("Check C (crop difference is non-uniform, not just a brightness shift) = ", check_c)

	var all_ok: bool = (
		s7_whole_frame_ok and s5_whole_frame_ok and check_a_s7 and check_a_s5 and check_b and check_c
	)
	get_tree().quit(0 if all_ok else 1)


func _capture_s7() -> Image:
	# 走完整、真正的正式場景 —— 不是複本。
	var battle_scene: Node = load("res://src/ui/battle/BattleScreen.tscn").instantiate()
	get_tree().root.add_child(battle_scene)
	await get_tree().process_frame
	await _resize_and_settle(TARGET_SIZE)

	# 覆寫成零張牌的 CardDeck —— GDD 明文合法的 pool_size=0 邊界情形。固定種子
	# 純粹是為了與 CardDeck._init() 簽章慣例一致、可重現(空池本身不會抽牌,
	# 種子在這裡不影響結果)。
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20260917
	var empty_deck: CardDeck = BattleScreen._build_card_deck([], rng)
	battle_scene._state.attach_card_deck(empty_deck)
	battle_scene._refresh_view()
	await get_tree().process_frame

	var img: Image = get_viewport().get_texture().get_image()
	_report_whole_frame_rule_1_to_3(img, "S7")
	DirAccess.make_dir_recursive_absolute(S7_OUTPUT_PATH.get_base_dir())
	img.save_png(S7_OUTPUT_PATH)
	_save_crop(img, S7_CROP_OUTPUT_PATH)

	get_tree().root.remove_child(battle_scene)
	battle_scene.free()
	return img


# S5 不經過完整 BattleScreen — battle_screen.gd(926-930 行)"Synchronous by
# design" 註解與全庫 grep -rn "await " src/ --include=*.gd(僅 1 個命中且在
# 註解裡)已確認 ENEMY_ACTING 在現行遊戲不會產生任何可擷取畫格。這張圖只證明
# HandBar 收到 LOCKED 會畫成什麼樣子,不證明現行遊戲跑得到這個畫面(見
# README.md / 本檔開頭)。
func _capture_s5() -> Image:
	var hand_bar: HandBar = load("res://src/ui/battle/HandBar.tscn").instantiate()
	get_tree().root.add_child(hand_bar)
	await get_tree().process_frame
	await _resize_and_settle(TARGET_SIZE)

	hand_bar.render([], CardDeck.HAND_SIZE_LIMIT, HandBar.Availability.LOCKED)
	await get_tree().process_frame

	var img: Image = get_viewport().get_texture().get_image()
	_report_whole_frame_rule_1_to_3(img, "S5")
	DirAccess.make_dir_recursive_absolute(S5_OUTPUT_PATH.get_base_dir())
	img.save_png(S5_OUTPUT_PATH)
	_save_crop(img, S5_CROP_OUTPUT_PATH)

	get_tree().root.remove_child(hand_bar)
	hand_bar.free()
	return img


func _resize_and_settle(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	for i in range(10):
		await get_tree().process_frame


func _dimensions_ok(img: Image) -> bool:
	return img.get_size() == TARGET_SIZE


# coding-standards.md Screenshot Evidence Rules #1-#3 — applied ONLY to the
# two full-window captures (2026-09-17 second coordinator ruling: this is
# what the rule is calibrated against; do not apply it to the crops, and do
# not weaken it to make a narrower capture pass).
func _report_whole_frame_rule_1_to_3(img: Image, label: String) -> void:
	var actual_size: Vector2i = img.get_size()
	print("--- %s whole frame ---" % label)
	print("target size = ", TARGET_SIZE, " captured size = ", actual_size, " match = ", actual_size == TARGET_SIZE)

	var sample_points: Array[Vector2i] = []
	for i in range(4):
		for j in range(3):
			sample_points.append(Vector2i(
				int((float(i) + 0.5) / 4.0 * actual_size.x),
				int((float(j) + 0.5) / 3.0 * actual_size.y)
			))
	var color_counts: Dictionary = {}
	for p: Vector2i in sample_points:
		color_counts[img.get_pixelv(p).to_html(false)] = true
	print("12-point sample distinct colors = ", color_counts.size(), " (rule requires >= 3)")

	var histogram: Dictionary = {}
	var step: int = 4
	var sampled_total: int = 0
	for y in range(0, actual_size.y, step):
		for x in range(0, actual_size.x, step):
			var key: String = img.get_pixel(x, y).to_html(false)
			histogram[key] = histogram.get(key, 0) + 1
			sampled_total += 1
	var dominant_count: int = 0
	for key: String in histogram:
		if histogram[key] > dominant_count:
			dominant_count = histogram[key]
	var dominant_share: float = float(dominant_count) / float(sampled_total) if sampled_total > 0 else 1.0
	print("dominant color share (subsampled every %dpx) = %.4f (rule requires <= 0.80)" % [step, dominant_share])


func _save_crop(img: Image, output_path: String) -> void:
	var fpx: float = float(HudLayout.font_size(TARGET_SIZE))
	var bar_rect: Rect2 = HandBar.slot_bar_rect(TARGET_SIZE, CardDeck.HAND_SIZE_LIMIT)
	var margin: float = CROP_MARGIN_FPX * fpx

	var caption_top: float = -(
		(HandBar.CAPTION_GAP_FPX_MULTIPLIER + HandBar.CAPTION_HEIGHT_FPX_MULTIPLIER) * fpx
	)
	var lock_glyph_left: float = -(
		(HandBar.LOCK_GLYPH_SIZE_FPX_MULTIPLIER + HandBar.LOCK_GLYPH_GAP_FPX_MULTIPLIER) * fpx
	)

	var local_left: float = minf(0.0, lock_glyph_left)
	var local_top: float = caption_top
	var local_right: float = bar_rect.size.x
	var local_bottom: float = bar_rect.size.y

	var crop_rect: Rect2i = Rect2i(
		Vector2i(bar_rect.position) + Vector2i(int(local_left - margin), int(local_top - margin)),
		Vector2i(
			int(local_right - local_left + margin * 2.0),
			int(local_bottom - local_top + margin * 2.0)
		)
	)
	crop_rect = crop_rect.intersection(Rect2i(Vector2i.ZERO, TARGET_SIZE))
	var crop: Image = img.get_region(crop_rect)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	crop.save_png(output_path)


# Check A — for each of the 5 empty-slot outlines, sample a small vertical
# band at the slot's LAYOUT-COMPUTED top-edge x/y (HandBar.slot_rect()) and
# compare against that SAME slot's own interior point (no border there) —
# self-contained per image, no cross-image background assumption. A genuine
# border pixel reads as a luminance jump versus the transparent interior a
# few pixels away.
func _check_a_slot_outlines_at_layout_positions(
	img: Image, bar_rect: Rect2, fpx: float, label: String
) -> bool:
	var found_count: int = 0
	for i in range(CardDeck.HAND_SIZE_LIMIT):
		var r: Rect2 = HandBar.slot_rect(i, TARGET_SIZE)
		var x: int = int(bar_rect.position.x + r.position.x + r.size.x / 2.0)
		var interior_y: int = int(bar_rect.position.y + r.size.y / 2.0)
		var interior_v: float = img.get_pixel(x, interior_y).v

		var best_delta: float = 0.0
		for edge_offset in range(0, 3):
			var edge_y: int = int(bar_rect.position.y + r.position.y) + edge_offset
			var edge_v: float = img.get_pixel(x, edge_y).v
			best_delta = maxf(best_delta, absf(edge_v - interior_v))

		var found: bool = best_delta >= LUMINANCE_DELTA_THRESHOLD
		print(
			"%s slot %d: top-edge/interior luminance delta = %.4f (threshold %.2f) -> %s"
			% [label, i, best_delta, LUMINANCE_DELTA_THRESHOLD, "found" if found else "NOT FOUND"]
		)
		if found:
			found_count += 1

	print("%s: %d/%d slot outlines found at their layout-computed position" % [
		label, found_count, CardDeck.HAND_SIZE_LIMIT
	])
	return found_count == CardDeck.HAND_SIZE_LIMIT


# Check B — S5 only, positive presence check: the lock glyph's own rect
# (computed from the exact constants hand_bar.gd itself uses) must be
# measurably brighter than a reference point guaranteed to be pure background
# in this capture (S5 is an isolated HandBar on an otherwise blank window —
# any far corner is background). See this file's class doc comment for why
# there is no equivalent "absent in S7" pixel check (arbitrary board content
# behind that screen position in S7) and where that half is proven instead.
func _check_b_lock_glyph_present_in_s5(img: Image, bar_rect: Rect2, fpx: float) -> bool:
	var caption_top: float = -(
		(HandBar.CAPTION_GAP_FPX_MULTIPLIER + HandBar.CAPTION_HEIGHT_FPX_MULTIPLIER) * fpx
	)
	var lock_glyph_left: float = -(
		(HandBar.LOCK_GLYPH_SIZE_FPX_MULTIPLIER + HandBar.LOCK_GLYPH_GAP_FPX_MULTIPLIER) * fpx
	)
	var lock_glyph_size: float = HandBar.LOCK_GLYPH_SIZE_FPX_MULTIPLIER * fpx

	var center_x: int = int(bar_rect.position.x + lock_glyph_left + lock_glyph_size / 2.0)
	var center_y: int = int(bar_rect.position.y + caption_top + lock_glyph_size / 2.0)
	var lock_v: float = img.get_pixel(center_x, center_y).v

	var reference_v: float = img.get_pixel(5, 5).v

	var delta: float = lock_v - reference_v
	print(
		"S5 lock glyph center luminance = %.4f, far-corner background reference = %.4f, delta = %.4f (threshold %.2f)"
		% [lock_v, reference_v, delta, LUMINANCE_DELTA_THRESHOLD]
	)
	return delta >= LUMINANCE_DELTA_THRESHOLD


# Check C — standard deviation of the per-pixel luminance difference between
# the two saved crops. A pure "uniform dimming" (contrast channel alone,
# nothing else different) would make every pixel's difference close to the
# SAME constant, so the standard deviation would be near zero; a genuinely
# structural difference (lock glyph / caption present in one, absent in the
# other) produces some pixels that differ a lot and others that barely
# differ, so the standard deviation is well above zero.
func _check_c_non_uniform_difference() -> bool:
	var s7: Image = Image.load_from_file(S7_CROP_OUTPUT_PATH)
	var s5: Image = Image.load_from_file(S5_CROP_OUTPUT_PATH)
	if s7 == null or s5 == null:
		print("Check C: failed to load one or both crop PNGs")
		return false

	var w: int = mini(s7.get_width(), s5.get_width())
	var h: int = mini(s7.get_height(), s5.get_height())
	if w <= 0 or h <= 0:
		print("Check C: zero-sized overlap between the two crops")
		return false

	var diffs: Array[float] = []
	var sum: float = 0.0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var d: float = absf(s7.get_pixel(x, y).v - s5.get_pixel(x, y).v)
			diffs.append(d)
			sum += d

	if diffs.is_empty():
		print("Check C: zero sampled pixels")
		return false

	var mean: float = sum / float(diffs.size())
	var variance_sum: float = 0.0
	for d: float in diffs:
		variance_sum += (d - mean) * (d - mean)
	var stddev: float = sqrt(variance_sum / float(diffs.size()))

	print("Check C: crop diff mean = %.4f, stddev = %.4f (n=%d samples)" % [mean, stddev, diffs.size()])
	# Non-zero threshold sized to distinguish "genuinely uniform" (stddev would
	# sit within float/PNG-compression noise, well under 0.01) from "has real
	# structure" — not a spec number, a judgment call matching
	# LUMINANCE_DELTA_THRESHOLD's own noise-floor reasoning.
	return stddev >= 0.02
