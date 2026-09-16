## Throwaway headless probe for Story U-004
## (production/epics/card-play-interface/story-u004-input-map-probe.md).
##
## Purpose: Before U-005 writes 5 new candidate actions (battle_cancel / open_hand /
## next_target / prev_target / battle_menu) into project.godot, measure — by asking
## the RUNNING ENGINE's InputMap, not by re-deriving or assuming the answer — whether
## any of the 10 candidate keys/buttons (5 actions x keyboard+gamepad) are already
## bound to any existing action (built-in `ui_*` engine defaults, or this project's
## own `battle_confirm` / `battle_end_phase`).
##
## Evidence-grade note (technical-preferences.md "(A) 的精確定義" 節):
## This script calls InputMap.get_actions() / InputMap.action_get_events() and reads
## the real `keycode` / `physical_keycode` / `shift_pressed` / `ctrl_pressed` /
## `alt_pressed` / `meta_pressed` / `button_index` fields directly off the actual
## InputEvent objects the engine returns for the actions that exist RIGHT NOW in
## this running engine + project (built-in ui_* defaults are NOT written anywhere
## in project.godot — they only exist inside the engine, which is exactly why this
## must be queried live and cannot be read off a text file).
##
## This script does NOT reimplement Godot's own InputEventKey.is_match() /
## InputEventJoypadButton.is_match() comparison semantics. It does its own explicit
## field-equality comparison instead, so that every comparison rule used here is
## visible in this file rather than hidden inside an engine method whose exact
## semantics (modifier handling, device wildcards) this project has never verified.
## That field-equality logic itself is therefore a project-authored rule, not an
## engine query — disclosed here rather than silently presented as "the engine
## decided this," per the (A)-grade discipline's requirement to list every
## re-implemented rule.
##
## KEY_* / JOY_BUTTON_* constants below are NOT hardcoded integers copied from
## training-data memory — they are GDScript global-scope enum names resolved by
## THIS engine build at parse time. The actual integer values are printed in the
## output for inspection (see "constants resolved by this engine build" section).
##
## Run:
##   "<godot path>" --headless --path . -s prototypes/u004-inputmap-probe-2026-09-16/probe_input_map.gd
extends SceneTree

## Deliberately excluded factors — see README "刻意未計入的因素" for the authoritative list.
## Summary: (1) only bare-key exact match is checked for battle_cancel/open_hand/
## next_target/battle_menu (Ctrl/Alt/Meta combos of the same key are NOT flagged);
## (2) prev_target's Shift+Tab check requires shift_pressed=true and ctrl/alt/meta=false,
## it does not check Shift+Ctrl+Tab etc.; (3) gamepad matching is device-agnostic
## (button_index only, no device id comparison) — acceptable because this project
## has no local multiplayer; (4) mouse-only bindings are not checked (none of the
## 5 candidates are mouse keys); (5) addon-registered actions are not separately
## enumerated — InputMap.get_actions() already returns the full merged set including
## any addon-declared actions, so this is covered by construction, not skipped.

const CANDIDATES: Array[Dictionary] = [
	{
		"action_name": "battle_cancel", "purpose": "取消 / 退一步",
		"key": KEY_ESCAPE, "key_label": "Esc", "shift": false,
		"joy": JOY_BUTTON_B, "joy_label": "B (右動作鍵)",
	},
	{
		"action_name": "open_hand", "purpose": "開 / 收手牌",
		"key": KEY_C, "key_label": "C", "shift": false,
		"joy": JOY_BUTTON_X, "joy_label": "X (左動作鍵)",
	},
	{
		"action_name": "next_target", "purpose": "跳下一個合法目標",
		"key": KEY_TAB, "key_label": "Tab", "shift": false,
		"joy": JOY_BUTTON_RIGHT_SHOULDER, "joy_label": "RB",
	},
	{
		"action_name": "prev_target", "purpose": "跳上一個合法目標",
		"key": KEY_TAB, "key_label": "Shift+Tab", "shift": true,
		"joy": JOY_BUTTON_LEFT_SHOULDER, "joy_label": "LB",
	},
	{
		"action_name": "battle_menu", "purpose": "開啟選單",
		"key": KEY_M, "key_label": "M", "shift": false,
		"joy": JOY_BUTTON_START, "joy_label": "Start",
	},
]


func _key_event_matches(event: InputEventKey, target_keycode: int, want_shift: bool) -> bool:
	# Project-authored comparison rule (disclosed above, not an engine-native match).
	var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if kc != target_keycode:
		return false
	if event.shift_pressed != want_shift:
		return false
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return false
	return true


func _find_key_conflicts(all_actions: Array, target_keycode: int, want_shift: bool) -> Array[StringName]:
	var hits: Array[StringName] = []
	for action in all_actions:
		for e in InputMap.action_get_events(action):
			if e is InputEventKey and _key_event_matches(e, target_keycode, want_shift):
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


func _action_sides(action: StringName) -> Dictionary:
	var has_kb := false
	var has_joy := false
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			has_kb = true
		elif e is InputEventJoypadButton:
			has_joy = true
	return {"keyboard": has_kb, "joypad": has_joy}


var _all_conflicting_actions: Dictionary = {}  # StringName -> true, accumulated for the raw dump at the end


