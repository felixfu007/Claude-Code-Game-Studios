## [SupportConversationWritePort] 的第一個真實實作 —— 把支援對話系統(系統 #8)的
## 觸發結果真的寫進 [AffinityDataPool](好感度數值池,ADR-0002)。
##
## 🔴 裁決②(2026-10-19 管理者裁決,逐字選項「新增一個專用轉接器(推薦)」):
## 不改既有的 [code]AffinityPoolWritePort[/code]
## ([code]src/gameplay/cards/affinity_pool_write_port.gd[/code],卡牌系統專用)——
## 理由見該檔自己的文件註解自陳:唯一合法呼叫端恆傳
## [code]AffinityWritePort.SOURCE_COMBAT_CARD[/code]。改它去認得支援對話來源等於
## 拿掉這個前提,而且它已有自己的測試釘著
## ([code]tests/integration/gameplay/cards/affinity_pool_write_port_test.gd[/code])。
## 支援對話系統因此需要自己專屬的轉接器,即本檔。
##
## [method SupportConversationWritePort.append_record] 的簽章刻意比照
## [method AffinityDataPool.append_record]
## ([code](pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source)[/code],
## 見 [SupportConversationWritePort] 類別文件註解),所以本轉接器只需要「原封不動
## 轉送」——不像卡牌系統的 [code]AffinityPoolWritePort[/code] 那樣要做
## roster id -> [enum AffinityTypes.Character] 序數的對映。那個對映是支援對話系統
## 上游([AffinityRosterCharacterMapper]、[method SupportConversationRules.trigger])
## 已經做完的事,本檔不重做,也沒有管道重做(抽象簽章接收的已經是組好的
## [enum AffinityTypes.Pair])。
##
## 🔴 [b]池子拒絕時怎麼處理 —— 本檔自己的判斷,未經協調者覆核。[/b] 若下一個人有
## 更好的表達方式,應該取代這裡,而不是延續它:
## [br]
## [method AffinityDataPool.append_record] 回傳 [enum AffinityDataPool.WriteRejection]
## 七類分支之一,而 [method SupportConversationWritePort.append_record] 的抽象簽章
## 回傳 [code]void[/code] —— 本轉接器結構上無法把拒絕碼回傳給唯一呼叫端
## ([method SupportConversationRules.trigger])。選擇[b]不靜默吞掉[/b],分兩層:
## [br]
## 1. 一律 [method push_error] 曝光拒絕碼與完整上下文(pair/m/source)。
##    刻意[b]不用[/b] [code]assert()[/code] —— 這是派工單的明文指示,也與本專案
##    `.claude/docs/coding-standards.md` 2026-09-15 條目一致的既有慣例
##    (該條目記載的具體陷阱是「assert 失敗會中止函式、回傳宣告型別的序數 0」,
##    本方法回傳型別是 [code]void[/code] 不直接落入那個陷阱,但沿用同一套
##    push_error() 慣例,讓讀者不必分辨「這裡為什麼是唯一的例外」)。
## 2. 額外保留 [member last_rejection] 診斷欄位,記錄最近一次池子實際回傳的
##    拒絕碼——這不是 [SupportConversationWritePort] 契約的一部分(介面簽章依然是
##    [code]void[/code]),純粹是本檔自己選擇的可觀測手段,讓測試能直接斷言
##    「池子真的拒絕了」,不必依賴脆弱的 log 字串比對(呼應
##    `.claude/docs/coding-standards.md` 的「Split the target:assert the
##    component's decision ... via a diagnostic getter」既有慣例)。🔴 [b]它是一個
##    公開可寫的 [code]var[/code],不是唯讀[/b]——GDScript 沒有唯讀修飾字,外部
##    呼叫端技術上能直接指派它,見 [member last_rejection] 自己的文件註解。
## [br]
## 沒有改寫 [SupportConversationWritePort] 本身的簽章成帶拒絕碼回傳值——那會連動
## 改到唯一呼叫端 [method SupportConversationRules.trigger]、測試用的假寫入埠
## (`support_conversation_rules_test.gd` 的 [code]_SpyWritePort[/code])、以及
## [code]support_conversation_write_call_site_count_test.gd[/code] 的乙類掃描
## 範圍假設——代價大於「void + push_error + 診斷欄位」這個不改介面的方案。
class_name SupportConversationPoolWritePort
extends SupportConversationWritePort


## 建構時注入的目標池(依賴注入,比照 [code]AffinityPoolWritePort._init[/code] 既有
## 形狀)。本檔不負責這個實例從哪裡來、由誰持有——那是接線那一端的責任。
var _pool: AffinityDataPool

## 診斷欄位——🔴 [b]公開可寫,不是唯讀[/b](GDScript 沒有唯讀修飾字,外部呼叫端
## 技術上能直接指派它)。慣例上只供讀取、僅供測試/除錯斷言,不屬於
## [SupportConversationWritePort] 的介面契約:最近一次呼叫 [method append_record]
## 時,池子實際回傳的 [enum AffinityDataPool.WriteRejection]。預設
## [constant AffinityDataPool.WriteRejection.NONE](尚未呼叫過,或尚未呼叫過
## 任何被拒絕的寫入)。見類別文件註解「池子拒絕時怎麼處理」第 2 點。
var last_rejection: AffinityDataPool.WriteRejection = AffinityDataPool.WriteRejection.NONE


## [param pool] 是本轉接器實際寫入的目標。
func _init(pool: AffinityDataPool) -> void:
	_pool = pool


## 見類別文件註解「池子拒絕時怎麼處理」。[param pair]/[param m]/[param source]
## 原封不動轉送給 [method AffinityDataPool.append_record]——本檔不做任何型別搬運
## 或轉換。
func append_record(pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source) -> void:
	last_rejection = _pool.append_record(pair, m, source)
	if last_rejection != AffinityDataPool.WriteRejection.NONE:
		push_error(
			(
				"SupportConversationPoolWritePort.append_record: 池子拒絕了這筆寫入"
				+ "(WriteRejection 序數 %d,pair=%d, m=%f, source=%d)。"
				+ "SupportConversationWritePort.append_record 的抽象簽章回傳 void,"
				+ "本轉接器無法把拒絕碼回傳給呼叫端——曝光為錯誤,並記錄於 "
				+ "last_rejection 供測試/除錯觀察,理由見本檔文件註解。"
			) % [int(last_rejection), int(pair), m, int(source)]
		)
