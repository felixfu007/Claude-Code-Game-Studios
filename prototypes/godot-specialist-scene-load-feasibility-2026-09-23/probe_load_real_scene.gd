extends Node
## Throwaway feasibility probe for the 2026-09-23 manager ruling (Batch 58,
## item 1): "評估腳本必須直接載入真實畫面檔". This does the simplest possible
## thing that could answer that question: load()+instantiate() the REAL
## res://src/ui/battle/BattleScreen.tscn -- not a rebuilt subtree, not a copy
## -- and see what happens, in both --headless and windowed runs.
##
## Run shape (mode passed via user args after `--`):
##   "<godot>" --headless --path . prototypes/godot-specialist-scene-load-feasibility-2026-09-23/ProbeLoadRealScene.tscn -- --mode=headless
##   "<godot>" --path . prototypes/godot-specialist-scene-load-feasibility-2026-09-23/ProbeLoadRealScene.tscn -- --mode=windowed
##
## Deliberately does NOT touch project.godot's run/main_scene (already IS
## BattleScreen.tscn) -- this probe is run as an explicit scene-path CLI
## argument instead, which overrides the main scene for this invocation only.

const BATTLE_SCREEN_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const OUT_DIR: String = "res://prototypes/godot-specialist-scene-load-feasibility-2026-09-23/"

