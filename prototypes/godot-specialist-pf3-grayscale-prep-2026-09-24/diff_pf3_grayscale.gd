## P-F3 灰階複驗 —— 灰階比對腳本(2026-09-24)。
##
## 🔴 第六十三批狀態更新:本檔【對真的兩張 legal_state.png / illegal_state.png
## 仍然未執行,也無法在本輪執行】——那兩個檔案只有在開窗執行 (二) 時才會真的
## 存檔(headless 下 `WorldViewport.get_texture().get_image()` 恆為 null,已在
## `run_output_headless.txt` 逐字重現)。**但本檔已用合成假影像走過一次完整的
## headless 端到端執行**(見同目錄 `self_test_diff_pf3_grayscale.gd` +
## `run_output_self_test.txt`),證明了語法正確、`_ready()` 從讀 JSON 到印出
## summary 這條路徑真的能跑完、且 pass/fail 兩種結果分支都真的被觸發過。
## **這仍然不等於「對真的兩張 PNG 跑過」**——合成影像只驗證了程式碼路徑本身,
## 不驗證真實遊戲畫面的灰階數值落在哪個範圍、0.08 這個門檻在真實畫面上準不準。
## 第一次拿到真的兩張 PNG 之後,仍然必須真的跑一次才能信任門檻與人眼複驗。
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
## ── 座標系轉換(2026-09-24 第六十三批缺陷二:此段原文是錯的,已改寫)────────
## 🔴 **原文的錯誤,寫下來避免下一個人重犯**:原文說「PNG 像素座標 =
## (board_view_global_position + local_point) * (world_container_size /
## world_viewport_size)」,把 (二) 擷取腳本拍的圖當成合成後的 960x540 整個視窗。
## 但 `extract_pf3_states.gd` 的 `_attempt_capture()` 讀的是
## `world_viewport.get_texture().get_image()`——即 `SubViewport` 的【原生緩衝區】,
## 尺寸是 `world_viewport_size`(480x270),不是 `world_container_size`
## (960x540 合成後的視窗)。乘上 2 倍的結果是:所有取樣點的 y 座標(206~224 x2
## = 412~448)都超出 270 這個圖高,`diff_pf3_grayscale.gd` 因此對每一點都
## `push_error` 並 `continue`,最終印出 `0 ok, 0 flagged`——看起來像是「跑完了、
## 沒有違規」,實際是「一個點都沒真的比對到」。
##
## **修法選的是哪一側**:改比對這一側,不改擷取那一側。擷取腳本繼續讀取
## `SubViewport` 原生緩衝區——這與 `.claude/docs/coding-standards.md`
## 「Check 4 世界層量法變更(2026-09-23 管理者裁決)」要求的方向一致（該裁決是
## 因為 `WorldViewportContainer` 在多數解析度下滿版覆蓋整個視窗，裁合成畫面的
## 容器矩形會把疊在上面的介面層內容一起算進「世界層」）——但 P-F3 本身【不是】
## Check 4：Check 4 管的是整數放大格線完整性,P-F3 管的是兩態之間的灰階對比度,
## 是兩條不同的檢查。這裡引用 Check 4 的裁決只是借用它已經驗證過的同一個
## 底層事實（讀原生緩衝區可以避開介面層污染的合成畫面），不是說 P-F3 受 Check 4
## 判準本身管轄。
##
## `board_view.global_transform` 在本次真實量測中是恆等變換
## （`SANITY: BoardView.global_transform = [X: (1.0, 0.0), Y: (0.0, 1.0), O: (0.0, 0.0)]`,
## 見 `run_output_headless.txt`），所以 `illegal_mark_local_points` 的座標系
## 與 `world_viewport` 原生緩衝區的像素座標系直接一致，只需要加上
## `board_view_global_position`（這次量到是 (0,0),但下面的程式碼仍然把它當
## 一般情況處理、不假設恆為零),不需要再乘任何倍率：
##   PNG 像素座標 = board_view_global_position + local_point
##
## `world_container_size` / `world_viewport_size` 這兩個尺寸依然從 JSON 讀出來
## 印在下面的 NOTE 行裡（供人核對這次真的是整數 nearest 2 倍,不是別的倍率),
## 但刻意【不】乘進 `pixel_point`。若日後 (二) 改成拍合成後的整個視窗,這裡的
## 公式必須跟著改回去——為了讓這種漂移不會再次靜默發生,下面在讀完兩張 PNG 後
## 會先斷言圖片尺寸等於 `world_viewport_size`,尺寸對不上就 `push_error` +
## `quit(1)`,不會像這次一樣悄悄印出「0 ok, 0 flagged」。
##
## 若日後解析度改變、或 BoardView 在畫面上的錨點方式改變,這裡的加法仍然成立
## ——因為它只依賴 real_geometry.json 這次真實紀錄的位移,不是寫死的座標。
## 但如果换了解析度重新擷取,必須重新跑 (二) 產生新的 real_geometry.json,
## 不能沿用舊的 JSON 配新的 PNG。
extends Node

const DIR: String = "res://prototypes/godot-specialist-pf3-grayscale-prep-2026-09-24/"
const GEOMETRY_PATH: String = DIR + "real_geometry.json"
const LEGAL_PNG: String = DIR + "legal_state.png"
const ILLEGAL_PNG: String = DIR + "illegal_state.png"

