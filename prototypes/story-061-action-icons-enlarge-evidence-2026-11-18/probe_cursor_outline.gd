extends SceneTree
## story-061 AC1: measure the real cursor_outline.png (frame thickness + placement).
## The PNG is fully non-transparent (alpha > 0 everywhere), so print per-pixel alpha/colour along row 16.
## Run: <godot> --headless --path . -s res://prototypes/story-061-action-icons-enlarge-evidence-2026-11-18/probe_cursor_outline.gd


func _init() -> void:
	var tex: Texture2D = load(BoardView.CURSOR_PATH)
	var img: Image = tex.get_image()
	print("CURSOR size=", img.get_size())
	for x: int in range(img.get_width()):
		print("CURSOR row16 x=", x, " ", img.get_pixel(x, 16).to_html(true))
	for y: int in range(6):
		print("CURSOR col16 y=", y, " ", img.get_pixel(16, y).to_html(true))
	quit()
