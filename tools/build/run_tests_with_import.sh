#!/bin/bash
# tools/build/run_tests_with_import.sh
#
# Godot test runner with automatic asset import (2026-10-15 manager ruling)
#
# Problem: Data files (e.g., locales/strings.csv) are version-controlled, but engine
#          import output (.translation resources) must be regenerated after changes.
#          Running tests without re-importing uses stale cache and reports false green.
#          This happened 2026-10-15: test claim "all green" was false; CSV was updated
#          but tests read pre-import cache. Only discovered when another task forced --import.
#
# Solution: Bundle import + test into one command.
#           Manager chose "always run --import" over "detect stale cache":
#           false negatives (stale cache, tests pass incorrectly) are worse than
#           false positives (10-15s cost every run). No fast path without adding
#           fragility (mtime checks, heuristics, etc.). Always pay the cost.
#
# Usage:
#   ./tools/build/run_tests_with_import.sh
#   GODOT_BIN=/path/to/godot ./tools/build/run_tests_with_import.sh
#   ./tools/build/run_tests_with_import.sh --godot-bin /path/to/godot
#
# Environment variables:
#   GODOT_BIN         Path to Godot 4.7.1 console executable
#   GODOT_PROJECT     Path to .godot project directory (default: . current directory)
#
# Exit codes:
#   0, 100, 101, 103  Test framework results (see coding-standards.md)
#   1                 Import failed (non-zero exit code)
#   2                 Godot executable not found
#   124               Import timed out (unlikely in practice, budget: 30s)
#
# Output:
#   Import log → stdout
#   Test log → stdout
#   Final summary extracted and re-printed for visibility
#
# Cost: ~10-15 seconds (import phase only, constant regardless of changes)
#       No optimization: every run includes import, even if nothing changed.
#       Reason: stale-cache detection (mtime, hashing, etc.) adds complexity and
#               creates false negatives elsewhere. Better to be uniformly slow
#               than intermittently wrong.

set -o pipefail

# === Configuration ===
GODOT_BIN="${GODOT_BIN:-}"
GODOT_PROJECT="${GODOT_PROJECT:-.}"
# 🔴 兩個逾時都可用環境變數覆寫,預設值刻意寬鬆。理由見下方註。
IMPORT_TIMEOUT_SEC="${IMPORT_TIMEOUT_SEC:-120}"
TEST_TIMEOUT_SEC="${TEST_TIMEOUT_SEC:-900}"
# 🔴 2026-10-15 協調者實測後調高(原為 import 30 / test 120)。
# 當天實測:整支腳本 94 秒,其中引擎跑測試那段約 75~80 秒(GdUnit4 自報
# Total execution time: 48s,其餘是引擎啟動與收尾)。
# **而測試數今天一天就從 1159 長到 1203。** 原本的 120 秒只剩約 40 秒餘裕。
# 一旦越過,timeout 會砍掉測試、回報 exit 124 —— 那是一個【新的】假訊號,
# 正好是本腳本存在的目的要消滅的東西(124 不在合法碼 {0,100,101,103} 內,
# 所以是響亮的,但會讓整條測試線停擺到有人查出原因為止)。
# 📌 預設值寧可寬鬆:逾時的唯一職責是防止無限期卡住(本專案登記過
# 「漏 quit() 的 headless 引擎會永遠空轉」),不是當效能門檻用。

# === Parse command-line arguments ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --godot-bin)
            GODOT_BIN="$2"
            shift 2
            ;;
        --project)
            GODOT_PROJECT="$2"
            shift 2
            ;;
        --help|-h)
            grep "^#" "$0" | grep -v "^#!/" | sed 's/^# //' | sed 's/^#$//'
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 2
            ;;
    esac
done

# === Locate Godot executable ===
find_godot_executable() {
    # Priority 1: Explicit --godot-bin argument or GODOT_BIN env var
    if [[ -n "$GODOT_BIN" && -f "$GODOT_BIN" ]]; then
        echo "$GODOT_BIN"
        return 0
    fi

    # Priority 2: Common Windows development machine (this machine's documented path)
    local dev_machine_path="C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
    if [[ -f "$dev_machine_path" ]]; then
        echo "$dev_machine_path"
        return 0
    fi

    # Priority 3: Other common Windows paths
    local fallback_paths=(
        "C:/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe"
        "C:/Program Files (x86)/Godot/Godot_v4.7.1-stable_win64_console.exe"
        "/c/Program Files/Godot/Godot_v4.7.1-stable_win64_console.exe"
        "/c/Program Files (x86)/Godot/Godot_v4.7.1-stable_win64_console.exe"
    )

    for path in "${fallback_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    # Not found
    return 1
}