## 🔴 第六十三批缺陷三新增:供自測 / 未來測試注入替代路徑用,不改變預設行為
## ——正式執行(管理者開窗跑出 legal_state.png / illegal_state.png 之後)完全
## 不需要設定這三個欄位,`_ready()` 會自動退回上面三個常數。硬性要求「自測不得
## 產生 legal_state.png / illegal_state.png 這兩個保留檔名」,需要一個能在不碰
## 常數本身的前提下換路徑的辦法——用法比照本專案既有的 `battle_screen.gd`
## `_path_override` 注入慣例:`instantiate()` → 設這三個欄位 →
## `call_deferred("add_child", ...)` → 等 2 個 process_frame。
@export var geometry_path_override: String = ""
@export var legal_png_override: String = ""
@export var illegal_png_override: String = ""

## 設計文件規定的取樣密度與分區——見
## design/art/hp-readout-contrast-fix.md 第四節步驟 3。
const SAMPLE_COUNT: int = 6
const OVERLAP_ZONE_CELL_Y_MAX: float = 11.0  # 格內相對 y < 11 屬於「預期內差異小」


func _ready() -> void:
	print("=== P-F3 grayscale diff ===")

	var geometry_path: String = geometry_path_override if geometry_path_override != "" else GEOMETRY_PATH
	var legal_png: String = legal_png_override if legal_png_override != "" else LEGAL_PNG
	var illegal_png: String = illegal_png_override if illegal_png_override != "" else ILLEGAL_PNG
	print("  paths: geometry=%s legal=%s illegal=%s" % [geometry_path, legal_png, illegal_png])

	if not FileAccess.file_exists(geometry_path):
		push_error("Missing %s -- run (二) extract_pf3_states.gd first" % geometry_path)
		get_tree().quit(1)
		return
	if not FileAccess.file_exists(legal_png) or not FileAccess.file_exists(illegal_png):
		print(
			(
				"ABORT: %s and/or %s do not exist yet -- they can only be produced by a WINDOWED " +
				"run of extract_pf3_states.gd (headless get_image() is null, per this round's own " +
				"run_output_headless.txt)."
			) % [legal_png, illegal_png]
		)
		get_tree().quit(0)
		return

	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(geometry_path))
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
	print(
		(
			"  NOTE: world_container_size=%s world_viewport_size=%s (ratio=%s) -- this ratio is " +
			"the nearest-integer upscale factor used when compositing the world layer into the " +
			"full window. It is NOT applied below: legal/illegal PNGs are the native SubViewport " +
			"buffer (world_viewport_size), not the composited window. See file header, batch-63 " +
			"defect-2 note."
		) % [container_size, viewport_size, container_size / viewport_size]
	)

	# 缺陷二報告要求「人眼那一步要看什麼」——不能只留兩個 480x270 的小檔案讓人
	# 自己找。算出真實對角線端點的 bounding box,印出建議的放大檢視範圍。
	if lines.is_empty():
		print("  HUMAN REVIEW HINT: illegal_mark_local_points is empty -- nothing to bound, cannot suggest a zoom region.")
	else:
		var bbox_min: Vector2 = Vector2(INF, INF)
		var bbox_max: Vector2 = Vector2(-INF, -INF)
		for pair: Array in lines:
			for pt: Array in pair:
				var p: Vector2 = board_offset + Vector2(pt[0], pt[1])
				bbox_min.x = minf(bbox_min.x, p.x)
				bbox_min.y = minf(bbox_min.y, p.y)
				bbox_max.x = maxf(bbox_max.x, p.x)
				bbox_max.y = maxf(bbox_max.y, p.y)
		var pad: float = 10.0
		print(
			(
				"  HUMAN REVIEW HINT: legal_state.png / illegal_state.png are the native 480x270 " +
				"SubViewport buffer -- too small to judge at 1:1 in a normal image viewer. Open " +
				"both at >=400%% zoom and focus on pixel rect roughly x=[%d,%d] y=[%d,%d] (the " +
				"illegal-mark bounding box plus %dpx padding) -- confirm the X still reads as a " +
				"complete X and the HP-backing colour difference is legible, not just the diff " +
				"numbers printed below."
			) % [
				int(bbox_min.x - pad), int(bbox_max.x + pad),
				int(bbox_min.y - pad), int(bbox_max.y + pad), int(pad)
			]
		)

	var legal_img: Image = Image.load_from_file(legal_png)
	var illegal_img: Image = Image.load_from_file(illegal_png)

	# 🔴 缺陷二的防呆:若擷取那一側日後改成拍合成後的整個視窗(或任何導致 PNG
	# 尺寸不再等於 world_viewport_size 的變動),這裡必須立刻大聲失敗,不能重演
	# 「座標超出邊界被 continue 掉、最後印出看似正常的 0 ok, 0 flagged」。
	var expected_size: Vector2i = Vector2i(int(round(viewport_size.x)), int(round(viewport_size.y)))
	if legal_img.get_size() != expected_size or illegal_img.get_size() != expected_size:
		push_error(
			(
				"legal/illegal PNG size legal=%s illegal=%s does not match world_viewport_size=%s " +
				"from %s -- this script assumes the native SubViewport buffer. If the capture side " +
				"changed to grab the composited window, the pixel_point formula below must change " +
				"too (see batch-63 defect-2 header note); do not just widen this check."
			) % [legal_img.get_size(), illegal_img.get_size(), expected_size, geometry_path]
		)
		get_tree().quit(1)
		return

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
			# 缺陷二修正:不再乘 scale_factor——見檔頭「座標系轉換」段落。
			var pixel_point: Vector2 = board_offset + local_point
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
