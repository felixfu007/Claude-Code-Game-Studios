## 音樂播放殼(audio-foundation story-004)。常駐宿主,掛在 [code]tree.root[/code],不是 Autoload。
##
## 為什麼掛 root:SceneRouter 每次切換都釋放舊場景,場景內的節點會把音樂砍斷;root 永不釋放。
## 入口只有兩處:[method SceneRouter.switch_to] 與開機場景 TitleScreen,兩處皆呼叫
## [method ensure_on_root](冪等)再 [method enter_scene]。
## 🔴 [method Node._ready] 內對 root add_child 會被引擎拒絕,故一律 call_deferred。
## 🔴 素材缺席安靜:不 push_error / push_warning。headless 下只驗決策與 volume_db 終值,聽感不可自動化。
## 循環:載入後若 stream 有 [code]loop[/code] 屬性(AudioStreamOggVorbis)就設 true(.import 旗標亦可)。
class_name MusicPlayerHost
extends Node

const HOST_NODE_NAME: String = "MusicPlayerHost"
const ROOT_META_KEY: StringName = &"music_player_host"

## 為 false 時只做決策與狀態記錄,不建立播放器(測試用)。
var playback_enabled: bool = true
## Callable() -> bool;預設讀 GameSettings.is_muted。
var muted_check: Callable = Callable()
## Callable(path: String) -> bool;預設 ResourceLoader.exists。
var asset_exists: Callable = Callable()
## Callable(path: String) -> AudioStream;預設 load()。
var stream_loader: Callable = Callable()

## 診斷:每次 enter_scene 的 [scene_key, Action];以及實際送出的播放請求路徑。
var diagnostic_actions: Array = []
var diagnostic_play_requests: Array[String] = []
## 目前(決策上)正在播的曲目路徑,空字串 = 沒有。
var current_track: String = ""

var _tracks: Dictionary = {}
var _tracks_configured: bool = false
var _pending_scene_key: StringName = &""
var _has_pending: bool = false
var _current_fade_out_ms: int = 0
var _player: AudioStreamPlayer
var _tween: Tween


## 確保 root 下恰好一個宿主(冪等);尚未進樹的宿主由 call_deferred 加入。
static func ensure_on_root(tree: SceneTree) -> MusicPlayerHost:
	var root: Window = tree.root
	if root.has_meta(ROOT_META_KEY):
		var existing: Variant = root.get_meta(ROOT_META_KEY)
		if is_instance_valid(existing):
			return existing as MusicPlayerHost
	var host: MusicPlayerHost = MusicPlayerHost.new()
	host.name = HOST_NODE_NAME
	root.set_meta(ROOT_META_KEY, host)
	root.add_child.call_deferred(host)
	return host


## 注入曲目表(測試用);未注入則 [method _ready] 讀真實資料檔。
func configure(tracks: Dictionary) -> void:
	_tracks = tracks
	_tracks_configured = true


func _ready() -> void:
	# 管理者裁決 2026-11-10:戰鬥選單開啟會 tree.paused = true,音樂須繼續播(探針
	# prototypes/audio-pause-probe-2026-11-10:INHERIT 下播放器被暫停、node 綁定 Tween 卡住)。
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _tracks_configured:
		_tracks = _load_default_tracks()
		_tracks_configured = true
	if playback_enabled:
		_player = AudioStreamPlayer.new()
		_player.bus = AudioBuses.BUS_MUSIC
		add_child(_player)
	if _has_pending:
		_has_pending = false
		_apply_scene(_pending_scene_key)


func _exit_tree() -> void:
	_kill_tween()


## 通知場景改變。宿主尚未 ready(deferred 加入前)時暫存,ready 後套用。
func enter_scene(scene_key: StringName) -> void:
	if scene_key == &"":
		# 未知場景:不改變目前音樂。
		return
	if not is_node_ready():
		_pending_scene_key = scene_key
		_has_pending = true
		return
	_apply_scene(scene_key)


