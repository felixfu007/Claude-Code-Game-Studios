extends SceneTree

# Probe A: property with ONLY a get: block (no set: block at all).
# Question: does GDScript 4.7.1 accept this as "computed read-only, no setter
# defined anywhere" -- and does that mean *internal* code in the same class
# also cannot assign to it (must go through a separate backing field)?

class_name ProbeAHolder

var _board_version: int = 0

var board_version: int:
	get:
		return _board_version

func bump_internal() -> void:
	# internal code writes the BACKING FIELD directly, not the property.
	_board_version += 1

func _init() -> void:
	print("A1: initial board_version = ", board_version)
	bump_internal()
	print("A2: after bump_internal(), board_version = ", board_version)

	# Now try to write to the property itself, as an EXTERNAL caller would.
	# We expect this to fail somehow (parse error, or runtime error).
	board_version = 999
	print("A3: after direct assignment attempt, board_version = ", board_version)

	quit()
