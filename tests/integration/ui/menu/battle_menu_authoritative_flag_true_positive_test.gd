## Story U-019 — `AC-U8` / `AC-M8` true-positive tests: drive the REAL
## [BattleState] flag through a REAL [method BattleState.commit_authoritative_change]
## call, instead of the `func() -> bool: return true` stand-in every existing
## injection site uses.
## `production/epics/card-play-interface/story-u019-authoritative-flag-true-positive.md`
##
## [b]AC-3 — the four existing stand-in sites are NOT touched by this file[/b]:
## [code]tests/integration/ui/forced_discard_test.gd[/code],
## [code]tests/integration/ui/menu/battle_menu_gating_test.gd[/code] (two
## sites), [code]tests/integration/ui/menu/battle_menu_leave_confirmation_test.gd[/code].
## They prove "the gate is wired and rejects when told to" — a different,
## still-valid claim this file does not replace.
##
## [b]🔴 A fifth stand-in site exists that the work order's own reconnaissance
## did not find[/b] (its grep searched for the literal substring
## [code]authoritative_write_in_progress_check[/code]; this site's local
## variable is named [code]write_in_progress[/code], so it did not match):
## [code]tests/integration/gameplay/cards/card_play_session_test.gd[/code]'s
## [code]test_ac14_authoritative_write_in_progress_blocks_open_hand_synchronously[/code],
## which stands in for [code]CardPlaySession.open_hand()[/code] — the
## production path `AC-U8` (as opposed to `AC-M8`, which is
## [method BattleMenu.open]) actually names. That test is likewise NOT
## touched here (same AC-3 reasoning). This file's "BONUS — AC-U8" section
## below covers that gate with the identical real-flag technique, so both
## halves of this story's own title are addressed, not only the one the
## story body's AC-1/AC-2 wording and code sample happen to spell out
## ("選單"/[BattleMenu] only).
##
## [b]🔴 Assertions that depend on the window being OPEN must run INSIDE the
## [param mutator] Callable[/b] passed to
## [method BattleState.commit_authoritative_change] — that is the only moment
## [member BattleState.authoritative_write_in_progress] reads `true` (this
## story's own AC-1 wording). An assertion placed after the call returns
## would read `false` and the test would pass vacuously (the gate genuinely
## can open at that point, so "rejected" would never be exercised) — the
## sensitivity proofs below demonstrate this failure mode concretely via a
## mutant [BattleState] that never raises the flag.
##
## All fixtures here are either [RefCounted] ([BattleState], [CardPlaySession],
## [CardDeck]) or a single auto-freed [BattleMenu] scene instance per test —
## no orphans expected, matching this project's established convention for
## this test area.
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/menu/BattleMenu.tscn"


# ── Shared fixtures ──────────────────────────────────────────────────────────


func _instantiate_menu() -> BattleMenu:
	var instance: BattleMenu = auto_free(load(SCENE_PATH).instantiate())
	add_child(instance)
	# 🔴 Known trap, found by actually running this file (same discovery
	# `battle_menu_gating_test.gd`'s own comment records): a freshly
	# instantiated BattleMenu inherits U-007's _ready() default
	# (Control.visible starts true). Without closing it first, is_open()
	# reads true from the very start, and any "must not have opened"
	# assertion below would be vacuously wrong about what it is even
	# comparing against.
	instance.close()
	return instance


func _two_unit_roster() -> Array[String]:
	return [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]


func _build_state() -> BattleState:
	return BattleState.create(PackedStringArray(), "\n".join(_two_unit_roster()))


## Minimal stand-in satisfying [AffinityWritePort]'s `@abstract` contract
## (bare-signature abstract methods — a body is a compile-time error in this
## engine version, registered forbidden pattern `abstract_func_with_body`).
## None of this file's tests ever call [method CardPlaySession.confirm], so
## this is never actually invoked — it exists purely to satisfy the
## constructor's required parameter, same role as
## `card_play_session_test.gd`'s own `_FakeAffinityWritePort`.
class _UnusedAffinityWritePort extends AffinityWritePort:
	func append_record(_character_a: int, _character_b: int, _m: int, _source: StringName) -> Rejection:
		return Rejection.NONE


func _build_card_play_session(
	state: BattleState, authoritative_write_in_progress_check: Callable = Callable()
) -> CardPlaySession:
	var deck: CardDeck = CardDeck.new([], RandomNumberGenerator.new())
	return CardPlaySession.new(
		deck, state, [], _UnusedAffinityWritePort.new(), authoritative_write_in_progress_check
	)


