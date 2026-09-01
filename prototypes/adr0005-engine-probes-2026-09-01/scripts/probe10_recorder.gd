extends Node
# ADR-0005 Probe #10 —— 拋棄式零件,不宣告 class_name。

var label: String = ""
var main: Node = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if main:
			main.log_event("FOCUS_OUT %s" % label)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if main:
			main.log_event("FOCUS_IN  %s" % label)


func _process(_delta: float) -> void:
	if main:
		main.log_event_silent("PROCESS   %s" % label)
