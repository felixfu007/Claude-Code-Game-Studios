class_name SupportConversationLedgerWritePort
extends SupportConversationWritePort
## 支援對話寫入介面的「戰役累積記錄」側轉接器。
##
## 實作 game-shell story-005 AC4(支援對話寫入真的進入下一場)。
##
## 為什麼有兩個轉接器:
## - SupportConversationPoolWritePort 寫進「這場戰鬥的好感度池」,但池子每場戰鬥都重建,
##   寫進去的東西下一場就沒了。
## - 跨關延續的載體是戰役層的 CampaignAffinityLedger;下一場開局時由 BattleScreen
##   把 ledger.records() 逐筆灌回新池子。本轉接器把支援對話的寫入送進 ledger。
##
## 分工與已知代價:
## 本轉接器【不做任何數值驗證或過濾】,ledger 只是記帳。真正的合法性檢查發生在
## 下一場開局灌回池子時(池子的 append_record 會回報拒絕)。
## 因此非法寫入要到下一場開局才會被發現 —— 這是已知代價,不是疏漏。
##
## 範圍聲明:「關掉遊戲再開,累積記錄歸零」是明文範圍
## (存檔系統不在 12 個月範圍內),本轉接器不負責持久化。

var _ledger: CampaignAffinityLedger


func _init(ledger: CampaignAffinityLedger) -> void:
	_ledger = ledger


## 把一筆寫入轉送給 ledger。ledger 為 null 時 push_error 並不寫
## (不用 assert:assert 失敗在回傳 enum 的函式會回 ordinal 0,此處雖回 void 仍遵守專案規範)。
func append_record(pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source) -> void:
	if _ledger == null:
		push_error("SupportConversationLedgerWritePort: ledger is null, record not written")
		return
	_ledger.append(pair, m, source)
