extends Node
@export var label: String = "?"
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var svc := get_node("SVC")
	var sv := get_node("SVC/SV")
	print("VERIFY 父節點型別=", label, "  容器尺寸=", svc.size, "  內部畫布尺寸=", sv.size)
	get_tree().quit()
