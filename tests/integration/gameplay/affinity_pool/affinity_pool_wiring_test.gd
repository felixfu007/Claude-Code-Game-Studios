# AffinityDataPool 生命週期接線的整合測試——
# production/epics/affinity-data-pool/story-009-wiring.md(S-009,依 2026-09-15
# 管理者裁決二併入 card-play-interface epic 的 U-003,見
# production/epics/card-play-interface/story-u003-battle-screen-deck-wiring.md
# 「合流點」節)。涵蓋原 S-009 的 AC-1(公開介面窮盡行為檢視)與端到端寫入/降級
# 路徑測試。
#
# 全鏈路(AffinityDataPool/AffinityTypes/AffinityRecord/AffinityRecordList/
# AffinityPoolWritePort/CardPlaySession/BattleController/BattleState/TurnOrder/
# Unit/CardDeck/Card/AffinityLink)都是 RefCounted 或不留孤兒節點的既有慣例
# （BattleState/BattleController 本身不建立任何 Node），不需要 tear-down。
#
# 🔴 本檔不修改 src/gameplay/affinity_pool/affinity_data_pool.gd —— 該檔本次
# session 由另一位專家處理中。AC-1 三條測試的敏感度證明因此改用本專案既有的
# 子類別注入手法（tests/integration/gameplay/cards/card_battle_wiring_test.gd
# 的 _SpyCardDeck、affinity_pool_write_port_test.gd 的 _AlwaysInvalidPairPool
# 先例），全部定義在本測試檔內部，不觸碰受保護的來源檔案。
#
# 🔴 本檔案 I/O 使用揭露（.claude/rules/test-standards.md「單元測試不得碰檔案
# 系統」節，2026-09-16 管理者裁決的甲/乙兩類明文例外——本檔為 Integration 型，
# 該節文字上雖以 unit test 為題，本檔仍主動比照其揭露義務，不主張自己在範圍外）:
#
#   甲類（讀 assets/data/ 底下已進版控的真實資料檔）—— _real_links() 讀
#   assets/data/affinity/vs01_affinity_links.txt，唯讀，不寫入任何檔案，沿用
#   affinity_pool_write_port_test.gd 既有同名手法的先例。理由同該檔:測真實
#   資料檔才抓得到「資料檔本身打錯字」這類錯，寫死假資料在測試裡測不到。
#
#   乙類（掃 src/**/*.gd 原始碼文字，斷言原始碼紀律）——
#   _method_names_from_source() 對 affinity_data_pool.gd 的原始碼文字做正規
#   表示式擷取，取代未經本專案驗證過的 Script.get_script_method_list() 反射
#   API（Godot 4.7 post-cutoff，見 docs/engine-reference/godot/VERSION.md）。
#   🔴 自陳範圍不窮盡：本掃描只抓「column-0 的 `func 名稱(`」這個文字形狀，
#   抓不到動態產生的方法、抓不到方法是否經由 `@abstract`/`virtual` 等修飾，
#   也無法證明「不存在其他讓外部觀察到副作用的管道」（例如 signal、直接讀寫
#   對外可見的 var 欄位）——這正是 test_known_public_method_list_matches_the_
#   real_source_file() 存在的理由:它只保證「本檔案已知的方法清單」與「原始碼
#   目前的方法清單」一致，一致本身不等於窮盡性成立,只是讓兩者不一致時可觀測。
extends GdUnitTestSuite


const _POOL_SOURCE_PATH: String = "res://src/gameplay/affinity_pool/affinity_data_pool.gd"
const _AFFINITY_LINKS_PATH: String = "res://assets/data/affinity/vs01_affinity_links.txt"

