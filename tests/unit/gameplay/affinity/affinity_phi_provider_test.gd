# AffinityPhiProvider（src/gameplay/affinity/affinity_phi_provider.gd）的單元測試。
#
# 這個類別是滿足 BattleController 建構子 phi_provider: Callable 契約
# （func(attacker_id: int, target_id: int) -> int）的介接物件：把 BattleState
# 的即時位置餵給 AffinityRules 的純函式數學。本檔前五支測試各自獨立驗證
# positions()/positions_with()/phi() 這三個公開方法的個別行為；最後一支是
# 規格書點名「本檔最重要的一支」的整合測試——真的組出一個 BattleController，
# 證明 Φ 從「布線但沒人接」變成「真的會改變傷害數字」，不然前面每一支測試
# 全過也可能是這條線根本沒接上。
#
# 全鏈路（BattleState/BattleController/TurnOrder/AffinityRules/AffinityLink）
# 都是 RefCounted 或 static，不建立任何 Node，不需要 tear-down，不會留下孤兒
# 節點。每個測試自建 roster/links 字串，不共用可變狀態，因此不依賴執行順序。
# 命名慣例沿用既有先例 test_[scenario]_[expected]（見
# affinity_rules_test.gd／battle_controller_threat_test.gd）。
extends GdUnitTestSuite

const VS01_ROSTER_PATH: String = "res://assets/data/units/vs01_roster.txt"
const VS01_LINKS_PATH: String = "res://assets/data/affinity/vs01_affinity_links.txt"

# 純粹用來合成一條正關係配對表的資料列字串，不是本作的真實人際關係
# （真實關係只在 affinity_link_test.gd／test 2、6 用到的 vs01 真實檔案裡斷言）。
const LINK_1_2_POSITIVE: String = "1,2,POSITIVE,1"

# 跟 LINK_1_2_POSITIVE 同一對單位、同一個 amp，只把 polarity 反過來，用來合成
# 「這一對關係被翻轉之後」的配對表——見 test_phi_reflects_a_pairing_polarity_flip_made_after_construction。
const LINK_1_2_NEGATIVE: String = "1,2,NEGATIVE,1"


func _links(text: String) -> Array[AffinityLink]:
	return AffinityLink.links_from_text(text)


# ---- (1) phi()：回報攻擊者當下的好感度加成 ---------------------------------

func test_phi_returns_attackers_current_affinity_bonus() -> void:
	# Arrange — 單位 1、2 正關係，相距 1 格 → +3；target_id 對 phi() 的計算
	# 無影響，故隨便給一個不存在的 id 也不該出錯。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,P2,PLAYER,20,10,0,0,1,1,1,0",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var links: Array[AffinityLink] = _links(LINK_1_2_POSITIVE)
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, links)

	# Act / Assert
	assert_int(provider.phi(1, 999)).is_equal(3)


# ---- (2) phi()：無配對的單位恆回傳 0（用真實 vs01 資料）----------------------

func test_phi_returns_zero_for_unit_with_no_links_vs01_unit_five() -> void:
	# Arrange — 戊（單位 5）在真實配對表裡刻意沒有任何線
	# （affinity_link_test.gd 的 test_links_from_text_vs01_file_gives_unit_five_no_links
	# 已經在「配對表本身」這一層釘死這個事實；這支測試釘的是「介接物件」這一層——
	# 兩層都要有，因為介接物件理論上可能在轉手 links 時搞錯順序或漏傳）。
	var roster_text: String = FileAccess.get_file_as_string(VS01_ROSTER_PATH)
	var links_text: String = FileAccess.get_file_as_string(VS01_LINKS_PATH)
	var state: BattleState = BattleState.create(PackedStringArray(), roster_text)
	var links: Array[AffinityLink] = _links(links_text)
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, links)

	# Act / Assert
	assert_int(provider.phi(5, 1)).is_equal(0)


# ---- (3) positions()：陣亡單位不出現 -----------------------------------------

func test_positions_omits_a_unit_that_has_died() -> void:
	# Arrange — 單位 2 hp=5，扛不住單位 1 的 10 點傷害，一擊陣亡
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,E1,ENEMY,5,10,0,0,1,1,1,0",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, [] as Array[AffinityLink])

	# Act
	var dealt: int = state.resolve_attack(1, 2, 0)
	assert_int(dealt).is_equal(10)
	assert_bool(state.unit_by_id(2).is_alive()).is_false()
	var positions: Dictionary[int, Vector2i] = provider.positions()

	# Assert — 陣亡單位從快照消失，存活單位仍在
	assert_bool(positions.has(2)).is_false()
	assert_bool(positions.has(1)).is_true()


