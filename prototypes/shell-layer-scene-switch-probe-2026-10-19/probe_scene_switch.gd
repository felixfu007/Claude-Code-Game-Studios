extends SceneTree
## 2026-10-19 殼層場景切換探針(shell-layer-scene-switch-probe-2026-10-19)。
##
## 任務來源:docs/reviews/settings-screen-has-nowhere-to-live-2026-10-16.md 第四節
## 末段明文留下一句「協調者未查證」——CursorStateHost(ADR-0005 的游標/高亮狀態
## Autoload)跨場景切換時的行為,本專案從未實機量測過。本探針把它從「從未量測」
## 變成「已量測」,回答四題(見本檔下方各 PHASE 對應的題號)。
##
## 🔴 遵守 .claude/docs/technical-preferences.md 第 5 點量測紀律:
## 本探針 load() production 真正啟動的那份場景檔
## (res://src/ui/battle/BattleScreen.tscn,project.godot 的 run/main_scene),
## 不自組「型別與腳本都對」的替身節點鏈。本次是結構/狀態量測,headless 可跑
## (不涉及像素)。
##
## 兩個必踩的坑(同節原文):
## 1. 不得在某節點的 _ready() 內直接 add_child() —— 本腳本改用
##    root.call_deferred("add_child", instance) 並等待 2 個 process_frame。
## 2. 資料注入只有一個時機窗:instantiate() 之後、add_child() 之前 —— 本探針
##    不需要覆寫任何資料路徑(用的是正式 BattleScreen 預設的生產資料),故此坑
##    與本次量測無關,僅在此記錄已知悉。
##
## 腳本結尾務必呼叫 quit() —— 本專案登記過「漏 quit() 的 headless 引擎會永遠
## 空轉」,會害下一個人去查殭屍行程。

const BATTLE_SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const BLANK_SCENE_PATH: String = "res://prototypes/shell-layer-scene-switch-probe-2026-10-19/ProbeBlankScene.tscn"

var _battle_instance_1: Node
var _battle_instance_2: Node
var _host_before: Node
var _host_instance_id_before: int = -1


## 🔴 工具層級發現(與本探針要回答的四題本身無關,是寫探針過程中撞到的):
## 把本腳本寫成以 `-s` 指定的 SceneTree 主迴圈腳本時,引擎在這份腳本【編譯期】
## 就會嘗試解析所有裸識別字 —— 包含寫在函式內部、尚未執行到的那些。而
## Autoload 的全域識別字(CursorStateHost)要等到 SceneTree 真正初始化、
## autoload 清單被處理過後才存在。本腳本本身就是那個 SceneTree 的來源,
## 於是出現「編譯這份腳本的時候,它自己要用的 Autoload 全域識別字還不存在」
## 的雞生蛋問題 —— 實測錯誤:
##   SCRIPT ERROR: Compile Error: Identifier not found: CursorStateHost
## 這與 production 無關:BattleScreen.gd 是一般場景腳本(不是 MainLoop),
## 全專案既有測試早已證明它能正常解析 CursorStateHost。修法:不要在原始碼裡
## 寫死 `CursorStateHost` 這個裸識別字,改用 root.get_node() 動態取得節點,
## 搭配 callv() 讓方法呼叫在執行期才動態解析(不經過靜態符號表)。
func _host_call(method_name: String, args: Array = []) -> Variant:
	var host: Node = root.get_node("CursorStateHost")
	return host.callv(method_name, args)


func _initialize() -> void:
	# _initialize() 本身就是整個 MainLoop 的進入點 —— 這裡還不能立刻 add_child,
	# 依本專案紀律照樣走 call_deferred,讓第一幀先穩定下來再開始量測主體。
	call_deferred("_run_probe")