# 本切片（S-004~S-007）已交付的公開方法全集——S-012/S-013/S-014（can_write()/
# export_state()/import_state() 等）明文不在範圍內，見 affinity_data_pool.gd
# 檔頭「尚未在此檔出現、屬於後續 story 的東西」一節。
#
# 🔴 這份清單本身是硬編碼，理由很簡單：呼叫一個方法之前一定要知道它的參數簽章，
# 反射（reflection）繞不開這件事。AC-1 真正要求的「驗證方式為行為檢視,不依賴
# 方法命名」指的是下面判斷「誰是附加記錄的方法/誰是前進戰役刻度的方法」這件事
# 只看呼叫後的可觀測效果，不看名字本身是否叫 append_record；至於「要呼叫哪些
# 方法」這件事本來就無法不靠名字。test_known_public_method_list_matches_the_
# real_source_file() 是這份硬編碼清單的活性檢查——用正規表示式直接從原始碼文字
# 重新derive 一份方法名稱清單並比對，清單過期時這條測試會變紅，而不是靜默漏檢查
# 新方法。
#
# 🔴 刻意不使用 Script.get_script_method_list() 這個引擎反射 API——本專案從未
# 在任何既有測試裡驗證過這個 API 在 Godot 4.7.1 的行為，而 4.7 是本專案文件
# 明文的訓練資料截止後版本（docs/engine-reference/godot/VERSION.md）。改用
# RegEx 直接從原始碼文字擷取「func 名稱(」這個機械事實（不是重新實作任何遊戲
# 規則的計算，只是抓一個識別碼），風險遠低於信任一個沒驗證過的引擎 API。
const _KNOWN_PUBLIC_METHODS: Array[StringName] = [
	&"notify_death",
	&"t_death",
	&"advance_campaign_tick",
	&"append_record",
	&"combat_strength_read",
	&"narrative_depth_read",
	&"shape_feature_read",
	&"diagnostic_calibration_is_placeholder",
]


# ---- 間諜子類別（不修改 affinity_data_pool.gd 本體，僅用於證明下面三條 AC-1
# 測試的判斷邏輯真的會抓到違反 AC-1 的池，而不是巧合綠燈）----------------------

# 覆寫一個「應為純讀取」的方法，讓它額外悄悄 append 一筆記錄——模擬「未來有人
# 在讀取方法裡夾帶了寫入副作用」這個 AC-1 要擋下的具體錯誤。
class _SpyPoolAppendOnRead extends AffinityDataPool:
	func combat_strength_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> AffinityReadResult:
		append_record(AffinityTypes.Pair.C3_C4, 1.0, AffinityTypes.Source.COMBAT_CARD)
		return super.combat_strength_read(pair, t_query)


# 覆寫另一個「應為純讀取」的方法，讓它額外悄悄前進戰役刻度。
class _SpyPoolAdvanceOnRead extends AffinityDataPool:
	func narrative_depth_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> AffinityReadResult:
		advance_campaign_tick()
		return super.narrative_depth_read(pair, t_query)


# 覆寫 t_death()（陣亡標記查詢，不在 AC-1 的「記錄/標記」定義範圍內，但本身仍是
# 一個公開方法）讓它把某配對既有記錄的順序倒過來——不改變筆數，只改變順序，
# 用來證明下面第三條測試比對的是逐筆內容而非只比對 size()。
class _SpyPoolReorderingReads extends AffinityDataPool:
	func t_death(pair: AffinityTypes.Pair) -> Variant:
		var list: AffinityRecordList = _records[AffinityTypes.Pair.C1_C2]
		list._items.reverse()
		return super.t_death(pair)


# 2026-09-16 協調者裁決追加——為 test_playing_combat_card_end_to_end_writes_a_
# record_and_is_readable_back() 補的敏感度證明用間諜:覆寫 append_record() 讓
# 它偽稱「NONE(接受)」但完全不寫入任何記錄，模擬「寫入路徑某處把結果悄悄吞掉，
# 呼叫端卻以為成功了」這個端到端測試存在的理由——AC-1 的三條測試只掃描
# AffinityDataPool 自己「一個乾淨物件上」的方法清單，抓不到這種「回報成功但沒有
# 真的做」的錯誤，只有端到端才看得到。
class _SpyPoolSilentlyDropsWrites extends AffinityDataPool:
	func append_record(_pair: AffinityTypes.Pair, _m: float, _source: AffinityTypes.Source) -> WriteRejection:
		return WriteRejection.NONE


# 2026-09-16 協調者裁決追加——為 test_null_write_port_fallback_path_still_
# works_when_no_pool_is_supplied() 補的敏感度證明用間諜:偽裝成一個「本該像
# NullAffinityWritePort 一樣恆拒絕，卻悄悄放行」的埠。⚠️ 這裡刻意【顯式傳入】
# 這個間諜（不是省略 write_port 讓 BattleController 自己代入
# NullAffinityWritePort）——battle_controller.gd 本身的「省略時代入
# NullAffinityWritePort」那段程式碼是既有程式碼、本輪不得修改也無法注入，這條
# 間諜證明的是「下面那條測試的斷言（confirmed == false、deck 沒有變化）確實會
# 分辨埠的行為，而不是巧合通過」，不是證明 BattleController 的內部代入邏輯本身。
class _SpyWritePortAlwaysAccepts extends AffinityWritePort:
	func append_record(_character_a: int, _character_b: int, _m: int, _source: StringName) -> Rejection:
		return Rejection.NONE


