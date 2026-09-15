# AffinityPoolWritePort —— AffinityWritePort(技能卡牌系統既有介面,
# src/gameplay/cards/affinity_write_port.gd)的第一個真實實作。在本檔存在
# 之前,NullAffinityWritePort 是唯一存在的實作,永遠什麼都不做——打一張丙類
# 卡因此永遠寫不進 Delta Log。
#
# Story:production/epics/affinity-data-pool/story-008-write-port-adapter.md(S-008)
# 治理 ADR:docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md
#   - 機制四(append_record() 七類拒絕)
#   - 機制四之三(呼叫端型別義務——本檔是這句話第一次有主人接手的地方)
#   - 機制四之四(8 個帶 enum 參數的入口統一序數驗證,本檔涵蓋其中兩個入口:
#     character_a/character_b -> AffinityTypes.Character)
#
# 把技能卡牌系統既有的呼叫慣例(character_a/character_b 為
# assets/data/units/vs01_roster.txt 的 roster id、m: int、source 恆為
# AffinityWritePort.SOURCE_COMBAT_CARD)轉換成 AffinityDataPool.append_record()
# 需要的型別(AffinityTypes.Pair / float / AffinityTypes.Source)。依賴注入
# ——建構子接收一個真正的 AffinityDataPool 參照(ADR-0002 機制一,非
# Autoload)。本 story 不負責這個池實例從哪裡來、由誰持有,那是 S-009(接線)
# 的範圍——本檔只需要能在測試裡自行 new() 一個 AffinityDataPool 傳入即可
# 獨立驗證。
#
# 🔴 五個陷阱(EPIC.md/工作單,逐一對應下方程式碼位置):
#   1. roster id(1~5)與 AffinityTypes.Character 序數(0 起算)差 1——見
#      _ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET 與 append_record() 開頭。
#      ADR-0002 全文沒有任何一句話建立這個對映,本檔是它的歸屬處。
#   2. 序數驗證必須先於 AffinityTypes.pair_of()——見 append_record() 對
#      is_valid_character() 的雙重驗證,以及對 character_a == character_b 的
#      額外檢查。AffinityTypes.pair_of() 自己的文件註解明文:「含 a == b,
#      同一人不成配對」也是該函式的未定義輸入,呼叫端必須連同序數驗證一起
#      擋下——只驗證單邊合法就放行的話,兩個相同的合法角色會落入
#      pair_of() 自己的 push_error() + 任意哨兵值 Pair.C1_C2 分支,而本檔
#      若照樣把哨兵值送進 _pool.append_record(),會靜默寫入一筆錯誤配對的
#      記錄——已登記禁令 unvalidated_character_into_pair_of。
#   3. source 只有一個合法值——不寫任何字串比較/轉換邏輯,見 append_record()
#      對 _source 參數的處理(底線前綴,刻意從不讀取)。
#   4. m: int -> float 的拓寬只在本檔這一個接縫發生——見 float(m) 那一行。
#      不得散佈到卡牌系統的其他呼叫端。
#   5. 埠側 INVALID_PAIR 與池側 INVALID_PAIR 同名不同義,不可直接轉送——見
#      _expose_unexpected_pool_rejection() 與其文件註解。
#
# 🔴 本檔對「角色設定關係線」(design/narrative/characters.md、
# assets/data/affinity/vs01_affinity_links.txt)零認知,刻意不檢查、也沒有
# 管道可以檢查——AffinityWritePort.append_record() 的抽象簽章不接受任何
# links 參數,本檔的建構子也只接收 AffinityDataPool。canon 關係線的檢查是
# PermanentAffinityWriteRules.play()(既有程式碼,skill-card-system Story 004)
# 的職責,在呼叫本埠之前就已完成(見該檔文件註解與 AC-8c 的測試)——這與
# ADR-0002 GDD 界線 4「池對敘事 canon 零認知」完全對稱,本檔是那個「池」的
# 真實轉接器,理當繼承同一種無知。
class_name AffinityPoolWritePort
extends AffinityWritePort


