# Story 018 直傷卡(傷害、擊殺清理、視線/射程、版本號與守衛)的單元測試。
# production/epics/skill-card-system/story-018-direct-damage-card-and-kill-chain.md
#
# 檔案存取:無(全為記憶體內夾具;卡牌用記憶體內 Card,14 張牌的資料列屬 story-022)。
#
# 敏感度證明(常駐 test_sensitivity_proof_*):CardPlaySession 的私有 seam 可被子類別覆寫,
# 每個 mutant 跑與真品相同的情境函式,真品必須回 true、mutant 必須回 false;
# 一個 mutant 一條獨立測試。
# 證明不了的(誠實登記):
#  ⑦「窗口外可呼叫」:守衛在 BattleState.resolve_direct_damage 內,而 BattleState.create()
#    寫死 BattleState.new(),set_script() 會把已建好的位置表/棋盤清回預設,沒有可注入的 seam
#    (D 類:唯一有意義的注入點在受限範圍外)。AC5 的窗口外拒絕以真品斷言(hp 不變、回 -1)覆蓋,
#    但「守衛被拿掉會紅」本檔證明不了。
#  ③「不呼叫勝負判定」在整合測試檔(需要 BattleController)。
extends GdUnitTestSuite

const _ROW_OPEN: String = "............."


# ---- 夾具 -------------------------------------------------------------------

## 13x6 空地;[param log_row0] 為 true 時 (2,0) 放倒木(擋視線)。
func _terrain(log_row0: bool) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	rows.append("..#.........." if log_row0 else _ROW_OPEN)
	for i: int in range(5):
		rows.append(_ROW_OPEN)
	return rows


## 我方 1(射程 1~1,(0,0))、2(射程 2~6,(0,1)),敵人 9(格子由參數給,hp 由參數給,DEF 50)。
func _build_state(enemy_x: int, enemy_y: int, enemy_hp: int, log_row0: bool = false, enemy_def: int = 50) -> BattleState:
	var lines: Array[String] = []
	lines.append("1,P1,PLAYER,20,10,3,1,1,1,0,0")
	lines.append("2,P2,PLAYER,22,10,3,1,2,6,0,1")
	lines.append("9,E1,ENEMY,%d,5,%d,1,1,1,%d,%d" % [enemy_hp, enemy_def, enemy_x, enemy_y])
	return BattleState.create(_terrain(log_row0), "\n".join(lines))


func _session(script: GDScript, state: BattleState, cards: Array[Card]) -> CardPlaySession:
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = script.new(deck, state, links, NullAffinityWritePort.new())
	session.attach_affinity_pool(AffinityDataPool.new())
	return session


## 直傷卡:施放者 [param caster] 付 [param cost] 血,對射程內可視敵人 [param damage] 固定傷害。
func _damage_card(caster: int, damage: int, cost: int = 3) -> Card:
	var card: Card = Card.new()
	card.id = "dd_%d" % damage
	card.category = Card.Category.DIRECT_DAMAGE
	card.cost_type = Card.CostType.HP
	card.cost_amount = cost
	card.effect_value = damage
	card.named_unit_id = caster
	return card


## 跑完整一次出牌(選牌 -> 選敵 -> 確認)。回傳 {confirmed, killed_ids, hp, state}。
func _play(script: GDScript, state: BattleState, card: Card, enemy_id: int = 9) -> Dictionary:
	var cards: Array[Card] = [card]
	var session: CardPlaySession = _session(script, state, cards)
	var killed: Array[int] = []
	session.attach_kill_hook(func(unit_id: int) -> void:
		killed.append(unit_id)
	)
	var ok: bool = session.open_hand()
	ok = ok and session.select_card(card)
	ok = ok and session.select_target(enemy_id)
	ok = ok and session.confirm()
	return {"confirmed": ok, "killed": killed, "session": session}


## 清理狀態快照:格子占位、位置表是否還有、unit_at。
func _cleanup_snapshot(state: BattleState, pos: Vector2i, id: int) -> Dictionary:
	return {
		"occupant": state.board.get_occupant(pos),
		"in_positions": state._positions.has(id),
		"unit_at_null": state.unit_at(pos) == null,
	}


# ---- AC1 傷害 ---------------------------------------------------------------

func test_direct_damage_equals_effect_value_ignoring_def() -> void:
	# Arrange:敵人 DEF 50、hp 30;施放者 1 在 (0,0),敵人緊鄰 (1,0)。
	var state: BattleState = _build_state(1, 0, 30)
	# Act
	var result: Dictionary = _play(CardPlaySession, state, _damage_card(1, 12))
	# Assert
	assert_bool(result["confirmed"]).is_true()
	assert_int(state.unit_by_id(9).hp).is_equal(18)


func test_direct_damage_same_input_same_result_no_rng() -> void:
	var first: BattleState = _build_state(1, 0, 30)
	var second: BattleState = _build_state(1, 0, 30)
	_play(CardPlaySession, first, _damage_card(1, 12))
	_play(CardPlaySession, second, _damage_card(1, 12))
	assert_int(first.unit_by_id(9).hp).is_equal(second.unit_by_id(9).hp)


