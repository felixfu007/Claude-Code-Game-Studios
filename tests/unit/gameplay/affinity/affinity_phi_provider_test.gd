# AffinityPhiProvider（src/gameplay/affinity/affinity_phi_provider.gd）的單元測試。
#
# 這個類別是滿足 BattleController 建構子 phi_provider: Callable 契約
# （func(attacker_id: int, target_id: int) -> int）的介接物件：把 BattleState
# 的即時位置與 AffinityDataPool 的即時配對資料餵給 AffinityRules 的純函式數學。
# 本檔前五支測試各自獨立驗證 positions()/positions_with()/phi() 這三個公開方法的
# 個別行為；第六支是規格書點名「本檔最重要的一支」的整合測試——真的組出一個
# BattleController，證明 Φ 從「布線但沒人接」變成「真的會改變傷害數字」，不然
# 前面每一支測試全過也可能是這條線根本沒接上；第七支是 story-005（好感度數值池
# 遷移）交付的逐查詢反快取測試，見該測試自己的註解。
#
# 全鏈路（BattleState/BattleController/TurnOrder/AffinityRules/AffinityDataPool）
# 都是 RefCounted 或 static，不建立任何 Node，不需要 tear-down，不會留下孤兒
# 節點。每個測試自建 roster 字串與/或 AffinityDataPool 記錄，不共用可變狀態，
# 因此不依賴執行順序。命名慣例沿用既有先例 test_[scenario]_[expected]（見
# affinity_rules_test.gd／battle_controller_threat_test.gd）。
#
# 🔴 story-005（production/epics/affinity-position-chain/
# story-005-pairing-data-per-query-refetch.md）—— AffinityPhiProvider 的建構子
# 簽章已從 (state, links: Array[AffinityLink]) 改為 (state, pool:
# AffinityDataPool)：配對資料不再是呼叫端傳入一份靜態陣列，而是 provider 每次
# 查詢時向 pool 即時取得（見 AffinityPhiProvider.links()/_link_for_pair()
# 文件註解）。本檔全部七支測試的 Arrange 步驟因此都從「組一份 AffinityLink
# CSV 字串」改為「建一個 AffinityDataPool 並視需要 append_record()」——這不是
# 在修改任一支測試的斷言來讓它通過，是建構子簽章改變後唯一能讓測試檔繼續編譯
# 的做法；每支測試原本斷言的具體數字（Φ 值）一個都沒有改變。
extends GdUnitTestSuite

const VS01_ROSTER_PATH: String = "res://assets/data/units/vs01_roster.txt"


## 建立一個全新 [AffinityDataPool]，並寫入一筆記錄（[param m] 的正負決定
## polarity，量值本身對 Φ 無意義——OQ-3 已裁決只取符號，[code]amp[/code]
## 恆為 1）。寫入斷言必須成功（[constant AffinityDataPool.WriteRejection.NONE]）—
## 若失敗代表治具本身寫錯，不是受測物的行為，不應該讓測試用一個悄悄壞掉的
## pool 繼續跑下去（響亮地停，呼應 [code]_links()[/code] 這支舊版輔助函式
## 曾經用過的同一種紀律，雖然它本身已隨本次改版移除）。
func _pool_with_record(pair: AffinityTypes.Pair, m: float) -> AffinityDataPool:
	var pool: AffinityDataPool = AffinityDataPool.new()
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(
		pair, m, AffinityTypes.Source.STORY_EVENT
	)
	if rejection != AffinityDataPool.WriteRejection.NONE:
		fail(
			"_pool_with_record(): append_record() 被拒絕(rejection=%d) —— 治具本身寫錯，"
			% rejection
			+ "不是受測物的行為。"
		)
	return pool


# ---- (1) phi()：回報攻擊者當下的好感度加成 ---------------------------------

func test_phi_returns_attackers_current_affinity_bonus() -> void:
	# Arrange — 單位 1、2 正關係，相距 1 格 → +3；target_id 對 phi() 的計算
	# 無影響，故隨便給一個不存在的 id 也不該出錯。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,P2,PLAYER,20,10,0,0,1,1,1,0",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var pool: AffinityDataPool = _pool_with_record(AffinityTypes.Pair.C1_C2, 1.0)
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, pool)

	# Act / Assert
	assert_int(provider.phi(1, 999)).is_equal(3)


# ---- (2) phi()：無配對的單位恆回傳 0（用真實 vs01 roster + 對應真實關係設定）--

