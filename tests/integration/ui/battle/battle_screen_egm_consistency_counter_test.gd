## battle-hud story-003 (`production/epics/battle-hud/story-003-consistency-counter-display.md`)
## —— EGM 一致率計數器(「猜中 M/N」)的畫面呈現,真實 BattleScreen.tscn 載入。
##
## 載入方式比照 `battle_screen_egm_guess_selector_test.gd`:load() 真實場景、
## GameSettings.set_egm_enabled() 於 instantiate 之前設定,不組替身節點鏈。
##
## 🔴 檔案 I/O 例外聲明(.claude/rules/test-standards.md 2026-09-16 裁決):
##   本檔的 AC4/AC5/AC6 三條【乙類】測試唯讀 `res://src/ui/battle/battle_screen.gd` 與
##   `hud_layout.gd` 的原始碼文字,斷言「沒有自行複製字級公式 / 沒有寫死玩家可見字串 /
##   沒有存檔寫入呼叫」。為什麼不能用注入取代:斷言對象就是原始碼的寫法本身。
##   🔴 乙類自陳:這些掃描【不等於窮盡】—— 反射存取、.tscn、shader、GDExtension 不在
##   視野內;AC6 只證明這兩支檔沒有出現常見的存檔 API 字樣,不證明別處沒有人去讀計數器。
##
## 🔴 敏感度證明對照(2026-09-16 門檻,逐條):
##   - AC1 文字內容:有常駐變種 _MutantSwappedCounter + test_sensitivity_proof_ac1_*。
##   - AC3 即時更新:有常駐變種 _MutantNeverUpdates + test_sensitivity_proof_ac3_*。
##   - AC2 EGM 關閉時不存在:【證明不了(類別 C 近似)】。判斷點在 _ready() 內
##     `if _egm_enabled_for_this_battle`,覆寫點只能是整個 _ready();進樹後換腳本
##     不安全(Case B),進樹前換腳本也無法把「條件」注入成錯的而不重寫整個 _ready()。
##   - AC4 位置:rect 函式是 static 純函式(類別 A,沒有繼承鏈可覆寫);與 Label 實際位置的
##     吻合斷言依賴 _ready() 內的版面套用,同屬進樹後才能觀察(類別 C)。字級來源的
##     原始碼掃描屬乙類,無法對原始碼本身做變種。
##   - AC5/AC6:靜態原始碼/資源斷言(類別 A′),沒有可注入錯誤版本的類別。
##   - 🔴 本檔只做 headless。位置、遮擋、字級、字型是否支援「猜中」字形:【未驗證】,
##     留給有畫面的環境人眼驗收(工作單明載)。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _BATTLE_SCREEN_SRC: String = "res://src/ui/battle/battle_screen.gd"
const _HUD_LAYOUT_SRC: String = "res://src/ui/battle/hud_layout.gd"
const _WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1366, 768), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160),
]

var _host_snap: CursorHostSnapshot = null


## 常駐變種:文字把猜中/總數對調(AC1 要抓的缺陷:顯示值與追蹤器不一致)。
class _MutantSwappedCounter extends BattleScreen:
	func _consistency_counter_text() -> String:
		return Loc.localize(TEXT_CONSISTENCY_COUNTER_FORMAT) % [
			_guess_tracker.get_scored_total(), _guess_tracker.get_scored_correct()
		]


## 常駐變種:計數器永不更新(AC3 要抓的缺陷:鎖定/移動之後仍顯示舊值)。
class _MutantNeverUpdates extends BattleScreen:
	func _update_consistency_counter() -> void:
		pass


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	GameSettings.reset_for_test()


func after_test() -> void:
	GameSettings.reset_for_test()
	_host_snap.restore()
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


# ---- helpers ----------------------------------------------------------------

## set_script() 必須在設任何 override 屬性之前、進樹之前(test-standards 2026-10-16 節)。
func _instance(egm_on: bool, mutant: Script = null) -> BattleScreen:
	GameSettings.set_egm_enabled(egm_on)
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	if mutant != null:
		instance.set_script(mutant)
	add_child(instance)
	return instance


func _event(action: StringName) -> InputEvent:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var k: InputEventKey = (event as InputEventKey).duplicate()
			k.pressed = true
			return k
	return null


func _select_unit_with_candidate(instance: BattleScreen) -> Dictionary:
	for unit: Unit in instance._state.units_of(Unit.Faction.PLAYER):
		if not instance._controller.select_unit(unit.id):
			continue
		for cell: Vector2i in instance._controller.move_targets().cells:
			if cell != instance._state.position_of(unit.id):
				return {"unit": unit, "a": cell, "delta_a": instance._guess_delta_for_cell(unit.id, cell)}
		instance._controller.deselect()
	return {}


func _park(instance: BattleScreen, cell: Vector2i) -> void:
	instance._cursor_cell = cell
	instance._cursor_active = true
	instance._refresh_view()


func _wrong_guess_for(delta: int) -> int:
	var actual: int = EffectGuessTracker.classify_delta(delta)
	return EffectGuessTracker.EffectDirection.NEGATIVE \
		if actual != EffectGuessTracker.EffectDirection.NEGATIVE \
		else EffectGuessTracker.EffectDirection.POSITIVE


