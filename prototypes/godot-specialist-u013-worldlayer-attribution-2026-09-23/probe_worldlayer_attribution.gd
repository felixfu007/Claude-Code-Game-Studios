extends Node
## Throwaway probe for the 2026-09-23 manager ruling: "verify the hypothesis
## before touching the rule" -- does the world-layer Check4 violation count
## (1071/112490, measured 2026-09-23 by
## prototypes/godot-specialist-scene-load-feasibility-2026-09-23/) come from
## BoardView's HP text Label (world layer, inside the SubViewport), or from
## something else?
##
## Loads the REAL res://src/ui/battle/BattleScreen.tscn (per the same-day
## rule at technical-preferences.md's "(A) 的精確定義" point 5) -- reuses the
## exact load()/instantiate()/call_deferred(add_child) sequence and the exact
## Check4 block-uniformity algorithm from that same prior probe verbatim (not
## re-derived), so this run's baseline numbers must reproduce that probe's
## 4563/129600 and 1071/112490 as a sanity check before trusting anything new
## this script adds.
##
## What this script ADDS on top of that probe:
##   1. A 4th real exclusion rect: HandBar.slot_bar_rect(window_size,
##      CardDeck.HAND_SIZE_LIMIT) -- a real UI element the prior probe's
##      exclusion list did not know about (it only knew of the 3 HudLayout
##      rects wired into hud_layout_scaler.gd; HandBar is a separate node
##      wired by hand_bar.gd's own _apply_layout(), positioned via a
##      different real function).
##   2. A real (not theoretical) measurement of the HP-text band's own
##      violation count, using the actual on-screen unit under the actual
##      initial cursor position (read from battle.get("_cursor_cell"), never
##      assumed), mapped into window space via the real observed scale
##      factor -- not a re-derived formula.
##
## Run shape:
##   "<godot>" --path . prototypes/godot-specialist-u013-worldlayer-attribution-2026-09-23/ProbeWorldlayerAttribution.tscn
## (windowed only -- headless cannot get_image(), already established by the
## prior probe; not re-tested here.)

const BATTLE_SCREEN_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const OUT_DIR: String = "res://prototypes/godot-specialist-u013-worldlayer-attribution-2026-09-23/"


