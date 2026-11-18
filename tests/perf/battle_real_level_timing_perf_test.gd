## story-062 -- wall-clock performance check for the REAL vs01 battle.
##
## 🔴 DELIBERATELY NOT COLLECTED BY THE FULL SUITE. `tests/perf/` is intentionally absent
## from FORCED_ARGS in tests/gdunit4_runner.gd. The usual rule "every new test level must be
## added there, or it silently never runs" is deliberately inverted here: this check measures
## real wall-clock time, which swings 2-3x with the machine's state (manager ruling 2026-11-17,
## option A; docs/reviews/timing-test-full-suite-red-2026-11-17.md). Do NOT "fix" the missing
## entry -- adding it brings back the false-red full suite this story removed.
## Run manually on an idle machine; see tests/perf/README.md for the command.
##
## Uses the same driver as the in-suite test (tests/helpers/real_battle_driver.gd), loading the
## real BattleScreen.tscn -- no re-implementation of the battle loop.
##
## Measurement: 3 full battles (each a fresh load), median elapsed < THRESHOLD_MSEC, and all 3
## round_counts must be equal (not hard-coded: different counts mean the battle is no longer
## deterministic, which is a different defect than slowness).
##
## Not provable by a resident sensitivity proof: the threshold itself (it would need a
## deliberately slowed battle -- real waiting slows the suite, a fake clock changes the unit
## under test; test-standards class D). Validity is backed by a one-off manual check recorded in
## README.md, which is NOT a resident proof.
extends GdUnitTestSuite

const THRESHOLD_MSEC: int = 30000
const _RUNS: int = 3
const _ROUND_CAP: int = 10

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


func test_real_level_battle_median_time_under_threshold() -> void:
	var driver: RealBattleDriver = RealBattleDriver.new(self)
	var times: Array[int] = []
	var rounds: Array[int] = []
	for i: int in range(_RUNS):
		var instance: BattleScreen = driver.load_battle_screen_real()
		driver.assert_opening_state(instance)
		var result: Dictionary = await driver.run_battle(instance, _ROUND_CAP, false)
		assert_bool(RealBattleDriver.is_terminal_outcome(result["outcome"])).is_true()
		times.append(result["elapsed_msec"])
		rounds.append(result["round_count"])
		# free this run's screen before the next so runs do not share state
		instance.queue_free()
		await get_tree().process_frame

	var sorted_times: Array[int] = times.duplicate()
	sorted_times.sort()
	var median_msec: int = sorted_times[_RUNS / 2]
	print("PERF real_level_battle times_msec=", times, " median_msec=", median_msec,
		" round_counts=", rounds, " threshold_msec=", THRESHOLD_MSEC)

	assert_int(rounds[1]).is_equal(rounds[0])
	assert_int(rounds[2]).is_equal(rounds[0])
	assert_int(median_msec).is_less(THRESHOLD_MSEC)
