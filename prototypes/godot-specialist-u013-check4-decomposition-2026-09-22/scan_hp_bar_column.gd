extends SceneTree
# Throwaway follow-up: raw pixel dump through the legal cell's HP bar column,
# to see whether the y=220/y=226 "other"-bucket violations found by
# decompose_check4.gd are a hard single-row anomaly or a genuine partial-
# coverage (sub-pixel) blend. Pure Image API read-back of the same already-
# rendered real PNG -- no rendering involved, headless is fine.
const CONTEXT_IMG_PATH: String = "res://prototypes/u013-highlight-evidence-2026-09-22/diagnostic-context-full-window-2026-09-22-CHECK4-FAILED.png"

func _init() -> void:
	var img: Image = Image.load_from_file(CONTEXT_IMG_PATH)
	for x in [440, 460]:
		print("--- column x=", x, " ---")
		for y in range(214, 230):
			print("  y=", y, " -> ", img.get_pixel(x, y))
	quit()
