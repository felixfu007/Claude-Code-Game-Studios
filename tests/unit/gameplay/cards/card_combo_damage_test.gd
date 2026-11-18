# Story 019 合擊直傷卡 c12 交叉火力(董振豪 x 秦亦柔)的單元測試。
# production/epics/skill-card-system/story-019-combo-damage-card.md
#
# 檔案存取:無(全為記憶體內夾具與記憶體內 Card;14 張牌的資料列屬 story-022)。
# 夾具以單位 id 1、2 代表兩名攻擊者(id -> 角色序號只用於配對,id 1/2 是合法一對)。
#
# 敏感度證明(常駐 test_sensitivity_proof_*):CardPlaySession 的私有 seam 可被子類別覆寫,
# 每個 mutant 跑與真品相同的情境函式,真品必須回 true、mutant 必須回 false;
# 一個 mutant 一條獨立測試。
# 證明不了的(誠實登記):AC5 的「全庫沒有第二份直傷結算」是原始碼層面的斷言,
# 本檔只證明「合擊的擊殺清理與直傷同一條路徑」(mutant ⑤);全庫無第二份由交件回報的 grep 證據覆蓋。
extends GdUnitTestSuite


# ---- 夾具 -------------------------------------------------------------------

## 一列 13 格(y=0),[param logs] 的 x 放倒木(擋視線)。
func _terrain(logs: Array[int]) -> PackedStringArray:
	var row: String = ""
	for x: int in range(13):
		row += "#" if logs.has(x) else "."
	var rows: PackedStringArray = PackedStringArray()
	rows.append(row)
	for i: int in range(5):
		rows.append(".............")
	return rows


## 我方 1、2(hp 20)在 y=0 的 [param p1x]/[param p2x],射程 1~rmax;敵人 9 在 [param enemy_x]。
func _build_state(p1x: int, p2x: int, enemy_x: int, enemy_hp: int, rmax1: int, rmax2: int, logs: Array[int] = []) -> BattleState:
	var lines: Array[String] = []
	lines.append("1,P1,PLAYER,20,10,3,1,1,%d,%d,0" % [rmax1, p1x])
	lines.append("2,P2,PLAYER,20,10,3,1,1,%d,%d,0" % [rmax2, p2x])
	lines.append("9,E1,ENEMY,%d,5,50,1,1,1,%d,0" % [enemy_hp, enemy_x])
	return BattleState.create(_terrain(logs), "\n".join(lines))


func _default_state(enemy_hp: int = 30) -> BattleState:
	return _build_state(0, 1, 3, enemy_hp, 6, 6)


## c12 型:1、2 兩人付代價(空池 -> 關係態 NONE -> 各付 3 血),各對同一敵人 6,target_range = -1。
func _c12() -> Card:
	var card: Card = Card.new()
	card.id = "c12"
	card.category = Card.Category.COMBO_DAMAGE
	card.cost_type = Card.CostType.PAIR
	card.cost_amount = 2
	card.effect_value = 6
	card.named_unit_id = 1
	card.partner_unit_id = 2
	card.target_range = -1
	return card


func _session(script: GDScript, state: BattleState, card: Card) -> CardPlaySession:
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = script.new(deck, state, links, NullAffinityWritePort.new())
	session.attach_affinity_pool(AffinityDataPool.new())
	return session


## 完整出牌(選牌 -> 選敵 -> 確認)。回傳 {confirmed, killed, session, version_before}。
func _play(script: GDScript, state: BattleState, enemy_id: int = 9) -> Dictionary:
	var card: Card = _c12()
	var session: CardPlaySession = _session(script, state, card)
	var killed: Array[int] = []
	session.attach_kill_hook(func(unit_id: int) -> void:
		killed.append(unit_id)
	)
	var before: int = state.combat_state_version
	var ok: bool = session.open_hand()
	ok = ok and session.select_card(card)
	ok = ok and session.select_target(enemy_id)
	ok = ok and session.confirm()
	return {"confirmed": ok, "killed": killed, "session": session, "version_before": before}


## 選到選敵步驟後的合法敵人清單(未選到則回空)。
func _legal(script: GDScript, state: BattleState) -> Array[int]:
	var card: Card = _c12()
	var session: CardPlaySession = _session(script, state, card)
	var empty: Array[int] = []
	if not session.open_hand() or not session.select_card(card):
		return empty
	return session.legal_targets()


func _cleanup_snapshot(state: BattleState, pos: Vector2i, id: int) -> Dictionary:
	return {
		"unit_at_null": state.unit_at(pos) == null,
		"in_positions": state._positions.has(id),
	}


# ---- AC1 兩擊 ---------------------------------------------------------------

