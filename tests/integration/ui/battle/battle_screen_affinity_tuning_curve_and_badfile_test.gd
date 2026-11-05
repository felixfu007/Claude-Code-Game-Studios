# production/epics/tuning-data/story-005-affinity-rules-tuning.md AC2(後半)/ AC3(後半)補測
# 真實 BattleScreen.tscn + 注入 tuning_path_override:
#   (1) delta_positive_adjacent 夾具 -> production 的 BattleScreen._guess_delta_for_cell()(畫面預覽 delta)
#       跟著變;對照真實檔(預設 3)證明差異來自夾具。
#   (2) phi_min > phi_max 夾具 -> BattleScreen 明確載入失敗(_load_failed、錯誤標籤顯示、無 BattleState),
#       不是靜默退回預設。
# 檔案存取:甲類例外 —— 唯讀 assets/data/tuning/ 版控夾具與真實檔,不寫入任何檔案。
#   無法改用注入:要證的正是「BattleScreen 讀資料檔那條路徑」。⚠️ 不證明窮盡性。
# 注入順序:instantiate() -> 設 override -> add_child(本檔不使用 set_script)。
#
# 曲線取值走 production 方法 BattleScreen._guess_delta_for_cell()(畫面好感度預覽的 delta = 預覽值 - 現值),
# 不在測試裡自己呼叫 AffinityRules:若 battle_screen.gd 預覽漏傳 tuning,這條才會變紅。
# 差值 = -2 的理由(實測 vs01 開場 unit_a 已在 unit_b 距離 1,先前「移到隔壁」的設計差值會是 0,已改):
# delta = bonus_for_at(假想格) - bonus_for(現位置)。現位置距離 1 -> 現值項 3(預設)/5(夾具);
# 假想格距離 3(delta_positive_far = -1,兩邊相同)-> 預覽項 -1。故 delta = -1-3=-4(預設)、-1-5=-6(夾具),差 -2。
# 前置條件(現位置距離 1)在測試內以斷言鎖住;若日後開場站位改變會明確變紅,而非悄悄算出別的數字。
# 敏感度證明(兩條都【無法常駐】,誠實登記):
#   證明形式需「注入錯誤版本的受測物」。兩條斷言的對象都是 真實 tuning 資料檔 -> BattleScreen 的載入路徑,
#   屬 test-standards.md 的 A′ 類(斷言對象是資料檔內容,沒有類別可注入錯誤版本);改壞只能改夾具檔本身,
#   而常駐測試不得寫檔(甲類例外只准唯讀)。故以手動改壞留紀錄(2026-11-05,各跑全套一次,改回後全檔掃描無殘留):
#   - 曲線:夾具 delta_positive_adjacent 5 -> 3,變紅:test_affinity_curve_follows_injected_delta_positive_adjacent
#     (斷言 5 but was 3 等 3 處,檔內對應行)。
#   - 壞檔:夾具 phi_max -3 -> 9(使檔案合法),變紅:test_phi_min_greater_than_phi_max_fixture_fails_load_explicitly
#     (Expecting true but is false,_load_failed / 錯誤標籤可見 兩處)。
#   ⚠️ 手動紀錄在版本庫外不可重現,僅為紀錄。
#   - production 側「漏傳 tuning」(2026-11-05 協調者做):暫將 battle_screen.gd _guess_delta_for_cell()
#     兩處 _state.affinity_tuning 改為 null,全套 ENGINE EXIT = 100 / 1867 test cases | 2 failures,
#     唯一 FAILED 為本檔 test_affinity_curve_follows_injected_delta_positive_adjacent;
#     已 git checkout 還原並確認與 HEAD 相同。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _REAL: String = "res://assets/data/tuning/tuning_knobs.txt"
const _ADJ5: String = "res://assets/data/tuning/test_fixture_tuning_affinity_delta_adj5.txt"
const _INVERTED: String = "res://assets/data/tuning/test_fixture_tuning_affinity_phi_inverted.txt"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()


func after_test() -> void:
	_host_snap.restore()
	CampaignProgress.reset_for_test()


func _load_with_tuning(path: String) -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.tuning_path_override = path
	add_child(instance)
	return instance


## 走真實流程:取 BattleScreen 自己的連線與站位,把第一條 POSITIVE 連線的 unit_a
## 假想移到 unit_b 的 3 格外(距離 3),以 production 的 [method BattleScreen._guess_delta_for_cell] 取好感度 delta。
## 前置:unit_a 現位置必須在 unit_b 距離 1(現值項才會隨 delta_positive_adjacent 變)。
func _adjacent_positive_preview_delta(s: BattleScreen) -> int:
	var link: AffinityLink = null
	for l: AffinityLink in s._phi.links():
		if l.polarity == AffinityLink.Polarity.POSITIVE:
			link = l
			break
	assert_object(link).is_not_null()
	var positions: Dictionary[int, Vector2i] = s._phi.positions()
	assert_bool(positions.has(link.unit_a)).is_true()
	assert_bool(positions.has(link.unit_b)).is_true()
	var current_distance: int = absi(positions[link.unit_a].x - positions[link.unit_b].x) + absi(positions[link.unit_a].y - positions[link.unit_b].y)
	assert_int(current_distance).is_equal(1)
	return s._guess_delta_for_cell(link.unit_a, positions[link.unit_b] + Vector2i(3, 0))


func test_affinity_curve_follows_injected_delta_positive_adjacent() -> void:
	var real: BattleScreen = _load_with_tuning(_REAL)
	assert_bool(real._load_failed).is_false()
	var real_value: int = _adjacent_positive_preview_delta(real)
	remove_child(real)

	var adj5: BattleScreen = _load_with_tuning(_ADJ5)
	assert_bool(adj5._load_failed).is_false()
	assert_int(adj5._state.affinity_tuning.delta_positive_adjacent()).is_equal(5)
	var fixture_value: int = _adjacent_positive_preview_delta(adj5)
	remove_child(adj5)

	# 預設 3 -> 夾具 5:同一份連線、同一種站位,只差 tuning 檔,delta 差 -2(理由見檔頭)。
	assert_int(real_value).is_equal(-4)
	assert_int(fixture_value).is_equal(-6)
	assert_int(fixture_value - real_value).is_equal(-2)


func test_phi_min_greater_than_phi_max_fixture_fails_load_explicitly() -> void:
	var s: BattleScreen = _load_with_tuning(_INVERTED)
	assert_bool(s._load_failed).is_true()
	assert_bool(s._load_error_label.visible).is_true()
	assert_str(s._load_error_label.text).is_equal(
		BattleScreen.load_failure_message(BattleScreen.LoadFailure.PARSE_ERROR, _INVERTED))
	assert_object(s._state).is_null()
	remove_child(s)