func _run_probe() -> void:
	print("=== PROBE START === frame=%d" % Engine.get_process_frames())

	# ── 第 1 題準備:切換前先記錄 CursorStateHost 這個 Autoload 的身分 ──────────
	_host_before = root.get_node_or_null("CursorStateHost")
	print("Q1-SETUP: CursorStateHost found at /root before any scene load? %s" % [_host_before != null])
	if _host_before != null:
		_host_instance_id_before = _host_before.get_instance_id()
		print("Q1-SETUP: CursorStateHost.get_instance_id() before = %d" % _host_instance_id_before)

	# ── 掛載真實的 BattleScreen.tscn(production 實際啟動的那份)──────────────
	var packed: PackedScene = load(BATTLE_SCENE_PATH)
	if packed == null:
		push_error("PROBE: failed to load() %s -- aborting" % BATTLE_SCENE_PATH)
		quit(1)
		return
	_battle_instance_1 = packed.instantiate()
	_battle_instance_1.tree_exiting.connect(
		func() -> void:
			print("PROBE: battle_instance_1.tree_exiting fired at frame=%d" % Engine.get_process_frames())
	)
	_battle_instance_1.tree_exited.connect(
		func() -> void:
			print("PROBE: battle_instance_1.tree_exited fired at frame=%d" % Engine.get_process_frames())
	)
	root.call_deferred("add_child", _battle_instance_1)
	await process_frame
	await process_frame
	current_scene = _battle_instance_1
	print(
		"SETUP: BattleScreen #1 mounted. is_inside_tree=%s instance_id=%d frame=%d" % [
			_battle_instance_1.is_inside_tree(), _battle_instance_1.get_instance_id(), Engine.get_process_frames()
		]
	)

	# ── 第 2 題(非破壞性探測):BattleScreen._ready() 的 Story 008 既有程式碼
	# 已經會在 _ready() 呼叫 CursorStateHost.register_surface(BOARD_TILE, self),
	# 並在 tree_exited 連一個安全網呼叫 unregister_surface(BOARD_TILE)。
	# 用「拿一個全新節點嘗試註冊同一個 tag」來探測目前誰佔著這個 tag,
	# 而不直接呼叫 unregister_surface 破壞現狀 —— DUPLICATE_TAG_REJECTED 時
	# register() 保證不寫入,是安全的唯讀探測。
	var probe_dummy_1: Node = Node.new()
	var probe_result_1: int = _host_call("register_surface", [CursorTypes.SurfaceType.BOARD_TILE, probe_dummy_1])
	print(
		"Q2-BEFORE-SWITCH: register_surface(dummy) while BattleScreen#1 alive -> %s (DUPLICATE_TAG_REJECTED=%d REGISTERED=%d) -- 預期 DUPLICATE,代表 #1 自己佔著 BOARD_TILE" % [
			CursorSurfaceRegistry.RegisterResult.find_key(probe_result_1),
			CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED,
			CursorSurfaceRegistry.RegisterResult.REGISTERED,
		]
	)
	probe_dummy_1.free()

	# ── 第 3 題:change_scene_to_file() 的實際時機語意 ──────────────────────
	print("Q3: about to call change_scene_to_file() at frame=%d" % Engine.get_process_frames())
	print("Q3-BEFORE-CALL: battle_instance_1.is_inside_tree()=%s is_instance_valid=%s" % [
		_battle_instance_1.is_inside_tree(), is_instance_valid(_battle_instance_1)
	])
	var switch_err: int = change_scene_to_file(BLANK_SCENE_PATH)
	print("Q3-RETURN-VALUE: change_scene_to_file() returned Error=%d (OK=%d) immediately upon return" % [switch_err, OK])
	print("Q3-IMMEDIATELY-AFTER: battle_instance_1.is_inside_tree()=%s is_instance_valid=%s frame=%d" % [
		(_battle_instance_1.is_inside_tree() if is_instance_valid(_battle_instance_1) else "N/A(freed)"),
		is_instance_valid(_battle_instance_1),
		Engine.get_process_frames(),
	])
	print("Q3-CALLER-CONTINUES: this line executes immediately after the call returned -- proves the calling function is NOT suspended by change_scene_to_file() itself")

	await process_frame
	print("Q3-AFTER-1-FRAME: battle_instance_1 is_instance_valid=%s frame=%d current_scene=%s" % [
		is_instance_valid(_battle_instance_1), Engine.get_process_frames(),
		(current_scene.name if current_scene != null else "null"),
	])
	await process_frame
	print("Q3-AFTER-2-FRAMES: battle_instance_1 is_instance_valid=%s frame=%d current_scene=%s" % [
		is_instance_valid(_battle_instance_1), Engine.get_process_frames(),
		(current_scene.name if current_scene != null else "null"),
	])

	# ── 第 1 題覆核:切到空白場景之後,CursorStateHost 是否還在、是不是同一個實例 ──
	var host_after_blank: Node = root.get_node_or_null("CursorStateHost")
	print("Q1-AFTER-BLANK: CursorStateHost found? %s" % [host_after_blank != null])
	if host_after_blank != null:
		print("Q1-AFTER-BLANK: instance_id=%d same_as_before=%s" % [
			host_after_blank.get_instance_id(),
			(host_after_blank.get_instance_id() == _host_instance_id_before),
		])

	# ── 第 2 題覆核:BattleScreen#1 的 tree_exited 安全網是否真的清掉了 BOARD_TILE ──
	var probe_dummy_2: Node = Node.new()
	var probe_result_2: int = _host_call("register_surface", [CursorTypes.SurfaceType.BOARD_TILE, probe_dummy_2])
	print(
		"Q2-AFTER-SWITCH: register_surface(dummy) after switching to blank scene -> %s -- 預期 REGISTERED,代表 #1 的 tree_exited 安全網成功解除了 BOARD_TILE" % [
			CursorSurfaceRegistry.RegisterResult.find_key(probe_result_2)
		]
	)
	# 不論成功與否都立刻清掉這個探測用的暫時註冊,避免污染後續第 4 題的量測。
	var cleanup_result_2: int = _host_call("unregister_surface", [CursorTypes.SurfaceType.BOARD_TILE])
	print("Q2-CLEANUP: unregister_surface(dummy) -> %s" % [CursorSurfaceRegistry.RegisterResult.find_key(cleanup_result_2)])
	probe_dummy_2.free()

	# ── 第 4 題:走一趟來回,BattleScreen -> 空白場景 -> BattleScreen ────────
	print("Q4: switching back to BattleScreen at frame=%d" % Engine.get_process_frames())
	var switch_back_err: int = change_scene_to_file(BATTLE_SCENE_PATH)
	print("Q4-RETURN-VALUE: change_scene_to_file(BattleScreen) returned Error=%d" % switch_back_err)
	await process_frame
	await process_frame
	_battle_instance_2 = current_scene
	print("Q4-RESULT: current_scene after round trip = %s" % [
		(_battle_instance_2.name if _battle_instance_2 != null else "null")
	])
	if _battle_instance_2 != null:
		print("Q4-RESULT: battle_instance_2 is_inside_tree=%s instance_id=%d" % [
			_battle_instance_2.is_inside_tree(), _battle_instance_2.get_instance_id()
		])
		print("Q4-RESULT: battle_instance_2.get_instance_id() == battle_instance_1's (%s) ? %s -- 預期不同,代表是全新實例,不是同一個被重新加回樹的物件" % [
			str(_battle_instance_1.get_instance_id()) if is_instance_valid(_battle_instance_1) else "freed",
			(_battle_instance_2.get_instance_id() == _battle_instance_1.get_instance_id()) if is_instance_valid(_battle_instance_1) else "N/A(instance_1 already freed, so definitely different)",
		])

	# 第 4 題延伸:round-trip 後 BattleScreen#2 是否乾淨地重新註冊了 BOARD_TILE
	var probe_dummy_3: Node = Node.new()
	var probe_result_3: int = _host_call("register_surface", [CursorTypes.SurfaceType.BOARD_TILE, probe_dummy_3])
	print(
		"Q4-BOARD-TILE: register_surface(dummy) after round-trip -> %s -- 預期 DUPLICATE_TAG_REJECTED,代表 BattleScreen#2 的 _ready() 乾淨地重新佔住了 BOARD_TILE" % [
			CursorSurfaceRegistry.RegisterResult.find_key(probe_result_3)
		]
	)
	probe_dummy_3.free()

	# 第 1 題最終覆核:整趟來回,CursorStateHost 全程是不是同一個實例
	var host_final: Node = root.get_node_or_null("CursorStateHost")
	if host_final != null:
		print("Q1-FINAL: instance_id=%d same_as_original=%s" % [
			host_final.get_instance_id(),
			(host_final.get_instance_id() == _host_instance_id_before),
		])

	# 診斷用:CursorStateHost 的 process_mode / diagnostic_process_tick_count 在
	# 整趟場景切換過程中有沒有繼續運作(連帶確認 Autoload 沒有被重建導致計數歸零)。
	if host_final != null and host_final.has_method("get"):
		print("Q1-EXTRA: CursorStateHost.diagnostic_process_tick_count (若此欄位存在且 > 0,代表 _process 全程持續運作,未曾重建) = %s" % [
			str(host_final.get("diagnostic_process_tick_count"))
		])

	print("=== PROBE END === frame=%d" % Engine.get_process_frames())
	quit()
