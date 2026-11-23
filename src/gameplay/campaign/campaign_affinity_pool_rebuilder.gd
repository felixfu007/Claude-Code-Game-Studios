## CampaignAffinityPoolRebuilder —— 「戰役累積記錄 -> 新好感度池」的唯一重播實作。
##
## 實作依據:production/epics/campfire/story-001-ledger-to-pool-rebuild-shared.md。
## 規格 4.3(寫入立即生效、下一場即反映)、4.4(先寫池再依寫入後的 v 產卡)、
## 登記表契約 affinity_relation_state_single_judgment(ONE JUDGMENT, ONE PLACE)。
##
## 原本這段重播只寫在 battle_screen.gd 的 _ready() 裡,營火畫面拿不到;若營火自己
## 再寫一份,就是本專案登記過的「兩份實作只是今天答案一致」形狀。故抽成純函式,
## 戰鬥畫面與營火共用。
##
## 全為 static func、零 static 欄位(不是 gameplay-code.md 的靜態狀態持有者):
## 輸入累積記錄、回傳新池,不持有任何東西。
##
## 範圍界線:第 1 場的開場灌入(seed_into_ledger)不在這裡 —— 那是戰鬥開局的事,
## 不是重播,仍留在 battle_screen.gd。
class_name CampaignAffinityPoolRebuilder
extends RefCounted


## 回傳一個新建的 [AffinityDataPool],依 [param ledger] 的附加順序逐筆灌入全部記錄。
## [param ledger] 為 null 或空 -> 回傳全空池(10 組皆 n_pair == 0)。
## 單筆被池拒絕時 [method @GlobalScope.push_error] 並繼續下一筆(不吞掉、不用
## assert():assert 失敗會讓回傳列舉序數 0 = 成功,見 coding-standards.md
## 2026-09-15 條目,且 release 匯出會整句移除)。
static func rebuild(ledger: CampaignAffinityLedger) -> AffinityDataPool:
	var pool: AffinityDataPool = AffinityDataPool.new()
	if ledger == null:
		return pool
	for entry: CampaignAffinityLedger.Entry in ledger.records():
		var rejection: AffinityDataPool.WriteRejection = pool.append_record(
			entry.pair, entry.m, entry.source
		)
		if rejection != AffinityDataPool.WriteRejection.NONE:
			push_error(
				(
					"CampaignAffinityPoolRebuilder.rebuild: campaign ledger replay record "
					+ "(pair ordinal %d) was REJECTED with WriteRejection code %d -- "
					+ "the rebuilt pool will NOT reflect this record."
				) % [entry.pair, rejection]
			)
	return pool