func test_combo_damage_both_attackers_hit_for_effect_value_each() -> void:
	var state: BattleState = _default_state(30)
	var result: Dictionary = _play(CardPlaySession, state)
	assert_bool(result["confirmed"]).is_true()
	assert_int(state.unit_by_id(9).hp).is_equal(18)
	var session: CardPlaySession = result["session"]
	assert_int(session.last_direct_damage_amount()).is_equal(12)
	assert_bool(session.last_direct_damage_killed()).is_false()


func test_combo_damage_both_attackers_pay_cost() -> void:
	var state: BattleState = _default_state(30)
	_play(CardPlaySession, state)
	assert_int(state.unit_by_id(1).hp).is_equal(17)
	assert_int(state.unit_by_id(2).hp).is_equal(17)


func test_combo_damage_ignores_distance_between_attackers() -> void:
	# 兩人相距 12 格(c12 不限距離,target_range = -1),敵人在兩人射程內。
	var state: BattleState = _build_state(0, 12, 6, 30, 12, 12)
	assert_array(_legal(CardPlaySession, state)).is_equal([9])
	var result: Dictionary = _play(CardPlaySession, state)
	assert_bool(result["confirmed"]).is_true()
	assert_int(state.unit_by_id(9).hp).is_equal(18)


# ---- AC2 第一擊擊殺 ---------------------------------------------------------

func test_combo_damage_first_hit_kill_skips_second_and_runs_kill_chain_once() -> void:
	var state: BattleState = _default_state(5)
	var result: Dictionary = _play(CardPlaySession, state)
	var session: CardPlaySession = result["session"]
	assert_bool(result["confirmed"]).is_true()
	assert_array(result["killed"]).is_equal([9])
	assert_int(session.last_direct_damage_amount()).is_equal(5)
	assert_bool(session.last_direct_damage_killed()).is_true()
	assert_bool(_cleanup_snapshot(state, Vector2i(3, 0), 9)["unit_at_null"]).is_true()
	# 代價不退。
	assert_int(state.unit_by_id(1).hp).is_equal(17)
	assert_int(state.unit_by_id(2).hp).is_equal(17)


func test_combo_damage_second_hit_kill_reports_total_and_kill_once() -> void:
	# hp 8:第一擊 6、第二擊補足 2(夾限)擊殺。
	var state: BattleState = _default_state(8)
	var result: Dictionary = _play(CardPlaySession, state)
	var session: CardPlaySession = result["session"]
	assert_array(result["killed"]).is_equal([9])
	assert_int(session.last_direct_damage_amount()).is_equal(8)
	assert_bool(session.last_direct_damage_killed()).is_true()


# ---- AC3 射程交集 / 雙方存活 ------------------------------------------------

func test_combo_damage_enemy_in_reach_of_both_is_legal() -> void:
	assert_array(_legal(CardPlaySession, _default_state())).is_equal([9])


func test_combo_damage_enemy_out_of_range_of_second_attacker_is_not_legal() -> void:
	# 2 在 (1,0),敵人 (3,0) 距離 2;射程 1 -> 打不到。
	assert_array(_legal(CardPlaySession, _build_state(0, 1, 3, 30, 6, 1))).is_empty()


func test_combo_damage_enemy_out_of_range_of_first_attacker_is_not_legal() -> void:
	# 1 在 (0,0),敵人 (3,0) 距離 3;射程 2 -> 打不到。
	assert_array(_legal(CardPlaySession, _build_state(0, 1, 3, 30, 2, 6))).is_empty()


func test_combo_damage_enemy_blocked_for_first_attacker_only_is_not_legal() -> void:
	# 1 在 (0,0)、倒木 (2,0)、敵人 (5,0);2 在 (4,0) 視線通暢。
	var logs: Array[int] = [2]
	assert_array(_legal(CardPlaySession, _build_state(0, 4, 5, 30, 6, 6, logs))).is_empty()


func test_combo_damage_enemy_blocked_for_second_attacker_only_is_not_legal() -> void:
	# 2 在 (8,0)、倒木 (6,0)、敵人 (5,0);1 在 (0,0) 視線通暢。
	var logs: Array[int] = [6]
	assert_array(_legal(CardPlaySession, _build_state(0, 8, 5, 30, 6, 6, logs))).is_empty()


func test_combo_damage_card_unplayable_when_first_attacker_dead() -> void:
	var state: BattleState = _default_state()
	state.unit_by_id(1).take_damage(999)
	var session: CardPlaySession = _session(CardPlaySession, state, _c12())
	assert_bool(session.is_card_playable(_c12())).is_false()


func test_combo_damage_card_unplayable_when_second_attacker_dead() -> void:
	var state: BattleState = _default_state()
	state.unit_by_id(2).take_damage(999)
	var session: CardPlaySession = _session(CardPlaySession, state, _c12())
	assert_bool(session.is_card_playable(_c12())).is_false()


# ---- AC4 版本號 +1 ----------------------------------------------------------