func test_phi_returns_zero_for_unit_with_no_links_vs01_unit_five() -> void:
	# Arrange — 戊（單位 5）即使在一個已有其他配對記錄的 pool 裡，自己從未被
	# 寫入任何一對 Pair 的記錄，查詢必須回傳 0。story-005 之後配對資料的權威
	# 來源是 AffinityDataPool，不再是 vs01_affinity_links.txt——這裡植入的
	# 兩筆記錄（1,2 正向／3,4 負向）內容對應 design/narrative/characters.md
	# 第三節的真實關係設定（與該檔過去記載的同一組關係），只是植入方式改為
	# 直接呼叫 append_record()，不再讀檔解析 CSV。
	var roster_text: String = FileAccess.get_file_as_string(VS01_ROSTER_PATH)
	var state: BattleState = BattleState.create(PackedStringArray(), roster_text)
	var pool: AffinityDataPool = _pool_with_record(AffinityTypes.Pair.C1_C2, 1.0)
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(
		AffinityTypes.Pair.C3_C4, -1.0, AffinityTypes.Source.STORY_EVENT
	)
	assert_int(rejection).is_equal(AffinityDataPool.WriteRejection.NONE)
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, pool)

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
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, AffinityDataPool.new())

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
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, AffinityDataPool.new())

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
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, AffinityDataPool.new())
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

	# Act — 附 Φ 供應器的一組
	var state_with_phi: BattleState = BattleState.create(PackedStringArray(), roster_text)
	var pool: AffinityDataPool = _pool_with_record(AffinityTypes.Pair.C1_C2, 1.0)
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state_with_phi, pool)
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
# affinity_pairing_data_per_query_refetch，story-005 交付前本檔唯一預期 FAIL
# 的測試，story-005 完成後必須變綠）---------------------------------------

# 這支測試釘的是 docs/registry/architecture.yaml 的 interface contract
# affinity_pairing_data_per_query_refetch：配對資料（polarity/strength）必須
# 跟 positions() 同一個新鮮度等級——每一次 phi() 查詢都要重新取得，不能只在
# 建構當下讀一次就固定終身。來源是 design/gdd/affinity-position-chain.md
# Interactions①與 States-and-Transitions：一張中途翻轉某對關係極性的對話卡牌，
# 效果必須在下一次 phi() 查詢就看得到，不必等 provider 被重新建構。
#
# ✅ story-005 之後這支測試改為直接對 provider 建構時已經在用的【同一個】
# AffinityDataPool 實例追加一筆新記錄——不再需要舊版（pool 出現之前）那套
# 「重新指派本地陣列變數，而非原地修改陣列元素」的技巧來模擬「資料來源給出
# 新資料」：pool 本來就是 RefCounted、傳參考，provider._pool 與這裡的 `pool`
# 變數是同一個物件，append_record() 直接改變的就是 provider 下一次查詢時
# combat_strength_read() 會讀到的資料，不需要任何語言層面的參考語意技巧。
func test_phi_reflects_a_pairing_polarity_flip_made_after_construction() -> void:
	# Arrange — 單位 1、2 相距 1 格，初始配對為正關係（distance=1 → Φ = +3）
	const EXPECTED_PHI_BEFORE_FLIP: int = 3   # delta(POSITIVE, distance=1, amp=1)
	const EXPECTED_PHI_AFTER_FLIP: int = -1   # delta(NEGATIVE, distance=1, amp=1)
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,P2,PLAYER,20,10,0,0,1,1,1,0",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var pool: AffinityDataPool = _pool_with_record(AffinityTypes.Pair.C1_C2, 1.0)
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, pool)

	# Sanity check — 翻轉前，provider 真的讀到初始正向記錄（舊版測試沒有斷言
	# 這一步；現在補上純屬加強嚴謹度，因為多一次查詢幾乎零成本）。
	assert_int(provider.phi(1, 999)).is_equal(EXPECTED_PHI_BEFORE_FLIP)

	# Act — provider 建構完成之後，直接對它持有的同一個 pool 追加一筆記錄，
	# 讓這對配對的淨值由正轉負（+1.0 累加 -5.0 → 淨值 -4.0 < 0）。兩筆記錄
	# 的 t_i 皆為 _t_now=0（本測試全程未呼叫 advance_campaign_tick()），故
	# 衰減一律為 1.0，結果不受校準旋鈕的實際數值影響，維持決定性。
	var rejection: AffinityDataPool.WriteRejection = pool.append_record(
		AffinityTypes.Pair.C1_C2, -5.0, AffinityTypes.Source.STORY_EVENT
	)
	assert_int(rejection).is_equal(AffinityDataPool.WriteRejection.NONE)
	var phi_after_flip: int = provider.phi(1, 999)

	# Assert — 通過代表 phi() 真的對 pool 做逐次查詢，而不是在建構時凍結一份
	# 配對資料（story-005 修復前的行為）
	assert_int(phi_after_flip).is_equal(EXPECTED_PHI_AFTER_FLIP)


