extends SceneTree

# Probe B: property with BOTH get: and set:, where set: is a guard that
# rejects/ignores external writes. Internal code still writes the backing
# field directly (bypassing the property's own setter).
# Question: does an external caller doing `obj.board_version = 999` actually
# invoke the setter (so we can push_error / ignore), or does something else
# happen? Does calling the setter cost anything measurable vs a plain field?

class_name ProbeBHolder

var _board_version: int = 0
var external_write_attempts: int = 0

var board_version: int:
	get:
		return _board_version
	set(value):
		external_write_attempts += 1
		push_warning("board_version is read-only from outside Board; ignoring external write of %d" % value)
		# deliberately do NOT assign _board_version here

func bump_internal() -> void:
	_board_version += 1

func _init() -> void:
	print("B1: initial board_version = ", board_version)
	bump_internal()
	bump_internal()
	print("B2: after two internal bumps, board_version = ", board_version)

	board_version = 999
	print("B3: after external write attempt, board_version = ", board_version, " (should still be 2, not 999)")
	print("B4: external_write_attempts = ", external_write_attempts)

	quit()
