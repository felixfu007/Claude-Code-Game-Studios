extends SceneTree
## story-053 截圖驅動(2026-11-16):結束角色行動按鈕 啟用/禁用/變淡。
## 規則:load() 真實 BattleScreen.tscn -> instantiate -> call_deferred add_child -> 等幀(technical-preferences 第 5 點)。
## 拍:啟用、禁用(無選取)、禁用+高亮壓框變淡、啟用+變淡;960x540 與 1920x1080。
## 用法(開窗):godot --path . -s res://prototypes/story-053-end-action-capture-2026-11-16/driver.gd
## headless 下 get_image() 為 null 屬正常,只驗流程與狀態物證。內建 WATCHDOG 120 秒。
const OUT_DIR: String = "res://prototypes/story-053-end-action-capture-2026-11-16/out/"
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
var _headless: bool = false

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("WATCHDOG fired -> quit(2)")
		quit(2))
	_run()

func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame

func _shot(inst: Node, size: Vector2i, tag: String) -> void:
	await _frames(3)
	if not _headless:
		await RenderingServer.frame_post_draw
	var b: Button = inst._end_action_button
	var r: Rect2 = HudLayout.hud_action_button_rect(size, HudLayout.END_ACTION_BUTTON_INDEX)
	print("STATE [%s %s] disabled=%s text='%s' tooltip='%s' modulate_a=%.2f rect=%s border_w_disabled=%d" % [
		size, tag, b.disabled, b.text, b.tooltip_text, b.modulate.a, r,
		(b.get_theme_stylebox(&"disabled") as StyleBoxFlat).border_width_left])
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("SHOT %s -> get_image() is null (expected under headless)" % tag)
		return
	var full: String = "%dx%d_%s.png" % [size.x, size.y, tag]
	print("SHOT %s save_err=%d" % [full, img.save_png(ProjectSettings.globalize_path(OUT_DIR + full))])
	# Category C 裁切:取樣區由真實矩形函式決定。
	var crop: Image = img.get_region(Rect2i(r.grow(4.0)))
	crop.save_png(ProjectSettings.globalize_path(OUT_DIR + "crop_" + full))

func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	print("DISPLAY_SERVER=", DisplayServer.get_name())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for size: Vector2i in [Vector2i(960, 540), Vector2i(1920, 1080)]:
		root.size = size
		await _frames(3)
		var inst: Node = (load(SCENE) as PackedScene).instantiate()
		root.call_deferred("add_child", inst)
		await _frames(12)
		print("HOST [%s] root.size=%s" % [size, root.size])
		await _shot(inst, size, "disabled_no_selection")
		var ids: Array[int] = inst._controller.selectable_units()
		inst._controller.select_unit(ids[0])
		await _frames(3)
		await _shot(inst, size, "enabled_selected")
		# 變淡:用真實函式的輸出值(高亮格壓到說明列)—— 直接設 HUD 變淡 alpha 以拍最壞情況。
		inst._set_frame_alpha(inst._end_action_button, HudLayout.OVERLAP_FADE_ALPHA)
		await _shot(inst, size, "enabled_faded")
		inst._controller.deselect()
		inst._refresh_view()
		await _frames(3)
		await _shot(inst, size, "disabled_faded")
		inst.queue_free()
		await _frames(3)
	quit(0)