var _mode_label: String = "unknown"


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode_label = arg.substr("--mode=".length())

	print("=== PROBE START mode=", _mode_label, " DisplayServer.get_name()=", DisplayServer.get_name(), " ===")
	print("Q1: CursorStateHost autoload present at /root? ", get_tree().root.has_node("CursorStateHost"))

	# ---------------------------------------------------------------
	# Q1 -- can a throwaway script load() + instantiate() the REAL
	# BattleScreen.tscn and get it running?
	# ---------------------------------------------------------------
	print("Q1: calling load(\"", BATTLE_SCREEN_PATH, "\")")
	var packed: PackedScene = load(BATTLE_SCREEN_PATH)
	print("Q1: load() returned null? ", packed == null)
	if packed == null:
		push_error("PROBE ABORT: load() returned null for BattleScreen.tscn")
		get_tree().quit(1)
		return

	print("Q1: calling packed.instantiate()")
	var battle: Node = packed.instantiate()
	print("Q1: instantiate() returned null? ", battle == null)
	if battle == null:
		push_error("PROBE ABORT: instantiate() returned null")
		get_tree().quit(1)
		return
	print("Q1: instantiated node class=", battle.get_class(), " name=", battle.name, " script=", battle.get_script())

	print("Q1: calling get_tree().root.add_child(battle) -- this is where _init()/_ready() run")
	get_tree().root.add_child(battle)
	print("Q1: add_child() returned. battle.is_inside_tree()=", battle.is_inside_tree())
	if not battle.is_inside_tree():
		# 2026-09-23 finding: a scene launched as the CLI positional scene
		# argument is still mid-setup when THIS node's own _ready() fires, so
		# a direct (non-deferred) add_child() on get_tree().root is rejected
		# by the engine ("Parent node is busy setting up children") -- see
		# run_output_headless.txt attempt 1 for the raw error. Retrying
		# deferred is the documented fix the engine's own error message names.
		print("Q1: direct add_child() was rejected by the engine (see error above) -- retrying via call_deferred")
		get_tree().root.call_deferred("add_child", battle)
		await get_tree().process_frame
		await get_tree().process_frame
		print("Q1: after call_deferred + 2 frames, battle.is_inside_tree()=", battle.is_inside_tree())
	print("Q1: root's children after add: ")
	for c: Node in get_tree().root.get_children():
		print("  - ", c.name, " (", c.get_class(), ")")

	# Let _ready()'s file loads / signal wiring / child construction settle,
	# and let a few frames of _process() run (device authority resolve_frame,
	# cursor visual update, etc.) before measuring anything.
	for i in range(15):
		await get_tree().process_frame

	# ---------------------------------------------------------------
	# Q3 -- did it reach a renderable state on its own, or does driving it
	# require more than "load + add_child"?
	# ---------------------------------------------------------------
	var load_error_label: Node = battle.get_node_or_null("UILayer/LoadErrorLabel")
	var status_label: Node = battle.get_node_or_null("UILayer/StatusLabel")
	print("Q3: UILayer/LoadErrorLabel found? ", load_error_label != null, " visible=", (load_error_label.visible if load_error_label else "N/A"))
	print("Q3: UILayer/StatusLabel found? ", status_label != null, " text='", (status_label.text if status_label else "N/A"), "'")
	print("Q3: battle.get(\"_load_failed\") = ", battle.get("_load_failed"))
	print("Q3: battle.get(\"_state\") is null? ", battle.get("_state") == null)
	print("Q3: battle.get(\"_controller\") is null? ", battle.get("_controller") == null)

	var world_container: Node = battle.get_node_or_null("WorldViewportContainer")
	var world_viewport: SubViewport = battle.get_node_or_null("WorldViewportContainer/WorldViewport")
	print("Q1/Q3: WorldViewportContainer found? ", world_container != null)
	print("Q1/Q3: WorldViewport (SubViewport) found? ", world_viewport != null)
	if world_container:
		print("Q1/Q3: WorldViewportContainer.position=", world_container.position, " size=", world_container.size, " stretch_shrink=", world_container.stretch_shrink)
	if world_viewport:
		print("Q1/Q3: WorldViewport.size (should be 480x270 per WorldLayout.BASE_WIDTH/HEIGHT) = ", world_viewport.size)

	# ---------------------------------------------------------------
	# Q2 path 1 -- root window screenshot
	# ---------------------------------------------------------------
	var root_vp: Viewport = get_viewport()
	print("Q2/ROOT: root viewport size = ", root_vp.size)
	var root_tex: ViewportTexture = root_vp.get_texture()
	print("Q2/ROOT: root_vp.get_texture() is null? ", root_tex == null)
	if root_tex != null:
		var root_img: Image = root_tex.get_image()
		print("Q2/ROOT: root_tex.get_image() is null? ", root_img == null)
		if root_img != null:
			print("Q2/ROOT: image size=", root_img.get_size(), " format=", root_img.get_format(), " is_empty()=", root_img.is_empty())
			_report_image_stats(root_img, "ROOT-" + _mode_label)
			var save_path: String = OUT_DIR + "root_" + _mode_label + ".png"
			var save_err: int = root_img.save_png(save_path)
			print("Q2/ROOT: save_png(", save_path, ") err=", save_err, " (0=OK)")

			if world_container != null:
				var rect: Rect2i = Rect2i(Vector2i(world_container.position), Vector2i(world_container.size))
				var clamped: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO, root_img.get_size()))
				print("Q5: world-layer rect in window space = ", rect, " clamped to image bounds = ", clamped)
				if clamped.size.x > 0 and clamped.size.y > 0:
					var world_crop: Image = root_img.get_region(clamped)
					_check4_integer_grid(world_crop, "WORLD-LAYER-CROP-" + _mode_label)

					# Follow-up measurement: at THIS window size the
					# WorldViewportContainer's rect fills the entire window
					# (see Q5 finding), so the crop above ALSO contains the
					# UILayer CanvasLayer's Labels/ColorRect (a separate
					# canvas layer drawn on the same final pixels, not a
					# child of the SubViewport). Re-run the same check
					# excluding the five HUD label rects, read from the REAL
					# production HudLayout.*_rect() functions (never
					# re-derived) -- this isolates whether the raw non-zero
					# count above is explained by antialiased HUD text
					# (coding-standards.md's own documented carve-out) rather
					# than a defect in the world layer itself.
					var window_size_i: Vector2i = root_vp.size
					# NOTE: LoadErrorLabel/ResultLabel deliberately excluded
					# from this list -- both are visible=false at battle
					# start (confirmed above), so their (very large,
					# near-fullscreen for LoadErrorLabel) rects draw no
					# pixels and including them would make this check
					# vacuous by masking out most of the board. Only the
					# three ACTUALLY VISIBLE HUD elements are excluded here.
					var hud_exclude: Array[Rect2i] = [
						Rect2i(HudLayout.status_label_rect(window_size_i)),
						Rect2i(HudLayout.info_label_rect(window_size_i)),
						Rect2i(HudLayout.controls_hint_bg_rect(window_size_i)),
					]
					print("Q5/FOLLOWUP: HUD exclude rects (real HudLayout.*_rect() calls, visible elements only) = ", hud_exclude)
					_check4_integer_grid_excluding(world_crop, clamped.position, hud_exclude, "WORLD-LAYER-CROP-MINUS-HUD-" + _mode_label)

	# ---------------------------------------------------------------
	# Q2 path 2 -- SubViewport internal buffer (raw 480x270, pre-upscale)
	# ---------------------------------------------------------------
	if world_viewport != null:
		var sub_tex: ViewportTexture = world_viewport.get_texture()
		print("Q2/SUBVIEWPORT: world_viewport.get_texture() is null? ", sub_tex == null)
		if sub_tex != null:
			var sub_img: Image = sub_tex.get_image()
			print("Q2/SUBVIEWPORT: sub_tex.get_image() is null? ", sub_img == null)
			if sub_img != null:
				print("Q2/SUBVIEWPORT: image size=", sub_img.get_size(), " format=", sub_img.get_format(), " is_empty()=", sub_img.is_empty())
				_report_image_stats(sub_img, "SUBVIEWPORT-" + _mode_label)
				var save_path2: String = OUT_DIR + "subviewport_" + _mode_label + ".png"
				var save_err2: int = sub_img.save_png(save_path2)
				print("Q2/SUBVIEWPORT: save_png(", save_path2, ") err=", save_err2, " (0=OK)")

	print("=== PROBE END mode=", _mode_label, " ===")
	get_tree().quit(0)


