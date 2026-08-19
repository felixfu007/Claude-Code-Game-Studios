# GdUnit4 headless 測試執行入口
#
# 用法(對應 .claude/docs/coding-standards.md 的 CI 指令):
#   godot --headless --script tests/gdunit4_runner.gd
#
# CI 走的是另一條路(.github/workflows/tests.yml 用 MikeSchulze/gdUnit4-action),
# 兩條路都必須存在:Action 用於自動化,本檔用於本機與任何無法使用 Action 的環境。
#
# ⚠️ 兩項未查證項(建立於 2026-08-19,專案當時無 Godot 執行環境可實測):
#   1. GdUnit4 CLI 入口的實際路徑。範本原本寫死 res://addons/gdunit4/GdUnitRunner.gd,
#      但 GdUnit4 的實際發行結構(含大小寫)未經確認 —— 本檔改為**逐一嘗試已知候選路徑**,
#      全部落空即 fail-loud,不靜默通過。
#   2. GdUnit4 對 Godot 4.7.1 的支援。4.7 為訓練截止後發布版本。
#   兩項皆須在 Godot 專案(project.godot)建立、GdUnit4 安裝完成後回頭實測。
extends SceneTree

const RUNNER_CANDIDATES: Array[String] = [
    "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
    "res://addons/gdunit4/bin/GdUnitCmdTool.gd",
    "res://addons/gdUnit4/GdUnitRunner.gd",
    "res://addons/gdunit4/GdUnitRunner.gd",
]

func _init() -> void:
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
            "找不到 GdUnit4 執行入口。已嘗試:\n  - %s\n"
            % "\n  - ".join(tried)
            + "請確認 GdUnit4 已安裝(Godot → AssetLib → 搜尋 GdUnit4 → 安裝並啟用外掛),"
            + "或更新本檔的 RUNNER_CANDIDATES。"
        )
        quit(1)
        return

    # ⚠️ 範本原本在此無條件 quit(0) —— 那會讓「測試失敗」的 CI 依然顯示綠燈,
    #    是比沒有 CI 更危險的狀態。本檔改為傳遞實際結果。
    #    run_tests() 的回傳型別未經查證,故同時處理 int 與 bool 兩種可能,
    #    無法判讀時一律視為失敗(fail-loud),不猜成功。
    var instance: Object = runner_script.new()
    if not instance.has_method("run_tests"):
        push_error("GdUnit4 執行入口不具 run_tests() 方法,介面與本檔假設不符,請回頭核對。")
        quit(1)
        return

    var result: Variant = instance.call("run_tests")
    var exit_code := 1
    if result is int:
        exit_code = result
    elif result is bool:
        exit_code = 0 if result else 1
    else:
        push_error("無法判讀 run_tests() 的回傳值(型別 %s),依 fail-loud 原則視為失敗。" % typeof(result))
    quit(exit_code)
