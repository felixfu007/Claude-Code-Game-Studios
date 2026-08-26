# GdUnit4 headless 測試執行入口
#
# 用法(對應 .claude/docs/coding-standards.md 的 CI 指令):
#   godot --headless --script tests/gdunit4_runner.gd
#
# CI 走的是另一條路(.github/workflows/tests.yml 用 MikeSchulze/gdUnit4-action),
# 兩條路都必須存在:Action 用於自動化,本檔用於本機與任何無法使用 Action 的環境。
#
# ✅ 2026-08-26 實機驗證(godot-gdscript-specialist,讀原始碼 + 實跑確認):
#
#   1. 真正的執行入口是 GdUnitTestCIRunner
#      (addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd)。它是一個要被
#      add_child() 進場景樹、靠 _process() 狀態機跑完測試、最後自己呼叫
#      get_tree().quit(exit_code) 的 Node —— 不是「呼叫一次就回傳結果」的
#      run_tests() 方法。舊版本檔對介面的假設(#3 待驗證項)是錯的,本檔已改正。
#
#   2. 這個 runner 平常靠剖析 OS.get_cmdline_args() 取得 -a / --ignoreHeadlessMode。
#      但 CmdArgumentParser.parse()(addons/gdUnit4/src/cmd/CmdArgumentParser.gd:14-36)
#      的機制是:先丟棄命令列中「含有 'GdUnitCmdTool.gd' 字串的那個 token」之前的
#      所有參數,才開始剖析後面的選項。用
#      `godot --headless --script tests/gdunit4_runner.gd` 呼叫時,命令列裡不會出現
#      那個字串 —— 若讓 runner 自己讀 OS.get_cmdline_args(),會被判定「沒有參數」,
#      直接印說明文字、以 exit code 0 結束。**測試完全沒跑就假綠燈,比失敗更危險。**
#
#      因此改用 _debug_cmd_args 這個唯一的注入點(見同檔 get_cmdline_args():
#      非空時優先於 OS.get_cmdline_args())直接灌入固定參數,繞開字串比對。
#      這是底線開頭的私有慣例欄位,不是公開 API —— 下方的介面檢查與寫回驗證
#      (has_method 檢查 + set 後讀回比對)確保 GdUnit4 版本更新若拿掉/改名這個欄位,
#      本檔會 fail-loud,不會靜默失效。
#
#   3. exit code 定義(GdUnitTestSessionRunner.gd):0 成功、100 有錯誤/失敗、
#      101 僅有孤兒節點、103 headless 未加 --ignoreHeadlessMode 旗標。
extends SceneTree

const RUNNER_CANDIDATES: Array[String] = [
    "res://addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd",
    "res://addons/gdunit4/src/core/runners/GdUnitTestCIRunner.gd",
]

# 對應 tests/README.md 記載的驗證指令:
#   <godot> --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
#           --ignoreHeadlessMode -a tests/unit
#
# 第一個元素 "GdUnitCmdTool.gd" 是必要的假 token,不能省略:
# CmdArgumentParser.parse()(addons/gdUnit4/src/cmd/CmdArgumentParser.gd:18-21)
# 不管參數陣列來自 OS.get_cmdline_args() 或 _debug_cmd_args,一律先執行
# 「丟棄含這個字串的 token 之前的所有內容」,找不到就把整個陣列當成雜訊丟光、
# 判定「無參數」。真正的命令列因為 -s 路徑本身含這個字串所以能通過;
# 用 _debug_cmd_args 灌參數時必須自己補上這個標記,否則會靜默退化成
# show_help() + exit code 0 的假綠燈(2026-08-26 實跑撞到過,已用探針腳本
# 確認根因並驗證此修法)。
const FORCED_ARGS: PackedStringArray = [
    "GdUnitCmdTool.gd", "-a", "tests/unit", "--ignoreHeadlessMode"
]

var _cli_runner: Node = null


func _initialize() -> void:
    var runner_script: Script = null
    var tried: PackedStringArray = []
    for path in RUNNER_CANDIDATES:
        tried.append(path)
        if ResourceLoader.exists(path):
            runner_script = load(path)
            if runner_script != null:
                break

    if runner_script == null:
        push_error(
            "找不到 GdUnit4 CI Runner(GdUnitTestCIRunner)。已嘗試:\n  - %s\n"
            % "\n  - ".join(tried)
            + "請確認 GdUnit4 已安裝(res://addons/gdUnit4/ 存在),"
            + "或更新本檔的 RUNNER_CANDIDATES。"
        )
        quit(1)
        return

    # 沿用 addons/gdUnit4/bin/GdUnitCmdTool.gd 的既有慣例:先縮小視窗再啟動。
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)

    var instance: Object = runner_script.new()

    # 介面不符就報錯 + exit code 1(防禦行為延續自舊版本檔)
    if not (instance is Node):
        push_error("GdUnit4 CI Runner 不是 Node,介面與本檔假設不符,請回頭核對。")
        quit(1)
        return
    if not instance.has_method("init_runner") or not instance.has_method("get_exit_code"):
        push_error(
            "GdUnit4 CI Runner 缺少 init_runner() 或 get_exit_code() 方法,"
            + "介面與本檔假設不符,請回頭核對。"
        )
        quit(1)
        return

    instance.set("_debug_cmd_args", FORCED_ARGS)
    var actual_args: Variant = instance.get("_debug_cmd_args")
    if actual_args == null or not (actual_args is PackedStringArray) or actual_args != FORCED_ARGS:
        push_error(
            "無法設定 GdUnit4 CI Runner 的 _debug_cmd_args"
            + "(欄位可能已被移除或改名),介面與本檔假設不符,請回頭核對。"
        )
        quit(1)
        return

    _cli_runner = instance as Node
    root.add_child(_cli_runner)


# do not use print statements on _finalize it results in random crashes
# (沿用 addons/gdUnit4/bin/GdUnitCmdTool.gd 的既有慣例)
func _finalize() -> void:
    if _cli_runner != null:
        queue_delete(_cli_runner)
