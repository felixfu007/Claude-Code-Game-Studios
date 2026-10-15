## Throwaway headless probe for the cursor-surface-register-guard contract
## (docs/reviews/cursor-surface-register-guard-contract-2026-10-15.md).
##
## The contract's 機制十四 condition-2 mechanical proxy (第四節「條件 2 的機械判準」)
## is entirely unverified against the real engine — it assumes
## [method Control.get_theme_stylebox] returns the SAME [StyleBox] instance
## that was handed to [method Control.add_theme_stylebox_override] (reference
## equality), both for the violation case and for the contract's proposed
## escape hatch (overriding hover/focus with the SAME instance as normal).
## This probe calls the real engine APIs directly — it does not reimplement
## any theme-resolution rule.
##
## Also answers:
##   P1 -- Control.new() / Button.new() default focus_mode (needed to know
##         whether Phase 1's T3 "bare Button rejected" is exercising
##         condition 1 or condition 2).
##   P2 (partial) -- does an OUT-OF-TREE node (register() does not require
##         the node to be in the tree) answer has_theme_stylebox() /
##         get_theme_stylebox() queries the same way an in-tree one would.
##
## Run:
##   "<godot 4.7.1 console exe>" --headless --path . -s prototypes/godot-gdscript-specialist-cursor-guard-probe-2026-10-15/probe_stylebox_reference_equality.gd
extends SceneTree


func _initialize() -> void:
	print("=== Cursor surface guard probe (2026-10-15) ===")
	print("Engine version: %s" % Engine.get_version_info())

	_probe_p1_default_focus_mode()
	_probe_p2_out_of_tree_theme_query()
	_probe_p3_stylebox_reference_equality()

	print("\n=== Probe complete ===")
	quit()


func _probe_p1_default_focus_mode() -> void:
	print("\n--- P1: default focus_mode ---")
	var control := Control.new()
	var button := Button.new()
	print("Control.FOCUS_NONE=%d Control.FOCUS_CLICK=%d Control.FOCUS_ALL=%d" % [
		Control.FOCUS_NONE, Control.FOCUS_CLICK, Control.FOCUS_ALL
	])
	print("Control.new().focus_mode = %d" % control.focus_mode)
	print("Button.new().focus_mode = %d" % button.focus_mode)
	control.free()
	button.free()


func _probe_p2_out_of_tree_theme_query() -> void:
	print("\n--- P2 (partial): out-of-tree theme stylebox query ---")
	var control := Control.new()
	print("out-of-tree plain Control.has_theme_stylebox(&\"hover\") (no override, no built-in theme) = %s" % control.has_theme_stylebox(&"hover"))
	var button := Button.new()
	print("out-of-tree Button.has_theme_stylebox(&\"hover\") (no override, built-in Button theme) = %s" % button.has_theme_stylebox(&"hover"))
	print("out-of-tree Button.has_theme_stylebox(&\"normal\") (no override, built-in Button theme) = %s" % button.has_theme_stylebox(&"normal"))
	if button.has_theme_stylebox(&"hover"):
		var hover_sb: StyleBox = button.get_theme_stylebox(&"hover")
		var normal_sb: StyleBox = button.get_theme_stylebox(&"normal") if button.has_theme_stylebox(&"normal") else null
		print("out-of-tree Button built-in hover stylebox = %s" % hover_sb)
		print("out-of-tree Button built-in normal stylebox = %s" % normal_sb)
		print("out-of-tree Button built-in hover == normal (reference) -> %s" % (hover_sb == normal_sb))
	control.free()
	button.free()

	# Needed for the "escape hatch" test on a real Button (not just a plain
	# Control): does Button's built-in theme also provide a "focus" StyleBox,
	# distinct from "normal"? If so, the escape hatch test must override BOTH
	# "hover" and "focus" to the normal instance, not just "hover".
	var button2 := Button.new()
	print("out-of-tree Button.has_theme_stylebox(&\"focus\") (no override, built-in Button theme) = %s" % button2.has_theme_stylebox(&"focus"))
	if button2.has_theme_stylebox(&"focus"):
		var focus_sb: StyleBox = button2.get_theme_stylebox(&"focus")
		var normal_sb2: StyleBox = button2.get_theme_stylebox(&"normal")
		print("out-of-tree Button built-in focus == normal (reference) -> %s" % (focus_sb == normal_sb2))
	button2.free()


func _probe_p3_stylebox_reference_equality() -> void:
	print("\n--- P3: stylebox override reference equality (the guard's whole mechanical basis) ---")

	# Case 1: override "hover" only, on a plain Control with no built-in theme.
	# Question: does get_theme_stylebox() hand back the EXACT instance set?
	var sb := StyleBoxEmpty.new()
	var control := Control.new()
	control.add_theme_stylebox_override(&"hover", sb)
	var queried: StyleBox = control.get_theme_stylebox(&"hover")
	print("Case1: has_theme_stylebox(&\"hover\") after override = %s" % control.has_theme_stylebox(&"hover"))
	print("Case1: get_theme_stylebox(&\"hover\") == the instance passed to add_theme_stylebox_override -> %s" % (queried == sb))
	print("Case1: queried instance id = %d, original instance id = %d" % [queried.get_instance_id(), sb.get_instance_id()])

	# Case 2: the contract's proposed escape hatch -- override BOTH hover and
	# normal with the SAME instance. Guard must judge this as compliant.
	var shared_sb := StyleBoxEmpty.new()
	var control2 := Control.new()
	control2.add_theme_stylebox_override(&"hover", shared_sb)
	control2.add_theme_stylebox_override(&"normal", shared_sb)
	var hover_q: StyleBox = control2.get_theme_stylebox(&"hover")
	var normal_q: StyleBox = control2.get_theme_stylebox(&"normal")
	print("Case2 (escape hatch): hover_q == normal_q (both overridden to the SAME instance) -> %s" % (hover_q == normal_q))
	print("Case2 (escape hatch): hover_q == shared_sb -> %s, normal_q == shared_sb -> %s" % [hover_q == shared_sb, normal_q == shared_sb])

	# Case 3: the contract's named over-rejection case -- two DISTINCT
	# StyleBoxEmpty instances that are visually indistinguishable. Guard
	# (by contract's own design) is expected to treat this as a violation.
	var sb_a := StyleBoxEmpty.new()
	var sb_b := StyleBoxEmpty.new()
	var control3 := Control.new()
	control3.add_theme_stylebox_override(&"hover", sb_a)
	control3.add_theme_stylebox_override(&"normal", sb_b)
	var hover_q3: StyleBox = control3.get_theme_stylebox(&"hover")
	var normal_q3: StyleBox = control3.get_theme_stylebox(&"normal")
	print("Case3 (two distinct-but-identical-looking StyleBoxEmpty instances): hover == normal -> %s (contract expects false here -- documented over-rejection)" % (hover_q3 == normal_q3))

	# Case 4: "focus" key behaves the same as "hover" (機制十四 names both).
	var focus_sb := StyleBoxEmpty.new()
	var control4 := Control.new()
	control4.add_theme_stylebox_override(&"focus", focus_sb)
	var focus_q: StyleBox = control4.get_theme_stylebox(&"focus")
	print("Case4: has_theme_stylebox(&\"focus\") after override = %s" % control4.has_theme_stylebox(&"focus"))
	print("Case4: get_theme_stylebox(&\"focus\") == the instance passed to add_theme_stylebox_override -> %s" % (focus_q == focus_sb))

	control.free()
	control2.free()
	control3.free()
	control4.free()