# ═══════════════════════════════════════════════════════════════════════════
# AC-1 / AC-2 — AC-M8: BattleMenu.open(), real BattleState, real flag
# ═══════════════════════════════════════════════════════════════════════════


## AC-1. [直接因果 — 不需另建突變] 這條本身就是本 story 的核心主張,另有獨立
## 敏感度證明(見下方 test_sensitivity_proof_*),故這裡不依賴分類豁免。
func test_menu_open_rejected_while_real_authoritative_write_window_is_open() -> void:
	# Arrange
	var state: BattleState = _build_state()
	var menu: BattleMenu = _instantiate_menu()
	monitor_signals(menu)
	menu.authoritative_write_in_progress_check = func() -> bool:
		return state.authoritative_write_in_progress

	# Precondition — the flag must read false before any commit starts,
	# otherwise the rejection asserted below would be unfalsifiable against
	# "this Callable always happens to read true".
	assert_bool(state.authoritative_write_in_progress).append_failure_message(
		"PRECONDITION: the flag must read false before any " +
		"commit_authoritative_change() call is in progress."
	).is_false()

	var probe: Dictionary = {}

	# Act — the assertions that matter run INSIDE this mutator; this is the
	# only moment the REAL flag reads true (see file header).
	state.commit_authoritative_change(func() -> void:
		probe["flag_during_commit"] = state.authoritative_write_in_progress
		probe["result"] = menu.open()
	)

	# Assert
	assert_bool(bool(probe["flag_during_commit"])).append_failure_message(
		"PRECONDITION: the real flag did not read true during the commit " +
		"window — this test cannot be meaningful if the premise it drives " +
		"off of never held."
	).is_true()
	assert_int(probe["result"]).append_failure_message(
		"open() must reject while the REAL authoritative-write flag reads " +
		"true (not a test-double Callable) — if this reads OPENED, either " +
		"the gate regressed or the real flag never became true."
	).is_equal(BattleMenu.OpenResult.REJECTED_AUTHORITATIVE_WRITE)
	assert_bool(menu.is_open()).append_failure_message(
		"the menu must not have become visible/open on a rejected open()."
	).is_false()
	await assert_signal(menu).is_emitted(
		"open_rejected",
		BattleMenu.OpenResult.REJECTED_AUTHORITATIVE_WRITE,
		Loc.localize(BattleMenu.REJECTION_MESSAGE_AUTHORITATIVE_WRITE)
	)


## AC-2. Proves the rejection above is CAUSED by the real window being open,
## not by something else being broken about the menu: the identical menu,
## wired to the identical state, opens normally once the window has
## genuinely closed.
func test_menu_open_succeeds_after_real_authoritative_write_window_closes() -> void:
	# Arrange
	var state: BattleState = _build_state()
	var menu: BattleMenu = _instantiate_menu()
	menu.authoritative_write_in_progress_check = func() -> bool:
		return state.authoritative_write_in_progress

	# Act — open and close a real commit window with an empty mutator; this
	# test only cares about the state AFTER commit_authoritative_change()
	# has returned.
	state.commit_authoritative_change(func() -> void:
		pass
	)

	# Assert
	assert_bool(state.authoritative_write_in_progress).append_failure_message(
		"PRECONDITION: the window must have genuinely closed after " +
		"commit_authoritative_change() returned."
	).is_false()
	var result: BattleMenu.OpenResult = menu.open()
	assert_int(result).append_failure_message(
		"open() must succeed once the real authoritative-write window has " +
		"closed — if this still rejects, the gate is stuck closed, not " +
		"correctly tied to the real flag's lifecycle."
	).is_equal(BattleMenu.OpenResult.OPENED)
	assert_bool(menu.is_open()).is_true()

	# Cleanup — leaving the REAL SceneTree paused would affect any other
	# test sharing this engine process (same convention
	# battle_menu_gating_test.gd's own AC-M3 tests already follow).
	menu.close()
	get_tree().paused = false


# ═══════════════════════════════════════════════════════════════════════════
# BONUS — AC-U8: CardPlaySession.open_hand(), real BattleState, real flag.
# Not required by this story's literal AC-1/AC-2 wording (which spells out
# only "選單"/BattleMenu), but explicitly named by this story's own title
# ("AC-U8 / AC-M8") and by EPIC.md's limitation #1 and its 2026-10-12
# addendum, both of which treat the two ACs as a paired consequence of the
# same underlying flag becoming real. See the file header's "fifth stand-in
# site" note for why this gate was missing from the work order's own
# reconnaissance.
# ═══════════════════════════════════════════════════════════════════════════


