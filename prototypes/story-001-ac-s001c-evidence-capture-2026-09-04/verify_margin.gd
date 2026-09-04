extends SceneTree
func _initialize() -> void:
	var img: Image = Image.load_from_file("res://production/qa/evidence/screen-scaling-2k-window-capture-2026-09-04.png")
	print("image size = ", img.get_size())
	# Expected world rect at 2560x1440 per WorldLayout: (80,45)-(2480,1395)
	var checks: Array = [
		["just left of world rect (79,720)", Vector2i(79, 720)],
		["just inside world rect left edge (81,720)", Vector2i(81, 720)],
		["just above world rect (1280,44)", Vector2i(1280, 44)],
		["just inside world rect top edge (1280,46)", Vector2i(1280, 46)],
		["just right of world rect (2481,720)", Vector2i(2481, 720)],
		["just inside world rect right edge (2478,720)", Vector2i(2478, 720)],
		["just below world rect (1280,1396)", Vector2i(1280, 1396)],
		["just inside world rect bottom edge (1280,1393)", Vector2i(1280, 1393)],
	]
	for c: Array in checks:
		var p: Vector2i = c[1]
		print(c[0], " -> ", img.get_pixelv(p))
	quit(0)
