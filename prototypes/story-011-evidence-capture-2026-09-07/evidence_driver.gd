extends Node
## Throwaway Story 011 evidence-capture driver (native cursor suppression +
## self-drawn substitute cursor + hover-based visibility arbiter).
##
## Loads the REAL production scene (res://src/ui/battle/BattleScreen.tscn) as
## backdrop content — not a copy, not a re-implementation — matching the
## precedent `prototypes/story-001-ac-s001c-evidence-capture-2026-09-04/`
## already established for this project's windowed evidence captures.
##
## [b]Why this driver builds its OWN CursorState/ThresholdMouseReclaimPolicy
## instead of touching the live CursorStateHost Autoload's instance[/b]:
## ADR-0005 機制六's automatic per-frame call site (device authority
## arbitration reacting to real InputEvents, including the mouse-reclaim
## threshold check) is Story 005's SEAM in `cursor_state.gd`'s
## `arbitrate_device_authority()`, which is CURRENTLY EMPTY — nothing in this
## project today ever calls `MouseReclaimPolicy.evaluate()` automatically in
## response to real mouse movement. This is a genuine, documented gap (see
## that method's own "STORY 005 SEAM" comment), not something this evidence
## driver can paper over. Reaching into the Autoload's private `_state` field
## to drive its `_reclaim` directly would also hit the registered forbidden
## pattern `external_access_to_cursor_reclaim_instance`
## (`docs/registry/architecture.yaml:2056`) — a rule this driver deliberately
## respects even though `prototypes/` is not bound by `src/`'s own discipline,
## because sidestepping it here would prove nothing about what Story 011
## actually delivers.
##
## Instead, this driver constructs its OWN [CursorState] +
## [ThresholdMouseReclaimPolicy] + the same two Story 011 presentation nodes
## ([SelfDrawnReclaimCursor], [NativePointerVisibilityArbiter]) — the EXACT
## SAME production classes `cursor_state_host.gd` wires — and manually calls
## `evaluate()` on the policy IT OWNS in lockstep with real OS mouse movement
## ([method Input.warp_mouse]). This demonstrates exactly what Story 011
## delivers (the presentation layer's reaction to reclaim progress) without
## fabricating Story 005's still-missing automatic wiring. The real
## CursorStateHost Autoload keeps running in parallel throughout — its own
## SelfDrawnReclaimCursor stays permanently at alpha 0.0 (nothing ever drives
## its policy), so it draws nothing perceptible; its own
## NativePointerVisibilityArbiter independently also decides HIDDEN (device
## authority never leaves UNINITIALIZED, which is not MOUSE), so it does not
## fight this driver's own arbiter for control of the same global
## [member Input.mouse_mode] setting.
##
## Three captures at 1920x1080 (zero world-layer margin per the manager's
## screen-architecture ruling, so no extra state to explain in the image):
## 1. "start" — reclaim progress 0.0 (native cursor hidden, substitute cursor
##    presented alpha 0.0 — AC-31's binary reading).
## 2. "partial" — reclaim progress ~0.4 mid-movement (AC-28c/AC-31b:
##    proportional, not binary).
## 3. "full" — reclaim progress 1.0 at the threshold (AC-28: 100% at the
##    crossing frame).
##
## Per `.claude/docs/coding-standards.md` Screenshot Evidence Rules: validates
## BEFORE writing (dimensions, >=3 distinct colors among 12 sample points,
## <=80% dominant-color share) and aborts without saving on failure — a tool
## that can emit false evidence is worse than no tool.

const OUTPUT_DIR: String = "res://production/qa/evidence/"
const TARGET_SIZE: Vector2i = Vector2i(1920, 1080)
const RECLAIM_THRESHOLD_PX: float = 80.0
const SEED_POSITION: Vector2 = Vector2(960, 540)  # window center


