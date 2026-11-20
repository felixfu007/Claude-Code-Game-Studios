extends Node
## 午休截圖驅動(拋棄式)。真實 BattleScreen.tscn + vs02 四個真實資料檔(override)。
## 開窗存 PNG 到 out/;headless 印 HEADLESS: skip capture、不寫檔、自行 quit。

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _OUT_DIR: String = "res://prototypes/capture-2026-11-20-lunch/out"
const _TERRAIN: String = "res://assets/data/levels/vs02_terrain.txt"
const _ROSTER: String = "res://assets/data/units/vs02_roster.txt"
const _AFFINITY: String = "res://assets/data/affinity/vs02_affinity_links.txt"
const _CARDS: String = "res://assets/data/cards/vs02_cards.txt"
const _CARD_TEXT: String = "res://assets/data/cards/vs02_card_text.txt"
const _RESOLUTIONS: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1920, 1080)]
const _SCENARIOS: Array[String] = [
	"1_confirm_panel", "2_relation_map_detail", "3_infocard_relation", "4_infocard_straddle",
	"5_hand_unplayable_reason", "6_hand_card22_long_face",
]

var _headless: bool = false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_run.call_deferred()


func _run() -> void:
	if not _headless:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_OUT_DIR))
	for res: Vector2i in _RESOLUTIONS:
		get_tree().root.size = res
		get_tree().root.content_scale_size = Vector2i.ZERO
		for i in 3:
			await get_tree().process_frame
		for scn: String in _SCENARIOS:
			await _capture_one(scn, res)
	print("DONE (headless=", _headless, ")")
	get_tree().quit()


func _new_screen() -> BattleScreen:
	var inst: BattleScreen = load(_SCENE_PATH).instantiate()
	inst.terrain_path_override = _TERRAIN
	inst.roster_path_override = _ROSTER
	inst.affinity_path_override = _AFFINITY
	inst.cards_path_override = _CARDS
	inst.card_text_path_override = _CARD_TEXT
	get_tree().root.call_deferred("add_child", inst)
	await get_tree().process_frame
	await get_tree().process_frame
	return inst


func _capture_one(scn: String, res: Vector2i) -> void:
	var inst: BattleScreen = await _new_screen()
	var note: String = ""
	if inst._load_failed or inst._controller == null:
		note = "LOAD_FAILED"
	else:
		match scn:
			"1_confirm_panel":
				_install_cards(inst, [_hp_card(2)])
				inst._input(_pressed(&"battle_open_hand"))
				inst._input(_pressed(&"battle_confirm"))
				if not inst._card_confirming:
					if inst._controller.select_target(inst._state.units_of(Unit.Faction.PLAYER)[0].id):
						inst._after_target_selection_advanced()
				note = "confirming=%s" % inst._card_confirming
			"2_relation_map_detail":
				_write(inst, 1, 3, 1.0)
				_write(inst, 2, 3, -1.0)
				_write(inst, 2, 4, 1.0)
				_write(inst, 3, 4, -1.0)
				inst._refresh_view()
				inst._toggle_relation_minimap()
				inst._refresh_view()
				note = "minimap_visible=%s detail_rows=%d" % [
					inst.diagnostic_relation_minimap_visible(), inst.diagnostic_relation_detail_rows().size()]
			"3_infocard_relation":
				_write(inst, 1, 2, 1.0)
				inst._controller.select_unit(1)
				_cursor_on(inst, 2)
				note = "rows=%s" % [inst.diagnostic_tile_info_relation_rows()]
			"4_infocard_straddle":
				_cursor_on(inst, 5)
				note = "rows=%s" % [inst.diagnostic_tile_info_relation_rows()]
			"5_hand_unplayable_reason", "6_hand_card22_long_face":
				var cards: Array[Card] = _vs02_cards()
				var c22: Card = null
				for c: Card in cards:
					if c.id == "card_22":
						c22 = c
				var payer: Unit = inst._state.units_of(Unit.Faction.PLAYER)[0]
				var hpc: Card = Card.new_temporary_stat_modifier("cap_hp", 1, 0, 1, payer.id)
				hpc.cost_type = Card.CostType.HP
				hpc.cost_amount = 2
				var wound: int = payer.hp - 2
				inst._state.commit_authoritative_change(func() -> void: payer.take_damage(wound))
				var deck_cards: Array[Card] = [hpc]
				if c22 != null:
					deck_cards.append(c22)
				_install_cards(inst, deck_cards)
				inst._handle_open_hand_pressed()
				inst._hand_bar._set_expand_progress(1.0)
				var want: String = "cap_hp" if scn.begins_with("5") else "card_22"
				var hand: Array = inst._state.card_deck().hand()
				for i in hand.size():
					if (hand[i] as Card).id == want:
						inst._hand_bar.move_cursor(i - inst._hand_bar.diagnostic_cursor_index())
				inst._refresh_view()
				note = "card22_found=%s want=%s hand=%d reason='%s'" % [
					c22 != null, want, hand.size(), inst._hand_bar.diagnostic_detail_reason_text()]
	for i in 3:
		await get_tree().process_frame
	var wvc: SubViewportContainer = inst.get_node("WorldViewportContainer")
	var wv: SubViewport = inst.get_node("WorldViewportContainer/WorldViewport")
	print("HOSTCHAIN scn=%s res=%s window=%s WVC.pos=%s WVC.size=%s stretch_shrink=%d WV.size=%s %s" % [
		scn, res, get_tree().root.size, wvc.position, wvc.size, wvc.stretch_shrink, wv.size, note])
	if _headless:
		print("HEADLESS: skip capture ", scn, " ", res)
	else:
		var img: Image = get_tree().root.get_texture().get_image()
		if img == null:
			push_error("get_image() null in windowed run: " + scn)
		else:
			var path: String = "%s/%s_%dx%d.png" % [_OUT_DIR, scn, res.x, res.y]
			img.save_png(path)
			print("SAVED ", path, " img=", img.get_size())
	inst.queue_free()
	await get_tree().process_frame
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host != null:
		var registry: CursorSurfaceRegistry = host.get(&"_registry")
		registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


func _pressed(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var d: InputEventKey = (event as InputEventKey).duplicate()
			d.pressed = true
			return d
	return null


func _vs02_cards() -> Array[Card]:
	var parsed: Variant = Card.cards_from_text(FileAccess.get_file_as_string(_CARDS))
	var out: Array[Card] = []
	if parsed != null:
		out = parsed
	return out


func _hp_card(amount: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("cap_hp", 1, 0, 1, Card.UNRESTRICTED_TARGET)
	card.cost_type = Card.CostType.HP
	card.cost_amount = amount
	return card


func _install_cards(instance: BattleScreen, cards: Array[Card]) -> void:
	var deck: CardDeck = CardDeck.new(cards)
	instance._state.attach_card_deck(deck)
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = CardPlaySession.new(
		deck, instance._state, links, NullAffinityWritePort.new())
	session.attach_affinity_pool(instance._affinity_pool)
	instance._controller._card_play_session = session


func _write(screen: BattleScreen, a: int, b: int, m: float) -> void:
	var pair: Variant = CardCostPlan.pair_of_units(a, b)
	screen._affinity_pool.append_record(int(pair) as AffinityTypes.Pair, m, AffinityTypes.Source.STORY_EVENT)


func _cursor_on(screen: BattleScreen, unit_id: int) -> void:
	screen._cursor_cell = screen._state.position_of(unit_id)
	screen._cursor_active = true
	screen._tile_info_cursor_valid = true
	screen._update_tile_info_panel()
	screen._refresh_view()
