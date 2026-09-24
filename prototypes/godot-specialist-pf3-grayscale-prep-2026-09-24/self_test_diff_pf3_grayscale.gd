## 第六十三批缺陷三/交件要求:證明 diff_pf3_grayscale.gd 能真的從頭跑到尾。
##
## 🔴 本檔產生並使用的兩張影像是【合成測試影像,不是遊戲畫面】。
## 檔名刻意不是 legal_state.png / illegal_state.png ——那兩個保留檔名只留給
## 開窗那次的真實證據,本檔全程不得(也確實沒有)寫出那兩個檔名,見下方
## SELF_TEST_LEGAL_PNG / SELF_TEST_ILLEGAL_PNG 常數。
##
## 做法:用 `diff_pf3_grayscale.gd` 第六十三批新增的三個 `@export ..._override`
## 欄位,把它指向這裡臨時產生的合成 JSON + 兩張合成 PNG,而不是去改
## `diff_pf3_grayscale.gd` 本身讀的預設路徑常數。注入順序比照本專案既有的
## `battle_screen.gd` `_path_override` 慣例與 (二) `extract_pf3_states.gd` 已驗證
## 過的安全寫法:`instantiate()` → 設 override 欄位 →
## `get_tree().root.call_deferred("add_child", instance)` → 等 2 個
## process_frame。
##
## 合成影像的設計刻意讓兩條「對角線」落在不同的灰階差異上,兩種結果都要出現:
##   - pair A(x=10 這條垂直線):legal=灰 0.2、illegal=灰 0.6,diff≈0.4 ——
##     CLEAR 區應該全部判定為「ok」(diff ≥ 0.08 門檻)。
##   - pair B(x=30 這條垂直線):legal=illegal=灰 0.5,diff≈0 ——
##     CLEAR 區應該全部判定為「flagged」(diff < 0.08 門檻)。
## 兩者都出現,才算真的走過 diff_pf3_grayscale.gd 的 pass 分支與 fail 分支,
## 不是只證明「腳本沒有當掉」。
extends Node

const DIR: String = "res://prototypes/godot-specialist-pf3-grayscale-prep-2026-09-24/"
const SELF_TEST_GEOMETRY_JSON: String = DIR + "self_test_synthetic_geometry.json"
const SELF_TEST_LEGAL_PNG: String = DIR + "self_test_synthetic_legal.png"
const SELF_TEST_ILLEGAL_PNG: String = DIR + "self_test_synthetic_illegal.png"

const DIFF_SCENE_PATH: String = DIR + "DiffPf3Grayscale.tscn"


func _ready() -> void:
	print("=== SELF-TEST (SYNTHETIC IMAGES, NOT GAMEPLAY FOOTAGE) for diff_pf3_grayscale.gd ===")
	print(
		(
			"This run writes and reads only: %s / %s / %s -- never legal_state.png or " +
			"illegal_state.png (those two filenames are reserved for the real windowed capture)."
		) % [SELF_TEST_GEOMETRY_JSON, SELF_TEST_LEGAL_PNG, SELF_TEST_ILLEGAL_PNG]
	)

	if not _write_synthetic_geometry():
		get_tree().quit(1)
		return
	if not _write_synthetic_image(SELF_TEST_LEGAL_PNG, 0.2, 0.5):
		get_tree().quit(1)
		return
	if not _write_synthetic_image(SELF_TEST_ILLEGAL_PNG, 0.6, 0.5):
		get_tree().quit(1)
		return
	print("Synthetic fixtures written. Expecting diff_pf3_grayscale.gd to report BOTH pass and fail samples below.")

	var packed: PackedScene = load(DIFF_SCENE_PATH)
	if packed == null:
		push_error("Failed to load %s" % DIFF_SCENE_PATH)
		get_tree().quit(1)
		return

	var diff_instance: Node = packed.instantiate()
	diff_instance.set("geometry_path_override", SELF_TEST_GEOMETRY_JSON)
	diff_instance.set("legal_png_override", SELF_TEST_LEGAL_PNG)
	diff_instance.set("illegal_png_override", SELF_TEST_ILLEGAL_PNG)

	get_tree().root.call_deferred("add_child", diff_instance)
	await get_tree().process_frame
	await get_tree().process_frame

	# diff_instance._ready() 會在上面兩個 process_frame 之間執行完畢並自行呼叫
	# get_tree().quit(...) ——一旦它跑完,這整個行程就會結束。下面這行多半不會
	#被執行到;寫著是為了「萬一它沒有如預期呼叫 quit()」時不要讓行程懸掛。
	print("=== SELF-TEST HARNESS: diff_instance._ready() should have already quit the tree above. If you see this line, it did NOT call quit() -- that itself is a defect. ===")
	get_tree().quit(1)


func _write_synthetic_geometry() -> bool:
	var data: Dictionary = {
		"note": (
			"SYNTHETIC self-test fixture -- NOT real engine output. Written by " +
			"self_test_diff_pf3_grayscale.gd (batch 63). Two vertical line-pairs at x=10 and " +
			"x=30, both spanning local y 50..68, chosen to exercise both the pass branch and " +
			"the fail branch of diff_pf3_grayscale.gd's CLEAR-zone check."
		),
		"world_container_position": [0.0, 0.0],
		"world_container_size": [960.0, 540.0],
		"world_container_stretch_shrink": 2,
		"world_viewport_size": [480, 270],
		"board_view_global_position": [0.0, 0.0],
		"target_cell": [0, 5],
		"illegal_mark_local_points": [
			[[10.0, 50.0], [10.0, 68.0]],
			[[30.0, 50.0], [30.0, 68.0]],
		],
	}
	var f: FileAccess = FileAccess.open(SELF_TEST_GEOMETRY_JSON, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open %s for writing" % SELF_TEST_GEOMETRY_JSON)
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true


## 建一張 480x270(與真實 world_viewport_size 一致,才通過 diff 腳本的尺寸防呆)
## 的合成灰階影像:整張先填 base_gray,再把 x∈[5,15] 那條帶子(對應 pair A,
## local x=10)填 col_a_gray,x∈[25,35] 那條帶子(對應 pair B,local x=30)填
## col_b_gray。y∈[45,73] 涵蓋兩條線 y=50..68 的取樣範圍,留了邊界緩衝。
func _write_synthetic_image(path: String, col_a_gray: float, col_b_gray: float) -> bool:
	var img: Image = Image.create(480, 270, false, Image.FORMAT_RGB8)
	img.fill(Color(0.5, 0.5, 0.5))
	img.fill_rect(Rect2i(5, 45, 11, 29), Color(col_a_gray, col_a_gray, col_a_gray))
	img.fill_rect(Rect2i(25, 45, 11, 29), Color(col_b_gray, col_b_gray, col_b_gray))
	var err: int = img.save_png(path)
	if err != OK:
		push_error("Failed to save synthetic image %s, error=%d" % [path, err])
		return false
	return true