# ---- 共用 fixture / helper ---------------------------------------------------

static func _total_records(pool: AffinityDataPool) -> int:
	var total: int = 0
	for pair: AffinityTypes.Pair in AffinityTypes.Pair.values():
		total += pool._records[pair].size()
	return total


# 每一對配對逐筆記錄的 (pair, m, t, c, source) 快照——不只比對筆數，重排也會
# 被抓到（見 _SpyPoolReorderingReads 的敏感度證明）。
static func _records_snapshot(pool: AffinityDataPool) -> Array:
	var snapshot: Array = []
	for pair: AffinityTypes.Pair in AffinityTypes.Pair.values():
		var list: AffinityRecordList = pool._records[pair]
		var one_pair: Array = []
		for i: int in range(list.size()):
			var r: AffinityRecord = list.get_at(i)
			one_pair.append([r.pair, r.m, r.t, r.c, r.source])
		snapshot.append(one_pair)
	return snapshot


func _pool_with_two_records_same_pair() -> AffinityDataPool:
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool.append_record(AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.COMBAT_CARD)
	pool.append_record(AffinityTypes.Pair.C1_C2, 2.0, AffinityTypes.Source.COMBAT_CARD)
	return pool


# 唯一知道每個公開方法簽章的地方（見 _KNOWN_PUBLIC_METHODS 的文件註解）。判斷
# PASS/FAIL 的邏輯本身（下面三條 test_public_method_inventory_* / test_no_
# other_*）從不檢查方法名稱字面上是不是叫 append_record/advance_campaign_tick，
# 只檢查呼叫後的可觀測效果——這才是 AC-1「不依賴方法命名」的實際落點。
func _call_public_method(pool: AffinityDataPool, method_name: StringName) -> void:
	match method_name:
		&"notify_death":
			pool.notify_death(AffinityTypes.Character.CHARACTER_3)
		&"t_death":
			pool.t_death(AffinityTypes.Pair.C1_C2)
		&"advance_campaign_tick":
			pool.advance_campaign_tick()
		&"append_record":
			pool.append_record(AffinityTypes.Pair.C3_C4, 1.0, AffinityTypes.Source.COMBAT_CARD)
		&"combat_strength_read":
			pool.combat_strength_read(AffinityTypes.Pair.C1_C2)
		&"narrative_depth_read":
			pool.narrative_depth_read(AffinityTypes.Pair.C1_C2)
		&"shape_feature_read":
			pool.shape_feature_read(AffinityTypes.Pair.C1_C2)
		&"diagnostic_calibration_is_placeholder":
			pool.diagnostic_calibration_is_placeholder()
		_:
			fail(
				(
					"_call_public_method: encountered a public method '%s' this test's call " +
					"table does not know how to invoke. Update _KNOWN_PUBLIC_METHODS and this " +
					"match above before trusting any AC-1 result in this file (Story U-003 " +
					"Implementation Notes #7 — re-run this exhaustive check whenever the " +
					"pool's public surface changes)."
				) % method_name
			)


func _appending_methods(make_pool: Callable) -> Array[StringName]:
	var appenders: Array[StringName] = []
	for name: StringName in _KNOWN_PUBLIC_METHODS:
		var pool: AffinityDataPool = make_pool.call()
		var before: int = _total_records(pool)
		_call_public_method(pool, name)
		var after: int = _total_records(pool)
		if after > before:
			appenders.append(name)
	return appenders


func _advancing_methods(make_pool: Callable) -> Array[StringName]:
	var advancers: Array[StringName] = []
	for name: StringName in _KNOWN_PUBLIC_METHODS:
		var pool: AffinityDataPool = make_pool.call()
		var before: int = pool._campaign_tick_marks.size()
		_call_public_method(pool, name)
		var after: int = pool._campaign_tick_marks.size()
		if after > before:
			advancers.append(name)
	return advancers


