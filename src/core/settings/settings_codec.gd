## 設定 ⇄ 文字 的純編解碼(audio-foundation story-001)。不碰檔案、不碰 [GameSettings]。
##
## 格式:[ConfigFile] 文字(`encode_to_text` / `parse`,2026-11-06 探針確認:
## `prototypes/audio-story001-probes-2026-11-06/run_output_api.txt`)。
## 一律區段 [code]settings[/code]。
##
## [b]壞資料策略[/b]:逐鍵獨立 —— 缺鍵、型別不符、非有限數、超出 [0,1] 的音量,
## 只讓【那一鍵】回傳預設,其他鍵保留。本檔自己不 push_error。
## ⚠️ 已知:亂碼文字會讓引擎自己的 [code]ConfigFile.parse[/code] 在 stderr 印一行
## ERROR(引擎內部,非本檔 push_error;回傳碼 43,不崩潰,全部回預設)。
class_name SettingsCodec
extends RefCounted

const SECTION: String = "settings"
const KEY_EGM: String = "egm_enabled"
const KEY_HIDE_AFFINITY: String = "hide_affinity_display"
const KEY_MASTER: String = "master_volume"
const KEY_MUSIC: String = "music_volume"
const KEY_SFX: String = "sfx_volume"
const KEY_MUTED: String = "muted"

const BOOL_KEYS: Array[String] = [KEY_EGM, KEY_HIDE_AFFINITY, KEY_MUTED]
const VOLUME_KEYS: Array[String] = [KEY_MASTER, KEY_MUSIC, KEY_SFX]


## 把六項設定([param values],鍵為上方 KEY_*)編成文字。
static func encode(values: Dictionary) -> String:
	var cf: ConfigFile = ConfigFile.new()
	for key: String in BOOL_KEYS:
		cf.set_value(SECTION, key, bool(values.get(key, false)))
	for key: String in VOLUME_KEYS:
		cf.set_value(SECTION, key, float(values.get(key, 0.0)))
	return cf.encode_to_text()


## 把文字解成六項設定;[param defaults] 提供每一鍵的回退值(需含六鍵)。
## 任何壞資料皆回預設,不崩潰。
static func decode(text: String, defaults: Dictionary) -> Dictionary:
	var result: Dictionary = defaults.duplicate()
	if text.strip_edges().is_empty():
		return result
	var cf: ConfigFile = ConfigFile.new()
	if cf.parse(text) != OK:
		return result
	for key: String in BOOL_KEYS:
		var raw: Variant = cf.get_value(SECTION, key, null)
		if typeof(raw) == TYPE_BOOL:
			result[key] = raw
	for key: String in VOLUME_KEYS:
		var raw: Variant = cf.get_value(SECTION, key, null)
		var t: int = typeof(raw)
		if t == TYPE_FLOAT or t == TYPE_INT:
			var f: float = float(raw)
			if is_finite(f) and f >= 0.0 and f <= 1.0:
				result[key] = f
	return result
