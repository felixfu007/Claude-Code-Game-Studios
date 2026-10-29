## 教學序列進度持有者(game-shell story-008)。
##
## 教學是【獨立於戰役的序列】:本類別不碰 [CampaignProgress],因此教學全程
## [method CampaignProgress.current_mission] 與戰役好感度累積記錄不可能被改動(AC5)。
## 形狀比照 [CampaignProgress](static var + [method reset_for_test]),已知代價相同:
## 跨啟動不持久化、跨測試共用狀態 —— 任何啟動教學的測試收尾必須呼叫 [method reset_for_test]。
class_name TutorialProgress
extends RefCounted

const FIRST_INDEX: int = 1

enum AdvanceResult { ADVANCED, TUTORIAL_COMPLETE }

static var _active: bool = false
static var _current: int = FIRST_INDEX


## 目前是否在教學序列中。
static func is_active() -> bool:
	return _active


## 教學第幾場(1 起算)。
static func current_index() -> int:
	return _current


## 從第 1 場開始教學(標題「開始」)。
static func begin() -> void:
	_active = true
	_current = FIRST_INDEX


## 結束教學(標題「略過教學」/ 進入戰役時)。
static func end() -> void:
	_active = false
	_current = FIRST_INDEX


## 教學場勝利:前進下一場;已是最後一場([param total] 由資料驅動)回傳
## [constant AdvanceResult.TUTORIAL_COMPLETE] 且不前進(是否結束教學由呼叫端決定)。
static func advance_on_victory(total: int) -> AdvanceResult:
	if _current >= total:
		return AdvanceResult.TUTORIAL_COMPLETE
	_current += 1
	return AdvanceResult.ADVANCED


## 測試專用重設。
static func reset_for_test() -> void:
	end()
