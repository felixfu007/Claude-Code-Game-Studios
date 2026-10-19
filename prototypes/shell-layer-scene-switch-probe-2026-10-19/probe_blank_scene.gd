extends Node
## 2026-10-19 殼層場景切換探針(shell-layer-scene-switch-probe)用的最小空白場景腳本。
## 唯一用途:在 _ready()/_exit_tree() 印出時間戳與 instance_id,讓
## probe_scene_switch.gd 能從【被切入/切出的那個場景自己的角度】確認引擎事件順序,
## 不必只靠呼叫端(SceneTree)外部觀察推測。
## 刻意不含任何遊戲邏輯 —— 這是拋棄式試作(prototypes/),不受 src/ 規範約束,
## 也不得被正式程式碼引用。

func _ready() -> void:
	print("PROBE[BlankScene]: _ready() fired at frame=%d instance_id=%d" % [Engine.get_process_frames(), get_instance_id()])

func _exit_tree() -> void:
	print("PROBE[BlankScene]: _exit_tree() fired at frame=%d instance_id=%d" % [Engine.get_process_frames(), get_instance_id()])