## 鎖定猜測(第一次確認),尚未移動。
func _lock(instance: BattleScreen, setup: Dictionary, guess: int) -> void:
	_park(instance, setup["a"])
	instance._guess_choice = guess
	instance._input(_event(&"battle_confirm"))


func _expected_text(correct: int, total: int) -> String:
	return Loc.localize(BattleScreen.TEXT_CONSISTENCY_COUNTER_FORMAT) % [correct, total]


## 擷取 `func <name>(` 到下一個頂層宣告之間的原始碼文字。
func _func_body(src: String, func_name: String) -> String:
	var start: int = src.find("func %s(" % func_name)
	assert_int(start).append_failure_message("找不到函式 %s" % func_name).is_greater_equal(0)
	if start < 0:
		return ""
	var end: int = src.find("\nfunc ", start + 1)
	return src.substr(start, (end if end > start else src.length()) - start)


# ---- AC1 有計數器 ------------------------------------------------------------

func test_ac01_egm_on_counter_exists_and_reads_the_tracker() -> void:
	var instance: BattleScreen = _instance(true)
	var tracker: EffectGuessTracker = instance.diagnostic_guess_tracker()

	assert_object(instance.diagnostic_consistency_label()).append_failure_message(
		"AC1:EGM 開啟時應有計數器 Label").is_not_null()
	assert_str(instance.diagnostic_consistency_label().text).is_equal(
		_expected_text(tracker.get_scored_correct(), tracker.get_scored_total()))
	assert_str(instance.diagnostic_consistency_label().text).contains("0/0")


func test_ac01_counter_text_equals_tracker_values_after_a_mismatch() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_candidate(instance)
	_lock(instance, setup, _wrong_guess_for(setup["delta_a"]))
	instance._input(_event(&"battle_confirm"))   # 移動 = 計分

	var tracker: EffectGuessTracker = instance.diagnostic_guess_tracker()
	assert_int(tracker.get_scored_total()).is_equal(1)
	assert_int(tracker.get_scored_correct()).is_equal(0)
	assert_str(instance.diagnostic_consistency_label().text).append_failure_message(
		"AC1:顯示值須等於追蹤器的 猜中/總數(不得自行重算)").is_equal(_expected_text(0, 1))


func test_sensitivity_proof_ac1_swapped_counter_is_caught() -> void:
	var instance: BattleScreen = _instance(true, _MutantSwappedCounter)
	var setup: Dictionary = _select_unit_with_candidate(instance)
	_lock(instance, setup, _wrong_guess_for(setup["delta_a"]))
	instance._input(_event(&"battle_confirm"))
	instance._update_consistency_counter()

	assert_str(instance.diagnostic_consistency_label().text).append_failure_message(
		"變種把 猜中/總數 對調;偵測用的期望值(0/1)必須與它不同,否則 AC1 的測試是裝飾品"
	).is_not_equal(_expected_text(0, 1))


# ---- AC2 EGM 關閉時不存在 -----------------------------------------------------

func test_ac02_egm_off_counter_does_not_exist() -> void:
	var instance: BattleScreen = _instance(false)

	assert_object(instance.diagnostic_consistency_label()).is_null()
	assert_object(instance.get_node_or_null("UILayer/ConsistencyCounterLabel")).append_failure_message(
		"AC2:EGM 關閉時 UILayer 底下不得有計數器節點").is_null()
	# 既有畫面不變:追蹤器與選擇器皆不存在(與 story-002 AC1 同一道短路)。
	assert_object(instance.diagnostic_guess_tracker()).is_null()
	assert_bool(instance.diagnostic_guess_selector_visible()).is_false()


# ---- AC3 即時更新 ------------------------------------------------------------

func test_ac03_move_after_lock_updates_counter_immediately() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_candidate(instance)
	_lock(instance, setup, EffectGuessTracker.classify_delta(setup["delta_a"]))
	assert_str(instance.diagnostic_consistency_label().text).append_failure_message(
		"鎖定但尚未移動:不計分,計數器不變").is_equal(_expected_text(0, 0))

	instance._input(_event(&"battle_confirm"))   # 移動

	assert_str(instance.diagnostic_consistency_label().text).append_failure_message(
		"AC3:確認移動之後計數器須立即反映新值(符合 → 1/1)").is_equal(_expected_text(1, 1))


func test_ac03_cancel_does_not_change_counter() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_candidate(instance)
	_lock(instance, setup, EffectGuessTracker.classify_delta(setup["delta_a"]))

	instance._controller.deselect()

	assert_str(instance.diagnostic_consistency_label().text).is_equal(_expected_text(0, 0))


func test_ac03_skip_move_does_not_change_counter() -> void:
	var instance: BattleScreen = _instance(true)
	var setup: Dictionary = _select_unit_with_candidate(instance)
	_park(instance, setup["a"])

	instance._input(_event(&"battle_confirm"))   # 未猜測就確認 = 跳過並移動

	assert_str(instance.diagnostic_consistency_label().text).is_equal(_expected_text(0, 0))


