## P-F3 灰階複驗 —— 狀態擷取探針(2026-09-24)。
##
## 🔴 執行方式的教訓(2026-09-24 本輪實測,寫下來避免下一個人重摔一次):
## 本檔最初寫成 `extends SceneTree`,用 `godot --headless --path . -s
## extract_pf3_states.gd` 直接執行。**這個寫法讓 battle_screen.gd 編譯期直接
## 報錯 `Identifier not found: CursorStateHost`**,重跑三次(含中間重新
## `--import` 一次)逐字重現,不是偶發。推論(未逐行讀引擎原始碼證實,但與
## 現象吻合):`-s` 自訂 MainLoop 腳本繞過了引擎正常的「先掛 Autoload、
## 再跑主場景」開機順序,CursorStateHost 在我的 `_init()` 執行的當下根本
## 還沒被註冊成全域識別字。**改成本檔現在這樣**——`extends Node`、放進一個
## 最小 `.tscn`(見同目錄 `ExtractPf3States.tscn`)、用
## `godot --headless --path . prototypes/.../ExtractPf3States.tscn` 當成
## 正常場景執行——問題消失,與本專案既有的
## `prototypes/godot-specialist-scene-load-feasibility-2026-09-23/probe_load_real_scene.gd`
## + `ProbeLoadRealScene.tscn` 採用的是同一種跑法。**下一個要對
## BattleScreen.tscn(或任何依賴 CursorStateHost 的場景)寫 headless 探針的人,
## 用這個跑法,不要用 `-s`。**
##
## 🔴 路線裁決(依協調者要求,必須寫明選了哪條、證明什麼、不證明什麼):
##
## 本腳本走【路 B —— 直接呼叫 render_pieces() / set_card_target_highlights()】,
## 不是【路 A —— 走完整卡牌流程】。
##
## 選路 B 的理由:路 A 需要先解決兩個本輪讀碼沒有走通的缺口——
##   (a) 讓 CursorStateHost 把游標定位到單位 5 的格子,好讓 show_hp_text 為真;
##   (b) 找到 open_hand()/select_card() 在 battle_screen.gd 真正的呼叫入口,
##       並處理丙類卡未必在手牌裡的重試迴圈。
## 在協調者明令「不准再讀檔案先確認」的前提下,這兩項無法在本輪解決,
## 選路 B 讓腳本能在本輪真的寫出來、真的跑起來。
##
## 🔴 這張證據因此【證明什麼】:
##   - board_view.gd 的 render_pieces() / set_card_target_highlights() /
##     _build_hp_text() / _build_card_target_illegal_mark() 這幾個真實
##     production 函式,在「card_target_illegal 旗標為 true」與「為 false」
##     兩種輸入下,真的畫出兩種不同的東西(HP 襯底顏色不同、有無 X 記號)——
##     這正是 P-F3 要驗的「渲染」問題本身。
##   - 兩態使用的棋盤、地形、名冊、單位位置全部來自真實 vs01 資料檔
##     (透過真實 BattleScreen.tscn 的 _ready() 正常載入,沒有覆寫任何
##     *_path_override),不是合成資料。
##
## 🔴 這張證據【不證明什麼】:
##   - 不證明「遊戲會在正確的時機把 card_target_illegal 設成 true」——那是
##     card_play_session.gd + battle_screen.gd 的職責,本腳本繞過了它們,
##     兩個旗標是腳本自己指定的,不是遊戲邏輯算出來的。要證明「觸發時機正確」
##     需要路 A(見上面兩個缺口),本輪未做。
##   - 本腳本沒有繞過真實渲染管線(SubViewportContainer/SubViewport/BoardView
##     全部是真的),只有「誰決定旗標值」這一件事被腳本接管,而且這件事已經
##     在上面明文揭露,不是不小心漏講。
##
## 硬性要求(2026-09-23 管理者裁決第 5 點):必須 load() 真正的
## res://src/ui/battle/BattleScreen.tscn,instantiate() 後
## call_deferred("add_child", ...) 並等待至少 2 個 process_frame,
## 不得自組替身節點鏈。物證:WorldViewportContainer 的
## position/size/stretch_shrink 與 WorldViewport.size 必須印出。
##
## 🔴 本輪裁決:只准 headless 執行,不准開窗。像素擷取那段寫出來但預期
## get_image() 為 null(已知的 headless 限制,見
## prototypes/godot-specialist-scene-load-feasibility-2026-09-23/run_output_headless.txt),
## 印出來即可,不強求非 null。
##
## 🔴 第六十三批缺陷一修正(2026-09-24):畫完(_render_state)與拍照
## (_attempt_capture)之間原本完全沒有等待,直接同一個 call stack 內連續執行。
## 依本專案唯一成功從視窗拍到真實像素的前例
## (prototypes/godot-specialist-hidden-window-feasibility-2026-09-24/probe_main.gd:40-42,91)
## 補上「兩個 process_frame + 一個 RenderingServer.frame_post_draw」。
## ⚠️ 但那支前例只在 windowed 執行過,本輪不准開窗，「frame_post_draw 在
## --headless 的 dummy rendering driver 下是否保證觸發」沒有查證過——若答案是
## 「不保證」，無條件 await 這個訊號會讓本檔重新變回本檔頭上一段記載過的那種
## 「quit() 永遠不會被呼叫、行程卡住」問題,只是換一個位置發作。因此改成
## _await_render_settle() 這個【有上限】的等待:先固定等 2 個 process_frame，
## 再連上 frame_post_draw 訊號、但最多再等 10 個 frame 就放棄繼續往下走，不會
## 無限期卡住。這是本輪的工程判斷，不是對前例的否定——若前例在 windowed 下
## 訊號準時觸發，這裡的行為與前例完全等價（提早跳出迴圈）；若訊號沒觸發，本檔
## 至少保證會印出一行提示並繼續往下執行、正常呼叫 quit()，不會懸掛。
## 本檔已在 headless 下重跑驗證：加了這段等待之後仍然 EXIT=0（見更新後的
## run_output_headless.txt）——這證明「不會懸掛」，不證明「windowed 下真的等到了
## 有效畫面」，那一項本輪無法驗證，留給開窗那次確認。
extends Node

const SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const TARGET_UNIT_ID: int = 5  # 戊 —— vs01_affinity_links.txt 裡唯一沒有任何配對的單位

var _frame_rendered: bool = false  # 供 _await_render_settle() 的有上限等待使用


func _ready() -> void:
	print("=== P-F3 grayscale prep: extract_pf3_states.gd ===")
	print("Q: CursorStateHost autoload present at /root? ", get_tree().root.has_node("CursorStateHost"))

	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("Failed to load %s" % SCENE_PATH)
		get_tree().quit(1)
		return

	var instance: BattleScreen = packed.instantiate()
	get_tree().root.call_deferred("add_child", instance)
	await get_tree().process_frame
	await get_tree().process_frame
	print("instance.is_inside_tree() = ", instance.is_inside_tree())

	# ── 物證:真實宿主鏈自己算出來的值,不是腳本自己決定的 ──────────────
	var world_container: SubViewportContainer = instance.get_node("WorldViewportContainer")
	var world_viewport: SubViewport = instance.get_node("WorldViewportContainer/WorldViewport")
	var board_view: BoardView = instance.get_node("WorldViewportContainer/WorldViewport/BoardView")

	print(
		"SANITY: WorldViewportContainer.position=%s size=%s stretch_shrink=%s"
		% [world_container.position, world_container.size, world_container.stretch_shrink]
	)
	print("SANITY: WorldViewport.size = %s" % [world_viewport.size])
	print("SANITY: BoardView.global_position = %s" % [board_view.global_position])
	print("SANITY: BoardView.global_transform = %s" % [board_view.global_transform])

	# ── 真實資料:從已經跑過 _ready() 的真實 _state 讀出真實單位,不是自己編的 ──
	var state: BattleState = instance._state
	if state == null:
		push_error("instance._state is null -- BattleScreen._ready() 可能還沒跑完,或欄位名稱不對")
		get_tree().quit(1)
		return

	var target_cell: Vector2i = state.position_of(TARGET_UNIT_ID)
	print("REAL DATA: unit %d (戊) real cell from vs01_roster.txt = %s" % [TARGET_UNIT_ID, target_cell])

	# ── 兩態 ──────────────────────────────────────────────────────────
	print("--- STATE A: legal (card_target_illegal = false) ---")
	_render_state(board_view, state, target_cell, false)
	var legal_lines: Array[PackedVector2Array] = _log_highlight_children(board_view)
	await _attempt_capture(world_viewport, "legal")

	print("--- STATE B: illegal (card_target_illegal = true) ---")
	_render_state(board_view, state, target_cell, true)
	var illegal_lines: Array[PackedVector2Array] = _log_highlight_children(board_view)
	await _attempt_capture(world_viewport, "illegal")

	# 把真實引擎算出來的對角線端點連同宿主鏈物證一併存成 JSON——(三) 的
	# 灰階比對腳本要讀這份檔案取樣座標,不得自己重算幾何。
	_write_geometry_json(world_container, world_viewport, board_view, target_cell, illegal_lines)

	print("=== done ===")
	get_tree().quit(0)


