class_name ControlsHintContent
extends RefCounted
## story-045:戰鬥畫面底部提示列的內容 —— 依【狀態】與【裝置】只顯示相關按鍵(單一出處)。
##
## 文案、鍵名、段落順序以 ux-designer 定稿為準:
## [code]docs/reviews/story-045-hint-copy-final-2026-11-13.md[/code](第 1 節表 + 第 7 節 FINISHED 重判)。
## 每格是「由左到右的段落陣列,同時就是保留優先序」:寬度不夠時由 [method fit_text]
## 從【右端】逐段丟棄(第 3 節),不是固定取前 N 段。
##
## 純函式、不持有狀態、不讀任何遊戲狀態。把 [BattleController] 的狀態映射成
## [enum HintState] 的那一處寫在 [code]BattleScreen._current_hint_state()[/code]。

enum HintState {
	NO_SELECTION,
	UNIT_SELECTED,
	HAND_OPEN,
	CARD_TARGET,
	CARD_CONFIRM,
	FORCED_DISCARD,
	MENU_OPEN,
	ENEMY_PHASE,
	FINISHED,
}

enum HintDevice { MOUSE, KEYBOARD, GAMEPAD }

## 段落 key 前綴;完整 key = 前綴 + 段落名 + "." + 裝置後綴。
const KEY_PREFIX: String = "battle.hud.hint."
## 與裝置無關的狀態句。
const SEG_PICK_TARGET: String = "status.pick_target"
const SEG_ENEMY_PHASE: String = "status.enemy_phase"
const SEPARATOR: String = "\u3000"

const _DEVICE_SUFFIX: Dictionary[int, String] = {
	HintDevice.MOUSE: "mouse",
	HintDevice.KEYBOARD: "keyboard",
	HintDevice.GAMEPAD: "gamepad",
}


## 各狀態、各裝置的段落名清單(順序即保留優先序,左 = 最後才丟)。
## 鍵盤與手把同序;滑鼠獨立一欄。FINISHED 為空(定稿第 7 節:結果畫面沒有任何可按的鍵)。
static func _segment_names(state: HintState, device: HintDevice) -> Array[String]:
	var mouse: bool = device == HintDevice.MOUSE
	var names: Array = []
	match state:
		HintState.NO_SELECTION:
			names = ["move", "select"] if mouse else ["move", "select", "hand", "menu"]
		HintState.UNIT_SELECTED:
			names = ["move", "confirm", "cancel"] if mouse else ["move", "confirm", "cancel", "end_unit", "jump_target", "hand", "menu"]
		HintState.HAND_OPEN:
			names = ["card_use", "cancel"] if mouse else ["card_pick", "card_use", "cancel", "hand_close"]
		HintState.CARD_TARGET:
			names = [SEG_PICK_TARGET, "target_confirm", "cancel"] if mouse else [SEG_PICK_TARGET, "cancel", "target_confirm", "move", "jump_target"]
		HintState.CARD_CONFIRM:
			names = ["confirm", "cancel"]
		HintState.FORCED_DISCARD:
			names = ["discard"] if mouse else ["card_pick", "discard"]
		HintState.MENU_OPEN:
			names = ["menu_pick", "confirm", "menu_close"]
		HintState.ENEMY_PHASE:
			names = [SEG_ENEMY_PHASE] if mouse else [SEG_ENEMY_PHASE, "menu"]
		HintState.FINISHED:
			names = []
		_:
			push_error("ControlsHintContent: unknown HintState %d" % int(state))
	var typed: Array[String] = []
	typed.assign(names)
	return typed


## 在地化後的片段陣列。FINISHED 回傳空陣列;其餘各格皆非空。
static func segments_for(state: HintState, device: HintDevice) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for seg: String in _segment_names(state, device):
		var key: String = KEY_PREFIX + seg
		if not seg.begins_with("status."):
			key += "." + _DEVICE_SUFFIX[device]
		out.append(Loc.localize(StringName(key)))
	return out


## 把 [param segments] 以全形空白連成單行;放不下 [param max_width] 時從右端逐段丟棄,
## 至少保留第一段。用真實 HUD 字型量寬。
static func fit_text(segments: PackedStringArray, max_width: float, font: Font, font_size: int) -> String:
	var count: int = segments.size()
	while count > 1:
		var text: String = SEPARATOR.join(segments.slice(0, count))
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			return text
		count -= 1
	return SEPARATOR.join(segments.slice(0, count))
