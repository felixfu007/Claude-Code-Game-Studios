# BattleScreen（src/ui/battle/battle_screen.gd）_ready() 開局好感度灌入——
# 裁決①第二輪的整合測試。
#
# 實作依據:production/epics/support-conversation/
# story-003-cross-mission-affinity-continuity.md（裁決①第二輪）。
#
# 本檔涵蓋的改動:[member BattleScreen.campaign_ledger_override]（新增的可注入
# 欄位，預設 `null`）與共用的私有寫入方法 [method BattleScreen._apply_opening_affinity_record]
# ——靜態 AFFINITY_PATH 灌入與戰役層累積記錄重播現在共用同一條寫入與拒絕碼檢查路徑。
#
# 本檔【不】涵蓋、且本輪刻意不做的事（與該新增欄位自己的文件註解一致）：
# 誰在 production 持有/建立 CampaignAffinityLedger 實例、何時呼叫
# begin_mission()/rollback_current_mission() ——那是下一輪的接線工作，本檔兩條
# 測試都只透過 campaign_ledger_override 直接注入一個手動建構的 ledger 實例。
#
# 載入真實場景的寫法沿用既有先例：
# tests/integration/ui/battle_screen_impassable_terrain_scan_test.gd（terrain_path_override
# 這一族 override 的時機合約：instantiate() 之後、add_child() 之前）、
# tests/integration/ui/battle/battle_screen_card_deck_wiring_test.gd
# （test_ready_seeds_affinity_pool_from_static_table_links_match_polarity()——
# 本檔第一條測試的斷言結構直接比照它，證明「不注入時」結果逐字相同）。
#
# ⚠️ 敏感度證明——誠實登記為「做不到」（test-standards.md 門檻義務）：
# 本檔兩條測試斷言的對象都是 BattleScreen._ready() 內部一段私有、非虛擬方法的
# 直線邏輯（一個 if 判斷 + 一個 for 迴圈），不透過任何可覆寫的虛擬方法或可注入的
# 介面暴露——要用間諜子類別證明「這段邏輯被正確執行」，必須能替換 _ready() 本身
# 的這一小段，而那等於再改一次 src/ui/battle/battle_screen.gd 的生產邏輯，不是
# 幫受測物件接一個合法的測試替身（同類情境見
# battle_screen_impassable_terrain_scan_test.gd 檔尾的誠實登記，屬同一種「寫死在
# _ready() 內部、無注入縫」限制）。兩條測試改採直接斷言真實 production
# AffinityDataPool 的查詢結果（combat_strength_read()）作為保障層級，是比「證明不了
# 就不寫」更弱但誠實的保障。
extends GdUnitTestSuite


var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	# Restore shared CursorStateHost Autoload state; see tests/helpers/cursor_host_snapshot.gd
	_host_snap.restore()


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


# ---- 迴歸鎖：不注入 campaign_ledger_override 時，開局行為與本輪改動之前逐字相同 ----
#
# 🔴 這條測試比下面那條新功能測試更重要（見本工作單的派工說明）：它保證這次新增
# 的「if campaign_ledger_override != null」分支在預設情況下完全不執行，production
# 既有的開局好感度灌入（story-005 的靜態 AFFINITY_PATH 灌入）不受影響。
#
# 斷言結構直接比照既有測試
# battle_screen_card_deck_wiring_test.gd::test_ready_seeds_affinity_pool_from_static_table_links_match_polarity()
# ——用 _phi.links()（AffinityPhiProvider.links()）而非直接讀 _affinity_pool 的理由：
# _phi.links() 走訪的是「目前存活的全部玩家角色兩兩組合」，涵蓋本專案固定 5 名角色
# 共 10 組 Pair 的每一組——如果這次改動不慎讓 campaign_ledger_override 的 null 預設
# 不再是真正的空操作（例如守衛條件寫反、或不小心建構出一個非 null 的預設值），
# 任何一組額外的記錄都會在這裡的 links() 結果裡多出一條或變動既有兩條的極性/數量，
# 不會被漏掉。
func test_ready_without_campaign_ledger_override_matches_existing_static_seed_behavior() -> void:
	# Arrange — 真實場景、真實資料檔，完全不設定 campaign_ledger_override
	# （欄位本身預設值就是 null，這裡刻意不賦值，驗證的就是這個預設值）
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())

	# Act
	add_child(instance)

	# Assert — 欄位預設確實是 null（先確認這條測試真的在測「沒注入」這個情境）
	assert_object(instance.campaign_ledger_override).is_null()
	assert_bool(instance._load_failed).is_false()

	# Assert — 與本輪改動之前的既有斷言逐字相同：靜態檔恰有兩條關係，
	# 1-2 POSITIVE、3-4 NEGATIVE，不多不少
	var links: Array[AffinityLink] = instance._phi.links()
	assert_int(links.size()).append_failure_message(
		(
			"不注入 campaign_ledger_override 時，_phi.links() 應該恰好是靜態 "
			+ "AFFINITY_PATH 的 2 條關係，實得 %d 條——這代表新增的 if 守衛沒有" +
			"正確地在 null 時整個跳過"
		) % links.size()
	).is_equal(2)

	var polarity_by_pair: Dictionary = {}
	for link: AffinityLink in links:
		var key: Vector2i = Vector2i(
			mini(link.unit_a, link.unit_b), maxi(link.unit_a, link.unit_b)
		)
		polarity_by_pair[key] = link.polarity

	assert_bool(polarity_by_pair.has(Vector2i(1, 2))).is_true()
	assert_int(polarity_by_pair.get(Vector2i(1, 2), -1)).is_equal(AffinityLink.Polarity.POSITIVE)
	assert_bool(polarity_by_pair.has(Vector2i(3, 4))).is_true()
	assert_int(polarity_by_pair.get(Vector2i(3, 4), -1)).is_equal(AffinityLink.Polarity.NEGATIVE)


