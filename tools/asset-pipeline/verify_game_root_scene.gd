extends SceneTree
## 驗證 res://src/ui/GameRoot.tscn 真的能載入、結構符合預期。
## 執行方式: godot --headless --script tools/asset-pipeline/verify_game_root_scene.gd

func _initialize() -> void:
	print("=== VERIFY GameRoot.tscn START ===")

	var packed: PackedScene = load("res://src/ui/GameRoot.tscn")
	assert(packed != null, "load() returned null — scene failed to load")
	print("[1] load() succeeded, resource = ", packed)

	var instance: Node = packed.instantiate()
	assert(instance != null, "instantiate() returned null")
	print("[2] instantiate() succeeded, root = ", instance.name, " (", instance.get_class(), ")")

	var world_container: Node = instance.get_node("WorldViewportContainer")
	assert(world_container is SubViewportContainer)
	print("[3] WorldViewportContainer found, stretch = ", world_container.stretch,
		", stretch_shrink = ", world_container.stretch_shrink,
		", texture_filter = ", world_container.texture_filter, " (1 == Nearest)")
	assert(world_container.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	assert(world_container.stretch == true)
	assert(world_container.stretch_shrink == 1)

	var world_viewport: Node = world_container.get_node("WorldViewport")
	assert(world_viewport is SubViewport)
	print("[4] WorldViewport found, class = ", world_viewport.get_class())

	var ui_layer: Node = instance.get_node("UILayer")
	assert(ui_layer is CanvasLayer)
	print("[5] UILayer found, class = ", ui_layer.get_class())

	instance.queue_free()
	print("=== VERIFY GameRoot.tscn END — ALL ASSERTIONS PASSED ===")
	quit(0)
