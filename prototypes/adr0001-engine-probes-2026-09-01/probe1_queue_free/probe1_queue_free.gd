extends SceneTree

# Probe 1: does queue_free() defer removal to end-of-frame in 4.7.1?
#
# ADR-0001 mechanism three depends on this: a unit that dies in settlement
# step (4) must still be readable as "occupied" via the logic dictionary in
# the SAME settlement step, precisely because if occupied() were derived from
# node-tree presence instead, the freed node would still be a scene-tree
# child at that point and the tile would be misread as occupied.
#
# This probe tests the node-tree side of that claim directly: after calling
# queue_free() on a child node, in the SAME synchronous call stack (no yield
# at all), is the node still a valid instance and still present in
# get_children()? And does it become invalid only after control returns to
# the engine and at least one frame boundary passes?

func _initialize() -> void:
	var root := Node.new()
	get_root().add_child(root)
	var victim := Node.new()
	victim.name = "Victim"
	root.add_child(victim)

	print("P1-1: before queue_free() -- is_instance_valid=%s, is_child=%s" % [
		is_instance_valid(victim),
		root.get_children().has(victim),
	])

	victim.queue_free()

	# Still the SAME synchronous call stack as the queue_free() call above --
	# no yield, no await, no return-to-engine has happened.
	print("P1-2: immediately after queue_free(), same call stack -- is_instance_valid=%s, is_child=%s, is_queued_for_deletion=%s" % [
		is_instance_valid(victim),
		root.get_children().has(victim),
		victim.is_queued_for_deletion(),
	])

	await process_frame

	print("P1-3: after one process_frame await -- is_instance_valid=%s" % [
		is_instance_valid(victim),
	])

	quit()
