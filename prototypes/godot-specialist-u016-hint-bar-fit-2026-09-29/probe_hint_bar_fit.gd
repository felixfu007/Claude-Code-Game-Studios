## U-016 hint bar fit probe.
## Loads the REAL production scene (res://src/ui/battle/BattleScreen.tscn) at
## five window sizes and measures (headless, structural/state only -- no
## pixel readback attempted; headless get_image() is always null per
## prototypes/godot-specialist-scene-load-feasibility-2026-09-23) whether
## ControlsHintBg / ControlsHintLabel fit within their rect / the window.
##
## Calls the REAL HudLayout static functions directly (font_size(),
## controls_hint_bg_rect()) -- never re-derives the multiplier math itself,
## per technical-preferences.md's "不得自行計算、不得複製公式" discipline.
##
## Window-size discipline: root.size is set BEFORE instantiate(), per
## prototypes/story-010-headless-resolution-probe-2026-09-04's finding that
## DisplayServer.window_set_size() is a silent no-op headless -- only
## get_tree().root.size (here: bare `root.size`, since this script IS the
## SceneTree) actually changes anything headless.
extends SceneTree

const BATTLE_SCREEN_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

## RUN 2 (2026-09-29, coordinator-directed re-test): 960x540 came back readback
## (64,64) on RUN 1's very first iteration -- not reproduced by any later
## iteration. This order deliberately puts a throwaway warm-up resolution
## FIRST, then 960x540, then a different resolution, then 960x540 AGAIN, to
## separate "first-iteration position bug" from "960x540-specific bug"
## without needing to diagnose anything first:
##   - both 960x540 runs clean  -> RUN 1's bug was position-in-loop, not size
##   - both 960x540 runs broken -> RUN 1's bug is size-specific
##   - one clean, one broken    -> timing/race, needs actual diagnosis
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1366, 768),   # warm-up -- numbers discarded, only iter=1 position matters
	Vector2i(960, 540),    # the resolution the whole measurement exists for
	Vector2i(1920, 1080),  # different resolution in between the two 960x540 runs
	Vector2i(960, 540),    # repeat -- reproducibility check
]


func _initialize() -> void:
	create_timer(90.0).timeout.connect(
		func() -> void:
			push_error("FAILSAFE: 90s elapsed without a clean quit() -- forcing exit now.")
			quit(2)
	)
	print("=== U-016 hint bar fit probe RUN 2 (headless, structural only, reproducibility re-test) ===")
	for i: int in range(RESOLUTIONS.size()):
		await _measure_one(RESOLUTIONS[i], i + 1)
	print("=== PROBE END ===")
	quit()


