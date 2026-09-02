extends RefCounted
# Isolated in its own file so the runner can tell definitively whether
# execution ever reached the FIRST LINE of the function body, independent of
# any print-buffering questions in the runner itself.

static func typed_control_param(c: Control) -> String:
	print("      >> typed_control_param: ENTERED BODY, param is_instance_valid()=%s" % is_instance_valid(c))
	return "REACHED END typed_control_param"


static func typed_node_param(n: Node) -> String:
	print("      >> typed_node_param: ENTERED BODY, param is_instance_valid()=%s" % is_instance_valid(n))
	return "REACHED END typed_node_param"


static func untyped_variant_param(v: Variant) -> String:
	print("      >> untyped_variant_param: ENTERED BODY, param is_instance_valid()=%s" % is_instance_valid(v))
	return "REACHED END untyped_variant_param"