func test_sensitivity_proof_ac3_never_updating_counter_is_caught() -> void:
	var instance: BattleScreen = _instance(true, _MutantNeverUpdates)
	var setup: Dictionary = _select_unit_with_candidate(instance)
	_lock(instance, setup, EffectGuessTracker.classify_delta(setup["delta_a"]))
	instance._input(_event(&"battle_confirm"))

	assert_int(instance.diagnostic_guess_tracker().get_scored_total()).append_failure_message(
		"前提:追蹤器確實已計分").is_equal(1)
	assert_str(instance.diagnostic_consistency_label().text).append_failure_message(
		"變種不更新計數器;AC3 的期望值(1/1)必須與它不同"
	).is_not_equal(_expected_text(1, 1))


# ---- AC4 位置與字級 ----------------------------------------------------------

func test_ac04_rect_is_inside_safe_area_below_status_and_not_a_side_column() -> void:
	for window_size: Vector2i in _WINDOW_SIZES:
		var rect: Rect2 = HudLayout.consistency_counter_rect(window_size)
		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var status: Rect2 = HudLayout.status_label_rect(window_size)
		var info: Rect2 = HudLayout.info_label_rect(window_size)
		assert_bool(safe.encloses(rect)).append_failure_message(
			"AC4:%s 計數器超出 title-safe 區" % window_size).is_true()
		assert_bool(rect.intersects(status)).append_failure_message(
			"%s 與 StatusLabel 重疊" % window_size).is_false()
		assert_bool(rect.intersects(info)).append_failure_message(
			"%s 與 InfoLabel 重疊" % window_size).is_false()
		# 疊在棋盤上方、不是側邊固定欄:寬度不超過安全區的 1/3,高度不超過一列 label。
		assert_float(rect.size.x).is_less_equal(safe.size.x / 3.0)
		assert_float(rect.size.y).is_equal(status.size.y)
		# 不與右側格位資訊面板(寬度 40% 靠右)重疊:本框右緣必須在安全區 60% 之左。
		assert_float(rect.end.x).is_less(safe.position.x + safe.size.x * 0.6)


func test_ac04_label_uses_the_rect_function_and_hud_font_size() -> void:
	var instance: BattleScreen = _instance(true)
	var window_size: Vector2i = instance.get_window().size
	var rect: Rect2 = HudLayout.consistency_counter_rect(window_size)
	var label: Label = instance.diagnostic_consistency_label()

	assert_vector(label.position).is_equal(rect.position)
	assert_vector(label.size).is_equal(rect.size)
	assert_int(label.get_theme_font_size(&"font_size")).append_failure_message(
		"AC4:字級須等於 HudLayout.font_size()").is_equal(HudLayout.font_size(window_size))


func test_ac04_counter_layout_code_does_not_recompute_the_scale_formula() -> void:
	var src: String = FileAccess.get_file_as_string(_BATTLE_SCREEN_SRC)
	var body: String = _func_body(src, "_apply_consistency_counter_layout")
	assert_str(body).is_not_empty()
	assert_str(body).contains("HudLayout.font_size(")
	assert_str(body).not_contains("compute_scale")
	assert_str(body).not_contains("GLYPH_PX")
	var layout_src: String = FileAccess.get_file_as_string(_HUD_LAYOUT_SRC)
	var rect_body: String = _func_body(layout_src, "consistency_counter_rect")
	assert_str(rect_body).not_contains("compute_scale")
	assert_str(rect_body).contains("font_size(")


# ---- AC5 在地化 --------------------------------------------------------------

func test_ac05_counter_format_key_resolves_to_localized_text() -> void:
	var text: String = Loc.localize(BattleScreen.TEXT_CONSISTENCY_COUNTER_FORMAT)
	assert_str(text).is_not_empty()
	assert_str(text).append_failure_message(
		"回傳鍵名本身(strings.csv 缺此列或未重新匯入)").is_not_equal(String(BattleScreen.TEXT_CONSISTENCY_COUNTER_FORMAT))
	assert_str(text).contains("%d")


func test_ac05_counter_text_source_has_no_hardcoded_visible_string() -> void:
	var body: String = _func_body(FileAccess.get_file_as_string(_BATTLE_SCREEN_SRC), "_consistency_counter_text")
	assert_str(body).contains("Loc.localize(")
	assert_str(body).not_contains("猜中")


# ---- AC6 不持久化 ------------------------------------------------------------

func test_ac06_counter_source_files_contain_no_save_write_api() -> void:
	for path: String in [_BATTLE_SCREEN_SRC, _HUD_LAYOUT_SRC]:
		var src: String = FileAccess.get_file_as_string(path)
		for banned: String in ["user://", "FileAccess.WRITE", "store_string", "store_var", "ConfigFile", "ResourceSaver"]:
			assert_bool(src.contains(banned)).append_failure_message(
				"AC6:%s 出現寫檔/存檔字樣 %s(計數器不得持久化)" % [path, banned]).is_false()