# ---- 新功能：注入帶兩筆記錄的 ledger，開局後池子查得到那兩筆的效果 ----
#
# 刻意不覆寫 terrain/roster/affinity 任何路徑——用 production 預設的 vs01 三件套，
# 讓靜態 AFFINITY_PATH 灌入（C1_C2、C3_C4 兩筆）與本次新增的 ledger 重播
# （C1_C3、C2_C5 兩筆，刻意選與靜態兩筆不重疊的配對）同時發生在同一次 _ready()，
# 更貼近 production 實際會發生的情況，而不是人工把靜態灌入清空成只剩 ledger 單獨一筆。
#
# 🔴 關於數值精確度的揭露：AffinityDataPool._t_now 在同一次 _ready() 內跨配對全域
# 遞增（見 AffinityDataPool.append_record() 文件註解），所以「本次新增的兩筆」在
# 寫入序列裡分別是第 3、第 4 筆（前兩筆是靜態灌入）。combat_strength_read() 預設
# 查詢時點 = 寫入完成當下的 _t_now，對【最後寫入】的那一筆（entry2，age=0）精確
# 可預期衰減為 1.0（_weighted_sum() 的 0^0:=1 顯式特判），可以斷言精確數值；
# 對【次新】的那一筆（entry1，age=1）衰減量取決於 λ_combat 這個平衡旋鈕的現行值
# （AffinityCalibration.uncalibrated_placeholder()，非本測試應該寫死的常數），
# 本檔只斷言其正負號與「這筆記錄確實存在（n_pair/diagnostic_visited_count）」，
# 不斷言其精確衰減後數值——避免把一個平衡旋鈕的具體數字焊進這條接線測試裡。
func test_ready_with_campaign_ledger_override_replays_entries_into_affinity_pool() -> void:
	# Arrange
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	ledger.append(AffinityTypes.Pair.C1_C3, 2.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	ledger.append(AffinityTypes.Pair.C2_C5, -3.0, AffinityTypes.Source.STORY_EVENT)

	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.campaign_ledger_override = ledger

	# Act
	add_child(instance)

	# Assert — 走到底，沒有被判定載入失敗
	assert_bool(instance._load_failed).is_false()

	# Assert — entry1（C1_C3，age=1，衰減量取決於 λ_combat，但正負號必為正、
	# 記錄確實被計入）
	var read1: AffinityDataPool.AffinityReadResult = (
		instance._affinity_pool.combat_strength_read(AffinityTypes.Pair.C1_C3)
	)
	assert_int(read1.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
	assert_int(read1.n_pair).append_failure_message(
		"預期 ledger 的第一筆記錄（C1_C3）被計入 n_pair，實得 %d" % read1.n_pair
	).is_equal(1)
	assert_int(read1.diagnostic_visited_count).is_equal(1)
	assert_bool(read1.value > 0.0).append_failure_message(
		"ledger 第一筆記錄 m=2.0（正）衰減後正負號應維持為正，實得 %f" % read1.value
	).is_true()

	# Assert — entry2（C2_C5，age=0，衰減量結構上精確等於 1.0，可斷言精確數值）
	var read2: AffinityDataPool.AffinityReadResult = (
		instance._affinity_pool.combat_strength_read(AffinityTypes.Pair.C2_C5)
	)
	assert_int(read2.rejection).is_equal(AffinityDataPool.ReadRejection.NONE)
	assert_int(read2.n_pair).is_equal(1)
	assert_int(read2.diagnostic_visited_count).is_equal(1)
	assert_float(read2.value).append_failure_message(
		"ledger 第二筆記錄（C2_C5，m=-3.0）衰減後正負號應維持為負，實得 %f。" % read2.value +
		"story-004:第 1 場開局起始關係改寫進累積記錄、排在這筆之後重播,所以它不再是" +
		"最後一筆(age>0),舊的「精確 -3.0」假設不成立,改斷言正負號"
	).is_less(0.0)

	# Assert — 原本的靜態灌入（C1_C2、C3_C4）沒有被 ledger 重播擠掉或改變，
	# 兩條機制確實共用同一個池、互不覆蓋
	var read_static_1: AffinityDataPool.AffinityReadResult = (
		instance._affinity_pool.combat_strength_read(AffinityTypes.Pair.C1_C2)
	)
	assert_int(read_static_1.n_pair).is_equal(1)
	var read_static_2: AffinityDataPool.AffinityReadResult = (
		instance._affinity_pool.combat_strength_read(AffinityTypes.Pair.C3_C4)
	)
	assert_int(read_static_2.n_pair).is_equal(1)
