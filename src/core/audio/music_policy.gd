## 音樂切換決策核心(audio-foundation story-004,純、全 static)。
##
## 輸入 (前一首曲目路徑, 新場景曲目路徑, 素材是否存在, 是否靜音) → [enum Action]。
## 空字串路徑代表「沒有曲目」。🔴 本檔刻意不呼叫 push_error / push_warning:素材缺席必須安靜。
##
## 規則(依序):
## 1. 靜音、新場景沒有曲目、或素材缺席 → 視為「無可播曲目」:前一首在播則 FADE_OUT,否則 SILENT。
##    這幾種情況【都不會】產生播放請求(AC-3 / AC-4)。
## 2. 新曲目與前一首相同 → KEEP(同曲跨場景不重啟,AC-1)。
## 3. 前一首為空 → FADE_IN;否則 SWITCH(淡出舊曲後淡入新曲,AC-2)。
##
## 範例:[code]MusicPolicy.decide("res://a.ogg", "res://b.ogg", true, false) == MusicPolicy.Action.SWITCH[/code]
class_name MusicPolicy
extends RefCounted

enum Action { KEEP, FADE_IN, SWITCH, FADE_OUT, SILENT }


static func decide(prev_track: String, new_track: String, asset_exists: bool, muted: bool) -> Action:
	var playable: String = new_track
	if muted or new_track.is_empty() or not asset_exists:
		playable = ""
	if playable.is_empty():
		return Action.FADE_OUT if not prev_track.is_empty() else Action.SILENT
	if playable == prev_track:
		return Action.KEEP
	if prev_track.is_empty():
		return Action.FADE_IN
	return Action.SWITCH


## 這個動作是否需要向播放器送出「播放新曲」的請求。
static func requests_playback(action: Action) -> bool:
	return action == Action.FADE_IN or action == Action.SWITCH
