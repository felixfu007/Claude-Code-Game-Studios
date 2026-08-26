extends SceneTree
## 一次性建構腳本 —— 產生 res://src/ui/GameRoot.tscn(世界層/介面層分層骨架)。
## 執行方式: godot --headless --script tools/asset-pipeline/build_game_root_scene.gd
##
## 世界層(WorldViewportContainer + WorldViewport)與介面層(UILayer)分層的理由,
## 見 .claude/docs/technical-preferences.md「美術方向與像素風專案設定」節。
## 本腳本只建立骨架節點與其關鍵屬性,不含任何玩法內容。

func _initialize() -> void:
	print("=== BUILD GameRoot.tscn START ===")

	var game_root := Node2D.new()
	game_root.name = "GameRoot"

	var world_container := SubViewportContainer.new()
	world_container.name = "WorldViewportContainer"
	world_container.stretch = true
	world_container.stretch_shrink = 1
	world_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 极易漏掉的手动覆写：SubViewportContainer.texture_filter 预设是 Inherit(0)，
	# 不覆写会在世界层贴回外层画面这一步被 Linear 再模糊一次。
	world_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	game_root.add_child(world_container)
	world_container.owner = game_root

	var world_viewport := SubViewport.new()
	world_viewport.name = "WorldViewport"
	# 不手动设置 world_viewport.size —— 由容器的 stretch/stretch_shrink 反推。
	world_container.add_child(world_viewport)
	world_viewport.owner = game_root

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	game_root.add_child(ui_layer)
	ui_layer.owner = game_root

	var packed := PackedScene.new()
	var pack_err: int = packed.pack(game_root)
	print("[pack] error = ", pack_err, " (0 == OK)")

	var save_err: int = ResourceSaver.save(packed, "res://src/ui/GameRoot.tscn")
	print("[save] error = ", save_err, " (0 == OK)")

	print("=== BUILD GameRoot.tscn END ===")
	quit(0 if (pack_err == 0 and save_err == 0) else 1)
