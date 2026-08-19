# 測試骨架自我檢查
#
# 這**不是**假測試。專案的 src/ 目前為空,沒有任何遊戲邏輯可測;
# 而 /gate-check 的 Technical Setup → Pre-Production 閘門要求「至少一個範例測試檔」。
# 本檔驗證的是**測試基礎設施本身是否真的接通**:框架載入、斷言可用、
# runner 能被 headless 執行、CI 能收到結果。
#
# 在沒有 Godot 執行環境的情況下(建立本檔時的專案狀態),
# 這是唯一能證明 CI + runner + 框架三者串起來的方法。
#
# 它同時充當**命名慣例的範本**:
#   檔名  [system]_[feature]_test.gd
#   函式  test_[scenario]_[expected]
#
# 第一個真實系統實作後,本檔仍應保留 —— 它抓的是基礎設施迴歸
# (例如有人升級 GdUnit4 後 runner 路徑改變),與遊戲邏輯正交。
extends GdUnitTestSuite


func test_assertion_api_is_available() -> void:
    # 框架的斷言 API 可用 —— 若 GdUnit4 未正確安裝/啟用,本檔連編譯都不會過。
    assert_bool(true).is_true()
    assert_int(1 + 1).is_equal(2)


func test_failing_assertion_is_actually_detected() -> void:
    # 比上一項重要:驗證框架**真的會判失敗**,而不是任何斷言都通過。
    # 一個永遠綠燈的測試框架比沒有測試框架更危險。
    assert_failure(func() -> void: assert_bool(false).is_true()).is_failed()


func test_engine_version_matches_pinned_version() -> void:
    # 專案釘選 Godot 4.7.1(docs/engine-reference/godot/VERSION.md)。
    # CI 執行時的引擎版本若與釘選版本不符,整個參考庫的引擎判斷都失去前提 ——
    # 這正是 ADR-0005 反覆遇到的「引擎假設未經查證」問題的基礎設施層防線。
    var info: Dictionary = Engine.get_version_info()
    assert_int(info["major"]).is_equal(4)
    assert_int(info["minor"]).is_equal(7)