func _report_image_stats(img: Image, label: String) -> void:
	var size: Vector2i = img.get_size()
	if size.x == 0 or size.y == 0:
		print("Q2: [", label, "] image has zero size -- cannot sample")
		return
	var colors: Dictionary = {}
	var sample_count: int = 0
	var step_x: int = max(1, size.x / 40)
	var step_y: int = max(1, size.y / 40)
	for y in range(0, size.y, step_y):
		for x in range(0, size.x, step_x):
			var c: Color = img.get_pixel(x, y)
			var key: String = c.to_html(false)
			colors[key] = colors.get(key, 0) + 1
			sample_count += 1
	print("Q2: [", label, "] sampled ", sample_count, " points on a step-", step_x, "x", step_y, " grid, distinct colors = ", colors.size())
	print("Q2: [", label, "] histogram (top entries) = ", colors)


# Same-shape check as coding-standards.md Category A Check 4 / the u013
# evidence driver's _integer_grid_violations() -- but read directly from the
# scale actually observed at runtime (world_container.size / sub_viewport
# native size), never a hardcoded factor, and NOT reimplemented as a new
# formula: it is the same "each source pixel must map to a clean NxN block"
# definition, applied here to a REAL production frame from a REAL load()'d
# scene, as a cross-check against the u013 spike's own real-pipeline result.
func _check4_integer_grid(img: Image, label: String) -> void:
	var size: Vector2i = img.get_size()
	if size.x < 2 or size.y < 2:
		print("Q5/CHECK4: [", label, "] crop too small to check (", size, ")")
		return
	# Derive scale empirically from the crop itself: WorldLayout.BASE_WIDTH is
	# the SubViewport's native width (480); scale = crop_width / 480, rounded,
	# since world_container.size is exactly scale * 480 x scale * 270 by
	# world_viewport_scaler.gd's own construction.
	var scale_guess: int = int(round(float(size.x) / float(WorldLayout.BASE_WIDTH)))
	if scale_guess < 1:
		print("Q5/CHECK4: [", label, "] scale_guess < 1 (", scale_guess, ") from crop size ", size, " -- skipping")
		return
	print("Q5/CHECK4: [", label, "] crop size=", size, " WorldLayout.BASE_WIDTH=", WorldLayout.BASE_WIDTH, " scale_guess=", scale_guess)
	var violations: int = 0
	var total_blocks: int = 0
	var blocks_x: int = size.x / scale_guess
	var blocks_y: int = size.y / scale_guess
	for by in range(blocks_y):
		for bx in range(blocks_x):
			total_blocks += 1
			var origin: Color = img.get_pixel(bx * scale_guess, by * scale_guess)
			var is_violation: bool = false
			for dy in range(scale_guess):
				for dx in range(scale_guess):
					var px: int = bx * scale_guess + dx
					var py: int = by * scale_guess + dy
					if px >= size.x or py >= size.y:
						continue
					var c: Color = img.get_pixel(px, py)
					if not c.is_equal_approx(origin):
						is_violation = true
						break
				if is_violation:
					break
			if is_violation:
				violations += 1
	print("Q5/CHECK4: [", label, "] integer-scale grid violations (whole-crop, NOT excluding antialiased UI text since this crop is world-layer only) = ", violations, " / ", total_blocks)


