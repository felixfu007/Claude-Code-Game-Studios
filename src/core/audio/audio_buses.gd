## AudioBus 結構與音量套用(audio-foundation story-001)。
##
## [b]Bus 建立方式:執行期 [code]AudioServer.add_bus[/code](不用 default_bus_layout.tres)[/b]。
## 理由:①不新增專案根檔案、不動 project.godot;②探針
## [code]prototypes/audio-story001-probes-2026-11-06/run_output_api.txt[/code] 確認
## headless 下 add_bus / set_bus_name / set_bus_send / get_bus_index 皆可正常讀回;
## ③[method ensure_buses] 以名稱查詢達成冪等。
##
## 🔴 headless 下音訊輸出是 no-op:本檔只有「決策」(純函式)可被自動驗證。
class_name AudioBuses
extends RefCounted

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"

## 三條子 bus,皆送往 Master。
const CHILD_BUSES: Array[StringName] = [BUS_MUSIC, BUS_SFX, BUS_UI]

## 線性 0 的靜音等價 dB(有限值,避免 -inf)。與 [code]linear_to_db(0.0001)[/code] 一致。
const SILENT_DB: float = -80.0
const SILENT_THRESHOLD: float = 0.0001


## 線性 0~1 → dB。輸入先夾制到 [0,1];≤ 門檻一律回 [constant SILENT_DB]。
## 1.0 → 0 dB;單調不減;絕不回 NaN/inf。
static func volume_to_db(linear: float) -> float:
	if is_nan(linear):
		return SILENT_DB
	var v: float = clampf(linear, 0.0, 1.0)
	if v <= SILENT_THRESHOLD:
		return SILENT_DB
	return linear_to_db(v)


## 純決策:各 bus 應套用的狀態。回傳 [code]{bus_name: {"db": float, "mute": bool}}[/code]。
## 靜音只影響各 bus 的 mute 旗標,不改寫三個音量值。UI bus 跟隨音效音量。
static func compute_bus_state(master: float, music: float, sfx: float, muted: bool) -> Dictionary:
	return {
		BUS_MASTER: {"db": volume_to_db(master), "mute": muted},
		BUS_MUSIC: {"db": volume_to_db(music), "mute": muted},
		BUS_SFX: {"db": volume_to_db(sfx), "mute": muted},
		BUS_UI: {"db": volume_to_db(sfx), "mute": muted},
	}


## 冪等建立三條子 bus(已存在者不重複加),送往 Master。
static func ensure_buses() -> void:
	for bus_name: StringName in CHILD_BUSES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, BUS_MASTER)


## 薄的套用入口:確保 bus 存在,再把 [method compute_bus_state] 寫進 AudioServer。
static func apply_settings(master: float, music: float, sfx: float, muted: bool) -> void:
	ensure_buses()
	var state: Dictionary = compute_bus_state(master, music, sfx, muted)
	for bus_name: StringName in state:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			continue
		var entry: Dictionary = state[bus_name]
		AudioServer.set_bus_volume_db(idx, float(entry["db"]))
		AudioServer.set_bus_mute(idx, bool(entry["mute"]))
