extends RefCounted
# Isolated in its OWN file, not inlined into runner.gd, precisely because it
# is uncertain whether GDScript treats a `_` pattern placed BEFORE a more
# specific TYPE_NIL pattern as a hard Parse Error (dead/unreachable code) or
# just compiles and runs with `_` swallowing everything. Isolating it means
# that even if this file fails to compile, the rest of the VR9 probe (A/B/D
# in runner.gd) still runs and still produces results -- avoiding the "one
# Parse Error blocks the whole batch" failure mode this project has already
# hit once (see prototypes/xcheck-adr0002-review-2026-08-24/scripts/runner.gd
# header comment referencing the probeC-v1-flawed precedent).

func classify(v: Variant) -> String:
	match typeof(v):
		_:
			return "DEFAULT(placed first in source)"
		TYPE_NIL:
			return "TYPE_NIL(placed second in source)"
