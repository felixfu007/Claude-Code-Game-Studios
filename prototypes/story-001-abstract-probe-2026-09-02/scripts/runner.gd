# Headless probe runner for Story 001 AC-S001-c compile-time verification.
#
# Uses the F-8 methodology already verified in this project
# (prototypes/engine-verification-spike-2026-08-20/scripts/verification_runner.gd):
# ResourceLoader.load(..., CACHE_MODE_IGNORE) followed by .reload() and
# checking the returned Error — NOT `load(path) != null`, which does not
# detect a failed compile (load() returns a non-null invalid resource on
# parse failure, not null).
extends SceneTree

const SCRIPTS := "res://"


func _initialize() -> void:
	print("=".repeat(78))
	print("STORY 001 — @abstract COMPILE PROBE — 2026-09-02")
	print("Godot version: %s" % str(Engine.get_version_info().get("string", "<unknown>")))
	print("=".repeat(78))
	print("")

	print("[1] 四種回傳型別(bool/float/void/Vector2)+ signal 同檔共存並編譯")
	print("    腳本:mouse_reclaim_policy_probe.gd")
	_report("mouse_reclaim_policy_probe.gd")
	print("")

	print("[2] 對照組:完整實作全部 4 個 @abstract 方法的具體子類別")
	print("    腳本:complete_subclass_probe.gd")
	_report("complete_subclass_probe.gd")
	print("")

	print("[3] 子類別只實作 3 個(故意漏 diagnostic_seed_position())")
	print("    腳本:incomplete_subclass_probe.gd")
	print("    預期:編譯失敗,且錯誤訊息指名缺少的是 diagnostic_seed_position")
	_report("incomplete_subclass_probe.gd")
	print("")

	print("=".repeat(78))
	print("REPORT COMPLETE")
	print("=".repeat(78))
	quit(0)


func _report(filename: String) -> void:
	var path := SCRIPTS + filename
	var res = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		print("  結果:FAILED (load -> null)")
		return
	if not (res is GDScript):
		print("  結果:FAILED (not GDScript)")
		return
	var err: int = res.reload()
	if err != OK:
		print("  結果:FAILED (reload=%s) -- 見上方引擎錯誤訊息(含指名缺少的方法)" % error_string(err))
		return
	print("  結果:COMPILED OK")