func _print_hits(label: String, hits: Array[StringName]) -> void:
	if hits.is_empty():
		print("  %s -> 未被佔用" % label)
		return
	print("  %s -> 已被佔用: %s" % [label, hits])
	for a in hits:
		var sides: Dictionary = _action_sides(a)
		var both_sides: String = "是(同時有鍵盤+手把)" if (sides["keyboard"] and sides["joypad"]) else "否(僅單側)"
		print("    - %s | 該動作同時有鍵盤與手把綁定: %s" % [a, both_sides])
		_all_conflicting_actions[a] = true


func _dump_action_raw(a: StringName) -> void:
	print("  %s:" % a)
	for e in InputMap.action_get_events(a):
		if e is InputEventKey:
			print("    InputEventKey keycode=%d physical_keycode=%d shift=%s ctrl=%s alt=%s meta=%s" \
				% [e.keycode, e.physical_keycode, e.shift_pressed, e.ctrl_pressed, e.alt_pressed, e.meta_pressed])
		elif e is InputEventJoypadButton:
			print("    InputEventJoypadButton button_index=%d" % e.button_index)
		else:
			print("    %s (未特別解析)" % e.get_class())


func _initialize() -> void:
	print("=== Story U-004 InputMap probe (2026-09-16) ===")
	print("Engine version: %s" % Engine.get_version_info())

	var all_actions: Array = InputMap.get_actions()
	print("InputMap 在 headless 下可讀: %s (get_actions() 回傳 %d 個動作,非空即為可讀)" \
		% [not all_actions.is_empty(), all_actions.size()])

	print("\n--- 本次使用的引擎常數,由本引擎建置即時解析,非記憶中的數字 ---")
	print("KEY_ESCAPE=%d  KEY_C=%d  KEY_TAB=%d  KEY_M=%d" % [KEY_ESCAPE, KEY_C, KEY_TAB, KEY_M])
	print("JOY_BUTTON_A=%d  JOY_BUTTON_B=%d  JOY_BUTTON_X=%d  JOY_BUTTON_Y=%d  JOY_BUTTON_START=%d  JOY_BUTTON_LEFT_SHOULDER=%d  JOY_BUTTON_RIGHT_SHOULDER=%d" \
		% [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER])

	print("\n--- 5 個候選鍵逐項查核(鍵盤 + 手把兩側,共 10 個按鍵) ---")
	for c in CANDIDATES:
		print("\n[%s — %s]  鍵盤建議=%s  手把建議=%s" \
			% [c["action_name"], c["purpose"], c["key_label"], c["joy_label"]])
		var kb_hits: Array[StringName] = _find_key_conflicts(all_actions, c["key"], c["shift"])
		_print_hits("鍵盤 %s" % c["key_label"], kb_hits)
		var joy_hits: Array[StringName] = _find_joy_conflicts(all_actions, c["joy"])
		_print_hits("手把 %s" % c["joy_label"], joy_hits)

	print("\n--- 陷阱九覆核:手把 X(左動作鍵)是否真的比 Y(上動作鍵)更安全? ---")
	print("既有結論(2026-08-27,轉錄於 EPIC.md):ui_select 的手把綁定 = Y(上動作鍵),")
	print("鍵盤綁定 = Space,而 Space 已被 battle_confirm 佔用 → 同一次按鍵觸發兩個動作。")
	var y_hits: Array[StringName] = _find_joy_conflicts(all_actions, JOY_BUTTON_Y)
	print("本次覆核 JOY_BUTTON_Y 佔用者:")
	_print_hits("手把 Y", y_hits)
	var x_hits: Array[StringName] = _find_joy_conflicts(all_actions, JOY_BUTTON_X)
	print("本次覆核 JOY_BUTTON_X 佔用者(即 open_hand 建議鍵,上方已查過,這裡重列以便對照):")
	_print_hits("手把 X", x_hits)

	print("\n--- Esc / B 特別檢查:除了 battle_end_phase 之外,是否還有其他動作佔用? ---")
	var esc_hits: Array[StringName] = _find_key_conflicts(all_actions, KEY_ESCAPE, false)
	var esc_others: Array[StringName] = []
	for a in esc_hits:
		if a != &"battle_end_phase":
			esc_others.append(a)
	print("鍵盤 Esc 佔用者(全部): %s" % [esc_hits])
	print("鍵盤 Esc 佔用者(排除 battle_end_phase 之後): %s" % [esc_others])
	var b_hits: Array[StringName] = _find_joy_conflicts(all_actions, JOY_BUTTON_B)
	var b_others: Array[StringName] = []
	for a in b_hits:
		if a != &"battle_end_phase":
			b_others.append(a)
	print("手把 B 佔用者(全部): %s" % [b_hits])
	print("手把 B 佔用者(排除 battle_end_phase 之後): %s" % [b_others])

	print("\n--- 附:project.godot 自訂動作(battle_confirm / battle_end_phase)的完整綁定原始資料 ---")
	for a in [&"battle_confirm", &"battle_end_phase"]:
		if not InputMap.has_action(a):
			print("  %s: 不存在" % a)
			continue
		_dump_action_raw(a)

	print("\n--- 附:上面每一項判定為「已被佔用」的動作,其完整綁定原始資料(逐一列出,供覆核不必相信本腳本的布林判定) ---")
	var conflict_names: Array = _all_conflicting_actions.keys()
	conflict_names.sort()
	for a in conflict_names:
		_dump_action_raw(a)

	print("\n=== Probe complete ===")
	quit()
