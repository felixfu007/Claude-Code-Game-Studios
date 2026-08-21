extends Node
# 探針 J runner —— Step 5.5 GDScript 語言層形狀驗證
# 紀律沿用 prototypes/xcheck-adr0003-2026-08-21/README.md 判讀陷阱:
#   (1) 先編譯全部、再呼叫任何一個;(2) 編譯判定用 reload() 的 Error,不用 load() != null;
#   (3) 一個檔一組測項,預期失敗者隔離;(4) 呼叫前後各一 sentinel。

const DECLS: Array = [
	["res://scripts/j1_save_format.gd", "J1  草案 3b 逐字宣告形狀"],
	["res://scripts/j4a_owner.gd", "J4a 擁有者類別(巢狀 enum)"],
	["res://scripts/j4b_qualified.gd", "J4b 獨立 class_name + 限定巢狀 enum"],
	["res://scripts/j4c_unqualified.gd", "J4c 獨立 class_name + 未限定巢狀 enum(預期失敗)"],
]

const CALLABLES: Array = [
	["res://scripts/j1b_caller.gd", "J1b 跨檔案 Outer.Inner 標註 + 欄位讀取"],
	["res://scripts/j1c_outside_new.gd", "J1c 外部構造內部類別 + enum 預設值"],
	["res://scripts/j1d_enum_int_literal.gd", "J1d enum 欄位 = 越界 int 字面量"],
	["res://scripts/j1e_enum_runtime_float.gd", "J1e enum 欄位 = 執行期 float(無型別 Variant)"],
	["res://scripts/j2_inner_no_extends.gd", "J2  內部類別無 extends"],
	["res://scripts/j3_forward_ref.gd", "J3  內部類別前向參照"],
	["res://scripts/j4d_use_qualified.gd", "J4d 使用限定寫法"],
	["res://scripts/j5_typed_containers.gd", "J5  型別化容器 / is Dictionary"],
	["res://scripts/j6_hashing_state.gd", "J6  HashingContext 狀態機"],
	["res://scripts/j7_hash_restart.gd", "J7  已餵資料後再 start()"],
]

func _compile(path: String) -> int:
	var res: Resource = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return ERR_CANT_ACQUIRE_RESOURCE
	var scr := res as GDScript
	if scr == null:
		return ERR_INVALID_DATA
	return scr.reload()

func _ready() -> void:
	print("=== 探針 J / Step 5.5 GDScript 語言層形狀驗證 ===")
	print("引擎:", Engine.get_version_info())
	print("--- 階段 1:編譯判定(reload() 的 Error 回傳值,0 = OK)---")
	for row in DECLS + CALLABLES:
		var err: int = _compile(row[0])
		print("  [%s] err=%d  %s   (%s)" % ["COMPILED OK" if err == OK else "COMPILE FAIL", err, row[1], row[0]])
	print("--- 階段 2:執行 ---")
	for row in CALLABLES:
		var err: int = _compile(row[0])
		print("  ## %s" % row[1])
		if err != OK:
			print("    !! 編譯失敗(err=%d),跳過呼叫" % err)
			continue
		var scr := load(row[0]) as GDScript
		var inst = scr.new()
		if inst == null:
			print("    !! new() 回傳 null,跳過")
			continue
		print("    >> calling %s ..." % row[0])
		var ret: String = inst.probe()
		print("    << 回傳值=[%s]  (空字串代表函式中途中止)" % ret)
	print("=== 探針 J 結束 ===")
	get_tree().quit()
