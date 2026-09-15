# AffinityTypes —— 好感度數值池(Delta Log)資料層的共用列舉詞彙。
#
# 設計文件:design/gdd/affinity-data-pool.md
#   - Formulas 章節開頭「共用符號表」(Pair/Character/Source 的定義域)
#   - Section A,AC-27a(Pair 恰有 10 種合法值)
#   - Section M,AC-56/AC-57(索引鍵持久化穩定性——名稱存取器與序數無關)
# 治理 ADR:docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md
#   - 機制二(共用列舉的檔案歸屬):三個列舉必須集中於本檔,以 class_name AffinityTypes
#     包裝——GDScript 沒有「不透過任何 class 包裝、跨檔案可見的裸列舉」這回事。
#   - 機制四之四(8 個帶 enum 參數的入口統一序數驗證):三個公開靜態驗證器 +
#     pair_of() 的呼叫端前置義務。
# Story:production/epics/affinity-data-pool/story-001-affinity-types.md(S-001)
#
# 本類別全為 static func,無實例狀態;extends RefCounted 只是為了讓
# class_name 掛得上去(ADR-0002 機制二逐字如此宣告)。
class_name AffinityTypes
extends RefCounted


## 5 名固定主角的佔位識別碼。角色系統尚未設計(ADR-0002 Constraints);
## 定案實際命名時只需重新命名這 5 個 enum 值本身,呼叫端邏輯不受影響——
## 呼叫端一律以 [enum Character] 列舉值溝通,不假設任何具體名稱字串。
##
## 🔴 本列舉的序數(0 起算)不等於 assets/data/units/vs01_roster.txt 的
## roster id(1 起算)——見 EPIC.md「陷阱一」。建立這個對映是 S-008 的責任,
## 本檔不建立、也不應被誤讀為暗示兩者相等。
enum Character {
	CHARACTER_1,
	CHARACTER_2,
	CHARACTER_3,
	CHARACTER_4,
	CHARACTER_5,
}

## 5 名固定主角兩兩組合、共 10 種固定配對(C(5,2)=10)。此集合遊戲全程
## 封閉且固定(GDD Edge Cases——「配對集合是封閉且固定的」)。AC-27a 驗證
## 本列舉恰有 10 個合法值。
enum Pair {
	C1_C2, C1_C3, C1_C4, C1_C5,
	C2_C3, C2_C4, C2_C5,
	C3_C4, C3_C5,
	C4_C5,
}

## Delta Log 記錄來源類別。用於標記每筆記錄由何種上游系統寫入。
enum Source {
	COMBAT_CARD,
	SUPPORT_CONVERSATION,
	STORY_EVENT,
}


## [enum Pair] -> 兩名成員 [enum Character] 的權威對照表(本模組唯一資料來源)。
## [method pair_of]([Character] × 2 -> [Pair])與 [method members_of]
##([Pair] -> [Character] × 2,反查方向)皆從本表推導,不再各自手寫一份
## 對映階梯——本專案已登記過「同一份對映在兩處各自手寫、只是今天答案一致,
## 而黑箱比對永遠無法區分『共用同一份』與『兩份碰巧一致』」這個失效模式
## (`.claude/docs/technical-preferences.md`、
## `production/epics/affinity-data-pool/EPIC.md`),故收斂為單一權威來源,
## 使兩個方向在結構上不可能不一致。
##
## 🔴 刻意私有(不對外公開)——外部呼叫端一律透過 [method pair_of] /
## [method members_of] 存取,不得直接讀寫本表。GDScript 的 `const` 只擋
## 重新賦值整個 [Dictionary],不擋修改巢狀 [Array] 的內容;若本表公開,
## 任何呼叫端都能就地改掉某個 [enum Pair] 的成員清單,弄壞全域共用狀態。
const _PAIR_MEMBERS: Dictionary = {
	Pair.C1_C2: [Character.CHARACTER_1, Character.CHARACTER_2],
	Pair.C1_C3: [Character.CHARACTER_1, Character.CHARACTER_3],
	Pair.C1_C4: [Character.CHARACTER_1, Character.CHARACTER_4],
	Pair.C1_C5: [Character.CHARACTER_1, Character.CHARACTER_5],
	Pair.C2_C3: [Character.CHARACTER_2, Character.CHARACTER_3],
	Pair.C2_C4: [Character.CHARACTER_2, Character.CHARACTER_4],
	Pair.C2_C5: [Character.CHARACTER_2, Character.CHARACTER_5],
	Pair.C3_C4: [Character.CHARACTER_3, Character.CHARACTER_4],
	Pair.C3_C5: [Character.CHARACTER_3, Character.CHARACTER_5],
	Pair.C4_C5: [Character.CHARACTER_4, Character.CHARACTER_5],
}


