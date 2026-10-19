## 支援對話系統(系統 #8)專用的好感度池寫入介面 —— 依賴注入,呼叫端決定實際寫到
## 哪裡。本 story 範圍明文:不接任何真實好感度池(見 EPIC.md「開工前查核一、二」,
## 兩個結構缺口尚待管理者裁決)。測試以一個記錄呼叫的假寫入埠驗證「有沒有寫、
## 寫了幾次、寫了什麼」。
##
## 🔴 [b]刻意不是 src/gameplay/cards/affinity_write_port.gd 的 AffinityWritePort。[/b]
## 那個介面的簽章([code]character_a: int, character_b: int, m: int,
## source: StringName[/code])是 2026-09-10 當時 [code]AffinityTypes[/code] 尚未
## 實作時的權宜設計(見該檔自己的文件註解:「building AffinityTypes here would mean
## this story quietly implementing a piece of #1's own ADR」)。今天
## [AffinityTypes]([code]src/gameplay/affinity_pool/affinity_types.gd[/code])已是
## ADR-0002 Accepted 之後的完整實作,而真實池
## [AffinityDataPool.append_record] 的簽章就是
## [code](pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source)[/code]
## —— 本介面直接比照真實池的簽章,不是另外發明第三種形狀:未來(story-002)接上
## 真池時,轉接層只需「原封不動轉送」,不必再做一次型別搬運。
##
## 使用 [enum AffinityTypes.Character]/[enum AffinityTypes.Pair] 而非自創一套新的
## 角色列舉,也是這個理由的延伸 —— 呼叫端([method SupportConversationRules.trigger])
## 透過既有的 [AffinityRosterCharacterMapper] 把資料表的名冊 id 轉成
## [enum AffinityTypes.Character] 後,再用 [method AffinityTypes.pair_of] 組成
## [enum AffinityTypes.Pair],本介面只接收組好的 [enum AffinityTypes.Pair]。
##
## 本 story 之所以仍要新定義一個介面、而不是直接讓呼叫端持有
## [AffinityDataPool] 本身 —— 依賴注入:測試可以替換成假寫入埠,不需要真的
## [code]AffinityDataPool.new()[/code]。
##
## 裸簽章抽象方法 —— 不帶主體(含 [code]pass[/code])。帶主體在本引擎版本是編譯期
## 錯誤(已登記禁用模式 [code]abstract_func_with_body[/code],2026-08-20 驗證;
## 先例:[code]src/gameplay/cards/affinity_write_port.gd[/code]、
## [code]src/ui/cursor/mouse_reclaim_policy.gd[/code])。
@abstract
class_name SupportConversationWritePort
extends RefCounted


## 寫入一筆支援對話來源的好感度記錄。
##
## 本介面刻意不定義任何拒絕碼回傳值 —— 本 story 的唯一呼叫端
## ([method SupportConversationRules.trigger],規格 AC-6 的那恰好 1 處)不需要區分
## 拒絕原因,只需要知道「有沒有被呼叫、呼叫了幾次、帶了什麼參數」,測試裡由假寫入埠
## 自行記錄即可。真實池是否接受這筆寫入(例如 [param m] == 0.0 會被
## [code]AffinityDataPool.append_record[/code] 的
## [code]WriteRejection.ZERO_AMPLITUDE[/code] 拒絕)是接上真池那天(story-002,
## 不在本 story 範圍)才需要處理的轉接層問題。
@abstract
func append_record(pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source) -> void
