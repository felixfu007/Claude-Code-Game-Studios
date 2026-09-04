## 量測目的:對三個候選 HUD 字級規則,在 8 個解析度(5 個規格明文列舉 + 3 個規格明文
## 標為「已知未定義」的邊界)下,算出整數倍率 N、字級 px、真實文字(取自
## src/ui/battle/battle_screen.gd 的常數,非杜撰句子)用 Cubic 11 實際渲染出的寬高、
## 佔螢幕高度百分比、以及是否放得進 title-safe 安全區(每邊內縮 5%,見
## design/art/art-direction.md 第六節)。
##
## 🔴 本腳本自己實作三條候選公式(N 的算法)——這不是「重新實作規則來源」,因為 N 的算法
## 本身就是本次要交付的候選方案(沒有既有類別可以呼叫)。但「字串實際渲染尺寸」一項改為
## 呼叫引擎 Font.get_string_size(),不自己用字元數估寬 —— 避免像 2026-08-31 那次 awk
## 棋盤量測一樣,重新發明一份跟真實引擎行為不一致的規則。
extends SceneTree

const FONT_PATH: String = "res://assets/fonts/Cubic_11.ttf"
const GLYPH_PX: int = 11  # Cubic 11 原生點陣格

# 真實文字,逐字抄自 src/ui/battle/battle_screen.gd 的常數(見該檔行號於下方註解)。
const TEXT_STATUS: String = "第 12 回合．我方行動"        # TEXT_STATUS_FORMAT % [12, TEXT_FACTION_PLAYER] (行 104-106)
const TEXT_INFO: String = "打擊 128　血量 240→112"          # TEXT_DAMAGE_PREVIEW_FORMAT 代入樣本數字 (行 119)
const TEXT_CONTROLS_HINT: String = "移動 方向鍵/十字鍵/滑鼠　確認 Enter/A/左鍵　結束回合 Esc/B"  # TEXT_CONTROLS_HINT (行 173),派工單點名的「最長提示文字」
const TEXT_RESULT: String = "勝利"                          # TEXT_RESULT_VICTORY (行 107),2 字,僅列出不列入安全區風險判定

# 解析度清單:5 個規格明文列舉 + 3 個規格明文標為「已知未定義」的邊界。
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(2560, 1080),
]
const DEFINED_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(2560, 1440),
	Vector2i(3440, 1440), Vector2i(3840, 2160),
]


## 候選 A ——「鎖定世界層倍率」:與 world_layout.gd 的世界層整數倍規則同一條公式
## (取塞得下的最大整數倍),HUD 字級 = 11 × 該倍率。
static func candidate_a_n(w: int, h: int) -> int:
	var n_w: int = int(floor(float(w) / 480.0))
	var n_h: int = int(floor(float(h) / 270.0))
	return max(2, min(n_w, n_h))


## 候選 B ——「高度分段、成長趨緩且封頂」:只看高度(不看寬度),公式
## N = clamp(floor(H/300)+1, 2, 6)。封頂在 6(66px)是刻意的設計判斷,理由是質疑
## 「4K 上 88px 的 HUD 文字是否真的需要跟棋盤像素同步放大那麼多」——這是候選方案要交給
## 管理者裁決的判斷,不是既定事實。
static func candidate_b_n(_w: int, h: int) -> int:
	var raw: int = int(floor(float(h) / 300.0)) + 1
	return clampi(raw, 2, 6)


## 候選 C ——「固定佔螢幕高度目標比例、就近取整」:目標高度佔比 3%,
## N = clamp(round(H*0.03/11), 2, 7)。與候選 A/B 的差異在於它用 round 而非 floor,
## 且目標比例本身('3%')是一個可調參數,非既定事實——標號選 3% 只是示範一個
## 比候選 A 的穩態值(~4.07%,見下方 log)更保守的起點。
static func candidate_c_n(_w: int, h: int) -> int:
	var raw: float = (float(h) * 0.03) / 11.0
	return clampi(int(round(raw)), 2, 7)


func _initialize() -> void:
	var font: FontFile = load(FONT_PATH)
	if font == null:
		print("🔴 字型載入失敗,中止")
		quit(1)
		return
	print("字型載入成功:font_name=%s" % font.font_name)
	print("")

	_run_all(font)
	quit()


func _run_all(font: FontFile) -> void:
	print("=== 逐解析度 × 候選規則 × N 值 ===")
	print("resolution,candidate,N,font_px,scale_pct_of_height")
	for res: Vector2i in RESOLUTIONS:
		var w: int = res.x
		var h: int = res.y
		var n_a: int = candidate_a_n(w, h)
		var n_b: int = candidate_b_n(w, h)
		var n_c: int = candidate_c_n(w, h)
		_print_row(res, "A_board_locked", n_a, h)
		_print_row(res, "B_height_capped", n_b, h)
		_print_row(res, "C_percent_round", n_c, h)

	print("")
	print("=== 真實字串渲染尺寸(Font.get_string_size,Cubic 11)===")
	print("resolution,candidate,N,font_px,text_label,measured_w,measured_h")
	for res: Vector2i in RESOLUTIONS:
		var w: int = res.x
		var h: int = res.y
		for pair: Array in [
			["A_board_locked", candidate_a_n(w, h)],
			["B_height_capped", candidate_b_n(w, h)],
			["C_percent_round", candidate_c_n(w, h)],
		]:
			var cand_name: String = pair[0]
			var n: int = pair[1]
			var font_px: int = GLYPH_PX * n
			for text_pair: Array in [
				["StatusLabel", TEXT_STATUS],
				["InfoLabel", TEXT_INFO],
				["ControlsHintLabel", TEXT_CONTROLS_HINT],
				["ResultLabel", TEXT_RESULT],
			]:
				var label_name: String = text_pair[0]
				var text: String = text_pair[1]
				var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
				print("%dx%d,%s,%d,%d,%s,%.1f,%.1f" % [w, h, cand_name, n, font_px, label_name, size.x, size.y])

	print("")
	print("=== 安全區(title-safe,每邊內縮 5%)寬度是否放得下 ControlsHintLabel ===")
	print("resolution,candidate,N,font_px,safe_area_w,measured_w,fits")
	for res: Vector2i in RESOLUTIONS:
		var w: int = res.x
		var h: int = res.y
		var safe_w: float = float(w) * 0.9
		for pair: Array in [
			["A_board_locked", candidate_a_n(w, h)],
			["B_height_capped", candidate_b_n(w, h)],
			["C_percent_round", candidate_c_n(w, h)],
		]:
			var cand_name: String = pair[0]
			var n: int = pair[1]
			var font_px: int = GLYPH_PX * n
			var size: Vector2 = font.get_string_size(TEXT_CONTROLS_HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
			var fits: bool = size.x <= safe_w
			print("%dx%d,%s,%d,%d,%.1f,%.1f,%s" % [w, h, cand_name, n, font_px, safe_w, size.x, str(fits)])


func _print_row(res: Vector2i, cand_name: String, n: int, h: int) -> void:
	var font_px: int = GLYPH_PX * n
	var pct: float = (float(font_px) / float(h)) * 100.0
	print("%dx%d,%s,%d,%d,%.2f%%" % [res.x, res.y, cand_name, n, font_px, pct])
