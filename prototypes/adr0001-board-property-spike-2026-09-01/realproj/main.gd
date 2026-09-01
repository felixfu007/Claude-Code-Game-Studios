extends Node

# Plays the role of an EXTERNAL system (e.g. a query object or the HUD)
# that only holds a reference to BoardProbe -- exactly how QueryResult /
# presentation-layer code would touch Board in the real system.

func _ready() -> void:
	var board: BoardProbe = BoardProbe.new()
	print("M1: initial board.board_version = ", board.board_version)

	board.commit_settlement_boundary()
	board.commit_settlement_boundary()
	print("M2: after two committed settlement boundaries = ", board.board_version)

	# External code attempts to poke the field directly, as if it were a
	# bare `var`. This is exactly the bug ADR-0001's registry entry
	# ("write_access: board-only") is meant to prevent.
	board.board_version = 999
	print("M3: after external write attempt = ", board.board_version, " (expect 2, not 999)")

	get_tree().quit()
