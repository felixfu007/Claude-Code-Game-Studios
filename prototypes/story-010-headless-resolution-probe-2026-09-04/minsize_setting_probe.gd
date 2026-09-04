## 查核專家宣稱:Godot 4.7.1 的 project.godot 沒有最小視窗尺寸設定,只能用程式設。
extends SceneTree
func _initialize() -> void:
	print("--- 全部 display/window/size/* 設定鍵 ---")
	for p in ProjectSettings.get_property_list():
		var n := String(p.name)
		if n.begins_with("display/window/size/"):
			print("  ", n, " = ", ProjectSettings.get_setting(n))
	print()
	print("--- 直接試探幾個可能的鍵名 ---")
	for k in ["display/window/size/window_min_width", "display/window/size/window_min_height",
			  "display/window/size/min_width", "display/window/size/min_height",
			  "display/window/size/minimum_width", "display/window/size/minimum_height"]:
		print("  ", k, " has_setting=", ProjectSettings.has_setting(k))
	quit()
