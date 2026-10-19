## campaign_affinity_ledger_test.gd
##
## 實作依據:
## production/epics/support-conversation/story-003-cross-mission-affinity-continuity.md
## AC1(持有累積記錄,純資料、零節點)+ AC4(打輸整關回滾,連累積記錄一起回滾)。
##
## 本檔本輪只測 [CampaignAffinityLedger] 這個獨立類別本身——誰持有它、何時呼叫
## [method CampaignAffinityLedger.begin_mission] /
## [method CampaignAffinityLedger.rollback_current_mission] 是接線端的責任,
## 本輪不處理(協調者 2026-10-19 課正後的派工範圍縮減)。
##
## 非 static——每條測試各自 [method CampaignAffinityLedger.new] 一份乾淨實例,
## 不需要 [code]reset_for_test()[/code] 那套既有紀律([code]GameSettings[/code] /
## [code]CampaignProgress[/code] 需要是因為它們是 [code]static var[/code];本類別
## 刻意不是,見該檔案頭文件註解)。
##
## 🔴 enum 字面值刻意只用本次工作已直接核實存在的兩個 [enum AffinityTypes.Pair]
## 成員([code]C1_C2[/code] / [code]C3_C4[/code])與兩個
## [enum AffinityTypes.Source] 成員([code]STORY_EVENT[/code] /
## [code]COMBAT_CARD[/code])——本檔不猜測其餘未直接核實過的成員名稱。本類別本身
## 不對 pair/source 做任何合法性檢查(見 [method CampaignAffinityLedger.append]
## 文件註解),所以這個限縮不影響測試對本類別行為的涵蓋範圍。
##
## [member CampaignAffinityLedger.records] 的回傳值在本檔一律收進未型別化的
## [Array] 局部變數,不宣告為
## [code]Array[CampaignAffinityLedger.Entry][/code]——本類別的 [Entry] 是刻意
## 不獨立成檔、不掛 [code]class_name[/code] 的內部類別(見該類別文件註解),本檔
## 不驗證跨檔宣告「外層類別.內部類別」型別化陣列在本專案釘死的 Godot 4.7.1 下是否
## 與同檔裸引用享有同一種編譯期保證,改用未型別化 [Array] 接收可以安全地繞開這個
## 未核實的角落,不影響任何斷言的精確度。
extends GdUnitTestSuite


func test_append_then_records_preserves_insertion_order() -> void:
	# Arrange
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()

	# Act
	ledger.append(AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.STORY_EVENT)
	ledger.append(AffinityTypes.Pair.C3_C4, -2.0, AffinityTypes.Source.COMBAT_CARD)
	ledger.append(AffinityTypes.Pair.C1_C2, 3.0, AffinityTypes.Source.STORY_EVENT)

	# Assert
	var records: Array = ledger.records()
	assert_int(records.size()).append_failure_message(
		"三次 append() 之後 records() 應回傳恰好 3 筆"
	).is_equal(3)

	var entry0: CampaignAffinityLedger.Entry = records[0]
	assert_int(entry0.pair).is_equal(AffinityTypes.Pair.C1_C2)
	assert_float(entry0.m).is_equal_approx(1.0, 0.000001)
	assert_int(entry0.source).is_equal(AffinityTypes.Source.STORY_EVENT)

	var entry1: CampaignAffinityLedger.Entry = records[1]
	assert_int(entry1.pair).is_equal(AffinityTypes.Pair.C3_C4)
	assert_float(entry1.m).is_equal_approx(-2.0, 0.000001)
	assert_int(entry1.source).is_equal(AffinityTypes.Source.COMBAT_CARD)

	var entry2: CampaignAffinityLedger.Entry = records[2]
	assert_int(entry2.pair).is_equal(AffinityTypes.Pair.C1_C2)
	assert_float(entry2.m).is_equal_approx(3.0, 0.000001)
	assert_int(entry2.source).is_equal(AffinityTypes.Source.STORY_EVENT)


## AC4——打輸整關回滾:begin_mission() -> 新增三筆 -> rollback_current_mission()
## -> 回到這一場開打前的樣子(本測試從一份全新、空的帳本開始,所以「開打前的樣子」
## 就是空清單)。
func test_rollback_current_mission_discards_entries_added_since_begin_mission() -> void:
	# Arrange
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	ledger.begin_mission()

	# Act
	ledger.append(AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.STORY_EVENT)
	ledger.append(AffinityTypes.Pair.C3_C4, 2.0, AffinityTypes.Source.COMBAT_CARD)
	ledger.append(AffinityTypes.Pair.C1_C2, 3.0, AffinityTypes.Source.STORY_EVENT)
	ledger.rollback_current_mission()

	# Assert
	assert_array(ledger.records()).append_failure_message(
		"AC4:這一場開打前帳本是空的,回滾後應回到空清單"
	).is_empty()


## 跨兩場:第 1 場新增一筆 -> begin_mission() 進入第 2 場 -> 新增一筆 -> 回滾
## 第 2 場 -> 第 1 場那筆還在(證明回滾只丟當場新增的,不是把整本帳清空)。
func test_rollback_current_mission_does_not_discard_earlier_missions_entries() -> void:
	# Arrange — 第 1 場:建構後、第一次呼叫 begin_mission() 之前就 append() 是
	# 合法呼叫序,等同「第 1 場從一開始就在記錄」。
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	ledger.append(AffinityTypes.Pair.C1_C2, 10.0, AffinityTypes.Source.STORY_EVENT)

	# Act — 第 2 場開打,新增一筆後回滾第 2 場
	ledger.begin_mission()
	ledger.append(AffinityTypes.Pair.C3_C4, -5.0, AffinityTypes.Source.COMBAT_CARD)
	ledger.rollback_current_mission()

	# Assert — 第 1 場那筆還在,第 2 場那筆消失
	var records: Array = ledger.records()
	assert_int(records.size()).append_failure_message(
		"回滾第 2 場不應連第 1 場累積的記錄一起清掉"
	).is_equal(1)
	var entry0: CampaignAffinityLedger.Entry = records[0]
	assert_int(entry0.pair).is_equal(AffinityTypes.Pair.C1_C2)
	assert_float(entry0.m).is_equal_approx(10.0, 0.000001)
	assert_int(entry0.source).is_equal(AffinityTypes.Source.STORY_EVENT)


## 敏感度證明:不呼叫 rollback_current_mission() 時,那些記錄確實還在——證明上面
## 兩條測試觀察到的「消失」是 rollback_current_mission() 造成的,不是這些記錄
## 本來就不會被記住(例如 append() 本身悄悄是個空操作這種退化,會讓上面兩條測試
## 巧合地通過)。
func test_sensitivity_proof_entries_survive_without_rollback() -> void:
	# Arrange
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	ledger.begin_mission()

	# Act — 與 test_rollback_current_mission_discards_entries_added_since_
	# begin_mission() 完全相同的三次 append(),唯一差異是不呼叫
	# rollback_current_mission()
	ledger.append(AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.STORY_EVENT)
	ledger.append(AffinityTypes.Pair.C3_C4, 2.0, AffinityTypes.Source.COMBAT_CARD)
	ledger.append(AffinityTypes.Pair.C1_C2, 3.0, AffinityTypes.Source.STORY_EVENT)

	# Assert — 三筆都還在,與上面那條回滾後 is_empty() 的結果精確地相反
	assert_int(ledger.records().size()).append_failure_message(
		"沒有呼叫 rollback_current_mission() 時,append() 的三筆記錄應該全部保留"
	).is_equal(3)
