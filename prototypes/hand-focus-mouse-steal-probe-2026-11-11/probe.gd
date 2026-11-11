extends SceneTree
# Probe: does a tiny MouseMotion steal hand focus? Loads REAL BattleScreen.tscn.
# Headless: engine delivers no InputEvents, so we call BattleScreen._input() directly
# (the production entry point; it is _input, not _unhandled_input).

func _initialize() -> void:
	var inst: Node = (load("res://src/ui/battle/BattleScreen.tscn") as PackedScene).instantiate()
	root.call_deferred("add_child", inst)
	await process_frame
	await process_frame
	var hb = inst.get("_hand_bar")
	print("PROBE hand_bar=", hb, " phase=", inst.get("_controller").phase())
	# production open path
	inst.call("_handle_open_hand_pressed")
	print("PROBE after open: from_hand=", inst.get("_card_selecting_from_hand"), " slots=", hb.diagnostic_slot_count())
	await create_timer(1.0).timeout
	await process_frame
	print("PROBE expanded=", hb.diagnostic_is_expanded(), " progress=", hb.diagnostic_expand_progress())
	var n: int = hb.diagnostic_slot_count()
	if n < 2:
		print("PROBE RESULT: UNMEASURABLE slots<2")
		quit(2)
		return
	# keyboard/gamepad: ui_right via production navigation path
	Input.action_press(&"ui_right")
	var ev := InputEventAction.new()
	ev.action = &"ui_right"
	ev.pressed = true
	inst.call("_input", ev)
	Input.action_release(&"ui_right")
	var kb: int = hb.diagnostic_cursor_index()
	print("PROBE after ui_right: cursor_index=", kb)
	# find a slot other than kb; compute its centre via production geometry
	var other: int = 0 if kb != 0 else 1
	var panels: Array = hb.get("_slot_nodes")
	var p: Panel = panels[other]
	var c: Vector2 = p.get_global_transform() * (p.size / 2.0)
	print("PROBE target slot=", other, " centre=", c, " slot_index_at(centre)=", hb.slot_index_at(c))
	# control: mouse over the CURRENT card, tiny relative
	var pk: Panel = panels[kb]
	var ck: Vector2 = pk.get_global_transform() * (pk.size / 2.0)
	var m0 := InputEventMouseMotion.new()
	m0.position = ck
	m0.relative = Vector2(1, 0)
	inst.call("_input", m0)
	print("PROBE control (mouse on same card, rel=(1,0)): cursor_index=", hb.diagnostic_cursor_index(), " expected unchanged=", kb)
	# test: mouse on OTHER card, relative (1,0)
	var m1 := InputEventMouseMotion.new()
	m1.position = c
	m1.relative = Vector2(1, 0)
	inst.call("_input", m1)
	var after: int = hb.diagnostic_cursor_index()
	print("PROBE test (mouse on other card, rel=(1,0)): cursor_index=", after, " before=", kb, " stolen=", after != kb)
	print("PROBE RESULT: ", "CONFIRMED focus stolen by 1px motion" if after == other else "NOT stolen")
	quit(0)