func _ready() -> void:
	# Fail-safe: the previous run of this probe crashed mid-_ready() (a type
	# error) and NEVER reached get_tree().quit() -- the windowed Godot process
	# stayed open until manually taskkill'd. This machine's user runs other
	# automation in parallel; a hung window is not a victimless bug. Whatever
	# happens below, this timer guarantees the process exits on its own within
	# 45s of start (generous margin over the ~15-frame settle + measurement
	# work below, which has never taken more than a couple seconds).
	get_tree().create_timer(45.0).timeout.connect(
		func() -> void:
			push_error("FAILSAFE: 45s elapsed without a clean quit() -- forcing exit now.")
			get_tree().quit(2)
	)

	print("=== PROBE START (windowed) DisplayServer.get_name()=", DisplayServer.get_name(), " ===")

	var packed: PackedScene = load(BATTLE_SCREEN_PATH)
	print("LOAD: load() returned null? ", packed == null)
	if packed == null:
		push_error("PROBE ABORT: load() returned null for BattleScreen.tscn")
		get_tree().quit(1)
		return

	var battle: Node = packed.instantiate()
	print("LOAD: instantiate() returned null? ", battle == null)
	if battle == null:
		push_error("PROBE ABORT: instantiate() returned null")
		get_tree().quit(1)
		return

	get_tree().root.add_child(battle)
	if not battle.is_inside_tree():
		print("LOAD: direct add_child() rejected as expected -- retrying via call_deferred (known trap, see prior probe)")
		get_tree().root.call_deferred("add_child", battle)
		await get_tree().process_frame
		await get_tree().process_frame
	print("LOAD: battle.is_inside_tree()=", battle.is_inside_tree())

	for i in range(15):
		await get_tree().process_frame

	# ---------------------------------------------------------------
	# Sanity check: reproduce the prior probe's structural findings before
	# trusting anything new below.
	# ---------------------------------------------------------------
	var status_label: Node = battle.get_node_or_null("UILayer/StatusLabel")
	print("SANITY: StatusLabel text='", (status_label.text if status_label else "N/A"), "'")
	print("SANITY: battle.get(\"_load_failed\") = ", battle.get("_load_failed"))

	var world_container: SubViewportContainer = battle.get_node_or_null("WorldViewportContainer")
	var world_viewport: SubViewport = battle.get_node_or_null("WorldViewportContainer/WorldViewport")
	print("SANITY: WorldViewportContainer.position=", world_container.position, " size=", world_container.size, " stretch_shrink=", world_container.stretch_shrink)
	print("SANITY: WorldViewport.size = ", world_viewport.size, " (WorldLayout.BASE_WIDTH/HEIGHT=", WorldLayout.BASE_WIDTH, "x", WorldLayout.BASE_HEIGHT, ")")

	# ---------------------------------------------------------------
	# Real cursor/selection state -- this determines exactly which unit(s)
	# show HP text on this frame. Read, never assumed.
	# ---------------------------------------------------------------
	var cursor_active: bool = battle.get("_cursor_active")
	var cursor_cell: Vector2i = battle.get("_cursor_cell")
	print("STATE: _cursor_active=", cursor_active, " _cursor_cell=", cursor_cell)
	# NOTE (2026-09-23, prior run): this used to also read battle.get("_controller")
	# into a `Node`-typed var for a cross-check. BattleController extends
	# RefCounted, not Node -- that assignment crashed _ready() at runtime with
	# no static-analysis warning beforehand, and since it happened before
	# get_tree().quit() was ever reached, the engine window hung open. Dropped
	# entirely rather than re-typed, per the coordinator's own call: it was an
	# incidental cross-check, not load-bearing for this probe's actual question.

	# ---------------------------------------------------------------
	# Root window screenshot.
	# ---------------------------------------------------------------
	var root_vp: Viewport = get_viewport()
	var root_img: Image = root_vp.get_texture().get_image()
	print("CAPTURE: root image size=", root_img.get_size())
	root_img.save_png(OUT_DIR + "root_windowed.png")

	var window_size_i: Vector2i = root_vp.size
	var scale: int = int(round(float(world_container.size.x) / float(WorldLayout.BASE_WIDTH)))
	print("CAPTURE: window_size=", window_size_i, " observed scale=", scale, " world_container.position=", world_container.position)

	# ---------------------------------------------------------------
	# The 3 HUD rects the PRIOR probe already excluded (real HudLayout calls,
	# reproduced verbatim for the sanity-check baseline).
	# ---------------------------------------------------------------
	var hud3: Array[Rect2i] = [
		Rect2i(HudLayout.status_label_rect(window_size_i)),
		Rect2i(HudLayout.info_label_rect(window_size_i)),
		Rect2i(HudLayout.controls_hint_bg_rect(window_size_i)),
	]

	# ---------------------------------------------------------------
	# NEW: HandBar's real rect -- a 4th UI element the prior probe's
	# exclusion list never knew about. Real function, real max_slots
	# constant, not re-derived.
	# ---------------------------------------------------------------
	var hand_bar_rect: Rect2i = Rect2i(HandBar.slot_bar_rect(window_size_i, CardDeck.HAND_SIZE_LIMIT))
	print("NEW: HandBar.slot_bar_rect(window_size, CardDeck.HAND_SIZE_LIMIT=", CardDeck.HAND_SIZE_LIMIT, ") = ", hand_bar_rect)

	var hud4: Array[Rect2i] = hud3.duplicate()
	hud4.append(hand_bar_rect)

	# ---------------------------------------------------------------
	# NEW: the real HP-text band rect for whichever unit is actually showing
	# HP text on this frame, per battle_screen.gd's _refresh_view() show_hp_text
	# rule: focus_cell = cursor_cell if cursor_active else (-1,-1); a PLAYER
	# unit shows HP text if its own position == focus_cell (since selected
	# == -1 at battle start); an ENEMY unit shows it only if it stands
	# exactly on focus_cell. We do not assume this -- we ask the loaded
	# battle for the unit actually at cursor_cell, and confirm no other unit
	# on the board coincidentally shares that cell (both factions checked).
	# ---------------------------------------------------------------
	var state: Object = battle.get("_state")
	var hp_text_cells: Array[Vector2i] = []
	if state != null and cursor_active:
		var unit_at_cursor: Object = state.call("unit_at", cursor_cell)
		if unit_at_cursor != null:
			hp_text_cells.append(cursor_cell)
			print("STATE: unit at cursor_cell ", cursor_cell, " id=", unit_at_cursor.get("id"), " hp=", unit_at_cursor.get("hp"), " -- this is the ONLY unit whose position matches focus_cell (checked directly)")
		else:
			print("STATE: no unit found at cursor_cell ", cursor_cell, " -- 0 units show HP text this frame")

	var hp_text_window_rects: Array[Rect2i] = []
	for cell: Vector2i in hp_text_cells:
		var cell_top_left: Vector2 = BoardCoords.grid_to_local(cell)
		var strip_top: float = cell_top_left.y + BoardView.HP_TEXT_TOP_MARGIN
		var source_rect: Rect2 = Rect2(
			Vector2(cell_top_left.x, strip_top), Vector2(BoardCoords.CELL_SIZE, BoardView.HP_TEXT_HEIGHT)
		)
		var window_rect: Rect2i = Rect2i(
			Vector2i(world_container.position) + Vector2i(source_rect.position) * scale,
			Vector2i(source_rect.size) * scale
		)
		hp_text_window_rects.append(window_rect)
		print("NEW: HP-text band for cell ", cell, " source_rect=", source_rect, " -> window_rect=", window_rect)

	# ---------------------------------------------------------------
	# BONUS (coordinator request): is 1071 a content problem or a measurement
	# problem? The prior probe's "world-layer crop" was actually a crop of the
	# ROOT WINDOW screenshot -- at this window size WorldViewportContainer
	# fills the whole window, so that crop also contains whatever the UILayer
	# CanvasLayer painted on the same final pixels. The ACTUAL world-layer-only
	# pixels are WorldViewport's own native 480x270 texture, captured before
	# any CanvasLayer compositing. Take that native image, upscale it
	# ourselves via NEAREST (matching exactly what SubViewportContainer's own
	# stretch does), and run the identical Check4 algorithm on it. Nearest
	# upscaling duplicates each source pixel into a uniform NxN block by
	# construction, so ANY content that goes through this exact pipeline --
	# antialiased or not -- must Check4 as 0 violations. A nonzero result here
	# would mean something is wrong with that premise; a zero result confirms
	# Check4 structurally cannot see inside the SubViewport at all, and every
	# violation counted above comes from something composited outside it.
	# ---------------------------------------------------------------
	var sub_native_img: Image = world_viewport.get_texture().get_image()
	print("BONUS: WorldViewport native image size=", sub_native_img.get_size())
	sub_native_img.save_png(OUT_DIR + "subviewport_native_windowed.png")
	var sub_upscaled: Image = sub_native_img.duplicate()
	sub_upscaled.resize(sub_native_img.get_width() * scale, sub_native_img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	print("BONUS: nearest-upscaled to ", sub_upscaled.get_size(), " (should equal window size ", window_size_i, ")")
	_check4_full(sub_upscaled, scale, "BONUS-SUBVIEWPORT-NATIVE-nearest-upscaled (pure world-layer content, isolates measurement-method vs content-problem)")

	# ---------------------------------------------------------------
	# Check4 runs.
	# ---------------------------------------------------------------
	_check4_full(root_img, scale, "BASELINE-whole-window")
	_check4_excluding(root_img, scale, hud3, "EXCL-3-HUD-rects (reproduces prior probe's 1071/112490)")
	_check4_excluding(root_img, scale, hud4, "EXCL-4-rects (3 HUD + HandBar)")

	var hp_exclude_only: Array[Rect2i] = hp_text_window_rects.duplicate()
	if not hp_exclude_only.is_empty():
		_check4_excluding(root_img, scale, hp_exclude_only, "EXCL-HP-text-band-ONLY (isolates non-HP-text violations)")

	var hud5: Array[Rect2i] = hud4.duplicate()
	for r: Rect2i in hp_text_window_rects:
		hud5.append(r)
	_check4_excluding(root_img, scale, hud5, "EXCL-5-rects (3 HUD + HandBar + HP-text band) -- if this is ~0, all violations are accounted for")

	# Targeted counts: violations strictly WITHIN each named region (not
	# excluded -- isolated), so we can attribute the 1071 by source rather
	# than just subtract.
	_count_violations_within(root_img, scale, hand_bar_rect, "WITHIN HandBar.slot_bar_rect")
	for i in range(hp_text_window_rects.size()):
		_count_violations_within(root_img, scale, hp_text_window_rects[i], "WITHIN HP-text-band[%d]" % i)
	for i in range(hud3.size()):
		_count_violations_within(root_img, scale, hud3[i], "WITHIN hud3[%d]" % i)

	print("=== PROBE END ===")
	get_tree().quit(0)


# Verbatim copy of the algorithm in
# godot-specialist-scene-load-feasibility-2026-09-23/probe_load_real_scene.gd's
# _check4_integer_grid(), applied to the WHOLE image at an explicitly-known
# scale (not re-derived from crop width, since this script needs the same
# scale value reused across multiple differently-shaped calls below).
func _check4_full(img: Image, scale: int, label: String) -> void:
	var size: Vector2i = img.get_size()
	var violations: int = 0
	var total_blocks: int = 0
	var blocks_x: int = size.x / scale
	var blocks_y: int = size.y / scale
	for by in range(blocks_y):
		for bx in range(blocks_x):
			total_blocks += 1
			if _block_is_violation(img, bx, by, scale, size):
				violations += 1
	print("CHECK4 [", label, "] = ", violations, " / ", total_blocks)


# Verbatim-equivalent to probe_load_real_scene.gd's
# _check4_integer_grid_excluding(), operating on the whole image with an
# explicit scale.
func _check4_excluding(img: Image, scale: int, exclude_rects: Array[Rect2i], label: String) -> void:
	var size: Vector2i = img.get_size()
	var violations: int = 0
	var total_blocks: int = 0
	var excluded_blocks: int = 0
	var blocks_x: int = size.x / scale
	var blocks_y: int = size.y / scale
	for by in range(blocks_y):
		for bx in range(blocks_x):
			var block_rect: Rect2i = Rect2i(bx * scale, by * scale, scale, scale)
			var excluded: bool = false
			for ex: Rect2i in exclude_rects:
				if ex.intersects(block_rect):
					excluded = true
					break
			if excluded:
				excluded_blocks += 1
				continue
			total_blocks += 1
			if _block_is_violation(img, bx, by, scale, size):
				violations += 1
	print("CHECK4-EXCL [", label, "] excluded_blocks=", excluded_blocks, " violations=", violations, " / ", total_blocks)


# Counts violations strictly among the blocks that intersect [param rect]
# (window space), for source attribution rather than exclusion.
func _count_violations_within(img: Image, scale: int, rect: Rect2i, label: String) -> void:
	var size: Vector2i = img.get_size()
	var blocks_x: int = size.x / scale
	var blocks_y: int = size.y / scale
	var violations: int = 0
	var total: int = 0
	for by in range(blocks_y):
		for bx in range(blocks_x):
			var block_rect: Rect2i = Rect2i(bx * scale, by * scale, scale, scale)
			if not rect.intersects(block_rect):
				continue
			total += 1
			if _block_is_violation(img, bx, by, scale, size):
				violations += 1
	print("WITHIN [", label, "] rect=", rect, " violations=", violations, " / ", total, " blocks")


func _block_is_violation(img: Image, bx: int, by: int, scale: int, size: Vector2i) -> bool:
	var origin: Color = img.get_pixel(bx * scale, by * scale)
	for dy in range(scale):
		for dx in range(scale):
			var px: int = bx * scale + dx
			var py: int = by * scale + dy
			if px >= size.x or py >= size.y:
				continue
			var c: Color = img.get_pixel(px, py)
			if not c.is_equal_approx(origin):
				return true
	return false
