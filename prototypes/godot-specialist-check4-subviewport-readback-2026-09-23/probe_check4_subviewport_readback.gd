extends Node
## Probe for the manager's Route (1) question (2026-09-23): if Check4's world-layer
## exemption is redefined from "crop the container rect out of the window
## screenshot" to "read SubViewport.get_texture().get_image() directly", does
## Check4 become a check that can never fail (zero detection power)?
##
## Builds on, does not re-derive, two prior probes' established facts:
##   - prototypes/godot-specialist-scene-load-feasibility-2026-09-23/ already
##     measured BOTH the root-window screenshot AND the SubViewport native
##     buffer get_image() as null headless (answers Q1 -- reused here, not
##     re-tested, since re-running it would just reproduce the same engine
##     limitation a third time).
##   - prototypes/godot-specialist-u013-worldlayer-attribution-2026-09-23/
##     already proved nearest-upscaled SubViewport content is Check4-clean by
##     construction (0/129600) when compared at the CONTAINER's scale factor.
##
## This probe's own new work (Q2, Q3, Q4):
##   Q2 -- capture the native buffer at frames 1/2/5/10/15 and diff bytes
##        against frame 15 to see how many frames are actually needed.
##   Q3 -- run Check4 DIRECTLY on the native 480x270 buffer, first at scale=1
##        (structural-tautology control), then against two synthetic sprites
##        added as EXTRA children of the REAL loaded WorldViewport (additions
##        on top of the production scene already loaded per
##        technical-preferences.md's "(A) 的精確定義" point 5 -- not a
##        stand-in scene) at a clean integer scale (3.0) vs a non-integer
##        scale (3.3), to see whether Check4 retains any detection power for
##        defects that originate INSIDE the world layer itself.
##   Q4 -- record node path/type of SubViewport as actually retrieved, for
##        the cost-of-Route-1 question.
##
## Run shape (windowed only -- headless get_image() already established null
## by the prior probe; not re-tested here):
##   "<godot>" --path . prototypes/godot-specialist-check4-subviewport-readback-2026-09-23/ProbeCheck4SubviewportReadback.tscn

const BATTLE_SCREEN_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const OUT_DIR: String = "res://prototypes/godot-specialist-check4-subviewport-readback-2026-09-23/"


