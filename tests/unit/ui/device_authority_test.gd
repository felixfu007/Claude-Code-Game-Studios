# DeviceAuthority（src/ui/battle/device_authority.gd）的單元測試。
#
# DeviceAuthority 是純邏輯裁決器（RefCounted），不碰 Input、InputEvent 或任何
# 節點，所以每一支測試都能用 new() 直接建構、headless 下完整驗證，不會留下
# 孤兒節點。命名慣例沿用既有先例（test_[scenario]_[expected]）。
extends GdUnitTestSuite


func test_init_current_matches_constructor_argument() -> void:
	# Arrange / Act
	var authority: DeviceAuthority = DeviceAuthority.new(DeviceAuthority.Device.PAD)

	# Assert
	assert_int(authority.current()).is_equal(DeviceAuthority.Device.PAD)


func test_init_default_current_is_mouse() -> void:
	# Arrange / Act
	var authority: DeviceAuthority = DeviceAuthority.new()

	# Assert
	assert_int(authority.current()).is_equal(DeviceAuthority.Device.MOUSE)


func test_resolve_frame_mouse_motion_only_grants_mouse() -> void:
	# Arrange — 起始主權設為 PAD，確保這支測試量到的是「轉移」而非「本來就是」
	var authority: DeviceAuthority = DeviceAuthority.new(DeviceAuthority.Device.PAD)

	# Act
	authority.note_mouse_motion()
	var changed: bool = authority.resolve_frame()

	# Assert
	assert_bool(changed).is_true()
	assert_int(authority.current()).is_equal(DeviceAuthority.Device.MOUSE)


func test_resolve_frame_pad_input_only_grants_pad() -> void:
	# Arrange — 起始主權為預設 MOUSE，確保量到的是「轉移」
	var authority: DeviceAuthority = DeviceAuthority.new()

	# Act
	authority.note_pad_input()
	var changed: bool = authority.resolve_frame()

	# Assert
	assert_bool(changed).is_true()
	assert_int(authority.current()).is_equal(DeviceAuthority.Device.PAD)


func test_resolve_frame_both_devices_same_frame_pad_wins() -> void:
	# Arrange — 起始主權為 MOUSE，確保平手裁決真的把它「搶」過來，而不是恰好維持原狀
	var authority: DeviceAuthority = DeviceAuthority.new(DeviceAuthority.Device.MOUSE)

	# Act — 同一畫格兩個旗標都亮
	authority.note_mouse_motion()
	authority.note_pad_input()
	var changed: bool = authority.resolve_frame()

	# Assert
	assert_bool(changed).is_true()
	assert_int(authority.current()).is_equal(DeviceAuthority.Device.PAD)


func test_resolve_frame_mouse_set_down_then_pad_picked_up_authority_transfers_to_pad() -> void:
	# 這支測試就是為了防「滑鼠恆有主權」這個做錯法而寫的（見管理者第二段裁決）：
	# 玩家先用滑鼠玩了幾個畫格取得主權，之後滑鼠完全不再動，只剩手把輸入 ——
	# 若實作誤把「滑鼠優先」當成常態狀態而非平手裁決，這支測試會失敗在最後一個
	# assert（主權會卡在 MOUSE 不放）。
	# Arrange — 滑鼠先動了三個畫格，取得並維持主權
	var authority: DeviceAuthority = DeviceAuthority.new()
	for _i in range(3):
		authority.note_mouse_motion()
		authority.resolve_frame()
	assert_int(authority.current()).is_equal(DeviceAuthority.Device.MOUSE)

	# Act — 放下滑鼠、拿起手把：接下來的畫格滑鼠完全不動，只有手把輸入
	authority.note_pad_input()
	var changed: bool = authority.resolve_frame()

	# Assert
	assert_bool(changed).is_true()
	assert_int(authority.current()).is_equal(DeviceAuthority.Device.PAD)