# ---- (4) positions()：反快取測試（本檔除整合測試外最重要的一支）--------------

func test_positions_reflects_a_move_made_after_construction() -> void:
	# Arrange — provider 在單位還沒移動前就已經建構完成
	var roster: Array[String] = ["1,P1,PLAYER,20,10,0,3,1,1,0,0"]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, [] as Array[AffinityLink])

	# Act — provider 建構完成之後才移動；如果 positions() 有快取，這裡不會反映
	assert_bool(state.move_unit(1, Vector2i(3, 0))).is_true()
	var positions: Dictionary[int, Vector2i] = provider.positions()

	# Assert — 必須是移動後的新位置，不是建構當下的 (0,0)
	assert_int(positions[1].x).is_equal(3)
	assert_int(positions[1].y).is_equal(0)


# ---- (5) positions_with()：只搬動指定單位，其餘不動 --------------------------

func test_positions_with_relocates_only_the_named_unit() -> void:
	# Arrange
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,P2,PLAYER,20,10,0,0,1,1,2,0",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, [] as Array[AffinityLink])
	var hypothetical_origin: Vector2i = Vector2i(5, 5)

	# Act
	var hypothetical: Dictionary[int, Vector2i] = provider.positions_with(1, hypothetical_origin)
	var real: Dictionary[int, Vector2i] = provider.positions()

	# Assert — 單位 1 被搬到假設格，單位 2 的真實位置完全不受影響
	assert_int(hypothetical[1].x).is_equal(5)
	assert_int(hypothetical[1].y).is_equal(5)
	assert_int(hypothetical[2].x).is_equal(real[2].x)
	assert_int(hypothetical[2].y).is_equal(real[2].y)
	# 未受影響的呼叫端 positions() 快照也不該被 positions_with() 污染
	assert_int(real[1].x).is_equal(0)
	assert_int(real[1].y).is_equal(0)


# ---- (6) 整合測試：Φ 真的會改變 BattleController 算出來的傷害 -----------------

func test_battle_controller_attack_damage_reflects_positive_link_phi_bonus_and_exceeds_no_provider_case() -> void:
	# Arrange — 單位 1（攻擊者，atk10/def0/range1）與單位 2（正關係夥伴）
	# 相距 1 格 → Φ = +3；單位 3（敵方目標，def0，hp 夠高不會死）與單位 1
	# 相距 1 格，射程內。前五支測試就算全過，也可能只是證明了「這個類別本身
	# 沒寫錯」，不代表它真的接進了 BattleController——這支測試才是唯一直接
	# 驗證「接上之後傷害數字真的變了」的地方。
	const ATK: int = 10
	const DEF: int = 0
	const EXPECTED_PHI: int = 3  # delta(POSITIVE, distance=1, amp=1)
	var roster: Array[String] = [
		"1,P1,PLAYER,20,%d,0,0,1,1,0,0" % ATK,
		"2,P2,PLAYER,20,10,0,0,1,1,1,0",
		"3,E1,ENEMY,500,0,%d,0,1,1,0,1" % DEF,
	]
	var roster_text: String = "\n".join(roster)
	var links: Array[AffinityLink] = _links(LINK_1_2_POSITIVE)

	# Act — 附 Φ 供應器的一組
	var state_with_phi: BattleState = BattleState.create(PackedStringArray(), roster_text)
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state_with_phi, links)
	var order_with_phi: TurnOrder = TurnOrder.new([1, 2], [3])
	var controller_with_phi: BattleController = BattleController.new(
		state_with_phi, order_with_phi, Callable(provider, "phi")
	)
	assert_bool(controller_with_phi.select_unit(1)).is_true()
	var result_with_phi: Dictionary = controller_with_phi.click_tile(Vector2i(0, 1))

	# Act — 沒有供應器的對照組（同一份 roster，重新建一整套全新狀態）
	var state_no_phi: BattleState = BattleState.create(PackedStringArray(), roster_text)
	var order_no_phi: TurnOrder = TurnOrder.new([1, 2], [3])
	var controller_no_phi: BattleController = BattleController.new(state_no_phi, order_no_phi)
	assert_bool(controller_no_phi.select_unit(1)).is_true()
	var result_no_phi: Dictionary = controller_no_phi.click_tile(Vector2i(0, 1))

	# Assert — 具體數字：atk=10 def=0 Φ=3 → 13；atk=10 def=0 Φ=0 → 10
	assert_int(EXPECTED_PHI).is_not_equal(0)
	assert_int(result_with_phi["damage"]).is_equal(CombatRules.damage(ATK, DEF, EXPECTED_PHI))
	assert_int(result_with_phi["damage"]).is_equal(13)
	assert_int(result_no_phi["damage"]).is_equal(CombatRules.damage(ATK, DEF, 0))
	assert_int(result_no_phi["damage"]).is_equal(10)
	assert_int(result_with_phi["damage"]).is_greater(result_no_phi["damage"])