func _mutation_violators(make_pool: Callable) -> Array[StringName]:
	var violators: Array[StringName] = []
	for name: StringName in _KNOWN_PUBLIC_METHODS:
		if name == &"append_record" or name == &"advance_campaign_tick":
			continue  # 這兩個是唯一允許改變兩個結構的方法，由上面兩條測試涵蓋
		var pool: AffinityDataPool = make_pool.call()
		var records_before: Array = _records_snapshot(pool)
		var marks_before: Array = pool._campaign_tick_marks.duplicate()

		_call_public_method(pool, name)

		var records_after: Array = _records_snapshot(pool)
		var marks_after: Array = pool._campaign_tick_marks.duplicate()

		if records_after != records_before or marks_after != marks_before:
			violators.append(name)
	return violators


func _real_links() -> Array[AffinityLink]:
	var text: String = FileAccess.get_file_as_string(_AFFINITY_LINKS_PATH)
	var parsed: Variant = AffinityLink.links_from_text(text)
	if parsed == null:
		fail(
			(
				"_real_links(): AffinityLink.links_from_text() returned null while parsing " +
				"%s — the real, version-controlled affinity data file failed to parse."
			) % _AFFINITY_LINKS_PATH
		)
		return []
	return parsed


# ---- 活性檢查：硬編碼清單是否仍與真實原始碼一致 --------------------------------
#
# 🔴 刻意放在檔案最後宣告，不是第一條——2026-09-16 實測發現的排序後果:GdUnit4
# 一條測試失敗會中止「同一個檔案」後面所有測試（.claude/docs/coding-standards.md
# 已登記的既有陷阱）。這條測試斷言的是「本檔其餘測試賴以成立的方法清單，此刻
# 是否仍與原始碼一致」——若它宣告在檔案開頭且原始碼剛好在別處被修改（例如另一
# 個人正在新增公開方法），一條完全不相干的活性檢查就會讓下面全部 AC-1 測試
# 一條都跑不到，讀者因此拿到「全部沒跑」而不是「這幾條仍然成立、只有清單過期」
# 這個更精確的資訊。放在最後：即使它紅了，上面每一條測試各自的 PASS/FAIL 都已
# 經是真實結果，不會被這條清單過期的事實連坐。

## [param source_override] 為 2026-09-16 協調者裁決追加，僅供下面的敏感度證明
## 測試使用——省略時（本檔其餘呼叫端一律省略）行為與新增前完全相同：讀真實的
## affinity_data_pool.gd 原始碼文字。不改變、不影響 test_known_public_method_
## list_matches_the_real_source_file() 本身讀的是不是真實檔案。
func _method_names_from_source(source_override: String = "") -> Array[StringName]:
	var source: String = (
		source_override if not source_override.is_empty()
		else FileAccess.get_file_as_string(_POOL_SOURCE_PATH)
	)
	var regex: RegEx = RegEx.new()
	regex.compile("(?m)^func ([a-zA-Z_][a-zA-Z0-9_]*)\\(")
	var names: Array[StringName] = []
	for m: RegExMatch in regex.search_all(source):
		var method_name: String = m.get_string(1)
		if not method_name.begins_with("_"):
			names.append(StringName(method_name))
	return names


# ---- AC-1 之一：恰有一個附加記錄的方法 ---------------------------------------

func test_public_method_inventory_has_exactly_one_record_appending_method() -> void:
	var appenders: Array[StringName] = _appending_methods(
		func() -> AffinityDataPool: return AffinityDataPool.new()
	)
	assert_array(appenders).is_equal([&"append_record"])


# 敏感度證明——已注入驗證過會紅（構造上就是一個違反 AC-1 的池）。
func test_sensitivity_proof_appender_count_test_catches_a_read_method_with_a_write_side_effect() -> void:
	var appenders: Array[StringName] = _appending_methods(
		func() -> AffinityDataPool: return _SpyPoolAppendOnRead.new()
	)
	assert_int(appenders.size()).is_equal(2)
	assert_bool(appenders.has(&"append_record")).is_true()
	assert_bool(appenders.has(&"combat_strength_read")).is_true()


# ---- AC-1 之二：恰有一個前進戰役刻度的方法 -----------------------------------

func test_public_method_inventory_has_exactly_one_campaign_tick_advancing_method() -> void:
	var advancers: Array[StringName] = _advancing_methods(
		func() -> AffinityDataPool: return AffinityDataPool.new()
	)
	assert_array(advancers).is_equal([&"advance_campaign_tick"])