func test_card_play_session_open_hand_rejected_while_real_authoritative_write_window_is_open() -> void:
	# Arrange
	var state: BattleState = _build_state()
	var session: CardPlaySession = _build_card_play_session(
		state, func() -> bool: return state.authoritative_write_in_progress
	)
	var probe: Dictionary = {}

	# Act
	state.commit_authoritative_change(func() -> void:
		probe["flag_during_commit"] = state.authoritative_write_in_progress
		probe["opened"] = session.open_hand()
	)

	# Assert
	assert_bool(bool(probe["flag_during_commit"])).append_failure_message(
		"PRECONDITION: the real flag did not read true during the commit window."
	).is_true()
	assert_bool(bool(probe["opened"])).append_failure_message(
		"open_hand() must reject (return false) while the REAL " +
		"authoritative-write flag reads true."
	).is_false()
	assert_bool(session.is_open()).append_failure_message(
		"the session must not have opened on a rejected open_hand()."
	).is_false()


func test_card_play_session_open_hand_succeeds_after_real_authoritative_write_window_closes() -> void:
	# Arrange
	var state: BattleState = _build_state()
	var session: CardPlaySession = _build_card_play_session(
		state, func() -> bool: return state.authoritative_write_in_progress
	)

	# Act
	state.commit_authoritative_change(func() -> void:
		pass
	)

	# Assert
	var opened: bool = session.open_hand()
	assert_bool(opened).append_failure_message(
		"open_hand() must succeed once the real authoritative-write window " +
		"has closed."
	).is_true()
	assert_bool(session.is_open()).is_true()


# ═══════════════════════════════════════════════════════════════════════════
# AC-4 — sensitivity proofs. Prove the real-flag tests above actually catch
# the defects they claim to, rather than passing regardless of BattleState's
# real behavior (.claude/rules/test-standards.md, 2026-09-16 manager ruling).
#
# Method-override mutants only — overriding [method BattleState.commit_authoritative_change]
# is the established, already-proven pattern in this codebase (see
# commit_authoritative_change_version_test.gd's own
# `_MutantSkipsVersionIncrement`/`_MutantIncrementsVersionOnEveryNestedCommit`).
# Overriding the [member BattleState.authoritative_write_in_progress] PROPERTY
# itself (its `get:` block) is deliberately NOT used — no precedent for
# overriding a `get:`/`set:` property block in a subclass exists anywhere in
# this test suite, and this file does not want to be the first place that
# untested a language-feature assumption lands. Overriding
# [method commit_authoritative_change] to manipulate the SAME
# `_authoritative_write_depth` field the real property getter reads achieves
# the identical observable effect through an already-verified mechanism.
# ═══════════════════════════════════════════════════════════════════════════


## Mutant for the "flag never becomes true" defect shape: the mutator runs,
## but [member BattleState._authoritative_write_depth] is never touched — so
## [member BattleState.authoritative_write_in_progress] (inherited,
## unoverridden getter reading `_authoritative_write_depth > 0`) reads false
## even while the mutator is executing. This is the exact defect AC-1/the
## CardPlaySession bonus test above exist to catch: "the real flag never
## genuinely becomes true during a real authoritative write".
class _MutantCommitNeverRaisesTheFlag extends BattleState:
	func commit_authoritative_change(mutator: Callable) -> void:
		# BUG (deliberately injected): _authoritative_write_depth is never
		# incremented, so the window never appears open to any reader.
		mutator.call()
		_combat_state_version += 1


## Mutant for the "window never closes" defect shape: the depth counter is
## incremented on entry but never decremented on exit — the window stays
## open forever after commit_authoritative_change() returns. This is the
## exact defect AC-2/the CardPlaySession bonus test above exist to catch:
## "the window never genuinely closes".
class _MutantCommitNeverClosesTheWindow extends BattleState:
	func commit_authoritative_change(mutator: Callable) -> void:
		_authoritative_write_depth += 1
		mutator.call()
		# BUG (deliberately injected): no decrement — the window is stuck open.
		_combat_state_version += 1


