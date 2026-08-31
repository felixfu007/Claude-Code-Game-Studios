## Asserts that every data file the game needs at runtime actually shipped inside
## an exported .pck.
##
## [b]Why this exists:[/b] on 2026-08-28 the game shipped with
## [code]export_filter="all_resources"[/code] and an empty
## [code]include_filter[/code]. Plain [code].txt[/code] data files are not Godot
## resources, so they were silently left out of the .pck. The exported build
## opened to a blank board while all 151 unit tests stayed green — unit tests run
## against the project directory and can never observe .pck contents.
##
## [b]This script must be run against a THROWAWAY EMPTY PROJECT[/b], never against
## the real project directory. Mounted-vs-on-disk is the whole point: inside the
## real project [method FileAccess.file_exists] returns [code]true[/code] for these
## paths whether or not they were packaged, which would make this check pass
## always — the exact "test that cannot fail" failure mode
## [code].claude/docs/coding-standards.md[/code] warns about. The wrapper
## [code]tools/build/verify_export.sh[/code] creates that empty project for you.
##
## Usage:
##   godot --headless --path <empty-project> -s res://verify_pck_contents.gd \
##       -- <pck-path> <res://required/file> [<res://required/file> ...]
##
## Exit codes: 0 pass, 1 missing/empty file, 2 bad usage, 3 pack failed to mount.
extends SceneTree


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		print("USAGE: -- <pck-path> <res://required-file> [more...]")
		quit(2)
		return

	var pck_path: String = args[0]
	if not ProjectSettings.load_resource_pack(pck_path, false):
		print("FAIL_MOUNT: could not load resource pack: %s" % pck_path)
		quit(3)
		return
	print("MOUNTED: %s" % pck_path)

	var missing: int = 0
	var checked: int = 0
	for i: int in range(1, args.size()):
		var path: String = args[i]
		checked += 1
		var exists: bool = FileAccess.file_exists(path)
		var body: String = FileAccess.get_file_as_string(path) if exists else ""
		# Empty counts as failure too: a zero-byte data file produces the same
		# blank board as a missing one, so "present" alone is not good enough.
		if not exists or body.strip_edges().is_empty():
			print("MISSING_OR_EMPTY: %s (exists=%s, bytes=%d)" % [path, exists, body.length()])
			missing += 1
		else:
			print("OK: %s (%d bytes)" % [path, body.length()])

	print("CHECKED=%d MISSING=%d" % [checked, missing])
	if missing > 0:
		print("RESULT=FAIL")
		quit(1)
		return
	print("RESULT=PASS")
	quit(0)
