extends Node2D
const W := 170
const H := 64
const CHECKS := [
	["TL", Vector2i(42,16), Color(1,0,0)],
	["TR", Vector2i(127,16), Color(0,1,0)],
	["BL", Vector2i(42,48), Color(0,0,1)],
	["BR", Vector2i(127,48), Color(1,1,0)],
	["cTL", Vector2i(0,0), Color(1,0,1)],
	["cTR", Vector2i(169,0), Color(1,0,1)],
	["cBL", Vector2i(0,63), Color(1,0,1)],
	["cBR", Vector2i(169,63), Color(1,0,1)],
]
func _init() -> void:
	DisplayServer.window_set_title("tmp")
	print("INIT_WINDOW_MODE=", DisplayServer.window_get_mode())
func _draw() -> void:
	draw_rect(Rect2(0,0,85,32), Color(1,0,0))
	draw_rect(Rect2(85,0,85,32), Color(0,1,0))
	draw_rect(Rect2(0,32,85,32), Color(0,0,1))
	draw_rect(Rect2(85,32,85,32), Color(1,1,0))
	for p in [Vector2(0,0), Vector2(168,0), Vector2(0,62), Vector2(168,62)]:
		draw_rect(Rect2(p, Vector2(2,2)), Color(1,0,1))
func _ready() -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("AUDIO_DRIVER_CURRENT=", AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "n/a")
	print("WINDOW_MODE_READBACK=", DisplayServer.window_get_mode(), " (1=MINIMIZED)")
	print("WINDOW_SIZE=", DisplayServer.window_get_size())
	var img: Image = get_viewport().get_texture().get_image()
	print("IMAGE_IS_NULL=", img == null)
	if img != null:
		print("IMAGE_SIZE=", img.get_size())
		var ok := 0
		for c in CHECKS:
			var a: Color = img.get_pixelv(c[1]) if img.get_width() > c[1].x and img.get_height() > c[1].y else Color(-1,-1,-1)
			var p: bool = a.is_equal_approx(c[2])
			if p: ok += 1
			print("CHECK ", c[0], " pos=", c[1], " expect=", c[2], " actual=", a, " pass=", p)
		print("RESULT=", "PASS" if ok == 8 else "FAIL", " ", ok, "/8")
	get_tree().quit()
