## Throwaway headless probe — does appending a "結束單位 Q/Back" caption to
## TEXT_CONTROLS_HINT's existing 2nd line still fit inside ControlsHintLabel's
## real width at every resolution, without forcing a 3rd line?
##
## Calls the REAL production classes (HudLayout.font_size / .controls_hint_bg_rect,
## WorldLayout.compute_scale underneath) rather than re-deriving the formula —
## per technical-preferences.md's "(A) 的精確定義" discipline. Font measurement
## uses the real engine Font.get_string_size(), not a hand-estimated char count,
## same method prototypes/story-002-font-scale-spike-2026-09-04/font_scale_probe.gd
## already established.
extends SceneTree

const FONT_PATH: String = "res://assets/fonts/Cubic_11.ttf"

const LINE2_CURRENT: String = "開/收手牌 C/X　跳目標 Tab/RB　選單 M/Start"
const LINE2_CANDIDATE_APPENDED: String = "開/收手牌 C/X　跳目標 Tab/RB　選單 M/Start　結束單位 Q/Back"

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

func _initialize() -> void:
	var font: FontFile = load(FONT_PATH)
	if font == null:
		print("字型載入失敗,中止")
		quit(1)
		return

	print("resolution,font_px,safe_w,line2_current_w,line2_appended_w,current_fits,appended_fits")
	for res: Vector2i in RESOLUTIONS:
		var fpx: int = HudLayout.font_size(res)
		var safe_w: float = HudLayout.controls_hint_bg_rect(res).size.x
		var cur_w: float = font.get_string_size(LINE2_CURRENT, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
		var app_w: float = font.get_string_size(LINE2_CANDIDATE_APPENDED, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
		print("%dx%d,%d,%.1f,%.1f,%.1f,%s,%s" % [
			res.x, res.y, fpx, safe_w, cur_w, app_w,
			str(cur_w <= safe_w), str(app_w <= safe_w)
		])
	quit()