# ---- (8) links()：n_pair == 0 邊界 —— 無資料的配對不產生任何線 ----------------
# story-005 QA Test Cases「n_pair == 0 邊界」。

func test_links_excludes_a_pair_with_zero_recorded_interactions() -> void:
	# Arrange — 兩個存活主角，pool 完全沒有任何記錄 → combat_strength_read()
	# 對這對配對回傳 rejection==NONE 且 n_pair==0（design/gdd/affinity-data-pool.md
	# Edge Cases「n(p)=0」的合法邊界，不是錯誤）。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,P2,PLAYER,20,10,0,0,1,1,1,0",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, AffinityDataPool.new())

	# Act
	var links: Array[AffinityLink] = provider.links()

	# Assert — 不產生任何線（不只是 Φ 算出 0，是 links() 結果裡根本沒有這筆）
	assert_bool(links.is_empty()).is_true()
	assert_int(provider.phi(1, 999)).is_equal(0)


# ---- (9) links()：裁決 4 降級處理 —— 被拒絕的配對不拋例外、貢獻視為 0、
# 留下可觀測診斷紀錄，且不影響其餘合法配對 ------------------------------------
# story-005 QA Test Cases「裁決 4 降級處理」。2026-09-29 管理者裁決，見
# story-005 自己的 markdown 檔「🔴 裁決 4」節。

func test_link_for_pair_degrades_a_rejected_pair_without_raising_and_logs_diagnostic() -> void:
	# Arrange — links() 自己的候選配對建構邏輯只會餵進目前在場且存活的主角
	# 兩兩配對，結構上永遠落在 10 個合法序數內（見 links() 文件註解），所以
	# 無法透過正常的 links()/phi() 呼叫路徑讓 combat_strength_read() 收到一個
	# 非法 Pair——裁決 4 的背景分析本身就指出這在正常遊玩中不可達。要重現這個
	# 降級路徑，必須像這裡一樣直接呼叫 _link_for_pair()，刻意帶入一個序數
	# 越界的 Pair，模擬「本類別自己把配對轉換寫錯」這個工程錯誤。
	var roster: Array[String] = ["1,P1,PLAYER,20,10,0,0,1,1,0,0"]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, AffinityDataPool.new())
	var invalid_pair: Variant = 999

	# Act
	var link: Variant = provider._link_for_pair(1, 2, invalid_pair)

	# Assert — 不拋例外（執行到這裡本身就是證明）、該配對貢獻視為「沒有這條線」、
	# 留下可觀測的診斷紀錄
	assert_object(link).is_null()
	assert_int(provider.diagnostic_rejected_pair_count()).is_equal(1)


func test_links_skips_only_the_rejected_pair_leaving_other_valid_pairs_unaffected() -> void:
	# Arrange — 同一次 links() 呼叫裡，一對合法（1,2 正向）與一對被拒絕
	# （刻意構造的非法 Pair，透過直接呼叫 _link_for_pair() 模擬）並存，
	# 驗證被拒絕的那對不會中止其餘合法配對的計算（裁決 4 Edge case）。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,P2,PLAYER,20,10,0,0,1,1,1,0",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var pool: AffinityDataPool = _pool_with_record(AffinityTypes.Pair.C1_C2, 1.0)
	var provider: AffinityPhiProvider = AffinityPhiProvider.new(state, pool)
	var invalid_pair: Variant = 999

	# Act — 合法配對走正常路徑，非法配對直接呼叫內部方法模擬裁決 4 的觸發情境
	var legal_link: Variant = provider._link_for_pair(1, 2, AffinityTypes.Pair.C1_C2)
	var rejected_link: Variant = provider._link_for_pair(3, 4, invalid_pair)

	# Assert — 合法配對正常產生一條正向線，被拒絕的配對是 null，兩者互不影響
	assert_object(legal_link).is_not_null()
	assert_object(rejected_link).is_null()
	assert_int(provider.diagnostic_rejected_pair_count()).is_equal(1)
	# 合法路徑（links()）本身仍然正常：存活主角只有兩位、配對正向、相距 1 格
	assert_int(provider.phi(1, 999)).is_equal(3)