func _ready() -> void:
	# Same fail-safe as both prior probes -- a crash mid-_ready() before
	# quit() would otherwise leave the windowed process hanging open.
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
		print("LOAD: direct add_child() rejected as expected -- retrying via call_deferred (known trap)")
		get_tree().root.call_deferred("add_child", battle)
		await get_tree().process_frame
		await get_tree().process_frame
	print("LOAD: battle.is_inside_tree()=", battle.is_inside_tree())

	# ---------------------------------------------------------------
	# Q4: node path/type as actually retrieved from the real loaded scene.
	# ---------------------------------------------------------------
	var world_container: SubViewportContainer = battle.get_node_or_null("WorldViewportContainer")
	var world_viewport: SubViewport = battle.get_node_or_null("WorldViewportContainer/WorldViewport")
	print("Q4: WorldViewportContainer node = ", world_container, " get_class()=", (world_container.get_class() if world_container else "N/A"))
	print("Q4: WorldViewport node = ", world_viewport, " get_class()=", (world_viewport.get_class() if world_viewport else "N/A"))
	print("SANITY: WorldViewportContainer.position=", world_container.position, " size=", world_container.size, " stretch_shrink=", world_container.stretch_shrink)
	print("SANITY: WorldViewport.size=", world_viewport.size)

	# ---------------------------------------------------------------
	# Q2: how many frames until the native buffer image stabilizes?
	# Capture at frames 1, 2, 5, 10, 15 (cumulative) and diff raw bytes
	# against the frame-15 capture (the frame count both prior probes used).
	# ---------------------------------------------------------------
	var frame_targets: Array[int] = [1, 2, 5, 10, 15]
	var captured_at: Dictionary = {}
	var elapsed: int = 0
	for target in frame_targets:
		while elapsed < target:
			await get_tree().process_frame
			elapsed += 1
		var img: Image = world_viewport.get_texture().get_image()
		var is_null: bool = img == null
		print("Q2: frame ", target, " get_image() null? ", is_null, " size=", (img.get_size() if not is_null else "N/A"))
		if not is_null:
			captured_at[target] = img.get_data()

	if captured_at.has(15):
		var ref_data: PackedByteArray = captured_at[15]
		for target in frame_targets:
			if captured_at.has(target):
				var same: bool = (captured_at[target] as PackedByteArray) == ref_data
				print("Q2: frame ", target, " byte-identical to frame 15? ", same)

	# ---------------------------------------------------------------
	# Q3 part A: Check4 on the native buffer at scale=1 -- structural
	# tautology check. A 1x1 "block" trivially always matches itself
	# (origin pixel IS the only pixel in the block), so this MUST be 0
	# regardless of content. Measured against the real loaded scene's actual
	# native buffer, not asserted analytically only.
	# ---------------------------------------------------------------
	var native_img: Image = world_viewport.get_texture().get_image()
	native_img.save_png(OUT_DIR + "native_frame15.png")
	_check4_full(native_img, 1, "Q3A-native-scale1 (structural tautology check, expect 0 by construction)")

	# ---------------------------------------------------------------
	# Q3 part B: construct a REAL internal-to-world-layer scaling defect and
	# test whether Check4, run directly on the native buffer at the sprite's
	# OWN intended integer scale, still detects it. This is the constructive
	# answer to "what detection power survives Route 1".
	#
	# Two synthetic sprites added as EXTRA children of the REAL loaded
	# WorldViewport (additions on top of the production scene already
	# loaded, not a stand-in scene):
	#   GOOD: 4x4 checkerboard texture, node scale = 3.0 (clean integer) ->
	#         every source pixel should map to a uniform 3x3 output block.
	#   BAD:  identical texture, node scale = 3.3 (non-integer) -> fractional
	#         scale means source-pixel boundaries drift off a clean 3px grid.
	# Positioned in the board's top-left margin to avoid overlapping real
	# board/HUD content that the prior probe already measured.
	# ---------------------------------------------------------------
	var tex: ImageTexture = _make_checkerboard_texture()

	# NOTE (fixed after 1st run): Check4's grid is a FIXED absolute grid
	# anchored at image (0,0), not anchored to the sprite's own top-left.
	# The 1st run positioned sprites at x=4 (not a multiple of scale=3),
	# which misaligned every block boundary against the sprite's own
	# source-pixel boundaries and produced spurious 100% violations even for
	# the clean-integer-scale sprite (16/16). Repositioned to multiples of 3
	# so the grid and the sprite's own pixel boundaries coincide, isolating
	# the scale-cleanliness question from this separate alignment question
	# (both are real, but conflating them answered the wrong thing).
	var good_sprite: Sprite2D = Sprite2D.new()
	good_sprite.texture = tex
	good_sprite.centered = false
	good_sprite.position = Vector2(3, 3)
	good_sprite.scale = Vector2(3.0, 3.0)
	good_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_viewport.add_child(good_sprite)

	var bad_sprite: Sprite2D = Sprite2D.new()
	bad_sprite.texture = tex
	bad_sprite.centered = false
	bad_sprite.position = Vector2(3, 63)
	bad_sprite.scale = Vector2(3.3, 3.3)
	bad_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_viewport.add_child(bad_sprite)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var native_with_synthetic: Image = world_viewport.get_texture().get_image()
	native_with_synthetic.save_png(OUT_DIR + "native_with_synthetic_sprites.png")
	print("Q3B: native_with_synthetic size=", native_with_synthetic.get_size())

	# 4x4 texture at scale 3.0, positioned at (3,3) (multiple of 3) -> 12x12px
	# rect, grid-aligned; check at scale=3 (the asset's nominal, intended
	# pixel-art scale).
	_check4_region(native_with_synthetic, 3, Rect2i(Vector2i(3, 3), Vector2i(12, 12)), "Q3B-GOOD-integer-scale-3.0-aligned")
	# 4x4 texture at scale 3.3, positioned at (3,63) (multiple of 3) -> occupies
	# a ~13.2x13.2px rect; still check at the SAME intended scale=3, since
	# that is what Check4 would need to be told to test against if it does
	# not already know the defect exists.
	_check4_region(native_with_synthetic, 3, Rect2i(Vector2i(3, 63), Vector2i(15, 15)), "Q3B-BAD-nonint-scale-3.3-aligned")

	print("=== PROBE END ===")
	get_tree().quit(0)


func _make_checkerboard_texture() -> ImageTexture:
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for y in range(4):
		for x in range(4):
			var c: Color = Color.WHITE if ((x + y) % 2 == 0) else Color.BLACK
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# Verbatim-equivalent algorithm to both prior probes' Check4 implementation
# (each source pixel must map to a uniform NxN block), applied whole-image.
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


# Same algorithm, restricted to the block-grid cells that fall within [param
# rect] (image space), for the synthetic-sprite constructive test.
func _check4_region(img: Image, scale: int, rect: Rect2i, label: String) -> void:
	var size: Vector2i = img.get_size()
	var violations: int = 0
	var total: int = 0
	var bx0: int = rect.position.x / scale
	var by0: int = rect.position.y / scale
	var bx1: int = (rect.position.x + rect.size.x) / scale
	var by1: int = (rect.position.y + rect.size.y) / scale
	for by in range(by0, by1):
		for bx in range(bx0, bx1):
			total += 1
			if _block_is_violation(img, bx, by, scale, size):
				violations += 1
	print("CHECK4-REGION [", label, "] = ", violations, " / ", total)


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
