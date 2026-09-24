## P-F3 灰階複驗 —— 灰階比對腳本(2026-09-24)。
##
## 🔴 本檔【未執行,也無法在本輪執行】——它依賴 (二)
## `extract_pf3_states.gd` 產出的 `legal_state.png` / `illegal_state.png`,
## 而那兩個檔案只有在開窗執行時才會真的存檔(headless 下
## `WorldViewport.get_texture().get_image()` 恆為 null,已在
## `run_output_headless.txt` 逐字重現;引用來源:
## prototypes/godot-specialist-scene-load-feasibility-2026-09-23/run_output_headless.txt
## 的既有結論,本輪只是再次確認,沒有推翻)。**下面的邏輯是設計,不是已驗證
## 可運作的程式碼** —— 第一次拿到真的兩張 PNG 之後,必須真的跑一次才能信任它。
##
## ── 取樣座標的來源:讀 real_geometry.json,不重算幾何 ───────────────────
## `real_geometry.json`(同目錄,由 (二) headless 執行時寫出)裡的
## `illegal_mark_local_points` 是 `board_view.gd` 的
## `_build_card_target_illegal_mark()` 真實建出的兩條 `Line2D.points`——
## 已實測(見 `run_output_headless.txt`):
##   對角線 a: (39.0, 206.0) -> (57.0, 224.0)
##   對角線 b: (57.0, 206.0) -> (39.0, 224.0)
## 這兩條線的 local_y 範圍剛好就是 [206, 224],對應設計文件
## (`design/art/hp-readout-contrast-fix.md` 第四節)講的「叉的完整範圍
## y ∈ [7, 25)(格內相對座標)」—— 也就是 local_y=206 對應格內相對 y=7,
## local_y=224 對應格內相對 y=25,兩者只差一個固定位移(206-7=199),不需要
## 另外去讀 BoardCoords/CARD_TARGET_ILLEGAL_MARK_INSET 的公式本身。
## 本腳本只在這兩條【真實引擎給的線段】上做線性內插取樣,不重新推導
## grid_to_local() 或 inset 常數。
##
## ── 座標系轉換 ──────────────────────────────────────────────────────
## `illegal_mark_local_points` 的座標系是 BoardView 的區域座標,而
## `real_geometry.json` 同時記了 `board_view_global_position`(這次量到是
## (0,0),但下面的程式碼仍然把它當一般情況處理、不假設恆為零)與
## `world_container_size` / `world_viewport_size`(960x540 / 480x270,商為 2,
## 即整數 nearest 放大倍率)。PNG 像素座標 = (board_view_global_position +
## local_point) * (world_container_size / world_viewport_size)。這個放大倍率
## 是【讀出來的】(來自兩個真實尺寸相除),不是猜的或抄公式抄來的。
##
## 若日後解析度改變、或 BoardView 在畫面上的錨點方式改變,這裡的乘法仍然成立
## ——因為它只依賴 real_geometry.json 這次真實紀錄的兩個尺寸,不是寫死的倍率。
## 但如果换了解析度重新擷取,必須重新跑 (二) 產生新的 real_geometry.json,
## 不能沿用舊的 JSON 配新的 PNG。
extends Node

const DIR: String = "res://prototypes/godot-specialist-pf3-grayscale-prep-2026-09-24/"
const GEOMETRY_PATH: String = DIR + "real_geometry.json"
const LEGAL_PNG: String = DIR + "legal_state.png"
const ILLEGAL_PNG: String = DIR + "illegal_state.png"

## 設計文件規定的取樣密度與分區——見
## design/art/hp-readout-contrast-fix.md 第四節步驟 3。
const SAMPLE_COUNT: int = 6
const OVERLAP_ZONE_CELL_Y_MAX: float = 11.0  # 格內相對 y < 11 屬於「預期內差異小」


