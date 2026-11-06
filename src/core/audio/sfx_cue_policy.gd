## 音效播放決策核心(audio-foundation story-003,純、可 new())。
##
## 輸入 (cue_id, 靜音旗標) → 輸出 [enum Decision]。時鐘與「素材是否存在」皆注入(Callable),
## 不直接呼叫 Time / ResourceLoader。🔴 本檔刻意不呼叫 push_error / push_warning:
## 素材缺席必須安靜(同一缺席路徑的結果快取,不重複查詢)。
##
## 決策順序:未知 cue → 靜音 → 素材缺席 → 最小間隔。只有「播」才更新該 cue 的最後播放時間。
class_name SfxCuePolicy
extends RefCounted

enum Decision { PLAY, MUTED, ASSET_MISSING, TOO_SOON, UNKNOWN_CUE }

## {StringName: {"path": String, "min_interval_ms": int, "bus": StringName}}
var _table: Dictionary
## Callable() -> int(毫秒)
var _clock: Callable
## Callable(path: String) -> bool
var _asset_exists: Callable
var _last_play_ms: Dictionary = {}
## 已知缺席的路徑快取。
var _missing_paths: Dictionary = {}


func _init(table: Dictionary, clock: Callable, asset_exists: Callable) -> void:
	_table = table
	_clock = clock
	_asset_exists = asset_exists


func decide(cue_id: StringName, muted: bool) -> Decision:
	if not _table.has(cue_id):
		return Decision.UNKNOWN_CUE
	if _blocks_for_mute(muted):
		return Decision.MUTED
	var entry: Dictionary = _table[cue_id]
	if not _asset_present(String(entry["path"])):
		return Decision.ASSET_MISSING
	var now_ms: int = int(_clock.call())
	if _blocks_for_interval(cue_id, now_ms, int(entry["min_interval_ms"])):
		return Decision.TOO_SOON
	_last_play_ms[cue_id] = now_ms
	return Decision.PLAY


func bus_of(cue_id: StringName) -> StringName:
	if not _table.has(cue_id):
		return &""
	return StringName(_table[cue_id]["bus"])


func path_of(cue_id: StringName) -> String:
	if not _table.has(cue_id):
		return ""
	return String(_table[cue_id]["path"])


## 受保護的判斷點(敏感度證明的 mutant 覆寫這兩個)。
func _blocks_for_mute(muted: bool) -> bool:
	return muted


func _blocks_for_interval(cue_id: StringName, now_ms: int, min_interval_ms: int) -> bool:
	if not _last_play_ms.has(cue_id):
		return false
	return now_ms - int(_last_play_ms[cue_id]) < min_interval_ms


func _asset_present(path: String) -> bool:
	if _missing_paths.has(path):
		return false
	var exists: bool = bool(_asset_exists.call(path))
	if not exists:
		_missing_paths[path] = true
	return exists
