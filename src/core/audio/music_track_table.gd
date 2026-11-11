## 音樂曲目表解析(audio-foundation story-004,AC-5)。
##
## 純函式:吃文字、回傳結果 Dictionary,不讀檔(讀檔留在宿主組裝點)、
## 不 push_error / push_warning(壞列以回傳值回報)。
## 資料檔為 .txt(不可用 .csv,Godot 會當翻譯檔匯入,見 coding-standards.md)。
class_name MusicTrackTable
extends RefCounted

const TABLE_PATH: String = "res://assets/data/audio/music_tracks.txt"

const KEY_TITLE: StringName = &"title"
const KEY_BATTLE: StringName = &"battle"
## 對話場景預設靜音:表內沒有此 key 的列即靜音。
const KEY_DIALOGUE: StringName = &"dialogue"

const COLUMN_COUNT: int = 4


## 解析表文字。回傳 {"tracks": {StringName: {"path": String, "fade_in_ms": int, "fade_out_ms": int,
## "pool": Array[Dictionary]}}, "errors": Array[String]}。壞列(欄數不對、空欄位、非數值/負數淡化
## 時間、同一 scene_key 下重複的 path)被略過並記入 errors。
##
## 曲目池(2026-11-11 管理者裁決「戰鬥BGM可以三四首隨機撥放」):同一 scene_key 可以有多列,
## 每列一首。第一列是 [code]tracks[key][/code] 的主欄位(path/fade_in_ms/fade_out_ms),全部列
## (含第一列)依出現順序收進 [code]tracks[key]["pool"][/code]。只有一列時 pool 只有它自己。
## 由宿主 [method MusicPlayerHost._apply_scene] 在每次進入場景時從 pool 挑一首。
## 🔴 同 key 同 path 仍是錯誤(重複列,多半是手誤),不會進 pool。
static func parse(text: String) -> Dictionary:
	var tracks: Dictionary = {}
	var errors: Array[String] = []
	var line_no: int = 0
	for raw_line: String in text.split("\n"):
		line_no += 1
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var cols: PackedStringArray = line.split(",")
		if cols.size() > 0 and cols[0].strip_edges() == "scene_key":
			continue # 標題列
		if cols.size() != COLUMN_COUNT:
			errors.append("line %d: expected %d columns, got %d" % [line_no, COLUMN_COUNT, cols.size()])
			continue
		var key: String = cols[0].strip_edges()
		var path: String = cols[1].strip_edges()
		var fade_in: String = cols[2].strip_edges()
		var fade_out: String = cols[3].strip_edges()
		if key.is_empty() or path.is_empty():
			errors.append("line %d: empty field" % line_no)
			continue
		if not fade_in.is_valid_int() or fade_in.to_int() < 0 \
				or not fade_out.is_valid_int() or fade_out.to_int() < 0:
			errors.append("line %d: fade time not a non-negative integer" % line_no)
			continue
		var row: Dictionary = {
			"path": path,
			"fade_in_ms": fade_in.to_int(),
			"fade_out_ms": fade_out.to_int(),
		}
		var skey: StringName = StringName(key)
		if tracks.has(skey):
			var pool: Array = tracks[skey]["pool"]
			var already: bool = false
			for existing: Dictionary in pool:
				if String(existing["path"]) == path:
					already = true
					break
			if already:
				errors.append("line %d: duplicate path '%s' for scene_key '%s'" % [line_no, path, key])
				continue
			pool.append(row)
			continue
		var first: Dictionary = row.duplicate()
		first["pool"] = [row]
		tracks[skey] = first
	return {"tracks": tracks, "errors": errors}


## 場景檔路徑 → 曲目表 scene_key。設定畫面沿用標題曲(標題 → 設定不斷樂);
## 其餘未知路徑回傳空 StringName(= 沒有曲目)。
static func scene_key_for_path(scene_path: String) -> StringName:
	match scene_path:
		SceneRouter.TITLE_SCENE_PATH, SceneRouter.SETTINGS_SCENE_PATH:
			return KEY_TITLE
		SceneRouter.BATTLE_SCENE_PATH:
			return KEY_BATTLE
		SceneRouter.SUPPORT_CONVERSATION_SCENE_PATH:
			return KEY_DIALOGUE
	return &""
