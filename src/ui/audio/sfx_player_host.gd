## 音效播放殼與 signal 接線(audio-foundation story-003)。每個場景一個,不是 Autoload。
##
## - M1:進樹時連 [signal SceneTree.node_added],對本宿主父節點子樹內的每個 BaseButton 連 pressed;
##   [method _ready] 補連既有按鈕;按鈕離樹即斷線。
## - M2~M9:[method bind_battle] 接 BattleController / AffinityDataPool / BattleMenu 的既有 signal。
##
## 🔴 ADR-0001:所有回呼只做「決策 + 播放請求」,不 await、不回寫戰鬥狀態、不用 deferred。
## 🔴 素材缺席安靜:不 push_error / push_warning(見 [SfxCuePolicy])。
## 🔴 headless 下音訊是 no-op,自動測試只驗決策([member diagnostic_play_requests] 等)。
class_name SfxPlayerHost
extends Node

const GROUP_NAME: StringName = &"sfx_host"
const HOST_NODE_NAME: String = "SfxPlayerHost"
## 同時發聲的 AudioStreamPlayer 數量。
const PLAYER_POOL_SIZE: int = 6

## 為 false 時只記錄決策、不真的送 AudioStreamPlayer(測試用)。
var playback_enabled: bool = true
## Callable() -> bool;預設讀 GameSettings.is_muted。
var muted_check: Callable = Callable()

## 診斷(唯讀語意):每次 request_cue 的 cue_id 與決策;以及決策為 PLAY 的 cue_id 序列。
var diagnostic_decisions: Array = []
var diagnostic_play_requests: Array[StringName] = []

var _policy: SfxCuePolicy
var _players: Array[AudioStreamPlayer] = []
var _connected_buttons: Dictionary = {} # instance_id -> {"pressed": Callable, "exit": Callable}
var _bound_controller: BattleController


## 在 [param root] 下確保恰好一個宿主(已有就回傳既有的)。
static func attach_to(root: Node) -> SfxPlayerHost:
	for child: Node in root.get_children():
		if child is SfxPlayerHost:
			return child as SfxPlayerHost
	var host: SfxPlayerHost = SfxPlayerHost.new()
	host.name = HOST_NODE_NAME
	root.add_child(host)
	return host


## 注入決策核心(測試用);未注入則 [method _ready] 以真實 CSV 組裝。
func configure(policy: SfxCuePolicy) -> void:
	_policy = policy


func _enter_tree() -> void:
	add_to_group(GROUP_NAME)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _ready() -> void:
	if _policy == null:
		_policy = _build_default_policy()
	if playback_enabled:
		for i: int in range(PLAYER_POOL_SIZE):
			var player: AudioStreamPlayer = AudioStreamPlayer.new()
			add_child(player)
			_players.append(player)
	var scope: Node = get_parent()
	if scope != null:
		_connect_buttons_under(scope)


func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)
	for id: int in _connected_buttons.keys():
		var button: Object = instance_from_id(id)
		if button is BaseButton:
			_disconnect_button(button as BaseButton)
	_connected_buttons.clear()


## 以現有的 controller / pool / menu 接 M2~M9。menu、pool 可為 null。
func bind_battle(controller: BattleController, pool: AffinityDataPool, menu: BattleMenu = null) -> void:
	_bound_controller = controller
	controller.unit_selected.connect(_on_unit_selected)
	controller.selection_cleared.connect(_on_selection_cleared)
	controller.unit_moved.connect(_on_unit_moved)
	controller.attack_resolved.connect(_on_attack_resolved)
	controller.battle_ended.connect(_on_battle_ended)
	if pool != null:
		pool.entry_appended.connect(_on_entry_appended)
	if menu != null:
		menu.open_rejected.connect(_on_open_rejected)


## 決策並(必要時)送出播放請求。回傳 [enum SfxCuePolicy.Decision]。
func request_cue(cue_id: StringName) -> int:
	if _policy == null:
		return SfxCuePolicy.Decision.UNKNOWN_CUE
	var muted: bool = bool(muted_check.call()) if muted_check.is_valid() else GameSettings.is_muted()
	var decision: SfxCuePolicy.Decision = _policy.decide(cue_id, muted)
	diagnostic_decisions.append([cue_id, decision])
	if decision == SfxCuePolicy.Decision.PLAY:
		diagnostic_play_requests.append(cue_id)
		_send_to_player(_policy.path_of(cue_id), _policy.bus_of(cue_id))
	return decision


