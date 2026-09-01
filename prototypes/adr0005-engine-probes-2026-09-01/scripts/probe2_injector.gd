extends Node
# ADR-0005 Probe #2 —— 注入端。刻意用 Timer.timeout 觸發(而非 _process()/_physics_process()
# 本身),讓注入點落在一個與五個 recorder 的 process_priority 排布無關的時機。

const NUM_INJECTIONS := 6
const INTERVAL_SEC := 0.35

var main: Node = null
var _remaining: int = NUM_INJECTIONS
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = INTERVAL_SEC
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)
	_timer.start()


func _on_timeout() -> void:
	if main:
		main.log_event("INJECT  (about to call Input.parse_input_event, remaining=%d)" % _remaining)
	var e := InputEventKey.new()
	e.keycode = KEY_UP
	e.physical_keycode = KEY_UP
	e.pressed = true
	e.echo = false
	Input.parse_input_event(e)
	_remaining -= 1
	if _remaining > 0:
		_timer.start()
	elif main:
		main.call_deferred("on_injections_done")
