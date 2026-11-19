extends GdUnitTestSuite
## story-020c AC(第 4 項)—— 確認面板矩形不得與底部說明列/按鈕列矩形相交。
## 非甲/乙類(不讀檔);全部呼叫真實版面函式,不重刻公式。
## 範圍聲明:只證明面板「矩形」不與說明列/按鈕列相交;不證明列內文字塞得進被壓縮後的矩形
## (960x540 高度由 484 壓到 431,內容是否裁切需開窗人眼確認,headless 量不到)。

const _SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]


func _overlaps_bar_or_buttons(panel: Rect2, size: Vector2i) -> bool:
	if panel.intersects(HudLayout.controls_hint_bg_rect(size)):
		return true
	for i: int in range(HudLayout.END_ACTION_BUTTON_INDEX + 1):
		if panel.intersects(HudLayout.hud_action_button_rect(size, i)):
			return true
	return false


func test_card_confirm_panel_rect_does_not_intersect_hint_bar_or_buttons() -> void:
	for size: Vector2i in _SIZES:
		assert_bool(_overlaps_bar_or_buttons(CardConfirmPanel.panel_rect(size), size)) \
			.override_failure_message("overlap @%s" % size).is_false()


## 敏感度證明:020a 的舊幾何(高度 22 fpx、不夾上限,垂直置中於 safe_rect)在 1920x1080 會與
## 說明列相交 —— 偵測器抓得到該缺陷。
func test_sensitivity_proof_old_unclamped_geometry_is_detected_at_1080p() -> void:
	var size: Vector2i = Vector2i(1920, 1080)
	var fpx: float = float(HudLayout.font_size(size))
	var safe: Rect2 = HudLayout.safe_rect(size)
	var old_size: Vector2 = Vector2(fpx * CardConfirmPanel.PANEL_WIDTH_FPX_MULTIPLIER, fpx * CardConfirmPanel.PANEL_HEIGHT_FPX_MULTIPLIER)
	var old_panel: Rect2 = Rect2(safe.position + (safe.size - old_size) / 2.0, old_size)
	assert_bool(_overlaps_bar_or_buttons(old_panel, size)).is_true()
