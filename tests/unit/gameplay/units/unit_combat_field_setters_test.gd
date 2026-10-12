## tests/unit/gameplay/units/unit_combat_field_setters_test.gd
##
## Story: production/epics/tactical-combat/story-017-unit-combat-field-setters.md
## (戰棋 #4 epic, ADR-0001 硬性義務第 2 條)。
##
## Covers [Unit]'s six combat-value fields (hp/atk/def/mp/min_range/max_range)
## becoming guarded properties enforcing ADR-0001's atomic write window —
## mirrors the Board/TurnOrder guard pattern established by story-003b
## (tests/unit/gameplay/battle/mutator_guard_rejection_test.gd), which this
## file does NOT modify or duplicate (that file's 7 existing Board/TurnOrder
## vectors are untouched; this file adds the 6 new Unit vectors AC6 requires,
## each field independently, in its own file per the story's Affected Files
## guidance).
##
## 🔴 Required-evidence conflict, flagged per dispatch instructions rather
## than silently resolved: the story's own "Test Evidence" section asks for
## a manual-injection sensitivity proof ("故意錯誤實作, 重跑對應測試確認會
## 轉紅, 改回"). .claude/rules/test-standards.md's 2026-09-16 ruling
## deprecates exactly that technique ("已淘汰, 理由是它在版本庫裡不留任何
## 痕跡") and requires either a spy-subclass test_sensitivity_proof_* or a
## written, per-item "why this can't be proven" note. Neither applies cleanly
## here: every test below directly exercises the real, unmodified production
## setter/guard/take_damage()/BattleState.create() code (no reimplementation,
## no mock, no static pure function, no RNG) — if the guard check were
## removed from a setter, or the create() mounting loop were deleted, or
## take_damage() were changed to route through the guarded setter, the
## corresponding test(s) below would go red immediately on their own, with
## zero extra scaffolding. This is the same structural proof
## mutator_guard_rejection_test.gd itself relies on for its 7 Board/TurnOrder
## vectors (grep that file: no spy subclass, no injected mutant — just
## assert_error()+value-unchanged against real code), and that file is
## Done. No manual injection was performed; disclosing this explicitly
## rather than fabricating a revert log, per the registered lesson in
## test-standards.md ("一支工作單宣稱已注入, 而 grep 命中為 0, 作廢重做").
##
## No Node is ever constructed — Unit/Board/TurnOrder/BattleState are all
## RefCounted, so no test here can leave an orphan.
extends GdUnitTestSuite


# ---- fixtures ---------------------------------------------------------------

# A roster line with six distinguishable combat values (hp_max=30, atk=16,
# def=8, mp=6, min_range=1, max_range=3 — min_range != max_range deliberately,
# so a test that accidentally reads the wrong one of the pair fails loudly).
func _roster_line() -> String:
	return "1,甲,PLAYER,30,16,8,6,1,3,0,2"


# A write-window guard that always reports the window CLOSED — isolates
# Unit's own setter+guard logic from BattleState's wiring correctness (the
# latter gets its own dedicated tests below using real BattleState.create()).
func _closed_window_guard() -> Callable:
	return func() -> bool:
		return false


# ---- AC2 / AC6 — six independent "mounted guard, window not open" vectors --
#
# Each field gets its own test (story AC6: "六個欄位各一條,不得合併成一條
# 只測其中一個") so one field's guard failing can never mask another's.

func test_hp_setter_rejected_when_write_window_not_open() -> void:
	# Arrange
	var unit: Unit = Unit.from_csv_line(_roster_line())
	unit.attach_write_guard(_closed_window_guard())
	var original: int = unit.hp

	# Act
	var call_set: Callable = func() -> void:
		unit.hp = original + 100

	# Assert
	await assert_error(call_set).is_push_error(any_string())
	assert_int(unit.hp).is_equal(original)


func test_atk_setter_rejected_when_write_window_not_open() -> void:
	# Arrange
	var unit: Unit = Unit.from_csv_line(_roster_line())
	unit.attach_write_guard(_closed_window_guard())
	var original: int = unit.atk

	# Act
	var call_set: Callable = func() -> void:
		unit.atk = original + 100

	# Assert
	await assert_error(call_set).is_push_error(any_string())
	assert_int(unit.atk).is_equal(original)


