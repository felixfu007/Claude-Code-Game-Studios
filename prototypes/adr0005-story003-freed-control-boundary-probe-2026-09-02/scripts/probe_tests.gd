extends RefCounted
# Isolation layer, same technique as
# prototypes/xcheck-gdscript-specialist-2026-08-20/scripts/x11c_typed_boundary_assign.gd:
# each risky call is wrapped in its own function with an UNTYPED (Variant)
# parameter, so the runner can hand it a possibly-freed object without
# tripping the boundary check on THIS call. The risky, statically-typed call
# happens INSIDE the wrapper. The runner invokes each wrapper via
# Callable.call(), which safely absorbs an abort one level down (established
# by prototypes/engine-verification-spike-2026-08-20 F-10): if the wrapper
# aborts partway, .call() returns the zero value ("" for a -> String
# function) and the runner itself keeps running.
#
# Each wrapper prints "ENTERED BODY" (via callee.gd) only if
# Callee's typed-parameter body was actually reached, and "REACHED END" as
# its own last statement before returning — the same two-marker technique
# used throughout the 2026-08-20 spikes to distinguish "ran to completion"
# from "aborted partway".

const Callee := preload("res://scripts/callee.gd")


static func test_typed_control_param_with_freed_object(maybe_freed: Variant) -> String:
	print("      >> wrapper entering. is_instance_valid=%s  ==null:%s" % [
		str(is_instance_valid(maybe_freed)), str(maybe_freed == null)
	])
	var r: String = Callee.typed_control_param(maybe_freed)
	print("      >> wrapper: call returned [%s], about to return" % r)
	return "REACHED END wrapper result=[%s]" % r


static func test_typed_node_param_with_freed_object(maybe_freed: Variant) -> String:
	print("      >> wrapper entering. is_instance_valid=%s  ==null:%s" % [
		str(is_instance_valid(maybe_freed)), str(maybe_freed == null)
	])
	var r: String = Callee.typed_node_param(maybe_freed)
	print("      >> wrapper: call returned [%s], about to return" % r)
	return "REACHED END wrapper result=[%s]" % r


static func test_untyped_variant_param_with_freed_object(maybe_freed: Variant) -> String:
	print("      >> wrapper entering. is_instance_valid=%s  ==null:%s" % [
		str(is_instance_valid(maybe_freed)), str(maybe_freed == null)
	])
	var r: String = Callee.untyped_variant_param(maybe_freed)
	print("      >> wrapper: call returned [%s], about to return" % r)
	return "REACHED END wrapper result=[%s]" % r


static func test_typed_control_param_with_valid_object(valid_control: Variant) -> String:
	print("      >> wrapper entering (control case: still-valid object). is_instance_valid=%s" % str(is_instance_valid(valid_control)))
	var r: String = Callee.typed_control_param(valid_control)
	print("      >> wrapper: call returned [%s], about to return" % r)
	return "REACHED END wrapper result=[%s]" % r


static func test_typed_control_param_with_null(_unused: Variant) -> String:
	print("      >> wrapper entering (control case: literal null)")
	var r: String = Callee.typed_control_param(null)
	print("      >> wrapper: call returned [%s], about to return" % r)
	return "REACHED END wrapper result=[%s]" % r