func test_direct_damage_overkill_is_clipped_to_current_hp() -> void:
	var state: BattleState = _build_state(1, 0, 5)
	var result: Dictionary = _play(CardPlaySession, state, _damage_card(1, 12))
	var session: CardPlaySession = result["session"]
	assert_int(session.last_direct_damage_amount()).is_equal(5)


# ---- AC2 擊殺 ---------------------------------------------------------------

func test_direct_damage_kill_clears_tile_and_reports_kill() -> void:
	var state: BattleState = _build_state(1, 0, 5)
	var result: Dictionary = _play(CardPlaySession, state, _damage_card(1, 12))
	var snap: Dictionary = _cleanup_snapshot(state, Vector2i(1, 0), 9)
	assert_bool(result["confirmed"]).is_true()
	assert_bool(snap["unit_at_null"]).is_true()
	assert_bool(snap["in_positions"]).is_false()
	assert_array(result["killed"]).is_equal([9])
	var session: CardPlaySession = result["session"]
	assert_bool(session.last_direct_damage_killed()).is_true()


func test_direct_damage_non_kill_does_not_clear_or_report() -> void:
	var state: BattleState = _build_state(1, 0, 30)
	var result: Dictionary = _play(CardPlaySession, state, _damage_card(1, 12))
	assert_bool(state.unit_at(Vector2i(1, 0)) != null).is_true()
	assert_array(result["killed"]).is_empty()


# ---- AC3 共用清理 -----------------------------------------------------------

## 一般攻擊擊殺 vs 直傷擊殺:兩邊 BattleState 的占位/位置表狀態必須相同(皆已清除)。
func _kill_paths_agree(script: GDScript) -> bool:
	# 一般攻擊路徑用 DEF 0,才保證打得死(DEF 50 時傷害為 0,不會擊殺)。
	var by_attack: BattleState = _build_state(1, 0, 1, false, 0)
	by_attack.resolve_attack(1, 9, 0)
	var by_card: BattleState = _build_state(1, 0, 1)
	_play(script, by_card, _damage_card(1, 12))
	var a: Dictionary = _cleanup_snapshot(by_attack, Vector2i(1, 0), 9)
	var b: Dictionary = _cleanup_snapshot(by_card, Vector2i(1, 0), 9)
	return a == b and a["in_positions"] == false


func test_direct_damage_kill_cleanup_matches_attack_kill_cleanup() -> void:
	assert_bool(_kill_paths_agree(CardPlaySession)).is_true()


# ---- AC4 視線/射程 ----------------------------------------------------------

func test_direct_damage_enemy_behind_sight_blocker_is_not_a_target() -> void:
	# 施放者 2(射程 2~6)在 (0,1),倒木在 (2,1),敵人在 (4,1) -> 被擋。
	assert_array(_targets_for_ranged_caster(CardPlaySession, true)).is_empty()


func test_direct_damage_enemy_in_open_line_within_range_is_a_target() -> void:
	assert_array(_targets_for_ranged_caster(CardPlaySession, false)).is_equal([9])


## 施放者 2(射程 2~6)在 (0,1);敵人在 (4,1)(距離 4);[param blocked]:在 (2,1) 放倒木。
func _targets_for_ranged_caster(script: GDScript, blocked: bool) -> Array[int]:
	var rows: PackedStringArray = PackedStringArray()
	for y: int in range(8):
		var row: String = _ROW_OPEN
		if y == 1 and blocked:
			row = "..#....."
		rows.append(row)
	var lines: Array[String] = []
	lines.append("1,P1,PLAYER,20,10,3,1,1,1,0,5")
	lines.append("2,P2,PLAYER,22,10,3,1,2,6,0,1")
	lines.append("9,E1,ENEMY,20,5,3,1,1,1,4,1")
	var state: BattleState = BattleState.create(rows, "\n".join(lines))
	var card: Card = _damage_card(2, 8)
	var cards: Array[Card] = [card]
	var session: CardPlaySession = _session(script, state, cards)
	session.open_hand()
	session.select_card(card)
	return session.legal_targets()


func test_direct_damage_range_boundary_max_plus_one_is_not_a_target() -> void:
	# 施放者 1(射程 1~1)在 (0,0):(1,0) 距離 1 可打;(2,0) 距離 2 = max+1 不可打。
	assert_array(_targets_for_melee_caster(CardPlaySession, 1)).is_equal([9])
	assert_array(_targets_for_melee_caster(CardPlaySession, 2)).is_empty()


func _targets_for_melee_caster(script: GDScript, enemy_x: int) -> Array[int]:
	var state: BattleState = _build_state(enemy_x, 0, 20)
	var card: Card = _damage_card(1, 8)
	var cards: Array[Card] = [card]
	var session: CardPlaySession = _session(script, state, cards)
	session.open_hand()
	session.select_card(card)
	return session.legal_targets()


# ---- AC5 版本號與守衛 -------------------------------------------------------