func _write_geometry_json(
	world_container: SubViewportContainer,
	world_viewport: SubViewport,
	board_view: BoardView,
	target_cell: Vector2i,
	illegal_lines: Array[PackedVector2Array]
) -> void:
	var lines_json: Array = []
	for pts: PackedVector2Array in illegal_lines:
		var pair: Array = []
		for p: Vector2 in pts:
			pair.append([p.x, p.y])
		lines_json.append(pair)

	var data: Dictionary = {
		"note": (
			"illegal_mark_local_points 是 _build_card_target_illegal_mark() 真實建出的 " +
			"Line2D.points,座標系與 board_view.global_transform 一致(這裡是恆等變換，" +
			"見同一次 log 的 BoardView.global_transform)。要換算成擷取到的 PNG 像素座標，" +
			"乘上 world_container.size / world_viewport.size 這個真實比例（這裡是整數 " +
			"stretch_shrink 的倒數），不要另外假設一個縮放倍率。"
		),
		"world_container_position": [world_container.position.x, world_container.position.y],
		"world_container_size": [world_container.size.x, world_container.size.y],
		"world_container_stretch_shrink": world_container.stretch_shrink,
		"world_viewport_size": [world_viewport.size.x, world_viewport.size.y],
		"board_view_global_position": [board_view.global_position.x, board_view.global_position.y],
		"target_cell": [target_cell.x, target_cell.y],
		"illegal_mark_local_points": lines_json,
	}

	var out_path: String = "res://prototypes/godot-specialist-pf3-grayscale-prep-2026-09-24/real_geometry.json"
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open %s for writing" % out_path)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("WROTE: %s" % out_path)


## 建出 render_pieces() 要的 Array[Dictionary],完全比照
## battle_screen.gd 產生 pieces 的邏輯(faction 分兩個迴圈、sprite_index 用
## clampi(unit.id - 1, 0, 4))——唯一手動接管的是單位 5 的 show_hp_text /
## card_target_illegal 這兩個旗標,其餘單位維持預設(false / false),因為
## 本次比對只需要單位 5 這一格。
func _render_state(
	board_view: BoardView, state: BattleState, target_cell: Vector2i, target_illegal: bool
) -> void:
	var pieces: Array[Dictionary] = []

	for unit: Unit in state.units_of(Unit.Faction.PLAYER):
		var is_target: bool = unit.id == TARGET_UNIT_ID
		pieces.append({
			"cell": state.position_of(unit.id),
			"faction": "PLAYER",
			"sprite_index": clampi(unit.id - 1, 0, 4),
			"hp": unit.hp,
			"hp_max": unit.hp_max,
			"hp_preview": -1,
			"show_hp_text": is_target,
			"card_target_illegal": is_target and target_illegal,
		})
	for unit: Unit in state.units_of(Unit.Faction.ENEMY):
		pieces.append({
			"cell": state.position_of(unit.id),
			"faction": "ENEMY",
			"sprite_index": 0,
			"hp": unit.hp,
			"hp_max": unit.hp_max,
			"hp_preview": -1,
			"show_hp_text": false,
			"card_target_illegal": false,
		})

	board_view.render_pieces(pieces)

	if target_illegal:
		board_view.set_card_target_highlights([], [target_cell])
	else:
		board_view.set_card_target_highlights([target_cell], [])


