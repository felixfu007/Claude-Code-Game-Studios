extends Node
## story-020a AC5 截圖驅動(拋棄式)。載入真實 BattleScreen.tscn,
## 沿用 tests/integration/ui/battle/battle_screen_card_confirm_cost_panel_test.gd 的注入/輸入路徑。
## 3 態 x 2 解析度 = 6 張 PNG -> out/。headless 時跳過寫檔。

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _OUT_DIR: String = "res://prototypes/story-020a-confirm-panel-capture-2026-11-19/out"
const _WIDE_RANGE: int = 99
const _RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const _SCENARIOS: Array[String] = ["1_single_hp", "2_duo_fray", "3_unaffordable"]

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


func _capture_one(scn: String, res: Vector2i) -> void:
	var inst: BattleScreen = load(_SCENE_PATH).instantiate()
	# 本驅動不設任何 *_path_override:用場景預設真實資料(與測試一致)
	get_tree().root.call_deferred("add_child", inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var units: Array[Unit] = inst._state.units_of(Unit.Faction.PLAYER)
	var a: Unit = units[0]
	var b: Unit = units[1]
	match scn:
		"1_single_hp":
			_install_card(inst, _hp_card(2))
			_enter_confirming(inst, a.id)
		"2_duo_fray":
			var pool: AffinityDataPool = _install_card(inst, _duo_buff(a.id, b.id))
			var pair: Variant = CardCostPlan.pair_of_units(a.id, b.id)
			pool.append_record(int(pair) as AffinityTypes.Pair, 1.0, AffinityTypes.Source.STORY_EVENT)
			_enter_confirming(inst, -1)
		"3_unaffordable":
			_install_card(inst, _hp_card(2))
			var amount: int = a.hp - 2
			inst._state.commit_authoritative_change(func() -> void: a.take_damage(amount))
			_enter_confirming(inst, a.id)
	for i in 3:
		await get_tree().process_frame
	var confirming: bool = inst._card_confirming
	var wvc: SubViewportContainer = inst.get_node("WorldViewportContainer")
	var wv: SubViewport = inst.get_node("WorldViewportContainer/WorldViewport")
	var rect: Rect2 = CardConfirmPanel.panel_rect(get_tree().root.size)
	print("HOSTCHAIN scn=%s res=%s window=%s confirming=%s WVC.pos=%s WVC.size=%s stretch_shrink=%d WV.size=%s panel_rect=%s" % [
		scn, res, get_tree().root.size, confirming, wvc.position, wvc.size, wvc.stretch_shrink, wv.size, rect])
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


# ---- 夾具(照抄測試) ----

func _pressed(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var d: InputEventKey = (event as InputEventKey).duplicate()
			d.pressed = true
			return d
	return null


func _hp_card(amount: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("t020_hp", 1, 0, 1, Card.UNRESTRICTED_TARGET)
	card.cost_type = Card.CostType.HP
	card.cost_amount = amount
	return card


func _duo_buff(a: int, b: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("t020_duo", 2, 1, 2, a)
	card.cost_type = Card.CostType.PAIR
	card.cost_amount = 1
	card.partner_unit_id = b
	card.target_range = _WIDE_RANGE
	return card


func _install_card(instance: BattleScreen, card: Card) -> AffinityDataPool:
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards)
	instance._state.attach_card_deck(deck)
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = CardPlaySession.new(
		deck, instance._state, links, NullAffinityWritePort.new()
	)
	var pool: AffinityDataPool = AffinityDataPool.new()
	session.attach_affinity_pool(pool)
	instance._controller._card_play_session = session
	return pool


func _enter_confirming(instance: BattleScreen, target_id: int) -> void:
	instance._input(_pressed(&"battle_open_hand"))
	instance._input(_pressed(&"battle_confirm"))
	if not instance._card_confirming and target_id >= 1:
		if instance._controller.select_target(target_id):
			instance._after_target_selection_advanced()
