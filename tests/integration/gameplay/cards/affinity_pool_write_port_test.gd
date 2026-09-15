# AffinityPoolWritePort(src/gameplay/cards/affinity_pool_write_port.gd)的
# 整合測試——production/epics/affinity-data-pool/story-008-write-port-adapter.md(S-008)。
#
# 🔴 本 story 的驗收落點在對面那份 GDD(design/gdd/skill-card-system.md),
# 本系統 GDD 對本 story 零管轄——涵蓋 AC-6、AC-7b、AC-8c(原文轉錄於工作單)。
# 型別:Integration(工作單明文)。
#
# 全鏈路(AffinityDataPool/AffinityTypes/AffinityRecord/AffinityPoolWritePort/
# PermanentAffinityWriteRules/Card/AffinityLink)都是 RefCounted,不建立任何
# Node,不會留下孤兒節點,不需要 tear-down。
#
# ⚠️ 沿用本專案既有測試慣例(tests/unit/gameplay/affinity_pool/
# affinity_data_pool_write_path_test.gd):GDScript 沒有真正的私有成員,底線
# 前綴只是命名慣例,測試直接讀取 pool._records / pool._t_now 驗證副作用——
# AffinityDataPool 在本 story 的切片內尚未提供任何公開的讀取方法
# (advance_campaign_tick()/三個加權讀取函數屬後續 story)。
extends GdUnitTestSuite


const _AFFINITY_LINKS_PATH: String = "res://assets/data/affinity/vs01_affinity_links.txt"


# 間諜池——永遠回傳池側 INVALID_PAIR,模擬「本檔序數驗證全部正確通過、但池
# 仍反悔」這個結構上不該發生的情境(限制第 9 條)。真實 AffinityDataPool 在
# 轉接器已驗證過序數的前提下不會走到這個分支——這個類別只用來證明轉接器
# 自己的防禦邏輯,不是在測池的真實行為。GDScript 支援子類別覆寫父類別的一般
# 方法並透過父類別型別的變數動態分派(沿用
# tests/integration/gameplay/cards/card_battle_wiring_test.gd 的 _SpyCardDeck
# 手法),AffinityPoolWritePort._pool 型別為 AffinityDataPool,注入本子類別
# 實例後,_pool.append_record() 會呼叫到這裡被覆寫的版本。
class _AlwaysInvalidPairPool extends AffinityDataPool:
	func append_record(
		_pair: AffinityTypes.Pair, _m: float, _source: AffinityTypes.Source
	) -> WriteRejection:
		return WriteRejection.INVALID_PAIR


func _real_links() -> Array[AffinityLink]:
	var text: String = FileAccess.get_file_as_string(_AFFINITY_LINKS_PATH)
	return AffinityLink.links_from_text(text)


# ---- AC-6:打出丙類 -> 池新增一筆記錄,source 為 combat_card、幅度為卡定義值 ----

func test_playing_combat_card_appends_record_with_combat_card_source_and_defined_magnitude() -> void:
	# Arrange — 甲乙(roster id 1、2)是真實資料檔裡的合作(POSITIVE)配對
	var pool: AffinityDataPool = AffinityDataPool.new()
	var port: AffinityPoolWritePort = AffinityPoolWritePort.new(pool)
	var links: Array[AffinityLink] = _real_links()
	var card: Card = Card.new_permanent_affinity_write("c_ac6", 1, 2, 3)
	var expected_pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2
	)

	# Act
	var rejection: AffinityWritePort.Rejection = PermanentAffinityWriteRules.play(
		card, 1, 2, links, port
	)

	# Assert
	assert_int(rejection).is_equal(AffinityWritePort.Rejection.NONE)
	assert_int(pool._records[expected_pair].size()).is_equal(1)
	var record: AffinityRecord = pool._records[expected_pair].get_at(0)
	assert_int(record.pair).is_equal(expected_pair)
	assert_float(record.m).is_equal_approx(3.0, 0.000000000001)
	assert_int(record.source).is_equal(AffinityTypes.Source.COMBAT_CARD)


# ---- AC-7b:繞過選擇介面,直接以陣亡配對呼叫 -> 驗證錯誤,記錄筆數不變 -------
#
# 🔴 誠實揭露:PermanentAffinityWriteRules.play() 只檢查 canon 存在(見該檔
# 文件註解),刻意不檢查存活——canon 存在 + 陣亡的組合必須真的走到本埠、
# 由池自己的 t_death() 擋下,證明第二道防線確實存在於埠這一層,不是被上游
# 攔截。因此本測試選 1-2(canon 存在)並讓 1(甲)陣亡。

