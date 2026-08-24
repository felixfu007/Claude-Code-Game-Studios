extends RefCounted
# Compile-only probe (loaded by runner.gd via ResourceLoader + reload()'s
# Error return, never a bare load()): does a statically-typed `Array[int]`
# even expose a `.get(index)` method the way `Dictionary` does? This is a
# compile-time question for a statically typed Array, so it is answered by
# whether this file compiles at all, not by running anything in it.

func f(arr: Array[int]) -> int:
	return arr.get(0)