func test_def_setter_rejected_when_write_window_not_open() -> void:
	# Arrange
	var unit: Unit = Unit.from_csv_line(_roster_line())
	unit.attach_write_guard(_closed_window_guard())
	var original: int = unit.def

	# Act
	var call_set: Callable = func() -> void:
		unit.def = original + 100

	# Assert
	await assert_error(call_set).is_push_error(any_string())
	assert_int(unit.def).is_equal(original)


func test_mp_setter_rejected_when_write_window_not_open() -> void:
	# Arrange
	var unit: Unit = Unit.from_csv_line(_roster_line())
	unit.attach_write_guard(_closed_window_guard())
	var original: int = unit.mp

	# Act
	var call_set: Callable = func() -> void:
		unit.mp = original + 100

	# Assert
	await assert_error(call_set).is_push_error(any_string())
	assert_int(unit.mp).is_equal(original)


func test_min_range_setter_rejected_when_write_window_not_open() -> void:
	# Arrange
	var unit: Unit = Unit.from_csv_line(_roster_line())
	unit.attach_write_guard(_closed_window_guard())
	var original: int = unit.min_range

	# Act
	var call_set: Callable = func() -> void:
		unit.min_range = original + 100

	# Assert
	await assert_error(call_set).is_push_error(any_string())
	assert_int(unit.min_range).is_equal(original)


func test_max_range_setter_rejected_when_write_window_not_open() -> void:
	# Arrange
	var unit: Unit = Unit.from_csv_line(_roster_line())
	unit.attach_write_guard(_closed_window_guard())
	var original: int = unit.max_range

	# Act
	var call_set: Callable = func() -> void:
		unit.max_range = original + 100

	# Assert
	await assert_error(call_set).is_push_error(any_string())
	assert_int(unit.max_range).is_equal(original)


# ---- AC2 — unmounted guard (selective-mount default) still permits direct
# assignment, for all six fields at once (backward compatibility with the
# project's existing 9+ pre-story call sites) -----------------------------

func test_unmounted_unit_allows_direct_assignment_to_all_six_fields() -> void:
	# Arrange — never attached to any guard, same as every existing
	# Unit.from_csv_line() fixture across the project that never goes
	# through BattleState at all (e.g. combat_rules_test.gd).
	var unit: Unit = Unit.from_csv_line(_roster_line())

	# Act
	unit.hp = 5
	unit.atk = 99
	unit.def = 98
	unit.mp = 7
	unit.min_range = 2
	unit.max_range = 9

	# Assert — every assignment took effect, exactly as a plain `var` would
	# have before this story
	assert_int(unit.hp).is_equal(5)
	assert_int(unit.atk).is_equal(99)
	assert_int(unit.def).is_equal(98)
	assert_int(unit.mp).is_equal(7)
	assert_int(unit.min_range).is_equal(2)
	assert_int(unit.max_range).is_equal(9)


# ---- AC5 — from_csv_line()'s six internal assignments are unaffected ------

func test_from_csv_line_internal_assignments_unaffected_by_guard() -> void:
	# Arrange / Act — Unit.from_csv_line() constructs a fresh, unguarded Unit
	# (no guard is attached until a later BattleState.create() call, if ever)
	var unit: Unit = Unit.from_csv_line(_roster_line())

	# Assert
	assert_int(unit.hp).is_equal(30)
	assert_int(unit.atk).is_equal(16)
	assert_int(unit.def).is_equal(8)
	assert_int(unit.mp).is_equal(6)
	assert_int(unit.min_range).is_equal(1)
	assert_int(unit.max_range).is_equal(3)


# ---- AC3 — BattleState.create() actually mounts the guard on each Unit ----
#
# The six tests above prove Unit's OWN setter+guard logic is correct using a
# manually-constructed Callable; these two prove create() really wires
# Callable(state, "write_window_is_open") onto every Unit it builds — not
# just that *some* Callable rejects writes.