func _measure_one(target_size: Vector2i, iter_num: int) -> void:
	var tag: String = "iter=" + str(iter_num) + "][" + str(target_size.x) + "x" + str(target_size.y)

	root.size = target_size
	await process_frame
	var actual_window_size: Vector2i = root.size
	var readback_ok: bool = actual_window_size == target_size
	if readback_ok:
		print("[", tag, "] SET root.size=", target_size, " -> READBACK root.size=", actual_window_size, " (match)")
	else:
		print("[", tag, "] 🔴 READBACK MISMATCH: SET root.size=", target_size, " -> READBACK root.size=", actual_window_size, " -- continuing anyway, downstream numbers in this iteration are measuring the READBACK size, not the target")

	var packed: PackedScene = load(BATTLE_SCREEN_PATH)
	if packed == null:
		push_error("[" + tag + "] PROBE ABORT: load() returned null for BattleScreen.tscn")
		quit(1)
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		push_error("[" + tag + "] PROBE ABORT: instantiate() returned null")
		quit(1)
		return

	root.call_deferred("add_child", instance)
	await process_frame
	await process_frame
	print("[", tag, "] instance.is_inside_tree()=", instance.is_inside_tree())

	var ui_layer: Node = instance.get_node_or_null("UILayer")
	var bg: ColorRect = instance.get_node_or_null("UILayer/ControlsHintBg") as ColorRect
	var label: Label = instance.get_node_or_null("UILayer/ControlsHintBg/ControlsHintLabel") as Label

	if ui_layer == null or bg == null or label == null:
		push_error("[" + tag + "] PROBE ABORT: expected nodes not found (ui_layer=" + str(ui_layer) + " bg=" + str(bg) + " label=" + str(label) + ")")
		instance.queue_free()
		await process_frame
		return

	# Re-invoke the REAL production layout method directly (not a
	# re-implementation) rather than gambling on Window.size_changed firing
	# under the headless dummy display driver. Idempotent given the same
	# window size, so calling it again here is harmless even though
	# HudLayoutScaler._ready() already called it once during add_child above.
	if ui_layer.has_method("_apply_layout"):
		ui_layer.call("_apply_layout")
	await process_frame

	# ---- ITEM 1: background rect vs window ----
	var bg_rect: Rect2 = HudLayout.controls_hint_bg_rect(actual_window_size)
	var bg_end: Vector2 = bg_rect.end
	var bg_fits_window: bool = bg_end.x <= float(actual_window_size.x) and bg_end.y <= float(actual_window_size.y)
	print("[", tag, "] ITEM1 HudLayout.controls_hint_bg_rect pos=", bg_rect.position, " size=", bg_rect.size, " end=", bg_end, " window=", actual_window_size, " fits_within_window=", bg_fits_window)
	print("[", tag, "] ITEM1b actual node ControlsHintBg.position=", bg.position, " size=", bg.size, " (post _apply_layout)")

	# ---- ITEM 2: label content size vs reported/readback font size ----
	var reported_font_px: int = HudLayout.font_size(actual_window_size)
	var label_font_px_readback: int = label.get_theme_font_size(&"font_size")
	var font: Font = label.get_theme_font(&"font")
	var line_count: int = label.get_line_count()
	var lines: PackedStringArray = label.text.split("\n")
	var line_widths: Array[float] = []
	for line: String in lines:
		var sz: Vector2 = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_px_readback)
		line_widths.append(sz.x)
	var multiline_size: Vector2 = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_px_readback)
	var single_line_height: float = font.get_height(label_font_px_readback)

	print("[", tag, "] ITEM2 label.size=", label.size, " label.position=", label.position, " get_line_count()=", line_count)
	print("[", tag, "] ITEM2 HudLayout.font_size()=", reported_font_px, " label.get_theme_font_size(font_size) readback=", label_font_px_readback)
	print("[", tag, "] ITEM2 per_line_widths(font.get_string_size)=", line_widths)
	print("[", tag, "] ITEM2 font.get_multiline_string_size(text,width=-1)=", multiline_size, " cross_check(font.get_height*line_count)=", single_line_height * float(line_count))

	# ---- ITEM 3: vertical fit -- content height vs bg rect height ----
	var content_height: float = multiline_size.y
	var bg_height: float = bg_rect.size.y
	var vertical_diff: float = bg_height - content_height
	print("[", tag, "] ITEM3 content_height=", content_height, " bg_rect.height=", bg_height, " diff(bg-content)=", vertical_diff, " overflow=", vertical_diff < 0.0)

	# ---- ITEM 4: horizontal fit -- longest line vs bg rect width vs window width ----
	var max_line_width: float = 0.0
	for w: float in line_widths:
		max_line_width = maxf(max_line_width, w)
	var bg_width: float = bg_rect.size.x
	var window_width: float = float(actual_window_size.x)
	var diff_vs_bg: float = bg_width - max_line_width
	var diff_vs_window: float = window_width - max_line_width
	print("[", tag, "] ITEM4 max_line_width=", max_line_width, " bg_rect.width=", bg_width, " diff(bg-line)=", diff_vs_bg, " window_width=", window_width, " diff(window-line)=", diff_vs_window, " overflow_bg=", diff_vs_bg < 0.0, " overflow_window=", diff_vs_window < 0.0)

	# ---- ITEM 5: overrun/wrap/clip properties ----
	print("[", tag, "] ITEM5 label.clip_text=", label.clip_text, " label.autowrap_mode=", label.autowrap_mode, " label.text_overrun_behavior=", label.text_overrun_behavior)

	instance.queue_free()
	await process_frame
	print("[", tag, "] --- done ---")
