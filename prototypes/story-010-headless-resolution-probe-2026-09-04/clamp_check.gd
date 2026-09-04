## 覆核專家宣稱:設定 min_size 大於當下視窗尺寸時,引擎會立刻把視窗撐大。
extends SceneTree
func _initialize() -> void:
	root.size = Vector2i(480, 270)
	print("設定前 root.size = ", root.size, "  min_size = ", root.min_size)
	root.min_size = Vector2i(960, 540)
	print("設 min_size=(960,540) 之後,立刻讀 root.size = ", root.size)
	print("→ 專家宣稱成立嗎: ", root.size == Vector2i(960, 540))
	quit()
