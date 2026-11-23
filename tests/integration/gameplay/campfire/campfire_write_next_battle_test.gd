## campfire_write_next_battle_test.gd
##
## 實作依據:production/epics/campfire/story-002-campfire-write-port.md
## AC4(營火寫入後,下一場戰鬥開局讀到新關係;載入真實 BattleScreen.tscn、注入累積記錄)、
## AC5(麥子健四組原本全 NONE,營火關心其中一組 -> 騎牆 lone_guard 與 hold_back 同時關閉;
## 讀端為 story-014 的 AffinityPhiProvider.straddle_valid)。
##
## 檔案存取:無自建檔案(AC4 由真實場景自行載入正式資料檔,屬場景載入非測試 I/O)。
##
## 敏感度證明:AC4/AC5 的斷言對象是「既有生產程式(BattleScreen 重播、story-014 判定)
## 讀到寫入口的產出」。寫入口本身的 mutant 已在
## tests/unit/gameplay/campfire/campfire_write_port_test.gd 的 test_sensitivity_proof_* 覆蓋;
## 本檔額外的保護是「寫入前/後對照」(先斷言寫入前為 NONE / 騎牆開,才斷言寫入後翻轉),
## 使「根本沒寫入」會讓後半段紅。BattleScreen 內部重播無注入縫,本檔不另蓋 mutant(D 類)。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _ROW: String = "............."
const _TERRAIN: PackedStringArray = [_ROW, _ROW, _ROW, _ROW, _ROW, _ROW]
const _KNOB_TEXT: String = "m,0.5\ncamp_actions_per_round,3\n"
const _C := AffinityTypes.Character

var _host_snap: CursorHostSnapshot = null
var _keep_alive: Array[AffinityPhiProvider] = []


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


func _port(ledger: CampaignAffinityLedger) -> CampfireWritePort:
	var knobs: CampfireKnobs = CampfireKnobs.from_text(_KNOB_TEXT)
	assert_object(knobs).is_not_null()
	var port: CampfireWritePort = CampfireWritePort.new(ledger, knobs)
	port.begin_round()
	return port


## 甲=1 在 (0,0);乙丙丁遠在 x=7;戊=5(麥子健,lone_guard)在 (2,0);敵 6 在 (7,2)。
func _build() -> BattleState:
	var lines: PackedStringArray = []
	lines.append("1,甲,PLAYER,30,16,8,6,1,1,0,0")
	lines.append("2,乙,PLAYER,30,16,8,6,1,1,7,0")
	lines.append("3,丙,PLAYER,30,16,8,6,1,1,7,1")
	lines.append("4,丁,PLAYER,30,16,8,6,1,1,6,1")
	lines.append("5,戊,PLAYER,30,16,8,6,1,1,2,0,1")
	lines.append("6,E1,ENEMY,300,14,6,6,1,1,7,2")
	return BattleState.create(_TERRAIN, "\n".join(lines))


func _wire(state: BattleState, pool: AffinityDataPool) -> void:
	var p: AffinityPhiProvider = AffinityPhiProvider.new(state, pool)
	_keep_alive.append(p)
	state.attach_straddle_provider(Callable(p, "straddle_valid"))


func _lone5(s: BattleState) -> int:
	return int(s.preview_damage_breakdown(6, 5, 0).breakdown["lone_guard"])


func _hold_back5(s: BattleState) -> int:
	return int(s.preview_damage_breakdown(5, 6, 0).breakdown["hold_back"])


# ---- AC4 ---------------------------------------------------------------------

func test_campfire_write_is_read_by_real_battle_screen_opening_pool() -> void:
	# Arrange -- 營火寫入 C2_C3(靜態關係檔不含的組,排除「是種子檔造成的」)
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var r: CampfireWritePort.Rejection = _port(ledger).confirm(
		_C.CHARACTER_2, _C.CHARACTER_3, CampfireWritePort.Action.CARE
	)
	assert_int(r).is_equal(CampfireWritePort.Rejection.NONE)
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.campaign_ledger_override = ledger
	# Act
	add_child(instance)
	# Assert
	assert_bool(instance._load_failed).is_false()
	var state: AffinityRelation.RelationState = AffinityRelation.state_of(
		instance._affinity_pool, AffinityTypes.Pair.C2_C3, 0.0
	)
	assert_int(state).append_failure_message("下一場開局應讀到營火寫入的正向關係").is_equal(AffinityRelation.RelationState.POS)


func test_without_campfire_write_the_same_pair_reads_none_in_real_battle_screen() -> void:
	# 對照組:同一場景、同一組、沒有營火寫入 -> NONE(證明上一條的 POS 來自營火寫入)
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.campaign_ledger_override = ledger
	add_child(instance)
	var state: AffinityRelation.RelationState = AffinityRelation.state_of(
		instance._affinity_pool, AffinityTypes.Pair.C2_C3, 0.0
	)
	assert_int(state).is_equal(AffinityRelation.RelationState.NONE)


# ---- AC5 ---------------------------------------------------------------------

func test_caring_for_one_mai_pair_closes_lone_guard_and_hold_back_together() -> void:
	# Arrange -- 寫入前:四組全 NONE,騎牆開(d=2:lone_guard +2、hold_back 1)
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var port: CampfireWritePort = _port(ledger)
	var before: BattleState = _build()
	_wire(before, port.rebuild_pool())
	assert_int(_lone5(before)).is_equal(2)
	assert_int(_hold_back5(before)).is_equal(1)
	# Act -- 營火關心麥子健(5)與丁(4)
	var r: CampfireWritePort.Rejection = port.confirm(_C.CHARACTER_4, _C.CHARACTER_5, CampfireWritePort.Action.CARE)
	assert_int(r).is_equal(CampfireWritePort.Rejection.NONE)
	var after: BattleState = _build()
	_wire(after, port.rebuild_pool())
	# Assert -- 兩項同時關閉
	assert_int(_lone5(after)).is_equal(0)
	assert_int(_hold_back5(after)).is_equal(0)
