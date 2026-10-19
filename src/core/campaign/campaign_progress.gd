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
## 🔴 [b]第三輪接線(2026-10-19,production/epics/support-conversation/
## story-003-cross-mission-affinity-continuity.md「下一輪接線」)[/b]:本檔掛載
## [CampaignAffinityLedger] 靜態持有 —— 持有者選「甲」:既有的戰役層靜態持有者
## 多帶一份資料,不是開第三個靜態狀態持有者(2026-10-19 裁決④的例外名單維持
## [code]GameSettings[/code]/[code]CampaignProgress[/code] 兩項不變,「再要第三個,
## 請重新裁決」)。
##
## 🔴 [b]結構防線(上一輪實作者主動揭露的陷阱的答案)[/b]:上一輪的
## [code]campaign_affinity_ledger.gd[/code] 文件註解明文警告「[method
## CampaignAffinityLedger.begin_mission] 忘了呼叫,本類別結構上偵測不到」。
## [method start_mission_affinity_ledger] 是本類別對外公開、唯一能取得
## [CampaignAffinityLedger] 參照的入口,且內部必定先呼叫
## [method CampaignAffinityLedger.begin_mission] 才回傳——呼叫端沒有任何管道能
## 拿到一個「沒 begin 過」的 ledger,這個陷阱因此在本層被結構性排除,不依賴
## 呼叫端自律。[method rollback_on_defeat] 同理直接操作
## [member _affinity_ledger],不對外暴露另一條能繞過 [method start_mission_affinity_ledger]
## 的存取路徑。
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

## 戰役層「到目前為止累積的好感度變化」——見本類別文件註解「第三輪接線」段。
## 腳本載入時就建構好一個空的 [CampaignAffinityLedger] 實例,終生只有這一個,
## 不會被重新指派([method reset_for_test] 呼叫的是它的
## [method CampaignAffinityLedger.clear],不是把這個變數換一個新實例)。
static var _affinity_ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()


## 目前第幾場(1 起算)。
static func current_mission() -> int:
	return _current_mission


## 取得「這一場要注入 [member BattleScreen.campaign_ledger_override] 的累積記錄
## ledger」的唯一入口。🔴 內部必定先呼叫
## [method CampaignAffinityLedger.begin_mission] 才回傳——見本類別文件註解
## 「結構防線」段。呼叫端(未來的戰役流程控制器,或測試)每次要開始/重新開始
## 一場戰鬥時都呼叫本方法取得要注入的 ledger,不得自行持有另一條取得
## [CampaignAffinityLedger] 參照的管道。
static func start_mission_affinity_ledger() -> CampaignAffinityLedger:
	_affinity_ledger.begin_mission()
	return _affinity_ledger


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


## AC4(失敗回滾)—— 場次編號不前進,且本場透過 [method start_mission_affinity_ledger]
## 取得並寫入的戰役層累積記錄一併丟棄([method CampaignAffinityLedger.rollback_current_mission])。
##
## 🔴 第三輪前本函式只有 [code]pass[/code](場次編號本來就靠「不呼叫
## [method advance_on_victory]」維持不前進,不需要額外動作);語意對稱的理由
## 不變——讀程式碼的人看得出「場次編號部分是故意什麼都不做」,而不是漏寫了
## 應有的回滾邏輯。第三輪多做的是把累積記錄的回滾也收進同一個呼叫點,
## 因為兩者是「失敗時不留下這一場的痕跡」同一個語意的兩個部分。
static func rollback_on_defeat() -> void:
	_affinity_ledger.rollback_current_mission()


## 測試專用:將本類別的靜態狀態重置回預設值,[member _affinity_ledger] 也一併
## 清空(含它自己的 mission 基準點)。任何呼叫 [method advance_on_victory] /
## [method start_mission_affinity_ledger] / [method rollback_on_defeat] 的測試
## 都必須在收尾呼叫本方法,比照 [code]GameSettings.reset_for_test[/code] 的
## 既有紀律。
static func reset_for_test() -> void:
	_current_mission = FIRST_MISSION_INDEX
	_affinity_ledger.clear()