func _ready() -> void:
	await get_tree().process_frame
	var battle_scene: Node = load("res://src/ui/battle/BattleScreen.tscn").instantiate()
	get_tree().root.add_child(battle_scene)
	await get_tree().process_frame

	await _resize_and_settle(TARGET_SIZE)

	# ─── Build this driver's OWN cursor-system instance (see class doc
	# comment for why NOT the live Autoload's) ──────────────────────────────
	var threshold_config := MouseReclaimThresholdConfig.new()
	threshold_config.board_tile_threshold_px = RECLAIM_THRESHOLD_PX
	threshold_config.relation_minimap_node_threshold_px = RECLAIM_THRESHOLD_PX
	threshold_config.card_slot_threshold_px = RECLAIM_THRESHOLD_PX
	threshold_config.dialogue_choice_threshold_px = RECLAIM_THRESHOLD_PX
	var policy := ThresholdMouseReclaimPolicy.new(threshold_config)
	var registry := CursorSurfaceRegistry.new()
	var demo_state := CursorState.new(policy, registry, Callable(self, "_get_mouse_position"))
	# Precondition for a meaningful mouse-reclaim demo: keyboard/gamepad holds
	# authority (direct field write — same pattern this story's own unit
	# tests use for _device_authority, NOT the forbidden _reclaim access).
	demo_state.set(&"_device_authority", CursorTypes.Authority.KEYBOARD_GAMEPAD)

	var demo_layer := CanvasLayer.new()
	demo_layer.name = "EvidenceDemoLayer"
	demo_layer.layer = 200  # above CursorStateHost's own layer (100)
	get_tree().root.add_child(demo_layer)

	var visual_config := CursorReclaimVisualConfig.new()
	visual_config.reclaim_visual_convergence_max_frames = 6
	var demo_cursor := SelfDrawnReclaimCursor.new(demo_state, visual_config)
	demo_cursor.name = "DemoSelfDrawnReclaimCursor"
	demo_layer.add_child(demo_cursor)

	var demo_arbiter := NativePointerVisibilityArbiter.new(
		demo_state, registry, Callable(self, "_no_hover")
	)
	demo_arbiter.name = "DemoNativePointerVisibilityArbiter"
	demo_layer.add_child(demo_arbiter)

	# Seed the accumulator and place the OS mouse at the seed position.
	Input.warp_mouse(SEED_POSITION)
	await get_tree().process_frame
	policy.reset(SEED_POSITION, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)
	await get_tree().process_frame

	# ─── Capture 1: "start" — progress 0.0 ─────────────────────────────────
	await _capture_and_verify("story011-native-cursor-suppression-start-2026-09-07", demo_arbiter, demo_state)

	# ─── Move partway toward the threshold, capture "partial" ──────────────
	var partial_offset: float = RECLAIM_THRESHOLD_PX * 0.4
	Input.warp_mouse(SEED_POSITION + Vector2(partial_offset, 0))
	await get_tree().process_frame
	policy.evaluate(SEED_POSITION + Vector2(partial_offset, 0), CursorTypes.SurfaceType.BOARD_TILE)
	await get_tree().process_frame
	await _capture_and_verify("story011-native-cursor-suppression-partial-2026-09-07", demo_arbiter, demo_state)

	# ─── Move to (at/above) the threshold, capture "full" ───────────────────
	Input.warp_mouse(SEED_POSITION + Vector2(RECLAIM_THRESHOLD_PX, 0))
	await get_tree().process_frame
	policy.evaluate(SEED_POSITION + Vector2(RECLAIM_THRESHOLD_PX, 0), CursorTypes.SurfaceType.BOARD_TILE)
	await get_tree().process_frame
	# Rising edge syncs immediately (R4-3), but let a couple more frames run
	# so the human/screenshot sees a settled state, not a mid-transition one.
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture_and_verify("story011-native-cursor-suppression-full-2026-09-07", demo_arbiter, demo_state)

	print("=== Story 011 evidence capture complete ===")
	get_tree().quit(0)


func _get_mouse_position() -> Vector2:
	return get_viewport().get_mouse_position()


func _no_hover() -> Variant:
	return null


func _resize_and_settle(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	for i in range(10):
		await get_tree().process_frame


## Captures the current frame, runs the coding-standards.md Screenshot
## Evidence Rules mechanical checks, and ONLY saves the PNG if all checks
## pass — "validate before writing... on exhaustion error out and write
## nothing" (per that file's Rules for capture tooling).
func _capture_and_verify(label: String, arbiter: NativePointerVisibilityArbiter, state: CursorState) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var actual_size: Vector2i = img.get_size()
	var size_ok: bool = actual_size == TARGET_SIZE

	# Rule #2: multi-point sampling, >= 3 distinct colors among 12 points.
	var sample_points: Array[Vector2i] = []
	for i in range(4):
		for j in range(3):
			sample_points.append(Vector2i(
				int((float(i) + 0.5) / 4.0 * actual_size.x),
				int((float(j) + 0.5) / 3.0 * actual_size.y)
			))
	var sample_colors: Dictionary = {}
	for p: Vector2i in sample_points:
		sample_colors[img.get_pixelv(p).to_html(false)] = true
	var distinct_samples: int = sample_colors.size()

	# Rule #3: dominant color share <= 80% (subsampled every 4px for speed).
	var histogram: Dictionary = {}
	var step: int = 4
	var sampled_total: int = 0
	for y in range(0, actual_size.y, step):
		for x in range(0, actual_size.x, step):
			var key: String = img.get_pixel(x, y).to_html(false)
			histogram[key] = histogram.get(key, 0) + 1
			sampled_total += 1
	var dominant_count: int = 0
	for key: String in histogram:
		if histogram[key] > dominant_count:
			dominant_count = histogram[key]
	var dominant_share: float = float(dominant_count) / float(sampled_total)
	var dominant_ok: bool = dominant_share <= 0.80

	var checks_pass: bool = size_ok and distinct_samples >= 3 and dominant_ok

	print("--- capture: ", label, " ---")
	print("  reclaim_progress = ", state.reclaim_progress())
	print("  arbiter.diagnostic_last_desired_mouse_mode = ", arbiter.diagnostic_last_desired_mouse_mode,
		" (0=VISIBLE, 1=HIDDEN)")
	print("  Input.mouse_mode (real engine value, this process) = ", Input.mouse_mode)
	print("  captured size = ", actual_size, " (target ", TARGET_SIZE, ") size_ok=", size_ok)
	print("  12-point distinct colors = ", distinct_samples, " (rule requires >= 3)")
	print("  dominant color share (subsampled every %dpx) = %.4f (rule requires <= 0.80)" % [step, dominant_share])
	print("  CHECKS PASS = ", checks_pass)

	if not checks_pass:
		print("  ABORTING — not writing any file for this capture (checks failed).")
		return

	var out_path: String = OUTPUT_DIR + label + ".png"
	var dir_err: int = DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var save_err: int = img.save_png(out_path)
	print("  saved: ", out_path, " save_err=", save_err, " (0 == OK)")
