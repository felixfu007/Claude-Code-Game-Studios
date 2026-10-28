# production/epics/game-shell/story-007-campaign-missions-3-to-5.md AC3
# 整合測試 —— 序列表每一列,用真實 BattleScreen.tscn 經 *_path_override 注入進樹,
# 斷言資料載入沒有失敗、棋盤尺寸與雙方單位數正確。
#
# 檔案存取:甲類例外 —— 唯讀 assets/data/ 已進版控的真實關卡資料檔(本測試的目的就是
# 抓「資料檔打錯字/座標出界」,改用寫死假資料就抓不到)。序列表本身用
# BattleScreen.campaign_total_missions() 與 CampaignSequence.sequence_from_text 讀取;
# 本檔不寫任何檔案。⚠️ 本測試不證明「資料內容在設計上正確」,只證明引擎載得起來且
# 單位數/棋盤尺寸符合 vs01~vs05 共同形狀(13×6,5 PLAYER + 5 ENEMY)。
#
# 敏感度證明:見 test_sensitivity_proof_*(以故意壞掉的名冊證明偵測器會紅)。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _SEQUENCE_PATH: String = "res://assets/data/levels/campaign_sequence.txt"
const _BAD_ROSTER_PATH: String = "res://assets/data/units/test_fixture_roster_duel.txt"

const _EXPECTED_WIDTH: int = 13
const _EXPECTED_HEIGHT: int = 6
const _EXPECTED_PER_FACTION: int = 5

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()


func after_test() -> void:
	_host_snap.restore()
	CampaignProgress.reset_for_test()


func _records() -> Array:
	var parsed: Variant = CampaignSequence.sequence_from_text(FileAccess.get_file_as_string(_SEQUENCE_PATH))
	assert_bool(parsed != null).is_true()
	return parsed as Array


## 載入某一列;roster_override 非空則覆蓋名冊(僅敏感度證明用)。
func _load_row(rec: CampaignSequence, roster_override: String = "") -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.terrain_path_override = rec.terrain_path
	instance.roster_path_override = rec.roster_path if roster_override == "" else roster_override
	instance.affinity_path_override = rec.affinity_path
	instance.cards_path_override = rec.cards_path
	instance.card_text_path_override = rec.card_text_path
	add_child(instance)
	return instance


## 回傳違規描述清單;空 = 乾淨。偵測器同時供敏感度證明使用。
func _violations(instance: BattleScreen, label: String) -> Array[String]:
	var out: Array[String] = []
	if instance._load_failed:
		out.append("%s: _load_failed == true(資料載入失敗)" % label)
		return out
	var board: Board = instance._state.board
	if not board.is_in_bounds(Vector2i(_EXPECTED_WIDTH - 1, _EXPECTED_HEIGHT - 1)):
		out.append("%s: 棋盤右下角 (12,5) 不在界內" % label)
	if board.is_in_bounds(Vector2i(_EXPECTED_WIDTH, 0)) or board.is_in_bounds(Vector2i(0, _EXPECTED_HEIGHT)):
		out.append("%s: 棋盤比 13x6 大" % label)
	var players: int = instance._state.units_of(Unit.Faction.PLAYER).size()
	var enemies: int = instance._state.units_of(Unit.Faction.ENEMY).size()
	if players != _EXPECTED_PER_FACTION:
		out.append("%s: PLAYER 單位數 %d,應為 %d" % [label, players, _EXPECTED_PER_FACTION])
	if enemies != _EXPECTED_PER_FACTION:
		out.append("%s: ENEMY 單位數 %d,應為 %d" % [label, enemies, _EXPECTED_PER_FACTION])
	return out


func test_every_campaign_row_loads_with_correct_board_and_units() -> void:
	var records: Array = _records()
	assert_int(records.size()).append_failure_message("序列表應有 5 列").is_equal(5)

	for rec: CampaignSequence in records:
		var instance: BattleScreen = _load_row(rec)
		var label: String = "第 %d 場" % rec.mission_index
		var resolved: Dictionary = instance.diagnostic_resolved_data_paths()
		assert_str(resolved.get("terrain", "")).append_failure_message(label).is_equal(rec.terrain_path)
		assert_str(resolved.get("roster", "")).append_failure_message(label).is_equal(rec.roster_path)
		var v: Array[String] = _violations(instance, label)
		assert_array(v).append_failure_message("\n".join(v)).is_empty()
		remove_child(instance)


# ── 敏感度證明(常駐):故意壞掉的輸入,偵測器必須抓到 ────────────────────────
func test_sensitivity_proof_wrong_roster_shape_is_detected() -> void:
	var rec: CampaignSequence = _records()[2]
	# 地形 vs03(13x6)搭配 duel 名冊(單位數不是 5+5)→ 單位數違規
	var instance: BattleScreen = _load_row(rec, _BAD_ROSTER_PATH)
	var v: Array[String] = _violations(instance, "mutant")
	assert_bool(v.size() > 0).append_failure_message(
		"偵測器必須能抓到單位數不符(或載入失敗)的名冊"
	).is_true()
	remove_child(instance)


func test_sensitivity_proof_missing_file_is_detected_as_load_failure() -> void:
	var rec: CampaignSequence = _records()[2]
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.terrain_path_override = "res://assets/data/levels/vs99_does_not_exist.txt"
	instance.roster_path_override = rec.roster_path
	add_child(instance)
	var v: Array[String] = _violations(instance, "mutant")
	assert_bool(v.size() > 0 and instance._load_failed).is_true()
	remove_child(instance)
