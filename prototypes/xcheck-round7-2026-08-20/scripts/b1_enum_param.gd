extends RefCounted
# B1 — R7E-4: does GDScript's typed-ENUM parameter boundary behave like the
# previously-verified typed-`float` boundary (whole caller function aborts on
# wrong TYPE, per prototypes/xcheck-gdscript-specialist-2026-08-20 XCHECK-4),
# or does it silently coerce a Variant into a legal-looking enum ordinal --
# the way `var t: int = <float 1.5>` silently truncates to `1` with no error?
# `g(n: int)` is the bare-int control group for direct comparison. Values
# -1 and 999 are deliberately LEGAL ints but ILLEGAL enum ordinals (Pair has
# only 10 members, ordinals 0-9) -- this is the part no prior probe covered.
#
# Smuggling technique: the Variant is passed through a `Variant`-typed
# parameter (`call_f_with`/`call_g_with`) so the actual value is not visible
# to static analysis at the call site inside `f`/`g` -- identical to X11c's
# `_append_like(pair_id, m: float, source_id)` technique for the float
# boundary.

static func f(p: AffinityTypes.Pair) -> String:
	print("      >> f: entering, typeof(p)=%d p=%s" % [typeof(p), str(p)])
	return "REACHED END typeof(p)=%d p=%s" % [typeof(p), str(p)]

static func call_f_with(v: Variant) -> String:
	print("      >> call_f_with: entering, about to call f(v)")
	var r: String = f(v)
	print("      >> call_f_with: call returned, about to return")
	return "REACHED END callee_said=[%s]" % r

static func g(n: int) -> String:
	print("      >> g: entering, typeof(n)=%d n=%s" % [typeof(n), str(n)])
	return "REACHED END typeof(n)=%d n=%s" % [typeof(n), str(n)]

static func call_g_with(v: Variant) -> String:
	print("      >> call_g_with: entering, about to call g(v)")
	var r: String = g(v)
	print("      >> call_g_with: call returned, about to return")
	return "REACHED END callee_said=[%s]" % r