func test_dead_pair_write_via_port_returns_validation_rejection_with_no_count_change() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()
	var port: AffinityPoolWritePort = AffinityPoolWritePort.new(pool)
	var links: Array[AffinityLink] = _real_links()
	pool.notify_death(AffinityTypes.Character.CHARACTER_1)
	var card: Card = Card.new_permanent_affinity_write("c_ac7b", 1, 2, 3)
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2
	)

	# Act
	var rejection: AffinityWritePort.Rejection = PermanentAffinityWriteRules.play(
		card, 1, 2, links, port
	)

	# Assert — 在埠這一層被拒絕(不是 has_canon_link 攔下的,那個 1-2 本來就有
	# canon 連結),記錄筆數與全域計數器都不變
	assert_int(rejection).is_equal(AffinityWritePort.Rejection.DEAD_PAIR_FORBIDDEN)
	assert_int(pool._records[pair].size()).is_equal(0)
	assert_int(pool._t_now).is_equal(0)


# ---- AC-8c:繞過選取介面,直接以非 canon 配對(含戊者)呼叫 -> 驗證錯誤 ------
#
# 🔴 本 story 的工作單原文(「Acceptance Criteria」節)明文:AC-8c「沒有第二道
# 防線,唯一防線就在本系統」——經逐檔核對,「本系統」指的是
# PermanentAffinityWriteRules.play() 既有的 has_canon_link() 前置檢查(skill-
# card-system Story 004 的既有程式碼,非本 story 交付範圍),不是本檔
# AffinityPoolWritePort。本檔對 canon 關係線零認知、也沒有管道可以檢查
# (AffinityWritePort.append_record() 的抽象簽章不接受 links 參數)——這條
# 測試因此驗證的是「本埠與既有 play() 正確接線在一起,使 8c 的既有防線在
# 加入真實埠之後仍然有效」,而不是本埠自己新增了 canon 檢查。見本 story 最終
# 回報「我沒做到或不確定的事」一節,對照原始派工單「唯一防線就在你這裡」
# 這句可能引起的誤讀。

func test_non_canon_pair_write_via_port_returns_validation_rejection_with_no_count_change() -> void:
	# Arrange — 甲(roster id 1)與戊(roster id 5)。戊在真實資料檔裡沒有任何
	# 配對(assets/data/affinity/vs01_affinity_links.txt 檔頭明文:「戊沒有任何
	# 配對,這是刻意的,不是漏寫」),1-5 因此結構上不可能是 canon 配對
	var pool: AffinityDataPool = AffinityDataPool.new()
	var port: AffinityPoolWritePort = AffinityPoolWritePort.new(pool)
	var links: Array[AffinityLink] = _real_links()
	var card: Card = Card.new_permanent_affinity_write("c_ac8c", 1, 5, 2)

	# Act
	var rejection: AffinityWritePort.Rejection = PermanentAffinityWriteRules.play(
		card, 1, 5, links, port
	)

	# Assert — has_canon_link() 失败,play() 從未呼叫 port.append_record()——
	# 池的全部 10 個配對筆數與全域計數器都必須維持初始狀態
	assert_int(rejection).is_equal(AffinityWritePort.Rejection.INVALID_PAIR)
	for pair: AffinityTypes.Pair in AffinityTypes.Pair.values():
		assert_int(pool._records[pair].size()).is_equal(0)
	assert_int(pool._t_now).is_equal(0)


# ---- 陷阱一:roster id -> Character 序數的對映,經驗證、不是裸算式 -----------

func test_roster_id_to_character_ordinal_mapping_is_off_by_one_and_validated() -> void:
	# Arrange — 甲(roster id 1)與戊(roster id 5),刻意選擇涵蓋範圍兩端點:
	# id 1 若被誤用「id 當序數」會變成 CHARACTER_2(off-by-one 往上偏一格),
	# id 5 若被誤用會落在合法範圍外(CHARACTER_5 的序數是 4,不是 5)。
	#
	# 🔴 這裡刻意直接呼叫 port.append_record(),不經 PermanentAffinityWriteRules
	# ——本埠對「角色設定關係線」零認知(見類別文件註解),1-5 沒有 canon 連結
	# 這件事在這一層不構成拒絕理由,正是 AC-8c 那條測試要證明「唯一防線在
	# play()、不在這裡」的另一面證據。
	var pool: AffinityDataPool = AffinityDataPool.new()
	var port: AffinityPoolWritePort = AffinityPoolWritePort.new(pool)
	var expected_pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_5
	)

	# Act
	var rejection: AffinityWritePort.Rejection = port.append_record(
		1, 5, 2, AffinityWritePort.SOURCE_COMBAT_CARD
	)

	# Assert — 接受,且記錄精確落在 C1_C5(不是誤用 id 當序數會導致的其他配對)
	assert_int(rejection).is_equal(AffinityWritePort.Rejection.NONE)
	assert_int(pool._records[expected_pair].size()).is_equal(1)
	var record: AffinityRecord = pool._records[expected_pair].get_at(0)
	assert_int(record.pair).is_equal(expected_pair)


