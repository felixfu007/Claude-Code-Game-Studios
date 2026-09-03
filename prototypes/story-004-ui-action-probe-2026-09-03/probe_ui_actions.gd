## Throwaway headless probe for Story 004 (裝置分類 + 動作語意分類).
##
## Purpose: ADR-0005 機制四之二 explicitly states ACKNOWLEDGED_OTHER_ACTIONS'
## listed values are "a reference starting point — implementation must fill it
## in against the real InputMap contents" (機制四之二 code comment). This
## project's project.godot [input] section only customizes `battle_confirm`
## and `battle_end_phase` (not `ui_*`), so every `ui_*` action visible here
## comes from Godot 4.7.1's own engine-registered defaults. There is no way
## to know that set without asking the running engine.
##
## Evidence-grade note (technical-preferences.md "來源等級三分法"): this probe
## calls CursorTypes.classify_action() itself for the classification checks
## below — it does NOT reimplement the NAVIGATION/CONFIRM/OTHER decision. The
## only thing this script does independently is walk InputMap.get_actions()
## and diff against CursorTypes' three constants, which is exactly the
## "did the project author actually look" question Story 004's task brief
## asked for, not a duplicate rule implementation.
##
## Run:
##   "<godot path>" --headless --path . -s prototypes/story-004-ui-action-probe-2026-09-03/probe_ui_actions.gd
extends SceneTree


func _initialize() -> void:
	print("=== Story 004 UI action probe (2026-09-03) ===")
	print("Engine version: %s" % Engine.get_version_info())

	var ui_actions: Array[StringName] = []
	for action in InputMap.get_actions():
		var action_name: String = String(action)
		if action_name.begins_with("ui_"):
			ui_actions.append(action)
	ui_actions.sort()

	print("\n--- All ui_* actions registered in this engine/project (%d total) ---" % ui_actions.size())
	for action in ui_actions:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		var event_descriptions: Array[String] = []
		for e in events:
			event_descriptions.append(e.get_class())
		print("  %s -> events: %s" % [action, event_descriptions])

	print("\n--- Diff against CursorTypes' three classification lists ---")
	var unmatched: Array[StringName] = []
	for action in ui_actions:
		var in_nav: bool = CursorTypes.NAVIGATION_ACTIONS.has(action)
		var in_confirm: bool = CursorTypes.CONFIRM_ACTIONS.has(action)
		var in_other: bool = CursorTypes.ACKNOWLEDGED_OTHER_ACTIONS.has(action)
		var hit_count: int = int(in_nav) + int(in_confirm) + int(in_other)
		if hit_count == 0:
			unmatched.append(action)
			print("  UNCLASSIFIED: %s" % action)
		elif hit_count > 1:
			print("  ⚠️ MULTI-HIT (%d lists): %s" % [hit_count, action])
		else:
			var bucket: String = "NAVIGATION" if in_nav else ("CONFIRM" if in_confirm else "ACKNOWLEDGED_OTHER")
			print("  ok (%s): %s" % [bucket, action])

	print("\n--- Summary ---")
	print("Total ui_* actions: %d" % ui_actions.size())
	print("Unclassified (hand to Story 006's loader validator): %d" % unmatched.size())
	for action in unmatched:
		print("  - %s" % action)

	print("\n--- Sanity: CursorTypes.classify_action() against real registered events ---")
	for action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", &"ui_cancel"]:
		if not InputMap.has_action(action):
			print("  %s: action does not exist in this engine, skipping" % action)
			continue
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		if events.is_empty():
			print("  %s: no bound events, skipping" % action)
			continue
		var result: CursorTypes.ActionClass = CursorTypes.classify_action(events[0])
		print("  %s (event %s) -> classify_action() = %s" % [action, events[0].get_class(), result])

	print("\n--- Mouse-bound ui_* actions check (relevant to AC-8) ---")
	var mouse_bound: Array[StringName] = []
	for action in ui_actions:
		for e in InputMap.action_get_events(action):
			if e is InputEventMouseButton or e is InputEventMouseMotion:
				mouse_bound.append(action)
				break
	print("ui_* actions with a mouse-typed bound event: %s" % [mouse_bound])

	print("\n=== Probe complete ===")
	quit()
