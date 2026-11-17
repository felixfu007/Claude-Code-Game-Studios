extends SceneTree
## story-060 AC7 開窗實拍:真實 BattleScreen.tscn(預設資料,不注入),開場 8 秒內開戰鬥選單,
## 960x540 與 1920x1080 各一張。load -> instantiate -> call_deferred add_child -> 等幀(第 5 點)。
## 宿主鏈量測值(WVC position/size/stretch_shrink、WorldViewport.size)與面板/選單矩形一併印出。
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const OUT_DIR: String = "res://prototypes/story-060-objective-menu-evidence-2026-11-17/out/"

func _initialize() -> void:
	create_timer(50.0).timeout.connect(func() -> void:
		paused = false
		quit(2))
	_run()

func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame

func _run() -> void:
	root.title = "x"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	print("DISPLAY_SERVER=", DisplayServer.get_name())
	for sz: Vector2i in [Vector2i(960, 540), Vector2i(1920, 1080)]:
		for t: int in range(5):
			root.size = sz
			await _frames(5)
			if root.size == sz:
				break
		var inst: Node = (load(SCENE) as PackedScene).instantiate()
		root.call_deferred("add_child", inst)
		await _frames(12)
		print("[%s] objective visible after load = %s" % [str(root.size), inst.is_objective_visible()])
		inst._handle_battle_menu_pressed()
		await _frames(5)
		await RenderingServer.frame_post_draw
		var c: SubViewportContainer = inst.get_node("WorldViewportContainer")
		var v: SubViewport = inst.get_node("WorldViewportContainer/WorldViewport")
		var t: Timer = inst.get_node("ObjectiveTimer")
		print("HOST [%s] WVC position=%s size=%s stretch_shrink=%d WorldViewport.size=%s" % [
			str(root.size), str(c.position), str(c.size), c.stretch_shrink, str(v.size)])
		print("FACTS [%s] paused=%s menu.visible=%s objective_visible=%s timer.is_stopped=%s return_row_rect=%s" % [
			str(root.size), paused, inst._battle_menu.visible, inst.is_objective_visible(), t.is_stopped(),
			str(inst._battle_menu._return_row.get_global_rect())])
		var img: Image = root.get_texture().get_image()
		if img == null:
			print("SHOT null")
		else:
			var f: String = "%dx%d_menu_open_within_8s.png" % [root.size.x, root.size.y]
			print("SHOT ", f, " ", img.get_size(), " save=", img.save_png(ProjectSettings.globalize_path(OUT_DIR + f)))
		paused = false
		inst.queue_free()
		await _frames(3)
	quit()
