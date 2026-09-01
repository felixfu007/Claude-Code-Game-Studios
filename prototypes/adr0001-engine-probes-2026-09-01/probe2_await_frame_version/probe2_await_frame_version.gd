extends SceneTree

# Probe 2: `await get_tree().process_frame` -- does board_version read
# BEFORE the await and AFTER the await behave the way ADR-0001's abort
# semantics require?
#
# ADR-0001 mechanism one: a cross-frame query records start_version, and at
# every resume point compares board.board_version != start_version -> abort
# and recompute if they differ. This probe tests both branches of that
# comparison against the real engine:
#   Scenario A (no settlement in between): resumed version must equal
#     start_version -- the query is allowed to complete normally.
#   Scenario B (a settlement boundary commits while the query is suspended):
#     resumed version must differ from start_version -- the query must be
#     able to detect this and abort.
#
# Board shape mirrors the ADR's Key Interfaces exactly: private backing
# field `_board_version`, public read-only property `board_version` with a
# get:/set: pair where set: calls push_error() and rejects the write.

class Board:
	var _board_version: int = 0
	var board_version: int:
		get:
			return _board_version
		set(value):
			push_error("board_version is read-only outside Board; rejected external write of %d" % value)

	func commit_settlement_boundary() -> void:
		_board_version += 1


var scenario: String = "A"
var board: Board


func _initialize() -> void:
	_run_scenario_a()


func _run_scenario_a() -> void:
	scenario = "A"
	board = Board.new()
	print("P2-A0: scenario A (no settlement between suspend and resume)")
	_query_and_report()


func _run_scenario_b() -> void:
	scenario = "B"
	board = Board.new()
	print("P2-B0: scenario B (settlement commits while query is suspended)")
	_query_and_report()


func _query_and_report() -> void:
	var start_version: int = board.board_version
	print("P2-%s1: query starts, start_version=%d" % [scenario, start_version])

	if scenario == "B":
		# Commit the settlement boundary from a SEPARATE coroutine that also
		# resumes on process_frame, to mirror the real engine's signal
		# dispatch rather than assuming call order by construction.
		_commit_after_one_frame()

	await process_frame

	var resumed_version: int = board.board_version
	var changed: bool = resumed_version != start_version
	print("P2-%s2: query resumed, resumed_version=%d, changed=%s (ADR requires: abort_and_recompute == %s)" % [
		scenario, resumed_version, changed, changed,
	])

	if scenario == "A":
		_run_scenario_b()
	else:
		quit()


func _commit_after_one_frame() -> void:
	# Deliberately does NOT await -- commits synchronously, in the same
	# frame the query suspended in, BEFORE the process_frame signal that
	# will resume the query fires. This is the ADR-mandated pattern:
	# settlement is synchronous within a single _process tick (mechanism
	# two), never itself spread across a yield.
	board.commit_settlement_boundary()
	print("P2-B-settle: committed settlement synchronously (no yield), version now=%d" % board.board_version)