# 敏感度證明——已注入驗證過會紅。
func test_sensitivity_proof_advancer_count_test_catches_a_read_method_with_a_tick_side_effect() -> void:
	var advancers: Array[StringName] = _advancing_methods(
		func() -> AffinityDataPool: return _SpyPoolAdvanceOnRead.new()
	)
	assert_int(advancers.size()).is_equal(2)
	assert_bool(advancers.has(&"advance_campaign_tick")).is_true()
	assert_bool(advancers.has(&"narrative_depth_read")).is_true()


# ---- AC-1 之三：其餘方法不得刪除/修改/清空/重排既有記錄或標記 -----------------

func test_no_other_public_method_deletes_modifies_clears_or_reorders_records_or_marks() -> void:
	var violators: Array[StringName] = _mutation_violators(
		func() -> AffinityDataPool: return _pool_with_two_records_same_pair()
	)
	assert_array(violators).is_empty()


# 敏感度證明——已注入驗證過會紅（重排、非增減筆數，證明比對邏輯看的是逐筆內容
# 而非只看 size()）。
#
# 🔴 2026-09-16 S-007 交件後更新（技術總監根因分析轉錄）：本測試原本斷言只有
# 直接被覆寫的 t_death() 會被判定為違規方法，期望值曾是 [&"t_death"]。S-007
# 之前 combat_strength_read()/narrative_depth_read() 從未呼叫 t_death()（S-006
# 階段的佔位空殼）；S-007 依 GDD Core Rules #3 正確地讓兩者透過
# _resolve_effective_t_query() 呼叫 t_death()（t_query 省略時的條件式預設查詢
# 時點）。對本檔的 _SpyPoolReorderingReads 呼叫這兩個函式，因此也會觸發同一個
# 被覆寫的 t_death() 副作用——偵測器如實回報三個名字，不是舊期望值的一個。
# 這是「正確實作規格造成的預期後果」，不是本測試邏輯的缺陷，也不是 S-007 的
# 缺陷：更新期望值本身就是在證明偵測器仍然精準，不是放寬它的偵測能力
# （shape_feature_read 不呼叫 t_death()——見該方法文件註解「不受陣亡凍結規則
# 影響」——因此不在這份清單內，這一點本身也是偵測器精準度的佐證）。
func test_sensitivity_proof_no_other_mutator_test_catches_a_read_method_that_reorders_records() -> void:
	var violators: Array[StringName] = _mutation_violators(
		func() -> AffinityDataPool:
			var p: _SpyPoolReorderingReads = _SpyPoolReorderingReads.new()
			p.append_record(AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.COMBAT_CARD)
			p.append_record(AffinityTypes.Pair.C1_C2, 2.0, AffinityTypes.Source.COMBAT_CARD)
			return p
	)
	assert_array(violators).is_equal([&"t_death", &"combat_strength_read", &"narrative_depth_read"])


