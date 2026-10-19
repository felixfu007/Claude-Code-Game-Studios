## 戰役進度持有者 —— production/epics/game-shell/
## story-003-campaign-flow-and-transition-slots.md「開工前查核三」甲案。
##
## [b]形狀直接比照 [code]src/core/settings/game_settings.gd[/code][/b]
## (static var + reset_for_test(),同一天稍早由 story-002 落地並通過驗收)——
## 本檔不重新推導「為什麼不是 Autoload」,理由與該檔完全相同:
## 1. 新增 Autoload 需同步修改既有文件
##    [code].claude/docs/technical-preferences.md[/code] 的 Autoload 表,
##    依 2026-10-12 管理者裁決,改動既有文件須先問管理者。
## 2. 存檔系統(第三條路)已明確不在 12 個月範圍內(ADR-0004 仍 Proposed)。
## 3. 本類別只有一個整數欄位,沒有初始化順序或跨單例依賴需求。
##
## [b]已知代價(與 GameSettings 相同的兩項,裁決接受,寫成 doc comment 不是
## 讓下一個人以為它壞了)[/b]:
## 1. 跨啟動不持久化 —— 重啟遊戲回到 [constant FIRST_MISSION_INDEX]。
## 2. 跨測試共用狀態 —— 任何呼叫 [method advance_on_victory] 的測試都必須在收尾
##    呼叫 [method reset_for_test],否則會污染同一次 headless 執行期間依賴預設值
##    的其他測試。
##
## [b]本輪範圍縮減(協調者 2026-10-19 裁決)[/b]:本檔只做「目前第幾場」的純狀態
## 追蹤,[b]不接 [code]src/ui/battle/battle_screen.gd[/code][/b] —— AC7(戰鬥結束
## 後真的切到下一場)、AC8(來回切換迴歸鎖)本輪不做,誠實登記於任務報告,不是
## 遺漏。
##
## ⚠️ [b]已知規則張力,誠實登記[/b]:[code].claude/rules/gameplay-code.md[/code]
## 明文「No static singletons for game state — use dependency injection」。本檔
## 與 [code]game_settings.gd[/code] 一樣是 static var,嚴格而言與該條文字相牴觸——
## 但本次做法由協調者直接裁決指定(逐字「這個選擇由我負責,不必再評估」),
## 且與今天稍早已驗收的 story-002 同一形狀。本處只誠實記錄這個張力存在,供
## [code]lead-programmer[/code] 日後評估是否需要修訂該條規則或登記專案級例外,
## 不在本檔自行裁決。
class_name CampaignProgress
extends RefCounted

## 全新戰役的起始場次。
const FIRST_MISSION_INDEX: int = 1

## AC3「終態必須是明確的狀態,不是靜默停住」—— [method advance_on_victory] 的
## 回傳型別,讓呼叫端用型別分辨「前進到下一場」與「已到達戰役完成終態」,
## 不必自行比較內部計數器與場次總數。
enum AdvanceResult { ADVANCED, CAMPAIGN_COMPLETE }

static var _current_mission: int = FIRST_MISSION_INDEX


## 目前第幾場(1 起算)。
static func current_mission() -> int:
	return _current_mission


## AC3(勝利推進)—— 前進到下一場。[param total_missions] 由呼叫端提供
## (資料驅動,AC2;本類別不內嵌任何寫死的關卡總數),若目前已是最後一場
## ([member _current_mission] >= [param total_missions]),不前進,回傳
## [constant AdvanceResult.CAMPAIGN_COMPLETE];否則前進一場並回傳
## [constant AdvanceResult.ADVANCED]。
static func advance_on_victory(total_missions: int) -> AdvanceResult:
	if _current_mission >= total_missions:
		return AdvanceResult.CAMPAIGN_COMPLETE
	_current_mission += 1
	return AdvanceResult.ADVANCED


## AC4(失敗回滾)—— 場次編號不前進。本函式刻意存在(而非讓呼叫端什麼都不做),
## 理由是語意對稱:讀程式碼的人看得出「這裡是故意什麼都不做」,而不是漏寫了
## 應有的回滾邏輯。
static func rollback_on_defeat() -> void:
	pass


## 測試專用:將本類別的靜態狀態重置回預設值。任何呼叫 [method advance_on_victory]
## 的測試都必須在收尾呼叫本方法,比照 [code]GameSettings.reset_for_test[/code]
## 的既有紀律。
static func reset_for_test() -> void:
	_current_mission = FIRST_MISSION_INDEX