func test_battle_state_create_mounts_guard_rejecting_direct_write_when_window_not_open() -> void:
	# Arrange — real BattleState.create(); write window has never been
	# opened (commit_authoritative_change() never called). Empty terrain
	# PackedStringArray, same minimal-fixture pattern as
	# mutator_guard_rejection_test.gd / commit_authoritative_change_version_test.gd.
	var state: BattleState = BattleState.create(PackedStringArray(), _roster_line())
	var unit: Unit = state.unit_by_id(1)
	var original: int = unit.hp

	# Act
	var call_set: Callable = func() -> void:
		unit.hp = original + 50

	# Assert
	await assert_error(call_set).is_push_error(any_string())
	assert_int(unit.hp).is_equal(original)


func test_battle_state_create_mounted_guard_allows_write_inside_commit_window() -> void:
	# Arrange
	var state: BattleState = BattleState.create(PackedStringArray(), _roster_line())
	var unit: Unit = state.unit_by_id(1)

	# Act — mutator runs INSIDE commit_authoritative_change(), the same
	# shape every real production mutator uses (ADR-0001 Mechanism One)
	state.commit_authoritative_change(func() -> void:
		unit.hp = 5
	)

	# Assert — proves the guard is not unconditionally rejecting; it tracks
	# the real write-window state
	assert_int(unit.hp).is_equal(5)


# ---- AC4 — take_damage() compatibility (選項 B: bypasses the guard) --------

func test_take_damage_bypasses_guard_when_window_not_open_unmounted_unit() -> void:
	# Arrange
	var unit: Unit = Unit.from_csv_line(_roster_line())
	unit.attach_write_guard(_closed_window_guard())
	var before: int = unit.hp

	# Act
	unit.take_damage(10)

	# Assert — take_damage() succeeded despite the guard reporting the
	# write window closed (story-017 "未決的實作細節" 第 1 項, 選項 B)
	assert_int(unit.hp).is_equal(before - 10)


func test_take_damage_bypasses_guard_on_battle_state_created_unit_when_window_not_open() -> void:
	# Arrange — real BattleState.create() wiring, window never opened
	var state: BattleState = BattleState.create(PackedStringArray(), _roster_line())
	var unit: Unit = state.unit_by_id(1)
	var before: int = unit.hp

	# Act
	unit.take_damage(7)

	# Assert
	assert_int(unit.hp).is_equal(before - 7)


func test_take_damage_succeeds_while_direct_hp_assignment_is_rejected_same_unit_same_window() -> void:
	# Arrange — contrasts both paths side by side on the SAME Unit, the SAME
	# (closed) window state, directly demonstrating story-017's Option B
	# design decision end-to-end in a single test.
	var unit: Unit = Unit.from_csv_line(_roster_line())
	unit.attach_write_guard(_closed_window_guard())
	var before: int = unit.hp

	# Act 1 — direct assignment through the guarded setter: rejected
	var call_set: Callable = func() -> void:
		unit.hp = before + 1
	await assert_error(call_set).is_push_error(any_string())
	assert_int(unit.hp).is_equal(before)

	# Act 2 — take_damage(): bypasses the guard, succeeds unconditionally
	unit.take_damage(3)

	# Assert
	assert_int(unit.hp).is_equal(before - 3)


func test_take_damage_still_clamps_at_zero_and_clears_modifiers_when_guard_mounted_and_window_closed() -> void:
	# Arrange — regression guard: the guard-bypass change to take_damage()
	# must not alter its existing clamp/modifier-clear behavior (already
	# covered unguarded by unit_test.gd; this repeats it under a mounted,
	# closed-window guard to prove the bypass doesn't also skip the clamp).
	var unit: Unit = Unit.from_csv_line(_roster_line())
	unit.attach_write_guard(_closed_window_guard())
	var modifier: CardModifier = CardModifier.new()
	modifier.source_name = "test"
	modifier.atk_delta = 1
	modifier.def_delta = 0
	modifier.remaining_turns = 3
	unit.add_modifier(modifier)

	# Act
	unit.take_damage(9999)

	# Assert
	assert_int(unit.hp).is_equal(0)
	assert_bool(unit.is_alive()).is_false()
	assert_array(unit.active_modifiers()).is_empty()