## 將兩個 [enum Character] 正規化為對應的 [enum Pair]。內部逐筆走訪
## [member _PAIR_MEMBERS]、對每筆的兩名成員各檢查一次「(a,b)」與「(b,a)」
## 兩種順序(而非依賴呼叫順序)消除歧義,因此 `pair_of(a, b)` 與
## `pair_of(b, a)` 永遠回傳相同的 [enum Pair]——呼叫端永遠不需要自行決定
## 兩個 Character 的排列順序。
##
## 🔴 前置條件(ADR-0002 機制四之四,已登記禁令
## unvalidated_character_into_pair_of):呼叫端必須先以
## [method is_valid_character] 驗證兩個參數。本函式回傳裸 [enum Pair],
## 結構上容不下拒絕碼——對非法序數(含 a == b,同一人不成配對)的行為
## 未定義。命中該情形時本函式會 push_error 並回傳一個任意的哨兵值
## （[constant Pair.C1_C2]),但呼叫端不應依賴這個哨兵值本身。
static func pair_of(a: Character, b: Character) -> Pair:
	for pair: Pair in _PAIR_MEMBERS:
		var members: Array = _PAIR_MEMBERS[pair]
		if (members[0] == a and members[1] == b) or (members[0] == b and members[1] == a):
			return pair

	# 前置條件被違反:越界序數,或 a == b(同一人不構成配對)。
	# _PAIR_MEMBERS 每筆的兩名成員互不相同,兩種輸入都不會命中上面任何
	# 一筆,與舊版 lo/hi 階梯落到同一個「查無此組合」分支行為一致。
	# ADR-0002 明文此為未定義行為——這裡選擇 push_error 而非靜默回傳,
	# 讓違反前置條件的呼叫在測試/開發階段可被發現,而不是悄悄拿到一個
	# 看似合法但錯誤的 Pair。
	push_error(
		"AffinityTypes.pair_of() 前置條件被違反(a=%d, b=%d)—— "
		% [int(a), int(b)]
		+ "呼叫端必須先以 is_valid_character() 驗證兩個參數。行為未定義。"
	)
	return Pair.C1_C2


## 回傳 [param p] 對應的兩名成員 [enum Character](依 [member _PAIR_MEMBERS]
## 定義順序,與呼叫端當初傳給 [method pair_of] 的 a/b 順序無關)。
## [method pair_of] 的反查方向——`pair_of()` 只提供
## `Character × 2 -> Pair`,本函式補上另一半,取代原本散落在
## `affinity_data_pool.gd` 的第二份手寫對照表。
##
## 未知/非法 [param p] 回傳空陣列,不中止、不拋錯——目前唯一呼叫端
## [method AffinityDataPool.t_death] 不在 ADR-0002 機制四之四的 8 個
## 序數驗證入口清單內,沿用既有的「查無則空、迴圈自然不執行」慣例。
##
## 🔴 回傳值是 [member _PAIR_MEMBERS] 內部陣列的複本([method Array.duplicate]),
## 不是原始參照——呼叫端修改回傳的陣列不會影響本表。
static func members_of(p: Pair) -> Array:
	if not _PAIR_MEMBERS.has(p):
		return []
	return _PAIR_MEMBERS[p].duplicate()


## 回傳 [param c] 是否為 [enum Character] 的 5 個合法序數之一。
##
## 🔴 必須以 `.values().has()` 實作,不得依賴「型別化參數本身能擋下非法值」
## 這個假設——探針 B 實測:越界 int(-1/999)原封不動抵達函式本體,零錯誤
## 零檢查;夾帶 float 3.7 會靜默截斷為合法序數 3、不中止。本函式是
## 唯一防線,不是防禦層(EPIC.md 陷阱二)。
static func is_valid_character(c: Character) -> bool:
	return Character.values().has(c)


## 回傳 [param p] 是否為 [enum Pair] 的 10 個合法序數之一。
## 實作理由同 [method is_valid_character]。
static func is_valid_pair(p: Pair) -> bool:
	return Pair.values().has(p)


## 回傳 [param s] 是否為 [enum Source] 的 3 個合法序數之一。
## 實作理由同 [method is_valid_character]。
static func is_valid_source(s: Source) -> bool:
	return Source.values().has(s)