## roster id(assets/data/units/vs01_roster.txt,1~5,甲乙丙丁戊)轉換成
## [enum AffinityTypes.Character] 序數(0 起算)所需的偏移量。**本專案唯一
## 建立這個對映的地方**——ADR-0002 全文沒有任何一句話定義它(見類別文件
## 註解陷阱一)。roster id 6~10 是敵方單位,不對應任何
## [enum AffinityTypes.Character] 成員,減去本偏移量後會落在 0~4 合法範圍
## 之外(5~9),由 [method AffinityTypes.is_valid_character] 擋下。
const _ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET: int = 1

## 若本檔自身的序數驗證已正確執行,呼叫 [method AffinityDataPool.append_record]
## 理論上不應該回傳下列任一種池側拒絕碼:[constant AffinityDataPool.WriteRejection.INVALID_PAIR]
## (限制第 9 條——池側語意與埠側 INVALID_PAIR 不同,不可直接轉送)、
## [constant AffinityDataPool.WriteRejection.INVALID_SOURCE] /
## [constant AffinityDataPool.WriteRejection.NON_FINITE_AMPLITUDE](本轉接器
## 這條路徑結構不可達——source 恆為合法常數、m: int 造不出 NaN/Infinity)、
## [constant AffinityDataPool.WriteRejection.SERIALIZATION_WINDOW_ACTIVE]
## (限制第 8 條,今天恆不可達,已登記給協調者處置,本檔不裁決是否新增埠側
## 列舉值)。落地此分支代表本檔自己的轉換邏輯有 bug,或(僅
## SERIALIZATION_WINDOW_ACTIVE)代表 S-014 已落地但本埠尚未擴充——兩者都不
## 該被靜默吞掉,也不該被誤讀成一個劇情/業務事實,因此一律 push_error() 曝光
## (見 [method _expose_unexpected_pool_rejection]),並回傳本常數做為
## 「拒絕,但不代表任何真實業務含義」的佔位訊號。
##
## 🔴 選擇 [constant Rejection.ZERO_MAGNITUDE] 純屬武斷,不是語意正確的對映
## ——本埠的 4 值列舉裡沒有一個成員的語意符合「內部錯誤/未預期分支」:
## [constant Rejection.NONE] 絕對不可選(會謊稱寫入成功,對「一個被拒絕的
## 寫入必須不留痕跡」這條原則造成最嚴重的違反);[constant Rejection.INVALID_PAIR]
## 依限制第 9 條明文禁止用於此處;[constant Rejection.DEAD_PAIR_FORBIDDEN] 會
## 對玩家/呼叫端斷言一個未必為真的敘事事實(有人死了);
## [constant Rejection.NO_PORT_CONFIGURED] 語意上專屬 NullAffinityWritePort,
## 用在一個真實配置的埠上是另一種謊言。ZERO_MAGNITUDE 是其中「不主張任何
## 具體錯誤敘事事實、只暗示『這次寫入沒有造成改變』」相對最無害的選擇。
## **這是本 story 的判斷,未經協調者覆核**——若下一個人有更好的表達方式
## (例如日後幫 AffinityWritePort 新增一個專門的「內部錯誤」分支),應該取代
## 這裡,而不是延續它。見本 story 最終回報「我沒做到或不確定的事」一節。
const _UNEXPECTED_POOL_REJECTION_SENTINEL: Rejection = Rejection.ZERO_MAGNITUDE

var _pool: AffinityDataPool


## [param pool] 是本轉接器實際寫入的目標(依賴注入,ADR-0002 機制一)。本
## story 不負責這個實例從哪裡來、由誰持有——那是 S-009 的範圍。
func _init(pool: AffinityDataPool) -> void:
	_pool = pool


