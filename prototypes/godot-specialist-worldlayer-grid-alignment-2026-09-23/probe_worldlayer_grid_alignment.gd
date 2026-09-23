extends Node
## Probe for the 2026-09-23 manager ruling: "走路①,但先花一輪查格線對齊".
## Loads the REAL production scene (res://src/ui/battle/BattleScreen.tscn),
## per technical-preferences.md's "(A) 的精確定義" point 5 -- not a stand-in
## scene, not a re-implementation of BoardView's layout math.
##
## Answers (headless, structural/state -- allowed per project rule: "結構/
## 狀態...headless 亦可"):
##   Q1 -- what content types actually populate the world layer (under
##        WorldViewportContainer/WorldViewport), and what "intended integer
##        scale" does each have, per its own source file?
##   Q2 -- do their actual .position / .scale values (as loaded from the REAL
##        scene with the REAL default data path, not synthetic data) satisfy
##        that scale's alignment requirement?
##
## Q3/Q4 (pixel-measurement, misreport magnitude + alternative-method
## validation) are answered in a SEPARATE windowed run building on this run's
## structural findings -- kept separate so the headless part never needs to
## steal the user's foreground window per the dispatch brief's discipline
## ("能 headless 完成的部分就 headless,真的需要開窗時集中成一次跑完").
##
## Run:
##   "<godot>" --headless --path . -s prototypes/godot-specialist-worldlayer-grid-alignment-2026-09-23/probe_worldlayer_grid_alignment.gd

const BATTLE_SCREEN_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


func _ready() -> void:
	# _init() cannot call get_tree() (node is not in the tree yet) -- this is
	# the same trap the dispatch brief's known-issue list warns about for a
	# different case (private-field typing); using _ready() here matches both
	# prior 2026-09-23 probes' proven-working pattern.
	get_tree().create_timer(45.0).timeout.connect(
		func() -> void:
			push_error("FAILSAFE: 45s elapsed without a clean quit() -- forcing exit now.")
			get_tree().quit(2)
	)
	_run()


func _run() -> void:
	print("=== PROBE START (headless, structural/state only) ===")

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

	# Known trap #1 (dispatch brief): direct add_child() in _ready()-adjacent
	# code gets rejected ("Parent node is busy setting up children"). Use
	# call_deferred + wait frames unconditionally, matching the two prior
	# 2026-09-23 probes' proven-working pattern.
	get_tree().root.call_deferred("add_child", battle)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("LOAD: battle.is_inside_tree()=", battle.is_inside_tree())

	var world_container: SubViewportContainer = battle.get_node_or_null("WorldViewportContainer")
	var world_viewport: SubViewport = battle.get_node_or_null("WorldViewportContainer/WorldViewport")
	var board_view: Node2D = battle.get_node_or_null("WorldViewportContainer/WorldViewport/BoardView")
	print("Q4-CARRY: WorldViewportContainer=", world_container, " WorldViewport=", world_viewport, " BoardView=", board_view)
	if world_container == null or world_viewport == null or board_view == null:
		push_error("PROBE ABORT: expected world-layer nodes not found -- scene shape changed?")
		get_tree().quit(1)
		return

	print("SANITY: WorldViewportContainer.position=", world_container.position, " size=", world_container.size, " stretch_shrink=", world_container.stretch_shrink)
	print("SANITY: WorldViewport.size=", world_viewport.size)

	# ---------------------------------------------------------------
	# Confirm real default-data self-initialization actually populated
	# content (per technical-preferences.md's note that battle_screen.gd
	# "幾乎自我初始化"). If this is empty, Q1/Q2 below would be vacuous.
	# ---------------------------------------------------------------
	var terrain_layer: Node2D = board_view.get_node_or_null("TerrainLayer")
	var pieces_layer: Node2D = board_view.get_node_or_null("PiecesLayer")
	var stats_layer: Node2D = board_view.get_node_or_null("StatsLayer")
	var cursor_sprite: Node2D = board_view.get_node_or_null("CursorSprite")
	print("CONTENT-CHECK: TerrainLayer children=", (terrain_layer.get_child_count() if terrain_layer else -1))
	print("CONTENT-CHECK: PiecesLayer children=", (pieces_layer.get_child_count() if pieces_layer else -1))
	print("CONTENT-CHECK: StatsLayer children=", (stats_layer.get_child_count() if stats_layer else -1))
	print("CONTENT-CHECK: CursorSprite visible=", (cursor_sprite.visible if cursor_sprite else "N/A"))

	# ---------------------------------------------------------------
	# Q1 + Q2: walk EVERY descendant of WorldViewport, recording its own
	# type, position, and scale. This is the actual engine-loaded state,
	# not a re-derivation of BoardCoords/board_view.gd's math.
	# (BoardCoords.CELL_SIZE is 32 -- named here in the doc comment only, not
	# re-derived as logic in this probe.)
	# ---------------------------------------------------------------
	var by_type: Dictionary = {}
	var counts: Dictionary = _walk_count(world_viewport, by_type)

	print("Q1: distinct node types found under WorldViewport, with counts:")
	for type_name: String in by_type.keys():
		print("  ", type_name, " x", by_type[type_name])

	print("Q2: total descendant nodes under WorldViewport = ", counts["total"])
	print("Q2: nodes with .scale != Vector2(1,1) = ", counts["non_unit_scale"])
	print("Q2: ==> if this is 0, no real world-layer content sets an internal scale at all, so 'alignment to the content's own intended scale' is trivially satisfied (there is nothing but scale=1, and Check4's block-grid check at block-size=1 is a structural tautology per the prior probe's Q3A finding -- it can never fail regardless of position).")

	print("=== PROBE END ===")
	get_tree().quit(0)