func test_resolve_frame_no_input_leaves_authority_unchanged_and_returns_false() -> void:
	# Arrange
	var authority: DeviceAuthority = DeviceAuthority.new(DeviceAuthority.Device.PAD)

	# Act — 兩個旗標都沒亮就呼叫
	var changed: bool = authority.resolve_frame()

	# Assert
	assert_bool(changed).is_false()
	assert_int(authority.current()).is_equal(DeviceAuthority.Device.PAD)


# 🔴 GDScript 陷阱記錄（本專案第一次撞到，寫下來給下一個寫測試的人）：
# lambda 按值捕捉區域變數 —— 若計數格是一個 int 區域變數，closure 裡的
# `emit_count += 1` 改的是捕捉當下的副本，外層變數永遠不變。
# **後果不是「測試會失敗」，是「斷言計數為 0 的測試會永遠綠燈」** ——
# 這比失敗更危險：訊號真的有發，斷言「沒發」的測試也照樣通過，
# 假陽性比假陰性更難被發現。
# 正確作法：計數格用參考型別（`Array`/`Dictionary`），對它的元素賦值是
# 透過共用參照生效，不受按值捕捉影響。下面兩支測試都用 `Array[int]`。
func test_resolve_frame_change_emits_authority_changed_exactly_once() -> void:
	# Arrange
	var authority: DeviceAuthority = DeviceAuthority.new()
	var emit_count: Array[int] = [0]
	var last_value: Array[DeviceAuthority.Device] = [DeviceAuthority.Device.MOUSE]
	authority.authority_changed.connect(
		func(new_device: DeviceAuthority.Device) -> void:
			emit_count[0] += 1
			last_value[0] = new_device
	)

	# Act
	authority.note_pad_input()
	authority.resolve_frame()

	# Assert
	assert_int(emit_count[0]).is_equal(1)
	assert_int(last_value[0]).is_equal(DeviceAuthority.Device.PAD)


func test_resolve_frame_no_change_does_not_emit_authority_changed() -> void:
	# 先確實觸發一次訊號、斷言計數變成 1，再做一次不該發射的操作、斷言計數
	# 維持 1 不動 —— 這樣「計數器根本沒在動」（前一版的假陽性陷阱）會在第
	# 一個斷言就被抓出來，不會讓第二個斷言在一個從未被證明會動的計數器上
	# 「通過」。
	# Arrange
	var authority: DeviceAuthority = DeviceAuthority.new(DeviceAuthority.Device.PAD)
	var emit_count: Array[int] = [0]
	authority.authority_changed.connect(func(_d: DeviceAuthority.Device) -> void: emit_count[0] += 1)

	# Act 1 — 確實會改變主權的操作，證明計數器真的在動
	authority.note_mouse_motion()
	authority.resolve_frame()
	assert_int(emit_count[0]).is_equal(1)

	# Act 2 — 兩個旗標都沒亮，主權不會變，計數器不該再動
	authority.resolve_frame()

	# Assert
	assert_int(emit_count[0]).is_equal(1)


func test_resolve_frame_clears_flags_after_call() -> void:
	# 驗證旗標在 resolve_frame() 後確實被清除：第一次呼叫吃掉滑鼠移動旗標拿到
	# 主權，第二次呼叫不重新記任何旗標就呼叫，應回 false 且主權不變 ——
	# 若旗標沒被清掉，第二次會誤以為滑鼠這一格又動了。
	# Arrange
	var authority: DeviceAuthority = DeviceAuthority.new(DeviceAuthority.Device.PAD)
	authority.note_mouse_motion()
	var first_changed: bool = authority.resolve_frame()
	assert_bool(first_changed).is_true()
	assert_int(authority.current()).is_equal(DeviceAuthority.Device.MOUSE)

	# Act — 不記任何旗標，直接再呼叫一次
	var second_changed: bool = authority.resolve_frame()

	# Assert
	assert_bool(second_changed).is_false()
	assert_int(authority.current()).is_equal(DeviceAuthority.Device.MOUSE)
