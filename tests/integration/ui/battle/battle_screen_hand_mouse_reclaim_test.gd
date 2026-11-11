# Story U-020 -- 手牌滑鼠奪權門檻。
# 真實 BattleScreen.tscn,headless 直接呼叫 _input()(重現探針
# prototypes/hand-focus-mouse-steal-probe-2026-11-11/probe.gd 的手法)。
#
# I/O 揭露:甲類例外 -- load()/instantiate() 真實 BattleScreen.tscn,其 _ready()
# 唯讀 assets/data/ 下已進版控的資料檔;不寫任何檔案。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	for action: StringName in [&"ui_right", &"ui_left"]:
		Input.action_release(action)


## 開手牌並等展開;回傳 BattleScreen。
func _open_hand() -> BattleScreen:
	var inst: BattleScreen = (load(_SCENE_PATH) as PackedScene).instantiate()
	add_child(inst)
	auto_free(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	inst._handle_open_hand_pressed()
	await get_tree().create_timer(1.0).timeout
	await get_tree().process_frame
	return inst


func _press_right(inst: BattleScreen) -> void:
	Input.action_press(&"ui_right")
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_right"
	ev.pressed = true
	inst._input(ev)
	Input.action_release(&"ui_right")


func _center_of(inst: BattleScreen, slot: int) -> Vector2:
	var panels: Array = inst._hand_bar.get("_slot_nodes")
	var p: Panel = panels[slot]
	return p.get_global_transform() * (p.size / 2.0)


func _motion(inst: BattleScreen, pos: Vector2, rel: Vector2) -> void:
	var m: InputEventMouseMotion = InputEventMouseMotion.new()
	m.position = pos
	m.relative = rel
	inst._input(m)


func test_ac1_small_mouse_motion_does_not_steal_focus_after_keyboard() -> void:
	var inst: BattleScreen = await _open_hand()
	assert_int(inst._hand_bar.diagnostic_slot_count()).is_greater_equal(2)
	_press_right(inst)
	var kb: int = inst._hand_bar.diagnostic_cursor_index()
	var other: int = 0 if kb != 0 else 1
	_motion(inst, _center_of(inst, other), Vector2(1, 0))
	assert_int(inst._hand_bar.diagnostic_cursor_index()).is_equal(kb)


func test_ac2_accumulated_motion_over_threshold_reclaims_focus() -> void:
	var inst: BattleScreen = await _open_hand()
	_press_right(inst)
	var kb: int = inst._hand_bar.diagnostic_cursor_index()
	var other: int = 0 if kb != 0 else 1
	var c: Vector2 = _center_of(inst, other)
	var threshold: float = inst._hand_reclaim_config.card_slot_threshold_px
	# 分兩段累積:第一段不夠,第二段跨過門檻。
	_motion(inst, c, Vector2(threshold * 0.6, 0))
	assert_int(inst._hand_bar.diagnostic_cursor_index()).is_equal(kb)
	_motion(inst, c, Vector2(threshold * 0.6, 0))
	assert_int(inst._hand_bar.diagnostic_cursor_index()).is_equal(other)


func test_ac3_pure_mouse_follows_on_first_hover() -> void:
	var inst: BattleScreen = await _open_hand()
	var cur: int = inst._hand_bar.diagnostic_cursor_index()
	var other: int = 0 if cur != 0 else 1
	_motion(inst, _center_of(inst, other), Vector2(1, 0))
	assert_int(inst._hand_bar.diagnostic_cursor_index()).is_equal(other)


func test_ac4_threshold_comes_from_config() -> void:
	var inst: BattleScreen = await _open_hand()
	var cfg: MouseReclaimThresholdConfig = MouseReclaimThresholdConfig.new()
	cfg.card_slot_threshold_px = 5.0
	inst._hand_reclaim_config = cfg
	_press_right(inst)
	var kb: int = inst._hand_bar.diagnostic_cursor_index()
	var other: int = 0 if kb != 0 else 1
	# 預設 75 時 10px 不夠;config 改 5 後夠 -> 奪回。
	_motion(inst, _center_of(inst, other), Vector2(10, 0))
	assert_int(inst._hand_bar.diagnostic_cursor_index()).is_equal(other)