# ---- 端到端：打一張丙類卡 -> 池新增一筆記錄 -> 讀得回來 ------------------------
#
# 🔴 誠實揭露：AffinityDataPool 三個公開加權讀取函數（combat_strength_read 等）
# 截至本檔撰寫時仍只回傳佔位中性值（見 affinity_data_pool.gd 檔頭「尚未在此檔
# 出現、屬於後續 story 的東西」——S-007 的真正加權計算邏輯尚未落地），無論池裡
# 有沒有記錄都一律回傳 value=0.0、n_pair=0。「讀得回來」因此驗證的是記錄本身
# 確實被附加、且欄位正確（沿用 affinity_pool_write_port_test.gd 既有測試的
# 讀回手法：直接讀 pool._records），不是呼叫公開讀取函數拿到有意義的加權值——
# 那條驗收要等 S-007 真正落地才成立，本測試不對此做任何宣稱。
func test_playing_combat_card_end_to_end_writes_a_record_and_is_readable_back() -> void:
	# Arrange — 與 battle_screen.gd _ready() 呼叫 BattleController.new() 完全
	# 相同的形狀（card_deck、affinity_links、write_port 皆非預設值），只是資料
	# 由本測試自建，不經場景樹（Story U-003 Implementation Notes #9：
	# card_play_session_test.gd 既有整合測試風格）。
	var roster_lines: Array[String] = [
		"1,P1,PLAYER,20,5,3,0,1,1,0,0",
		"2,P2,PLAYER,20,5,3,0,1,1,1,0",
		"6,E1,ENEMY,20,5,3,0,1,1,12,5",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new([1, 2], [6])
	var card: Card = Card.new_permanent_affinity_write("wiring_e2e_card", 1, 2, 2)
	var deck: CardDeck = CardDeck.new([card])
	var links: Array[AffinityLink] = _real_links()
	var pool: AffinityDataPool = AffinityDataPool.new()
	var write_port: AffinityPoolWritePort = AffinityPoolWritePort.new(pool)
	var controller: BattleController = BattleController.new(
		state, order, Callable(), Callable(), deck, links, write_port
	)

	# Act
	assert_bool(controller.open_hand()).is_true()
	assert_bool(controller.select_card(card)).is_true()
	assert_array(controller.legal_targets()).contains([1, 2])
	assert_bool(controller.select_target(1)).is_true()
	assert_bool(controller.select_second_target(2)).is_true()
	var confirmed: bool = controller.confirm()

	# Assert
	assert_bool(confirmed).is_true()
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2
	)
	assert_int(pool._records[pair].size()).is_equal(1)
	var record: AffinityRecord = pool._records[pair].get_at(0)
	assert_int(record.pair).is_equal(pair)
	assert_float(record.m).is_equal_approx(2.0, 0.000000000001)
	assert_int(record.source).is_equal(AffinityTypes.Source.COMBAT_CARD)
	assert_int(deck.used_size()).is_equal(1)  # 卡片確實移到已用區

	# 🔴 技術總監 2026-09-16 裁決的一部分（六個校準旋鈕，AffinityCalibration）——
	# 這是「會執行的檢查」，不是紀律要求：本斷言今天是綠的（AffinityDataPool.new()
	# 未傳 calibration 時退回 AffinityCalibration.uncalibrated_placeholder()）。
	# 等六個校準旋鈕真的被校準的那天，battle_screen.gd 必須改傳一個真正校準過的
	# AffinityCalibration 給 AffinityDataPool.new()，屆時這條斷言會變紅——這是
	# 刻意設計，逼出一次有意識的編輯，不是本測試壞了。看到它變紅時，去改
	# battle_screen.gd 傳入真正的校準值，而不是把這條斷言直接改成 is_false()。
	# 本專案已有「刻意留紅且經核准」的前例（affinity_phi_provider_test.gd 的
	# 已核准紅燈）；這條是「刻意留綠、變紅即代表義務未了」的反向版本。
	assert_bool(pool.diagnostic_calibration_is_placeholder()).is_true()


# 敏感度證明(2026-09-16 協調者裁決追加)——見 _SpyPoolSilentlyDropsWrites 的
# 文件註解。用一個「偽稱成功但完全不寫入」的池重跑同一套端到端流程，證明上面
# 那條測試 pool._records[pair].size() == 1 的斷言確實在做工:confirm() 仍然
# 回傳 true(卡片一樣被判定為合法打出),但記錄筆數維持 0——這正是若真實
# AffinityPoolWritePort/AffinityDataPool 的寫入路徑哪天真的悄悄失效時,上面那
# 條測試會抓到的樣子,不是巧合綠燈。
func test_sensitivity_proof_end_to_end_test_catches_a_pool_that_silently_drops_writes() -> void:
	# Arrange — 與上面的端到端測試完全同型,只把 pool 換成間諜
	var roster_lines: Array[String] = [
		"1,P1,PLAYER,20,5,3,0,1,1,0,0",
		"2,P2,PLAYER,20,5,3,0,1,1,1,0",
		"6,E1,ENEMY,20,5,3,0,1,1,12,5",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new([1, 2], [6])
	var card: Card = Card.new_permanent_affinity_write("wiring_sensitivity_card", 1, 2, 2)
	var deck: CardDeck = CardDeck.new([card])
	var links: Array[AffinityLink] = _real_links()
	var spy_pool: _SpyPoolSilentlyDropsWrites = _SpyPoolSilentlyDropsWrites.new()
	var write_port: AffinityPoolWritePort = AffinityPoolWritePort.new(spy_pool)
	var controller: BattleController = BattleController.new(
		state, order, Callable(), Callable(), deck, links, write_port
	)

	# Act
	assert_bool(controller.open_hand()).is_true()
	assert_bool(controller.select_card(card)).is_true()
	assert_bool(controller.select_target(1)).is_true()
	assert_bool(controller.select_second_target(2)).is_true()
	var confirmed: bool = controller.confirm()

	# Assert — 間諜讓 confirm() 看起來仍然成功(這正是為何光看 confirmed==true
	# 不足以當作「有寫入」的證據),但記錄筆數維持 0——真正的端到端測試量的是
	# 這件事,不是 confirmed 本身
	assert_bool(confirmed).is_true()
	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
		AffinityTypes.Character.CHARACTER_1, AffinityTypes.Character.CHARACTER_2
	)
	assert_int(spy_pool._records[pair].size()).is_equal(0)


