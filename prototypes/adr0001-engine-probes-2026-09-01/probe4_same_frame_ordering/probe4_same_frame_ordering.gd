extends SceneTree

# Probe 4: "same-frame visibility" ordering guarantee.
#
# ADR-0001's abort semantics implicitly assume: if a settlement boundary
# commits (board_version += 1) at some point BEFORE a suspended cross-frame
# query's await-resume point, that query, when it resumes, MUST read the
# incremented board_version. If this were false, mechanism one's abort
# check (`board.board_version != start_version`) could miss a class of
# cases -- the query would resume, see a version that matches its
# start_version even though a settlement already happened, and proceed to
# use a result computed against a snapshot that no longer represents the
# authoritative board.
#
# This probe routes the settlement commit through `_process()` (ADR
# mechanism two states settlement executes on the `_process` chain), and
# the query's resume through a LOOP of `await get_tree().process_frame`
# calls (mirroring a multi-frame-unrolled query that re-checks the version
# at every resume point, per ADR mechanism one), to test the ACTUAL
# ordering between those two engine-driven event sources -- not an assumed
# ordering.
#
# 2026-09-01 revision (v2): the first version of this probe tried to vary
# "which _process() call commits the settlement" across independent
# single-suspend trials, but had a bug -- restarting each trial's query
# synchronously inside the SAME _process()/signal-handling chain as the
# previous trial's resume meant every trial after the first inherited a
# "used up" process_frame emission and its query resumed one signal early,
# before settlement had a chance to fire. That produced 4 "inconclusive"
# results out of 5, which is a probe defect, not evidence about the ADR.
#
# Fixed shape: ONE query per run, looping across MAX_FRAMES resume points
# (mirrors a real multi-frame-unrolled reachable_set calculation checking
# board_version at every resume, not just once). Settlement fires on a
# specific _process() call number partway through. This directly records,
# at EVERY resume point, whether the version read matches "has settlement
# already committed by now" -- including the critical first resume
# immediately after settlement.

const MAX_FRAMES: int = 8
const SETTLE_AT_FRAME: int = 4  # commit partway through the loop, not on frame 1

class Board:
	var _board_version: int = 0
	var board_version: int:
		get:
			return _board_version
		set(value):
			push_error("board_version is read-only outside Board; rejected external write of %d" % value)

	func commit_settlement_boundary() -> void:
		_board_version += 1


var board: Board
var frame_count: int = 0
var settlement_committed: bool = false
var settlement_committed_at_frame: int = -1
var query_done: bool = false

# Per-resume record: [frame_at_resume, version_read, settlement_already_committed_at_that_point]
var records: Array = []


func _initialize() -> void:
	board = Board.new()
	print("P4-start: start_version=%d, will commit settlement on _process call #%d, looping %d resumes" % [
		board.board_version, SETTLE_AT_FRAME, MAX_FRAMES,
	])
	_run_query()


func _run_query() -> void:
	var start_version: int = board.board_version
	for i: int in range(MAX_FRAMES):
		await process_frame
		var resumed_version: int = board.board_version
		var settled_by_now: bool = settlement_committed
		records.append([frame_count, resumed_version, settled_by_now])
		print("P4-resume[%d]: frame=%d version=%d settlement_committed_by_now=%s" % [
			i, frame_count, resumed_version, settled_by_now,
		])
	query_done = true
	print("P4-query-loop-complete: final version=%d, start_version was %d" % [board.board_version, start_version])


func _process(_delta: float) -> bool:
	frame_count += 1

	if frame_count == SETTLE_AT_FRAME and not settlement_committed:
		board.commit_settlement_boundary()
		settlement_committed = true
		settlement_committed_at_frame = frame_count
		print("P4-settle (in _process chain): frame=%d committed, version now=%d" % [
			frame_count, board.board_version,
		])

	if query_done:
		# Verdict: find the FIRST resume record where settlement had already
		# committed -- that resume MUST show the incremented version. And no
		# resume BEFORE settlement should show it.
		var first_post_settle_ok: bool = true
		var no_premature_leak: bool = true
		var found_first_post_settle: bool = false
		for rec: Array in records:
			var rec_frame: int = rec[0]
			var rec_version: int = rec[1]
			var rec_settled: bool = rec[2]
			if rec_settled and not found_first_post_settle:
				found_first_post_settle = true
				if rec_version != 1:
					first_post_settle_ok = false
				print("P4-CRITICAL-RESUME: first resume after settlement -> frame=%d version=%d (expect 1) -> %s" % [
					rec_frame, rec_version, "OK" if rec_version == 1 else "FAIL",
				])
			if not rec_settled and rec_version != 0:
				no_premature_leak = false
				print("P4-ANOMALY: resume BEFORE settlement already shows incremented version at frame=%d" % rec_frame)
		print("P4-FINAL-VERDICT: settlement_committed_at_frame=%d, first_post_settle_saw_increment=%s, no_premature_leak=%s, records=%s" % [
			settlement_committed_at_frame, first_post_settle_ok, no_premature_leak, records,
		])
		return true  # end the main loop
	return false
