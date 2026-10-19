## CampaignAffinityLedger —— 戰役層「到目前為止累積的好感度變化」純資料持有者。
##
## 實作依據:
## production/epics/support-conversation/story-003-cross-mission-affinity-continuity.md
## AC1(持有累積記錄,純資料、零節點)、AC4(打輸整關回滾,連累積記錄一起回滾)。
## 本輪範圍依協調者 2026-10-19 課正縮減——本檔只交付這個獨立類別本身,不接線
## (誰持有這個實例、何時 new()、何時呼叫 begin_mission()/rollback_current_mission()
## 皆不在本輪範圍,battle_screen.gd 本輪零改動)。
##
## 🔴 刻意不做成 static —— `.claude/rules/gameplay-code.md` 2026-10-19 裁決④
## 明文:本專案目前已有兩個登記在案的靜態狀態持有者例外([code]GameSettings[/code]/
## [code]CampaignProgress[/code]),「是例外不是放寬……再要第三個,請重新裁決,
## 不要援引本條」。本類別因此設計成一般可 [method RefCounted.new] 的類別,
## 不持有任何 static 欄位。
##
## 純資料、零節點、不碰 [FileAccess]——序列化(跨啟動持久化)不在本輪範圍,
## 存檔系統 ADR-0004 仍 [code]Proposed[/code]。
##
## 回滾機制(AC4):[method begin_mission] 記錄呼叫當下的筆數,作為「這一場開打前」
## 的基準點;[method rollback_current_mission] 把清單截回那個基準點,等同丟棄
## 「這一場新增的全部記錄」,不影響基準點之前(前幾場)累積的任何記錄。
##
## 🔴 [method begin_mission] 必須在每場戰鬥開局時呼叫恰好一次——忘了呼叫的後果是
## [method rollback_current_mission] 的截斷基準點停在上一次呼叫當下的值,等同
## 連同更早的場次一起回滾(過度回滾),而不是「這一場什麼都不做」那種容易被發現
## 的錯法。本類別本身無法偵測「忘了呼叫」這件事——這是接線端(下一輪)的責任。
class_name CampaignAffinityLedger
extends RefCounted


## 一筆累積的好感度變化——(pair, m, source) 三元組。
##
## 🔴 刻意不重用 [AffinityRecord]——後者的 [member AffinityRecord.t] /
## [member AffinityRecord.c] 兩個欄位是 [AffinityDataPool] 內部寫入計數器/戰役
## 刻度計數器的值,由該池的 [method AffinityDataPool.append_record] 在寫入當下
## 指派;本類別管理的是「尚未寫入任何特定池」的待重播記錄,套用 t/c 兩個欄位沒有
## 意義,也會讓呼叫端誤以為這裡的 t/c 是有意義的歷史值。
class Entry extends RefCounted:
	var pair: AffinityTypes.Pair
	var m: float
	var source: AffinityTypes.Source

	func _init(p: AffinityTypes.Pair, amount: float, src: AffinityTypes.Source) -> void:
		pair = p
		m = amount
		source = src


## 累積記錄本體,append-only——唯一的例外是 [method rollback_current_mission]
## 的截斷。
var _entries: Array[Entry] = []

## [method begin_mission] 記下的基準點——[member _entries] 在那次呼叫當下的筆數。
## [method rollback_current_mission] 截斷到這個值。預設 [code]0[/code]:建構後、
## 第一次呼叫 [method begin_mission] 之前就呼叫 [method rollback_current_mission]
## 是合法的呼叫序(結構上等同「這一場從空清單開始」),不中止、不報錯。
var _mission_start_count: int = 0


## 附加一筆記錄。[param pair]/[param m]/[param source] 不在本類別內做任何合法性
## 檢查——那是 [method AffinityDataPool.append_record] 的職責(真正寫入某個戰鬥的
## 池時);本類別只負責持有,不重複驗證,也不假設呼叫端一定會把它寫進任何池。
func append(pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source) -> void:
	_entries.append(Entry.new(pair, m, source))


## 回傳目前累積的全部記錄,依附加順序。回傳值是內部陣列的淺層複本
## ([method Array.duplicate])——呼叫端對回傳陣列本身的增刪不會影響本類別的內部
## 狀態,但陣列內的 [Entry] 物件是共享參照(本類別不提供修改單筆記錄的介面,
## 因此這不構成可觀測的風險)。
func records() -> Array[Entry]:
	return _entries.duplicate()


## 清空全部記錄——回到「戰役尚未開始」的狀態,連 [method begin_mission] 的基準點
## 一併歸零。目前沒有生產呼叫端使用本方法(本輪只有 AC1 要求提供這個能力);保留
## 它是因為「清空累積記錄」本身是合法的未來生產需求(例如新戰役開局),不是測試
## 專用的 [code]reset_for_test()[/code] 替代品——本類別非 static,測試可以直接
## [method RefCounted.new] 一份乾淨實例,不需要依賴本方法做隔離。
func clear() -> void:
	_entries.clear()
	_mission_start_count = 0


## AC4——標記「這一場開打了」。記下呼叫當下 [member _entries] 的筆數,作為
## [method rollback_current_mission] 的截斷基準點。🔴 必須在每場戰鬥開局時呼叫
## 恰好一次——見本類別文件註解「忘了呼叫的後果」。
func begin_mission() -> void:
	_mission_start_count = _entries.size()


## AC4——打輸整關回滾:把 [member _entries] 截斷回最近一次 [method begin_mission]
## 呼叫當下的筆數,等同丟棄「這一場新增的全部記錄」,不影響基準點之前累積的任何
## 記錄。對基準點之前的記錄無副作用;可重複呼叫(冪等)——若這一場本來就沒有新增
## 任何記錄,截斷後筆數不變。
##
## 🔴 刻意逐一 [method Array.pop_back] 而非呼叫 [method Array.resize]——本專案
## 尚未在既有測試裡驗證型別化 [Array] 的 [method Array.resize] 在本專案釘死的
## Godot 4.7.1(訓練資料截止後版本,見 [code]docs/engine-reference/godot/VERSION.md[/code])
## 下對「縮小」以外的語意是否與未型別化陣列一致;[method Array.pop_back] 是本專案
## 其餘程式碼已經在用的既有操作([AffinityRecordList] 等),風險更低。由於
## [member _mission_start_count] 恆小於等於呼叫當下的 [member _entries] 筆數
## (它只會被設成某個過去時刻的快照,期間 [member _entries] 只增不減,直到下一次
## 本方法被呼叫),這個迴圈只會縮小陣列,不會意外觸發增長語意。
func rollback_current_mission() -> void:
	while _entries.size() > _mission_start_count:
		_entries.pop_back()