# ---- 既有降級路徑（NullAffinityWritePort）在真實接線之後仍然有效 --------------
#
# story-009-wiring.md Implementation Notes #4 / Test Evidence 明文要求：本 story
# 只確保「有池的情境」用真實轉接器，不強制每場戰鬥都有池——write_port 省略時
# BattleController._init() 既有的 NullAffinityWritePort 降級必須維持不變。這條
# 測試的對象是 battle_controller.gd 既有程式碼（本 story 未修改該檔），驗證的是
# 「本次改動沒有破壞這條既有路徑」。
func test_null_write_port_fallback_path_still_works_when_no_pool_is_supplied() -> void:
	# Arrange — write_port 留預設值 null
	var roster_lines: Array[String] = [
		"1,P1,PLAYER,20,5,3,0,1,1,0,0",
		"2,P2,PLAYER,20,5,3,0,1,1,1,0",
		"6,E1,ENEMY,20,5,3,0,1,1,12,5",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new([1, 2], [6])
	var card: Card = Card.new_permanent_affinity_write("wiring_fallback_card", 1, 2, 2)
	var deck: CardDeck = CardDeck.new([card])
	var links: Array[AffinityLink] = _real_links()
	var controller: BattleController = BattleController.new(
		state, order, Callable(), Callable(), deck, links
	)

	# Act
	assert_bool(controller.open_hand()).is_true()
	assert_bool(controller.select_card(card)).is_true()
	assert_bool(controller.select_target(1)).is_true()
	assert_bool(controller.select_second_target(2)).is_true()
	var confirmed: bool = controller.confirm()

	# Assert — NullAffinityWritePort 恆拒絕，confirm() 因此回傳 false、
	# 卡片沒有被移到已用區、session 停在原地不崩潰
	assert_bool(confirmed).is_false()
	assert_int(deck.used_size()).is_equal(0)
	assert_bool(deck.hand().has(card)).is_true()


# 敏感度證明(2026-09-16 協調者裁決追加)——見 _SpyWritePortAlwaysAccepts 的
# 文件註解。🔴 誠實揭露這條證明了什麼、沒證明什麼:battle_controller.gd 裡
# 「write_port 省略時代入 NullAffinityWritePort」那段程式碼本身是既有程式碼、
# 本輪不得修改，因此無法對那段程式碼本身注入錯誤。這條測試改為【顯式傳入】
# 一個偽裝成 NullAffinityWritePort、卻悄悄放行一切的間諜，證明上面那條測試賴
# 以判斷「降級路徑仍然拒絕」的三個斷言(confirmed==false、used_size()==0、
# hand().has(card)==true)確實會分辨埠的行為——換一個放行的埠，結果精確地
# 反過來。這證明的是「斷言本身有分辨力」，不是「NullAffinityWritePort 的
# 內部代入邏輯今天沒壞」——後者這輪結構上驗不到，如實記錄。
func test_sensitivity_proof_null_write_port_fallback_test_would_catch_a_wrongly_permissive_substitute() -> void:
	# Arrange — 與上面幾乎同型，唯一差異是顯式傳入間諜埠（不是省略讓
	# BattleController 自己代入 NullAffinityWritePort）
	var roster_lines: Array[String] = [
		"1,P1,PLAYER,20,5,3,0,1,1,0,0",
		"2,P2,PLAYER,20,5,3,0,1,1,1,0",
		"6,E1,ENEMY,20,5,3,0,1,1,12,5",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new([1, 2], [6])
	var card: Card = Card.new_permanent_affinity_write("wiring_fallback_sensitivity_card", 1, 2, 2)
	var deck: CardDeck = CardDeck.new([card])
	var links: Array[AffinityLink] = _real_links()
	var spy_port: _SpyWritePortAlwaysAccepts = _SpyWritePortAlwaysAccepts.new()
	var controller: BattleController = BattleController.new(
		state, order, Callable(), Callable(), deck, links, spy_port
	)

	# Act
	assert_bool(controller.open_hand()).is_true()
	assert_bool(controller.select_card(card)).is_true()
	assert_bool(controller.select_target(1)).is_true()
	assert_bool(controller.select_second_target(2)).is_true()
	var confirmed: bool = controller.confirm()

	# Assert — 換成錯誤放行的埠後，三個結果精確地與上面那條測試相反：確認、
	# 已用區有一張、手牌不再持有這張卡
	assert_bool(confirmed).is_true()
	assert_int(deck.used_size()).is_equal(1)
	assert_bool(deck.hand().has(card)).is_false()


# 敏感度證明(2026-09-16 協調者裁決追加)——證明下面 test_known_public_method_
# list_matches_the_real_source_file() 賴以判斷「清單過期」的比對邏輯，真的會
# 在清單與原始碼不一致時抓到，而不是巧合綠燈。用 _method_names_from_source()
# 的 source_override 參數餵一段【手寫、不讀任何真實檔案】的假原始碼文字，模擬
# 「_KNOWN_PUBLIC_METHODS 少了一個新方法」這個真正會發生的情境。
#
# ⚠️ 這條測試不受「活性檢查必須放檔案最後一條」那條規則約束——它比對的兩邊都
# 是本測試自己建構的常數（假原始碼字串 + 手寫的期望清單），不依賴真實原始碼
# 檔案此刻的狀態，因此即使原始碼真的在別處被修改，這條測試的 PASS/FAIL 也不
# 會受影響，可以放在檔案中段。
func test_sensitivity_proof_source_method_scan_catches_a_known_list_missing_a_new_method() -> void:
	# Arrange — 假原始碼比真實的 _KNOWN_PUBLIC_METHODS 多一個從未被登記過的
	# 公開方法（模擬「有人加了新方法，忘記更新清單」），並混入一個底線開頭的
	# 私有方法與一段刻意縮排的行，用來確認正規表示式的 column-0 錨點與「排除
	# 底線開頭」這兩條規則本身也一起被驗證到，不是只驗證到「數量對不上」。
	var fake_source: String = (
		"func append_record(pair, m, source) -> void:\n" +
		"\tpass\n" +
		"func _private_helper() -> void:\n" +
		"\tpass\n" +
		"\tfunc nested_indented_not_top_level() -> void:\n" +
		"\t\tpass\n" +
		"func advance_campaign_tick() -> void:\n" +
		"\tpass\n" +
		"func brand_new_public_method_nobody_registered_yet() -> void:\n" +
		"\tpass\n"
	)
	var known: Array = [&"append_record", &"advance_campaign_tick"]  # 故意缺一項
	known.sort()

	# Act
	var from_fake_source: Array = _method_names_from_source(fake_source)
	from_fake_source.sort()

	# Assert — 兩邊不相等,證明清單過期這件事會被本檔的比對邏輯抓到；同時
	# 順便鎖住「私有方法與縮排行不會被誤判為新增公開方法」這個既有假設
	assert_array(from_fake_source).is_not_equal(known)
	var expected: Array = [
		&"append_record", &"advance_campaign_tick", &"brand_new_public_method_nobody_registered_yet"
	]
	expected.sort()
	assert_array(from_fake_source).is_equal(expected)


# 見上方 "---- 活性檢查 ----" 節的文件註解，說明為何刻意放在檔案最後一條。
func test_known_public_method_list_matches_the_real_source_file() -> void:
	# Arrange / Act
	var from_source: Array = _method_names_from_source()
	from_source.sort()
	var known: Array = _KNOWN_PUBLIC_METHODS.duplicate()
	known.sort()

	# Assert — 若這條紅了，代表 _KNOWN_PUBLIC_METHODS（因此上面全部 AC-1 測試賴
	# 以呼叫的方法清單）已經跟不上池的真實公開介面，必須先更新這份清單與
	# _call_public_method()，而不是相信舊清單得出的結論。這條測試自己變紅，
	# 不代表上面任何一條測試的 PASS/FAIL 結果本身是錯的——見本檔活性檢查節。
	assert_array(from_source).is_equal(known)
