extends SceneTree

# Probe C: rough performance comparison between:
#   1. plain public var (no property)
#   2. property with get:/set: block (Probe B shape)
#   3. underscore-private var + explicit get_x() method
# read N times in a tight loop, to see if the property syntax has measurable
# per-access overhead relevant to a hot path (per-query validity check).
# This is a rough order-of-magnitude check, not a rigorous benchmark.

const ITERATIONS: int = 5_000_000

class PlainHolder:
	var v: int = 42

class PropertyHolder:
	var _v: int = 42
	var v: int:
		get:
			return _v
		set(value):
			pass

class MethodHolder:
	var _v: int = 42
	func get_v() -> int:
		return _v

func _init() -> void:
	var plain: PlainHolder = PlainHolder.new()
	var prop: PropertyHolder = PropertyHolder.new()
	var meth: MethodHolder = MethodHolder.new()

	var sink: int = 0

	var t0: int = Time.get_ticks_usec()
	for i: int in range(ITERATIONS):
		sink += plain.v
	var t1: int = Time.get_ticks_usec()
	for i: int in range(ITERATIONS):
		sink += prop.v
	var t2: int = Time.get_ticks_usec()
	for i: int in range(ITERATIONS):
		sink += meth.get_v()
	var t3: int = Time.get_ticks_usec()

	print("sink (ignore, prevents optimization-away) = ", sink)
	print("C1: plain var    read x%d: %d us" % [ITERATIONS, t1 - t0])
	print("C2: property     read x%d: %d us" % [ITERATIONS, t2 - t1])
	print("C3: getter method read x%d: %d us" % [ITERATIONS, t3 - t2])

	quit()
