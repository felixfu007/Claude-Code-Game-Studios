extends Node
# ADR-0005 Probe #2 —— 拋棄式零件,不宣告 class_name。

var label: String = ""
var main: Node = null


func _input(event: InputEvent) -> void:
	# 刻意直接比對 keycode,不呼叫 InputMap.event_is_action() —— #2 與 #13 是兩個獨立問題,
	# 不希望 #2 的量測結果被 #13 的答案汙染。
	if event is InputEventKey:
		var k: InputEventKey = event
		if k.keycode == KEY_UP and k.pressed and not k.echo:
			if main:
				main.log_event("INPUT   %s" % label)


func _process(_delta: float) -> void:
	if main:
		main.log_event("PROCESS %s" % label)