# Same as _check4_integer_grid() but skips any block that intersects one of
# [param exclude_rects_window] (given in window-space, converted to
# crop-local space via [param crop_offset_window]).
func _check4_integer_grid_excluding(img: Image, crop_offset_window: Vector2i, exclude_rects_window: Array[Rect2i], label: String) -> void:
	var size: Vector2i = img.get_size()
	if size.x < 2 or size.y < 2:
		print("Q5/CHECK4-EXCL: [", label, "] crop too small to check (", size, ")")
		return
	var scale_guess: int = int(round(float(size.x) / float(WorldLayout.BASE_WIDTH)))
	if scale_guess < 1:
		print("Q5/CHECK4-EXCL: [", label, "] scale_guess < 1 -- skipping")
		return
	var exclude_local: Array[Rect2i] = []
	for r: Rect2i in exclude_rects_window:
		exclude_local.append(Rect2i(r.position - crop_offset_window, r.size))
	var violations: int = 0
	var total_blocks: int = 0
	var excluded_blocks: int = 0
	var blocks_x: int = size.x / scale_guess
	var blocks_y: int = size.y / scale_guess
	for by in range(blocks_y):
		for bx in range(blocks_x):
			var block_rect: Rect2i = Rect2i(bx * scale_guess, by * scale_guess, scale_guess, scale_guess)
			var excluded: bool = false
			for ex: Rect2i in exclude_local:
				if ex.intersects(block_rect):
					excluded = true
					break
			if excluded:
				excluded_blocks += 1
				continue
			total_blocks += 1
			var origin: Color = img.get_pixel(bx * scale_guess, by * scale_guess)
			var is_violation: bool = false
			for dy in range(scale_guess):
				for dx in range(scale_guess):
					var px: int = bx * scale_guess + dx
					var py: int = by * scale_guess + dy
					if px >= size.x or py >= size.y:
						continue
					var c: Color = img.get_pixel(px, py)
					if not c.is_equal_approx(origin):
						is_violation = true
						break
				if is_violation:
					break
			if is_violation:
				violations += 1
	print("Q5/CHECK4-EXCL: [", label, "] integer-scale grid violations excluding ", exclude_local.size(), " HUD rects (", excluded_blocks, " blocks skipped) = ", violations, " / ", total_blocks)