## 走真實的 _build_card_target_illegal_mark() 畫出來的節點,把它實際產生的
## Line2D.points 讀出來印成 log——這是「呼叫它、讀它算出來的值」,不是
## 腳本自己重算叉的兩條對角線端點。legal 狀態下 illegal_cells 是空的,
## 預期印不出任何 Line2D,這也照實印出來,不是省略。
##
## 🔴 存取 board_view._card_target_highlight_layer 是直接讀底線開頭的內部欄位
## ——production 程式碼不該這樣做,但這是拋棄式探針(prototypes/ 標準明文放寬,
## 見 .claude/rules/prototype-code.md),目的是不重寫一份幾何公式,兩害相權。
func _log_highlight_children(board_view: BoardView) -> Array[PackedVector2Array]:
	var layer: Node2D = board_view._card_target_highlight_layer
	var line_count: int = 0
	var collected: Array[PackedVector2Array] = []
	for child: Node in layer.get_children():
		for sub: Node in child.get_children():
			if sub is Line2D:
				line_count += 1
				var pts: PackedVector2Array = (sub as Line2D).points
				collected.append(pts)
				print("  MARK_LINE points (real, engine-computed) = %s" % [pts])
	print("  (highlight layer child count = %d, Line2D count = %d)" % [layer.get_child_count(), line_count])
	return collected


## 缺陷一修正:在「畫完」與「拍照」之間插入有上限的等待,讓 GPU/合成器有機會
## 真的把上一步 render_pieces()/set_card_target_highlights() 畫出來的內容送進
## world_viewport 的原生緩衝區。有上限（最多再等 10 個 frame）是刻意的——見檔頭
## 說明,目的是即使 frame_post_draw 在 headless 下從不觸發，本函式也保證會繼續
## 往下走，不會讓呼叫端永遠掛在這個 await 上。
func _await_render_settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_frame_rendered = false
	if not RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
		RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
	var waited_frames: int = 0
	while not _frame_rendered and waited_frames < 10:
		await get_tree().process_frame
		waited_frames += 1
	if not _frame_rendered:
		print(
			(
				"  (frame_post_draw did not fire within 10 extra frames after the base 2 -- " +
				"proceeding anyway. Expected under --headless per this round's ruling; if this " +
				"prints during a WINDOWED run, that is new information and should be reported.)"
			)
		)


func _on_frame_post_draw() -> void:
	_frame_rendered = true


## 嘗試讀取 WorldViewport 的原生緩衝區像素——依 2026-09-23 已驗證的限制,
## headless 下這裡預期 get_image() 為 null。不強行處理成 error,只誠實印出來。
func _attempt_capture(world_viewport: SubViewport, label: String) -> void:
	await _await_render_settle()

	var texture: ViewportTexture = world_viewport.get_texture()
	if texture == null:
		print("  CAPTURE[%s]: get_texture() itself returned null" % label)
		return
	var img: Image = texture.get_image()
	if img == null:
		print(
			(
				"  CAPTURE[%s]: get_image() is null (expected under --headless, per 2026-09-23 " +
				"finding -- not executed further, per this round's 'no window' ruling)"
			) % label
		)
		return
	# 只有開窗執行才會走到這裡。此分支這輪不會被觸發,寫出來供開窗後直接沿用。
	var out_path: String = (
		"res://prototypes/godot-specialist-pf3-grayscale-prep-2026-09-24/%s_state.png" % label
	)
	img.save_png(out_path)
	print("  CAPTURE[%s]: saved %s size=%s" % [label, out_path, img.get_size()])