func test_combo_damage_bumps_combat_state_version_exactly_once() -> void:
	var state: BattleState = _default_state()
	var result: Dictionary = _play(CardPlaySession, state)
	assert_int(state.combat_state_version - int(result["version_before"])).is_equal(1)


# ---- AC6 敏感度證明 ---------------------------------------------------------

class _MutantOnlyOneAttacker extends CardPlaySession:
	# ① 只有一人出手。
	func _combo_attackers(attacker_a: int, _attacker_b: int) -> Array[int]:
		return [attacker_a]


class _MutantSecondHitAfterKill extends CardPlaySession:
	# ② 第二擊打已死目標,且重複擊殺鏈。
	func _combo_hit_allowed(_enemy: Unit) -> bool:
		return true

	func _apply_direct_damage_in_window(caster_id: int, enemy_id: int, effect_value: int) -> void:
		var enemy: Unit = _state.unit_by_id(enemy_id)
		if not enemy.is_alive():
			_notify_kill(enemy_id)
			return
		super(caster_id, enemy_id, effect_value)


class _MutantUnionReach extends CardPlaySession:
	# ③ 射程交集改聯集。
	func _combo_legal_enemies(attacker_a: int, attacker_b: int) -> Array[int]:
		var result: Array[int] = _legal_enemy_targets(attacker_a)
		for enemy_id: int in _legal_enemy_targets(attacker_b):
			if not result.has(enemy_id):
				result.append(enemy_id)
		return result


class _MutantTwoCommitWindows extends CardPlaySession:
	# ④ 版本號 +2:卡牌結算後另開一個窗口。
	func confirm() -> bool:
		var ok: bool = super()
		_state.commit_authoritative_change(func() -> void:
			pass
		)
		return ok


class _MutantCopiedHitForgetsPositions extends CardPlaySession:
	# ⑤ 複製一份直傷結算,漏掉位置表:格子清了、_positions 沒清。
	func _combo_hit(_caster_id: int, enemy_id: int, _effect_value: int) -> void:
		var enemy: Unit = _state.unit_by_id(enemy_id)
		var pos: Vector2i = _state.position_of(enemy_id)
		enemy.take_damage(enemy.hp)
		_state.board._clear_occupant(pos)
		_notify_kill(enemy_id)


func _scenario_two_hits(script: GDScript) -> bool:
	var state: BattleState = _default_state(30)
	_play(script, state)
	return state.unit_by_id(9).hp == 18


func _scenario_kill_chain_once(script: GDScript) -> bool:
	var state: BattleState = _default_state(5)
	var result: Dictionary = _play(script, state)
	var killed: Array = result["killed"]
	return result["confirmed"] and killed == [9]


func _scenario_intersection_not_union(script: GDScript) -> bool:
	# 2 射程只有 1、敵人距離 2:只有 1 打得到 -> 交集為空。
	return _legal(script, _build_state(0, 1, 3, 30, 6, 1)).is_empty()


func _scenario_version_plus_one(script: GDScript) -> bool:
	var state: BattleState = _default_state()
	var result: Dictionary = _play(script, state)
	return state.combat_state_version - int(result["version_before"]) == 1


func _scenario_kill_cleanup_shared(script: GDScript) -> bool:
	var state: BattleState = _default_state(5)
	_play(script, state)
	var snap: Dictionary = _cleanup_snapshot(state, Vector2i(3, 0), 9)
	return snap["unit_at_null"] and snap["in_positions"] == false


func test_sensitivity_proof_only_one_attacker_hitting_is_caught() -> void:
	assert_bool(_scenario_two_hits(CardPlaySession)).is_true()
	assert_bool(_scenario_two_hits(_MutantOnlyOneAttacker)).is_false()


func test_sensitivity_proof_second_hit_after_kill_with_duplicate_chain_is_caught() -> void:
	assert_bool(_scenario_kill_chain_once(CardPlaySession)).is_true()
	assert_bool(_scenario_kill_chain_once(_MutantSecondHitAfterKill)).is_false()


func test_sensitivity_proof_reach_union_instead_of_intersection_is_caught() -> void:
	assert_bool(_scenario_intersection_not_union(CardPlaySession)).is_true()
	assert_bool(_scenario_intersection_not_union(_MutantUnionReach)).is_false()


func test_sensitivity_proof_version_bumped_twice_is_caught() -> void:
	assert_bool(_scenario_version_plus_one(CardPlaySession)).is_true()
	assert_bool(_scenario_version_plus_one(_MutantTwoCommitWindows)).is_false()


func test_sensitivity_proof_copied_settlement_diverging_from_shared_path_is_caught() -> void:
	assert_bool(_scenario_kill_cleanup_shared(CardPlaySession)).is_true()
	assert_bool(_scenario_kill_cleanup_shared(_MutantCopiedHitForgetsPositions)).is_false()