func test_direct_damage_card_bumps_combat_state_version_exactly_once() -> void:
	var state: BattleState = _build_state(1, 0, 5)
	var before: int = state.combat_state_version
	_play(CardPlaySession, state, _damage_card(1, 12))
	assert_int(state.combat_state_version).is_equal(before + 1)


func test_direct_damage_resolve_outside_window_is_rejected_and_writes_nothing() -> void:
	var state: BattleState = _build_state(1, 0, 20)
	var before_version: int = state.combat_state_version
	var dealt: int = state.resolve_direct_damage(9, 8)
	assert_int(dealt).is_equal(-1)
	assert_int(state.unit_by_id(9).hp).is_equal(20)
	assert_int(state.combat_state_version).is_equal(before_version)


func test_direct_damage_payer_hp_cost_is_paid_once() -> void:
	var state: BattleState = _build_state(1, 0, 30)
	_play(CardPlaySession, state, _damage_card(1, 12, 3))
	assert_int(state.unit_by_id(1).hp).is_equal(17)


# ---- AC6 敏感度證明(一個 mutant 一條獨立測試)-------------------------------

class _MutantKillWithoutClearing extends CardPlaySession:
	# ① 擊殺不清佔位:直接扣光 hp,不經共用清理。
	func _apply_direct_damage_in_window(_caster_id: int, enemy_id: int, _effect_value: int) -> void:
		var enemy: Unit = _state.unit_by_id(enemy_id)
		enemy.take_damage(enemy.hp)
		_notify_kill(enemy_id)


class _MutantKillNotReportedToOrder extends CardPlaySession:
	# ② 擊殺不移出行動序:吞掉 kill hook。
	func _notify_kill(_unit_id: int) -> void:
		pass


class _MutantCopiedCleanupForgetsPositions extends CardPlaySession:
	# ④ 複製貼上一份清理,漏掉位置表:格子清了、_positions 沒清。
	func _apply_direct_damage_in_window(_caster_id: int, enemy_id: int, _effect_value: int) -> void:
		var enemy: Unit = _state.unit_by_id(enemy_id)
		var pos: Vector2i = _state.position_of(enemy_id)
		enemy.take_damage(enemy.hp)
		_state.board._clear_occupant(pos)
		_notify_kill(enemy_id)


class _MutantDamageAppliesDef extends CardPlaySession:
	# ⑤ 傷害套用 DEF。
	func _direct_damage_amount(enemy: Unit, effect_value: int) -> int:
		return mini(maxi(effect_value - enemy.def, 0), enemy.hp)


class _MutantIgnoresLineOfSight extends CardPlaySession:
	# ⑥ 視線檢查略過:任何存活敵人都算在射程內。
	func _enemy_in_reach(_caster_id: int, _enemy_id: int) -> bool:
		return true


func _kill_scenario_cleans_tile(script: GDScript) -> bool:
	var state: BattleState = _build_state(1, 0, 5)
	_play(script, state, _damage_card(1, 12))
	var snap: Dictionary = _cleanup_snapshot(state, Vector2i(1, 0), 9)
	return snap["unit_at_null"] and snap["in_positions"] == false


func _kill_scenario_reports_to_order(script: GDScript) -> bool:
	var state: BattleState = _build_state(1, 0, 5)
	var result: Dictionary = _play(script, state, _damage_card(1, 12))
	var killed: Array = result["killed"]
	return killed == [9]


func _damage_scenario_ignores_def(script: GDScript) -> bool:
	var state: BattleState = _build_state(1, 0, 30)
	_play(script, state, _damage_card(1, 12))
	return state.unit_by_id(9).hp == 18


func test_sensitivity_proof_kill_without_clearing_tile_is_caught() -> void:
	assert_bool(_kill_scenario_cleans_tile(CardPlaySession)).is_true()
	assert_bool(_kill_scenario_cleans_tile(_MutantKillWithoutClearing)).is_false()


func test_sensitivity_proof_kill_not_removed_from_order_is_caught() -> void:
	assert_bool(_kill_scenario_reports_to_order(CardPlaySession)).is_true()
	assert_bool(_kill_scenario_reports_to_order(_MutantKillNotReportedToOrder)).is_false()


func test_sensitivity_proof_copied_cleanup_diverging_from_attack_path_is_caught() -> void:
	assert_bool(_kill_paths_agree(CardPlaySession)).is_true()
	assert_bool(_kill_paths_agree(_MutantCopiedCleanupForgetsPositions)).is_false()


func test_sensitivity_proof_damage_applying_def_is_caught() -> void:
	assert_bool(_damage_scenario_ignores_def(CardPlaySession)).is_true()
	assert_bool(_damage_scenario_ignores_def(_MutantDamageAppliesDef)).is_false()


func test_sensitivity_proof_ignoring_line_of_sight_is_caught() -> void:
	assert_array(_targets_for_ranged_caster(CardPlaySession, true)).is_empty()
	assert_array(_targets_for_ranged_caster(_MutantIgnoresLineOfSight, true)).is_equal([9])
