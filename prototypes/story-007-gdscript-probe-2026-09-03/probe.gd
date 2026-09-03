extends SceneTree

class Emitter extends RefCounted:
	signal src(v: int)
	func fire(v: int) -> void:
		src.emit(v)

class Relay extends RefCounted:
	signal dst(v: int)
	const K: String = "k"
	enum E { A, B }
	var _plain: int = 1
	var _vec: Vector2 = Vector2.ZERO
	var diagnostic_n: int = 0
	var _e: Emitter
	func _init(e: Emitter) -> void:
		_e = e
		_e.src.connect(dst.emit)

var _seen: int = -1

func _on_dst(v: int) -> void:
	_seen = v

func _initialize() -> void:
	var e := Emitter.new()
	var r := Relay.new(e)
	r.dst.connect(_on_dst)
	e.fire(42)
	print("PROBE1 signal.emit-as-Callable forward -> seen=", _seen)

	var names: Array = []
	for p: Dictionary in r.get_script().get_script_property_list():
		names.append("%s|usage=%d" % [p.get("name"), p.get("usage", 0)])
	print("PROBE2 get_script_property_list -> ", names)

	var t: int = 0
	print("PROBE3 CAT flag = ", PROPERTY_USAGE_CATEGORY)
	quit()