# ---- (7) phi()：配對資料的逐查詢義務（反快取測試——registry 契約
# affinity_pairing_data_per_query_refetch，本檔目前唯一一支預期會 FAIL 的測試）--

# 這支測試釘的是 docs/registry/architecture.yaml 的 interface contract
# affinity_pairing_data_per_query_refetch：配對資料（polarity/strength）必須
# 跟 positions() 同一個新鮮度等級——每一次 phi() 查詢都要重新取得，不能只在
# 建構當下讀一次就固定終身。來源是 design/gdd/affinity-position-chain.md
# Interactions①與 States-and-Transitions：一張中途翻轉某對關係極性的對話卡牌，
# 效果必須在下一次 phi() 查詢就看得到，不必等 provider 被重新建構。
#
# ⚠️ 這支測試預期在目前實作下會 FAIL，而且這是刻意的、已核准的結果——不是
# 測試寫錯，缺陷是真的、還沒修。affinity_phi_provider.gd 的 _links 只在
# _init() 賦值一次，它自己的文件註解就寫著「fixed for the provider's
# lifetime」；phi() 讀的是這個凍結欄位，不會重新查詢，跟 positions() 每次呼叫
# 都重新從 _state 讀不對稱（registry 該筆 notes 的實測紀錄）。
#
# 為什麼「翻轉」要用重新指派本地變數到一份全新配對表、而不是直接改寫傳給
# provider 建構子的那個陣列裡的物件的 polarity 欄位：後者今天就會「看似通
# 過」——GDScript 的 Array 是傳參考（已在本次調查用 array_ref_check.gd 對照組
# 實測驗證：原地修改陣列元素的欄位，透過另一個持有同一份陣列的變數立刻可見），
# provider._links 跟呼叫端手上的陣列是同一份資料，直接改欄位會「意外」穿透，
# 但那穿透的是語言本身的參考語意，不是 provider 有重新查詢的邏輯。真正對應
# 「配對資料來源在建構之後被替換成新的一份」（未來 AffinityDataPool 每次查詢
# 都會回傳的東西，而不是呼叫端手上還留著的同一個物件）的重現方式，是把本地
# 變數重新指派成一份全新陣列——這才是 _links 目前「建構時凍結、之後永不重讀」
# 這個缺陷唯一會被打中的路徑。
func test_phi_reflects_a_pairing_polarity_flip_made_after_construction() -> void:
	# Arrange — 單位 1、2 相距 1 格，初始配對為正關係（distance=1 → Φ = +3）
	const EXPECTED_PHI_AFTER_FLIP: int = -1  # delta(NEGATIVE, distance=1, amp=1)
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,P2,PLAYER,20,10,0,0,1,1,1,0",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var links: Array[AffinityLink] = _links(LINK_1_2_POSITIVE)
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, links)

	# Act — provider 建構完成之後，配對表的來源被替換成同一對單位但極性翻轉
	# 的一份全新資料（模擬對話卡牌中途翻轉極性，且模擬的是「來源給出新資料」
	# 而非「原地改寫舊物件」）；provider 從未被要求重讀，若它真的做到逐查詢
	# 重新取得，這裡應該還是要看到新的極性
	links = _links(LINK_1_2_NEGATIVE)
	var phi_after_flip: int = provider.phi(1, 999)

	# Assert — 通過代表缺陷已修好；目前預期 FAIL（provider 仍回報翻轉前的 +3，
	# 而不是這裡斷言的 -1），因為 _links 在 _init() 就已經凍結成翻轉前的那份陣列
	assert_int(phi_after_flip).is_equal(EXPECTED_PHI_AFTER_FLIP)