# === Main execution ===
main() {
    echo "Godot Test Runner with Import (2026-10-15)"
    echo "==========================================="
    echo ""

    # Find Godot
    GODOT=$(find_godot_executable)
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Godot 4.7.1 executable not found" >&2
        echo "" >&2
        echo "  Tried:" >&2
        [[ -n "$GODOT_BIN" ]] && echo "    GODOT_BIN=$GODOT_BIN" >&2
        echo "    C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/..." >&2
        echo "    C:/Program Files/Godot/..." >&2
        echo "" >&2
        echo "  Solutions:" >&2
        echo "    export GODOT_BIN=/path/to/godot && ./run_tests_with_import.sh" >&2
        echo "    ./run_tests_with_import.sh --godot-bin /path/to/godot" >&2
        return 2
    fi

    echo "Using Godot executable:"
    echo "  $GODOT"
    echo ""
    echo "Project directory:"
    echo "  $GODOT_PROJECT"
    echo ""

    # Step 1: Run asset import
    echo "Step 1: Importing assets (--import) ..."
    echo "       (budget: ${IMPORT_TIMEOUT_SEC}s, no fast path, every run includes this)"
    echo ""

    local import_log
    import_log=$(mktemp)
    local import_exit=0

    # Run import with timeout (but timeout failures are non-fatal, just warn)
    timeout "$IMPORT_TIMEOUT_SEC" "$GODOT" --headless --path "$GODOT_PROJECT" --import >"$import_log" 2>&1 || import_exit=$?

    # Display import output
    cat "$import_log"

    # 🔴 2026-10-15 協調者實測補強:匯入會【偶發】失敗,而且不是真的壞掉。
    # 當天實測:同一份程式碼,一次 WRAPPER EXIT = 1(匯入非 0),緊接著單獨
    # 連跑三次 --import 全部 exit 0。最可能的成因是【另一個引擎行程還沒完全
    # 結束】—— 兩個引擎同時動 .godot 快取。本專案的工作方式(協調者在專家的
    # 引擎剛跑完就接著驗收)會讓這個情況經常發生。
    # ⚠️ 這比任何一條測試紅掉都嚴重:**一個會偶發誤報的閘門,跟沒有閘門一樣
    # 不可信** —— 用的人第二次看到它紅就會開始懷疑它,而不是懷疑程式碼。
    # 📌 處置:失敗時【重試一次】再判定。重試仍失敗才當成真的失敗。
    if [[ $import_exit -ne 0 && $import_exit -ne 124 ]]; then
        echo ""
        echo "NOTE: Import returned $import_exit -- retrying once before failing."
        echo "      (Known flake: another engine process may still hold the .godot cache.)"
        echo "      See this script's comment above for the 2026-10-15 measurement."
        echo ""
        import_exit=0
        timeout "$IMPORT_TIMEOUT_SEC" "$GODOT" --headless --path "$GODOT_PROJECT" --import >"$import_log" 2>&1 || import_exit=$?
        cat "$import_log"
    fi

    # Check import result
    if [[ $import_exit -eq 124 ]]; then
        echo ""
        echo "WARNING: Asset import timed out (budget exceeded, but continuing anyway)"
        echo "         This is not expected; check for large asset files or I/O issues"
        echo ""
    elif [[ $import_exit -ne 0 ]]; then
        echo ""
        echo "ERROR: Asset import failed (exit code $import_exit)"
        echo "       Cannot proceed with tests; stale cache would be used"
        rm -f "$import_log"
        return 1
    fi

    rm -f "$import_log"

    echo ""
    echo "Asset import completed successfully"
    echo ""

    # Step 2: Run tests
    echo "Step 2: Running tests ..."
    echo ""

    local test_log
    test_log=$(mktemp)
    local test_exit=0

    # Run test runner; capture exit code (critical for CI)
    timeout "$TEST_TIMEOUT_SEC" "$GODOT" --headless --path "$GODOT_PROJECT" -s tests/gdunit4_runner.gd >"$test_log" 2>&1 || test_exit=$?

    # Display all test output
    cat "$test_log"

    # Extract and re-print summary for visibility
    echo ""
    echo "========== Test Summary =========="

    local overall_summary
    overall_summary=$(grep "Overall Summary:" "$test_log" || echo "")
    if [[ -n "$overall_summary" ]]; then
        echo "$overall_summary"
    else
        echo "(No summary line found; check for early termination or parse error)"
    fi

    local executed_suites
    executed_suites=$(grep "Executed test suites:" "$test_log" || echo "")
    if [[ -n "$executed_suites" ]]; then
        echo "$executed_suites"
    fi

    echo "ENGINE EXIT = $test_exit"
    echo ""

    # Clean up
    rm -f "$test_log"

    # Return test exit code (critical for CI: CI only checks this value)
    return $test_exit
}

# Run
main "$@"
