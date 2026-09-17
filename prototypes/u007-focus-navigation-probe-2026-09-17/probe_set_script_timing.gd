## Throwaway headless probe — closes a gap an independent review (godot-specialist,
## 2026-09-17) correctly caught: `tests/unit/ui/menu/battle_menu_layout_test.gd`
## claimed "pre-ready set_script() preserves @onready resolution and the
## inheritance dispatch chain — verified" and pointed at THIS directory, but
## none of probe_focus_navigation.gd / _v2.gd / _v3.gd ever load
## `BattleMenu.tscn` or call `set_script()` — all three build raw
## `Button.new()` trees. The claim was directionally correct (the test file's
## own sensitivity-proof tests do this and pass) but the specific file path
## attached to it did not contain what it claimed to contain. This probe makes
## that sentence true by actually doing the measurement here, and adds the
## control group the review asked for: what happens if the script is swapped
## AFTER the node has already entered the tree and run _ready() once — this is
## the exact scenario `.claude/rules/test-standards.md`'s Category C describes
## as "本專案從未驗證" for @onready references.
##
## 🔴 First run of this probe (see run_output_set_script_timing.txt's git
## history / the report this accompanies) synchronously called grab_focus()
## right after add_child() with NO awaited process_frame in between, unlike
## every other probe in this directory — that produced a confusing false
## reading (return_row.has_focus() == false even for the UNTOUCHED script,
## and an explicit engine error "Condition '!is_inside_tree()' is true" on
## the second grab_focus() call) that had nothing to do with the actual
## pre/post-ready question and everything to do with the same kind of
## timing gap Claim about VBoxContainer layout already found earlier in this
## story. Fixed by awaiting frames the same way probe_focus_navigation_v2.gd
## / _v3.gd already do — kept as a comment here rather than silently
## overwritten, per this project's own "first result confusing → re-measure,
## keep both" discipline (see this directory's README).
##
## Run:
##   "<godot path>" --headless --path . -s prototypes/u007-focus-navigation-probe-2026-09-17/probe_set_script_timing.gd
extends SceneTree

const SCENE_PATH: String = "res://src/ui/menu/BattleMenu.tscn"


## Mirrors the mutant shape used in battle_menu_layout_test.gd's own
## sensitivity proofs: overrides a method BattleMenu's own _ready() calls
## indirectly (via a connected signal), so a successful override call proves
## the INHERITANCE DISPATCH chain works, not just that the object didn't crash.
class _ProbeMutant extends BattleMenu:
	var mutant_focus_entered_called: bool = false
	func _on_row_focus_entered(row: Button) -> void:
		mutant_focus_entered_called = true
		super._on_row_focus_entered(row)


func _initialize() -> void:
	print("=== U-007 set_script() timing probe (2026-09-17) ===")
	print("Answers: does pre-ready set_script() preserve @onready resolution")
	print("and the inheritance dispatch chain? What about post-ready swap")
	print("(the untested scenario test-standards.md Category C names)?")

	await _probe_pre_ready_swap()
	await _probe_post_ready_swap()

	quit()


## ── Case A: set_script() BEFORE add_child() (the technique this project's ──
## ── sensitivity-proof tests actually use) ───────────────────────────────────
func _probe_pre_ready_swap() -> void:
	print("\n--- Case A: set_script() BEFORE add_child() (pre-ready) ---")
	var instance: Control = load(SCENE_PATH).instantiate()
	instance.set_script(_ProbeMutant)
	get_root().add_child(instance)
	await process_frame
	await process_frame

	# @onready resolution check: get_node() must find the real child (proves
	# the .tscn's node tree resolved correctly under the swapped script).
	var return_row: Button = instance.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")
	print("A: @onready node resolves via get_node() = ", return_row != null, " (", return_row, ")")
	print("A: return_row.has_focus() (default-focus _ready() logic ran) = ", return_row.has_focus())

	# Inheritance dispatch check: move focus to a DIFFERENT row and confirm
	# the OVERRIDDEN method actually fired (not silently skipped).
	var end_phase_row: Button = instance.get_node("Panel/ContentMargin/Rows/EndPhaseRow")
	end_phase_row.grab_focus()
	await process_frame
	print("A: mutant override _on_row_focus_entered() was called = ", instance.get("mutant_focus_entered_called"))
	print("A: marker text still applied by super call = '", end_phase_row.text, "'")

	get_root().remove_child(instance)
	instance.queue_free()
	await process_frame


## ── Case B: set_script() AFTER add_child() / after _ready() already ran ────
## ── (the scenario this project has never measured before now) ──────────────
func _probe_post_ready_swap() -> void:
	print("\n--- Case B: set_script() AFTER add_child() (post-ready) ---")
	var instance: Control = load(SCENE_PATH).instantiate()
	get_root().add_child(instance)
	await process_frame
	await process_frame

	# Let the ORIGINAL script's _ready() run to completion first.
	var return_row_before: Button = instance.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")
	print("B: (original script) return_row.has_focus() before swap = ", return_row_before.has_focus())

	instance.set_script(_ProbeMutant)
	print("B: script after post-ready swap = ", instance.get_script())

	# Does @onready state survive? Query the SAME node path again.
	var return_row: Button = null
	var path_resolves: bool = instance.has_node("Panel/ContentMargin/Rows/ReturnToBattleRow")
	if path_resolves:
		return_row = instance.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")
	print("B: get_node() still resolves the same path after swap = ", path_resolves, " (", return_row, ")")
	print("B: is it the SAME Button instance as before the swap = ", return_row == return_row_before)

	# Does the mutant's OWN _ready() run again (re-triggering focus_entered
	# connections a second time, potentially double-connecting signals), or
	# does _ready() only run once per node lifetime regardless of script swaps?
	print("B: mutant_focus_entered_called immediately after swap (before any new signal) = ",
		instance.get("mutant_focus_entered_called"))

	var end_phase_row: Button = instance.get_node("Panel/ContentMargin/Rows/EndPhaseRow")
	end_phase_row.grab_focus()
	await process_frame
	print("B: mutant override _on_row_focus_entered() was called after grab_focus = ",
		instance.get("mutant_focus_entered_called"))
	print("B: marker text after swap + grab_focus = '", end_phase_row.text, "'")
	print("B: reading above answers whether a focus_entered Callable bound BEFORE the swap")
	print("   dispatches through the NEW script's override at call time (polymorphic,")
	print("   i.e. GDScript methods are resolved dynamically per-call) or is frozen to the")
	print("   OLD script's method (bound at connect() time).")

	get_root().remove_child(instance)
	instance.queue_free()
	await process_frame
