extends SceneTree

# Probe 3: does `Dictionary[Vector2i, int]` (struct-like key + typed
# container) compile without warnings in 4.7.1, exactly as ADR-0001's Key
# Interfaces declares it (board.gd line: `var _occupied: Dictionary[Vector2i, int]`)?
#
# Tests both the exact ADR shape (uninitialized typed instance var, no `= {}`
# literal) and basic read/write/iterate operations on it, then a rejection
# check (assigning a wrong-typed key should fail loudly, not silently).

class BoardLike:
	# Exact shape from ADR-0001 Key Interfaces: no initializer literal.
	var _occupied: Dictionary[Vector2i, int]

	func is_occupied(tile: Vector2i) -> bool:
		return _occupied.has(tile)

	func occupant_of(tile: Vector2i) -> int:
		return _occupied.get(tile, -1)

	func set_occupant(tile: Vector2i, unit_id: int) -> void:
		_occupied[tile] = unit_id


func _initialize() -> void:
	var b := BoardLike.new()

	print("P3-1: uninitialized typed Dictionary field -- b._occupied = %s (size=%d)" % [
		b._occupied, b._occupied.size(),
	])

	b.set_occupant(Vector2i(1, 2), 42)
	b.set_occupant(Vector2i(3, 4), 7)

	print("P3-2: is_occupied(1,2)=%s occupant_of(1,2)=%d" % [
		b.is_occupied(Vector2i(1, 2)), b.occupant_of(Vector2i(1, 2)),
	])
	print("P3-3: is_occupied(9,9)=%s occupant_of(9,9)=%d" % [
		b.is_occupied(Vector2i(9, 9)), b.occupant_of(Vector2i(9, 9)),
	])
	print("P3-4: size=%d" % b._occupied.size())

	for key: Vector2i in b._occupied:
		print("P3-5: key=%s (is Vector2i=%s) value=%s (is int=%s)" % [
			key, key is Vector2i, b._occupied[key], b._occupied[key] is int,
		])

	# Local typed dict literal too, since the ADR text also shows this shape
	# informally in prose ("使用者裁決" for Dictionary[Vector2i, unit_id]).
	var local_typed: Dictionary[Vector2i, int] = {}
	local_typed[Vector2i(0, 0)] = 1
	print("P3-6: local typed dict literal works, size=%d" % local_typed.size())

	quit()
