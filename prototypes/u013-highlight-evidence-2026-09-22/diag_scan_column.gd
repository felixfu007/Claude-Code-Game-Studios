extends SceneTree
# Throwaway diagnostic (headless is fine here -- reading pixels back out of an
# already-saved PNG is pure Image API, no rendering/input pipeline involved).
# Scans a vertical column at the legal cell's expected x, and one at the
# illegal cell's expected x, printing every pixel from y=0..80 so the actual
# on-disk pixel data (not a possibly-resized terminal preview) tells us where
# the white outline band really sits in u013-card-target-highlight-2026-09-22.png.
func _init() -> void:
	var img: Image = Image.load_from_file("res://production/qa/evidence/u013-card-target-highlight-2026-09-22.png")
	print("crop image size = ", img.get_size())
	for x in [96, 352]:
		print("--- column x=", x, " ---")
		for y in range(0, 90, 2):
			print("  y=", y, " -> ", img.get_pixel(x, y))
	quit()