# Walks every descendant of node, filling by_type with a type_name->count
# tally (for Q1's summary) and returning {"total": int, "non_unit_scale":
# int} (for Q2's headline numbers) in one pass. Also prints one evidence
# line per node whose position is not exactly integer OR whose scale is not
# exactly Vector2(1,1), so the raw evidence is on record even though (per
# the reasoning in the doc comment above) it should not matter for Check4 at
# native scale=1.
func _walk_count(node: Node, by_type: Dictionary) -> Dictionary:
	var total: int = 0
	var non_unit_scale: int = 0
	for child in node.get_children():
		var type_name: String = child.get_class()
		by_type[type_name] = by_type.get(type_name, 0) + 1
		total += 1
		if child is Node2D:
			var n2d: Node2D = child as Node2D
			var scale_is_unit: bool = n2d.scale.is_equal_approx(Vector2.ONE)
			if not scale_is_unit:
				non_unit_scale += 1
				print("Q2-EVIDENCE: ", child.get_path(), " (", child.get_class(), ") scale=", n2d.scale, " position=", n2d.position, " <-- NON-UNIT SCALE")
			var pos_is_integer: bool = (
				is_equal_approx(n2d.position.x, roundf(n2d.position.x))
				and is_equal_approx(n2d.position.y, roundf(n2d.position.y))
			)
			if not pos_is_integer:
				print("Q2-EVIDENCE: ", child.get_path(), " (", child.get_class(), ") position=", n2d.position, " scale=", n2d.scale, " <-- FRACTIONAL POSITION (informational only -- irrelevant to Check4 at scale=1, see structural-tautology note)")
		elif child is Control:
			var ctrl: Control = child as Control
			print("Q2-EVIDENCE: ", child.get_path(), " (", child.get_class(), ") is a Control inside the world layer -- position=", ctrl.position, " size=", ctrl.size, " (Controls have no .scale property the same way Node2D does; recorded for completeness)")
		var sub: Dictionary = _walk_count(child, by_type)
		total += sub["total"]
		non_unit_scale += sub["non_unit_scale"]
	return {"total": total, "non_unit_scale": non_unit_scale}
