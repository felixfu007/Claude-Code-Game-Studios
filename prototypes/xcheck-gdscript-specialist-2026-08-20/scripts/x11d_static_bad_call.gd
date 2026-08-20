extends RefCounted
# X11d — statically visible wrong-type argument to a typed `float` parameter
# (literal String, not smuggled through Variant). Separate file so a parse
# failure here doesn't block loading x11a/b/c. Companion to x11c's runtime
# smuggling tests — this is the control showing what happens when the bad
# type IS visible to the compiler (expected: Parse Error, same family as
# x1b/x1c in XCHECK-1).

static func _append_like(pair_id: int, m: float, source_id: int) -> String:
	return "received: m=%s" % str(m)

static func try_static_bad_call() -> String:
	return _append_like(0, "abc", 0)