func _apply_scene(scene_key: StringName) -> void:
	var entry: Dictionary = _tracks.get(scene_key, {})
	var new_track: String = String(entry.get("path", ""))
	var exists: bool = false
	if not new_track.is_empty():
		exists = bool(asset_exists.call(new_track)) if asset_exists.is_valid() else ResourceLoader.exists(new_track)
	var muted: bool = bool(muted_check.call()) if muted_check.is_valid() else GameSettings.is_muted()
	var action: MusicPolicy.Action = MusicPolicy.decide(current_track, new_track, exists, muted)
	diagnostic_actions.append([scene_key, action])
	var out_ms: int = _current_fade_out_ms
	match action:
		MusicPolicy.Action.FADE_IN:
			_start_track(new_track, entry)
		MusicPolicy.Action.SWITCH:
			_switch_track(new_track, entry, out_ms)
		MusicPolicy.Action.FADE_OUT:
			current_track = ""
			_fade_out_and_stop(out_ms)
		_:
			pass


func _start_track(path: String, entry: Dictionary) -> void:
	current_track = path
	_current_fade_out_ms = int(entry.get("fade_out_ms", 0))
	diagnostic_play_requests.append(path)
	if _player == null:
		return
	var stream: AudioStream = _load_stream(path)
	if stream == null:
		current_track = ""
		return
	_kill_tween()
	_player.stream = stream
	var fade_in_ms: int = int(entry.get("fade_in_ms", 0))
	if fade_in_ms <= 0:
		_player.volume_db = 0.0
		_player.play()
		return
	_player.volume_db = AudioBuses.SILENT_DB
	_player.play()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", 0.0, float(fade_in_ms) / 1000.0)


func _switch_track(path: String, entry: Dictionary, out_ms: int) -> void:
	# 決策層立即記下新曲目,連續切場景時才會以最新狀態比較。
	current_track = path
	_current_fade_out_ms = int(entry.get("fade_out_ms", 0))
	diagnostic_play_requests.append(path)
	if _player == null:
		return
	_kill_tween()
	if out_ms <= 0 or not _player.playing:
		_begin_loaded_track(path, entry)
		return
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", AudioBuses.SILENT_DB, float(out_ms) / 1000.0)
	_tween.tween_callback(_begin_loaded_track.bind(path, entry))


func _begin_loaded_track(path: String, entry: Dictionary) -> void:
	var stream: AudioStream = _load_stream(path)
	if stream == null:
		current_track = ""
		_player.stop()
		return
	_player.stop()
	_player.stream = stream
	var fade_in_ms: int = int(entry.get("fade_in_ms", 0))
	if fade_in_ms <= 0:
		_player.volume_db = 0.0
		_player.play()
		return
	_player.volume_db = AudioBuses.SILENT_DB
	_player.play()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", 0.0, float(fade_in_ms) / 1000.0)


func _fade_out_and_stop(out_ms: int) -> void:
	if _player == null:
		return
	_kill_tween()
	if out_ms <= 0 or not _player.playing:
		_player.stop()
		_player.volume_db = AudioBuses.SILENT_DB
		return
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", AudioBuses.SILENT_DB, float(out_ms) / 1000.0)
	_tween.tween_callback(_player.stop)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _load_stream(path: String) -> AudioStream:
	var stream: AudioStream = null
	if stream_loader.is_valid():
		stream = stream_loader.call(path) as AudioStream
	else:
		stream = load(path) as AudioStream
	if stream != null and "loop" in stream:
		stream.set("loop", true)
	return stream


func _load_default_tracks() -> Dictionary:
	var text: String = ""
	if FileAccess.file_exists(MusicTrackTable.TABLE_PATH):
		text = FileAccess.get_file_as_string(MusicTrackTable.TABLE_PATH)
	return MusicTrackTable.parse(text)["tracks"]