# ---- 陷阱二:越界 roster id 在 pair_of() 之前就被擋下 -----------------------

func test_roster_id_out_of_range_is_rejected_before_reaching_pair_of() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()
	var port: AffinityPoolWritePort = AffinityPoolWritePort.new(pool)

	# Act — Case 1:roster id 0(低於 1,對映後序數 -1)
	var rejection_low: AffinityWritePort.Rejection = port.append_record(
		0, 2, 2, AffinityWritePort.SOURCE_COMBAT_CARD
	)
	# Act — Case 2:roster id 6(敵方單位範圍,對映後序數 5,超出 Character 的 0~4)
	var rejection_high: AffinityWritePort.Rejection = port.append_record(
		6, 2, 2, AffinityWritePort.SOURCE_COMBAT_CARD
	)
	# Act — Case 3:同一人不成配對(character_a == character_b);
	# AffinityTypes.pair_of() 文件註解明文這也是未定義輸入
	var rejection_same: AffinityWritePort.Rejection = port.append_record(
		3, 3, 2, AffinityWritePort.SOURCE_COMBAT_CARD
	)

	# Assert — 三種非法輸入都回傳驗證錯誤
	assert_int(rejection_low).is_equal(AffinityWritePort.Rejection.INVALID_PAIR)
	assert_int(rejection_high).is_equal(AffinityWritePort.Rejection.INVALID_PAIR)
	assert_int(rejection_same).is_equal(AffinityWritePort.Rejection.INVALID_PAIR)

	# Assert — 沒有任何一筆記錄意外寫入任何合法配對(證明真的在 pair_of() 之前
	# 被擋下,不是進了 pair_of() 拿到任意哨兵值 Pair.C1_C2 後仍寫入池),
	# 全域計數器也未遞增
	for pair: AffinityTypes.Pair in AffinityTypes.Pair.values():
		assert_int(pool._records[pair].size()).is_equal(0)
	assert_int(pool._t_now).is_equal(0)


# ---- 限制第 9 條:池側 INVALID_PAIR 絕不可原樣轉送成埠側 INVALID_PAIR --------

func test_port_never_returns_pool_invalid_pair_as_port_invalid_pair() -> void:
	# Arrange — 間諜池永遠回傳池側 INVALID_PAIR(見本檔頂部 _AlwaysInvalidPairPool
	# 的文件註解)
	var spy_pool: _AlwaysInvalidPairPool = _AlwaysInvalidPairPool.new()
	var port: AffinityPoolWritePort = AffinityPoolWritePort.new(spy_pool)

	# Act — 輸入本身完全合法(roster id 1、2,皆為合法序數且不相等),因此會
	# 走到呼叫 _pool.append_record() 這一步,拿到間諜池的 INVALID_PAIR
	var rejection: AffinityWritePort.Rejection = port.append_record(
		1, 2, 2, AffinityWritePort.SOURCE_COMBAT_CARD
	)

	# Assert — 轉接器絕不可把池側 INVALID_PAIR 原樣轉送成埠側 INVALID_PAIR
	# (見類別文件註解:兩者同名不同義,且本檔已驗證過序數,理論上不該收到
	# 池的這個回覆——落地此分支代表轉接器自己有 bug,由
	# _expose_unexpected_pool_rejection() 曝光並回傳一個非 INVALID_PAIR 的
	# 佔位訊號)
	assert_int(rejection).is_not_equal(AffinityWritePort.Rejection.INVALID_PAIR)


# ---- int -> float 的單一收斂點,對卡牌系統值域 {-3..-1, 1..3} 無精度損失 -----

func test_int_magnitude_widens_to_float_without_precision_loss() -> void:
	# Arrange
	var pool: AffinityDataPool = AffinityDataPool.new()
	var port: AffinityPoolWritePort = AffinityPoolWritePort.new(pool)
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2
	)

	# Act — 涵蓋 GDD Formula 三值域 {-3,-2,-1,+1,+2,+3} 的正負兩端
	port.append_record(1, 2, -3, AffinityWritePort.SOURCE_COMBAT_CARD)
	port.append_record(1, 2, 3, AffinityWritePort.SOURCE_COMBAT_CARD)

	# Assert
	var first: AffinityRecord = pool._records[pair].get_at(0)
	var second: AffinityRecord = pool._records[pair].get_at(1)
	assert_float(first.m).is_equal_approx(-3.0, 0.000000000001)
	assert_float(second.m).is_equal_approx(3.0, 0.000000000001)
