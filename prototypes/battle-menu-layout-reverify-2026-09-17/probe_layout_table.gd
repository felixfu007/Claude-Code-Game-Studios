# 拋棄式探針:複驗 design/ux/battle-menu.md 「四種螢幕 × 三個字級檔位」表。
#
# 🔴 本探針【呼叫專案自己的類別】,不重新實作任何一條規則 ——
#    HudLayout.font_size() / HudLayout.safe_rect() 皆為直接呼叫。
#    唯一由本檔提供的,是 battle-menu.md「Layout Zones」表明文寫下的 fpx 倍數
#    (M1 = 10×9 fpx、M4 = 14×7 fpx)與無障礙 150% 字級係數 —— 這三項是【文件常數】,
#    不是程式規則,故不存在「第二份實作」的問題。逐條來源:
#      - M1 寬 10 fpx / 高 9 fpx  ← battle-menu.md, Layout Zones 表, M1 列
#      - M4 寬 14 fpx / 高 7 fpx  ← battle-menu.md, Layout Zones 表, M4 列
#      - 150% 係數 1.5            ← battle-menu.md, 表標題「判準同 skill-card-play.md:150% 仍不得溢出」
#
# 刻意未計入:M2 項目列高度、M3 原因文字、實際字串寬度。本表驗的是面板外框,不是內容。
extends SceneTree

const SCREENS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const M1_W_FPX: float = 10.0
const M1_H_FPX: float = 9.0
const M4_W_FPX: float = 14.0
const M4_H_FPX: float = 7.0
const SCALE_150: float = 1.5


func _init() -> void:
	print("screen | fpx | safe_rect | M1(100%) | M1(150%) | M4(150%) | fits_safe?")
	for s: Vector2i in SCREENS:
		var fpx: int = HudLayout.font_size(s)
		var safe: Rect2 = HudLayout.safe_rect(s)
		var m1_100 := Vector2(M1_W_FPX * fpx, M1_H_FPX * fpx)
		var m1_150 := Vector2(M1_W_FPX * SCALE_150 * fpx, M1_H_FPX * SCALE_150 * fpx)
		var m4_150 := Vector2(M4_W_FPX * SCALE_150 * fpx, M4_H_FPX * SCALE_150 * fpx)
		var fits: bool = (
			m1_150.x <= safe.size.x and m1_150.y <= safe.size.y
			and m4_150.x <= safe.size.x and m4_150.y <= safe.size.y
		)
		print("%dx%d | %d | %.1fx%.1f | %.1fx%.1f | %.1fx%.1f | %.1fx%.1f | %s" % [
			s.x, s.y, fpx,
			safe.size.x, safe.size.y,
			m1_100.x, m1_100.y,
			m1_150.x, m1_150.y,
			m4_150.x, m4_150.y,
			str(fits),
		])
	print("--- 非整數值逐一列出(表格捨入爭議點)---")
	for s: Vector2i in SCREENS:
		var fpx: int = HudLayout.font_size(s)
		for label: String in ["M1_150_h", "M4_150_h"]:
			var v: float = (M1_H_FPX if label == "M1_150_h" else M4_H_FPX) * SCALE_150 * fpx
			if not is_equal_approx(v, floorf(v)):
				print("%dx%d %s = %.2f  (floor=%d ceil=%d)" % [s.x, s.y, label, v, int(floorf(v)), int(ceilf(v))])
	quit()