func _ready() -> void:
	print("=== P-F3 grayscale diff (DESIGN ONLY -- see file header, not executed this round) ===")

	if not FileAccess.file_exists(GEOMETRY_PATH):
		push_error("Missing %s -- run (二) extract_pf3_states.gd first" % GEOMETRY_PATH)
		get_tree().quit(1)
		return
	if not FileAccess.file_exists(LEGAL_PNG) or not FileAccess.file_exists(ILLEGAL_PNG):
		print(
			(
				"ABORT (expected this round): %s and/or %s do not exist yet -- they can only be " +
				"produced by a WINDOWED run of extract_pf3_states.gd (headless get_image() is " +
				"null, per this round's own run_output_headless.txt). This script is written but " +
				"has never actually executed past this point."
			) % [LEGAL_PNG, ILLEGAL_PNG]
		)
		get_tree().quit(0)
		return

	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_PATH))
	var lines: Array = geometry["illegal_mark_local_points"]
	var board_offset: Vector2 = Vector2(
		geometry["board_view_global_position"][0], geometry["board_view_global_position"][1]
	)
	var container_size: Vector2 = Vector2(
		geometry["world_container_size"][0], geometry["world_container_size"][1]
	)
	var viewport_size: Vector2 = Vector2(
		geometry["world_viewport_size"][0], geometry["world_viewport_size"][1]
	)
	var scale_factor: Vector2 = container_size / viewport_size  # 讀出來的倍率,不是寫死的

	var legal_img: Image = Image.load_from_file(LEGAL_PNG)
	var illegal_img: Image = Image.load_from_file(ILLEGAL_PNG)
	legal_img.convert(Image.FORMAT_L8)
	illegal_img.convert(Image.FORMAT_L8)

	var min_local_y: float = INF
	for pair: Array in lines:
		for pt: Array in pair:
			min_local_y = minf(min_local_y, pt[1])
	# min_local_y 對應設計文件的格內相對 y=7(見檔頭推導)。

	var pass_count: int = 0
	var fail_count: int = 0

	for pair: Array in lines:
		var p0: Vector2 = Vector2(pair[0][0], pair[0][1])
		var p1: Vector2 = Vector2(pair[1][0], pair[1][1])
		for i in range(SAMPLE_COUNT):
			var t: float = float(i) / float(SAMPLE_COUNT - 1)
			var local_point: Vector2 = p0.lerp(p1, t)
			var cell_relative_y: float = 7.0 + (local_point.y - min_local_y)
			var pixel_point: Vector2 = (board_offset + local_point) * scale_factor
			var px: int = int(round(pixel_point.x))
			var py: int = int(round(pixel_point.y))

			if px < 0 or py < 0 or px >= legal_img.get_width() or py >= legal_img.get_height():
				push_error("Sample point (%d,%d) out of image bounds -- geometry/scale mismatch?" % [px, py])
				continue

			var legal_gray: float = legal_img.get_pixel(px, py).r
			var illegal_gray: float = illegal_img.get_pixel(px, py).r
			var diff: float = absf(legal_gray - illegal_gray)

			var zone: String = (
				"OVERLAP(可接受幾乎看不見)" if cell_relative_y < OVERLAP_ZONE_CELL_Y_MAX
				else "CLEAR(必須清楚可辨)"
			)
			print(
				(
					"  sample cell_y=%.1f px=(%d,%d) zone=%s legal_gray=%.3f illegal_gray=%.3f " +
					"diff=%.3f"
				) % [cell_relative_y, px, py, zone, legal_gray, illegal_gray, diff]
			)

			# 通過門檻本身是本腳本的設計判斷,不是設計文件給的精確數字——
			# 設計文件只說「清楚可辨」/「幾乎看不見」,沒有給浮點數門檻。
			# 下面 0.08 是暫定值,第一次真的跑出兩張 PNG 之後必須用人眼核對
			# 這個門檻抓不抓得到「清楚可辨」與「幾乎看不見」的真實邊界,
			# 不能盲目相信這個數字。
			if zone.begins_with("CLEAR") and diff < 0.08:
				fail_count += 1
			else:
				pass_count += 1

	print("=== summary: %d ok, %d flagged (see zone/diff above) ===" % [pass_count, fail_count])
	print(
		"🔴 REMINDER: per coding-standards.md Check 5 and this design doc's own step 4, a human " +
		"opening both PNGs and confirming the X still reads as a complete X is MANDATORY and " +
		"NOT replaced by this script's pass/fail count."
	)
	get_tree().quit(0)