func test_sensitivity_proof_menu_test_catches_a_battlestate_that_never_raises_the_flag_during_commit() -> void:
	# Arrange — no board/units needed: menu.open() never touches BattleState
	# itself, only the injected Callable's closure over it.
	var mutant_state: _MutantCommitNeverRaisesTheFlag = _MutantCommitNeverRaisesTheFlag.new()
	var menu: BattleMenu = _instantiate_menu()
	menu.authoritative_write_in_progress_check = func() -> bool:
		return mutant_state.authoritative_write_in_progress
	var probe: Dictionary = {}

	# Act
	mutant_state.commit_authoritative_change(func() -> void:
		probe["result"] = menu.open()
	)

	# Assert — with the real BattleState this reads
	# REJECTED_AUTHORITATIVE_WRITE (see the test above). With this mutant it
	# must read OPENED, proving the real-flag test's assertion technique
	# would have failed loudly had the real implementation shipped with this
	# defect.
	assert_int(probe["result"]).append_failure_message(
		"SENSITIVITY PROOF FAILED: the mutant never raises " +
		"_authoritative_write_depth, so menu.open() must succeed (OPENED) " +
		"here — if it still rejects, the real-flag test cannot tell a " +
		"BattleState that genuinely raises the flag from one that never does."
	).is_equal(BattleMenu.OpenResult.OPENED)

	# Cleanup — unlike the real AC-1 test, this mutant's open() DID succeed,
	# so it genuinely paused the tree / suspended arbitration.
	menu.close()
	get_tree().paused = false


func test_sensitivity_proof_menu_test_catches_a_battlestate_that_never_closes_the_window() -> void:
	# Arrange
	var mutant_state: _MutantCommitNeverClosesTheWindow = _MutantCommitNeverClosesTheWindow.new()
	var menu: BattleMenu = _instantiate_menu()
	menu.authoritative_write_in_progress_check = func() -> bool:
		return mutant_state.authoritative_write_in_progress

	# Act
	mutant_state.commit_authoritative_change(func() -> void:
		pass
	)

	# Assert — with the real BattleState, open() succeeds here (see the test
	# above). With this mutant the window never closed, so it must still
	# reject — proving the real-flag test's assertion technique would have
	# failed loudly had the real implementation shipped with this "stuck
	# open" defect.
	var result: BattleMenu.OpenResult = menu.open()
	assert_int(result).append_failure_message(
		"SENSITIVITY PROOF FAILED: the mutant never decrements " +
		"_authoritative_write_depth, so the window is stuck open and " +
		"menu.open() must still reject here — if it opens, the real-flag " +
		"test cannot tell a BattleState that genuinely closes the window " +
		"from one that never does."
	).is_equal(BattleMenu.OpenResult.REJECTED_AUTHORITATIVE_WRITE)


func test_sensitivity_proof_card_play_session_test_catches_a_battlestate_that_never_raises_the_flag_during_commit() -> void:
	# Arrange
	var mutant_state: _MutantCommitNeverRaisesTheFlag = _MutantCommitNeverRaisesTheFlag.new()
	var session: CardPlaySession = _build_card_play_session(
		mutant_state, func() -> bool: return mutant_state.authoritative_write_in_progress
	)
	var probe: Dictionary = {}

	# Act
	mutant_state.commit_authoritative_change(func() -> void:
		probe["opened"] = session.open_hand()
	)

	# Assert — with the real BattleState this reads false (see the bonus
	# test above). With this mutant it must read true.
	assert_bool(bool(probe["opened"])).append_failure_message(
		"SENSITIVITY PROOF FAILED: the mutant never raises " +
		"_authoritative_write_depth, so open_hand() must succeed here — if " +
		"it still rejects, the real-flag test cannot tell a BattleState " +
		"that genuinely raises the flag from one that never does."
	).is_true()


func test_sensitivity_proof_card_play_session_test_catches_a_battlestate_that_never_closes_the_window() -> void:
	# Arrange
	var mutant_state: _MutantCommitNeverClosesTheWindow = _MutantCommitNeverClosesTheWindow.new()
	var session: CardPlaySession = _build_card_play_session(
		mutant_state, func() -> bool: return mutant_state.authoritative_write_in_progress
	)

	# Act
	mutant_state.commit_authoritative_change(func() -> void:
		pass
	)

	# Assert — with the real BattleState, open_hand() succeeds here (see the
	# bonus test above). With this mutant the window never closed, so it
	# must still reject.
	var opened: bool = session.open_hand()
	assert_bool(opened).append_failure_message(
		"SENSITIVITY PROOF FAILED: the mutant never decrements " +
		"_authoritative_write_depth, so the window is stuck open and " +
		"open_hand() must still reject here."
	).is_false()
