# Headless probe runner re-running Story 001 AC-S001-c against the project's
# ACTUAL production files (CursorTypes / CursorTarget / MouseReclaimPolicy),
# copied verbatim into this throwaway project -- not the placeholder
# int-typed stand-in used by prototypes/story-001-abstract-probe-2026-09-02/'s
# first pass. Same F-8 methodology (ResourceLoader.load + CACHE_MODE_IGNORE +
# .reload(), checking the returned Error -- NOT `load(path) != null`).
extends SceneTree

const SCRIPTS := "res://scripts/"


func _initialize() -> void:
	print("=".repeat(78))
	print("STORY 001 -- REAL-TYPE @abstract COMPILE PROBE -- 2026-09-02")
	print("Godot version: %s" % str(Engine.get_version_info().get("string", "<unknown>")))
	print("=".repeat(78))
	print("")

	print("[1] Real MouseReclaimPolicy base file compiles standalone")
	_report("mouse_reclaim_policy.gd")
	print("")

	print("[2] Control group: complete subclass of the REAL MouseReclaimPolicy,")
	print("    typed CursorTypes.SurfaceType / CursorTypes.ResetTrigger params")
	_report("complete_real_subclass.gd")
	print("")

	print("[3] Subclass of the REAL MouseReclaimPolicy implementing only 3 of 4")
	print("    (deliberately omits diagnostic_seed_position())")
	print("    Expected: compile failure naming diagnostic_seed_position")
	_report("incomplete_real_subclass.gd")
	print("")

	print("=".repeat(78))
	print("REPORT COMPLETE")
	print("=".repeat(78))
	quit(0)


func _report(filename: String) -> void:
	var path := SCRIPTS + filename
	var res = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		print("  RESULT: FAILED (load -> null)")
		return
	if not (res is GDScript):
		print("  RESULT: FAILED (not GDScript)")
		return
	var err: int = res.reload()
	if err != OK:
		print("  RESULT: FAILED (reload=%s) -- see engine error message above (names the missing method)" % error_string(err))
		return
	print("  RESULT: COMPILED OK")