func _build_default_policy() -> SfxCuePolicy:
	var text: String = ""
	if FileAccess.file_exists(SfxCueTable.CSV_PATH):
		text = FileAccess.get_file_as_string(SfxCueTable.CSV_PATH)
	var parsed: Dictionary = SfxCueTable.parse(text)
	return SfxCuePolicy.new(
		parsed["cues"],
		Callable(Time, "get_ticks_msec"),
		func(path: String) -> bool: return ResourceLoader.exists(path),
	)


func _send_to_player(path: String, bus: StringName) -> void:
	if not playback_enabled:
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			player.stream = stream
			player.bus = bus
			player.play()
			return


# ---- M1 -----------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	var scope: Node = get_parent()
	if scope == null or not (node is BaseButton):
		return
	if scope == node or scope.is_ancestor_of(node):
		_connect_button(node as BaseButton)


func _connect_buttons_under(scope: Node) -> void:
	if scope is BaseButton:
		_connect_button(scope as BaseButton)
	for child: Node in scope.get_children():
		_connect_buttons_under(child)


func _connect_button(button: BaseButton) -> void:
	var id: int = button.get_instance_id()
	if _connected_buttons.has(id):
		return
	var on_pressed: Callable = _on_button_pressed
	var on_exit: Callable = _on_button_tree_exiting.bind(button)
	button.pressed.connect(on_pressed)
	button.tree_exiting.connect(on_exit)
	_connected_buttons[id] = {"pressed": on_pressed, "exit": on_exit}


func _disconnect_button(button: BaseButton) -> void:
	var id: int = button.get_instance_id()
	if not _connected_buttons.has(id):
		return
	var entry: Dictionary = _connected_buttons[id]
	if button.pressed.is_connected(entry["pressed"]):
		button.pressed.disconnect(entry["pressed"])
	if button.tree_exiting.is_connected(entry["exit"]):
		button.tree_exiting.disconnect(entry["exit"])
	_connected_buttons.erase(id)


func _on_button_tree_exiting(button: BaseButton) -> void:
	_disconnect_button(button)


func _on_button_pressed() -> void:
	request_cue(SfxCueTable.CUE_UI_CLICK)


# ---- M2~M9(皆不 await、不回寫戰鬥狀態)---------------------------------

func _on_unit_selected(_id: int) -> void:
	request_cue(SfxCueTable.CUE_UNIT_SELECT)


func _on_selection_cleared() -> void:
	request_cue(SfxCueTable.CUE_CANCEL)


func _on_open_rejected(_result: int, _message: String) -> void:
	request_cue(SfxCueTable.CUE_CANCEL)


func _on_unit_moved(_id: int, _from: Vector2i, _to: Vector2i) -> void:
	request_cue(SfxCueTable.CUE_UNIT_MOVE)


## M5 / M6 二擇一:擊倒只出 unit_down。
func _on_attack_resolved(_attacker_id: int, _target_id: int, _damage: int, target_died: bool) -> void:
	if target_died:
		request_cue(SfxCueTable.CUE_UNIT_DOWN)
	else:
		request_cue(SfxCueTable.CUE_ATTACK_HIT)


func _on_battle_ended(outcome: BattleState.Outcome) -> void:
	if outcome == BattleState.Outcome.VICTORY:
		request_cue(SfxCueTable.CUE_VICTORY)
	elif outcome == BattleState.Outcome.DEFEAT:
		request_cue(SfxCueTable.CUE_DEFEAT)


## M9:依紀錄帶號幅度分音。池已拒絕 0 / NaN / inf,故只有正、負兩種;record 為 null 時不出聲。
func _on_entry_appended(_pair: AffinityTypes.Pair, record: AffinityRecord) -> void:
	if record == null:
		return
	if record.m > 0.0:
		request_cue(SfxCueTable.CUE_AFFINITY_UP)
	elif record.m < 0.0:
		request_cue(SfxCueTable.CUE_AFFINITY_DOWN)
