extends SceneTree
## Self-contained probe: does `var a: Array[int] = (expr if cond else [])` crash
## at runtime, and under what conditions?
##
## Run ONE case per invocation (isolation — a runtime SCRIPT ERROR aborts the
## calling function, and we don't want one case's abort to hide whether a
## later case would also have run/crashed):
##
##   godot --headless --path . -s prototypes/.../probe_ternary_typed_array.gd -- --case=<name>
##
## Valid --case values are the match arms in _run_case() below. See run_all.sh
## in this directory for the full list run in one batch.

func _get_dynamic_array_int() -> Array:
	return [1, 2, 3]

func _get_dynamic_array_string() -> Array:
	return ["a", "b"]

func _get_dynamic_array_vec2i() -> Array:
	return [Vector2i(1, 1)]

func _get_dynamic_dict() -> Dictionary:
	return {"k": 1}

## Mirrors the REAL production shape: BattleController.legal_targets() at
## src/gameplay/battle/battle_controller.gd:403 is declared `-> Array[int]`
## (typed), not plain Array. q1/q2/q3 above all used a plain-`Array`-returning
## source, which is NOT what the real bug looked like. This function matches
## the real signature so q5 reproduces the actual production shape exactly.
func _get_typed_array_int() -> Array[int]:
	return [1, 2, 3]


func _run_case(case_name: String) -> void:
	match case_name:
		# --- Q1: does the crash depend on which branch is actually taken at runtime? ---
		"q1_true":
			print("CASE q1_true: BEGIN")
			var cond := true
			var a: Array[int] = (_get_dynamic_array_int() if cond else [])
			print("CASE q1_true: END a=", a, " is_typed=", a.is_typed())
		"q1_false":
			print("CASE q1_false: BEGIN")
			var cond := false
			var a: Array[int] = (_get_dynamic_array_int() if cond else [])
			print("CASE q1_false: END a=", a, " is_typed=", a.is_typed())

		# --- Q2: can annotating the empty-array branch save it? ---
		"q2_as_cast_false":
			print("CASE q2_as_cast_false: BEGIN")
			var cond := false
			var a: Array[int] = (_get_dynamic_array_int() if cond else ([] as Array[int]))
			print("CASE q2_as_cast_false: END a=", a, " is_typed=", a.is_typed())
		"q2_as_cast_true":
			print("CASE q2_as_cast_true: BEGIN")
			var cond := true
			var a: Array[int] = (_get_dynamic_array_int() if cond else ([] as Array[int]))
			print("CASE q2_as_cast_true: END a=", a, " is_typed=", a.is_typed())
		"q2_pretyped_var_false":
			print("CASE q2_pretyped_var_false: BEGIN")
			var cond := false
			var empty_typed: Array[int] = []
			var a: Array[int] = (_get_dynamic_array_int() if cond else empty_typed)
			print("CASE q2_pretyped_var_false: END a=", a, " is_typed=", a.is_typed())
		"q2_typed_array_constructor_false":
			print("CASE q2_typed_array_constructor_false: BEGIN")
			var cond := false
			var a: Array[int] = (_get_dynamic_array_int() if cond else (Array([], TYPE_INT, "", null)))
			print("CASE q2_typed_array_constructor_false: END a=", a, " is_typed=", a.is_typed())

		# --- Q3: same shape on Array[String] / Array[Vector2i] / typed Dictionary ---
		"q3_string_false":
			print("CASE q3_string_false: BEGIN")
			var cond := false
			var a: Array[String] = (_get_dynamic_array_string() if cond else [])
			print("CASE q3_string_false: END a=", a)
		"q3_string_true":
			print("CASE q3_string_true: BEGIN")
			var cond := true
			var a: Array[String] = (_get_dynamic_array_string() if cond else [])
			print("CASE q3_string_true: END a=", a)
		"q3_vector2i_false":
			print("CASE q3_vector2i_false: BEGIN")
			var cond := false
			var a: Array[Vector2i] = (_get_dynamic_array_vec2i() if cond else [])
			print("CASE q3_vector2i_false: END a=", a)
		"q3_typed_dict_false":
			print("CASE q3_typed_dict_false: BEGIN")
			var cond := false
			var d: Dictionary[String, int] = (_get_dynamic_dict() if cond else {})
			print("CASE q3_typed_dict_false: END d=", d)
		"q3_typed_dict_true":
			print("CASE q3_typed_dict_true: BEGIN")
			var cond := true
			var d: Dictionary[String, int] = (_get_dynamic_dict() if cond else {})
			print("CASE q3_typed_dict_true: END d=", d)
		"q3_plain_dict_false":
			print("CASE q3_plain_dict_false: BEGIN")
			var cond := false
			var d: Dictionary = (_get_dynamic_dict() if cond else {})
			print("CASE q3_plain_dict_false: END d=", d)

		# --- Q4: reverse control — untyped Array target, same ternary shape ---
		"q4_untyped_target_false":
			print("CASE q4_untyped_target_false: BEGIN")
			var cond := false
			var a: Array = (_get_dynamic_array_int() if cond else [])
			print("CASE q4_untyped_target_false: END a=", a)
		"q4_untyped_target_true":
			print("CASE q4_untyped_target_true: BEGIN")
			var cond := true
			var a: Array = (_get_dynamic_array_int() if cond else [])
			print("CASE q4_untyped_target_true: END a=", a)

		# --- Q5: EXACT production shape — source function returns Array[int]
		#     (typed), else-branch is untyped `[]`. This is what
		#     battle_screen.gd's `card_target_legal_ids` line actually was.
		"q5_typed_source_true":
			print("CASE q5_typed_source_true: BEGIN")
			var cond := true
			var a: Array[int] = (_get_typed_array_int() if cond else [])
			print("CASE q5_typed_source_true: END a=", a, " is_typed=", a.is_typed())
		"q5_typed_source_false":
			print("CASE q5_typed_source_false: BEGIN")
			var cond := false
			var a: Array[int] = (_get_typed_array_int() if cond else [])
			print("CASE q5_typed_source_false: END a=", a, " is_typed=", a.is_typed())

		_:
			print("UNKNOWN CASE: '", case_name, "'")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	print("PROBE ARGS = ", args)
	var case_name := ""
	for a in args:
		if a.begins_with("--case="):
			case_name = a.substr(len("--case="))
	if case_name == "":
		print("NO --case= ARG SUPPLIED")
	else:
		_run_case(case_name)
	print("PROBE REACHED END OF _init() (script did not hard-abort)")
	quit()