## 見類別文件註解的五個陷阱與 [AffinityWritePort.append_record] 的抽象簽章。
##
## [param _source] 刻意底線前綴、從不讀取其實際內容——見類別文件註解陷阱三:
## 本埠的唯一合法呼叫端([code]PermanentAffinityWriteRules.play[/code])恆傳
## [constant AffinityWritePort.SOURCE_COMBAT_CARD],因此本方法直接映射成
## [constant AffinityTypes.Source.COMBAT_CARD] 這個唯一對應的池側常數,不對
## [param _source] 做任何字串比較或轉列舉的邏輯。
func append_record(character_a: int, character_b: int, m: int, _source: StringName) -> Rejection:
	# 陷阱一 + 陷阱二:roster id -> Character 序數,呼叫 pair_of() 之前必須先
	# 驗證兩個參數皆為合法序數,且兩者不相等(AffinityTypes.pair_of() 文件
	# 註解明文:a == b 同樣是該函式的未定義輸入)。任一條件不成立,在此直接
	# 回傳 INVALID_PAIR——這裡的語意是「這個輸入從頭到尾就沒有描述過一個
	# 可寫入的配對」,不同於下方 match 分支要防的「本檔驗證通過、但池又
	# 反悔」那種情況(限制第 9 條)。
	var char_a: AffinityTypes.Character = character_a - _ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET
	var char_b: AffinityTypes.Character = character_b - _ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET

	if not AffinityTypes.is_valid_character(char_a) or not AffinityTypes.is_valid_character(char_b):
		push_error(
			"AffinityPoolWritePort.append_record: roster id 超出合法範圍(character_a=%d, character_b=%d)"
			% [character_a, character_b]
		)
		return Rejection.INVALID_PAIR

	if char_a == char_b:
		push_error(
			(
				"AffinityPoolWritePort.append_record: character_a 與 character_b 相同"
				+ "(roster id %d),同一人不構成配對"
			) % character_a
		)
		return Rejection.INVALID_PAIR

	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(char_a, char_b)

	# 陷阱四:int -> float 的拓寬,本檔唯一接縫,不得散佈到其他呼叫端。
	# 陷阱三:source 直接映射成唯一合法的池側常數,不比較 _source 的實際內容。
	var pool_rejection: AffinityDataPool.WriteRejection = _pool.append_record(
		pair, float(m), AffinityTypes.Source.COMBAT_CARD
	)

	match pool_rejection:
		AffinityDataPool.WriteRejection.NONE:
			return Rejection.NONE
		AffinityDataPool.WriteRejection.ZERO_AMPLITUDE:
			return Rejection.ZERO_MAGNITUDE
		AffinityDataPool.WriteRejection.DEAD_PAIR_COMBAT_CARD_FORBIDDEN:
			return Rejection.DEAD_PAIR_FORBIDDEN
		_:
			# 結構上不應抵達此分支——INVALID_PAIR(限制第 9 條)、
			# INVALID_SOURCE / NON_FINITE_AMPLITUDE(本路徑結構不可達)、
			# SERIALIZATION_WINDOW_ACTIVE(限制第 8 條,今天恆不可達,已登記
			# 給協調者處置,本檔不裁決)全部落入此分支,一律曝光不吞掉。
			return _expose_unexpected_pool_rejection(pool_rejection, character_a, character_b, m)


## 見 [member _UNEXPECTED_POOL_REJECTION_SENTINEL] 的判斷理由與代價。
func _expose_unexpected_pool_rejection(
	pool_rejection: AffinityDataPool.WriteRejection, character_a: int, character_b: int, m: int
) -> Rejection:
	push_error(
		(
			"AffinityPoolWritePort.append_record: AffinityDataPool.append_record() 回傳了 "
			+ "WriteRejection 序數 %d,但本轉接器自己的序數驗證應已排除這個分支"
			+ "(character_a=%d, character_b=%d, m=%d)。這不是一個真實的業務拒絕——"
			+ "曝光為未預期的內部錯誤,詳見本檔 _UNEXPECTED_POOL_REJECTION_SENTINEL 的文件註解。"
		) % [int(pool_rejection), character_a, character_b, m]
	)
	return _UNEXPECTED_POOL_REJECTION_SENTINEL
