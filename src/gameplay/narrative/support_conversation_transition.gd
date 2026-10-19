## 轉場時觸發支援對話的唯一入口 —— production/epics/game-shell/
## story-003-campaign-flow-and-transition-slots.md AC5/AC6。
##
## 🔴 放在 [code]src/gameplay/narrative/[/code] 目錄內是刻意的(AC5 的二選一,
## 協調者 2026-10-19 裁決選①):支援對話系統 story-001 的
## [code]tests/unit/gameplay/narrative/support_conversation_write_call_site_count_test.gd[/code]
## 掃描範圍只涵蓋這個目錄,要求 [method SupportConversationWritePort.append_record]
## 在此目錄內恰好被呼叫 1 處。本檔只呼叫 [method SupportConversationRules.trigger]
## (不直接呼叫 [code].append_record([/code]),所以那條既有測試的計數完全不受
## 本檔影響,不需要改它。
##
## 本函式只做一件事:在「剛打完第 [param slot] 場、即將進入下一場」這個轉場點,
## 從 [param records] 找出 [member SupportConversationRecord.trigger_after_mission]
## 等於 [param slot] 的記錄,逐一呼叫 [method SupportConversationRules.trigger]
## 判定並觸發。找不到任何符合的記錄時什麼都不做、回傳空陣列 —— 這是合法的設計
## 狀態(例如 5 場骨架的 4→5 槽位刻意空置),不是遺漏(本 story AC6)。
##
## 本輪範圍縮減(協調者 2026-10-19 裁決):本檔尚未被任何正式呼叫端接線 ——
## [code]src/ui/battle/battle_screen.gd[/code] 本輪不碰,接線留待下一輪
## (AC7/AC8)。
class_name SupportConversationTransition
extends RefCounted


## 見類別文件註解。[param is_alive]/[param port] 的形狀與
## [method SupportConversationRules.trigger] 完全相同,直接轉送,不做任何轉換。
static func trigger_for_mission_transition(
	slot: int,
	records: Array[SupportConversationRecord],
	is_alive: Callable,
	port: SupportConversationWritePort
) -> Array[SupportConversationRecord]:
	var triggered: Array[SupportConversationRecord] = []
	for record: SupportConversationRecord in records:
		if record.trigger_after_mission == slot:
			SupportConversationRules.trigger(record, is_alive, port)
			triggered.append(record)
	return triggered
