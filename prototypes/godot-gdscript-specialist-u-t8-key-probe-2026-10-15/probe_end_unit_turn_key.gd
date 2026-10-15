## Throwaway headless probe for Story 011 U-T8 (production/epics/tactical-combat/story-011-input-gaps.md).
##
## Purpose: Before adding a NEW project.godot [input] action for "結束該單位行動"
## (end_unit_turn), measure — by asking the RUNNING ENGINE's InputMap, not by
## re-deriving or assuming the answer — whether the two candidate bindings
## (keyboard Backspace, gamepad Y) are already bound to any existing action
## (built-in ui_* engine defaults, or this project's own battle_* actions).
##
## Same method/discipline as prototypes/u004-inputmap-probe-2026-09-16/probe_input_map.gd
## (field-equality comparison, not InputEventKey.is_match(), disclosed explicitly;
## only bare-key exact match checked, Ctrl/Alt/Meta combos of the same key not flagged).
##
## Run:
##   "<godot path>" --headless --path . -s prototypes/godot-gdscript-specialist-u-t8-key-probe-2026-10-15/probe_end_unit_turn_key.gd
extends SceneTree

func _key_event_matches(event: InputEventKey, target_keycode: int) -> bool:
	var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if kc != target_keycode:
		return false
	if event.shift_pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return false
	return true


func _find_key_conflicts(all_actions: Array, target_keycode: int) -> Array[StringName]:
	var hits: Array[StringName] = []
	for action in all_actions:
		for e in InputMap.action_get_events(action):
			if e is InputEventKey and _key_event_matches(e, target_keycode):
				hits.append(action)
				break
	return hits


func _find_joy_conflicts(all_actions: Array, target_button: int) -> Array[StringName]:
	var hits: Array[StringName] = []
	for action in all_actions:
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton and e.button_index == target_button:
				hits.append(action)
				break
	return hits


func _initialize() -> void:
	print("=== Story 011 U-T8 key probe (2026-10-15) ===")
	print("Engine version: %s" % Engine.get_version_info())

	var all_actions: Array = InputMap.get_actions()
	print("InputMap 在 headless 下可讀: %s (get_actions() 回傳 %d 個動作)" \
		% [not all_actions.is_empty(), all_actions.size()])

	print("KEY_BACKSPACE=%d  JOY_BUTTON_Y=%d  KEY_Q=%d  KEY_V=%d  JOY_BUTTON_BACK=%d  JOY_BUTTON_MISC1=%d" \
		% [KEY_BACKSPACE, JOY_BUTTON_Y, KEY_Q, KEY_V, JOY_BUTTON_BACK, JOY_BUTTON_MISC1])

	var kb_candidates: Array[Dictionary] = [
		{"label": "Backspace", "key": KEY_BACKSPACE},
		{"label": "Q", "key": KEY_Q},
		{"label": "V", "key": KEY_V},
	]
	for c in kb_candidates:
		print("\n--- 候選鍵盤 %s ---" % c["label"])
		var kb_hits: Array[StringName] = _find_key_conflicts(all_actions, c["key"])
		if kb_hits.is_empty():
			print("  未被佔用")
		else:
			print("  已被佔用: %s" % [kb_hits])

	var joy_candidates: Array[Dictionary] = [
		{"label": "Y (上動作鍵)", "button": JOY_BUTTON_Y},
		{"label": "Back/Select", "button": JOY_BUTTON_BACK},
		{"label": "Misc1", "button": JOY_BUTTON_MISC1},
	]
	for c in joy_candidates:
		print("\n--- 候選手把 %s ---" % c["label"])
		var joy_hits: Array[StringName] = _find_joy_conflicts(all_actions, c["button"])
		if joy_hits.is_empty():
			print("  未被佔用")
		else:
			print("  已被佔用: %s" % [joy_hits])

	print("\n--- 全部既有動作一覽(供人工覆核) ---")
	for a in all_actions:
		print("  %s" % a)

	print("\n=== Probe complete ===")
	quit()
